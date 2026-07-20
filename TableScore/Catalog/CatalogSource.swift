import Foundation

/// Abstracts where catalog.json comes from so the bundled development
/// fixture can be swapped for a CDN URL without touching sync logic.
protocol CatalogSource: Sendable {
    func fetchManifest() async throws -> CatalogManifest
}

enum CatalogSourceError: LocalizedError {
    case fixtureMissing
    case badServerResponse(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .fixtureMissing:
            return String(localized: "The bundled catalog is missing.")
        case .badServerResponse(let code):
            return String(localized: "The catalog server returned an error (\(code)).")
        }
    }
}

/// Development source: reads the fixture catalog.json shipped in the bundle.
struct BundledCatalogSource: CatalogSource {
    var fileName = "catalog"

    func fetchManifest() async throws -> CatalogManifest {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw CatalogSourceError.fixtureMissing
        }
        let data = try Data(contentsOf: url)
        return try CatalogManifest.decoder().decode(CatalogManifest.self, from: data)
    }
}

/// Production source: fetches catalog.json from a CDN, honoring ETag so an
/// unchanged catalog costs one cheap 304 round-trip.
struct RemoteCatalogSource: CatalogSource {
    let manifestURL: URL
    static let etagKey = "catalog.etag"

    /// Drops the cached ETag so the next fetch is unconditional (full 200,
    /// re-applied) instead of a 304 no-op. Used by forced refreshes to recover
    /// from any stale/inconsistent local catalog state.
    static func clearCachedETag() {
        UserDefaults.standard.removeObject(forKey: etagKey)
    }

    func fetchManifest() async throws -> CatalogManifest {
        var request = URLRequest(url: manifestURL)
        if let etag = UserDefaults.standard.string(forKey: Self.etagKey) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 304 {
                throw CancellationError() // unchanged; caller treats as no-op
            }
            guard (200..<300).contains(http.statusCode) else {
                throw CatalogSourceError.badServerResponse(statusCode: http.statusCode)
            }
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                UserDefaults.standard.set(etag, forKey: Self.etagKey)
            }
        }
        return try CatalogManifest.decoder().decode(CatalogManifest.self, from: data)
    }
}
