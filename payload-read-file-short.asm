;======================================================================
; Archivo      : payload-read-file.asm
; Creado       : 09/02/2025
; Modificado   : 09/02/2025
; Autor        : Gastón M. González
; Plataforma   : Linux
; Arquitectura : x86-64
; Descripción  : Loader de payload contenido en un archivo <= 4KB
;
; Compilar     : nasm -f elf64 payload-read-file.asm -o payload-read-file.o
; Linkear      : ld payload-read-file.o -o payload-read-file
; Ejecutar     : ./payload-read-file
;======================================================================
	
section .rodata
    filename db "payload.bin", 0   ; nombre del archivo que contiene el payload

section .bss
    fd resq 1           ; descriptor de archivo
    exec_mem resq 1     ; dirección de memoria ejecutable (asignada con mmap)

section .text
    global _start

_start:
    ;======================================================================
    ; 1. Abre el archivo "payload.bin"
    ;======================================================================
    mov rax, 2              ; syscall: open
    lea rdi, [filename]     ; dirección del nombre del archivo
    mov rsi, 0              ; O_RDONLY (solo lectura)
    syscall
    test rax, rax
    js open_error
    mov [fd], rax           ; guardar el descriptor de archivo

    ;======================================================================
    ; 2. Reserva memoria ejecutable con mmap (4KB)
    ;======================================================================
    mov rax, 9              ; syscall: mmap
    xor rdi, rdi            ; dejar que el sistema elija la dirección
    mov rsi, 4096           ; tamaño: 4KB
    mov rdx, 7              ; PROT_READ | PROT_WRITE | PROT_EXEC
    mov r10, 0x22           ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1              ; sin descriptor de archivo
    mov r9, 0               ; offset = 0
    syscall
    test rax, rax
    js mmap_error
    mov [exec_mem], rax     ; guardar dirección asignada

    ;======================================================================
    ; 3. Lee el contenido y lo almacena en la memoria reservada
    ;======================================================================
    mov rdi, [fd]           ; descriptor de archivo
    mov rax, 0              ; syscall: read
    mov rsi, [exec_mem]     ; buffer destino
    mov rdx, 4096           ; máximo 4KB a leer
    syscall
    cmp rax, 0
    jl read_error           ; si rax < 0, error en la syscall
    je empty_file_error     ; si rax == 0, archivo vacío

    ;======================================================================
    ; 4. Cierra el archivo
    ;======================================================================
    mov rax, 3              ; syscall: close
    mov rdi, [fd]
    syscall

    ;======================================================================
    ; 5. Ejecuta el payload
    ;======================================================================
    call qword [exec_mem]   ; llamar al payload

    ;======================================================================
    ; 6. Salida: Se alcanza solo si el payload retorna
    ;======================================================================
    mov rax, 60             ; syscall: exit
    xor rdi, rdi
    syscall

 ;======================================================================
 ; Manejo de errores: Salida con código distinto según el error
 ;======================================================================
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

exit_error:
    mov rax, 60             ; syscall: exit
    syscall
