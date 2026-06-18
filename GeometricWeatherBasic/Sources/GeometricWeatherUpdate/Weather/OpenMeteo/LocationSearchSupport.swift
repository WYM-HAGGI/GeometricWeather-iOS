//
//  LocationSearchSupport.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/18.
//

import Foundation
import CoreLocation
import GeometricWeatherCore
import GeometricWeatherResources

struct LocationSearchQuery {
    let raw: String
    let trimmed: String
    let lowercased: String
    let isChinese: Bool
    let containsLatin: Bool
    let pinyinCandidate: String?
    
    var isEmpty: Bool {
        trimmed.isEmpty
    }
}

enum LocationSearchNormalizer {
    
    static func normalize(_ query: String) -> LocationSearchQuery {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        let isChinese = trimmed.range(of: "\\p{Han}", options: .regularExpression) != nil
        let containsLatin = trimmed.range(of: "[A-Za-z]", options: .regularExpression) != nil
        
        return LocationSearchQuery(
            raw: query,
            trimmed: trimmed,
            lowercased: lowercased,
            isChinese: isChinese,
            containsLatin: containsLatin,
            pinyinCandidate: containsLatin ? lowercased : nil
        )
    }
}

enum LocationSearchSource: Equatable {
    case remoteGeocoding
    case localCache
    case systemGeocoder
}

private func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return nil
    }
    return value
}

struct LocationSearchResult {
    let name: String
    let localizedName: String?
    let country: String?
    let admin1: String?
    let admin2: String?
    let admin3: String?
    let admin4: String?
    let latitude: Double
    let longitude: Double
    let timezone: String?
    let source: LocationSearchSource
    let sourceId: String?
    
    var displayTitle: String {
        nonEmpty(localizedName)
        ?? nonEmpty(name)
        ?? Self.coordinateTitle(latitude: latitude, longitude: longitude)
    }
    
    var displaySubtitle: String {
        [
            nonEmpty(admin4),
            nonEmpty(admin3),
            nonEmpty(admin2),
            nonEmpty(admin1),
            nonEmpty(country)
        ]
            .compactMap { $0 }
            .reduce(into: [String]()) { result, item in
                if !result.contains(item) {
                    result.append(item)
                }
            }
            .joined(separator: " ")
    }
    
    var searchableText: String {
        [
            displayTitle,
            name,
            localizedName,
            country,
            admin1,
            admin2,
            admin3,
            admin4
        ]
            .compactMap { nonEmpty($0)?.lowercased() }
            .joined(separator: " ")
    }
    
    func toLocation(weatherSource: WeatherSource = .openMeteo) -> Location? {
        guard latitude.isFinite, longitude.isFinite else {
            return nil
        }
        guard (-90.0 ... 90.0).contains(latitude),
              (-180.0 ... 180.0).contains(longitude) else {
            return nil
        }
        
        let city = nonEmpty(localizedName)
        ?? nonEmpty(name)
        ?? Self.coordinateTitle(latitude: latitude, longitude: longitude)
        let province = nonEmpty(admin1) ?? nonEmpty(admin2) ?? ""
        let district = nonEmpty(admin4) ?? nonEmpty(admin3) ?? ""
        
        return Location(
            cityId: sourceId ?? OpenMeteoConvert.stableCityId(
                latitude: latitude,
                longitude: longitude
            ),
            latitude: latitude,
            longitude: longitude,
            timezone: TimeZone(identifier: timezone ?? "") ?? TimeZone.current,
            country: nonEmpty(country) ?? "",
            province: province,
            city: city,
            district: district,
            weather: nil,
            weatherSource: weatherSource,
            currentPosition: false,
            residentPosition: false
        )
    }
    
    static func fromOpenMeteo(_ result: OpenMeteoLocationResult) -> LocationSearchResult? {
        guard let latitude = result.latitude,
              let longitude = result.longitude,
              latitude.isFinite,
              longitude.isFinite,
              (-90.0 ... 90.0).contains(latitude),
              (-180.0 ... 180.0).contains(longitude) else {
            return nil
        }
        
        let name = nonEmpty(result.name) ?? coordinateTitle(latitude: latitude, longitude: longitude)
        return LocationSearchResult(
            name: name,
            localizedName: nil,
            country: nonEmpty(result.country),
            admin1: nonEmpty(result.admin1),
            admin2: nonEmpty(result.admin2),
            admin3: nonEmpty(result.admin3),
            admin4: nonEmpty(result.admin4),
            latitude: latitude,
            longitude: longitude,
            timezone: nonEmpty(result.timezone),
            source: .remoteGeocoding,
            sourceId: result.id.map { String($0) }
        )
    }
    
    static func fromPlacemark(_ placemark: CLPlacemark) -> LocationSearchResult? {
        guard let coordinate = placemark.location?.coordinate,
              coordinate.latitude.isFinite,
              coordinate.longitude.isFinite,
              (-90.0 ... 90.0).contains(coordinate.latitude),
              (-180.0 ... 180.0).contains(coordinate.longitude) else {
            return nil
        }
        
        let fallbackName = nonEmpty(placemark.name)
        ?? nonEmpty(placemark.locality)
        ?? nonEmpty(placemark.subAdministrativeArea)
        ?? coordinateTitle(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        return LocationSearchResult(
            name: fallbackName,
            localizedName: nonEmpty(placemark.name),
            country: nonEmpty(placemark.country),
            admin1: nonEmpty(placemark.administrativeArea),
            admin2: nonEmpty(placemark.subAdministrativeArea),
            admin3: nonEmpty(placemark.locality),
            admin4: nonEmpty(placemark.subLocality),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timezone: placemark.timeZone?.identifier,
            source: .systemGeocoder,
            sourceId: nil
        )
    }
    
    private static func coordinateTitle(latitude: Double, longitude: Double) -> String {
        return String(format: "%.4f, %.4f", latitude, longitude)
    }
}

protocol LocationSearchCache {
    func save(results: [LocationSearchResult], for query: String)
    func searchLocal(query: LocationSearchQuery) -> [LocationSearchResult]
}

final class InMemoryLocationSearchCache: LocationSearchCache {
    
    static let shared = InMemoryLocationSearchCache()
    
    private let lock = NSLock()
    private var recentResults = [String: [LocationSearchResult]]()
    
    private init() {
        // singleton
    }
    
    func save(results: [LocationSearchResult], for query: String) {
        let normalized = LocationSearchNormalizer.normalize(query)
        guard !normalized.isEmpty, !results.isEmpty else {
            return
        }
        
        lock.lock()
        recentResults[normalized.lowercased] = results
        if recentResults.count > 30,
           let firstKey = recentResults.keys.first {
            recentResults.removeValue(forKey: firstKey)
        }
        lock.unlock()
    }
    
    func searchLocal(query: LocationSearchQuery) -> [LocationSearchResult] {
        guard !query.isEmpty else {
            return []
        }
        
        lock.lock()
        let values = Array(recentResults.values).flatMap { $0 }
        lock.unlock()
        
        return values.filter { result in
            result.searchableText.contains(query.lowercased)
        }
        .map { result in
            LocationSearchResult(
                name: result.name,
                localizedName: result.localizedName,
                country: result.country,
                admin1: result.admin1,
                admin2: result.admin2,
                admin3: result.admin3,
                admin4: result.admin4,
                latitude: result.latitude,
                longitude: result.longitude,
                timezone: result.timezone,
                source: .localCache,
                sourceId: result.sourceId
            )
        }
    }
}

protocol LocationSearchProvider {
    var providerName: String { get }
    func search(query: LocationSearchQuery, completion: @escaping ([LocationSearchResult]) -> Void)
    func cancel()
}

final class OpenMeteoLocationSearchProvider: LocationSearchProvider {
    
    let providerName = "Open-Meteo Geocoding"
    private let service: OpenMeteoService
    
    init(service: OpenMeteoService) {
        self.service = service
    }
    
    func search(query: LocationSearchQuery, completion: @escaping ([LocationSearchResult]) -> Void) {
        let languages = Self.languageFallbacks(for: query)
        search(query: query, languages: languages, collected: [], completion: completion)
    }
    
    func cancel() {
        service.cancel()
    }
    
    private func search(
        query: LocationSearchQuery,
        languages: [String?],
        collected: [LocationSearchResult],
        completion: @escaping ([LocationSearchResult]) -> Void
    ) {
        guard let language = languages.first else {
            completion(collected)
            return
        }
        
        service.searchLocation(query: query.trimmed, language: language) { [weak self] result in
            let results: [LocationSearchResult]
            switch result {
            case .success(let response):
                results = response.results?.compactMap {
                    LocationSearchResult.fromOpenMeteo($0)
                } ?? []
                
            case .failure(let error):
                printLog(keyword: "location", content: "Open-Meteo location search error: \(error)")
                results = []
            }
            
            let merged = LocationSearchCoordinator.deduplicate(collected + results)
            if !merged.isEmpty || languages.count <= 1 {
                completion(merged)
                return
            }
            
            self?.search(
                query: query,
                languages: Array(languages.dropFirst()),
                collected: merged,
                completion: completion
            )
        }
    }
    
    private static func languageFallbacks(for query: LocationSearchQuery) -> [String?] {
        let uiLanguage = appLanguageCode()
        if query.isChinese {
            return uniqueLanguages([uiLanguage, "zh", nil])
        }
        return uniqueLanguages([uiLanguage, "en", nil])
    }
    
    private static func appLanguageCode() -> String {
        let language = Bundle.main.preferredLocalizations.first ?? Locale.current.languageCode ?? "en"
        if language.hasPrefix("zh") {
            return "zh"
        }
        return language.components(separatedBy: "-").first ?? "en"
    }
    
    private static func uniqueLanguages(_ languages: [String?]) -> [String?] {
        var result = [String?]()
        var seen = Set<String>()
        for language in languages {
            let key = language ?? "_none"
            if !seen.contains(key) {
                seen.insert(key)
                result.append(language)
            }
        }
        return result
    }
}

final class AppleGeocoderLocationSearchProvider: LocationSearchProvider {
    
    let providerName = "Apple CLGeocoder"
    private let geocoder = CLGeocoder()
    
    func search(query: LocationSearchQuery, completion: @escaping ([LocationSearchResult]) -> Void) {
        geocoder.geocodeAddressString(query.trimmed) { placemarks, error in
            if let error = error {
                printLog(keyword: "location", content: "Apple location search error: \(error)")
            }
            completion(placemarks?.compactMap { LocationSearchResult.fromPlacemark($0) } ?? [])
        }
    }
    
    func cancel() {
        geocoder.cancelGeocode()
    }
}

final class LocalCacheLocationSearchProvider: LocationSearchProvider {
    
    let providerName = "Local Location Cache"
    private let cache: LocationSearchCache
    
    init(cache: LocationSearchCache) {
        self.cache = cache
    }
    
    func search(query: LocationSearchQuery, completion: @escaping ([LocationSearchResult]) -> Void) {
        completion(cache.searchLocal(query: query))
    }
    
    func cancel() {
        // no-op
    }
}

final class LocationSearchCoordinator {
    
    private let remoteProvider: LocationSearchProvider
    private let appleProvider: LocationSearchProvider
    private let localProvider: LocationSearchProvider
    private let cache: LocationSearchCache
    
    init(
        remoteProvider: LocationSearchProvider,
        appleProvider: LocationSearchProvider,
        localProvider: LocationSearchProvider,
        cache: LocationSearchCache
    ) {
        self.remoteProvider = remoteProvider
        self.appleProvider = appleProvider
        self.localProvider = localProvider
        self.cache = cache
    }
    
    func search(_ rawQuery: String, completion: @escaping ([LocationSearchResult]) -> Void) {
        let query = LocationSearchNormalizer.normalize(rawQuery)
        guard !query.isEmpty else {
            completion([])
            return
        }
        
        localProvider.search(query: query) { [weak self] localResults in
            guard let self = self else {
                completion(localResults)
                return
            }
            
            self.remoteProvider.search(query: query) { [weak self] remoteResults in
                guard let self = self else {
                    completion(Self.deduplicate(localResults + remoteResults))
                    return
                }
                
                let merged = Self.deduplicate(localResults + remoteResults)
                if !merged.isEmpty, !Self.shouldTrySystemGeocoder(query: query) {
                    let sorted = Self.sorted(merged, query: query)
                    self.cache.save(results: sorted, for: query.trimmed)
                    completion(sorted)
                    return
                }
                
                self.appleProvider.search(query: query) { appleResults in
                    let sorted = Self.sorted(
                        Self.deduplicate(merged + appleResults),
                        query: query
                    )
                    self.cache.save(results: sorted, for: query.trimmed)
                    completion(sorted)
                }
            }
        }
    }
    
    func cancel() {
        remoteProvider.cancel()
        appleProvider.cancel()
        localProvider.cancel()
    }
    
    static func deduplicate(_ results: [LocationSearchResult]) -> [LocationSearchResult] {
        var unique = [LocationSearchResult]()
        for result in results {
            let exists = unique.contains { item in
                abs(item.latitude - result.latitude) < 0.02
                && abs(item.longitude - result.longitude) < 0.02
                && namesClose(item.displayTitle, result.displayTitle)
            }
            if !exists {
                unique.append(result)
            }
        }
        return unique
    }
    
    private static func sorted(
        _ results: [LocationSearchResult],
        query: LocationSearchQuery
    ) -> [LocationSearchResult] {
        return results.sorted { left, right in
            score(left, query: query) > score(right, query: query)
        }
    }
    
    private static func score(_ result: LocationSearchResult, query: LocationSearchQuery) -> Int {
        let text = result.searchableText
        var score = 0
        if result.displayTitle.lowercased() == query.lowercased {
            score += 100
        }
        if result.displayTitle.lowercased().contains(query.lowercased) {
            score += 50
        }
        if text.contains(query.lowercased) {
            score += 20
        }
        if result.source == .localCache {
            score += 10
        }
        if result.source == .remoteGeocoding {
            score += 5
        }
        return score
    }
    
    private static func shouldTrySystemGeocoder(query: LocationSearchQuery) -> Bool {
        return query.isChinese || query.trimmed.count >= 3
    }
    
    private static func namesClose(_ left: String, _ right: String) -> Bool {
        let left = left.lowercased()
        let right = right.lowercased()
        return left == right || left.contains(right) || right.contains(left)
    }
}
