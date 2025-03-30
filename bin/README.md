# Verificación y Descarga de Payloads

Este documento proporciona los **enlaces de descarga** de los payloads y el procedimiento detallado para verificar su integridad mediante **MD5**, asegurando que corresponden al código fuente publicado.     

**Nota:** Si los MD5 no coinciden, **no uses el payload y tampoco el link que lo referencia en ningún programa**.

## Pasos para verificar un payload

Para utilizar los links con **confianza** y asegurarte de que el payload descargado es auténtico, sigue estos pasos:

1. **Descargar el payload**  
   Descarga el archivo binario desde el [enlace proporcionado](https://github.com/Pithase/asm-payloads-loaders/blob/main/bin/README.md#payloads-est%C3%A1ndar).
   ```sh
   wget -O <nombre_payload_descargado> <link_payload_descargar>
   ```
   ```sh
   ❯  wget -O payload-http.bin http://pithase.com.ar/bin/payload.bin
   ``` 

3. **Verificar el MD5 del archivo descargado**  
   Ejecuta el siguiente comando para calcular su **MD5**:
   ```sh
   md5sum <nombre_payload_descargado>
   ```
   ```sh
   ❯  md5sum payload-http.bin

   ❮  0badde3c53e0cf86c52fffa1ea41ef27  payload-http.bin
   ```      
   **Compara** el resultado con el MD5 publicado. **Deben ser idénticos**.  

4. **Compilar el payload**  
   Compila el payload a partir del código fuente.

5. **Verificar el MD5 según el tipo de payload**  
   Dependiendo del tipo de payload, sigue el procedimiento correspondiente:

   - **Para Payloads Estándar** (sin modificaciones):
     - Calcula el MD5 del archivo compilado:
       ```sh
       md5sum <nombre_payload_compilado>
       ```
       ```sh
       ❯  md5sum payload.bin

       ❮  0badde3c53e0cf86c52fffa1ea41ef27  payload.bin
       ```       
     - **Compara** el resultado con el MD5 publicado. **Deben ser idénticos**.

   - **Para Payloads Extendidos** ([payloadextend.sh](https://github.com/Pithase/asm-payloads-loaders/blob/main/payloadextend.sh) aplicado):
     - Ejecuta el script **payloadextend.sh** para extender el payload:
       ```sh
       ./payloadextend.sh [--checksum] [--size] <nombre_payload_compilado>
       ```
       ```sh
       ❯  ./payloadextend.sh --checksum payload.bin

       ❮  ✓ Archivo 'payload-ext-c.bin' generado correctamente. Se agregó información adicional de checksum.
       ```        
     - Calcula el MD5 del archivo generado:
       ```sh
       md5sum <nombre_payload_generado>
       ```
       ```sh
       ❯  md5sum payload-ext-c.bin

       ❮  aaa75017b8e5e500debe7ccdfc7c5c1a  payload-ext-c.bin
       ```       
     - **Compara** el resultado con el MD5 publicado. **Deben ser idénticos**.
    
   - **Para Payloads en Registros TXT de DNS** ([payloadextend.sh](https://github.com/Pithase/asm-payloads-loaders/blob/main/payloadextend.sh) aplicado):
     - Ejecuta el script **payloadextend.sh** para generar un archivo del payload convertido a hexadecimal :
       ```sh
       ./payloadextend.sh [--checksum] [--size] --dns <nombre_payload_compilado>
       ```       
       ```sh
       ❯  ./payloadextend.sh --checksum --dns payload.bin

       ❮  ✓ Archivo 'payload-ext-c.bin' generado correctamente. Se agregó información adicional de checksum.
       ❮  ✓ Archivo 'payload-ext-c-dns.txt' generado correctamente para su uso en registros TXT de DNS.
       ```
     - Calcula el MD5 del archivo generado:
       ```sh
       tr -d ' "' < <nombre_payload_generado> | md5sum
       ```
       ```sh
       ❯  tr -d ' "' < payload-ext-c-dns.txt | md5sum | awk '{print $1}'

       ❮  eba1ebb72c905624bfa5352636b45a0f
       ```
     - Calcula el MD5 del payload contenido en el registro TXT del DNS:
       ```sh
       ./dns-txt-validator.sh <nombre-registro-TXT>.<dominio>
       ```
       ```sh       
       ❯  ./dns-txt-validator.sh payload-ext-c-hex.pithase.com.ar

       ❮  ✓ MD5 del contenido TXT de payload-ext-c-hex.pithase.com.ar: eba1ebb72c905624bfa5352636b45a0f
       ```       
     - **Compara** ambos resultados con el MD5 publicado. **Deben ser idénticos**.

## Listado de Payloads

### Payloads Estándar

| Link | MD5 | Tamaño | Video |
|------|-----|-------:|-------|
| `http://pithase.com.ar/bin/payload.bin` | `0badde3c53e0cf86c52fffa1ea41ef27` | 49 bytes | <a href="https://www.youtube.com/watch?v=WlPRBZxzqQ8" target="_blank">Ir a verlo</a> |
| `http://pithase.com.ar/bin/payload4KBlarger.bin` | `d20d72a7d7c05ed70d58aceec8031f29` | 5.088 bytes | |

### Payloads Extendidos ([payloadextend.sh](https://github.com/Pithase/asm-payloads-loaders/blob/main/payloadextend.sh) aplicado)

| Link | MD5 | Tamaño | Argumentos |
|------|-----|-------:|------------|
| `http://pithase.com.ar/bin/payload-ext-c.bin` | `aaa75017b8e5e500debe7ccdfc7c5c1a` | 52 bytes | --checksum |
| `http://pithase.com.ar/bin/payload-ext-cs.bin` | `a845f257af8b9145ef61b17d2fb64db6` | 55 bytes | --checksum --size |
| `http://pithase.com.ar/bin/payload4KBlarger-ext-c.bin` | `515fc532fb39eada6adcf4aced73b02e` | 5.091 bytes | --checksum|
| `http://pithase.com.ar/bin/payload4KBlarger-ext-cs.bin` | `7ef1ec1edd3c9080d6a7118afbbaf429` | 5.094 bytes | --checksum --size |

### Payloads en Registros TXT de DNS ([payloadextend.sh](https://github.com/Pithase/asm-payloads-loaders/blob/main/payloadextend.sh) aplicado)

| Nombre | MD5 | Tamaño | Formato | Argumentos |
|--------|-----|-------:|---------|------------|
| `payload-ext-c-hex.pithase.com.ar` | `eba1ebb72c905624bfa5352636b45a0f` | 110 bytes | hexadecimal | --checksum --dns |
| `payload4KBlarger-ext-c-hex.pithase.com.ar` | `3b3a809722e1afd65efee1c4c2a68a66` | 10.188 bytes | hexadecimal | --checksum --dns |
