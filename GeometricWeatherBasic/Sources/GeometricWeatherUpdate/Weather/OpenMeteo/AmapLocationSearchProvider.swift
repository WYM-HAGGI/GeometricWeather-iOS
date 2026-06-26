//
//  AmapLocationSearchProvider.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/18.
//

import Foundation
import GeometricWeatherCore

enum AmapConfig {
    
    // TODO: Production builds should inject this key through a secure local xcconfig
    // or backend-controlled configuration. Do not commit a real AMap Web Service key.
    static var apiKey: String {
        let values = [
            Bundle.main.object(forInfoDictionaryKey: "AMAP_API_KEY") as? String,
            ProcessInfo.processInfo.environment["AMAP_API_KEY"],
            UserDefaults.standard.string(forKey: "AMAP_API_KEY")
        ]
        return values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("$(") } ?? ""
    }
}

final class AmapLocationSearchProvider: LocationSearchProvider {
    
    let providerName = "AMap Web Service"
    
    private var tasks = [URLSessionDataTask]()
    private let lock = NSLock()
    
    func search(query: LocationSearchQuery, completion: @escaping ([LocationSearchResult]) -> Void) {
        guard !AmapConfig.apiKey.isEmpty else {
            completion([])
            return
        }
        
        let group = DispatchGroup()
        var collected = [LocationSearchResult]()
        let collectLock = NSLock()
        
        func collect(_ results: [LocationSearchResult]) {
            collectLock.lock()
            collected.append(contentsOf: results)
            collectLock.unlock()
        }
        
        group.enter()
        requestPlaceText(query: query.trimmed) { results in
            collect(results)
            group.leave()
        }
        
        group.enter()
        requestGeocode(query: query.trimmed) { results in
            collect(results)
            group.leave()
        }
        
        group.enter()
        requestDistrict(query: query.trimmed) { results in
            collect(results)
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(LocationSearchCoordinator.deduplicate(collected))
        }
    }
    
    func cancel() {
        lock.lock()
        let runningTasks = tasks
        tasks.removeAll()
        lock.unlock()
        runningTasks.forEach { $0.cancel() }
    }
    
    private func requestPlaceText(query: String, completion: @escaping ([LocationSearchResult]) -> Void) {
        request(
            path: "/v3/place/text",
            queryItems: [
                URLQueryItem(name: "keywords", value: query),
                URLQueryItem(name: "offset", value: "20"),
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "extensions", value: "all")
            ],
            responseType: AmapPlaceTextResponse.self
        ) { result in
            switch result {
            case .success(let response):
                completion(response.pois?.compactMap { LocationSearchResult.fromAmapPOI($0) } ?? [])
            case .failure(let error):
                printLog(keyword: "location", content: "AMap POI search error: \(error)")
                completion([])
            }
        }
    }
    
    private func requestGeocode(query: String, completion: @escaping ([LocationSearchResult]) -> Void) {
        request(
            path: "/v3/geocode/geo",
            queryItems: [
                URLQueryItem(name: "address", value: query)
            ],
            responseType: AmapGeocodeResponse.self
        ) { result in
            switch result {
            case .success(let response):
                completion(response.geocodes?.compactMap { LocationSearchResult.fromAmapGeocode($0) } ?? [])
            case .failure(let error):
                printLog(keyword: "location", content: "AMap geocode error: \(error)")
                completion([])
            }
        }
    }
    
    private func requestDistrict(query: String, completion: @escaping ([LocationSearchResult]) -> Void) {
        request(
            path: "/v3/config/district",
            queryItems: [
                URLQueryItem(name: "keywords", value: query),
                URLQueryItem(name: "subdistrict", value: "3"),
                URLQueryItem(name: "extensions", value: "base")
            ],
            responseType: AmapDistrictResponse.self
        ) { result in
            switch result {
            case .success(let response):
                completion((response.districts ?? []).flatMap { $0.flattenedResults() })
            case .failure(let error):
                printLog(keyword: "location", content: "AMap district search error: \(error)")
                completion([])
            }
        }
    }
    
    private func request<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "restapi.amap.com"
        components.path = path
        components.queryItems = queryItems + [
            URLQueryItem(name: "key", value: AmapConfig.apiKey),
            URLQueryItem(name: "output", value: "json")
        ]
        guard let url = components.url else {
            completion(.failure(AmapLocationSearchError.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            defer {
                self?.removeFinishedTask(url: url)
            }
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode),
                  let data = data else {
                completion(.failure(AmapLocationSearchError.badResponse))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let envelope = try decoder.decode(AmapResponseEnvelope<T>.self, from: data)
                guard envelope.status == "1" else {
                    completion(.failure(AmapLocationSearchError.apiError(
                        info: envelope.info,
                        infocode: envelope.infocode
                    )))
                    return
                }
                completion(.success(envelope.value))
            } catch {
                completion(.failure(error))
            }
        }
        
        lock.lock()
        tasks.append(task)
        lock.unlock()
        task.resume()
    }
    
    private func removeFinishedTask(url: URL) {
        lock.lock()
        tasks.removeAll { $0.originalRequest?.url == url }
        lock.unlock()
    }
}

private enum AmapLocationSearchError: Error {
    case invalidURL
    case badResponse
    case apiError(info: String?, infocode: String?)
}
