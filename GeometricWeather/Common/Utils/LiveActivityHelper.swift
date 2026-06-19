//
//  LiveActivityHelper.swift
//  GeometricWeather
//
//  Created by 王大爷 on 2023/1/18.
//

import Foundation
import GeometricWeatherCore
import GeometricWeatherResources
import GeometricWeatherSettings
import ActivityKit

private let updateQueue = SerialTasks<Void>()

@available(iOS 16.2, *)
func updateLiveActivity(locations: [Location]) {
    if !ActivityAuthorizationInfo().areActivitiesEnabled {
        return
    }
    guard let location = locations.first else {
        return
    }
    Task {
        do {
            try await updateLiveActivity(for: location)
        } catch {
            printLog(
                keyword: "liveActivity",
                content: "Catched an error \"\(error.localizedDescription)\" when updating live activity for \(location.formattedId)"
            )
        }
    }
}

@available(iOS 16.2, *)
private func updateLiveActivity(for location: Location) async throws {
    try await updateQueue.add {
        // 先停掉所有旧的live activity
        for activity in Activity<PrecipitationActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        if !SettingsManager.shared.dynamicIslandEnabled {
            return
        }
        guard let reason = await LiveActivityWeatherEligibility.reason(
            for: location,
            alertProvider: WeatherAlertProviderBridge.fallbackProvider
        ) else {
            printLog(
                keyword: "liveActivity",
                content: "Ended live activity and skipped request because no eligible weather event exists for \(location.formattedId)"
            )
            return
        }
        guard
            let base = location.weather?.base,
            let current = location.weather?.current,
            let today = location.weather?.dailyForecasts.get(0)
        else {
            return
        }
        let minutely = location.weather?.minutelyForecast
            ?? LiveActivityWeatherEligibility.fallbackMinutely(for: location)
        
        let deadline = Date(
            timeIntervalSince1970: minutely.endTime - Double(
                location.timezone.secondsFromGMT() - TimeZone.current.secondsFromGMT()
            )
        )
        let activityContent = ActivityContent(
            state: PrecipitationActivityAttributes.ContentState(
                currentTimeSince1970: Date().timeIntervalSince1970
            ),
            staleDate: deadline
        )
        
//        if !Activity<PrecipitationActivityAttributes>.activities.isEmpty {
//            for activity in Activity<PrecipitationActivityAttributes>.activities {
//                await activity.update(activityContent, alertConfiguration: nil)
//            }
//            return
//        }
        
        do {
            let _ = try Activity.request(
                attributes: PrecipitationActivityAttributes(
                    locationName: getLocationText(location: location),
                    locationFormattedId: location.formattedId,
                    isDaylight: location.isDaylight,
                    isCurrentPosition: location.currentPosition,
                    timestamp: base.timeStamp,
                    timezone: location.timezone,
                    weatherText: getDisplayWeatherText(current.weatherText),
                    weatherCode: current.weatherCode,
                    temperature: current.temperature.temperature,
                    daytimeTemperature: today.day.temperature.temperature,
                    nighttimeTemperature: today.night.temperature.temperature,
                    forecastDescription: current.hourlyForecast
                    ?? current.dailyForecast
                    ?? "Powered by \(location.weatherSource.url)",
                    minutely: minutely
                ),
                content: activityContent
            )
            printLog(
                keyword: "liveActivity",
                content: "Requested a live activity for \(location.formattedId), reason: \(reason)"
            )
        } catch (let error) {
            printLog(
                keyword: "liveActivity",
                content: "Catched an error \"\(error.localizedDescription)\" when requesting live activity for \(location.formattedId)"
            )
        }
    }
}
