// Copyright (c) 2026 SlashGordon
// Author: SlashGordon <slash.gordon.dev@gmail.com>


import Foundation

/// Manages loading and saving of PrankLockerConfig from a JSON file on disk.
/// The config directory path is injectable for testability.
class ConfigurationManager {
    static let shared = ConfigurationManager()

    var config: PrankLockerConfig = .default

    /// The directory containing the config file.
    let configDirectoryPath: String

    /// Full path to the config JSON file.
    var configFilePath: String {
        return (configDirectoryPath as NSString).appendingPathComponent("config.json")
    }

    /// Creates a ConfigurationManager with an injectable config directory path.
    /// - Parameter configDirectoryPath: Path to the config directory.
    ///   Defaults to `~/.prank-locker`.
    init(configDirectoryPath: String = "~/.prank-locker") {
        self.configDirectoryPath = configDirectoryPath
    }

    /// Loads config from the JSON file at `configFilePath`.
    /// Falls back to `PrankLockerConfig.default` if the file doesn't exist.
    func load() throws {
        let expandedDir = NSString(string: configDirectoryPath).expandingTildeInPath
        let expandedFile = (expandedDir as NSString).appendingPathComponent("config.json")

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: expandedFile) else {
            config = .default
            return
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: expandedFile))
        let decoder = JSONDecoder()
        config = try decoder.decode(PrankLockerConfig.self, from: data)
    }

    /// Saves the current config to the JSON file at `configFilePath`.
    /// Creates the config directory if it doesn't exist.
    func save() throws {
        let expandedDir = NSString(string: configDirectoryPath).expandingTildeInPath
        let expandedFile = (expandedDir as NSString).appendingPathComponent("config.json")

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: expandedDir) {
            try fileManager.createDirectory(
                atPath: expandedDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        try data.write(to: URL(fileURLWithPath: expandedFile))
    }
}
