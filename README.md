# Chill

Herramienta de terminal en Swift para explorar métricas del sistema en macOS. Es un proyecto personal en desarrollo; la compatibilidad entre modelos de Mac y la exactitud de sus lecturas todavía necesitan validación.

## Qué contiene

El código implementa un panel con CPU, memoria, procesos, batería, red y sensores térmicos disponibles. Usa APIs Mach, comandos de macOS (`ps`, `ioreg`, `netstat`) y funciones privadas de IOHID para sensores. No controla los ventiladores.

## Requisitos y ejecución local

- macOS: los fuentes importan `Darwin` y `IOKit`; no es una aplicación multiplataforma.
- Un toolchain que admita `swift-tools-version: 6.4`, según `Package.swift`. Comprobarlo con `swift --version`.
- Terminal con soporte ANSI y entrada interactiva.

```sh
git clone https://github.com/Barbafebles/chill.git
cd chill
swift build -c release
.build/release/chill
```

Alternativa para desarrollo: `swift run chill`. Estos comandos describen el flujo de Swift Package Manager; no se han ejecutado en macOS durante esta auditoría.

## Controles implementados

| Tecla | Acción |
| --- | --- |
| Q / X | Salir y restaurar la terminal |
| P | Cambiar orden de procesos por CPU o memoria |
| + | Aumentar el intervalo de actualización (actualiza menos frecuentemente) |
| - | Reducir el intervalo de actualización |
| S | Activar una carga de CPU de unos 3 segundos |

La opción S genera carga deliberadamente y bloquea temporalmente el panel. Su implementación concurrente necesita revisión antes de considerarla validada.

## Estructura

| Ruta | Responsabilidad |
| --- | --- |
| `Package.swift` | Configuración de Swift Package Manager |
| `Sources/chill/main.swift` | Panel, teclado y terminal |
| `Sources/chill/SystemMetrics.swift` | Métricas y consulta de procesos |
| `Sources/chill/SMCBridge.swift` | Acceso experimental a sensores mediante IOHID |
| `Tests/chillTests/` | Plantilla de test, todavía sin aserciones |
| `.github/workflows/release.yml` | Compilación y publicación al crear tags `v*` |
| `Formula/chill.rb` / `install.sh` | Instaladores pendientes de validación |

## Limitaciones conocidas

- La auditoría del 11 de octubre de 2026 se hizo en Linux sin Swift: no se verificaron compilación, interfaz ni sensores reales. Apple Silicon e Intel no constituyen una matriz de compatibilidad comprobada.
- Las APIs privadas de sensores pueden cambiar o no devolver datos. El nombre `SMCBridge` no demuestra una implementación completa del protocolo AppleSMC.
- El indicador de margen térmico calcula `100 - temperatura máxima`; no mide el umbral real de throttling de cada equipo.
- Si falla la consulta de batería, el código puede mostrar valores de respaldo de 100%. No deben interpretarse como una medición válida.
- La resta de contadores de red sin comprobar si disminuyen puede desbordar cuando una interfaz se reinicia.
- La variable compartida del test de carga no tiene sincronización; `@unchecked Sendable` no resuelve ese problema.
- `swift test` ejecutaría actualmente una plantilla sin comprobaciones. No existe un workflow de tests para cada pull request.
- La fórmula Homebrew usa un requisito de Xcode que no garantiza el toolchain declarado y llama a `--help`, aunque el programa no implementa esa opción.
- `install.sh` puede usar `sudo`, descarga la última release y no verifica su checksum. Su instalación y la arquitectura del binario no se han validado. Se recomienda revisar estos archivos antes de utilizarlos.

## Licencia

[MIT](./LICENSE).

La ejecución de release [v1.0.0](https://github.com/Barbafebles/chill/actions/runs/32719420108) falló: el paquete solicita Swift 6.4.0 y el runner tenía 6.3.3. La publicación de esa ejecución se omitió.
