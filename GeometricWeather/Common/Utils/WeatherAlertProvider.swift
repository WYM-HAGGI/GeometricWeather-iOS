//
//  WeatherAlertProvider.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/16.
//

import Foundation
import GeometricWeatherCore

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
            // Existing WeatherAlert has no provider-normalized severity field. Until each
            // provider maps severity explicitly, recent unknown alerts are treated as eligible
            // because the source has already decided to issue an alert.
            return true
        }
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
}

final class DefaultWeatherAlertFallbackProvider: WeatherAlertProvider {
    
    let providerName = "Default weather alert fallback"
    
    func fetchAlerts(for location: Location) async throws -> [WeatherAlert] {
        // This provider is intentionally alert-only. It must never overwrite current,
        // hourly, daily, or minutely weather from the selected forecast provider.
        // TODO: Connect a China Weather/CNMC/CaiYun/other reliable alert source here.
        return []
    }
}

enum WeatherAlertProviderBridge {
    
    static let fallbackProvider: WeatherAlertProvider = DefaultWeatherAlertFallbackProvider()
    
    static func fallbackProviderNotice(providerName: String = fallbackProvider.providerName) -> String {
        return "当前天气源暂不提供天气预警信息。为保证恶劣天气提醒完整性，系统将默认使用 \(providerName) 补充预警数据，实时天气与降水数据仍以当前天气源为准。"
    }
    
    // TODO: When a China alert source is added, fetch fallback alerts here and merge them
    // only into alert eligibility. Fallback alerts must not overwrite current, hourly,
    // daily, or minutely data from the selected forecast provider.
    static func getFallbackAlerts(for location: Location) async throws -> [WeatherAlert] {
        return try await fallbackProvider.fetchAlerts(for: location)
    }
}
