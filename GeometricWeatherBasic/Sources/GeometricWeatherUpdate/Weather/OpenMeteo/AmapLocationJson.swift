//
//  AmapLocationJson.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/18.
//

import Foundation

struct AmapResponseEnvelope<Value: Decodable>: Decodable {
    let status: String?
    let info: String?
    let infocode: String?
    let value: Value
    
    enum CodingKeys: String, CodingKey {
        case status
        case info
        case infocode
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        info = try container.decodeIfPresent(String.self, forKey: .info)
        infocode = try container.decodeIfPresent(String.self, forKey: .infocode)
        value = try Value(from: decoder)
    }
}

struct AmapPlaceTextResponse: Decodable {
    let pois: [AmapPOI]?
}

struct AmapPOI: Decodable {
    let name: String?
    let type: String?
    let typecode: String?
    let address: AmapFlexibleString?
    let location: String?
    let pname: String?
    let cityname: AmapFlexibleString?
    let adname: String?
    let citycode: AmapFlexibleString?
    let adcode: String?
    let business_area: AmapFlexibleString?
}

struct AmapGeocodeResponse: Decodable {
    let geocodes: [AmapGeocode]?
}

struct AmapGeocode: Decodable {
    let formatted_address: String?
    let province: String?
    let city: AmapFlexibleString?
    let district: AmapFlexibleString?
    let township: AmapFlexibleString?
    let neighborhood: AmapNamedValue?
    let building: AmapNamedValue?
    let adcode: String?
    let location: String?
    let level: String?
}

struct AmapNamedValue: Decodable {
    let name: AmapFlexibleString?
    let type: AmapFlexibleString?
}

struct AmapDistrictResponse: Decodable {
    let districts: [AmapDistrict]?
}

struct AmapDistrict: Decodable {
    let name: String?
    let adcode: String?
    let citycode: AmapFlexibleString?
    let center: String?
    let level: String?
    let districts: [AmapDistrict]?
}

struct AmapFlexibleString: Decodable {
    let value: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
            return
        }
        if let array = try? container.decode([String].self) {
            value = array.first
            return
        }
        value = nil
    }
}
