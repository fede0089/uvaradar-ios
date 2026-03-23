import Foundation

struct RemoteSeriesConfig {
    let baseURL: URL

    static let `default` = RemoteSeriesConfig(
        baseURL: URL(string: "https://uva-radar.vercel.app")!
    )
}

protocol SeriesRepository {
    func loadCachedSeries() throws -> SeriesBundle?
    func fetchInitialSeries() async throws -> SeriesBundle
    func refreshSeries(ifNewerThan current: SeriesBundle) async throws -> SeriesBundle?
}

final class LiveSeriesRepository: SeriesRepository {
    private let config: RemoteSeriesConfig
    private let session: URLSession
    private let cacheURL: URL

    init(config: RemoteSeriesConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session

        let fileManager = FileManager.default
        let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = (appSupport ?? fileManager.temporaryDirectory).appendingPathComponent("UvaRadar", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.cacheURL = directory.appendingPathComponent("series-cache-v1.json")
    }

    func loadCachedSeries() throws -> SeriesBundle? {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: cacheURL)
        return try JSONDecoder().decode(SeriesBundle.self, from: data)
    }

    func fetchInitialSeries() async throws -> SeriesBundle {
        let manifest = try await fetchManifest()
        let bundle = try await fetchBundle(using: manifest)
        try persist(bundle)
        return bundle
    }

    func refreshSeries(ifNewerThan current: SeriesBundle) async throws -> SeriesBundle? {
        let manifest = try await fetchManifest()
        guard manifest.lastCloseDate > current.manifest.lastCloseDate else {
            return nil
        }

        let bundle = try await fetchBundle(using: manifest)
        try persist(bundle)
        return bundle
    }

    private func fetchManifest() async throws -> SeriesManifest {
        try await fetchJSON(path: "series_manifest.json", queryItems: [
            URLQueryItem(name: "d", value: ISODateSupport.string(from: Date()))
        ])
    }

    private func fetchBundle(using manifest: SeriesManifest) async throws -> SeriesBundle {
        async let uva = fetchSeries(name: "uva", manifest: manifest)
        async let usd = fetchSeries(name: "usd", manifest: manifest)
        return try await SeriesBundle(manifest: manifest, uva: uva, usd: usd)
    }

    private func fetchSeries(name: String, manifest: SeriesManifest) async throws -> [String: Double] {
        var combined: [String: Double] = [:]
        let latestYear = manifest.years.max()

        for year in manifest.years {
            var queryItems: [URLQueryItem] = []
            if year == latestYear {
                queryItems.append(URLQueryItem(name: "v", value: manifest.lastCloseDate))
            }
            let chunk: [String: Double] = try await fetchJSON(path: "series_\(name)/\(year).json", queryItems: queryItems)
            combined.merge(chunk) { _, newValue in newValue }
        }

        return combined
    }

    private func fetchJSON<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        guard var components = URLComponents(url: config.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw SeriesRepositoryError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw SeriesRepositoryError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SeriesRepositoryError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SeriesRepositoryError.httpStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func persist(_ bundle: SeriesBundle) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(bundle)
        try data.write(to: cacheURL, options: [.atomic])
    }
}

enum SeriesRepositoryError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return AppStrings.Errors.invalidSeriesURL
        case .invalidResponse:
            return AppStrings.Errors.invalidSeriesResponse
        case .httpStatus(let code):
            return AppStrings.Errors.quotesDownloadFailed(code: code)
        }
    }
}
