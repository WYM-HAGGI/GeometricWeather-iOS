//
//  DeviceBarometerProvider.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/16.
//

import Foundation
@preconcurrency import CoreMotion

struct DeviceBarometerReading: Sendable {
    let pressureHpa: Double
    let relativeAltitudeMeters: Double?
    let timestamp: Date
}

enum DeviceBarometerError: Error, Sendable {
    case unavailable
    case timeout
    case invalidReading
}

final class DeviceBarometerProvider {
    
    static let shared = DeviceBarometerProvider()
    
    private let altimeter = CMAltimeter()
    private let operationQueue = OperationQueue()
    private let state = DeviceBarometerState()
    
    private let cacheLifetime: TimeInterval = 60.0
    private let timeout: TimeInterval = 3.0
    
    var isAvailable: Bool {
        return CMAltimeter.isRelativeAltitudeAvailable()
    }
    
    private init() {
        self.operationQueue.name = "com.haggi.geometricweather.device-barometer"
        self.operationQueue.maxConcurrentOperationCount = 1
    }
    
    func fetchCurrentPressure() async throws -> DeviceBarometerReading {
        let newTask = Task<DeviceBarometerReading, Error> {
            return try await self.readPressureOnce()
        }
        
        let request = await self.state.resolveRequest(
            cacheLifetime: self.cacheLifetime,
            newTask: newTask
        )
        
        switch request {
        case .cached(let cached):
            newTask.cancel()
            return cached
            
        case .task(let task):
            do {
                let reading = try await task.value
                await self.state.finish(reading: reading)
                return reading
            } catch {
                await self.state.finish(reading: nil)
                throw error
            }
        }
    }

    private func readPressureOnce() async throws -> DeviceBarometerReading {
        guard self.isAvailable else {
            throw DeviceBarometerError.unavailable
        }
        
        let altimeter = self.altimeter
        let operationQueue = self.operationQueue
        let timeout = self.timeout
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let resumeBox = DeviceBarometerContinuationBox(continuation: continuation)
                
                altimeter.startRelativeAltitudeUpdates(to: operationQueue) { data, error in
                    if let error = error {
                        altimeter.stopRelativeAltitudeUpdates()
                        resumeBox.resume(throwing: error)
                        return
                    }
                    
                    guard let data = data else {
                        return
                    }
                    
                    let pressureHpa = data.pressure.doubleValue * 10.0
                    guard pressureHpa > 0 else {
                        altimeter.stopRelativeAltitudeUpdates()
                        resumeBox.resume(throwing: DeviceBarometerError.invalidReading)
                        return
                    }
                    
                    altimeter.stopRelativeAltitudeUpdates()
                    resumeBox.resume(
                        returning: DeviceBarometerReading(
                            pressureHpa: pressureHpa,
                            relativeAltitudeMeters: data.relativeAltitude.doubleValue,
                            timestamp: Date()
                        )
                    )
                }
                
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    altimeter.stopRelativeAltitudeUpdates()
                    resumeBox.resume(throwing: DeviceBarometerError.timeout)
                }
            }
        } onCancel: {
            altimeter.stopRelativeAltitudeUpdates()
        }
    }
}

private enum DeviceBarometerRequest: Sendable {
    case cached(DeviceBarometerReading)
    case task(Task<DeviceBarometerReading, Error>)
}

private actor DeviceBarometerState {
    
    private var cachedReading: DeviceBarometerReading?
    private var activeTask: Task<DeviceBarometerReading, Error>?
    
    func resolveRequest(
        cacheLifetime: TimeInterval,
        newTask: Task<DeviceBarometerReading, Error>
    ) -> DeviceBarometerRequest {
        if let cachedReading = self.cachedReading,
           Date().timeIntervalSince(cachedReading.timestamp) <= cacheLifetime {
            return .cached(cachedReading)
        }
        
        if let activeTask = self.activeTask {
            newTask.cancel()
            return .task(activeTask)
        }
        
        self.activeTask = newTask
        return .task(newTask)
    }
    
    func finish(reading: DeviceBarometerReading?) {
        if let reading = reading {
            self.cachedReading = reading
        }
        self.activeTask = nil
    }
}

private final class DeviceBarometerContinuationBox: @unchecked Sendable {
    
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<DeviceBarometerReading, Error>
    
    init(continuation: CheckedContinuation<DeviceBarometerReading, Error>) {
        self.continuation = continuation
    }
    
    func resume(returning reading: DeviceBarometerReading) {
        self.lock.lock()
        guard !self.didResume else {
            self.lock.unlock()
            return
        }
        self.didResume = true
        self.lock.unlock()
        
        self.continuation.resume(returning: reading)
    }
    
    func resume(throwing error: Error) {
        self.lock.lock()
        guard !self.didResume else {
            self.lock.unlock()
            return
        }
        self.didResume = true
        self.lock.unlock()
        
        self.continuation.resume(throwing: error)
    }
}

struct BarometricAltitudeCalculator {
    
    static func altitudeMeters(
        devicePressureHpa: Double,
        seaLevelPressureHpa: Double
    ) -> Double? {
        guard devicePressureHpa > 0, seaLevelPressureHpa > 0 else {
            return nil
        }
        
        let altitude = 44330.0 * (1.0 - pow(devicePressureHpa / seaLevelPressureHpa, 1.0 / 5.255))
        guard (-500.0 ... 9000.0).contains(altitude) else {
            return nil
        }
        return altitude
    }
}

struct PressureDisplayValue {
    let pressureHpa: Double
    let pressureSource: PressureSource
    let calibratedAltitudeMeters: Double?
    let altitudeSource: AltitudeSource
}

enum PressureSource {
    case device
    case weather
}

enum AltitudeSource {
    case barometricCalibrated
    case weatherElevation
    case unavailable
}

struct PressureDisplayValueProvider {
    
    static func fallback(weatherPressureHpa: Double?) -> PressureDisplayValue? {
        guard let weatherPressureHpa = weatherPressureHpa else {
            return nil
        }
        return PressureDisplayValue(
            pressureHpa: weatherPressureHpa,
            pressureSource: .weather,
            calibratedAltitudeMeters: nil,
            altitudeSource: .unavailable
        )
    }
    
    static func current(weatherPressureHpa: Double?) async -> PressureDisplayValue? {
        do {
            let reading = try await DeviceBarometerProvider.shared.fetchCurrentPressure()
            return PressureDisplayValue(
                pressureHpa: reading.pressureHpa,
                pressureSource: .device,
                calibratedAltitudeMeters: weatherPressureHpa.flatMap {
                    BarometricAltitudeCalculator.altitudeMeters(
                        devicePressureHpa: reading.pressureHpa,
                        seaLevelPressureHpa: $0
                    )
                },
                altitudeSource: weatherPressureHpa == nil ? .unavailable : .barometricCalibrated
            )
        } catch {
            return self.fallback(weatherPressureHpa: weatherPressureHpa)
        }
    }
}
