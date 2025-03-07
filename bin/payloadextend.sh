#!/bin/bash

#================================================================================================================
# Archivo      : payloadextend.sh
# Creado       : 07/03/2025
# Modificado   : 07/03/2025
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
#                El nombre del archivo generado refleja las opciones utilizadas.
#                Por ejemplo, si se usa payload.bin, los nombres de los archivos generados serán:
#                • payload-ext-c.bin  → si se usó --checksum
#                • payload-ext-s.bin  → si se usó --size
#                • payload-ext-cs.bin → si se usaron ambos
#
#                Si se usa el argumento --dns, se genera un archivo con el contenido del payload convertido
#                a hexadecimal, para su uso en registros TXT de DNS. Este argumento admite un tamaño máximo
#                de 65535 bytes.
#                
#                Los nombres de los archivos generados serán:
#                • payload-dns.txt        → si no utilizó ningún argumento adicional
#                • payload-ext-c-dns.txt  → si se usó --checksum
#                • payload-ext-s-dns.txt  → si se usó --size
#                • payload-ext-cs-dns.txt → si se usaron ambos
#
# Configuración: Asegurarse de que el script tenga permisos de ejecución: 
#                chmod +x payloadextend.sh
#
# Uso          : ./payloadextend.sh [--checksum] [--size] [--dns] <archivo-payload>
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
ADD_DNS=false
FILE_PROVIDED=false
INVALID_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --checksum) ADD_CHECKSUM=true; shift ;;
    --size) ADD_SIZE=true; shift ;;
    --dns) ADD_DNS=true; shift ;;
    --help|-h)
      echo "Uso: $0 [--checksum] [--size] [--dns] <archivo-payload>"
      echo "Opciones:"
      echo "  --checksum  agrega el checksum"
      echo "  --size      agrega el tamaño del archivo"
      echo "  --dns       genera cadenas en hexadecimal para uso en DNS"
      echo "Ejemplo:"
      echo "  $0 --checksum --size --dns payload.bin"
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
        INVALID_ARGS+=("$1")  # Si hay más de un archivo, se trata como argumento inválido
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
  echo "Uso: $0 [--checksum] [--size] [--dns] <archivo-payload>"
  exit 1
fi

#----------------------------------------------------------------------------------------------------------------
# 4. Verifica que al menos una opción haya sido seleccionada
#----------------------------------------------------------------------------------------------------------------
if ! $ADD_CHECKSUM && ! $ADD_SIZE && ! $ADD_DNS; then
  echo "ERROR: Debes especificar al menos una opción (--checksum, --size o --dns)."
  echo "Uso: $0 [--checksum] [--size] [--dns] <archivo-payload>"
  exit 1
fi

#----------------------------------------------------------------------------------------------------------------
# 5. Obtiene el tamaño en bytes del archivo original
#----------------------------------------------------------------------------------------------------------------
SIZE=$(stat -c%s "$LOCAL_FILE")

#----------------------------------------------------------------------------------------------------------------
# 6. Genera el nombre del nuevo archivo binario (cuando hay --checksum o --size)
#----------------------------------------------------------------------------------------------------------------
EXTENSION="-ext"
if $ADD_CHECKSUM || $ADD_SIZE; then
  EXTENSION+="-"
fi
if $ADD_CHECKSUM; then EXTENSION+="c"; fi
if $ADD_SIZE; then EXTENSION+="s"; fi

NEW_FILE="${LOCAL_FILE%.*}${EXTENSION}.${LOCAL_FILE##*.}"

#----------------------------------------------------------------------------------------------------------------
# 7. Genera el nombre del archivo para DNS (cuando hay --dns)
#----------------------------------------------------------------------------------------------------------------
if $ADD_DNS; then
  if $ADD_CHECKSUM || $ADD_SIZE; then
    DNS_FILE="${NEW_FILE%.*}-dns.txt"  # Basado en el archivo extendido
  else
    DNS_FILE="${LOCAL_FILE%.*}-dns.txt"  # Basado en el archivo original, sin "-ext"
  fi
fi

#----------------------------------------------------------------------------------------------------------------
# 8. Copia el archivo original si se va a modificar
#----------------------------------------------------------------------------------------------------------------
if $ADD_CHECKSUM || $ADD_SIZE; then
  cp "$LOCAL_FILE" "$NEW_FILE"
fi

#----------------------------------------------------------------------------------------------------------------
# 9. Calcula el checksum sumando todos los bytes del archivo original (si está habilitado)
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
# 10. Extrae los 3 bytes del tamaño en little endian (si está habilitado)
#----------------------------------------------------------------------------------------------------------------
if $ADD_SIZE; then
  B0=$(( SIZE        & 0xFF ))
  B1=$(( (SIZE >> 8) & 0xFF ))
  B2=$(( (SIZE >>16) & 0xFF ))

  # Agrega el tamaño (3 bytes)
  printf "%b" "\\x$(printf '%02x' "$B0")\\x$(printf '%02x' "$B1")\\x$(printf '%02x' "$B2")" >> "$NEW_FILE"
fi

#----------------------------------------------------------------------------------------------------------------
# 11. Mensaje de éxito según la acción realizada
#----------------------------------------------------------------------------------------------------------------
if $ADD_CHECKSUM || $ADD_SIZE; then
  echo -n "✓ Archivo '$NEW_FILE' generado correctamente. Se agregó información adicional"
  if $ADD_CHECKSUM && $ADD_SIZE; then
    echo " de checksum y tamaño."
  elif $ADD_CHECKSUM; then
    echo " de checksum."
  elif $ADD_SIZE; then
    echo " de tamaño."
  fi
fi

#----------------------------------------------------------------------------------------------------------------
# 12. Genera las cadenas hexadecimales para DNS si está habilitado
#----------------------------------------------------------------------------------------------------------------
if $ADD_DNS; then
  # Si se generó un archivo extendido con -c o -s, usar ese archivo para DNS, sino usar el archivo original
  DNS_INPUT_FILE="$LOCAL_FILE"
  if $ADD_CHECKSUM || $ADD_SIZE; then
    DNS_INPUT_FILE="$NEW_FILE"
  fi

  # Verifica si el archivo excede los 65535 bytes antes de generar el DNS
  FILE_SIZE=$(stat -c%s "$DNS_INPUT_FILE")
  if [ "$FILE_SIZE" -gt 65535 ]; then
    echo "x ERROR: No se generó el archivo DNS porque el tamaño del archivo ($FILE_SIZE bytes) excede el límite de 65535 bytes."
    exit 1
  fi

  # Genera el archivo DNS si el tamaño es válido
  hexdump -ve '1/1 "%02x"' "$DNS_INPUT_FILE" | fold -w254 | sed 's/.*/"&"/' | tr '\n' ' ' > "$DNS_FILE"
  echo "✓ Archivo '$DNS_FILE' generado correctamente para su uso en registros TXT de DNS."
fi
