import Foundation

struct MDMMetrics: Equatable {
    enum EnrollmentStatus: Equatable {
        case enrolled
        case notEnrolled
        case depAssignedOnly
        case historicalTracesOnly
        case unknown
        
        var localizedKey: LocalizedKey {
            switch self {
            case .enrolled: .mdmStatusCurrentlyEnrolled
            case .notEnrolled: .mdmStatusNotCurrentlyEnrolled
            case .depAssignedOnly: .mdmStatusDepAdeAssigned
            case .historicalTracesOnly: .mdmStatusHistoricalTracesFound
            case .unknown: .mdmStatusNeedsReview
            }
        }
    }
    
    enum ResetRisk: Equatable {
        case high
        case medium
        case low
        case unknown
        
        var localizedKey: LocalizedKey {
            switch self {
            case .high: .mdmRiskLikelyYes
            case .medium: .mdmRiskPossible
            case .low: .mdmRiskUnlikely
            case .unknown: .mdmRiskNoClearTrigger
            }
        }
        
        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "green"
            case .unknown: return "gray"
            }
        }
    }
    
    struct DEPConfiguration: Equatable {
        let organizationName: String?
        let configurationURL: String?
        let isSupervised: Bool
        let isMDMUnremovable: Bool
        let isMandatory: Bool
        let skipSetupItems: [String]
        let organizationEmail: String?
        let organizationPhone: String?
        let organizationAddress: String?
    }
    
    let timestamp: Date
    
    // Historical traces
    let depTracePresent: Bool
    let mdmTracePresent: Bool
    
    // Current enrollment
    let enrolledViaDEP: Bool
    let mdmEnrolled: Bool
    
    // Hosts bypass
    let bypassHostsDetected: Bool
    
    // DEP Configuration
    let depConfig: DEPConfiguration?
    
    // Installed profiles
    let installedProfiles: [String]
    
    // Computed properties
    var enrollmentStatus: EnrollmentStatus {
        if mdmEnrolled {
            return .enrolled
        } else if depConfig != nil {
            return .depAssignedOnly
        } else if depTracePresent || mdmTracePresent {
            return .historicalTracesOnly
        } else if !enrolledViaDEP && !mdmEnrolled {
            return .notEnrolled
        }
        return .unknown
    }
    
    var resetRisk: ResetRisk {
        if mdmEnrolled || (depConfig?.isMandatory == true) {
            return .high
        } else if depConfig != nil || depTracePresent {
            return .medium
        } else if !enrolledViaDEP && !mdmEnrolled && !depTracePresent && !mdmTracePresent {
            return .low
        }
        return .unknown
    }
    
    var hasAnyMDMActivity: Bool {
        mdmEnrolled || enrolledViaDEP || depTracePresent || mdmTracePresent || depConfig != nil
    }
}

struct MDMMetricsParser {
    static func parse(_ output: String) -> MDMMetrics? {
        let lines = output.components(separatedBy: .newlines)
        
        // Parse historical traces
        let depTracePresent = lines.contains { $0.contains("DEP trace files: Present") }
        let mdmTracePresent = lines.contains { $0.contains("Historical MDM traces: Present") }
        
        // Parse hosts bypass
        let bypassHostsDetected = lines.contains { line in
            line.contains("0.0.0.0") && (
                line.contains("deviceenrollment.apple.com") ||
                line.contains("mdmenrollment.apple.com") ||
                line.contains("iprofiles.apple.com")
            )
        }
        
        // Parse enrollment status
        let enrolledViaDEP = lines.contains { $0.contains("Enrolled via DEP: Yes") }
        let mdmEnrolled = lines.contains { $0.contains("MDM enrollment: Yes") }
        
        // Parse DEP configuration
        let depConfig = parseDEPConfiguration(from: lines)
        
        // Parse installed profiles
        let installedProfiles = parseInstalledProfiles(from: lines)
        
        return MDMMetrics(
            timestamp: .now,
            depTracePresent: depTracePresent,
            mdmTracePresent: mdmTracePresent,
            enrolledViaDEP: enrolledViaDEP,
            mdmEnrolled: mdmEnrolled,
            bypassHostsDetected: bypassHostsDetected,
            depConfig: depConfig,
            installedProfiles: installedProfiles
        )
    }
    
    private static func parseDEPConfiguration(from lines: [String]) -> MDMMetrics.DEPConfiguration? {
        // Find the start of DEP configuration block
        guard let configStartIndex = lines.firstIndex(where: { $0.contains("Device Enrollment configuration:") }) else {
            return nil
        }
        
        // Check if configuration is empty
        if lines.indices.contains(configStartIndex + 1) &&
           lines[configStartIndex + 1].trimmingCharacters(in: .whitespaces) == "{}" {
            return nil
        }
        
        var organizationName: String?
        var configurationURL: String?
        var isSupervised = false
        var isMDMUnremovable = false
        var isMandatory = false
        var skipSetupItems: [String] = []
        var organizationEmail: String?
        var organizationPhone: String?
        var organizationAddress: String?
        
        // Parse configuration block
        for i in (configStartIndex + 1)..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Stop at closing brace or next section
            if line == "}" || line.starts(with: "profiles list:") {
                break
            }
            
            if line.contains("OrganizationName = ") {
                organizationName = extractValue(from: line)
            } else if line.contains("ConfigurationURL = ") {
                configurationURL = extractValue(from: line)
            } else if line.contains("IsSupervised = ") {
                isSupervised = line.contains("= 1")
            } else if line.contains("IsMDMUnremovable = ") {
                isMDMUnremovable = line.contains("= 1")
            } else if line.contains("IsMandatory = ") {
                isMandatory = line.contains("= 1")
            } else if line.contains("SkipSetup = ") {
                skipSetupItems = parseSkipSetup(from: line)
            } else if line.contains("OrganizationEmail = ") {
                organizationEmail = extractValue(from: line)
            } else if line.contains("OrganizationPhone = ") {
                organizationPhone = extractValue(from: line)
            } else if line.contains("OrganizationAddress = ") {
                organizationAddress = extractValue(from: line)
            }
        }
        
        // Only return config if we found meaningful data
        guard organizationName != nil || configurationURL != nil else {
            return nil
        }
        
        return MDMMetrics.DEPConfiguration(
            organizationName: organizationName,
            configurationURL: configurationURL,
            isSupervised: isSupervised,
            isMDMUnremovable: isMDMUnremovable,
            isMandatory: isMandatory,
            skipSetupItems: skipSetupItems,
            organizationEmail: organizationEmail,
            organizationPhone: organizationPhone,
            organizationAddress: organizationAddress
        )
    }
    
    private static func parseInstalledProfiles(from lines: [String]) -> [String] {
        var profiles: [String] = []
        var inProfilesList = false
        
        for line in lines {
            if line.contains("profiles list:") {
                inProfilesList = true
                continue
            }
            
            if inProfilesList {
                if line.contains("There are no configuration profiles") {
                    break
                }
                
                if line.contains("profiles show -type") {
                    break
                }
                
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !trimmed.starts(with: "$") {
                    profiles.append(trimmed)
                }
            }
        }
        
        return profiles
    }
    
    private static func extractValue(from line: String) -> String? {
        guard let equalIndex = line.firstIndex(of: "=") else { return nil }
        
        let value = line[line.index(after: equalIndex)...]
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\";"))
        
        return value.isEmpty ? nil : value
    }
    
    private static func parseSkipSetup(from line: String) -> [String] {
        guard let startIndex = line.firstIndex(of: "("),
              let endIndex = line.firstIndex(of: ")") else {
            return []
        }
        
        let content = line[line.index(after: startIndex)..<endIndex]
        return content.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
