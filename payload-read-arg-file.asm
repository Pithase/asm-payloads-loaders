;=============================================================================================
; Archivo      : payload-read-arg-file.asm
; Creado       : 11/02/2025
; Modificado   : 01/06/2025
; Autor        : Gastón M. González
; Plataforma   : Linux
; Arquitectura : x86-64
; Descripción  : Loader de payload contenido en un archivo, con reserva de
;                memoria dinámica según el tamaño del payload. El nombre
;                del archivo se pasa como argumento.
;
; Compilar     : nasm -f elf64 payload-read-arg-file.asm -o payload-read-arg-file.o
; Linkear      : ld payload-read-arg-file.o -o payload-read-arg-file
; Ejecutar     : ./payload-read-arg-file <archivo_payload>
; Ejecutar     : ./payload-read-arg-file <archivo_payload> ; echo "Código de salida:" $?
;=============================================================================================
; Licencia MIT:
; Este código es de uso libre bajo los términos de la Licencia MIT.
; Puedes usarlo, modificarlo y redistribuirlo, siempre que incluyas esta nota de atribución.
; NO HAY GARANTÍA DE NINGÚN TIPO, EXPRESA O IMPLÍCITA.
; Licencia completa en: https://github.com/Pithase/asm-payloads-loaders/blob/main/LICENSE
;=============================================================================================
; Referencia:
; https://github.com/Pithase/asm-payloads-loaders/blob/main/structures.md#struct-stat
;=============================================================================================

section .rodata
    usage_msg db "Uso: ./payload-read-arg-file <archivo_payload>", 10
    usage_msg_len equ $ - usage_msg

section .bss
    fd         resq 1           ; descriptor de archivo
    exec_mem   resq 1           ; dirección de memoria ejecutable (asignada con mmap)
    statbuf    resb 144         ; buffer para la estructura stat (struct stat en x86-64)

section .text
    global _start

_start:
    ;=========================================================================
    ; 1. Verifica que se haya pasado al menos un argumento (archivo payload)
    ;=========================================================================
    mov rax, [rsp]          ; rax = argc
    cmp rax, 2
    jl usage_error          ; si argc < 2, error de uso

    ; Obtiene la dirección del argumento argv[1] (nombre del archivo)
    mov rsi, [rsp+16]       ; rsi = pointer a argv[1]

    ;=========================================================================
    ; 2. Abre el archivo que contiene el payload
    ;=========================================================================
    mov rax, 2              ; syscall: open
    mov rdi, rsi            ; rdi = pointer al nombre del archivo (argv[1])
    mov rsi, 0              ; O_RDONLY (solo lectura)
    syscall
    test rax, rax
    js open_error
    mov [fd], rax           ; guardar el descriptor de archivo

    ;=========================================================================
    ; 3. Obtiene el tamaño del archivo mediante fstat
    ;=========================================================================
    mov rax, 5              ; syscall: fstat 
    mov rdi, [fd]           ; descriptor de archivo
    lea rsi, [statbuf]      ; dirección del buffer para struct stat
    syscall
    test rax, rax
    js fstat_error

    ; Extrae el tamaño del payload (st_size se encuentra a 48 bytes en struct stat)
    mov rbx, [statbuf + 48] ; rbx = tamaño del archivo
    cmp rbx, 0
    je empty_file_error     ; error si el archivo está vacío

    ;=========================================================================
    ; 4. Calcula el tamaño a mapear, redondeando al múltiplo de 4096
    ;=========================================================================
    mov rax, rbx          ; rax = tamaño del payload
    add rax, 4095         ; suma 4095 para el redondeo
    and rax, 0xFFFFFFFFFFFFF000  ; redondea hacia abajo al múltiplo de 4096

    ;=========================================================================
    ; 5. Reserva memoria ejecutable con mmap (según el tamaño calculado)
    ;=========================================================================
    mov rdi, 0              ; dejar que el sistema elija la dirección
    mov rsi, rax            ; tamaño mapeado (redondeado)
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
    ; 6. Lee el contenido y lo almacena en la memoria reservada
    ;=========================================================================
    mov rdi, [fd]           ; descriptor de archivo
    mov rax, 0              ; syscall: read
    mov rsi, [exec_mem]     ; buffer destino (memoria mapeada)
    mov rdx, rbx            ; cantidad de bytes a leer = tamaño del payload
    syscall
    cmp rax, 0
    jl read_error           ; error en la syscall read
    je empty_file_error     ; si no se leyó nada, el archivo está vacío

    ;=========================================================================
    ; 7. Cierra el archivo
    ;=========================================================================
    mov rax, 3              ; syscall: close
    mov rdi, [fd]
    syscall

    ;=========================================================================
    ; 8. Ejecuta el payload
    ;=========================================================================
    call qword [exec_mem]   ; llama al payload cargado en memoria

    ;=========================================================================
    ; 9. Salida: Se alcanza solo si el payload retorna
    ;=========================================================================
    mov rax, 60             ; syscall: exit
    xor rdi, rdi
    syscall

;=========================================================================
; Manejo de errores: Salida con código distinto según el error
;=========================================================================
open_error:
    mov rdi, 1
    jmp exit_error

read_error:
    mov rdi, 2
    jmp exit_error

empty_file_error:
    mov rdi, 3
    jmp exit_error

mmap_error:
    mov rdi, 4
    jmp exit_error

fstat_error:
    mov rdi, 5
    jmp exit_error

usage_error:
    ; Imprime el mensaje de uso en stderr (fd = 2)
    mov rax, 1                ; syscall: write
    mov rdi, 2                ; file descriptor: stderr
    lea rsi, [rel usage_msg]  ; dirección del mensaje
    mov rdx, usage_msg_len    ; longitud del mensaje
    syscall
    mov rdi, 6

exit_error:
    mov rax, 60             ; syscall: exit
    syscall
