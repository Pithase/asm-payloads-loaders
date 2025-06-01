## struct stat

En Ubuntu y otras distribuciones basadas en Debian, la estructura **`stat`** se declara en los encabezados de la biblioteca C (glibc). Las rutas relevantes son:

* `/usr/include/sys/stat.h` → Archivo principal de cabecera que incluye `bits/stat.h`.
* `/usr/include/x86_64-linux-gnu/bits/stat.h` → Implementación específica para x86-64 con la definición completa de `struct stat`.
* `/usr/include/x86_64-linux-gnu/bits/types.h` → Donde se definen mediante `typedef` los tipos subyacentes (`__dev_t`, `__ino_t`, `__mode_t`, etc.) usados en la estructura.
* `/usr/include/x86_64-linux-gnu/bits/typesizes.h` → Define las macros auxiliares utilizadas en `bits/types.h`.

Si analizamos el contenido de `/usr/include/sys/stat.h` observamos que incluye el archivo `#include <bits/stat.h>`. Luego, al examinar `/usr/include/x86_64-linux-gnu/bits/stat.h`, encontramos las declaraciones de los campos de la estructura junto a sus tipos.

La estructura resultante, una vez resueltas las directivas de preprocesamiento en C, y manteniendo únicamente las variables válidas para arquitecturas **x86-64** (definidas bajo `__x86_64__`), se presenta así:

```
struct stat {
    __dev_t st_dev;                         /* Device.  */
    __ino_t st_ino;                         /* File serial number.  */
    __nlink_t st_nlink;                     /* Link count.  */
    __mode_t st_mode;                       /* File mode.  */
    __uid_t st_uid;                         /* User ID of the file's owner. */
    __gid_t st_gid;                         /* Group ID of the file's group.*/
    int __pad0;
    __dev_t st_rdev;                        /* Device number, if device.  */
    __off_t st_size;                        /* Size of file, in bytes.  */
    __blksize_t st_blksize;                 /* Optimal block size for I/O.  */
    __blkcnt_t st_blocks;                   /* Number 512-byte blocks allocated. */
    __time_t st_atime;                      /* Time of last access.  */
    __syscall_ulong_t st_atimensec;         /* Nscecs of last access.  */
    __time_t st_mtime;                      /* Time of last modification.  */
    __syscall_ulong_t st_mtimensec;         /* Nsecs of last modification.  */
    __time_t st_ctime;                      /* Time of last status change.  */
    __syscall_ulong_t st_ctimensec;         /* Nsecs of last status change.  */
    __syscall_slong_t __glibc_reserved[3];
  };
```

Excepto por el campo `int __pad0`, el resto de los tipos de datos están definidos mediante `typedef`. Para identificar los tipos básicos y poder calcular offsets y alineaciones, es necesario desentrañar la cadena de macros y definiciones. Este proceso no es inmediato, ya que las asignaciones no son directas, sino que se propagan a través de múltiples archivos. A grandes rasgos, el flujo de resolución es:

1. **`/usr/include/x86_64-linux-gnu/bits/types.h`**

Buscar definiciones de tipo:

`$ grep __dev_t /usr/include/x86_64-linux-gnu/bits/types.h`

```
__STD_TYPE __DEV_T_TYPE __dev_t;        /* Type of device numbers.  */
```

2. **`/usr/include/x86_64-linux-gnu/bits/typesizes.h`**

Buscar el valor de la macro `__DEV_T_TYPE`:

`$ grep __DEV_T_TYPE /usr/include/x86_64-linux-gnu/bits/typesizes.h`

```
#define __DEV_T_TYPE            __UQUAD_TYPE
```

3. Volver a **`bits/types.h`** para resolver **`__UQUAD_TYPE`**

`$ grep __UQUAD_TYPE /usr/include/x86_64-linux-gnu/bits/types.h`

```
# define __UQUAD_TYPE           __uint64_t
# define __UQUAD_TYPE           unsigned long int
```

Finalmente, deducimos que el campo **`st_dev`** es de tipo **`unsigned long int`**, por lo tanto, ocupa **8 bytes** en la arquitectura x86-64.

Este mismo procedimiento debe repetirse para cada campo de la estructura `stat`, para así conocer con precisión los tamaños, alineaciones y offsets de cada miembro.

El resultado de aplicar el proceso es el siguiente:

```
struct stat {
    __dev_t st_dev;                        /* [ 8 bytes] [offset  0 ] Dispositivo. */
    __ino_t st_ino;                        /* [ 8 bytes] [offset  8 ] Número de inodo. */
    __nlink_t st_nlink;                    /* [ 8 bytes] [offset  16] Cantidad de enlaces. */
    __mode_t st_mode;                      /* [ 4 bytes] [offset  24] Modo de archivo. */
    __uid_t st_uid;                        /* [ 4 bytes] [offset  28] UID del propietario. */
    __gid_t st_gid;                        /* [ 4 bytes] [offset  32] GID del grupo. */
    int __pad0;                            /* [ 4 bytes] [offset  36] Relleno para alinear al siguiente campo de 8. */
    __dev_t st_rdev;                       /* [ 8 bytes] [offset  40] Número de dispositivo (si corresponde). */
    __off_t st_size;                       /* [ 8 bytes] [offset  48] Tamaño en bytes. */
    __blksize_t st_blksize;                /* [ 8 bytes] [offset  56] Tamaño óptimo de bloque para I/O. */
    __blkcnt_t st_blocks;                  /* [ 8 bytes] [offset  64] Cantidad de bloques de 512 bytes asignados. */
    __time_t st_atime;                     /* [ 8 bytes] [offset  72] Fecha de último acceso. */
    __syscall_ulong_t st_atimensec;        /* [ 8 bytes] [offset  80] Nanosegundos del último acceso. */
    __time_t st_mtime;                     /* [ 8 bytes] [offset  88] Fecha de última modificación. */
    __syscall_ulong_t st_mtimensec;        /* [ 8 bytes] [offset  96] Nanosegundos de última modificación. */
    __time_t st_ctime;                     /* [ 8 bytes] [offset 104] Fecha de último cambio de estado. */
    __syscall_ulong_t st_ctimensec;        /* [ 8 bytes] [offset 112] Nanosegundos del último cambio de estado. */
    __syscall_slong_t __glibc_reserved[3]; /* [24 bytes] [offset 120] Reservado para uso futuro */
  };
```

El tamaño total de la estructura es de **144 bytes** y está **alineado a 8 bytes**, de acuerdo con las convenciones de la ABI x86-64 en Linux.
