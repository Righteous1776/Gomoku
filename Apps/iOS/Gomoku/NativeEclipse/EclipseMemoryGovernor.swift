import Foundation

/// iPhone 7 has 2 GB RAM. No device-name blacklist and no model substitution.
/// On 3 GB+ devices this governor has zero impact on search policy.
enum EclipseMemoryGovernor {
    static func isConstrained(physicalMemory: UInt64) -> Bool {
        physicalMemory > 0 && physicalMemory <= 2_500_000_000
    }
    static var lowMemoryDevice: Bool {
        isConstrained(physicalMemory: ProcessInfo.processInfo.physicalMemory)
    }
}
