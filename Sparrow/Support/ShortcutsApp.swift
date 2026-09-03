import SwiftUI

/// What `ShortcutsLink` does, without the system-drawn pill.
///
/// 🧪 All three values were read out of `_AppIntents_SwiftUI.framework` in the
/// iOS 27 runtime, which carries the literal `shortcuts://app?bundleID=` next to
/// `bundleIdentifier`, the title format `"%@ shortcuts"`, and an image asset
/// named `Shortcuts`.
enum ShortcutsApp {
    /// Not `shortcuts://`, which lands on the library root. This opens the
    /// app's own page — its App Shortcuts rather than a list of every app.
    static var url: URL? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "app"
        components.queryItems = [URLQueryItem(name: "bundleID", value: bundleID)]
        return components.url
    }

    static var appName: String {
        let info = Bundle.main.infoDictionary
        return info?["CFBundleDisplayName"] as? String
            ?? info?["CFBundleName"] as? String
            ?? "Sparrow"
    }

    /// ⚠️ Apple artwork, loaded by name from a system framework. There is no SF
    /// Symbol of it and no public API that vends it, so this is undocumented
    /// and can break in any OS release — hence the fallback. Neither branch
    /// copies the image into our bundle.
    @ViewBuilder
    static var icon: some View {
        #if os(iOS)
        if let bundle = Bundle(identifier: "com.apple.-AppIntents-SwiftUI"),
           let image = UIImage(named: "Shortcuts", in: bundle, with: nil) {
            Image(uiImage: image)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
        } else {
            Image(systemName: "square.stack.3d.down.right")
        }
        #endif
    }
}
