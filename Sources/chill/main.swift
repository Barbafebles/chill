import Foundation

@MainActor
struct ChillApp {
    private static func clearScreen() {
        print("\u{001B}[2J\u{001B}[H")
    }

    private static func printBanner() {
        print("""
        \u{001B}[36m
           _____ _    _ _____ _      _      
          / ____| |  | |_   _| |    | |     
         | |    | |__| | | | | |    | |     
         | |    |  __  | | | | |    | |     
         | |____| |  | |_| |_| |____| |____ 
          \\_____|_|  |_|_____|______|______|
        \u{001B}[0m
        ❄️  \u{001B}[1mCHILL - macOS Thermal & Hardware Monitor\u{001B}[0m
        ─────────────────────────────────────────────
        """)
    }

    static func start() {
        let args = Array(CommandLine.arguments.dropFirst())

        if let firstArg = args.first {
            switch firstArg {
            case "-s", "--status":
                displaySnapshot()
                return
            case "-m", "--monitor":
                liveMonitor()
                return
            case "-h", "--help":
                printHelp()
                return
            default:
                break
            }
        }

        interactiveMenu()
    }

    private static func printHelp() {
        printBanner()
        print("""
        Uso:
          chill [opción]

        Opciones:
          -s, --status    Muestra el estado térmico actual y sale
          -m, --monitor   Inicia el panel continuo en tiempo real
          -h, --help      Muestra esta ayuda

        Sin argumentos inicia el menú interactivo.
        """)
    }

    private static func displaySnapshot() {
        printBanner()
        let sensors = SMCBridge.shared.getThermalSensors()
        let fans = SMCBridge.shared.getFanSpeed()
        let avgTemp = sensors.isEmpty ? 0.0 : (sensors.map(\.temperature).reduce(0, +) / Double(sensors.count))
        let maxTemp = sensors.map(\.temperature).max() ?? 0.0

        print("🌡️  TEMPERATURAS")
        print(" • Media del SoC:  \u{001B}[32m\(String(format: "%.1f", avgTemp)) °C\u{001B}[0m")
        print(" • Pico máximo:    \u{001B}[33m\(String(format: "%.1f", maxTemp)) °C\u{001B}[0m")
        print("─────────────────────────────────────────────")
        print("🌀 VENTILADORES")
        if fans.isEmpty {
            print(" • 0 RPM (Modo Pasivo / Silencioso de macOS)")
        } else {
            for fan in fans {
                print(" • Ventilador #\(fan.id): \(fan.currentRPM) RPM")
            }
        }
        print("─────────────────────────────────────────────\n")
    }

    private static func interactiveMenu() {
        while true {
            clearScreen()
            printBanner()
            print("""
            \u{001B}[1m[ MENÚ PRINCIPAL ]\u{001B}[0m

            1.  Ver Estado Térmico y Sensores
            2.  Monitor Continuo en Tiempo Real
            3.  Test de Respuesta Térmica (Carga de CPU)
            4.  Acerca de Chill
            0.  Salir

            """)
            print(" Selecciona una opción [0-4]: ", terminator: "")

            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }

            switch input {
            case "1":
                showDetailedTelemetry()
            case "2":
                liveMonitor()
            case "3":
                runStressTest()
            case "4":
                aboutMenu()
            case "0":
                clearScreen()
                print("👋 ¡Hasta luego! Mantén tu Mac fresco ❄️\n")
                exit(0)
            default:
                print("\n❌ Opción no válida. Presiona Enter para continuar...")
                _ = readLine()
            }
        }
    }

    private static func showDetailedTelemetry() {
        while true {
            clearScreen()
            printBanner()

            let sensors = SMCBridge.shared.getThermalSensors()
            let fans = SMCBridge.shared.getFanSpeed()
            let avgTemp = sensors.isEmpty ? 0.0 : (sensors.map(\.temperature).reduce(0, +) / Double(sensors.count))
            let maxTemp = sensors.map(\.temperature).max() ?? 0.0

            print("""
            \u{001B}[1m[ 🌀 TELEMETRÍA DEL SISTEMA ]\u{001B}[0m

            🌡️  Temperatura Media SoC: \u{001B}[32m\(String(format: "%.1f", avgTemp)) °C\u{001B}[0m | Pico Máx: \u{001B}[33m\(String(format: "%.1f", maxTemp)) °C\u{001B}[0m
            """)

            if fans.isEmpty {
                print(" 🌀 Ventiladores: \u{001B}[34m0 RPM (Modo Pasivo / Silencioso)\u{001B}[0m")
            } else {
                for fan in fans {
                    print(" 🌀 Ventilador #\(fan.id): \u{001B}[32m\(fan.currentRPM) RPM\u{001B}[0m")
                }
            }

            print("""
            ─────────────────────────────────────────────
            SENSORES ACTIVOS (HID):
            """)
            for (idx, s) in sensors.prefix(8).enumerated() {
                print(" [\(idx + 1)] \(s.name.padding(toLength: 18, withPad: " ", startingAt: 0)): \(String(format: "%.1f", s.temperature)) °C")
            }

            print("""
            ─────────────────────────────────────────────
            1.  Actualizar datos
            0.  Volver al menú principal

            """)
            print(" Selecciona una opción [0-1]: ", terminator: "")

            guard let choice = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
            if choice == "1" { continue }
            if choice == "0" { return }
        }
    }

    private static func liveMonitor() {
        clearScreen()
        print("❄️  Iniciando monitor en tiempo real (Presiona Ctrl+C para volver)...\n")
        Thread.sleep(forTimeInterval: 0.8)

        while true {
            clearScreen()
            printBanner()
            let sensors = SMCBridge.shared.getThermalSensors()
            let fans = SMCBridge.shared.getFanSpeed()
            let avgTemp = sensors.isEmpty ? 0.0 : (sensors.map(\.temperature).reduce(0, +) / Double(sensors.count))
            let maxTemp = sensors.map(\.temperature).max() ?? 0.0

            print("🌡️  Media SoC: \u{001B}[32m\(String(format: "%.1f", avgTemp)) °C\u{001B}[0m | Pico: \u{001B}[33m\(String(format: "%.1f", maxTemp)) °C\u{001B}[0m")

            if fans.isEmpty {
                print("🌀 Ventiladores: \u{001B}[34m0 RPM (Silencioso)\u{001B}[0m\n")
            } else {
                let fanList = fans.map { "#\($0.id): \($0.currentRPM) RPM" }.joined(separator: " | ")
                print("🌀 Ventiladores: \u{001B}[32m\(fanList)\u{001B}[0m\n")
            }

            print("Sensores activos:")
            for (idx, s) in sensors.prefix(8).enumerated() {
                print(" [\(idx + 1)] \(s.name.padding(toLength: 18, withPad: " ", startingAt: 0)): \(String(format: "%.1f", s.temperature)) °C")
            }
            print("\nRefresco cada 2 segundos... (Ctrl+C para salir)")
            Thread.sleep(forTimeInterval: 2.0)
        }
    }

    private static func runStressTest() {
        clearScreen()
        printBanner()
        print("""
        \u{001B}[1m[ 🔥 TEST DE RESPUESTA TÉRMICA ]\u{001B}[0m

        Carga controlada de CPU durante 10 segundos para observar cómo 
        sube la temperatura en tus sensores en tiempo real.

        Presiona Enter para iniciar (o '0' para cancelar)...
        """)
        if let input = readLine(), input.trimmingCharacters(in: .whitespacesAndNewlines) == "0" {
            return
        }

        print("\n🔥 Ejecutando cálculo multinúcleo...")
        var isRunning = true
        let group = DispatchGroup()
        let cores = ProcessInfo.processInfo.activeProcessorCount

        for _ in 0..<cores {
            group.enter()
            DispatchQueue.global(qos: .userInteractive).async {
                while isRunning {
                    _ = (0..<1000).reduce(0, +)
                }
                group.leave()
            }
        }

        for sec in (1...10).reversed() {
            let sensors = SMCBridge.shared.getThermalSensors()
            let avgTemp = sensors.isEmpty ? 0.0 : (sensors.map(\.temperature).reduce(0, +) / Double(sensors.count))
            print(" ⏱️  Tiempo restante: \(sec)s | Temperatura SoC: \u{001B}[33m\(String(format: "%.1f", avgTemp)) °C\u{001B}[0m")
            Thread.sleep(forTimeInterval: 1.0)
        }

        isRunning = false
        group.wait()

        print("\n✅ Prueba terminada. Presiona Enter para volver...")
        _ = readLine()
    }

    private static func aboutMenu() {
        clearScreen()
        printBanner()
        print("""
        \u{001B}[1m[ ACERCA DE CHILL ]\u{001B}[0m

        • Versión:     1.0.0 (Open Source)
        • Plataforma:  macOS (Apple Silicon & Intel)
        • Telemetría:  IOHIDEventSystem Native Client

        Presiona Enter para volver al menú principal...
        """)
        _ = readLine()
    }
}

ChillApp.start()