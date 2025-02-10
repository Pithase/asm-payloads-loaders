;===========================================================================
; Archivo      : payload4KBlarger.asm
; Creado       : 10/02/2025
; Modificado   : 10/02/2025
; Autor        : Gastón M. González
; Plataforma   : Linux
; Arquitectura : x86-64
; Descripción  : Payload de prueba (+4KB) para los ejemplos de los loaders
;
; Para usarlo como Payload
; Compilar     : nasm -f bin payload4KBlarger.asm -o payload4KBlarger.bin
;
; Para ejecutarlo en forma independiente
; Compilar     : nasm -f elf64 payload4KBlarger.asm -o payload4KBlarger.o
; Linkear      : ld payload4KBlarger.o -o payload4KBlarger
; Ejecutar     : ./payload4KBlarger
;===========================================================================

BITS 64
global _start

section .text

_start:
    xor rax, rax
    inc rax

    xor rdi, rdi
    inc rdi

    ; Obtiene la dirección de "message" sin ceros, usando un lea ajustado:
    ; Se utiliza una constante arbitraria (0x11111111) que, sumada al desplazamiento real,
    ; produce un inmediato sin 0x00; luego se resta esa misma constante.
    lea rsi, [rel message + 0x11111111]  ; codifica el desplazamiento (message - RIP + 0x11111111)
    sub rsi, 0x11111111                  ; ahora rsi apunta a message

    ; Configura rdx = 5045 (0x13b5)
    xor rdx, rdx
    mov dl, 0xb5
    mov dh, 0x13

    syscall              ; syscall (sys_write)

    ; Salir: syscall exit(0)
    push 60
    pop rax
    xor rdi, rdi
    syscall

; La cadena a imprimir: "Hola Mundo!" seguido de 719 'Pithase' más el salto de línea.
; Suman 5.045 bytes
;"Hola Mundo!": 11 bytes
;Repeticiones de "Pithase": 719 × 7 = 5033 bytes
;Salto de línea: 1 byte
message:
    db "Hola Mundo!"
    times 719 db 'Pithase'
    db 10
	
