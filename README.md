# Serie: Cargadores de Payloads - #Assembly #Picante

Desarrollo paso a paso de cargadores de payloads, escritos exclusivamente en **Ensamblador x86-64 para Linux**, sin dependencias externas y utilizando sólo **syscalls nativas**.

Una vez avanzada la serie, se publicará en forma detallada el paso a paso para poder desarrollar cada uno de los ejemplos, aportando toda la documentación y explicaciones necesarias para que lo comprendas de punta a punta y no te quede absolutamente ninguna duda.

## Ejemplos

1. **Payload para Ejemplos**  
   [payload-read-file-short.asm](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-file-short.asm)  
   Payload de 49 bytes.
   
   [payload4KBlarger.asm](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload4KBlarger.asm)  
   Payload de 5.088 bytes.

2. **Carga de Payload desde un Archivo (<= 4KB)**  
   [payload-read-file-short.asm](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-file-short.asm)  
   Carga un payload contenido en un archivo. Tamaño máximo del paylaod 4KB.

3. **Carga de Payload desde un Archivo con reserva de memoria dinámica según el tamaño del payload**  
   [payload-read-file.asm](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-file.asm)  
   Carga un payload contenido en un archivo.

4. **Carga de Payload desde un Archivo, especificado por argumento, con reserva de memoria dinámica según el tamaño del payload**  
   [payload-read-arg-file.asm](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-arg-file.asm)  
   Carga un payload contenido en un archivo.
