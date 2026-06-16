//
//  OpenMeteoApi.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/16.
//

import Foundation
import GeometricWeatherCore

public final class OpenMeteoApi: WeatherApi {
    
    private let service = OpenMeteoService()
    
    public init() {
        // do nothing.
    }
    
    public func getLocation(
        _ query: String,
        callback: @escaping ([Location]) -> Void
    ) {
        service.searchLocation(query: query) { result in
            switch result {
            case .success(let response):
                callback(OpenMeteoConvert.generateLocations(from: response))
            case .failure(let error):
                printLog(keyword: "network", content: "Open-Meteo location search error: \(error)")
                callback([])
            }
        }
    }
    
    public func getGeoPosition(
        target: Location,
        callback: @escaping (Location?) -> Void
    ) {
        callback(OpenMeteoConvert.generateLocationByCoordinate(target: target))
    }
    
    public func getWeather(
        target: Location,
        units: UnitSet,
        callback: @escaping (Weather?) -> Void
    ) {
        service.requestForecast(
            latitude: target.latitude,
            longitude: target.longitude,
            timezone: target.timezone.identifier
        ) { [weak self] forecastResult in
            switch forecastResult {
            case .success(let forecast):
                self?.service.requestAirQuality(
                    latitude: target.latitude,
                    longitude: target.longitude,
                    timezone: target.timezone.identifier
                ) { airQualityResult in
                    let airQuality = try? airQualityResult.get()
                    callback(
                        OpenMeteoConvert.generateWeather(
                            location: target,
                            forecast: forecast,
                            airQuality: airQuality
                        )
                    )
                }
            case .failure(let error):
                printLog(keyword: "network", content: "Open-Meteo weather request error: \(error)")
                callback(nil)
            }
        }
    }
    
    public func cancel() {
        service.cancel()
    }
}
