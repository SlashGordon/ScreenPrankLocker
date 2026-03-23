import Foundation

/// Locates resources that work both during `swift build`/`swift run` (where SwiftPM
/// places a resource bundle next to the executable) and inside a signed `.app` bundle
/// (where build.sh copies resources into Contents/Resources/).
enum ResourceHelper {
    /// Returns the URL for a resource file, checking multiple locations.
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        // 1. App bundle: Contents/Resources/
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }

        // 2. App bundle: Contents/Resources/<name>.<ext> (flat copy)
        let appResources = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources")
            .appendingPathComponent("\(name).\(ext)")
        if FileManager.default.fileExists(atPath: appResources.path) {
            return appResources
        }

        // 3. SwiftPM resource bundle next to executable
        let swiftpmBundle = Bundle.main.bundleURL
            .appendingPathComponent("ScreenPrankLocker_ScreenPrankLocker.bundle")
        if let bundle = Bundle(path: swiftpmBundle.path),
           let url = bundle.url(forResource: name, withExtension: ext) {
            return url
        }

        return nil
    }
}
