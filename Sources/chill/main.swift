import Foundation
import Darwin
import Dispatch

final class StressState: @unchecked Sendable {
    var isRunning = true
}

@MainActor
struct ChillDashboard {
    private static var running = true
    private static var cpuHistory: [Double] = Array(repeating: 0.0, count: 18)
    private static var originalTermios = termios()
    private static var refreshInterval: Double = 1.5
    private static var sortMode: ProcessSortMode = .cpu
    private static var sigintSource: DispatchSourceSignal?

    private static func enableRawMode() {
        tcgetattr(STDIN_FILENO, &originalTermios)
        var raw = originalTermios
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON)
        raw.c_cc.16 = 0
        raw.c_cc.17 = 1
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
    }

    private static func disableRawMode() {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
    }

    private static func setupTerminal() {
        enableRawMode()
        print("\u{001B}[?1049h\u{001B}[?25l", terminator: "")
        fflush(stdout)

        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler {
            cleanupAndExit()
        }
        source.resume()
        sigintSource = source
    }

    private static func cleanupAndExit() {
        disableRawMode()
        print("\u{001B}[?25h\u{001B}[?1049l", terminator: "")
        fflush(stdout)
        exit(0)
    }

    private static func makeBar(percentage: Double, length: Int = 16) -> String {
        let cleanPercent = max(0.0, min(100.0, percentage))
        let filledCount = Int((cleanPercent / 100.0) * Double(length))
        let emptyCount = max(0, length - filledCount)
        let colorCode = cleanPercent < 55.0 ? "\u{001B}[32m" : (cleanPercent < 80.0 ? "\u{001B}[33m" : "\u{001B}[31m")
        return "\(colorCode)\(String(repeating: "▰", count: filledCount))\u{001B}[90m\(String(repeating: "▱", count: emptyCount))\u{001B}[0m"
    }

    private static func makeSparkline(history: [Double]) -> String {
        let ticks = [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        return history.map { val in
            let index = min(7, max(0, Int((val / 100.0) * 8.0)))
            return ticks[index]
        }.joined()
    }

    private static func visibleLength(of text: String) -> Int {
        var stripped = ""
        var inAnsi = false
        for char in text {
            if char == "\u{001B}" { inAnsi = true; continue }
            if inAnsi {
                if char.isLetter { inAnsi = false }
                continue
            }
            stripped.append(char)
        }
        return stripped.utf16.count
    }

    private static func padCol(_ text: String, width: Int) -> String {
        let visLen = visibleLength(of: text)
        let spaces = max(0, width - visLen)
        return text + String(repeating: " ", count: spaces)
    }

    private static func render(cpu: CPUUsage, mem: MemoryUsage, sensors: [ThermalSensor], fans: [FanStatus], processes: [ProcessItem], batt: BatteryStatus, net: (down: String, up: String)) {
        
        cpuHistory.removeFirst()
        cpuHistory.append(cpu.totalUsage)

        let avgTemp = sensors.isEmpty ? 0.0 : (sensors.map(\.temperature).reduce(0, +) / Double(sensors.count))
        let maxTemp = sensors.map(\.temperature).max() ?? 0.0
        let thermalHeadroom = max(0.0, 100.0 - maxTemp)
        let headroomPercent = (thermalHeadroom / 60.0) * 100.0
        
        let isDesktop = batt.percentage == 100 && batt.cycleCount == 0 && batt.health == 100
        let battIcon = batt.isCharging ? "⚡️" : "🔋"
        let sortLabel = sortMode == .cpu ? "% CPU" : "% RAM"

        var buffer = "\u{001B}[H"
        buffer += """
        \u{001B}[36m
          ░█████╗░██╗░░██╗██╗██╗░░░░░██╗░░░░░
          ██╔══██╗██║░░██║██║██║░░░░░██║░░░░░
          ██║░░╚═╝███████║██║██║░░░░░██║░░░░░
          ██║░░██╗██╔══██║██║██║░░░░░██║░░░░░
          ╚█████╔╝██║░░██║██║███████╗███████╗
          ░╚════╝░╚═╝░░╚═╝╚═╝╚══════╝╚══════╝\u{001B}[0m
        \u{001B}[36m┌─── TELEMETRY & HARDWARE MONITOR ───────────────────────────── [ macOS ] ──────┐\u{001B}[0m\n
        """

        let headerText = "  \u{001B}[1m❄️  APPLE SILICON DASHBOARD\u{001B}[0m           Uptime: \(cpu.uptimeString.padding(toLength: 8, withPad: " ", startingAt: 0)) Refresh: \(String(format: "%.1f", refreshInterval))s"
        buffer += "│" + padCol(headerText, width: 78) + "  │\n"
        
        buffer += "\u{001B}[36m├─── CPU & RESOURCES ────────────────────────┬─── THERMALS & COOLING ───────────┤\u{001B}[0m\n"

        buffer += "│" + padCol("  CPU Load:  [\(makeBar(percentage: cpu.totalUsage))] \(String(format: "%5.1f", cpu.totalUsage))%", width: 44) + "│" + padCol("  SoC Avg:      \u{001B}[32m\(String(format: "%5.1f", avgTemp)) °C\u{001B}[0m", width: 33) + " │\n"
        buffer += "│" + padCol("  History:   \u{001B}[36m\(makeSparkline(history: cpuHistory))\u{001B}[0m", width: 44) + "│" + padCol("  Peak Temp:    \u{001B}[33m\(String(format: "%5.1f", maxTemp)) °C\u{001B}[0m", width: 33) + " │\n"
        buffer += "│" + padCol("  Topology:  \(cpu.coreCount) Active Cores", width: 44) + "│" + padCol("  Headroom:     [\(makeBar(percentage: headroomPercent, length: 8))] \(String(format: "%4.1f", thermalHeadroom))°C", width: 33) + " │\n"

        buffer += "\u{001B}[36m├─── UNIFIED MEMORY & NETWORK ───────────────┼─── BATTERY & FANS ───────────────┤\u{001B}[0m\n"
        
        buffer += "│" + padCol("  RAM Usage: [\(makeBar(percentage: mem.percentage))] \(String(format: "%5.1f", mem.percentage))%", width: 44) + "│" + padCol("  Fan State: " + (fans.isEmpty ? "\u{001B}[34m0 RPM (Silent Mode)\u{001B}[0m" : "\u{001B}[32m\(fans[0].currentRPM) RPM\u{001B}[0m"), width: 33) + " │\n"
        buffer += "│" + padCol("  Allocated: \(String(format: "%4.1f", mem.usedGB)) / \(String(format: "%4.1f", mem.totalGB)) GB", width: 44) + "│" + padCol(isDesktop ? "  Battery:   AC Power (Desktop)" : "  Battery:   [\(makeBar(percentage: Double(batt.percentage), length: 8))] \(batt.percentage)% \(battIcon)", width: 33) + " │\n"
        buffer += "│" + padCol("  App: \(String(format: "%3.1f", mem.appGB))G | Wired: \(String(format: "%3.1f", mem.wiredGB))G | Comp: \(String(format: "%3.1f", mem.compressedGB))G", width: 44) + "│" + padCol(isDesktop ? "  Health:    N/A" : "  Health:    \(batt.health)% (\(batt.cycleCount) Cycles)", width: 33) + " │\n"
        buffer += "│" + padCol("  Live Net:  ↓ \(net.down.padding(toLength: 8, withPad: " ", startingAt: 0)) | ↑ \(net.up)", width: 44) + "│" + padCol("  Fan Curve: Native macOS (Auto)", width: 33) + " │\n"

        buffer += "\u{001B}[36m├─── TOP PROCESSES [ Sort: \(sortLabel) ] ─────────────────────────────────────────────┤\u{001B}[0m\n"

        if processes.isEmpty {
            buffer += "│" + padCol("  No active processes found", width: 78) + " │\n"
        } else {
            for proc in processes {
                let badge = proc.cpuPercent > 50.0 ? "🔴" : (proc.cpuPercent >= 15.0 ? "🟠" : "🟢")
                let color = proc.cpuPercent > 50.0 ? "\u{001B}[31m" : (proc.cpuPercent >= 15.0 ? "\u{001B}[33m" : "\u{001B}[32m")
                let pidStr = "[\(proc.pid)]".padding(toLength: 7, withPad: " ", startingAt: 0)
                let nameStr = proc.name.prefix(22).padding(toLength: 23, withPad: " ", startingAt: 0)
                let metricStr = sortMode == .cpu 
                    ? String(format: "%5.1f%% CPU", proc.cpuPercent)
                    : String(format: "%5.1f%% RAM", proc.memPercent)
                
                let procLine = "  \(badge)  \(pidStr) \(nameStr) \(color)\(metricStr)\u{001B}[0m"
                buffer += "│" + padCol(procLine, width: 78) + " │\n"
            }
        }
        
        buffer += "\u{001B}[36m├───────────────────────────────────────────────────────────────────────────────┤\u{001B}[0m\n"
        let footerText = "  [Q/X] Exit  [P] Sort: CPU/RAM  [+/-] Refresh  [S] Stress 3s"
        buffer += "│" + padCol(footerText, width: 78) + " │\n"
        buffer += "\u{001B}[36m└───────────────────────────────────────────────────────────────────────────────┘\u{001B}[0m"
        
        print(buffer, terminator: "")
        fflush(stdout)
    }

    private static func readKeyNonBlocking() -> Character? {
        var byte: UInt8 = 0
        let res = read(STDIN_FILENO, &byte, 1)
        if res > 0 {
            return Character(UnicodeScalar(byte))
        }
        return nil
    }

    private static func runMiniStress() {
        let state = StressState()
        let group = DispatchGroup()
        let cores = ProcessInfo.processInfo.activeProcessorCount

        for _ in 0..<cores {
            group.enter()
            DispatchQueue.global(qos: .userInteractive).async {
                while state.isRunning {
                    _ = (0..<1000).reduce(0, +)
                }
                group.leave()
            }
        }

        Thread.sleep(forTimeInterval: 3.0)
        state.isRunning = false
        group.wait()
    }

    static func start() {
        _ = SystemMetrics.shared.getCPUUsage() 
        setupTerminal()

        while running {
            let cpu = SystemMetrics.shared.getCPUUsage()
            let mem = SystemMetrics.shared.getMemoryUsage()
            let sensors = SMCBridge.shared.getThermalSensors()
            let fans = SMCBridge.shared.getFanSpeed()
            let procs = SystemMetrics.shared.getTopProcesses(limit: 5, sortBy: sortMode)
            let batt = SystemMetrics.shared.getBatteryStatus()
            let net = SystemMetrics.shared.getNetworkSpeed()

            render(cpu: cpu, mem: mem, sensors: sensors, fans: fans, processes: procs, batt: batt, net: net)

            let slices = Int(refreshInterval * 10)
            for _ in 0..<max(1, slices) {
                if let key = readKeyNonBlocking() {
                    switch key {
                    case "q", "Q", "x", "X":
                        cleanupAndExit()
                    case "p", "P":
                        sortMode = (sortMode == .cpu) ? .memory : .cpu
                    case "+", "=":
                        refreshInterval = min(5.0, refreshInterval + 0.5)
                    case "-", "_":
                        refreshInterval = max(0.5, refreshInterval - 0.5)
                    case "s", "S":
                        runMiniStress()
                    default:
                        break
                    }
                    break
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
}

ChillDashboard.start()