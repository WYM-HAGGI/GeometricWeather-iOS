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
    case amap
    case localCache
    case systemGeocoder
}

enum CoordinateSystem: Equatable {
    case wgs84
    case gcj02
    case bd09
    case unknown
}

enum LocationSearchResultType: Equatable {
    case city
    case district
    case township
    case poi
    case address
    case unknown
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
    let township: String?
    let address: String?
    let latitude: Double
    let longitude: Double
    let weatherLatitude: Double
    let weatherLongitude: Double
    let coordinateSystem: CoordinateSystem
    let timezone: String?
    let source: LocationSearchSource
    let sourceId: String?
    let resultType: LocationSearchResultType
    let category: String?
    
    init(
        name: String,
        localizedName: String? = nil,
        country: String? = nil,
        admin1: String? = nil,
        admin2: String? = nil,
        admin3: String? = nil,
        admin4: String? = nil,
        township: String? = nil,
        address: String? = nil,
        latitude: Double,
        longitude: Double,
        weatherLatitude: Double? = nil,
        weatherLongitude: Double? = nil,
        coordinateSystem: CoordinateSystem = .wgs84,
        timezone: String? = nil,
        source: LocationSearchSource,
        sourceId: String? = nil,
        resultType: LocationSearchResultType = .unknown,
        category: String? = nil
    ) {
        self.name = name
        self.localizedName = localizedName
        self.country = country
        self.admin1 = admin1
        self.admin2 = admin2
        self.admin3 = admin3
        self.admin4 = admin4
        self.township = township
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.weatherLatitude = weatherLatitude ?? latitude
        self.weatherLongitude = weatherLongitude ?? longitude
        self.coordinateSystem = coordinateSystem
        self.timezone = timezone
        self.source = source
        self.sourceId = sourceId
        self.resultType = resultType
        self.category = category
    }
    
    var displayTitle: String {
        nonEmpty(localizedName)
        ?? nonEmpty(name)
        ?? Self.coordinateTitle(latitude: latitude, longitude: longitude)
    }
    
    var displaySubtitle: String {
        let locationText = Self.joinDisplayParts(administrativeParts + [nonEmpty(address)])
        let category = displayCategory
        if !locationText.isEmpty, let category = category {
            return "\(locationText) · \(category)"
        }
        return locationText.isEmpty ? (category ?? "") : locationText
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
            admin4,
            township,
            address,
            category
        ]
            .compactMap { nonEmpty($0)?.lowercased() }
            .joined(separator: " ")
    }
    
    func toLocation(weatherSource: WeatherSource = .openMeteo) -> Location? {
        guard weatherLatitude.isFinite, weatherLongitude.isFinite else {
            return nil
        }
        guard (-90.0 ... 90.0).contains(weatherLatitude),
              (-180.0 ... 180.0).contains(weatherLongitude) else {
            return nil
        }
        
        let city = administrativeCity
        let province = nonEmpty(admin1) ?? ""
        let district = administrativeDistrict
        
        let location = Location(
            cityId: sourceId ?? OpenMeteoConvert.stableCityId(
                latitude: weatherLatitude,
                longitude: weatherLongitude
            ),
            latitude: weatherLatitude,
            longitude: weatherLongitude,
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
        
        saveLocationDetailText(
            location: location,
            detail: Self.joinDisplayParts(administrativeParts + [nonEmpty(address)])
        )
        saveLocationSearchDisplayText(
            location: location,
            title: displayTitle,
            subtitle: displaySubtitle
        )
        return location
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
            weatherLatitude: latitude,
            weatherLongitude: longitude,
            coordinateSystem: .wgs84,
            timezone: nonEmpty(result.timezone),
            source: .remoteGeocoding,
            sourceId: result.id.map { String($0) },
            resultType: .city
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
            township: nil,
            address: nonEmpty(placemark.thoroughfare),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            weatherLatitude: coordinate.latitude,
            weatherLongitude: coordinate.longitude,
            coordinateSystem: .wgs84,
            timezone: placemark.timeZone?.identifier,
            source: .systemGeocoder,
            sourceId: nil,
            resultType: .address
        )
    }
    
    private static func coordinateTitle(latitude: Double, longitude: Double) -> String {
        return String(format: "%.4f, %.4f", latitude, longitude)
    }
    
    private var administrativeCity: String {
        nonEmpty(admin3)
        ?? nonEmpty(admin2)
        ?? (source == .systemGeocoder ? nil : nonEmpty(localizedName))
        ?? nonEmpty(name)
        ?? Self.coordinateTitle(latitude: latitude, longitude: longitude)
    }
    
    private var administrativeDistrict: String {
        let city = administrativeCity
        let district = nonEmpty(admin4) ?? nonEmpty(township)
        return district != city ? (district ?? "") : ""
    }
    
    private var administrativeParts: [String?] {
        [
            nonEmpty(admin1),
            nonEmpty(admin2),
            nonEmpty(admin3),
            nonEmpty(admin4),
            nonEmpty(township)
        ]
    }
    
    fileprivate var administrativeQuality: Int {
        var quality = administrativeParts.compactMap { $0 }.count
        if nonEmpty(address) != nil {
            quality += 1
        }
        if resultType == .poi {
            quality += 1
        }
        if source == .systemGeocoder {
            quality += 1
        }
        if source == .amap {
            quality += 2
        }
        return quality
    }
    
    private var displayCategory: String? {
        if let category = nonEmpty(category) {
            return category
        }
        switch resultType {
        case .city:
            return "城市"
        case .district:
            return "区县"
        case .township:
            return "街道"
        case .poi:
            return "地点"
        case .address:
            return "地址"
        case .unknown:
            return nil
        }
    }
    
    private static func joinDisplayParts(_ parts: [String?]) -> String {
        parts
            .compactMap { $0 }
            .reduce(into: [String]()) { result, item in
                if !result.contains(item) {
                    result.append(item)
                }
            }
            .joined(separator: " ")
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
                township: result.township,
                address: result.address,
                latitude: result.latitude,
                longitude: result.longitude,
                weatherLatitude: result.weatherLatitude,
                weatherLongitude: result.weatherLongitude,
                coordinateSystem: result.coordinateSystem,
                timezone: result.timezone,
                source: .localCache,
                sourceId: result.sourceId,
                resultType: result.resultType,
                category: result.category
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
    private let amapProvider: LocationSearchProvider
    private let appleProvider: LocationSearchProvider
    private let localProvider: LocationSearchProvider
    private let cache: LocationSearchCache
    
    init(
        remoteProvider: LocationSearchProvider,
        amapProvider: LocationSearchProvider,
        appleProvider: LocationSearchProvider,
        localProvider: LocationSearchProvider,
        cache: LocationSearchCache
    ) {
        self.remoteProvider = remoteProvider
        self.amapProvider = amapProvider
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
            
            self.amapProvider.search(query: query) { [weak self] amapResults in
                guard let self = self else {
                    completion(Self.deduplicate(localResults + amapResults))
                    return
                }
                
                let firstMerged = Self.deduplicate(localResults + amapResults)
                if Self.hasPreciseAmapResult(firstMerged, query: query) {
                    let sorted = Self.sorted(firstMerged, query: query)
                    self.cache.save(results: sorted, for: query.trimmed)
                    completion(sorted)
                    return
                }
                
                self.appleProvider.search(query: query) { [weak self] appleResults in
                    guard let self = self else {
                        completion(Self.deduplicate(firstMerged + appleResults))
                        return
                    }
                    
                    let secondMerged = Self.deduplicate(firstMerged + appleResults)
                    self.remoteProvider.search(query: query) { remoteResults in
                        let sorted = Self.sorted(
                            Self.deduplicate(secondMerged + remoteResults),
                            query: query
                        )
                        self.cache.save(results: sorted, for: query.trimmed)
                        completion(sorted)
                    }
                }
            }
        }
    }
    
    func cancel() {
        remoteProvider.cancel()
        amapProvider.cancel()
        appleProvider.cancel()
        localProvider.cancel()
    }
    
    static func deduplicate(_ results: [LocationSearchResult]) -> [LocationSearchResult] {
        var unique = [LocationSearchResult]()
        for result in results {
            if let index = unique.firstIndex(where: { item in
                distanceMeters(item, result) < 1000.0
                && namesClose(item.displayTitle, result.displayTitle)
                && sameAdministrativeArea(item, result)
            }) {
                if result.administrativeQuality > unique[index].administrativeQuality {
                    unique[index] = result
                }
            } else {
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
        switch result.source {
        case .localCache:
            score += 40
        case .amap:
            score += result.resultType == .poi ? 35 : 30
        case .systemGeocoder:
            score += 15
        case .remoteGeocoding:
            score += 5
        }
        score += result.administrativeQuality * 5
        return score
    }
    
    private static func hasPreciseAmapResult(_ results: [LocationSearchResult], query: LocationSearchQuery) -> Bool {
        return results.contains { result in
            result.source == .amap
            && (result.resultType == .poi || result.resultType == .township || result.resultType == .address)
            && result.searchableText.contains(query.lowercased)
        }
    }
    
    private static func namesClose(_ left: String, _ right: String) -> Bool {
        let left = left.lowercased()
        let right = right.lowercased()
        return left == right || left.contains(right) || right.contains(left)
    }
    
    private static func sameAdministrativeArea(_ left: LocationSearchResult, _ right: LocationSearchResult) -> Bool {
        let leftParts = [left.admin1, left.admin2, left.admin3, left.admin4].compactMap { nonEmpty($0) }
        let rightParts = [right.admin1, right.admin2, right.admin3, right.admin4].compactMap { nonEmpty($0) }
        guard !leftParts.isEmpty, !rightParts.isEmpty else {
            return true
        }
        return leftParts.contains { rightParts.contains($0) }
    }
    
    private static func distanceMeters(_ left: LocationSearchResult, _ right: LocationSearchResult) -> Double {
        let lat1 = left.weatherLatitude * Double.pi / 180.0
        let lat2 = right.weatherLatitude * Double.pi / 180.0
        let dLat = lat2 - lat1
        let dLon = (right.weatherLongitude - left.weatherLongitude) * Double.pi / 180.0
        let a = sin(dLat / 2.0) * sin(dLat / 2.0)
            + cos(lat1) * cos(lat2) * sin(dLon / 2.0) * sin(dLon / 2.0)
        return 6371000.0 * 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
    }
}
