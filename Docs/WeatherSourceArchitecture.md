# Multi-Source Weather Architecture Plan

## Current Limitation

`WeatherApi` currently returns one complete `Weather` object from one selected `WeatherSource`.
That keeps the update path simple, but it couples forecast, air quality, alerts, minutely
precipitation, geocoding, and reverse geocoding to the same provider.

This is enough for Open-Meteo phase 2A, but it is not ideal for China-specific alerts,
local air quality, or provider-specific minute precipitation.

## Data Source Roles

Future provider selection should be split by role:

```swift
enum WeatherDataSourceRole {
    case forecast
    case airQuality
    case alerts
    case minutely
    case geocoding
    case reverseGeocoding
}
```

The current app should continue to use a single default source until each role is stable.

## Recommended Priority

Forecast:
1. Open-Meteo
2. CaiYun
3. AccuWeather

Air quality:
1. China or CNEMC-compatible provider
2. Open-Meteo Air Quality
3. AccuWeather

Alerts:
1. China Weather provider
2. AccuWeather
3. Empty alerts

Minutely:
1. CaiYun
2. Open-Meteo `minutely_15`
3. Empty minutely forecast

Geocoding:
1. Open-Meteo Geocoding
2. Apple CLGeocoder

Reverse geocoding:
1. Apple CLGeocoder
2. Existing provider-specific reverse geocoding
3. Coordinate-only fallback

## MultiSourceWeatherApi

A future `MultiSourceWeatherApi: WeatherApi` can orchestrate multiple providers:

1. Request forecast from the primary forecast source.
2. Request air quality, alerts, and minutely data from role-specific sources.
3. Merge role results into the original `Weather` model.
4. Return partial data when non-primary roles fail.

It should not replace `OpenMeteoApi` until merge rules and failure behavior are covered by
manual tests. Phase 2B keeps Open-Meteo as the default path.

## Settings Strategy

Do not expose advanced source roles in the normal settings page yet. A first implementation
can keep role priorities as code defaults, then later add an advanced settings screen after
China alerts and local AQI are stable.

## Suggested Rollout

1. Keep Open-Meteo as the default single-source provider.
2. Add a China alert provider returning only `WeatherAlert`.
3. Add a China air quality provider returning only `AirQuality`.
4. Add `MultiSourceWeatherApi` behind a debug flag.
5. Promote role-based source selection to user settings only after reliability testing.
