//
//  OpenMeteoApi.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/16.
//

import Foundation
import CoreLocation
import GeometricWeatherCore

public final class OpenMeteoApi: WeatherApi {
    
    private let service = OpenMeteoService()
    private let locationGeocoder = CLGeocoder()
    private let searchLocalizationGeocoder = CLGeocoder()
    private let reverseGeocoder = CLGeocoder()
    private static var reverseGeocodeCache = [String: Location]()
    
    public init() {
        // do nothing.
    }
    
    public func getLocation(
        _ query: String,
        callback: @escaping ([Location]) -> Void
    ) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            callbackOnMain([], callback)
            return
        }
        
        if containsHanText(query) {
            locationGeocoder.geocodeAddressString(query) { [weak self] placemarks, error in
                if let error = error {
                    printLog(keyword: "location", content: "Apple location search error: \(error)")
                }
                
                let locations = placemarks?.compactMap {
                    OpenMeteoConvert.generateLocation(from: $0)
                } ?? []
                if !locations.isEmpty {
                    callbackOnMain(locations, callback)
                    return
                }
                
                self?.requestOpenMeteoLocation(query: query, callback: callback)
            }
            return
        }
        
        requestOpenMeteoLocation(query: query, callback: callback)
    }
    
    private func requestOpenMeteoLocation(
        query: String,
        callback: @escaping ([Location]) -> Void
    ) {
        service.searchLocation(query: query) { result in
            switch result {
            case .success(let response):
                self.localizeLocations(
                    OpenMeteoConvert.generateLocations(from: response),
                    callback: callback
                )
            case .failure(let error):
                printLog(keyword: "network", content: "Open-Meteo location search error: \(error)")
                callbackOnMain([], callback)
            }
        }
    }
    
    public func getGeoPosition(
        target: Location,
        callback: @escaping (Location?) -> Void
    ) {
        let fallback = OpenMeteoConvert.generateLocationByCoordinate(target: target)
        let cacheKey = Self.reverseGeocodeCacheKey(
            latitude: target.latitude,
            longitude: target.longitude
        )
        
        if let cached = Self.reverseGeocodeCache[cacheKey] {
            callback(cached)
            return
        }
        
        let location = CLLocation(
            latitude: target.latitude,
            longitude: target.longitude
        )
        let callbackBox = SingleLocationCallback(callback)
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
            callbackBox.call(fallback)
        }
        reverseGeocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                printLog(keyword: "location", content: "Open-Meteo reverse geocode error: \(error)")
                callbackBox.call(fallback)
                return
            }
            
            guard let placemark = placemarks?.first else {
                callbackBox.call(fallback)
                return
            }
            
            let result = OpenMeteoConvert.generateLocationByCoordinate(
                target: target,
                placemark: placemark
            )
            Self.reverseGeocodeCache[cacheKey] = result
            callbackBox.call(result)
        }
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
                    callbackOnMain(
                        OpenMeteoConvert.generateWeather(
                            location: target,
                            forecast: forecast,
                            airQuality: airQuality
                        ),
                        callback
                    )
                }
            case .failure(let error):
                printLog(keyword: "network", content: "Open-Meteo weather request error: \(error)")
                callbackOnMain(nil, callback)
            }
        }
    }
    
    public func cancel() {
        service.cancel()
        locationGeocoder.cancelGeocode()
        searchLocalizationGeocoder.cancelGeocode()
        reverseGeocoder.cancelGeocode()
    }
    
    private static func reverseGeocodeCacheKey(latitude: Double, longitude: Double) -> String {
        return "\(String(format: "%.4f", latitude)),\(String(format: "%.4f", longitude))"
    }
    
    private func localizeLocations(
        _ locations: [Location],
        index: Int = 0,
        localized: [Location] = [],
        callback: @escaping ([Location]) -> Void
    ) {
        guard index < locations.count, index < 6 else {
            callbackOnMain(localized + Array(locations.dropFirst(index)), callback)
            return
        }
        
        let location = locations[index]
        searchLocalizationGeocoder.reverseGeocodeLocation(
            CLLocation(latitude: location.latitude, longitude: location.longitude)
        ) { [weak self] placemarks, error in
            if let error = error {
                printLog(keyword: "location", content: "Open-Meteo search localization error: \(error)")
            }
            
            let localizedLocation = placemarks?.first.flatMap {
                OpenMeteoConvert.generateLocation(from: $0, src: location)
            } ?? location
            self?.localizeLocations(
                locations,
                index: index + 1,
                localized: localized + [localizedLocation],
                callback: callback
            )
        }
    }
}

private func callbackOnMain<T>(_ value: T, _ callback: @escaping (T) -> Void) {
    if Thread.isMainThread {
        callback(value)
    } else {
        DispatchQueue.main.async {
            callback(value)
        }
    }
}

private func containsHanText(_ text: String) -> Bool {
    return text.range(of: "\\p{Han}", options: .regularExpression) != nil
}

private final class SingleLocationCallback {
    
    private let lock = NSLock()
    private var fired = false
    private let callback: (Location?) -> Void
    
    init(_ callback: @escaping (Location?) -> Void) {
        self.callback = callback
    }
    
    func call(_ location: Location?) {
        lock.lock()
        defer {
            lock.unlock()
        }
        
        guard !fired else {
            return
        }
        fired = true
        callbackOnMain(location, callback)
    }
}
