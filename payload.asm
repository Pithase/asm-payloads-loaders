;======================================================================
; Archivo      : payload.asm
; Creado       : 08/02/2025
; Modificado   : 08/02/2025
; Autor        : Gastón M. González
; Plataforma   : Linux
; Arquitectura : x86-64
; Descripción  : Payload de prueba para los ejemplos de los loaders
;
; Compilar     : nasm -f bin payload.asm -o payload.bin
;======================================================================

BITS 64
global _start

section .text

_start:
    xor rax, rax
    inc rax
    mov rdi, rax
    push 0x0a216f64              ;"do!\n" en little-endian
    mov rbx, 0x6e754d20616c6f48  ;"Hola Mun" en little-endian
    push rbx

    mov rsi, rsp
    xor rdx, rdx
    add rdx, 12
    syscall

    add rsp, 16 ;recupero la pila

    push 60
    pop rax
    xor rdi, rdi
    syscall
