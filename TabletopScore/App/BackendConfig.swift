import Foundation

/// Single source of truth for the PocketBase backend location.
enum BackendConfig {
    /// UPDATE after provisioning (backend/README.md, SERVER.md). Must be
    /// HTTPS — the app ships no ATS exceptions for production traffic.
    /// PocketBase on Oracle Cloud, behind Nginx + Let's Encrypt.
    ///
    /// Do NOT go back to an `*.sslip.io` host. App Review 1.0 (2) was rejected
    /// because the reviewer's device never reached the server at all — those
    /// wildcard-DNS hostnames resolve any IP on demand, so DNS filters commonly
    /// blocklist them. The server logs showed zero connections from the review
    /// device while serving everyone else normally.
    static let baseURL = URL(string: "https://tablescore.duckdns.org")!

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
