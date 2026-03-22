import XCTest
@testable import ScreenPrankLocker

final class ConfigurationManagerTests: XCTestCase {
    private var tempDir: String!
    private var manager: ConfigurationManager!

    override func setUp() {
        super.setUp()
        tempDir = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("ConfigManagerTests-\(UUID().uuidString)")
        manager = ConfigurationManager(configDirectoryPath: tempDir)
    }

    override func tearDown() {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        super.tearDown()
    }

    // MARK: - Default config when no file exists (Requirement 3.1, 8.1)

    func testLoadWithNoConfigFileReturnsDefaults() throws {
        // The temp directory doesn't exist yet, so no config file
        try manager.load()

        let config = manager.config
        XCTAssertEqual(config.deactivationSequence, "unlock")
        XCTAssertEqual(config.imageDirectory, "~/.prank-locker/images/")
        XCTAssertEqual(config.imageIntervalSeconds, 3.0)
        XCTAssertEqual(config.maxSimultaneousImages, 15)
        XCTAssertEqual(config.failsafeTimeoutMinutes, 30)
        XCTAssertTrue(config.isEmergencyStopEnabled)
    }

    // MARK: - Custom config overrides (Requirement 4.3)

    func testLoadWithCustomConfigParsesCorrectly() throws {
        // Create the temp directory and write a custom config
        try FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )

        let customJSON = """
        {
            "activationShortcut": {
                "modifiers": ["shift", "command"],
                "keyCode": 12
            },
            "deactivationSequence": "opensesame",
            "imageDirectory": "/tmp/my-images/",
            "imageIntervalSeconds": 5.0,
            "maxSimultaneousImages": 10,
            "failsafeTimeoutMinutes": 60
        }
        """

        let configPath = (tempDir as NSString).appendingPathComponent("config.json")
        try customJSON.write(toFile: configPath, atomically: true, encoding: .utf8)

        try manager.load()

        let config = manager.config
        XCTAssertEqual(config.deactivationSequence, "opensesame")
        XCTAssertEqual(config.imageDirectory, "/tmp/my-images/")
        XCTAssertEqual(config.imageIntervalSeconds, 5.0)
        XCTAssertEqual(config.maxSimultaneousImages, 10)
        XCTAssertEqual(config.failsafeTimeoutMinutes, 60)
        XCTAssertTrue(config.isEmergencyStopEnabled)
    }

    // MARK: - Save and reload round-trip

    func testSaveWritesValidJSONThatCanBeReloaded() throws {
        // Save defaults to disk
        try manager.save()

        // Create a new manager pointing at the same directory and load
        let manager2 = ConfigurationManager(configDirectoryPath: tempDir)
        try manager2.load()

        let config = manager2.config
        XCTAssertEqual(config.deactivationSequence, "unlock")
        XCTAssertEqual(config.maxSimultaneousImages, 15)
        XCTAssertEqual(config.failsafeTimeoutMinutes, 30)
        XCTAssertTrue(config.isEmergencyStopEnabled)
    }

    // MARK: - Save creates directory if missing

    func testSaveCreatesDirectoryIfMissing() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir))

        try manager.save()

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir))
        let configPath = (tempDir as NSString).appendingPathComponent("config.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath))
    }

    // MARK: - Default activation shortcut values

    func testDefaultActivationShortcut() throws {
        try manager.load()

        let shortcut = manager.config.activationShortcut
        XCTAssertEqual(shortcut.keyCode, 37) // 'L' key
        XCTAssertTrue(shortcut.modifiers.contains(.maskControl))
        XCTAssertTrue(shortcut.modifiers.contains(.maskAlternate))
        XCTAssertTrue(shortcut.modifiers.contains(.maskCommand))
    }
}
