# 🚀 Serie: Cargadores de Payloads - #Assembly #Picante

Desarrollo paso a paso de cargadores de payloads, escritos exclusivamente en **Ensamblador x86-64 para Linux**, sin dependencias externas y utilizando sólo **syscalls nativas**.

📌 **Objetivo:**  
Una vez avanzada la serie, publicaré en forma detallada el paso a paso para poder desarrollar cada uno de los ejemplos, aportando toda la documentación y explicaciones necesarias para que lo comprendas **de punta a punta** y no te quede absolutamente ninguna duda.

💬 **¿Dudas, sugerencias o correcciones?**  
Escribime a: ✉️ `repo-asm-payloads-loaders@pithase.com.ar`

---

## 📂 **Ejemplos de Payloads**

### 🟢 **1️⃣ Payloads para Ejemplo**

| 🔗 Archivo | 📏 Tamaño |
|------------|---------:|
| [`payload.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload.asm) | 49 bytes |
| [`payload4KBlarger.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload4KBlarger.asm) | 5.088 bytes |

📎 **[Links de los archivos binarios](https://github.com/Pithase/asm-payloads-loaders/tree/main/bin)**  

---

### 🟠 **2️⃣ Cargadores de Payload desde Archivos**
Cargadores que leen un payload desde un archivo en disco.

| 🔗 Archivo | 📄 Descripción |
|------------|---------------|
| [`payload-read-file-short.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-file-short.asm) | Carga de un payload de un archivo **<= 4KB** |
| [`payload-read-file.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-file.asm) | Carga un payload desde archivo con **reserva de memoria dinámica** según su tamaño |
| [`payload-read-arg-file.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-arg-file.asm) | Permite especificar el **archivo como argumento** , lee su tamaño y **asigna memoria dinámica** según corresponda |

---

### 🟡 **3️⃣ Cargadores de Payload desde HTTP (No HTTPS)**
Cargadores que obtienen el payload desde una URL HTTP.

| 🔗 Archivo | 📄 Descripción |
|------------|---------------|
| [`payload-read-http-file-size-fixed.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-http-file-size-fixed.asm) | Carga un payload **<= 4KB** con un tamaño predefinido en el código |
| [`payload-read-http-file-size-fixed-checksum.asm`](https://github.com/Pithase/asm-payloads-loaders/blob/main/payload-read-http-file-size-fixed-checksum.asm) | Carga un payload **<= 4KB** con un tamaño y checksum predefinidos en el código, **verificando el checksum** antes de ejecutar el payload |

--- 
