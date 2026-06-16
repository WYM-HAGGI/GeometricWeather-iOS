//
//  LiveActivityWeatherEligibility.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/16.
//

import Foundation
import GeometricWeatherCore

enum LiveActivityReason {
    case precipitation
    case severeWeather
    case alert
}

struct LiveActivityWeatherEligibility {
    
    // Verification cases for a future test target:
    // clear/cloudy/fog + precipitation 0 => nil
    // drizzle/light rain + precipitation 0 => nil
    // light rain + precipitation >= 0.3 mm/h => .precipitation
    // minutely values below 0.3 mm/h => nil
    // minutely value >= 0.3 mm/h in the next 60 minutes => .precipitation
    // thunderstorm/hail/heavy snow => .severeWeather
    // recent alert => .alert, old alert => nil
    private enum Threshold {
        static let precipitationMmPerHour = 0.3
        static let lookaheadMinutes = 60
        static let hourlyLookaheadHours = 2
        static let alertMaxAge: TimeInterval = 24 * 60 * 60
    }
    
    static func reason(for location: Location) -> LiveActivityReason? {
        guard let weather = location.weather else {
            return nil
        }
        
        if hasValidAlert(weather.alerts) {
            return .alert
        }
        if isSevere(weather.current.weatherCode) || hasSevereHourlyWeather(weather.hourlyForecasts) {
            return .severeWeather
        }
        if hasCurrentPrecipitation(weather.current)
            || hasUpcomingMinutelyPrecipitation(weather.minutelyForecast)
            || hasUpcomingHourlyPrecipitation(weather.hourlyForecasts) {
            return .precipitation
        }
        return nil
    }
    
    static func fallbackMinutely(for location: Location) -> Minutely {
        let beginTime = Date().timeIntervalSince1970
        return Minutely(
            beginTime: beginTime,
            endTime: beginTime + TimeInterval(Threshold.lookaheadMinutes * 60),
            precipitationIntensities: [0.0, 0.0]
        )
    }
    
    private static func hasValidAlert(_ alerts: [WeatherAlert]) -> Bool {
        let now = Date().timeIntervalSince1970
        return alerts.contains { alert in
            // WeatherAlert currently has no expiration timestamp. Treat recent alerts as active
            // until source-specific alert expiry is added by a future WeatherAlertProvider.
            alert.time >= now - Threshold.alertMaxAge
        }
    }
    
    private static func hasCurrentPrecipitation(_ current: Current) -> Bool {
        guard isPrecipitationWeatherCode(current.weatherCode),
              !isSevere(current.weatherCode) else {
            return false
        }
        return (current.precipitationIntensity ?? 0.0) >= Threshold.precipitationMmPerHour
    }
    
    private static func hasUpcomingMinutelyPrecipitation(_ minutely: Minutely?) -> Bool {
        guard let minutely = minutely else {
            return false
        }
        
        let duration = max(minutely.endTime - minutely.beginTime, 1.0)
        let secondsPerItem = duration / Double(max(minutely.precipitationIntensities.count - 1, 1))
        let maxCount = min(
            minutely.precipitationIntensities.count,
            Int(ceil(TimeInterval(Threshold.lookaheadMinutes * 60) / secondsPerItem)) + 1
        )
        
        // Open-Meteo minutely_15 is converted to project precipitation intensity in mm/h
        // in OpenMeteoConvert before creating Minutely. Other providers should also store
        // Minutely.precipitationIntensities as mm/h.
        return minutely.precipitationIntensities.prefix(maxCount).contains { intensity in
            intensity >= Threshold.precipitationMmPerHour
        }
    }
    
    private static func hasUpcomingHourlyPrecipitation(_ hourlies: [Hourly]) -> Bool {
        let now = Date().timeIntervalSince1970
        let deadline = now + TimeInterval(Threshold.hourlyLookaheadHours * 60 * 60)
        return hourlies.contains { hourly in
            guard now <= hourly.time && hourly.time <= deadline,
                  isPrecipitationWeatherCode(hourly.weatherCode),
                  !isSevere(hourly.weatherCode) else {
                return false
            }
            // Hourly precipitation from Open-Meteo represents hourly accumulation in mm,
            // equivalent to average mm/h across that hour for eligibility purposes.
            return (hourly.precipitationIntensity ?? 0.0) >= Threshold.precipitationMmPerHour
        }
    }
    
    private static func hasSevereHourlyWeather(_ hourlies: [Hourly]) -> Bool {
        let now = Date().timeIntervalSince1970
        let deadline = now + TimeInterval(Threshold.hourlyLookaheadHours * 60 * 60)
        return hourlies.contains { hourly in
            now <= hourly.time && hourly.time <= deadline && isSevere(hourly.weatherCode)
        }
    }
    
    private static func isSevere(_ weatherCode: WeatherCode) -> Bool {
        switch weatherCode {
        case .thunderstorm, .hail, .sleet(_):
            return true
        case .rain(.heavy), .snow(.heavy):
            return true
        default:
            return false
        }
    }
}
