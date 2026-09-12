import Foundation


enum CommandRunner {
    static func run(_ executable: String, arguments: [String] = []) async -> String? {
        await Task.detached(priority: .utility) {
            let process = Process()
            let pipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = errorPipe

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    let stderr = String(data: errorData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    SystemDeckLog.command.warning(
                        "Command failed: \(executable, privacy: .public) status=\(process.terminationStatus) stderr=\(stderr, privacy: .private(mask: .hash))"
                    )
                    return nil
                }

                return String(data: data, encoding: .utf8)
            } catch {
                SystemDeckLog.command.error(
                    "Unable to run \(executable, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                return nil
            }
        }.value
    }
}
