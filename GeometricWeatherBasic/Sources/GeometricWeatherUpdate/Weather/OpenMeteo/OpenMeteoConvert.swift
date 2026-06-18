//
//  OpenMeteoConvert.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/16.
//

import Foundation
import CoreLocation
import GeometricWeatherCore
import GeometricWeatherResources

enum OpenMeteoConvert {
    
    static func generateLocations(
        from response: OpenMeteoGeocodingResponse,
        src: Location? = nil
    ) -> [Location] {
        return response.results?.compactMap { item in
            generateLocation(from: item, src: src)
        } ?? []
    }
    
    static func generateLocation(
        from result: OpenMeteoLocationResult,
        src: Location? = nil
    ) -> Location? {
        guard
            let latitude = result.latitude,
            let longitude = result.longitude
        else {
            return nil
        }
        
        let cityName = nonEmpty(result.name) ?? fallbackLocationName(latitude: latitude, longitude: longitude)
        let province = nonEmpty(result.admin1) ?? nonEmpty(result.admin2) ?? ""
        let district = nonEmpty(result.admin4) ?? nonEmpty(result.admin3) ?? ""
        
        return Location(
            cityId: result.id.map { String($0) } ?? stableCityId(latitude: latitude, longitude: longitude),
            latitude: latitude,
            longitude: longitude,
            timezone: TimeZone(identifier: result.timezone ?? "") ?? TimeZone.current,
            country: result.country ?? "",
            province: province,
            city: cityName,
            district: district,
            weather: nil,
            weatherSource: .openMeteo,
            currentPosition: src?.currentPosition ?? false,
            residentPosition: src?.residentPosition ?? false
        )
    }
    
    static func generateLocationByCoordinate(target: Location) -> Location {
        return Location(
            cityId: target.usable ? target.cityId : stableCityId(
                latitude: target.latitude,
                longitude: target.longitude
            ),
            latitude: target.latitude,
            longitude: target.longitude,
            timezone: target.timezone,
            country: target.country,
            province: target.province,
            city: nonEmpty(target.city) ?? getLocalizedText("current_location"),
            district: target.district,
            weather: target.weather,
            weatherSource: .openMeteo,
            currentPosition: target.currentPosition,
            residentPosition: target.residentPosition
        )
    }
    
    static func generateLocationByCoordinate(
        target: Location,
        placemark: CLPlacemark
    ) -> Location {
        let location = Location(
            cityId: target.usable ? target.cityId : stableCityId(
                latitude: target.latitude,
                longitude: target.longitude
            ),
            latitude: target.latitude,
            longitude: target.longitude,
            timezone: placemark.timeZone ?? target.timezone,
            country: nonEmpty(placemark.country) ?? target.country,
            province: nonEmpty(placemark.administrativeArea) ?? target.province,
            city: nonEmpty(placemark.locality)
                ?? nonEmpty(placemark.subAdministrativeArea)
                ?? nonEmpty(target.city)
                ?? getLocalizedText("current_location"),
            district: nonEmpty(placemark.subLocality) ?? target.district,
            weather: target.weather,
            weatherSource: .openMeteo,
            currentPosition: target.currentPosition,
            residentPosition: target.residentPosition
        )
        saveLocationDetailText(
            location: location,
            detail: generateDetailAddress(from: placemark)
        )
        return location
    }
    
    static func generateLocation(
        from placemark: CLPlacemark,
        src: Location? = nil
    ) -> Location? {
        guard let coordinate = placemark.location?.coordinate else {
            return nil
        }
        
        let fallbackName = nonEmpty(placemark.name)
            ?? fallbackLocationName(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let location = Location(
            cityId: stableCityId(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timezone: placemark.timeZone ?? TimeZone.current,
            country: nonEmpty(placemark.country) ?? "",
            province: nonEmpty(placemark.administrativeArea) ?? "",
            city: nonEmpty(placemark.locality)
                ?? nonEmpty(placemark.subAdministrativeArea)
                ?? fallbackName,
            district: nonEmpty(placemark.subLocality) ?? "",
            weather: src?.weather,
            weatherSource: .openMeteo,
            currentPosition: src?.currentPosition ?? false,
            residentPosition: src?.residentPosition ?? false
        )
        saveLocationDetailText(
            location: location,
            detail: generateDetailAddress(from: placemark)
        )
        return location
    }
    
    static func generateWeather(
        location: Location,
        forecast: OpenMeteoForecastResponse,
        airQuality: OpenMeteoAirQualityResponse?
    ) -> Weather? {
        guard let current = forecast.current else {
            return nil
        }
        
        let hourlyAirQuality = generateHourlyAirQuality(airQuality?.hourly)
        let currentAirQuality = nearestAirQuality(
            hourlyAirQuality,
            to: current.time?.value ?? Date().timeIntervalSince1970
        )
        
        let hourlies = generateHourlyList(
            hourly: forecast.hourly,
            hourlyAirQuality: hourlyAirQuality
        )
        let dailies = generateDailyList(
            daily: forecast.daily,
            hourlies: hourlies,
            timezone: TimeZone(identifier: forecast.timezone ?? "") ?? location.timezone
        )
        
        return Weather(
            base: Base(
                cityId: location.cityId,
                timeStamp: current.time?.value ?? Date().timeIntervalSince1970
            ),
            current: Current(
                weatherText: OpenMeteoIconMapper.weatherText(from: current.weatherCode),
                weatherCode: OpenMeteoIconMapper.weatherCode(from: current.weatherCode),
                temperature: Temperature(
                    temperature: roundedInt(current.temperature2m),
                    realFeelTemperature: roundedOptionalInt(current.apparentTemperature),
                    apparentTemperature: roundedOptionalInt(current.apparentTemperature)
                ),
                precipitationIntensity: current.precipitation,
                precipitationProbability: nil,
                wind: generateWind(
                    degree: current.windDirection10m,
                    speed: current.windSpeed10m
                ),
                uv: UV(
                    index: nil,
                    level: nil,
                    description: nil
                ),
                airQuality: currentAirQuality ?? emptyAirQuality(),
                relativeHumidity: current.relativeHumidity2m,
                pressure: current.pressureMsl ?? current.surfacePressure,
                visibility: forecast.hourly?.visibility?.compactMap { visibilityInKilometers($0) }.first,
                dewPoint: nil,
                cloudCover: current.cloudCover,
                ceiling: nil,
                dailyForecast: nil,
                hourlyForecast: nil
            ),
            yesterday: nil,
            dailyForecasts: dailies,
            hourlyForecasts: hourlies,
            minutelyForecast: generateMinutely(forecast.minutely15),
            alerts: []
        )
    }
    
    private static func generateHourlyList(
        hourly: OpenMeteoHourly?,
        hourlyAirQuality: [TimeInterval: AirQuality]
    ) -> [Hourly] {
        guard let time = hourly?.time else {
            return []
        }
        
        let maxCount = min(time.count, 72)
        var result = [Hourly]()
        for index in 0 ..< maxCount {
            guard let timestamp = time.get(index)?.value else {
                continue
            }
            
            let weatherCode = hourly?.weatherCode?.get(index) ?? nil
            let airQuality = nearestAirQuality(hourlyAirQuality, to: timestamp)
            result.append(
                Hourly(
                    time: timestamp,
                    daylight: (hourly?.isDay?.get(index) ?? nil) == 1,
                    weatherText: OpenMeteoIconMapper.weatherText(from: weatherCode),
                    weatherCode: OpenMeteoIconMapper.weatherCode(from: weatherCode),
                    temperature: Temperature(
                        temperature: roundedInt(hourly?.temperature2m?.get(index) ?? nil),
                        realFeelTemperature: roundedOptionalInt(hourly?.apparentTemperature?.get(index) ?? nil),
                        apparentTemperature: roundedOptionalInt(hourly?.apparentTemperature?.get(index) ?? nil)
                    ),
                    precipitationIntensity: hourly?.precipitation?.get(index) ?? nil,
                    precipitationProbability: hourly?.precipitationProbability?.get(index) ?? nil,
                    wind: generateWind(
                        degree: hourly?.windDirection10m?.get(index) ?? nil,
                        speed: hourly?.windSpeed10m?.get(index) ?? nil
                    ),
                    cloudrate: (hourly?.cloudCover?.get(index) ?? nil).map { $0 / 100.0 },
                    pressure: hourly?.pressureMsl?.get(index) ?? hourly?.surfacePressure?.get(index) ?? nil,
                    visibility: visibilityInKilometers(hourly?.visibility?.get(index) ?? nil),
                    airQuality: airQuality,
                    humidity: hourly?.relativeHumidity2m?.get(index) ?? nil
                )
            )
        }
        return result
    }
    
    private static func generateDailyList(
        daily: OpenMeteoDaily?,
        hourlies: [Hourly],
        timezone: TimeZone
    ) -> [Daily] {
        guard let time = daily?.time else {
            return []
        }
        
        let maxCount = min(time.count, 15)
        var result = [Daily]()
        for index in 0 ..< maxCount {
            guard let timestamp = time.get(index)?.value else {
                continue
            }
            
            let weatherCode = daily?.weatherCode?.get(index) ?? nil
            let text = OpenMeteoIconMapper.weatherText(from: weatherCode)
            let code = OpenMeteoIconMapper.weatherCode(from: weatherCode)
            let dayHourly = hourliesForDay(timestamp, hourlies: hourlies, timezone: timezone)
            let representativeWind = generateWind(
                degree: daily?.windDirection10mDominant?.get(index) ?? nil,
                speed: daily?.windSpeed10mMax?.get(index) ?? nil
            )
            let dayTemperature = roundedInt(daily?.temperature2mMax?.get(index) ?? nil)
            let nightTemperature = roundedInt(daily?.temperature2mMin?.get(index) ?? nil)
            
            result.append(
                Daily(
                    time: timestamp,
                    day: HalfDay(
                        weatherText: text,
                        weatherPhase: getLocalizedText("daytime"),
                        weatherCode: code,
                        temperature: Temperature(
                            temperature: dayTemperature,
                            realFeelTemperature: roundedOptionalInt(daily?.apparentTemperatureMax?.get(index) ?? nil),
                            apparentTemperature: roundedOptionalInt(daily?.apparentTemperatureMax?.get(index) ?? nil)
                        ),
                        precipitationTotal: daily?.precipitationSum?.get(index) ?? nil,
                        precipitationIntensity: daily?.precipitationSum?.get(index) ?? nil,
                        precipitationProbability: daily?.precipitationProbabilityMax?.get(index) ?? nil,
                        wind: representativeWind,
                        cloudCover: nil,
                        pressure: average(dayHourly.compactMap { $0.pressure }),
                        visibility: average(dayHourly.compactMap { $0.visibility }),
                        humidity: average(dayHourly.compactMap { $0.humidity })
                    ),
                    night: HalfDay(
                        weatherText: text,
                        weatherPhase: getLocalizedText("nighttime"),
                        weatherCode: code,
                        temperature: Temperature(
                            temperature: nightTemperature,
                            realFeelTemperature: roundedOptionalInt(daily?.apparentTemperatureMin?.get(index) ?? nil),
                            apparentTemperature: roundedOptionalInt(daily?.apparentTemperatureMin?.get(index) ?? nil)
                        ),
                        precipitationTotal: daily?.precipitationSum?.get(index) ?? nil,
                        precipitationIntensity: daily?.precipitationSum?.get(index) ?? nil,
                        precipitationProbability: daily?.precipitationProbabilityMax?.get(index) ?? nil,
                        wind: representativeWind,
                        cloudCover: nil,
                        pressure: average(dayHourly.compactMap { $0.pressure }),
                        visibility: average(dayHourly.compactMap { $0.visibility }),
                        humidity: average(dayHourly.compactMap { $0.humidity })
                    ),
                    sun: Astro(
                        riseTime: daily?.sunrise?.get(index)?.value,
                        setTime: daily?.sunset?.get(index)?.value
                    ),
                    moon: Astro(
                        riseTime: nil,
                        setTime: nil
                    ),
                    moonPhase: MoonPhase(
                        angle: nil,
                        description: nil
                    ),
                    precipitationTotal: daily?.precipitationSum?.get(index) ?? nil,
                    precipitationIntensity: daily?.precipitationSum?.get(index) ?? nil,
                    precipitationProbability: daily?.precipitationProbabilityMax?.get(index) ?? nil,
                    wind: representativeWind,
                    airQuality: emptyAirQuality(),
                    pollen: emptyPollen(),
                    uv: UV(
                        index: roundedOptionalInt(daily?.uvIndexMax?.get(index) ?? nil),
                        level: nil,
                        description: nil
                    ),
                    hoursOfSun: (daily?.sunshineDuration?.get(index) ?? nil).map { $0 / 3600.0 },
                    pressure: average(dayHourly.compactMap { $0.pressure }),
                    cloudrate: average(dayHourly.compactMap { $0.cloudrate }),
                    visibility: average(dayHourly.compactMap { $0.visibility }),
                    humidity: average(dayHourly.compactMap { $0.humidity })
                )
            )
        }
        return result
    }
    
    private static func generateMinutely(_ minutely: OpenMeteoMinutely?) -> Minutely? {
        guard
            let times = minutely?.time,
            let first = times.first?.value,
            let last = times.last?.value
        else {
            return nil
        }
        
        let intensities = minutely?.precipitation?
            .compactMap { value in
                value.map { $0 * 4.0 }
            } ?? []
        if intensities.count < 2 {
            return nil
        }
        return Minutely(
            beginTime: first,
            endTime: last,
            precipitationIntensities: intensities
        )
    }
    
    private static func generateHourlyAirQuality(_ hourly: OpenMeteoAirQualityHourly?) -> [TimeInterval: AirQuality] {
        guard let times = hourly?.time else {
            return [:]
        }
        
        var result = [TimeInterval: AirQuality]()
        for index in 0 ..< times.count {
            guard let time = times.get(index)?.value else {
                continue
            }
            let pm25 = hourly?.pm25?.get(index) ?? nil
            let pm10 = hourly?.pm10?.get(index) ?? nil
            let aqiIndex = pm25.map { estimateAqi(pm25: $0) }
            result[time] = AirQuality(
                aqiLevel: aqiIndex.map { getAqiQualityInt(index: $0) },
                aqiIndex: aqiIndex,
                pm25: pm25,
                pm10: pm10,
                so2: hourly?.sulphurDioxide?.get(index) ?? nil,
                no2: hourly?.nitrogenDioxide?.get(index) ?? nil,
                o3: hourly?.ozone?.get(index) ?? nil,
                co: (hourly?.carbonMonoxide?.get(index) ?? nil).map { $0 / 1000.0 }
            )
        }
        return result
    }
    
    private static func nearestAirQuality(
        _ airQuality: [TimeInterval: AirQuality],
        to timestamp: TimeInterval
    ) -> AirQuality? {
        airQuality.min { first, second in
            abs(first.key - timestamp) < abs(second.key - timestamp)
        }?.value
    }
    
    private static func generateWind(
        degree: Double?,
        speed: Double?
    ) -> Wind {
        return Wind(
            direction: getWindDirectionText(degree),
            degree: WindDegree(
                degree: degree ?? 0,
                noDirection: degree == nil
            ),
            speed: speed,
            level: getWindLevelInt(speed: speed ?? 0)
        )
    }
    
    private static func getWindDirectionText(_ degree: Double?) -> String? {
        guard let degree = degree else {
            return nil
        }
        let d = degree.truncatingRemainder(dividingBy: 360.0)
        if 348.75 < d || d <= 11.25 {
            return getLocalizedText("wind_direction_n")
        }
        if 11.25 < d && d <= 33.75 {
            return getLocalizedText("wind_direction_nne")
        }
        if 33.75 < d && d <= 56.25 {
            return getLocalizedText("wind_direction_ne")
        }
        if 56.25 < d && d <= 78.75 {
            return getLocalizedText("wind_direction_ene")
        }
        if 78.75 < d && d <= 101.25 {
            return getLocalizedText("wind_direction_e")
        }
        if 101.25 < d && d <= 123.75 {
            return getLocalizedText("wind_direction_ese")
        }
        if 123.75 < d && d <= 146.25 {
            return getLocalizedText("wind_direction_se")
        }
        if 146.25 < d && d <= 168.75 {
            return getLocalizedText("wind_direction_sse")
        }
        if 168.75 < d && d <= 191.25 {
            return getLocalizedText("wind_direction_s")
        }
        if 191.25 < d && d <= 213.75 {
            return getLocalizedText("wind_direction_ssw")
        }
        if 213.75 < d && d <= 236.25 {
            return getLocalizedText("wind_direction_sw")
        }
        if 236.25 < d && d <= 258.75 {
            return getLocalizedText("wind_direction_wsw")
        }
        if 258.75 < d && d <= 281.25 {
            return getLocalizedText("wind_direction_w")
        }
        if 281.25 < d && d <= 303.75 {
            return getLocalizedText("wind_direction_wnw")
        }
        if 303.75 < d && d <= 326.25 {
            return getLocalizedText("wind_direction_nw")
        }
        return getLocalizedText("wind_direction_nnw")
    }
    
    private static func hourliesForDay(
        _ day: TimeInterval,
        hourlies: [Hourly],
        timezone: TimeZone
    ) -> [Hourly] {
        let calendar = Calendar.current
        let dayDate = Date(timeIntervalSince1970: day)
        return hourlies.filter { hourly in
            calendar.isDate(
                Date(timeIntervalSince1970: hourly.time),
                inSameDayAs: dayDate
            )
        }
    }
    
    private static func roundedInt(_ value: Double?) -> Int {
        return Int((value ?? 0).rounded())
    }
    
    private static func roundedOptionalInt(_ value: Double?) -> Int? {
        return value.map { Int($0.rounded()) }
    }
    
    private static func visibilityInKilometers(_ meters: Double?) -> Double? {
        // Open-Meteo visibility is returned in meters. The app's DistanceUnit
        // uses kilometers as its default model unit before formatting.
        return meters.map { $0 / 1000.0 }
    }
    
    private static func average(_ values: [Double]) -> Double? {
        if values.isEmpty {
            return nil
        }
        return values.reduce(0, +) / Double(values.count)
    }
    
    private static func emptyAirQuality() -> AirQuality {
        return AirQuality(
            aqiLevel: nil,
            aqiIndex: nil,
            pm25: nil,
            pm10: nil,
            so2: nil,
            no2: nil,
            o3: nil,
            co: nil
        )
    }
    
    private static func emptyPollen() -> Pollen {
        return Pollen(
            grassIndex: nil,
            grassLevel: nil,
            grassDescription: nil,
            moldIndex: nil,
            moldLevel: nil,
            moldDescription: nil,
            ragweedIndex: nil,
            ragweedLevel: nil,
            ragweedDescription: nil,
            treeIndex: nil,
            treeLevel: nil,
            treeDescription: nil
        )
    }
    
    private static func estimateAqi(pm25: Double) -> Int {
        if pm25 <= 12 {
            return Int(pm25 / 12.0 * 50.0)
        }
        if pm25 <= 35.4 {
            return Int(51.0 + (pm25 - 12.1) / (35.4 - 12.1) * 49.0)
        }
        if pm25 <= 55.4 {
            return Int(101.0 + (pm25 - 35.5) / (55.4 - 35.5) * 49.0)
        }
        if pm25 <= 150.4 {
            return Int(151.0 + (pm25 - 55.5) / (150.4 - 55.5) * 49.0)
        }
        if pm25 <= 250.4 {
            return Int(201.0 + (pm25 - 150.5) / (250.4 - 150.5) * 99.0)
        }
        return 301
    }
    
    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
    
    private static func generateDetailAddress(from placemark: CLPlacemark) -> String? {
        let compact = shouldCompactPlacemark(placemark)
        var detail = joinUnique(
            [
                nonEmpty(placemark.administrativeArea),
                nonEmpty(placemark.locality) ?? nonEmpty(placemark.subAdministrativeArea),
                nonEmpty(placemark.subLocality),
                nonEmpty(placemark.thoroughfare),
                nonEmpty(placemark.subThoroughfare)
            ],
            compact: compact
        )
        
        if detail.isEmpty {
            detail = joinUnique(
                [
                    nonEmpty(placemark.country),
                    nonEmpty(placemark.locality)
                        ?? nonEmpty(placemark.subAdministrativeArea)
                        ?? nonEmpty(placemark.name)
                ],
                compact: compact
            )
        }
        
        if detail.isEmpty {
            return nil
        }
        if compact,
           nonEmpty(placemark.thoroughfare) != nil,
           nonEmpty(placemark.subThoroughfare) == nil,
           !detail.hasSuffix(getLocalizedText("nearby_suffix")) {
            detail += getLocalizedText("nearby_suffix")
        }
        return detail
    }
    
    private static func joinUnique(_ parts: [String?], compact: Bool) -> String {
        var result = [String]()
        for part in parts {
            guard let part = part, !result.contains(part) else {
                continue
            }
            result.append(part)
        }
        return result.joined(separator: compact ? "" : ", ")
    }
    
    private static func shouldCompactPlacemark(_ placemark: CLPlacemark) -> Bool {
        return [
            placemark.country,
            placemark.administrativeArea,
            placemark.locality,
            placemark.subAdministrativeArea,
            placemark.subLocality,
            placemark.thoroughfare
        ].contains { text in
            text?.range(of: "\\p{Han}", options: .regularExpression) != nil
        }
    }
    
    static func stableCityId(latitude: Double, longitude: Double) -> String {
        return "openmeteo_\(String(format: "%.4f", latitude))_\(String(format: "%.4f", longitude))"
    }
    
    private static func fallbackLocationName(latitude: Double, longitude: Double) -> String {
        return String(format: "%.4f, %.4f", latitude, longitude)
    }
}
