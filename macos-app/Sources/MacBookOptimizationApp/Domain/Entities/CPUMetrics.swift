import Foundation

struct CPUMetrics: Equatable {
    let timestamp: Date
    let cpuName: String
    let totalCores: Int
    let thermalPressure: ThermalPressure
    let clusters: [ClusterMetrics]
    let cores: [CoreMetrics]
    let power: PowerMetrics
    
    enum ThermalPressure: String, Equatable {
        case nominal = "Nominal"
        case moderate = "Moderate"
        case heavy = "Heavy"
        case trapping = "Trapping"
        case sleeping = "Sleeping"
        
        var displayName: String { rawValue }
    }
    
    struct ClusterMetrics: Equatable, Identifiable {
        let id: String
        let name: String
        let online: Double
        let activeFrequency: Int
        let activeResidency: Double
        let idleResidency: Double
        let downResidency: Double
        let frequencyDistribution: [FrequencyBucket]
        
        struct FrequencyBucket: Equatable {
            let frequency: Int
            let percentage: Double
        }
    }
    
    struct CoreMetrics: Equatable, Identifiable {
        let id: Int
        let frequency: Int
        let activeResidency: Double
        let idleResidency: Double
        let downResidency: Double
    }
    
    struct PowerMetrics: Equatable {
        let cpu: Int
        let gpu: Int
        let ane: Int
        
        var combined: Int {
            cpu + gpu + ane
        }
    }
    
    var overallCPUUsage: Double {
        guard !cores.isEmpty else { return 0 }
        let totalActive = cores.reduce(0.0) { $0 + $1.activeResidency }
        return totalActive / Double(cores.count)
    }
}

struct CPUMetricsParser {
    static func parse(_ output: String, cpuName: String) -> CPUMetrics? {
        let lines = output.components(separatedBy: .newlines)
        
        guard let thermalPressure = parseThermalPressure(from: lines),
              let power = parsePower(from: lines) else {
            return nil
        }
        
        let clusters = parseClusters(from: lines)
        let cores = parseCores(from: lines)
        
        return CPUMetrics(
            timestamp: .now,
            cpuName: cpuName,
            totalCores: cores.count,
            thermalPressure: thermalPressure,
            clusters: clusters,
            cores: cores,
            power: power
        )
    }
    
    private static func parseThermalPressure(from lines: [String]) -> CPUMetrics.ThermalPressure? {
        guard let line = lines.first(where: { $0.contains("Current pressure level:") }) else {
            return nil
        }
        
        let components = line.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }
        
        let level = components[1].trimmingCharacters(in: .whitespaces)
        return CPUMetrics.ThermalPressure(rawValue: level)
    }
    
    private static func parsePower(from lines: [String]) -> CPUMetrics.PowerMetrics? {
        var cpu: Int?
        var gpu: Int?
        var ane: Int?
        
        for line in lines {
            if line.contains("CPU Power:") {
                cpu = extractMilliwatts(from: line)
            } else if line.contains("GPU Power:") {
                gpu = extractMilliwatts(from: line)
            } else if line.contains("ANE Power:") {
                ane = extractMilliwatts(from: line)
            }
        }
        
        guard let cpuPower = cpu, let gpuPower = gpu, let anePower = ane else {
            return nil
        }
        
        return CPUMetrics.PowerMetrics(cpu: cpuPower, gpu: gpuPower, ane: anePower)
    }
    
    private static func extractMilliwatts(from line: String) -> Int? {
        let components = line.components(separatedBy: " ")
        guard let mwIndex = components.firstIndex(of: "mW"),
              mwIndex > 0 else {
            return nil
        }
        return Int(components[mwIndex - 1])
    }
    
    private static func parseClusters(from lines: [String]) -> [CPUMetrics.ClusterMetrics] {
        var clusters: [CPUMetrics.ClusterMetrics] = []
        
        let clusterNames = ["E-Cluster", "P0-Cluster", "P1-Cluster"]
        
        for clusterName in clusterNames {
            if let cluster = parseCluster(name: clusterName, from: lines) {
                clusters.append(cluster)
            }
        }
        
        return clusters
    }
    
    private static func parseCluster(name: String, from lines: [String]) -> CPUMetrics.ClusterMetrics? {
        guard let onlineIndex = lines.firstIndex(where: { $0.contains("\(name) Online:") }),
              let freqIndex = lines.firstIndex(where: { $0.contains("\(name) HW active frequency:") }),
              let residencyIndex = lines.firstIndex(where: { $0.contains("\(name) HW active residency:") }),
              let idleIndex = lines.firstIndex(where: { $0.contains("\(name) idle residency:") }),
              let downIndex = lines.firstIndex(where: { $0.contains("\(name) down residency:") }) else {
            return nil
        }
        
        let onlineLine = lines[onlineIndex]
        let freqLine = lines[freqIndex]
        let residencyLine = lines[residencyIndex]
        let idleLine = lines[idleIndex]
        let downLine = lines[downIndex]
        
        guard let online = extractPercentage(from: onlineLine),
              let frequency = extractFrequency(from: freqLine),
              let activeResidency = extractPercentage(from: residencyLine),
              let idleResidency = extractPercentage(from: idleLine),
              let downResidency = extractPercentage(from: downLine) else {
            return nil
        }
        
        let freqDistribution = parseFrequencyDistribution(from: residencyLine)
        
        return CPUMetrics.ClusterMetrics(
            id: name,
            name: name,
            online: online,
            activeFrequency: frequency,
            activeResidency: activeResidency,
            idleResidency: idleResidency,
            downResidency: downResidency,
            frequencyDistribution: freqDistribution
        )
    }
    
    private static func parseFrequencyDistribution(from line: String) -> [CPUMetrics.ClusterMetrics.FrequencyBucket] {
        var buckets: [CPUMetrics.ClusterMetrics.FrequencyBucket] = []
        
        // Extract content within parentheses
        guard let startIndex = line.firstIndex(of: "("),
              let endIndex = line.firstIndex(of: ")") else {
            return buckets
        }
        
        let content = String(line[line.index(after: startIndex)..<endIndex])

        let pattern = #"(\d+)\s+MHz:\s*([\d.]+)%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return buckets
        }

        let nsContent = content as NSString
        let matches = regex.matches(
            in: content,
            options: [],
            range: NSRange(location: 0, length: nsContent.length)
        )

        for match in matches where match.numberOfRanges == 3 {
            let frequencyString = nsContent.substring(with: match.range(at: 1))
            let percentageString = nsContent.substring(with: match.range(at: 2))

            if let frequency = Int(frequencyString),
               let percentage = Double(percentageString) {
                buckets.append(
                    CPUMetrics.ClusterMetrics.FrequencyBucket(
                        frequency: frequency,
                        percentage: percentage
                    )
                )
            }
        }
        
        return buckets.sorted { $0.frequency < $1.frequency }
    }
    
    private static func parseCores(from lines: [String]) -> [CPUMetrics.CoreMetrics] {
        var cores: [CPUMetrics.CoreMetrics] = []
        
        for i in 0..<20 {
            if let core = parseCore(id: i, from: lines) {
                cores.append(core)
            }
        }
        
        return cores
    }
    
    private static func parseCore(id: Int, from lines: [String]) -> CPUMetrics.CoreMetrics? {
        guard let freqIndex = lines.firstIndex(where: { $0.contains("CPU \(id) frequency:") }),
              let activeIndex = lines.firstIndex(where: { $0.contains("CPU \(id) active residency:") }),
              let idleIndex = lines.firstIndex(where: { $0.contains("CPU \(id) idle residency:") }),
              let downIndex = lines.firstIndex(where: { $0.contains("CPU \(id) down residency:") }) else {
            return nil
        }
        
        let freqLine = lines[freqIndex]
        let activeLine = lines[activeIndex]
        let idleLine = lines[idleIndex]
        let downLine = lines[downIndex]
        
        guard let frequency = extractFrequency(from: freqLine),
              let activeResidency = extractPercentage(from: activeLine),
              let idleResidency = extractPercentage(from: idleLine),
              let downResidency = extractPercentage(from: downLine) else {
            return nil
        }
        
        return CPUMetrics.CoreMetrics(
            id: id,
            frequency: frequency,
            activeResidency: activeResidency,
            idleResidency: idleResidency,
            downResidency: downResidency
        )
    }
    
    private static func extractPercentage(from line: String) -> Double? {
        let components = line.components(separatedBy: " ")
        for component in components {
            if component.hasSuffix("%") {
                let numStr = component.replacingOccurrences(of: "%", with: "")
                return Double(numStr)
            }
        }
        return nil
    }
    
    private static func extractFrequency(from line: String) -> Int? {
        let components = line.components(separatedBy: " ")
        guard let mhzIndex = components.firstIndex(of: "MHz"),
              mhzIndex > 0 else {
            return nil
        }
        return Int(components[mhzIndex - 1])
    }
}
