//
//  WeatherAlertProvider.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/16.
//

import Foundation
import GeometricWeatherCore
import GeometricWeatherResources

protocol WeatherAlertProvider {
    var providerName: String { get }

    func fetchAlerts(for location: Location) async throws -> [WeatherAlert]
    func getAlerts(for location: Location) async throws -> [WeatherAlert]
}

extension WeatherAlertProvider {

    func getAlerts(for location: Location) async throws -> [WeatherAlert] {
        return try await fetchAlerts(for: location)
    }
}

enum WeatherAlertSeverity {
    case minor
    case moderate
    case severe
    case extreme
    case unknown
}

enum WeatherAlertType {
    case thunderstorm
    case heavyRain
    case heavySnow
    case strongWind
    case highTemperature
    case lowTemperature
    case fog
    case hail
    case freezing
    case typhoon
    case sandstorm
    case unknown
}

enum DebugWeatherAlertScenario: String {
    case rainstormYellow
    case thunderstormOrange
    case windBlue
    case expiredRainstorm
}

extension WeatherAlert {

    func isEffective(now: Date = Date()) -> Bool {
        return WeatherAlertValidation.isActive(self, now: now.timeIntervalSince1970)
    }

    var shouldTriggerLiveActivity: Bool {
        return WeatherAlertValidation.isLiveActivityEligible(self)
    }

    var shouldShowHomeNotice: Bool {
        return WeatherAlertValidation.shouldShowHomeNotice(self)
    }

    var normalizedType: WeatherAlertType {
        return WeatherAlertValidation.alertType(for: self)
    }

    var normalizedSeverity: WeatherAlertSeverity {
        return WeatherAlertValidation.severity(for: self)
    }

    var noticeTitle: String {
        let typeText = WeatherAlertValidation.localizedTypeText(for: normalizedType)
        let severityText = WeatherAlertValidation.localizedSeverityText(for: normalizedSeverity)
        if severityText.isEmpty {
            return typeText
        }
        return WeatherAlertValidation.localizedTitle(typeText: typeText, severityText: severityText)
    }

    var noticeSubtitle: String {
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return content
        }
        if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }
        return getLocalizedText("hourly_notice_weather_alert_subtitle")
    }
}

struct WeatherAlertValidation {

    private enum Threshold {
        static let startTolerance: TimeInterval = 30 * 60
        static let fallbackActiveAge: TimeInterval = 24 * 60 * 60
    }

    static func isLiveActivityEligible(_ alert: WeatherAlert, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard isActive(alert, now: now) else {
            return false
        }

        switch severity(for: alert) {
        case .moderate, .severe, .extreme:
            return true
        case .minor:
            return false
        case .unknown:
            switch alertType(for: alert) {
            case .thunderstorm, .heavyRain, .heavySnow, .typhoon, .hail:
                return true
            default:
                return false
            }
        }
    }

    static func shouldShowHomeNotice(_ alert: WeatherAlert, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        return isActive(alert, now: now)
    }

    static func isActive(_ alert: WeatherAlert, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        // WeatherAlert currently has only one timestamp and no explicit start/end dates.
        // Treat recent alerts as active; future provider adapters should drop expired alerts
        // before creating WeatherAlert, or extend the model in a migration-safe way.
        return alert.time <= now + Threshold.startTolerance
            && alert.time >= now - Threshold.fallbackActiveAge
    }

    static func severity(for alert: WeatherAlert) -> WeatherAlertSeverity {
        if alert.priority >= 4 {
            return .extreme
        }
        if alert.priority == 3 {
            return .severe
        }
        if alert.priority == 2 {
            return .moderate
        }
        if alert.priority == 1 {
            return .minor
        }
        return .unknown
    }

    static func alertType(for alert: WeatherAlert) -> WeatherAlertType {
        let text = [
            alert.type,
            alert.description,
            alert.content
        ].joined(separator: " ")

        if containsAny(text, ["雷暴", "雷电", "thunderstorm", "thunder"]) {
            return .thunderstorm
        }
        if containsAny(text, ["暴雨", "大雨", "rainstorm", "heavy rain"]) {
            return .heavyRain
        }
        if containsAny(text, ["暴雪", "大雪", "snowstorm", "heavy snow"]) {
            return .heavySnow
        }
        if containsAny(text, ["大风", "强风", "gale", "strong wind"]) {
            return .strongWind
        }
        if containsAny(text, ["高温", "heat", "high temperature"]) {
            return .highTemperature
        }
        if containsAny(text, ["寒潮", "低温", "cold wave", "low temperature"]) {
            return .lowTemperature
        }
        if containsAny(text, ["大雾", "雾", "fog"]) {
            return .fog
        }
        if containsAny(text, ["冰雹", "hail"]) {
            return .hail
        }
        if containsAny(text, ["道路结冰", "冻雨", "freezing", "ice"]) {
            return .freezing
        }
        if containsAny(text, ["台风", "typhoon"]) {
            return .typhoon
        }
        if containsAny(text, ["沙尘", "sandstorm", "dust"]) {
            return .sandstorm
        }
        return .unknown
    }

    static func localizedTypeText(for type: WeatherAlertType) -> String {
        switch type {
        case .thunderstorm:
            return getLocalizedText("weather_alert_type_thunderstorm")
        case .heavyRain:
            return getLocalizedText("weather_alert_type_heavy_rain")
        case .heavySnow:
            return getLocalizedText("weather_alert_type_heavy_snow")
        case .strongWind:
            return getLocalizedText("weather_alert_type_strong_wind")
        case .highTemperature:
            return getLocalizedText("weather_alert_type_high_temperature")
        case .lowTemperature:
            return getLocalizedText("weather_alert_type_low_temperature")
        case .fog:
            return getLocalizedText("weather_alert_type_fog")
        case .hail:
            return getLocalizedText("weather_alert_type_hail")
        case .freezing:
            return getLocalizedText("weather_alert_type_freezing")
        case .typhoon:
            return getLocalizedText("weather_alert_type_typhoon")
        case .sandstorm:
            return getLocalizedText("weather_alert_type_sandstorm")
        case .unknown:
            return getLocalizedText("weather_alert")
        }
    }

    static func localizedSeverityText(for severity: WeatherAlertSeverity) -> String {
        switch severity {
        case .minor:
            return getLocalizedText("weather_alert_severity_blue")
        case .moderate:
            return getLocalizedText("weather_alert_severity_yellow")
        case .severe:
            return getLocalizedText("weather_alert_severity_orange")
        case .extreme:
            return getLocalizedText("weather_alert_severity_red")
        case .unknown:
            return ""
        }
    }

    static func localizedTitle(typeText: String, severityText: String) -> String {
        let format = getLocalizedText("weather_alert_title_format")
        if format == "weather_alert_title_format" || format.isEmpty {
            return severityText + " " + typeText
        }
        return String(format: format, typeText, severityText)
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        let lowercased = text.lowercased()
        return keywords.contains { lowercased.contains($0.lowercased()) }
    }
}

final class DefaultWeatherAlertFallbackProvider: WeatherAlertProvider {

    let providerName = "WMO SWIC"
    private let cacheLifetime: TimeInterval = 10 * 60
    private let remoteProviders: [WeatherAlertProvider] = [
        WmoSevereWeatherAlertProvider()
    ]
    private let lock = NSLock()
    private var cache = [String: (date: Date, alerts: [WeatherAlert])]()

    #if DEBUG
    static var debugMockAlertsEnabled = false
    static var debugMockScenario: DebugWeatherAlertScenario = .rainstormYellow

    private enum DebugKey {
        static let mockScenario = "GEOWEATHER_DEBUG_ALERT_SCENARIO"
    }
    #endif

    func fetchAlerts(for location: Location) async throws -> [WeatherAlert] {
        // This provider is intentionally alert-only. It must never overwrite current,
        // hourly, daily, or minutely weather from the selected forecast provider.
        #if DEBUG
        if let scenario = Self.runtimeMockScenario() {
            let alerts = Self.mockAlerts(scenario: scenario)
            printLog(
                keyword: "weatherAlert",
                content: "Using DEBUG mock alert scenario: \(scenario.rawValue)"
            )
            cacheAlerts(alerts, for: location)
            return alerts
        }
        #endif

        if let cached = cachedAlerts(for: location) {
            return cached
        }

        do {
            let alerts = try await fetchRemoteAlerts(for: location)
            cacheAlerts(alerts, for: location)
            return alerts
        } catch {
            printLog(
                keyword: "weatherAlert",
                content: "\(providerName) failed: \(error.localizedDescription)"
            )
            return cachedAlerts(for: location, allowExpiredCache: true) ?? []
        }
    }

    func cachedAlerts(for location: Location) -> [WeatherAlert]? {
        return cachedAlerts(for: location, allowExpiredCache: false)
    }

    private func cachedAlerts(for location: Location, allowExpiredCache: Bool) -> [WeatherAlert]? {
        lock.lock()
        defer { lock.unlock() }
        guard let cached = cache[location.formattedId] else {
            return nil
        }
        guard allowExpiredCache || Date().timeIntervalSince(cached.date) <= cacheLifetime else {
            return nil
        }
        return cached.alerts.filter { $0.shouldShowHomeNotice }
    }

    private func cacheAlerts(_ alerts: [WeatherAlert], for location: Location) {
        lock.lock()
        cache[location.formattedId] = (Date(), alerts)
        lock.unlock()
    }

    private func fetchRemoteAlerts(for location: Location) async throws -> [WeatherAlert] {
        for provider in remoteProviders {
            do {
                let alerts = try await provider.fetchAlerts(for: location)
                if !alerts.isEmpty {
                    return alerts
                }
            } catch {
                printLog(
                    keyword: "weatherAlert",
                    content: "\(provider.providerName) failed: \(error.localizedDescription)"
                )
            }
        }
        return []
    }

    #if DEBUG
    private static func runtimeMockScenario() -> DebugWeatherAlertScenario? {
        if let value = ProcessInfo.processInfo.environment[DebugKey.mockScenario],
           let scenario = DebugWeatherAlertScenario(rawValue: value) {
            return scenario
        }
        if let value = UserDefaults.standard.string(forKey: DebugKey.mockScenario),
           let scenario = DebugWeatherAlertScenario(rawValue: value) {
            return scenario
        }
        return debugMockAlertsEnabled ? debugMockScenario : nil
    }

    private static func mockAlerts(scenario: DebugWeatherAlertScenario) -> [WeatherAlert] {
        let now = Date().timeIntervalSince1970
        switch scenario {
        case .rainstormYellow:
            return [mockAlert(
                id: 3001,
                time: now,
                description: "暴雨黄色预警",
                content: "当前地区存在暴雨黄色预警，请注意防范。",
                type: "暴雨",
                priority: 2,
                color: 2
            )]
        case .thunderstormOrange:
            return [mockAlert(
                id: 3002,
                time: now,
                description: "雷暴大风橙色预警",
                content: "当前地区存在雷暴大风橙色预警，请注意户外安全。",
                type: "雷暴大风",
                priority: 3,
                color: 3
            )]
        case .windBlue:
            return [mockAlert(
                id: 3003,
                time: now,
                description: "大风蓝色预警",
                content: "当前地区存在大风蓝色预警，请注意防范。",
                type: "大风",
                priority: 1,
                color: 1
            )]
        case .expiredRainstorm:
            return [mockAlert(
                id: 3004,
                time: now - 25 * 60 * 60,
                description: "暴雨橙色预警",
                content: "这是一条用于验证过期过滤的预警。",
                type: "暴雨",
                priority: 3,
                color: 3
            )]
        }
    }

    private static func mockAlert(
        id: Int64,
        time: TimeInterval,
        description: String,
        content: String,
        type: String,
        priority: Int,
        color: Int
    ) -> WeatherAlert {
        return WeatherAlert(
            alertId: id,
            time: time,
            description: description,
            content: content,
            type: type,
            priority: priority,
            color: color
        )
    }
    #endif
}

/// Alert-only fallback based on Breezy Weather's WMO Severe Weather source.
///
/// Breezy Weather's China source also exposes alerts, but it lives in `src_nonfreenet`
/// and uses Xiaomi Weather aggregation endpoints with bundled appKey/sign values. Do
/// not copy those credentials into this iOS app. This provider uses WMO SWIC instead
/// because it is public and keyless, while keeping the same alert-only role split that
/// Breezy uses through `SourceFeature.ALERT`.
final class WmoSevereWeatherAlertProvider: WeatherAlertProvider {

    let providerName = "WMO Severe Weather Information Centre"

    private enum Constant {
        static let baseURL = "https://severeweather.wmo.int/f/wfs"
        static let timeout: TimeInterval = 8
    }

    #if DEBUG
    private enum DebugKey {
        static let forceFailure = "GEOWEATHER_DEBUG_ALERT_FORCE_NETWORK_FAILURE"
    }
    #endif

    func fetchAlerts(for location: Location) async throws -> [WeatherAlert] {
        #if DEBUG
        if ProcessInfo.processInfo.environment[DebugKey.forceFailure] == "1"
            || UserDefaults.standard.bool(forKey: DebugKey.forceFailure) {
            throw WeatherAlertProviderError.debugForcedFailure
        }
        #endif

        let coordinateOrders = [
            (location.longitude, location.latitude),
            // Breezy currently uses this order in its WMO source. Try it as a fallback
            // so we do not silently miss alerts if SWIC geometry expects that variant.
            (location.latitude, location.longitude)
        ]

        for coordinateOrder in coordinateOrders {
            let alerts = try await requestAlerts(
                firstCoordinate: coordinateOrder.0,
                secondCoordinate: coordinateOrder.1
            )
            if !alerts.isEmpty {
                return alerts
            }
        }
        return []
    }

    private func requestAlerts(firstCoordinate: Double, secondCoordinate: Double) async throws -> [WeatherAlert] {
        var components = URLComponents(string: Constant.baseURL)
        let cqlFilter = "INTERSECTS(wkb_geometry, POINT (\(firstCoordinate) \(secondCoordinate))) AND row_type NEQ 'BOUNDARY'"
        components?.queryItems = [
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "version", value: "1.1.0"),
            URLQueryItem(name: "typeName", value: "local_postgis:postgis_geojsons"),
            URLQueryItem(name: "cql_filter", value: cqlFilter),
            URLQueryItem(name: "outputFormat", value: "json")
        ]

        guard let url = components?.url else {
            throw WeatherAlertProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = Constant.timeout
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw WeatherAlertProviderError.invalidResponse
        }

        let result = try JSONDecoder().decode(WmoSevereWeatherAlertResponse.self, from: data)
        return (result.features ?? [])
            .compactMap { convert(feature: $0) }
            .filter { $0.shouldShowHomeNotice }
    }

    private func convert(feature: WmoSevereWeatherAlertFeature) -> WeatherAlert? {
        guard let properties = feature.properties else {
            return nil
        }
        let expires = WeatherAlertDateParser.date(from: properties.expires)
        if let expires = expires, expires <= Date() {
            return nil
        }

        let event = properties.event?.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = properties.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let startDate = WeatherAlertDateParser.date(from: properties.onset)
            ?? WeatherAlertDateParser.date(from: properties.effective)
            ?? WeatherAlertDateParser.date(from: properties.sent)
            ?? Date()

        let title = event?.isEmpty == false ? event! : getLocalizedText("weather_alert")
        let content = description?.isEmpty == false ? description! : getLocalizedText("hourly_notice_weather_alert_subtitle")
        let priority = max(0, min(properties.s ?? 0, 4))
        let idSeed = [
            feature.id,
            properties.identifier,
            properties.capurl,
            properties.url,
            title,
            String(Int(startDate.timeIntervalSince1970))
        ]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: "|")

        return WeatherAlert(
            alertId: WeatherAlertStableID.make(from: idSeed),
            time: startDate.timeIntervalSince1970,
            description: title,
            content: content,
            type: title,
            priority: priority,
            color: priority
        )
    }
}

private enum WeatherAlertProviderError: Error {
    case invalidURL
    case invalidResponse
    #if DEBUG
    case debugForcedFailure
    #endif
}

private struct WmoSevereWeatherAlertResponse: Decodable {
    let features: [WmoSevereWeatherAlertFeature]?
}

private struct WmoSevereWeatherAlertFeature: Decodable {
    let id: String?
    let properties: WmoSevereWeatherAlertProperties?
}

private struct WmoSevereWeatherAlertProperties: Decodable {
    let capurl: String?
    let identifier: String?
    let sent: String?
    let description: String?
    let event: String?
    let s: Int?
    let effective: String?
    let onset: String?
    let url: String?
    let expires: String?
}

private enum WeatherAlertDateParser {

    private static let isoFormatter = ISO8601DateFormatter()

    static func date(from value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        if let date = isoFormatter.date(from: value) {
            return date
        }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        for format in [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss"
        ] {
            fallback.dateFormat = format
            if let date = fallback.date(from: value) {
                return date
            }
        }
        return nil
    }
}

private enum WeatherAlertStableID {

    static func make(from text: String) -> Int64 {
        var hash: UInt64 = 1469598103934665603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int64(bitPattern: hash)
    }
}

enum WeatherAlertProviderBridge {

    static let fallbackProvider = DefaultWeatherAlertFallbackProvider()

    static func fallbackProviderNotice(providerName: String = fallbackProvider.providerName) -> String {
        return "当前天气源暂不提供天气预警信息。为保证恶劣天气提醒完整性，系统将默认使用 \(providerName) 补充预警数据，实时天气与降水数据仍以当前天气源为准。"
    }

    // TODO: When a China alert source is added, fetch fallback alerts here and merge them
    // only into alert eligibility. Fallback alerts must not overwrite current, hourly,
    // daily, or minutely data from the selected forecast provider.
    static func getFallbackAlerts(for location: Location) async throws -> [WeatherAlert] {
        return try await fallbackProvider.fetchAlerts(for: location)
    }

    static func cachedFallbackAlerts(for location: Location) -> [WeatherAlert] {
        return fallbackProvider.cachedAlerts(for: location) ?? []
    }
}
