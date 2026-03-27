import Foundation

enum OptimizationCatalog {
    static func actions() -> [OptimizationAction] {
        systemActions
        + networkActions
        + storageActions
        + performanceActions
        + maintenanceActions
        + monitoringActions
    }
}
