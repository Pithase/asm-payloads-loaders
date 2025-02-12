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

3. **Carga de Payload desde un Archivo con reserva de memoria dinámica según el tamaño del payload**  
   [payload-read-file.asm](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-file.asm)  

4. **Carga de Payload desde un Archivo, especificado por argumento, con reserva de memoria dinámica según el tamaño del payload**  
   [payload-read-arg-file.asm](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-arg-file.asm)  

5. **Carga de Payload desde HTTP (no HTTPS), con payload <= 4KB**  
   [payload-read-http-file-size-fixed.asm](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-http-file-size-fixed.asm)  

6. **Carga de Payload desde HTTP (no HTTPS), con payload <= 4KB y verificación de checksum**  
   [payload-read-http-file-size-fixed-checksum.asm](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-http-file-size-fixed-checksum.asm)  
   
