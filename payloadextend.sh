#!/bin/bash

#================================================================================================================
# Archivo      : payloadextend.sh
# Creado       : 14/02/2025
# Modificado   : 21/02/2025
# Autor        : Gastón M. González
# Plataforma   : Linux
# Arquitectura : x86-64
# Descripción  : Genera una copia de un archivo binario con información adicional, agregando según se solicite:
#                • Checksum global aditivo sobre el payload (3 bytes, en little endian).
#                • Tamaño del payload (3 bytes, en little endian).
#
#                El archivo resultante puede quedar estructurado de las siguientes formas:
#
#                • --checksum + --size
#                ┌────────────────────────────┬────────────────────────┬────────────────────────┐
#                │      Payload original      │ Checksum (3 bytes, LE) │  Tamaño (3 bytes, LE)  │
#                └────────────────────────────┴────────────────────────┴────────────────────────┘
#
#                • --checksum
#                ┌────────────────────────────┬────────────────────────┐
#                │      Payload original      │ Checksum (3 bytes, LE) │
#                └────────────────────────────┴────────────────────────┘
#
#                • --size
#                ┌────────────────────────────┬────────────────────────┐
#                │      Payload original      │  Tamaño (3 bytes, LE)  │
#                └────────────────────────────┴────────────────────────┘
#
# Configuración: Asegurarse de que el script tenga permisos de ejecución:
#                chmod +x payloadextend.sh
#
# Uso          : ./payloadextend.sh [--checksum] [--size] <archivo-payload>
#================================================================================================================
# Licencia MIT:
# Este código es de uso libre bajo los términos de la Licencia MIT.
# Puedes usarlo, modificarlo y redistribuirlo, siempre que incluyas esta nota de atribución.
# NO HAY GARANTÍA DE NINGÚN TIPO, EXPRESA O IMPLÍCITA.
# Licencia completa en: https://github.com/Pithase/asm-payloads-loaders/blob/main/LICENSE
#================================================================================================================

#----------------------------------------------------------------------------------------------------------------
# 1. Verifica los argumentos y define flags
#----------------------------------------------------------------------------------------------------------------
ADD_CHECKSUM=false
ADD_SIZE=false
FILE_PROVIDED=false
INVALID_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --checksum) ADD_CHECKSUM=true; shift ;;
    --size) ADD_SIZE=true; shift ;;
    --help|-h)
      echo "Uso: $0 [--checksum] [--size] <archivo-payload>"
      echo "Opciones:"
      echo "  --checksum  agrega el checksum"
      echo "  --size      agrega el tamaño del archivo"
      echo "Ejemplo:"
      echo "  $0 --checksum --size payload.bin"
      exit 0
      ;;
    -*)
      INVALID_ARGS+=("$1")  # Guarda los argumentos inválidos
      shift
      ;;
    *)
      if [ -z "$LOCAL_FILE" ]; then
        LOCAL_FILE="$1"
        FILE_PROVIDED=true
      else
        INVALID_ARGS+=("$1")  # Si hay más de un archivo, lo tratamos como argumento inválido
      fi
      shift
      ;;
  esac
done

#----------------------------------------------------------------------------------------------------------------
# 2. Verifica si hay argumentos inválidos
#----------------------------------------------------------------------------------------------------------------
if [ ${#INVALID_ARGS[@]} -gt 0 ]; then
  if [ ${#INVALID_ARGS[@]} -eq 1 ]; then
    echo "ERROR: El argumento '${INVALID_ARGS[0]}' no se reconoce."
  elif [ ${#INVALID_ARGS[@]} -eq 2 ]; then
    echo "ERROR: Los argumentos '${INVALID_ARGS[0]}' y '${INVALID_ARGS[1]}' no se reconocen."
  else
    echo "ERROR: Los siguientes argumentos no se reconocen: ${INVALID_ARGS[*]}"
  fi
  exit 1
fi

#----------------------------------------------------------------------------------------------------------------
# 3. Verifica que se haya proporcionado un archivo válido
#----------------------------------------------------------------------------------------------------------------
if ! $FILE_PROVIDED || [ ! -f "$LOCAL_FILE" ]; then
  echo "ERROR: Debes especificar un archivo binario válido."
  echo "Uso: $0 [--checksum] [--size] <archivo-payload>"
  exit 1
fi

#----------------------------------------------------------------------------------------------------------------
# 4. Verifica que al menos una opción haya sido seleccionada
#----------------------------------------------------------------------------------------------------------------
if ! $ADD_CHECKSUM && ! $ADD_SIZE; then
  echo "ERROR: Debes especificar al menos una opción (--checksum o --size)."
  echo "Uso: $0 [--checksum] [--size] <archivo-payload>"
  exit 1
fi

#----------------------------------------------------------------------------------------------------------------
# 5. Obtiene el tamaño en bytes del archivo original
#----------------------------------------------------------------------------------------------------------------
SIZE=$(stat -c%s "$LOCAL_FILE")

#----------------------------------------------------------------------------------------------------------------
# 6. Nombre del nuevo archivo (sufijo -ext)
#----------------------------------------------------------------------------------------------------------------
NEW_FILE="${LOCAL_FILE%.*}-ext.${LOCAL_FILE##*.}"

#----------------------------------------------------------------------------------------------------------------
# 7. Copia el archivo original
#----------------------------------------------------------------------------------------------------------------
cp "$LOCAL_FILE" "$NEW_FILE"

#----------------------------------------------------------------------------------------------------------------
# 8. Calcula el checksum sumando todos los bytes del archivo original (si está habilitado)
#----------------------------------------------------------------------------------------------------------------
if $ADD_CHECKSUM; then
  CHECKSUM=$(od -An -tu1 "$LOCAL_FILE" | awk '{ for(i=1;i<=NF;i++) s+=$i } END { printf "%d", s }')
  C0=$(( CHECKSUM        & 0xFF ))
  C1=$(( (CHECKSUM >> 8) & 0xFF ))
  C2=$(( (CHECKSUM >>16) & 0xFF ))

  # Agrega el checksum (3 bytes)
  printf "%b" "\\x$(printf '%02x' "$C0")\\x$(printf '%02x' "$C1")\\x$(printf '%02x' "$C2")" >> "$NEW_FILE"
fi

#----------------------------------------------------------------------------------------------------------------
# 9. Extrae los 3 bytes del tamaño en little endian (si está habilitado)
#----------------------------------------------------------------------------------------------------------------
if $ADD_SIZE; then
  B0=$(( SIZE        & 0xFF ))
  B1=$(( (SIZE >> 8) & 0xFF ))
  B2=$(( (SIZE >>16) & 0xFF ))

  # Agrega el tamaño (3 bytes)
  printf "%b" "\\x$(printf '%02x' "$B0")\\x$(printf '%02x' "$B1")\\x$(printf '%02x' "$B2")" >> "$NEW_FILE"
fi

#----------------------------------------------------------------------------------------------------------------
# 10. Mensaje de éxito según la acción realizada
#----------------------------------------------------------------------------------------------------------------
echo -n "✅ Archivo '$NEW_FILE' generado correctamente. Se agregó información adicional"

if $ADD_CHECKSUM && $ADD_SIZE; then
  echo " de checksum y tamaño."
elif $ADD_CHECKSUM; then
  echo " de checksum."
elif $ADD_SIZE; then
  echo " de tamaño."
fi
