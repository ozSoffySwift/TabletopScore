import Foundation

/// Single source of truth for the PocketBase backend location.
enum BackendConfig {
    /// UPDATE after provisioning (backend/README.md, SERVER.md). Must be
    /// HTTPS — the app ships no ATS exceptions for production traffic.
    /// PocketBase on Oracle Cloud, behind Nginx + Let's Encrypt (sslip.io).
    static let baseURL = URL(string: "https://82-70-253-130.sslip.io")!

    static var catalogURL: URL { baseURL.appending(path: "/api/catalog.json") }
    static var eventsURL: URL { baseURL.appending(path: "/api/collections/events/records") }

    /// Both DEBUG and Release sync from the server by default. For offline
    /// development against the local DevCDN fixture (localhost audio URLs),
    /// launch a DEBUG build with the `-UseBundledCatalog` scheme argument —
    /// and run `Tools/serve_devcdn.sh` so those localhost streams resolve.
    static func catalogSource() -> CatalogSource {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UseBundledCatalog") {
            return BundledCatalogSource()
        }
        return PocketBaseCatalogSource()
        #else
        return PocketBaseCatalogSource()
        #endif
    }
}

/// Catalog manifest from the PocketBase `/api/catalog.json` hook — same
/// wire format as the bundled fixture, ETag handled by RemoteCatalogSource.
struct PocketBaseCatalogSource: CatalogSource {
    func fetchManifest() async throws -> CatalogManifest {
        try await RemoteCatalogSource(manifestURL: BackendConfig.catalogURL).fetchManifest()
    }
}
