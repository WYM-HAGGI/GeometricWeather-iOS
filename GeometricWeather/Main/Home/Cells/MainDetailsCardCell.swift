//
//  MainDetailsCardCell.swift
//  GeometricWeather
//
//  Created by 王大爷 on 2021/8/22.
//

import UIKit
import GeometricWeatherCore
import GeometricWeatherResources
import GeometricWeatherSettings
import GeometricWeatherDB
import GeometricWeatherTheme

class MainDetailsCardCell: MainTableViewCell {
    
    // MARK: - subviews.
    
    private let vstack = UIStackView(frame: .zero)
    private var pressureTask: Task<Void, Never>?
    
    // MARK: - life cycle.
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.cardTitle.text = getLocalizedText("life_details")
        
        self.vstack.axis = .vertical
        self.cardContainer.contentView.addSubview(self.vstack)
        
        self.titleVibrancyContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(normalMargin)
            make.leading.equalToSuperview().offset(normalMargin)
            make.trailing.equalToSuperview().offset(-normalMargin)
        }
        self.vstack.snp.makeConstraints { make in
            make.top.equalTo(self.titleVibrancyContainer.snp.bottom)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-normalMargin)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        self.pressureTask?.cancel()
        self.pressureTask = nil
    }
    
    override func bindData(location: Location, timeBar: MainTimeBarView?) {
        super.bindData(location: location, timeBar: timeBar)
        self.pressureTask?.cancel()
        self.pressureTask = nil
        
        guard let weather = location.weather else {
            return
        }
        
        // remove all detail item view.
        for subview in self.vstack.arrangedSubviews {
            subview.removeFromSuperview()
        }
        
        // generate detial item views.
        
        // wind.
        if let wind = weather.dailyForecasts.get(0)?.wind {
            self.vstack.addArrangedSubview(
                self.generateDetailItemView(
                    iconName: "wind",
                    title: getLocalizedText("live") + ": " + getWindText(
                        wind: weather.current.wind,
                        unit: SettingsManager.shared.speedUnit
                    ),
                    body: getLocalizedText("today") + ": " + getWindText(
                        wind: wind,
                        unit: SettingsManager.shared.speedUnit
                    )
                )
            )
        } else if let daytime = weather.dailyForecasts.get(0)?.day.wind,
                  let nighttime = weather.dailyForecasts.get(0)?.night.wind {
            self.vstack.addArrangedSubview(
                self.generateDetailItemView(
                    iconName: "wind",
                    title: getLocalizedText("live") + ": " + getWindText(
                        wind: weather.current.wind,
                        unit: SettingsManager.shared.speedUnit
                    ),
                    body: getLocalizedText("daytime") + ": " + getWindText(
                        wind: daytime,
                        unit: SettingsManager.shared.speedUnit
                    ) + "\n" + getLocalizedText("nighttime") + ": " + getWindText(
                        wind: nighttime,
                        unit: SettingsManager.shared.speedUnit
                    )
                )
            )
        }
        
        // humidity.
        if let humidity = weather.current.relativeHumidity {
            self.vstack.addArrangedSubview(
                self.generateDetailItemView(
                    iconName: "humidity",
                    title: getLocalizedText("humidity"),
                    body: getPercentText(
                        humidity,
                        decimal: 1
                    )
                )
            )
        }
        
        // uv.
        if weather.current.uv.isValid() {
            self.vstack.addArrangedSubview(
                self.generateDetailItemView(
                    iconName: "sun.max",
                    title: getLocalizedText("uv_index"),
                    body: weather.current.uv.getUVDescription()
                )
            )
        }
        
        // pressure.
        if let pressureValue = PressureDisplayValueProvider.fallback(
            weatherPressureHpa: weather.current.pressure
        ) {
            let pressureItem = self.generateDetailItemView(
                iconName: "gauge",
                title: getLocalizedText("pressure"),
                body: self.getPressureText(pressureValue)
            )
            self.vstack.addArrangedSubview(
                pressureItem
            )
            let locationId = location.formattedId
            self.pressureTask = Task { [weak self, weak pressureItem] in
                guard let pressureValue = await PressureDisplayValueProvider.current(
                    weatherPressureHpa: weather.current.pressure
                ) else {
                    return
                }
                await MainActor.run {
                    guard let self = self,
                          let pressureItem = pressureItem,
                          !Task.isCancelled,
                          locationId == location.formattedId else {
                        return
                    }
                    pressureItem.bindData(
                        iconName: "gauge",
                        title: getLocalizedText("pressure"),
                        body: self.getPressureText(pressureValue)
                    )
                }
            }
        }
        
        // visibility.
        if let visibility = weather.current.visibility {
            let unit = SettingsManager.shared.distanceUnit
            self.vstack.addArrangedSubview(
                self.generateDetailItemView(
                    iconName: "eye",
                    title: getLocalizedText("visibility"),
                    body: unit.formatValueWithUnit(
                        visibility,
                        unit: getLocalizedText(unit.key)
                    )
                )
            )
        }
    }
    
    // MARK: - ui.
    
    private func generateDetailItemView(
        iconName: String,
        title: String,
        body: String
    ) -> MainDetailItemView {
        let view = MainDetailItemView(frame: .zero)
        view.bindData(iconName: iconName, title: title, body: body)
        return view
    }
    
    private func getPressureText(_ value: PressureDisplayValue) -> String {
        let pressureText = String(
            format: "%.1f hPa (%@)",
            value.pressureHpa,
            self.getPressureSourceText(value.pressureSource)
        )
        
        guard let altitude = value.calibratedAltitudeMeters else {
            return pressureText
        }
        
        switch value.altitudeSource {
        case .barometricCalibrated:
            return pressureText + " | " + String(format: getLocalizedText("altitude_approx_format"), altitude)
            
        case .weatherElevation:
            return pressureText + " | " + String(format: getLocalizedText("altitude_format"), altitude)
            
        case .unavailable:
            return pressureText
        }
    }
    
    private func getPressureSourceText(_ source: PressureSource) -> String {
        switch source {
        case .device:
            return getLocalizedText("pressure_source_device")
            
        case .weather:
            return getLocalizedText("pressure_source_weather")
        }
    }
}
