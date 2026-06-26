//
//  AmapLocationConvert.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/18.
//

import Foundation

extension LocationSearchResult {
    
    static func fromAmapPOI(_ poi: AmapPOI) -> LocationSearchResult? {
        guard let name = cleanAmapText(poi.name),
              let coordinate = parseAmapCoordinate(poi.location) else {
            return nil
        }
        
        let weatherCoordinate = CoordinateTransform.gcj02ToWgs84(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let city = cleanAmapText(poi.cityname?.value)
        let district = cleanAmapText(poi.adname)
        return LocationSearchResult(
            name: name,
            localizedName: name,
            country: "中国",
            admin1: cleanAmapText(poi.pname),
            admin2: city,
            admin3: city,
            admin4: district,
            township: nil,
            address: cleanAmapText(poi.address?.value),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            weatherLatitude: weatherCoordinate.latitude,
            weatherLongitude: weatherCoordinate.longitude,
            coordinateSystem: .gcj02,
            timezone: "Asia/Shanghai",
            source: .amap,
            sourceId: poi.adcode.map { "amap_poi_\($0)_\(String(format: "%.5f", weatherCoordinate.latitude))_\(String(format: "%.5f", weatherCoordinate.longitude))" },
            resultType: .poi,
            category: categoryText(type: poi.type, fallback: "地点")
        )
    }
    
    static func fromAmapGeocode(_ geocode: AmapGeocode) -> LocationSearchResult? {
        guard let coordinate = parseAmapCoordinate(geocode.location) else {
            return nil
        }
        
        let title = cleanAmapText(geocode.formatted_address)
            ?? cleanAmapText(geocode.building?.name?.value)
            ?? cleanAmapText(geocode.neighborhood?.name?.value)
            ?? cleanAmapText(geocode.township?.value)
            ?? cleanAmapText(geocode.district?.value)
        guard let title = title else {
            return nil
        }
        
        let weatherCoordinate = CoordinateTransform.gcj02ToWgs84(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let district = cleanAmapText(geocode.district?.value)
        let township = cleanAmapText(geocode.township?.value)
        return LocationSearchResult(
            name: title,
            localizedName: title,
            country: "中国",
            admin1: cleanAmapText(geocode.province),
            admin2: cleanAmapText(geocode.city?.value),
            admin3: cleanAmapText(geocode.city?.value),
            admin4: district,
            township: township,
            address: cleanAmapText(geocode.formatted_address),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            weatherLatitude: weatherCoordinate.latitude,
            weatherLongitude: weatherCoordinate.longitude,
            coordinateSystem: .gcj02,
            timezone: "Asia/Shanghai",
            source: .amap,
            sourceId: geocode.adcode.map { "amap_geo_\($0)_\(String(format: "%.5f", weatherCoordinate.latitude))_\(String(format: "%.5f", weatherCoordinate.longitude))" },
            resultType: township != nil ? .township : .address,
            category: levelCategory(geocode.level)
        )
    }
    
    fileprivate static func parseAmapCoordinate(_ text: String?) -> (latitude: Double, longitude: Double)? {
        guard let text = cleanAmapText(text) else {
            return nil
        }
        let parts = text.split(separator: ",")
        guard parts.count == 2,
              let longitude = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
              let latitude = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)),
              latitude.isFinite,
              longitude.isFinite,
              (-90.0 ... 90.0).contains(latitude),
              (-180.0 ... 180.0).contains(longitude) else {
            return nil
        }
        return (latitude, longitude)
    }
    
    private static func cleanAmapText(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              text != "[]" else {
            return nil
        }
        return text
    }
    
    private static func categoryText(type: String?, fallback: String) -> String {
        guard let type = cleanAmapText(type) else {
            return fallback
        }
        if type.contains("风景名胜") || type.contains("旅游景点") {
            return "景区"
        }
        if type.contains("购物") {
            return "商场"
        }
        if type.contains("公司") || type.contains("企业") || type.contains("产业园") {
            return "园区"
        }
        if type.contains("道路") || type.contains("地名地址") {
            return "地址"
        }
        return type.components(separatedBy: ";").last ?? fallback
    }
    
    private static func levelCategory(_ level: String?) -> String {
        guard let level = cleanAmapText(level) else {
            return "地址"
        }
        if level.contains("乡镇") || level.contains("街道") {
            return "街道"
        }
        if level.contains("区县") {
            return "区县"
        }
        if level.contains("市") {
            return "城市"
        }
        return level
    }
}

extension AmapDistrict {
    
    func flattenedResults(
        province: String? = nil,
        city: String? = nil,
        district: String? = nil
    ) -> [LocationSearchResult] {
        let level = nameForLevel()
        let nextProvince = level == .city && province == nil ? name : province
        let nextCity = level == .city && province != nil ? name : city
        let nextDistrict = level == .district ? name : district
        var results = [LocationSearchResult]()
        
        if let result = toLocationSearchResult(
            province: nextProvince,
            city: nextCity,
            district: nextDistrict
        ) {
            results.append(result)
        }
        
        for child in districts ?? [] {
            results.append(contentsOf: child.flattenedResults(
                province: nextProvince,
                city: nextCity,
                district: nextDistrict
            ))
        }
        return results
    }
    
    private func toLocationSearchResult(
        province: String?,
        city: String?,
        district: String?
    ) -> LocationSearchResult? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty,
              let coordinate = LocationSearchResult.parseAmapCoordinate(center) else {
            return nil
        }
        let weatherCoordinate = CoordinateTransform.gcj02ToWgs84(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let resultType = nameForLevel()
        return LocationSearchResult(
            name: name,
            localizedName: name,
            country: "中国",
            admin1: province,
            admin2: city,
            admin3: city,
            admin4: resultType == .district ? name : district,
            township: resultType == .township ? name : nil,
            address: nil,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            weatherLatitude: weatherCoordinate.latitude,
            weatherLongitude: weatherCoordinate.longitude,
            coordinateSystem: .gcj02,
            timezone: "Asia/Shanghai",
            source: .amap,
            sourceId: adcode.map { "amap_district_\($0)" },
            resultType: resultType,
            category: categoryForLevel()
        )
    }
    
    private func nameForLevel() -> LocationSearchResultType {
        switch level {
        case "province", "city":
            return .city
        case "district":
            return .district
        case "street":
            return .township
        default:
            return .unknown
        }
    }
    
    private func categoryForLevel() -> String {
        switch level {
        case "province", "city":
            return "城市"
        case "district":
            return "区县"
        case "street":
            return "街道"
        default:
            return "行政区"
        }
    }
}
