//
//  HourlyWeatherNoticeBuilder.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/18.
//

import Foundation
import GeometricWeatherCore
import GeometricWeatherResources

enum HourlyWeatherNoticeReason {
    case precipitation
    case thunderstorm
    case wind
    case severeWeather
    case alert
}

struct HourlyWeatherNotice {
    let title: String
    let subtitle: String?
    let reason: HourlyWeatherNoticeReason
    let startDate: Date?
    let endDate: Date?
}

struct HourlyWeatherNoticeBuilder {

    static func build(
        for location: Location,
        weather: Weather?,
        fallbackAlerts: [WeatherAlert] = []
    ) -> HourlyWeatherNotice? {
        guard let weather = weather else {
            return nil
        }

        if let alert = (weather.alerts + fallbackAlerts)
            .filter({ $0.shouldShowHomeNotice })
            .sorted(by: sortAlert)
            .first {
            return alertNotice(alert)
        }
        if isSevere(weather.current.weatherCode)
            || upcomingHourlies(weather.hourlyForecasts).contains(where: { isSevere($0.weatherCode) }) {
            return notice(
                titleKey: "hourly_notice_severe_weather_title",
                subtitleKey: "hourly_notice_severe_weather_subtitle",
                reason: .severeWeather
            )
        }
        if weather.current.weatherCode == .thunder
            || weather.current.weatherCode == .thunderstorm
            || upcomingHourlies(weather.hourlyForecasts).contains(where: {
                $0.weatherCode == .thunder || $0.weatherCode == .thunderstorm
            }) {
            return notice(
                titleKey: "hourly_notice_thunderstorm_title",
                subtitleKey: "hourly_notice_thunderstorm_subtitle",
                reason: .thunderstorm
            )
        }
        if hasStrongWind(weather.current.wind)
            || upcomingHourlies(weather.hourlyForecasts).contains(where: { hourly in
                hourly.wind.map(hasStrongWind) ?? false
            }) {
            return notice(
                titleKey: "hourly_notice_wind_title",
                subtitleKey: "hourly_notice_wind_subtitle",
                reason: .wind
            )
        }
        if hasCurrentPrecipitation(weather.current)
            || hasUpcomingMinutelyPrecipitation(weather.minutelyForecast)
            || upcomingHourlies(weather.hourlyForecasts).contains(where: hasUpcomingHourlyPrecipitation) {
            return notice(
                titleKey: "hourly_notice_precipitation_title",
                subtitleKey: "hourly_notice_precipitation_subtitle",
                reason: .precipitation
            )
        }
        return nil
    }

    private static func notice(
        titleKey: String,
        subtitleKey: String,
        reason: HourlyWeatherNoticeReason
    ) -> HourlyWeatherNotice {
        return HourlyWeatherNotice(
            title: getLocalizedText(titleKey),
            subtitle: getLocalizedText(subtitleKey),
            reason: reason,
            startDate: nil,
            endDate: nil
        )
    }

    private static func alertNotice(_ alert: WeatherAlert) -> HourlyWeatherNotice {
        return HourlyWeatherNotice(
            title: alert.noticeTitle,
            subtitle: alert.noticeSubtitle,
            reason: .alert,
            startDate: Date(timeIntervalSince1970: alert.time),
            endDate: nil
        )
    }

    private static func sortAlert(_ lhs: WeatherAlert, _ rhs: WeatherAlert) -> Bool {
        let lhsSeverity = severityRank(lhs.normalizedSeverity)
        let rhsSeverity = severityRank(rhs.normalizedSeverity)
        if lhsSeverity != rhsSeverity {
            return lhsSeverity > rhsSeverity
        }
        return lhs.time > rhs.time
    }

    private static func severityRank(_ severity: WeatherAlertSeverity) -> Int {
        switch severity {
        case .extreme:
            return 4
        case .severe:
            return 3
        case .moderate:
            return 2
        case .minor:
            return 1
        case .unknown:
            return 0
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
        return minutely.precipitationIntensities.prefix(maxCount).contains { intensity in
            intensity >= WeatherEventThresholds.precipitationMmPerHour
        }
    }

    private static func hasUpcomingHourlyPrecipitation(_ hourly: Hourly) -> Bool {
        guard isPrecipitationWeatherCode(hourly.weatherCode),
              !isSevere(hourly.weatherCode) else {
            return false
        }
        return (hourly.precipitationIntensity ?? 0.0) >= WeatherEventThresholds.precipitationMmPerHour
    }

    private static func upcomingHourlies(_ hourlies: [Hourly]) -> [Hourly] {
        let now = Date().timeIntervalSince1970
        let deadline = now + TimeInterval(WeatherEventThresholds.hourlyLookaheadHours * 60 * 60)
        return hourlies.filter { hourly in
            now <= hourly.time && hourly.time <= deadline
        }
    }

    private static func hasStrongWind(_ wind: Wind) -> Bool {
        // Open-Meteo requests wind_speed_unit=ms, so current Open-Meteo weather stores
        // wind speed in m/s. Future multi-source providers should normalize before reuse.
        return (wind.speed ?? 0.0) >= WeatherEventThresholds.strongWindMetersPerSecond
    }

    private static func isSevere(_ weatherCode: WeatherCode) -> Bool {
        switch weatherCode {
        case .thunderstorm, .hail, .sleet(_), .rain(.heavy), .snow(.heavy):
            return true
        default:
            return false
        }
    }
}
