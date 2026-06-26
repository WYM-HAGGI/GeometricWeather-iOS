//
//  CoordinateTransform.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/18.
//

import Foundation

enum CoordinateTransform {
    
    private static let earthRadius = 6378245.0
    private static let ee = 0.00669342162296594323
    
    static func gcj02ToWgs84(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        guard isInChina(latitude: latitude, longitude: longitude) else {
            return (latitude, longitude)
        }
        
        let delta = delta(latitude: latitude, longitude: longitude)
        return (
            latitude: latitude * 2.0 - delta.latitude,
            longitude: longitude * 2.0 - delta.longitude
        )
    }
    
    static func wgs84ToGcj02(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        guard isInChina(latitude: latitude, longitude: longitude) else {
            return (latitude, longitude)
        }
        
        let delta = delta(latitude: latitude, longitude: longitude)
        return delta
    }
    
    static func isInChina(latitude: Double, longitude: Double) -> Bool {
        return (0.8293 ... 55.8271).contains(latitude)
            && (72.004 ... 137.8347).contains(longitude)
    }
    
    private static func delta(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        var dLat = transformLatitude(x: longitude - 105.0, y: latitude - 35.0)
        var dLon = transformLongitude(x: longitude - 105.0, y: latitude - 35.0)
        let radLat = latitude / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1.0 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((earthRadius * (1.0 - ee)) / (magic * sqrtMagic) * Double.pi)
        dLon = (dLon * 180.0) / (earthRadius / sqrtMagic * cos(radLat) * Double.pi)
        return (latitude + dLat, longitude + dLon)
    }
    
    private static func transformLatitude(x: Double, y: Double) -> Double {
        var result = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y
            + 0.2 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        result += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        result += (160.0 * sin(y / 12.0 * Double.pi) + 320.0 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return result
    }
    
    private static func transformLongitude(x: Double, y: Double) -> Double {
        var result = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y
            + 0.1 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        result += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        result += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return result
    }
}
