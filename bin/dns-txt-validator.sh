#!/bin/bash

#================================================================================================================
# Archivo      : dns-txt-validator.sh
# Creado       : 07/03/2025
# Modificado   : 07/03/2025
# Autor        : Gastón M. González
# Plataforma   : Linux
# Arquitectura : x86-64
# Descripción  : Obtiene el contenido de un registro TXT de un dominio a través de servidores DNS públicos, 
#                eliminando comillas y espacios antes de calcular el hash MD5 del contenido. 
#                Utiliza el servidor de Google (8.8.8.8) para garantizar respuestas consistentes. 
#
# Configuración: Asegurarse de que el script tenga permisos de ejecución: 
#                chmod +x dns-txt-validator.sh
#
# Uso          : ./dns-txt-validator.sh <nombre-registro-TXT>.<dominio>
# Ejemplo      : ./dns-txt-validator.sh txt1.pithase.com.ar
# Salida       : ✓ MD5 del contenido TXT de txt1.pithase.com.ar: 5df04d1f985342baf47344cbc62fa18f
#================================================================================================================
# Licencia MIT:
# Este código es de uso libre bajo los términos de la Licencia MIT.
# Puedes usarlo, modificarlo y redistribuirlo, siempre que incluyas esta nota de atribución.
# NO HAY GARANTÍA DE NINGÚN TIPO, EXPRESA O IMPLÍCITA.
# Licencia completa en: https://github.com/Pithase/asm-payloads-loaders/blob/main/LICENSE
#================================================================================================================

#----------------------------------------------------------------------------------------------------------------
# 1. Verifica los argumentos
#----------------------------------------------------------------------------------------------------------------
if [ $# -ne 1 ] || [[ "$1" == "--help" ]]; then
  echo "Uso: $0 <nombre-registro-TXT>.<dominio>"
  echo "Ejemplo: $0 txt1.pithase.com.ar"
  exit 0
fi

DOMINIO="$1"

#----------------------------------------------------------------------------------------------------------------
# 2. Obtiene las cadenas del registro TXT usando los servidores 8.8.8.8, eliminando comillas y espacios
#----------------------------------------------------------------------------------------------------------------
TXT_DATA=$(dig +short TXT "$DOMINIO" @8.8.8.8 | tr -d ' "' | tr -d '\n')

#----------------------------------------------------------------------------------------------------------------
# 3. Verifica si se encontraron registros TXT
#----------------------------------------------------------------------------------------------------------------
if [ -z "$TXT_DATA" ]; then
  echo "x ERROR: No se encontraron registros TXT para $DOMINIO"
  exit 1
fi

#----------------------------------------------------------------------------------------------------------------
# 4. Calcula y muestra el MD5
#----------------------------------------------------------------------------------------------------------------
MD5_HASH=$(echo -n "$TXT_DATA" | md5sum | awk '{print $1}')
echo "✓ MD5 del contenido TXT de $DOMINIO: $MD5_HASH"
