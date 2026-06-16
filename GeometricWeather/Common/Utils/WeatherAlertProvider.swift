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
    
    func getAlerts(for location: Location) async throws -> [WeatherAlert]
}

struct EmptyWeatherAlertProvider: WeatherAlertProvider {
    
    let providerName = "None"
    
    func getAlerts(for location: Location) async throws -> [WeatherAlert] {
        return []
    }
}

enum WeatherAlertProviderBridge {
    
    static let fallbackProvider: WeatherAlertProvider = EmptyWeatherAlertProvider()
    
    static let fallbackProviderNotice = "当前天气源暂不提供天气预警信息。为保证恶劣天气提醒完整性，系统将默认使用备用天气源补充预警数据，实时天气与降水数据仍以当前天气源为准。"
    
    // TODO: When a China alert source is added, fetch fallback alerts here and merge them
    // only into alert eligibility. Fallback alerts must not overwrite current, hourly,
    // daily, or minutely data from the selected forecast provider.
    static func getFallbackAlerts(for location: Location) async throws -> [WeatherAlert] {
        return try await fallbackProvider.getAlerts(for: location)
    }
}
