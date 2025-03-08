# Verificación y Descarga de Payloads

Este documento proporciona los **enlaces de descarga** de los payloads y el procedimiento detallado para verificar su integridad mediante **MD5**, asegurando que corresponden al código fuente publicado.

## Pasos para verificar un payload

Para utilizar los links con **confianza** y asegurarte de que el payload descargado es auténtico, sigue estos pasos:

1. **Descargar el payload**  
   Descarga el archivo binario desde el enlace proporcionado.

2. **Verificar el MD5 del archivo descargado**  
   Ejecuta el siguiente comando para calcular su **hash MD5**:
   ```sh
   md5sum <nombre_payload_descargado>
   ```
   **Compara el resultado** con el MD5 publicado en este documento.  
   **Nota:** Si los MD5 no coinciden, **no uses el payload**. Vuelve a descargarlo.

3. **Compilar el payload**  
   Compila el payload a partir del código fuente.

4. **Verificar el MD5 según el tipo de payload**  
   Dependiendo del tipo de payload, sigue el procedimiento correspondiente:

   - **Para Payloads Estándar** (sin modificaciones):
     - Calcula el MD5 del archivo compilado:
       ```sh
       md5sum <nombre_payload_compilado>
       ```
     - **Compara** el resultado con el MD5 publicado. **Deben ser idénticos**.

   - **Para Payloads Extendidos** ([payloadextend.sh](https://github.com/Pithase/asm-payloads-loaders/blob/main/payloadextend.sh) aplicado):
     - Ejecuta el script **payloadextend.sh** para extender el payload:
       ```sh
       ./payloadextend.sh [--checksum] [--size] <nombre_payload_compilado>
       ```
     - Calcula el MD5 del archivo generado:
       ```sh
       md5sum <nombre_payload_generado>
       ```
     - **Compara** el resultado con el MD5 publicado. **Deben ser idénticos**.

## Listado de Payloads

### Payloads Estándar

| Link | MD5 | Tamaño |
|------|-----|-------:|
| `http://pithase.com.ar/bin/payload.bin` | `0badde3c53e0cf86c52fffa1ea41ef27` | 49 bytes |
| `http://pithase.com.ar/bin/payload4KBlarger.bin` | `d20d72a7d7c05ed70d58aceec8031f29` | 5.088 bytes |

### Payloads Extendidos ([payloadextend.sh](https://github.com/Pithase/asm-payloads-loaders/blob/main/payloadextend.sh) aplicado)

| Link | MD5 | Tamaño | Argumentos |
|------|-----|-------:|------------|
| `http://pithase.com.ar/bin/payload-ext-cs.bin` | `a845f257af8b9145ef61b17d2fb64db6` | 55 bytes | --checksum --size |
| `http://pithase.com.ar/bin/payload4KBlarger-ext-cs.bin` | `7ef1ec1edd3c9080d6a7118afbbaf429` | 5.094 bytes | --checksum --size |
| `http://pithase.com.ar/bin/payload-ext-c.bin` | `aaa75017b8e5e500debe7ccdfc7c5c1a` | 52 bytes | --checksum |
| `http://pithase.com.ar/bin/payload4KBlarger-ext-c.bin` | `515fc532fb39eada6adcf4aced73b02e` | 5.091 bytes | --checksum|

### Payloads en Registros TXT de DNS ([payloadextend.sh](https://github.com/Pithase/asm-payloads-loaders/blob/main/payloadextend.sh) aplicado)

| Nombre | MD5 | Tamaño | Argumentos |
|--------|-----|-------:|------------|
| `payload.pithase.com.ar` | `eba1ebb72c905624bfa5352636b45a0f` | 106 bytes | --checksum --dns |
| `payload4KBlarger.pithase.com.ar` | `3b3a809722e1afd65efee1c4c2a68a66` | 10.304 bytes | --checksum --dns |
