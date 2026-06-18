//
//  OpenMeteoService.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/16.
//

import Foundation

final class OpenMeteoService {
    
    private let session: URLSession
    private var tasks = [URLSessionDataTask]()
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func searchLocation(
        query: String,
        language: String? = nil,
        completion: @escaping (Result<OpenMeteoGeocodingResponse, Error>) -> Void
    ) {
        var queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "format", value: "json")
        ]
        if let language = language, !language.isEmpty {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }
        
        request(
            base: "https://geocoding-api.open-meteo.com/v1/search",
            queryItems: queryItems,
            completion: completion
        )
    }
    
    func requestForecast(
        latitude: Double,
        longitude: Double,
        timezone: String?,
        completion: @escaping (Result<OpenMeteoForecastResponse, Error>) -> Void
    ) {
        request(
            base: "https://api.open-meteo.com/v1/forecast",
            queryItems: [
                URLQueryItem(name: "latitude", value: "\(latitude)"),
                URLQueryItem(name: "longitude", value: "\(longitude)"),
                URLQueryItem(name: "timezone", value: timezone?.isEmpty == false ? timezone : "auto"),
                URLQueryItem(name: "timeformat", value: "unixtime"),
                URLQueryItem(name: "forecast_days", value: "15"),
                URLQueryItem(name: "current", value: [
                    "temperature_2m",
                    "relative_humidity_2m",
                    "apparent_temperature",
                    "is_day",
                    "precipitation",
                    "rain",
                    "showers",
                    "snowfall",
                    "weather_code",
                    "cloud_cover",
                    "pressure_msl",
                    "surface_pressure",
                    "wind_speed_10m",
                    "wind_direction_10m",
                    "wind_gusts_10m"
                ].joined(separator: ",")),
                URLQueryItem(name: "hourly", value: [
                    "temperature_2m",
                    "relative_humidity_2m",
                    "dew_point_2m",
                    "apparent_temperature",
                    "precipitation_probability",
                    "precipitation",
                    "rain",
                    "showers",
                    "snowfall",
                    "weather_code",
                    "pressure_msl",
                    "surface_pressure",
                    "cloud_cover",
                    "visibility",
                    "wind_speed_10m",
                    "wind_direction_10m",
                    "wind_gusts_10m",
                    "uv_index",
                    "is_day"
                ].joined(separator: ",")),
                URLQueryItem(name: "daily", value: [
                    "weather_code",
                    "temperature_2m_max",
                    "temperature_2m_min",
                    "apparent_temperature_max",
                    "apparent_temperature_min",
                    "sunrise",
                    "sunset",
                    "daylight_duration",
                    "sunshine_duration",
                    "uv_index_max",
                    "precipitation_sum",
                    "rain_sum",
                    "showers_sum",
                    "snowfall_sum",
                    "precipitation_probability_max",
                    "wind_speed_10m_max",
                    "wind_gusts_10m_max",
                    "wind_direction_10m_dominant"
                ].joined(separator: ",")),
                URLQueryItem(name: "minutely_15", value: "precipitation"),
                URLQueryItem(name: "wind_speed_unit", value: "ms")
            ],
            completion: completion
        )
    }
    
    func requestAirQuality(
        latitude: Double,
        longitude: Double,
        timezone: String?,
        completion: @escaping (Result<OpenMeteoAirQualityResponse, Error>) -> Void
    ) {
        request(
            base: "https://air-quality-api.open-meteo.com/v1/air-quality",
            queryItems: [
                URLQueryItem(name: "latitude", value: "\(latitude)"),
                URLQueryItem(name: "longitude", value: "\(longitude)"),
                URLQueryItem(name: "timezone", value: timezone?.isEmpty == false ? timezone : "auto"),
                URLQueryItem(name: "timeformat", value: "unixtime"),
                URLQueryItem(name: "forecast_days", value: "7"),
                URLQueryItem(name: "hourly", value: [
                    "pm10",
                    "pm2_5",
                    "carbon_monoxide",
                    "nitrogen_dioxide",
                    "sulphur_dioxide",
                    "ozone"
                ].joined(separator: ","))
            ],
            completion: completion
        )
    }
    
    func cancel() {
        tasks.forEach { task in
            task.cancel()
        }
        tasks.removeAll()
    }
    
    private func request<T: Decodable>(
        base: String,
        queryItems: [URLQueryItem],
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard var components = URLComponents(string: base) else {
            completion(.failure(OpenMeteoError.invalidURL))
            return
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            completion(.failure(OpenMeteoError.invalidURL))
            return
        }
        
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            self?.removeFinishedTask(url: url)
            
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let response = response as? HTTPURLResponse else {
                completion(.failure(OpenMeteoError.invalidResponse))
                return
            }
            guard (200 ..< 300).contains(response.statusCode) else {
                completion(.failure(OpenMeteoError.httpStatus(response.statusCode)))
                return
            }
            guard let data = data else {
                completion(.failure(OpenMeteoError.emptyData))
                return
            }
            
            do {
                completion(.success(try JSONDecoder().decode(T.self, from: data)))
            } catch {
                completion(.failure(error))
            }
        }
        
        tasks.append(task)
        task.resume()
    }
    
    private func removeFinishedTask(url: URL) {
        tasks.removeAll { task in
            task.originalRequest?.url == url
        }
    }
}

enum OpenMeteoError: Error {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case emptyData
    case noForecast
}
