# Serie: Cargadores de Payloads - #Assembly #Picante

Desarrollo paso a paso de cargadores de payloads, escritos exclusivamente en **Ensamblador x86-64 para Linux**, sin dependencias externas y utilizando sólo **syscalls nativas**.

## Ejemplos

1. **Payload para Ejemplos**  
   [payload.asm](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload.asm)  
   Payload de 49 bytes.
   
   [payload4KBlarger.asm](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload4KBlarger.asm)  
   Payload de 5.088 bytes.

3. **Carga de Payload desde un Archivo (<= 4KB)**  
   [payload-read-file.asm](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-file.asm)  
   Carga un payload contenido en un archivo. Tamaño máximo del paylaod 4KB.
