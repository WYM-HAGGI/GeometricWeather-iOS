//
//  AirQualityProvider.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/16.
//

import Foundation
import GeometricWeatherCore

protocol AirQualityProvider {
    var providerName: String { get }
    
    func fetchAirQuality(for location: Location) async throws -> AirQuality
}

enum AirQualityProviderBridge {
    
    // TODO: Open-Meteo AQI is currently estimated from PM2.5 in the weather converter.
    // A future provider should prefer China environmental monitoring, city AQI, or a
    // reliable third-party AQI source, then adapt it to the existing AirQuality model.
    // This bridge must not replace forecast, hourly, daily, minutely, or alert data.
    static var provider: AirQualityProvider? {
        return nil
    }
}
