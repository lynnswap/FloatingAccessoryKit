import OSLog

@MainActor
enum FloatingAccessoryDiagnostics {
    private static let logger = Logger(
        subsystem: "FloatingAccessoryKit",
        category: "Runtime"
    )
    private static var reportedIDs: Set<String> = []

    static func reportOnce(id: String, _ message: String) {
        guard reportedIDs.insert(id).inserted else {
            return
        }

        logger.error("\(message, privacy: .public)")
    }
}
