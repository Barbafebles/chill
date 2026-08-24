import Foundation
import Darwin

public enum ProcessSortMode: Sendable {
    case cpu
    case memory
}

public struct CPUUsage: Sendable {
    public let totalUsage: Double
    public let coreCount: Int
    public let uptimeString: String
}

public struct MemoryUsage: Sendable {
    public let usedGB: Double
    public let totalGB: Double
    public let percentage: Double
    public let appGB: Double
    public let wiredGB: Double
    public let compressedGB: Double
}

public struct ProcessItem: Sendable {
    public let pid: Int32
    public let name: String
    public let cpuPercent: Double
    public let memPercent: Double
}

public struct BatteryStatus: Sendable {
    public let percentage: Int
    public let isCharging: Bool
    public let cycleCount: Int
    public let health: Int
}

public final class SystemMetrics: @unchecked Sendable {
    public static let shared = SystemMetrics()

    private var previousCpuInfo: processor_info_array_t?
    private var previousCpuInfoCount: mach_msg_type_number_t = 0
    
    private var lastNetIn: UInt64 = 0
    private var lastNetOut: UInt64 = 0
    private var lastNetTime: Date = Date()

    public func getCPUUsage() -> CPUUsage {
        var numProcessors: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numProcessors, &cpuInfo, &numCpuInfo)
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return CPUUsage(totalUsage: 0.0, coreCount: ProcessInfo.processInfo.activeProcessorCount, uptimeString: "--")
        }

        var totalUsage: Double = 0.0
        if let prevInfo = previousCpuInfo {
            var inUse: Int64 = 0
            var total: Int64 = 0
            for i in 0..<Int(numProcessors) {
                let base = i * Int(CPU_STATE_MAX)
                let u = Int64(cpuInfo[base + Int(CPU_STATE_USER)] - prevInfo[base + Int(CPU_STATE_USER)])
                let s = Int64(cpuInfo[base + Int(CPU_STATE_SYSTEM)] - prevInfo[base + Int(CPU_STATE_SYSTEM)])
                let n = Int64(cpuInfo[base + Int(CPU_STATE_NICE)] - prevInfo[base + Int(CPU_STATE_NICE)])
                let id = Int64(cpuInfo[base + Int(CPU_STATE_IDLE)] - prevInfo[base + Int(CPU_STATE_IDLE)])
                let coreInUse = u + s + n
                let coreTotal = coreInUse + id
                inUse += coreInUse
                total += coreTotal
            }
            if total > 0 { totalUsage = (Double(inUse) / Double(total)) * 100.0 }
            let prevSize = vm_size_t(previousCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), prevSize)
        }
        previousCpuInfo = cpuInfo
        previousCpuInfoCount = numCpuInfo

        let uptimeSecs = Int(ProcessInfo.processInfo.systemUptime)
        let days = uptimeSecs / 86400
        let hours = (uptimeSecs % 86400) / 3600
        let mins = (uptimeSecs % 3600) / 60
        let uptimeStr = days > 0 ? "\(days)d \(hours)h \(mins)m" : "\(hours)h \(mins)m"

        return CPUUsage(totalUsage: totalUsage, coreCount: Int(numProcessors), uptimeString: uptimeStr)
    }

    public func getMemoryUsage() -> MemoryUsage {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        let totalRamBytes = ProcessInfo.processInfo.physicalMemory
        let totalGB = Double(totalRamBytes) / 1_073_741_824.0
        guard kerr == KERN_SUCCESS else {
            return MemoryUsage(usedGB: 0, totalGB: totalGB, percentage: 0, appGB: 0, wiredGB: 0, compressedGB: 0)
        }
        let pageSize = Double(sysconf(_SC_PAGESIZE))
        let internalBytes = Double(stats.internal_page_count) * pageSize
        let purgeableBytes = Double(stats.purgeable_count) * pageSize
        let appBytes = max(0, internalBytes - purgeableBytes)
        let wiredBytes = Double(stats.wire_count) * pageSize
        let compressedBytes = Double(stats.compressor_page_count) * pageSize
        let usedBytes = appBytes + wiredBytes + compressedBytes
        let usedGB = usedBytes / 1_073_741_824.0
        let percentage = min(100.0, (usedBytes / Double(totalRamBytes)) * 100.0)

        return MemoryUsage(usedGB: usedGB, totalGB: totalGB, percentage: percentage, appGB: appBytes / 1_073_741_824.0, wiredGB: wiredBytes / 1_073_741_824.0, compressedGB: compressedBytes / 1_073_741_824.0)
    }

    public func getTopProcesses(limit: Int = 5, sortBy: ProcessSortMode = .cpu) -> [ProcessItem] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        let sortFlag = (sortBy == .cpu) ? "-r" : "-m"
        task.arguments = ["-Aceo", "pid,%cpu,%mem,comm", sortFlag]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            var items: [ProcessItem] = []
            let lines = output.components(separatedBy: .newlines).dropFirst()
            for line in lines {
                let tokens = line.trimmingCharacters(in: .whitespaces).split(separator: " ", omittingEmptySubsequences: true)
                guard tokens.count >= 4,
                      let pid = Int32(tokens[0]),
                      let cpu = Double(tokens[1]),
                      let mem = Double(tokens[2]) else { continue }
                let cleanName = (tokens[3...].joined(separator: " ") as NSString).lastPathComponent
                if cleanName == "ps" || cleanName == "chill" { continue }
                items.append(ProcessItem(pid: pid, name: cleanName, cpuPercent: cpu, memPercent: mem))
                if items.count >= limit { break }
            }
            return items
        } catch { return [] }
    }

    public func getBatteryStatus() -> BatteryStatus {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        task.arguments = ["-rn", "AppleSmartBattery"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8), output.contains("AppleSmartBattery") else {
                return BatteryStatus(percentage: 100, isCharging: true, cycleCount: 0, health: 100)
            }
            var cap = 100.0, maxCap = 100.0, designCap = 100.0, cycles = 0, isCharging = false
            for line in output.components(separatedBy: .newlines) {
                if line.contains("\"CurrentCapacity\" =") { cap = Double(line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "100") ?? 100.0 }
                else if line.contains("\"MaxCapacity\" =") { maxCap = Double(line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "100") ?? 100.0 }
                else if line.contains("\"DesignCapacity\" =") { designCap = Double(line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "100") ?? 100.0 }
                else if line.contains("\"CycleCount\" =") { cycles = Int(line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "0") ?? 0 }
                else if line.contains("\"IsCharging\" = Yes") { isCharging = true }
            }
            let pct = maxCap > 0 ? Int((cap / maxCap) * 100) : 100
            let health = designCap > 0 ? Int((maxCap / designCap) * 100) : 100
            return BatteryStatus(percentage: pct, isCharging: isCharging, cycleCount: cycles, health: health)
        } catch { return BatteryStatus(percentage: 100, isCharging: true, cycleCount: 0, health: 100) }
    }

    public func getNetworkSpeed() -> (down: String, up: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        task.arguments = ["-ib"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return ("0 B/s", "0 B/s") }
            var totalIn: UInt64 = 0, totalOut: UInt64 = 0
            let lines = output.components(separatedBy: .newlines).dropFirst()
            for line in lines where line.starts(with: "en") || line.starts(with: "lo") {
                let cols = line.split(separator: " ", omittingEmptySubsequences: true)
                if let linkIdx = cols.firstIndex(where: { $0.hasPrefix("<Link#") }) {
                    var off = 1
                    if linkIdx + 1 < cols.count && cols[linkIdx + 1].contains(":") { off = 2 }
                    if linkIdx + off + 2 < cols.count, let ib = UInt64(cols[linkIdx + off + 2]) { totalIn += ib }
                    if linkIdx + off + 5 < cols.count, let ob = UInt64(cols[linkIdx + off + 5]) { totalOut += ob }
                }
            }
            let now = Date()
            let timeDiff = now.timeIntervalSince(lastNetTime)
            guard timeDiff > 0, lastNetIn > 0 else {
                lastNetIn = totalIn; lastNetOut = totalOut; lastNetTime = now
                return ("0 B/s", "0 B/s")
            }
            let bInSec = Double(totalIn - lastNetIn) / timeDiff
            let bOutSec = Double(totalOut - lastNetOut) / timeDiff
            lastNetIn = totalIn; lastNetOut = totalOut; lastNetTime = now
            return (formatBytes(bInSec), formatBytes(bOutSec))
        } catch { return ("0 B/s", "0 B/s") }
    }

    private func formatBytes(_ bytes: Double) -> String {
        if bytes < 0 { return "0 B/s" }
        if bytes >= 1_048_576 { return String(format: "%.1f MB/s", bytes / 1_048_576) }
        else if bytes >= 1024 { return String(format: "%.1f KB/s", bytes / 1024) }
        else { return String(format: "%.0f B/s", bytes) }
    }
}