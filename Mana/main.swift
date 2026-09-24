import Foundation
import SwiftUI

// An app launch has no arguments. A lowercase `mana` command runs the CLI by default.
let arguments = Array(CommandLine.arguments.dropFirst())
let executableName = URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent
let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
if !isTestHost && (!arguments.isEmpty || executableName == "mana") {
    let status = await ManaCLI.run(arguments)
    exit(status)
} else {
    ManaApp.main()
}
