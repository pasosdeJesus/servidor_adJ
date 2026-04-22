# Plan de mejora de la documentación de adJ

Este documento resume las acciones propuestas para actualizar y completar los tres manuales de la distribución Aprendiendo de Jesús (adJ):

- `basico_adJ` – uso básico del sistema (para usuarios principiantes o que usan una máquina administrada por terceros)
- `usuario_adJ` – uso como sistema de escritorio y entorno de desarrollo
- `servidor_adJ` – administración de servidores y servicios de red

Las prioridades se clasifican como **Alta**, **Media** o **Baja**.

---

## 1. `basico_adJ.md` (usuario principiante o con acceso limitado)

| Tema | Prioridad | Acción |
| :--- | :--- | :--- |
| Determinar versión actual y novedades | **Alta** | Añadir al final del documento una sección breve que explique cómo obtener la versión del sistema (`uname -a`) y dónde consultar los cambios importantes (enlace a la sección de novedades del mismo documento). |
| Respaldo básico de archivos personales | **Media** | Agregar una sección que muestre cómo copiar archivos a una memoria USB usando `cp -r` o `tar czf respaldo.tgz /home/usuario`. |
| Solución de problemas comunes | **Existente** | La sección actual es suficiente; no se requiere añadir gestión de energía ni actualización del sistema. |

> **Nota:** En `basico_adJ` no se documenta `ispell` (no está presente en esa guía) ni se usa `sysmerge` en adJ.

---

## 2. `usuario_adJ.md` (usuario de escritorio y desarrollador)

### Prioridad Alta

| Tema | Acción |
| :--- | :--- |
| **Gestión de energía** (nuevo en adJ 7.8) | Añadir una sección completa que cubra: activación de `apmd`, suspensión (`zzz`), hibernación (`Zzz`), configuración con `sysctl hw.apm`, manejo del botón de encendido, etc. |

### Prioridad Media

| Tema | Acción |
| :--- | :--- |
| **Actualización del sistema** | Integrar el contenido del archivo `Actualiza.md` (o el procedimiento equivalente) en este manual: uso de `rsync-adJ`, scripts `preact-adJ.sh`, `actbase.sh`, ejecución de `/inst-adJ.sh`, y cómo recuperarse en caso de fallo. No se emplea `sysmerge`. |
| **Migración de Ruby a Next.js** | A medida que se desarrollen los paquetes correspondientes, documentar la instalación de Node.js, npm/yarn, creación de un proyecto Next.js básico y su integración con blockchains (CELO). Puede formar un subcapítulo dentro de "Ambiente de Desarrollo". |
| **Monitoreo básico del sistema** | Añadir herramientas como `htop`, `vmstat 1`, `iostat`, `systat`, `sensorsd` (temperatura), `smartctl` (estado de discos). |
| **Ajuste de rendimiento (tuning)** | Explicar modificaciones en `login.conf` (límites de recursos), `sysctl.conf` (ej. `kern.maxfiles`, `net.inet.tcp.sack`) y `rc.conf.local`. |
| **Virtualización con `vmm`** | Crear y administrar máquinas virtuales con `vmctl`, útil para desarrolladores que necesiten probar otros sistemas operativos. |
| **Copias de respaldo automatizadas** | Scripts programados con `cron` que utilicen `rsync` hacia discos externos o remotos, incluyendo volcados de bases de datos (PostgreSQL, MariaDB). |
| **Solución de problemas comunes en el escritorio** | Incluir una sección con 5‑10 problemas típicos: X no arranca, teclado sin `ñ`, USB no se monta, conflictos entre paquetes, errores de permisos, etc. |

### Prioridad Baja

| Tema | Acción |
| :--- | :--- |
| **Accesibilidad** | Solo se abordará si hay pruebas reales y demanda; de momento no es prioritario. |

---

## 3. `servidor_adJ.md` (administrador de servidores)

### Prioridad Alta

| Tema | Acción |
| :--- | :--- |
| **Solución de problemas comunes en servidor** | Crear una sección que aborde: `pf` bloquea todo (cómo desactivar temporalmente), correo no entregado (Gmail, puertos), fallos en resolución DNS, certificados SSL caducados, base de datos que no arranca, etc. |
| **Monitoreo de servidor** | Documentar el uso de `snmpd`, `collectd`, `prometheus` (nivel básico), alertas por correo e integración con `pkg_add telegraf`. |
| **Jaulas (`chroot`) y restricciones (`unveil`/`pledge`)** | Ejemplos prácticos de cómo confinar un servicio con `chroot` y cómo emplear `pledge` en scripts para reducir privilegios. |

### Prioridad Media

| Tema | Acción |
| :--- | :--- |
| **Renovación automática de Let's Encrypt** | Añadir una tarea programada en `cron` para ejecutar `letsencrypt renew` y recargar los servicios afectados (nginx, httpd, smtpd). |
| **NFS (servidor y cliente)** | Explicar cómo exportar directorios, opciones de seguridad y montaje automático en el cliente. |
| **Seguridad adicional** | Incluir: verificación de paquetes con `signify`, deshabilitar servicios innecesarios (`rcctl disable`), uso de `fail2ban` o scripts propios, y opciones de seguridad en `sysctl.conf`. |
| **Replicación PostgreSQL maestro/esclavo** | Aunque es una configuración avanzada, documentar los pasos que han resultado funcionales (por ejemplo con `repmgr` o configuración manual). |
| **IPv6 progresivo** | Describir la asignación de direcciones estáticas, enrutamiento, reglas de `pf` y resolución de nombres (unbound/nsd) con IPv6, incluyendo pruebas básicas. |

### Prioridad Baja o descartar

| Tema | Acción |
| :--- | :--- |
| **CARP / relayd** | Solo se mencionará como opción avanzada si se dispone de experiencia estable; por ahora no se profundiza. |

---

## 4. Observaciones generales

- Los tres manuales mantendrán su estilo actual (dominio público, referencias espirituales, ejemplos prácticos).
- No se emplea `sysmerge` en adJ; los procedimientos de actualización usan los scripts propios de la distribución.
- La sección de “Convertirse en desarrollador de adJ” (empaquetado, uso del repositorio, construcción de imágenes, envío de parches) se añadirá en un futuro como un capítulo independiente dentro de `usuario_adJ.md`.
- A medida que surjan nuevos paquetes (Next.js, integración con blockchains como CELO) se actualizará la documentación correspondiente.

---

*Última revisión: abril de 2026*
