//
//  AbstractMainCell.swift
//  GeometricWeather
//
//  Created by 王大爷 on 2021/8/8.
//

import UIKit
import GeometricWeatherCore
import GeometricWeatherResources
import GeometricWeatherSettings
import GeometricWeatherDB
import GeometricWeatherTheme

private let blurStyle = UIBlurEffect.Style.prominent

protocol AbstractMainItem {
    
    func bindData(location: Location, timeBar: MainTimeBarView?)
}

class MainTableViewCell: UITableViewCell, AbstractMainItem {
    
    // MARK: - subviews.
    
    let cardContainer = UIVisualEffectView(
        effect: UIBlurEffect(style: blurStyle)
    )
    
    let titleVibrancyContainer = UIVisualEffectView(
        effect: UIVibrancyEffect(
            blurEffect: UIBlurEffect(style: blurStyle)
        )
    )
    let cardTitle = UILabel(frame: .zero)
    
    let backgroundShadowView = ResizeableShadowView(
        frame: .zero,
        shadow: Shadow(
            offset: CGSize(width: 0.0, height: 2.0),
            blur: 12.0,
            color: .black.withAlphaComponent(0.2)
        ),
        cornerRadius: cardRadius
    )
    
    // MARK: - data.
    
    private(set) var location: Location?
    
    // MARK: - life cycles.
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        
        self.contentView.addSubview(self.backgroundShadowView)
        
        self.cardContainer.layer.cornerRadius = cardRadius
        self.cardContainer.layer.masksToBounds = true
        self.contentView.addSubview(self.cardContainer)
        
        self.titleVibrancyContainer.effect = nil
        self.cardTitle.font = titleFont
        self.titleVibrancyContainer.contentView.addSubview(self.cardTitle)
        self.cardContainer.contentView.addSubview(self.titleVibrancyContainer)

        self.contentView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(littleMargin)
            make.trailing.equalToSuperview().offset(-littleMargin)
            make.bottom.equalToSuperview()
        }
        self.cardContainer.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.width.lessThanOrEqualToSuperview()
            make.width.equalTo(getTabletAdaptiveWidth())
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-littleMargin)
        }
        self.backgroundShadowView.snp.makeConstraints { make in
            make.edges.equalTo(self.cardContainer)
        }
        self.cardTitle.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func bindData(location: Location, timeBar: MainTimeBarView?) {
        self.location = location
        
        self.cardContainer.contentView.backgroundColor = UIColor(
            ThemeManager.weatherThemeDelegate.getCardBackgroundColor(
                weatherKind: weatherCodeToWeatherKind(
                    code: location.weather?.current.weatherCode ?? .clear
                ),
                daylight: location.isDaylight
            )
        )
        self.applyReadableCardColors(location: location)
        
        if let timeBar = timeBar {
            timeBar.removeFromSuperview()
            self.cardContainer.contentView.addSubview(timeBar)
            
            if let weather = location.weather {
                timeBar.register(
                    weather: weather,
                    andTimezone: location.timezone
                )
            }
            
            timeBar.snp.makeConstraints { make in
                make.top.equalToSuperview()
                make.leading.equalToSuperview()
                make.trailing.equalToSuperview()
            }
            self.titleVibrancyContainer.snp.remakeConstraints { make in
                make.top.equalTo(timeBar.snp.bottom).offset(MainCardLayoutMetrics.sectionSpacing)
                make.leading.equalToSuperview().offset(normalMargin)
                make.trailing.equalToSuperview().offset(-normalMargin)
            }
        } else {
            self.titleVibrancyContainer.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(MainCardLayoutMetrics.titleTopPadding)
                make.leading.equalToSuperview().offset(normalMargin)
                make.trailing.equalToSuperview().offset(-normalMargin)
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.applyReadableCardColors(location: self.location)
    }

    func readableCardTitleColor(location: Location?) -> UIColor {
        return MainHomeReadableColors.cardTitleColor(
            themeColor: self.themeAccentColor(location: location),
            isDaylight: location?.isDaylight ?? true
        )
    }

    func readableCardSecondaryTextColor() -> UIColor {
        return MainHomeReadableColors.secondaryTextColor
    }

    private func applyReadableCardColors(location: Location?) {
        self.cardTitle.textColor = self.readableCardTitleColor(location: location)
    }

    private func themeAccentColor(location: Location?) -> UIColor {
        let color = ThemeManager.weatherThemeDelegate.getThemeColor(
            weatherKind: weatherCodeToWeatherKind(
                code: location?.weather?.current.weatherCode ?? .clear
            ),
            daylight: location?.isDaylight ?? true
        )
        return UIColor(color)
    }
}

enum MainHomeReadableColors {

    static func cardTitleColor(
        themeColor: UIColor,
        isDaylight: Bool
    ) -> UIColor {
        return UIColor { trait in
            if trait.userInterfaceStyle == .dark || !isDaylight {
                return UIColor.white.withAlphaComponent(0.94)
            }
            return themeColor
        }
    }

    static var secondaryTextColor: UIColor {
        return UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor.white.withAlphaComponent(0.78)
            }
            return UIColor.secondaryLabel
        }
    }

    static var footerPrimaryTextColor: UIColor {
        return UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor.white.withAlphaComponent(0.96)
            }
            return UIColor.white.withAlphaComponent(0.92)
        }
    }

    static var footerSecondaryTextColor: UIColor {
        return UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor.white.withAlphaComponent(0.84)
            }
            return UIColor.white.withAlphaComponent(0.78)
        }
    }
}
