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

    static func reason(
        for location: Location,
        alertProvider: WeatherAlertProvider?
    ) async -> LiveActivityReason? {
        if let reason = reason(for: location) {
            return reason
        }
        guard let alertProvider = alertProvider else {
            return nil
        }

        do {
            let alerts = try await alertProvider.fetchAlerts(for: location)
            return hasValidAlert(alerts) ? .alert : nil
        } catch {
            printLog(
                keyword: "liveActivity",
                content: "Fallback alert provider \(alertProvider.providerName) failed: \(error.localizedDescription)"
            )
            return nil
        }
    }

    static func fallbackMinutely(for location: Location) -> Minutely {
        let beginTime = Date().timeIntervalSince1970
        return Minutely(
            beginTime: beginTime,
            endTime: beginTime + TimeInterval(WeatherEventThresholds.minutelyLookaheadMinutes * 60),
            precipitationIntensities: [0.0, 0.0]
        )
    }

    private static func hasValidAlert(_ alerts: [WeatherAlert]) -> Bool {
        return alerts.contains { alert in
            WeatherAlertValidation.isLiveActivityEligible(alert)
        }
    }

    private static func hasCurrentPrecipitation(_ current: Current) -> Bool {
        guard isPrecipitationWeatherCode(current.weatherCode),
              !isSevere(current.weatherCode) else {
            return false
        }
        return (current.precipitationIntensity ?? 0.0) >= WeatherEventThresholds.precipitationMmPerHour
    }

    private static func hasUpcomingMinutelyPrecipitation(_ minutely: Minutely?) -> Bool {
        guard let minutely = minutely else {
            return false
        }

        let duration = max(minutely.endTime - minutely.beginTime, 1.0)
        let secondsPerItem = duration / Double(max(minutely.precipitationIntensities.count - 1, 1))
        let maxCount = min(
            minutely.precipitationIntensities.count,
            Int(ceil(TimeInterval(WeatherEventThresholds.minutelyLookaheadMinutes * 60) / secondsPerItem)) + 1
        )

        // Open-Meteo minutely_15 is converted to project precipitation intensity in mm/h
        // in OpenMeteoConvert before creating Minutely. Other providers should also store
        // Minutely.precipitationIntensities as mm/h.
        return minutely.precipitationIntensities.prefix(maxCount).contains { intensity in
            intensity >= WeatherEventThresholds.precipitationMmPerHour
        }
    }

    private static func hasUpcomingHourlyPrecipitation(_ hourlies: [Hourly]) -> Bool {
        let now = Date().timeIntervalSince1970
        let deadline = now + TimeInterval(WeatherEventThresholds.hourlyLookaheadHours * 60 * 60)
        return hourlies.contains { hourly in
            guard now <= hourly.time && hourly.time <= deadline,
                  isPrecipitationWeatherCode(hourly.weatherCode),
                  !isSevere(hourly.weatherCode) else {
                return false
            }
            // Hourly precipitation from Open-Meteo represents hourly accumulation in mm,
            // equivalent to average mm/h across that hour for eligibility purposes.
            return (hourly.precipitationIntensity ?? 0.0) >= WeatherEventThresholds.precipitationMmPerHour
        }
    }

    private static func hasSevereHourlyWeather(_ hourlies: [Hourly]) -> Bool {
        let now = Date().timeIntervalSince1970
        let deadline = now + TimeInterval(WeatherEventThresholds.hourlyLookaheadHours * 60 * 60)
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
