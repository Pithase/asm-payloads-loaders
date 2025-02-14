# 📌 Verificación y Descarga de Payloads

Este documento proporciona los **enlaces de descarga** de los payloads y el procedimiento detallado para verificar su integridad mediante **MD5**, asegurando que corresponden al código fuente publicado.

---

## 📌 **Pasos para verificar un payload**

Para utilizar los links con **confianza** y asegurarte de que el payload descargado es auténtico, sigue estos pasos:

### 🔹 **1️⃣ Descargar el payload**
Descarga el archivo binario desde el enlace proporcionado.

### 🔹 **2️⃣ Verificar el MD5 del archivo descargado**
Ejecuta el siguiente comando para calcular su **hash MD5**:
```sh
md5sum <nombre_payload_descargado>
```
✅ **Compara el resultado** con el MD5 publicado en este documento.  
📌 **Si los MD5 no coinciden, NO uses el payload. Vuelve a descargarlo.**

### 🔹 **3️⃣ Compilar el payload**
Compila el payload a partir del código fuente.

### 🔹 **4️⃣ Verificar el MD5 según el tipo de payload**
Dependiendo del tipo de payload, sigue el procedimiento correspondiente:

#### 🔹 **Para Payloads Estándar** (sin modificaciones):
- Calcula el MD5 del archivo compilado:
  ```sh
  md5sum <nombre_payload_compilado>
  ```
- **Compara** el resultado con el MD5 publicado. ✅ **Deben ser idénticos**.

#### 🔹 **Para Payloads Extendidos** (`payloadextend.sh` aplicado):
- Ejecuta el script `payloadextend.sh` para extender el payload:
  ```sh
  ./payloadextend.sh <nombre_payload_compilado>
  ```
- Calcula el MD5 del archivo **generado**:
  ```sh
  md5sum <nombre_payload_generado>
  ```
- **Compara** el resultado con el MD5 publicado. ✅ **Deben ser idénticos**.

---

## 📌 **Listado de Payloads**

### 🟢 **1️⃣ Payloads Estándar**  
Estos son los archivos originales antes de aplicar `payloadextend.sh`.

| 🔗 Link | 🔑 MD5 | 📏 Tamaño |
|------------------------------------------|----------------------------------|----------|
| `http://pithase.com.ar/bin/payload.bin` | `badde3c53e0cf86c52fffa1ea41ef27` | 49 bytes |
| `http://pithase.com.ar/bin/payload4KBlarger.bin` | `d20d72a7d7c05ed70d58aceec8031f29` | 5.088 bytes |

### 🟠 **2️⃣ Payloads Extendidos (`payloadextend.sh` aplicado)**  
Estos archivos han sido modificados con metadatos adicionales.

| 🔗 Link | 🔑 MD5 | 📏 Tamaño |
|------------------------------------------|----------------------------------|----------|
| `http://pithase.com.ar/bin/payload-ext.bin` | `a845f257af8b9145ef61b17d2fb64db6` | 55 bytes |
| `http://pithase.com.ar/bin/payload4KBlarger-ext.bin` | `7ef1ec1edd3c9080d6a7118afbbaf429` | 5.094 bytes |

---
