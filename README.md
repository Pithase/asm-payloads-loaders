# Serie: Cargadores de Payloads - #Assembly #Picante

Desarrollo paso a paso de cargadores de payloads, escritos exclusivamente en **Ensamblador x86-64 para Linux**, sin dependencias externas y utilizando sólo **syscalls nativas**.

## Objetivo  

Una vez avanzada la serie, publicaré en forma detallada el paso a paso para poder desarrollar cada uno de los ejemplos, aportando toda la documentación y explicaciones necesarias para que lo comprendas **de punta a punta** y no te quede absolutamente ninguna duda.

## Contacto  

Si tenés dudas, sugerencias o correcciones, escribime a:  
✉️ `repo-asm-payloads-loaders@pithase.com.ar`  
⠀

## Payloads para los Ejemplos  

| Archivo | Descripción | Video |
|---------|------------:|-------|
| [`payload.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload.asm) | 49 bytes | <a href="https://www.youtube.com/watch?v=WlPRBZxzqQ8" target="_blank">Ir a verlo</a> |
| [`payload4KBlarger.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload4KBlarger.asm) | 5.088 bytes | <a href="https://www.youtube.com/watch?v=J9Zz03EN7mc" target="_blank">Ir a verlo</a> |

👉 **[Links de los archivos binarios](https://github.com/Pithase/asm-payloads-loaders/tree/main/bin)**  
⠀

## Cargadores de Payload  

### Cargadores de Payload desde Archivos  

| Archivo | Descripción |
|---------|-------------|
| [`payload-read-file-short.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-file-short.asm) | Carga de un payload de un archivo **<= 4KB** |
| [`payload-read-file.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-file.asm) | Carga un payload desde archivo con **reserva de memoria dinámica** según su tamaño |
| [`payload-read-arg-file.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-arg-file.asm) | Permite especificar el **archivo como argumento**, lee su tamaño y **asigna memoria dinámica** según corresponda |

### Cargadores de Payload desde HTTP (no HTTPS)  

| Archivo | Descripción |
|---------|-------------|
| [`payload-read-http-file-size-fixed.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-http-file-size-fixed.asm) | Carga un payload **<= 4KB** con un tamaño predefinido en el código |
| [`payload-read-http-file-size-fixed-checksum.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-http-file-size-fixed-checksum.asm) | Carga un payload **<= 4KB** con un tamaño y checksum predefinidos en el código, **verificando el checksum** antes de ejecutarlo |
| [`payload-read-http-file-size-dynamic-checksum.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-http-file-size-dynamic-checksum.asm) | Carga un payload de **tamaño variable**, **sin límite de tamaño** (predefinido en el código) y **verifica el checksum** antes de ejecutarlo |
| [`http-payload-loader-full-dynamic-checksum.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/http-payload-loader-full-dynamic-checksum.asm) | Carga un payload de forma **TOTALMENTE DINÁMICA**, capaz de manejar payloads de **tamaño variable sin límites predefinidos**, con **verificación de integridad mediante checksum** |

### Cargadores de Payload desde DNS  

| Archivo | Descripción |
|---------|-------------|
| [`dns-payload-loader-full-dynamic-checksum.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/dns-payload-loader-full-dynamic-checksum.asm) | Carga un payload de forma **TOTALMENTE DINÁMICA**, capaz de manejar payloads de **tamaño variable sin límites predefinidos**, con **verificación de integridad mediante checksum** |
