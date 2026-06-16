//
//  OpenMeteoIconMapper.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/16.
//

import Foundation
import GeometricWeatherCore
import GeometricWeatherResources

enum OpenMeteoIconMapper {
    
    static func weatherCode(from code: Int?) -> WeatherCode {
        guard let code = code else {
            return .cloudy
        }
        
        switch code {
        case 0, 1:
            return .clear
        case 2:
            return .partlyCloudy
        case 3:
            return .cloudy
        case 45, 48:
            return .fog
        case 51, 53, 55, 56, 57, 61, 66, 80:
            return .rain(.light)
        case 63, 67, 81:
            return .rain(.middle)
        case 65, 82:
            return .rain(.heavy)
        case 71, 85:
            return .snow(.light)
        case 73:
            return .snow(.middle)
        case 75, 86:
            return .snow(.heavy)
        case 77:
            return .sleet(.light)
        case 95:
            return .thunderstorm
        case 96, 99:
            return .hail
        default:
            return .cloudy
        }
    }
    
    static func weatherText(from code: Int?) -> String {
        guard let code = code else {
            return getLocalizedText("weather_cloudy")
        }
        
        switch code {
        case 0:
            return getLocalizedText("weather_clear")
        case 1:
            return getLocalizedText("openmeteo_weather_mainly_clear")
        case 2:
            return getLocalizedText("weather_partly_cloudy")
        case 3:
            return getLocalizedText("weather_cloudy")
        case 45:
            return getLocalizedText("weather_fog")
        case 48:
            return getLocalizedText("openmeteo_weather_rime_fog")
        case 51:
            return getLocalizedText("openmeteo_weather_drizzle_light")
        case 53:
            return getLocalizedText("openmeteo_weather_drizzle_moderate")
        case 55:
            return getLocalizedText("openmeteo_weather_drizzle_heavy")
        case 56:
            return getLocalizedText("openmeteo_weather_freezing_drizzle_light")
        case 57:
            return getLocalizedText("openmeteo_weather_freezing_drizzle_heavy")
        case 61:
            return getLocalizedText("weather_light_rain")
        case 63:
            return getLocalizedText("weather_moderate_rain")
        case 65:
            return getLocalizedText("weather_heavy_rain")
        case 66:
            return getLocalizedText("openmeteo_weather_freezing_rain_light")
        case 67:
            return getLocalizedText("openmeteo_weather_freezing_rain_heavy")
        case 71:
            return getLocalizedText("weather_light_snow")
        case 73:
            return getLocalizedText("weather_moderate_snow")
        case 75:
            return getLocalizedText("weather_heavy_snow")
        case 77:
            return getLocalizedText("openmeteo_weather_snow_grains")
        case 80:
            return getLocalizedText("openmeteo_weather_rain_showers_light")
        case 81:
            return getLocalizedText("openmeteo_weather_rain_showers_moderate")
        case 82:
            return getLocalizedText("openmeteo_weather_rain_showers_heavy")
        case 85:
            return getLocalizedText("openmeteo_weather_snow_showers_light")
        case 86:
            return getLocalizedText("openmeteo_weather_snow_showers_heavy")
        case 95:
            return getLocalizedText("weather_thunderstorm")
        case 96:
            return getLocalizedText("openmeteo_weather_thunderstorm_light_hail")
        case 99:
            return getLocalizedText("openmeteo_weather_thunderstorm_heavy_hail")
        default:
            return getLocalizedText("weather_cloudy")
        }
    }
}
