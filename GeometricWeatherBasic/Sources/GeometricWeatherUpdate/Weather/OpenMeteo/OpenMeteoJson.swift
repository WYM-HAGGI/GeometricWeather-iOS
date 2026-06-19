//
//  OpenMeteoJson.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/16.
//

import Foundation

struct OpenMeteoTime: Codable {

    let value: TimeInterval?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
            return
        }
        if let intValue = try? container.decode(Int.self) {
            self.value = TimeInterval(intValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            if let doubleValue = Double(stringValue) {
                self.value = doubleValue
                return
            }

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]
            if let date = isoFormatter.date(from: stringValue) {
                self.value = date.timeIntervalSince1970
                return
            }

            let fallbackFormatter = ISO8601DateFormatter()
            if let date = fallbackFormatter.date(from: stringValue) {
                self.value = date.timeIntervalSince1970
                return
            }

            self.value = nil
            return
        }

        self.value = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct OpenMeteoGeocodingResponse: Codable {
    let results: [OpenMeteoLocationResult]?
    let generationtimeMs: Double?
    let error: Bool?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case results
        case generationtimeMs = "generationtime_ms"
        case error
        case reason
    }
}

struct OpenMeteoLocationResult: Codable {
    let id: Int?
    let name: String?
    let latitude: Double?
    let longitude: Double?
    let elevation: Double?
    let timezone: String?
    let country: String?
    let countryCode: String?
    let admin1: String?
    let admin2: String?
    let admin3: String?
    let admin4: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case latitude
        case longitude
        case elevation
        case timezone
        case country
        case countryCode = "country_code"
        case admin1
        case admin2
        case admin3
        case admin4
    }
}

struct OpenMeteoForecastResponse: Codable {
    let latitude: Double?
    let longitude: Double?
    let timezone: String?
    let utcOffsetSeconds: Int?
    let current: OpenMeteoCurrent?
    let hourly: OpenMeteoHourly?
    let daily: OpenMeteoDaily?
    let minutely15: OpenMeteoMinutely?
    let error: Bool?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case timezone
        case utcOffsetSeconds = "utc_offset_seconds"
        case current
        case hourly
        case daily
        case minutely15 = "minutely_15"
        case error
        case reason
    }
}

struct OpenMeteoCurrent: Codable {
    let time: OpenMeteoTime?
    let interval: Int?
    let temperature2m: Double?
    let relativeHumidity2m: Double?
    let apparentTemperature: Double?
    let isDay: Int?
    let precipitation: Double?
    let rain: Double?
    let showers: Double?
    let snowfall: Double?
    let weatherCode: Int?
    let cloudCover: Int?
    let pressureMsl: Double?
    let surfacePressure: Double?
    let windSpeed10m: Double?
    let windDirection10m: Double?
    let windGusts10m: Double?

    enum CodingKeys: String, CodingKey {
        case time
        case interval
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case isDay = "is_day"
        case precipitation
        case rain
        case showers
        case snowfall
        case weatherCode = "weather_code"
        case cloudCover = "cloud_cover"
        case pressureMsl = "pressure_msl"
        case surfacePressure = "surface_pressure"
        case windSpeed10m = "wind_speed_10m"
        case windDirection10m = "wind_direction_10m"
        case windGusts10m = "wind_gusts_10m"
    }
}

struct OpenMeteoHourly: Codable {
    let time: [OpenMeteoTime]?
    let temperature2m: [Double?]?
    let relativeHumidity2m: [Double?]?
    let dewPoint2m: [Double?]?
    let apparentTemperature: [Double?]?
    let precipitationProbability: [Double?]?
    let precipitation: [Double?]?
    let rain: [Double?]?
    let showers: [Double?]?
    let snowfall: [Double?]?
    let weatherCode: [Int?]?
    let pressureMsl: [Double?]?
    let surfacePressure: [Double?]?
    let cloudCover: [Double?]?
    let visibility: [Double?]?
    let windSpeed10m: [Double?]?
    let windDirection10m: [Double?]?
    let windGusts10m: [Double?]?
    let uvIndex: [Double?]?
    let isDay: [Int?]?

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case dewPoint2m = "dew_point_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitationProbability = "precipitation_probability"
        case precipitation
        case rain
        case showers
        case snowfall
        case weatherCode = "weather_code"
        case pressureMsl = "pressure_msl"
        case surfacePressure = "surface_pressure"
        case cloudCover = "cloud_cover"
        case visibility
        case windSpeed10m = "wind_speed_10m"
        case windDirection10m = "wind_direction_10m"
        case windGusts10m = "wind_gusts_10m"
        case uvIndex = "uv_index"
        case isDay = "is_day"
    }
}

struct OpenMeteoDaily: Codable {
    let time: [OpenMeteoTime]?
    let weatherCode: [Int?]?
    let temperature2mMax: [Double?]?
    let temperature2mMin: [Double?]?
    let apparentTemperatureMax: [Double?]?
    let apparentTemperatureMin: [Double?]?
    let sunrise: [OpenMeteoTime]?
    let sunset: [OpenMeteoTime]?
    let daylightDuration: [Double?]?
    let sunshineDuration: [Double?]?
    let uvIndexMax: [Double?]?
    let precipitationSum: [Double?]?
    let rainSum: [Double?]?
    let showersSum: [Double?]?
    let snowfallSum: [Double?]?
    let precipitationProbabilityMax: [Double?]?
    let windSpeed10mMax: [Double?]?
    let windGusts10mMax: [Double?]?
    let windDirection10mDominant: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time
        case weatherCode = "weather_code"
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case apparentTemperatureMax = "apparent_temperature_max"
        case apparentTemperatureMin = "apparent_temperature_min"
        case sunrise
        case sunset
        case daylightDuration = "daylight_duration"
        case sunshineDuration = "sunshine_duration"
        case uvIndexMax = "uv_index_max"
        case precipitationSum = "precipitation_sum"
        case rainSum = "rain_sum"
        case showersSum = "showers_sum"
        case snowfallSum = "snowfall_sum"
        case precipitationProbabilityMax = "precipitation_probability_max"
        case windSpeed10mMax = "wind_speed_10m_max"
        case windGusts10mMax = "wind_gusts_10m_max"
        case windDirection10mDominant = "wind_direction_10m_dominant"
    }
}

struct OpenMeteoMinutely: Codable {
    let time: [OpenMeteoTime]?
    let precipitation: [Double?]?
}

struct OpenMeteoAirQualityResponse: Codable {
    let utcOffsetSeconds: Int?
    let hourly: OpenMeteoAirQualityHourly?
    let error: Bool?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case utcOffsetSeconds = "utc_offset_seconds"
        case hourly
        case error
        case reason
    }
}

struct OpenMeteoAirQualityHourly: Codable {
    let time: [OpenMeteoTime]?
    let pm10: [Double?]?
    let pm25: [Double?]?
    let carbonMonoxide: [Double?]?
    let nitrogenDioxide: [Double?]?
    let sulphurDioxide: [Double?]?
    let ozone: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time
        case pm10
        case pm25 = "pm2_5"
        case carbonMonoxide = "carbon_monoxide"
        case nitrogenDioxide = "nitrogen_dioxide"
        case sulphurDioxide = "sulphur_dioxide"
        case ozone
    }
}
