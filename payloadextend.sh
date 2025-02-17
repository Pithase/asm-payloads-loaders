#!/bin/bash

#=========================================================================================================
# Archivo      : payloadextend.sh
# Creado       : 14/02/2025
# Modificado   : 14/02/2025
# Autor        : Gastón M. González
# Plataforma   : Linux
# Arquitectura : x86-64
# Descripción  : Genera una copia de un archivo binario con información adicional, agregándole:
#                • Checksum global aditivo sobre el payload (3 bytes, en little endian).
#                • Longitud del payload (3 bytes, en little endian).
#
#                El archivo resultante queda estructurado de la siguiente manera:
#                ┌────────────────────────────┬────────────────────────┬────────────────────────┐
#                │      Payload original      │ Checksum (3 bytes, LE) │ Longitud (3 bytes, LE) │
#                └────────────────────────────┴────────────────────────┴────────────────────────┘
#
# Configuración: Asegurarse de que el script tenga permisos de ejecución:
#                chmod +x payloadextend.sh
#
# Uso          : ./payloadextend.sh payload.bin
#=========================================================================================================
# Licencia MIT:
# Este código es de uso libre bajo los términos de la Licencia MIT.
# Puedes usarlo, modificarlo y redistribuirlo, siempre que incluyas esta nota de atribución.
# NO HAY GARANTÍA DE NINGÚN TIPO, EXPRESA O IMPLÍCITA.
# Licencia completa en: https://github.com/Pithase/asm-payloads-loaders/blob/main/LICENSE
#=========================================================================================================

#---------------------------------------------------------------------------------------------------------
# 1. Recupera el argumento del archivo binario
#---------------------------------------------------------------------------------------------------------
LOCAL_FILE="$1"

#---------------------------------------------------------------------------------------------------------
# 2. Verifica el argumento y la existencia del archivo
#---------------------------------------------------------------------------------------------------------
if [ -z "$LOCAL_FILE" ] || [ ! -f "$LOCAL_FILE" ]; then
  echo "ERROR: Debes especificar un archivo binario válido."
  echo "Uso: $0 <archivo.bin>"
  echo "Ejemplo: $0 payload.bin"
  exit 1
fi

#---------------------------------------------------------------------------------------------------------
# 3. Obtiene el tamaño en bytes del archivo original
#---------------------------------------------------------------------------------------------------------
SIZE=$(stat -c%s "$LOCAL_FILE")

#---------------------------------------------------------------------------------------------------------
# 4. Nombre del nuevo archivo (sufijo -ext)
#---------------------------------------------------------------------------------------------------------
NEW_FILE="${LOCAL_FILE%.*}-ext.${LOCAL_FILE##*.}"

#---------------------------------------------------------------------------------------------------------
# 5. Copia el archivo original
#---------------------------------------------------------------------------------------------------------
cp "$LOCAL_FILE" "$NEW_FILE"

#---------------------------------------------------------------------------------------------------------
# 6. Calcula el checksum sumando todos los bytes del archivo original
#---------------------------------------------------------------------------------------------------------
CHECKSUM=$(od -An -tu1 "$LOCAL_FILE" | awk '{ for(i=1;i<=NF;i++) s+=$i } END { printf "%d", s }')

#---------------------------------------------------------------------------------------------------------
# 7. Extrae los 3 bytes del checksum en little endian
#---------------------------------------------------------------------------------------------------------
C0=$(( CHECKSUM        & 0xFF ))
C1=$(( (CHECKSUM >> 8) & 0xFF ))
C2=$(( (CHECKSUM >>16) & 0xFF ))

#---------------------------------------------------------------------------------------------------------
# 8. Extrae los 3 bytes de la longitud en little endian
#---------------------------------------------------------------------------------------------------------
B0=$(( SIZE        & 0xFF ))
B1=$(( (SIZE >> 8) & 0xFF ))
B2=$(( (SIZE >>16) & 0xFF ))

#---------------------------------------------------------------------------------------------------------
# 9. Agrega el checksum (3 bytes)
#---------------------------------------------------------------------------------------------------------
printf "%b" "\\x$(printf '%02x' "$C0")\\x$(printf '%02x' "$C1")\\x$(printf '%02x' "$C2")" >> "$NEW_FILE"

#---------------------------------------------------------------------------------------------------------
# 10. Agrega la longitud (3 bytes)
#---------------------------------------------------------------------------------------------------------
printf "%b" "\\x$(printf '%02x' "$B0")\\x$(printf '%02x' "$B1")\\x$(printf '%02x' "$B2")" >> "$NEW_FILE"

#---------------------------------------------------------------------------------------------------------
# 11. Mensaje de éxito
#---------------------------------------------------------------------------------------------------------
echo "✅ Archivo '$NEW_FILE' generado correctamente con metadatos."
