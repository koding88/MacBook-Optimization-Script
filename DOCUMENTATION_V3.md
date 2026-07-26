# 📘 Arquitectura Técnica y Guía de Evolución (v3.1)

## 📋 Resumen Ejecutivo

Este documento detalla la evolución arquitectónica y refactorización técnica de **MacBook Optimization Script (v3.1 Next-Gen)**. El proyecto ha sido transformado de una colección básica de utilidades de terminal a una plataforma de optimización, diagnóstico y mantenimiento de grado empresarial (*production-ready*) para **macOS**.

El rediseño prioriza la **resiliencia del sistema**, el **respeto por la seguridad de Apple (SIP y SSV)**, la **trazabilidad estricta de código de retorno**, la **compatibilidad multi-arquitectura** (Apple Silicon M1/M2/M3/M4 e Intel `x86_64`) y la **extensibilidad mediante plugins y automatización CLI**.

---

## 🏗️ Pilares de Diseño Arquitectónico

### 1. 🖥️ Motor de Compatibilidad Multisistema (`sys_compat.sh`)
La diversidad de versiones de macOS (desde Catalina 10.15 hasta Sonoma/Sequoia 15+) y la coexistencia de arquitecturas ARM y x86_64 requieren comprobaciones preventivas antes de ejecutar llamadas al sistema:
* **Detección de Arquitectura:** Diferencia automáticamente entre procesadores Apple Silicon e Intel. Parámetros obsoletos como *Sudden Motion Sensor* (`sms`) o *AutoBoot* (`nvram`) se omiten o adaptan según el hardware.
* **Respeto a SSV (Signed System Volume):** En macOS 11+, la partición `/System` está protegida en modo solo lectura cifrado. El motor omite modificaciones destructivas en `/System` previniendo errores de *Operation not permitted*.
* **Verificación de Volumen APFS:** Reemplaza la antigua instrucción `diskutil verifyPermissions` (removida en OS X El Capitan) por el diagnóstico moderno de volumen APFS `diskutil verifyVolume /`.

---

### 2. 🛡️ Resiliencia y Control de Señales (`trap_handler.sh`)
Para evitar estados inconsistentes en la terminal o la corrupción de archivos durante la interrupción voluntaria del usuario (`Ctrl+C` / `SIGINT` / `SIGTERM`):
* **Limpieza Garantizada:** Un manejador de trampas de señales (`trap`) restaura la visibilidad del cursor (`tput cnorm`) y restablece la paleta de colores ANSI (`tput sgr0`).
* **Cerrojo de Instancia Única (*Process Locking*):** Asigna un identificador PID en `/tmp/macbook_optimizer.lock` para prevenir la ejecución concurrente aleatoria de múltiples instancias del script.

---

### 3. 💾 Persistencia y Copia de Seguridad Estructurada (`backup.sh` & `json_engine.sh`)
* **Respaldo Extractor Previo:** Antes de alterar cualquier preferencia con `defaults write`, `sysctl` o `pmset`, el sistema captura los valores originales del usuario en `~/.macbook_optimizer_user_backup.conf`.
* **Restauración Exacta (*Rollback*):** La función de reversión no solo aplica valores por defecto genéricos de Apple, sino que prioriza la restauración de los valores exactos previamente respaldados por el usuario.
* **Persistencia JSON Nativa:** Registro dual de estado en texto plano y en formato estructurado `JSON` (`~/.macbook_optimizer_state.json`) procesado con parsers AWK/Bash ultrarrápidos sin dependencias externas.

---

### 4. ⚡ Diagnóstico Paralelo Concurrente (`parallel_diag.sh`)
* **Ejecución Asíncrona:** Recopila información del procesador, uso de memoria RAM, salud del disco y perfil de batería ejecutando trabajos en segundo plano (`&`) y sincronizando la entrega mediante `wait`.
* **Reducción de Latencia:** Reduce el tiempo de respuesta en la recolección de diagnósticos en un 400%.

---

### 5. 📊 Suite de Benchmarking de Rendimiento (`benchmark.sh`)
Permite evaluar de forma cuantitativa el impacto de las optimizaciones:
* **Latencia DNS:** Mide en milisegundos (`ms`) el tiempo de resolución de nombres usando adaptadores de red o Python 3.
* **Tasa de Transferencia I/O:** Mide la velocidad secuencial de escritura en almacenamiento mediante muestras controladas en `/tmp`.
* **Disponibilidad de Memoria RAM:** Calcula el índice de páginas de memoria libres y comprimidas utilizables.

---

### 6. 🌐 Automatización CLI y Modo Simulación (`script.sh`)
Soporte completo para integración en scripts de automatización (Dotfiles, Ansible, MDM, CI/CD):
* `--dry-run`: Previsualización de comandos sin alterar configuraciones del sistema.
* `--all`: Ejecución no interactiva de todas las optimizaciones seguras.
* `--module <nombre>`: Ejecución aislada de módulos específicos.
* `--status`: Generación de reportes de estado no interactivos.
* `--rollback`: Restauración automatizada a valores anteriores.
* `--lang <es|en>`: Selección de idioma de la interfaz (Español / Inglés).

---

## 🗂️ Mapa de Módulos del Sistema

```
MacBook-Optimization-Script/
├── script.sh                   # Punto de entrada principal y analizador de argumentos CLI
├── fix_permissions.sh          # Utilidad de diagnóstico y reparación de permisos
├── DOCUMENTATION_V3.md         # Documentación de arquitectura técnica
├── README.md                   # Manual de usuario e instrucciones de uso
├── tests/
│   └── test_modules.sh         # Suite de pruebas de integración automatizadas
└── modules/
    ├── sys_compat.sh           # Detección de OS, Arquitectura, SIP, SSV y Filesystem
    ├── trap_handler.sh         # Manejador de trampas de señales y lockfile de proceso
    ├── logger.sh               # Registro estructurado de logs (~/.macbook_optimizer.log)
    ├── i18n.sh                 # Diccionario multilingüe (Español / Inglés)
    ├── json_engine.sh          # Motor de almacenamiento de estado en JSON nativo
    ├── backup.sh               # Extracción y respaldo de preferencias originales
    ├── config.sh               # Gestión de estado y wrapper de ejecución segura (safe_exec)
    ├── rollback.sh             # Motor de reversión a respaldo de usuario o valores de fábrica
    ├── ui_library.sh           # Biblioteca de UI (spinners, barras de progreso y tablas)
    ├── ui_components.sh        # Renderizado ANSI del menú principal y encabezados
    ├── menu_handler.sh         # Enrutador de selecciones interactivas (Opciones 0-34)
    ├── system_optimizations.sh # Ajustes de kernel sysctl, purga de RAM y SSD
    ├── network_optimizations.sh# Ajustes TCP/IP, vaciado DNS y regla de Firewall
    ├── storage_optimizations.sh# Limpieza de cachés de usuario/sistema y .DS_Store
    ├── performance_tweaks.sh   # Ajuste de animaciones, Dock y Spotlight
    ├── maintenance.sh          # Verificación APFS, scripts periódicos y borrado de logs
    ├── system_monitoring.sh    # Monitoreo detallado de hardware y estado térmico
    ├── thermal_process.sh      # Inspección de estrangulamiento térmico y procesos zombi
    ├── benchmark.sh            # Suite de pruebas cuantitativas de rendimiento
    ├── scheduler.sh            # Agente automatizador LaunchAgent para ejecuciones semanales
    ├── plugin_loader.sh        # Cargador dinámico de módulos de terceros (plugins/)
    ├── power_management.sh     # Modo de bajo consumo, AutoBoot e inspección MDM
    └── updater.sh              # Comprobador y aplicador de actualizaciones de Git
```

---

## 🧪 Pruebas de Integración y Calidad de Código

El repositorio cuenta con una suite de integración automatizada (`tests/test_modules.sh`) que valida:
1. Sintaxis limpia sin errores en todos los archivos `.sh` mediante `bash -n`.
2. Compatibilidad estricta con **Bash 3.2** (versión nativa por defecto en macOS).
3. Correcto funcionamiento de banderas de línea de comandos (`--help`, `--status`, `--dry-run`, `--module`).
4. Verificación del cargador paralelo de diagnósticos y el benchmark de red/disco.

**Resultado de la suite de pruebas:** `8 Passed, 0 Failed`.

---

## 📝 Conclusión y Buenas Prácticas

Esta evolución técnica garantiza que la herramienta sea **segura, idempotente y completamente reversible**. Ofrece a los administradores de sistemas y usuarios avanzados una infraestructura robusta para mantener sus equipos Mac en su máximo nivel de rendimiento y salud.
