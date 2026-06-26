//
//  MainHourlyCardCell.swift
//  GeometricWeather
//
//  Created by 王大爷 on 2021/8/16.
//

import UIKit
import GeometricWeatherCore
import GeometricWeatherResources
import GeometricWeatherSettings
import GeometricWeatherDB
import GeometricWeatherTheme
import SwiftUI

private let hourlyTrendViewHeight = MainCardLayoutMetrics.hourlyTrendHeight
private let minutelyTrendViewHeight = MainCardLayoutMetrics.minutelyTrendHeight

struct HourlyTrendCellTapAction {
    let index: Int
}

class MainHourlyCardCell: MainTableViewCell,
                            UICollectionViewDataSource,
                            UICollectionViewDelegateFlowLayout,
                            MainSelectableTagDelegate {

    // MARK: - subviews.

    private let vstack = UIStackView(frame: .zero)

    private let summaryLabel = UILabel(frame: .zero)
    private let noticeContainer = UIView(frame: .zero)
    private let noticeTextStack = UIStackView(frame: .zero)
    private let noticeTitleLabel = UILabel(frame: .zero)
    private let noticeSubtitleLabel = UILabel(frame: .zero)
    private let noticeSeparator = UIView(frame: .zero)

    private let tagPaddingTop = UIView(frame: .zero)
    private let hourlyTagView = MainSelectableTagView(frame: .zero)

    private let hourlyTrendGroupView = UIView(frame: .zero)
    private let hourlyCollectionView = MainTrendShaderCollectionView(frame: .zero)
    private let hourlyBackgroundView = MainTrendBackgroundView(frame: .zero)

    private let minutelyTitleVibrancyContainer = UIVisualEffectView(
        effect: UIVibrancyEffect(
            blurEffect: UIBlurEffect(style: .prominent)
        )
    )
    private let minutelyTitle = UILabel(frame: .zero)

    private let minutelyView = HistogramPolylineView(frame: .zero)

    // MARK: - data.

    private var validTrendGenerators = [MainTrendGeneratorProtocol]()
    private var displayLocation: Location?
    private var displayHourlySourceStartIndex = 0

    private var lastBoundLocationId: String?
    private var lastHourlyDisplaySignature: String?
    private var hasLoggedHourlyAlignmentDebug = false
    private var fallbackAlertTask: Task<Void, Never>?

    // MARK: - life cycle.

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.cardTitle.text = getLocalizedText("hourly_overview")

        self.vstack.axis = .vertical
        self.vstack.alignment = .center
        self.vstack.spacing = 0
        self.cardContainer.contentView.addSubview(self.vstack)

        self.summaryLabel.font = miniCaptionFont;
        self.summaryLabel.textColor = .tertiaryLabel
        self.summaryLabel.numberOfLines = 0
        self.summaryLabel.lineBreakMode = .byWordWrapping
        self.vstack.addArrangedSubview(self.summaryLabel)

        self.noticeContainer.backgroundColor = .secondarySystemFill
        self.noticeContainer.layer.cornerRadius = 8.0
        self.noticeContainer.layer.masksToBounds = true
        self.noticeContainer.isHidden = true
        self.vstack.addArrangedSubview(self.noticeContainer)

        self.noticeTextStack.axis = .vertical
        self.noticeTextStack.alignment = .fill
        self.noticeTextStack.spacing = 2.0
        self.noticeContainer.addSubview(self.noticeTextStack)

        self.noticeTitleLabel.font = .systemFont(ofSize: miniCaptionFont.pointSize, weight: .bold)
        self.noticeTitleLabel.textColor = .label
        self.noticeTitleLabel.numberOfLines = 1
        self.noticeTextStack.addArrangedSubview(self.noticeTitleLabel)

        self.noticeSubtitleLabel.font = tinyCaptionFont
        self.noticeSubtitleLabel.textColor = .secondaryLabel
        self.noticeSubtitleLabel.numberOfLines = 2
        self.noticeSubtitleLabel.lineBreakMode = .byTruncatingTail
        self.noticeTextStack.addArrangedSubview(self.noticeSubtitleLabel)

        self.noticeSeparator.backgroundColor = .separator.withAlphaComponent(0.45)
        self.noticeSeparator.isHidden = true

        self.minutelyTitle.text = getLocalizedText("precipitation_overview")
        self.minutelyTitle.font = titleFont
        self.minutelyTitleVibrancyContainer.effect = nil
        self.minutelyTitleVibrancyContainer.contentView.addSubview(self.minutelyTitle)
        self.minutelyTitleVibrancyContainer.isHidden = true
        self.vstack.addArrangedSubview(self.minutelyTitleVibrancyContainer)

        self.minutelyView.isHidden = true
        self.vstack.addArrangedSubview(self.minutelyView)

        self.vstack.addArrangedSubview(self.noticeSeparator)
        self.vstack.addArrangedSubview(self.tagPaddingTop)

        self.hourlyTagView.tagDelegate = self
        self.vstack.addArrangedSubview(self.hourlyTagView)

        self.hourlyCollectionView.delegate = self
        self.hourlyCollectionView.dataSource = self
        self.hourlyCollectionView.highlightsLeadingVisibleItem = true
        self.getAllTrendGeneratorTypes().forEach { item in
            item.registerCellClass(to: self.hourlyCollectionView)
        }
        self.hourlyTrendGroupView.addSubview(self.hourlyCollectionView)

        self.hourlyBackgroundView.isUserInteractionEnabled = false
        self.hourlyTrendGroupView.addSubview(self.hourlyBackgroundView)

        self.vstack.addArrangedSubview(self.hourlyTrendGroupView)

        self.titleVibrancyContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(MainCardLayoutMetrics.titleTopPadding)
            make.leading.equalToSuperview().offset(normalMargin)
            make.trailing.equalToSuperview().offset(-normalMargin)
        }
        self.vstack.snp.makeConstraints { make in
            make.top.equalTo(self.titleVibrancyContainer.snp.bottom)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        self.summaryLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(normalMargin)
            make.trailing.equalToSuperview().offset(-normalMargin)
        }
        self.noticeContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(normalMargin)
            make.trailing.equalToSuperview().offset(-normalMargin)
        }
        self.noticeTextStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(littleMargin)
            make.leading.equalToSuperview().offset(littleMargin)
            make.trailing.equalToSuperview().offset(-littleMargin)
            make.bottom.equalToSuperview().offset(-littleMargin)
        }
        self.noticeSeparator.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(normalMargin)
            make.trailing.equalToSuperview().offset(-normalMargin)
            make.height.equalTo(0.5)
        }
        self.minutelyTitleVibrancyContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(normalMargin)
            make.trailing.equalToSuperview().offset(-normalMargin)
        }
        self.minutelyView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(minutelyTrendViewHeight)
        }
        self.tagPaddingTop.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(MainCardLayoutMetrics.sectionSpacing)
        }
        self.hourlyTagView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(MainCardLayoutMetrics.tagHeight)
        }
        self.hourlyTrendGroupView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(hourlyTrendViewHeight + MainCardLayoutMetrics.hourlyTrendGroupVerticalPadding)
        }
        self.hourlyBackgroundView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(hourlyTrendViewHeight)
        }
        self.hourlyCollectionView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(hourlyTrendViewHeight)
        }

        self.minutelyTitle.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(MainCardLayoutMetrics.sectionSpacing)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-MainCardLayoutMetrics.sectionSpacing)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.onDeviceOrientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func bindData(location: Location, timeBar: MainTimeBarView?) {
        super.bindData(location: location, timeBar: timeBar)
        self.applyReadableHourlyColors(location: location)
        self.fallbackAlertTask?.cancel()
        let locationChanged = self.lastBoundLocationId != location.formattedId
        if locationChanged {
            self.lastBoundLocationId = location.formattedId
            self.hasLoggedHourlyAlignmentDebug = false
            self.lastHourlyDisplaySignature = nil
        }

        guard let weather = location.weather else {
            self.displayLocation = nil
            self.displayHourlySourceStartIndex = 0
            self.lastHourlyDisplaySignature = nil
            self.configureNotice(nil)
            self.configureMinutely(nil, location: location)
            return
        }

        self.summaryLabel.text = weather.current.hourlyForecast
        self.summaryLabel.isHidden = (weather.current.hourlyForecast ?? "").isEmpty
        self.configureNotice(
            HourlyWeatherNoticeBuilder.build(
                for: location,
                weather: weather,
                fallbackAlerts: WeatherAlertProviderBridge.cachedFallbackAlerts(for: location)
            )
        )
        self.fetchFallbackAlertNoticeIfNeeded(location: location, weather: weather)
        self.configureMinutely(weather, location: location)

        let display = Self.makeDisplayLocation(from: location, weather: weather)
        self.displayLocation = display.location
        self.displayHourlySourceStartIndex = display.sourceStartIndex

        let generators = self.ensureTrendGenerators(for: display.location)
        self.validTrendGenerators = generators.valid
        self.hourlyTagView.tagList = generators.valid.map { item in
            item.dispayName
        }

        self.hourlyCollectionView.reloadData()
        self.resetHourlyCollectionIfNeeded(
            signature: display.signature,
            location: display.location
        )
    }

    deinit {
        self.fallbackAlertTask?.cancel()
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.applyReadableHourlyColors(location: self.location)
        DispatchQueue.main.async {
            self.hourlyCollectionView.reloadData()
        }
    }

    @objc private func onDeviceOrientationChanged() {
        if !self.hourlyCollectionView.indexPathsForVisibleItems.isEmpty {
            self.hourlyCollectionView.reloadData()
        }
    }

    // MARK: - generators.

    private func ensureTrendGenerators(
        for location: Location
    ) -> (
        total: [MainTrendGeneratorProtocol],
        valid: [MainTrendGeneratorProtocol]
    ) {
        let total = self.getAllTrendGeneratorTypes().map { item in
            item.init(location)
        }
        let valid = total.filter { item in
            item.isValid
        }
        return (total: total, valid: valid)
    }

    private func getAllTrendGeneratorTypes() -> [MainTrendGeneratorProtocol.Type] {
        return [
            HourlyTemperatureTrendGenerator.self,
            HourlyWindTrendGenerator.self,
            HourlyAirQualityTrendGenerator.self,
            HourlyPrecipitationTrendGenerator.self,
            HourlyHumidityTrendGenerator.self,
            HourlyVisibilityTrendGenerator.self,
        ]
    }

    // MARK: - scroll view delegate.

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollView.setNeedsLayout()
    }

    // MARK: - collection view delegate.

    // collection view delegate flow layout.

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        return self.hourlyCollectionView.cellSize
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        self.window?.windowScene?.eventBus.post(
            HourlyTrendCellTapAction(index: self.sourceHourlyIndex(forDisplayIndex: indexPath.row))
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard
            let weather = self.location?.weather,
            let timezone = self.location?.timezone
        else {
            return nil
        }

        return UIContextMenuConfiguration(
            identifier: NSNumber(value: indexPath.row)
        ) {
            return UIHostingController<HourlyView>(
                rootView: HourlyView(
                    weather: weather,
                    index: self.sourceHourlyIndex(forDisplayIndex: indexPath.row),
                    timezone: timezone
                )
            )
        } actionProvider: { _ in
            return nil
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        guard let row = (configuration.identifier as? NSNumber)?.intValue else {
            return nil
        }
        guard let cell = collectionView.cellForItem(
            at: IndexPath(row: row, section: 0)
        ) else {
            return nil
        }

        let params = UIPreviewParameters()
        params.backgroundColor = .clear

        return UITargetedPreview(view: cell, parameters: params)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        return self.collectionView(
            collectionView,
            previewForHighlightingContextMenuWithConfiguration: configuration
        )
    }

    // data source.

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        return self.displayLocation?.weather?.hourlyForecasts.count ?? 0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        return self.validTrendGenerators[
            self.hourlyTagView.selectedIndex
        ].bindCellData(
            at: indexPath,
            to: collectionView
        )
    }

    // MARK: - selectable tag view delegate.

    func getSelectedColor() -> UIColor {
        return .systemBlue
    }

    func getUnselectedColor() -> UIColor {
        return UIColor(
            ThemeManager.weatherThemeDelegate.getThemeColor(
                weatherKind: weatherCodeToWeatherKind(
                    code: self.location?.weather?.current.weatherCode ?? .clear
                ),
                daylight: self.location?.isDaylight ?? true
            )
        ).withAlphaComponent(0.33)
    }

    func onSelectedChanged(newSelectedIndex: Int) {
        self.hourlyCollectionView.collectionViewLayout.invalidateLayout()
        self.hourlyCollectionView.reloadData()

        self.validTrendGenerators[
            newSelectedIndex
        ].bindCellBackground(
            to: self.hourlyBackgroundView
        )
    }

    func onSelectedRepeatly(currentSelectedIndex: Int) {
        if self.hourlyCollectionView.indexPathsForVisibleItems.first != nil {
            self.scrollHourlyCollection(to: 0, animated: true)
        }
    }

    private func resetHourlyCollectionIfNeeded(
        signature: String,
        location: Location
    ) {
        guard self.lastHourlyDisplaySignature != signature else {
            return
        }
        self.lastHourlyDisplaySignature = signature
        let hourly = location.weather?.hourlyForecasts ?? []
        self.logHourlyAlignmentDebugIfNeeded(location: location, hourly: hourly, index: 0)
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.displayLocation?.formattedId == location.formattedId,
                  self.hourlyCollectionView.numberOfSections > 0,
                  self.hourlyCollectionView.numberOfItems(inSection: 0) > 0 else {
                return
            }

            self.hourlyCollectionView.layoutIfNeeded()
            self.scrollHourlyCollection(to: 0, animated: false)
        }
    }

    private static func makeDisplayLocation(
        from location: Location,
        weather: Weather
    ) -> (location: Location, sourceStartIndex: Int, signature: String) {
        let slice = Self.displayHourlySlice(
            hourly: weather.hourlyForecasts,
            now: Date(),
            timezone: location.timezone
        )
        let displayWeather = Weather(
            base: weather.base,
            current: weather.current,
            yesterday: weather.yesterday,
            dailyForecasts: weather.dailyForecasts,
            hourlyForecasts: slice.items,
            minutelyForecast: weather.minutelyForecast,
            alerts: weather.alerts
        )
        let firstTime = slice.items.first?.time ?? 0.0
        let lastTime = slice.items.last?.time ?? 0.0
        let signature = [
            location.formattedId,
            "\(weather.base.timeStamp)",
            "\(slice.sourceStartIndex)",
            "\(slice.items.count)",
            "\(firstTime)",
            "\(lastTime)"
        ].joined(separator: "|")
        return (
            location.copyOf(weather: displayWeather),
            slice.sourceStartIndex,
            signature
        )
    }

    private static func displayHourlySlice(
        hourly: [Hourly],
        now: Date,
        timezone: TimeZone
    ) -> (items: [Hourly], sourceStartIndex: Int) {
        guard !hourly.isEmpty else {
            return ([], 0)
        }
        let startIndex = Self.currentHourlyIndex(
            hourly: hourly,
            now: now,
            displayTimeZone: timezone
        )
        let startTime = hourly[startIndex].time
        let endTime = startTime + 24.0 * 60.0 * 60.0
        let rangeItems = hourly
            .dropFirst(startIndex)
            .prefix { item in
                item.time < endTime
            }
        let items = Array(rangeItems)
        if !items.isEmpty {
            return (items, startIndex)
        }
        return (Array(hourly.dropFirst(startIndex).prefix(24)), startIndex)
    }

    private func sourceHourlyIndex(forDisplayIndex displayIndex: Int) -> Int {
        let count = self.location?.weather?.hourlyForecasts.count ?? 0
        guard count > 0 else {
            return 0
        }
        return max(0, min(self.displayHourlySourceStartIndex + displayIndex, count - 1))
    }

    static func currentHourlyIndex(
        hourly: [Hourly],
        now: Date,
        displayTimeZone: TimeZone = .current
    ) -> Int {
        guard !hourly.isEmpty else {
            return 0
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = displayTimeZone
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        if let index = hourly.firstIndex(where: { item in
            let itemComponents = calendar.dateComponents(
                [.year, .month, .day, .hour],
                from: Date(timeIntervalSince1970: item.time)
            )
            return itemComponents.year == nowComponents.year
                && itemComponents.month == nowComponents.month
                && itemComponents.day == nowComponents.day
                && itemComponents.hour == nowComponents.hour
        }) {
            return max(0, min(index, hourly.count - 1))
        }

        let targetTime = now.timeIntervalSince1970
        let index = hourly.firstIndex { item in
            item.time >= targetTime
        } ?? (hourly.count - 1)
        return max(0, min(index, hourly.count - 1))
    }

    private func scrollHourlyCollection(to index: Int, animated: Bool) {
        let itemCount = self.hourlyCollectionView.numberOfItems(inSection: 0)
        guard itemCount > 0 else {
            return
        }

        let row = max(0, min(index, itemCount - 1))
        let itemWidth = self.hourlyCollectionView.cellSize.width
        let maxOffsetX = max(0.0, self.hourlyCollectionView.contentSize.width - self.hourlyCollectionView.bounds.width)
        let leftOffsetX = min(maxOffsetX, max(0.0, CGFloat(row) * itemWidth))
        let offsetX = self.hourlyCollectionView.isRtl ? maxOffsetX - leftOffsetX : leftOffsetX
        self.hourlyCollectionView.setContentOffset(
            CGPoint(x: offsetX, y: 0.0),
            animated: animated
        )
    }

    private func configureNotice(_ notice: HourlyWeatherNotice?) {
        guard let notice = notice else {
            self.noticeContainer.isHidden = true
            self.noticeTitleLabel.text = nil
            self.noticeSubtitleLabel.text = nil
            self.updateNoticeSeparatorVisibility()
            return
        }

        self.noticeTitleLabel.text = notice.title
        self.noticeSubtitleLabel.text = notice.subtitle
        self.noticeSubtitleLabel.isHidden = (notice.subtitle ?? "").isEmpty
        self.noticeContainer.isHidden = false
        self.updateNoticeSeparatorVisibility()
    }

    private func fetchFallbackAlertNoticeIfNeeded(location: Location, weather: Weather) {
        self.fallbackAlertTask = Task { [weak self] in
            do {
                let alerts = try await WeatherAlertProviderBridge.getFallbackAlerts(for: location)
                guard !Task.isCancelled else {
                    return
                }
                await MainActor.run { [weak self] in
                    guard let self = self,
                          self.location?.formattedId == location.formattedId else {
                        return
                    }
                    self.configureNotice(
                        HourlyWeatherNoticeBuilder.build(
                            for: location,
                            weather: weather,
                            fallbackAlerts: alerts
                        )
                    )
                }
            } catch {
                printLog(
                    keyword: "weatherAlert",
                    content: "Fallback alert notice fetch failed: \(error.localizedDescription)"
                )
            }
        }
    }

    private func configureMinutely(_ weather: Weather?, location: Location) {
        guard let weather = weather,
              let minutely = weather.minutelyForecast,
              minutely.isValid else {
            self.minutelyTitleVibrancyContainer.isHidden = true
            self.minutelyView.isHidden = true
            self.updateNoticeSeparatorVisibility()
            return
        }

        let color = UIColor(
            ThemeManager.weatherThemeDelegate.getThemeColor(
                weatherKind: weatherCodeToWeatherKind(code: weather.current.weatherCode),
                daylight: location.isDaylight
            )
        )
        self.minutelyView.polylineColor = { _ in color }
        self.minutelyView.baselineColor = color
        self.minutelyView.polylineTintColor = .systemBlue

        let maxIntensity = minutely.precipitationIntensities.max { a, b in a < b } ?? precipitationIntensityHeavy
        self.minutelyView.polylineValues = minutely.precipitationIntensities.map { intensity in
            min(1.0, intensity / maxIntensity)
        }
        self.minutelyView.polylineDescriptionMapper = { value in
            let unit = SettingsManager.shared.precipitationIntensityUnit
            return unit.formatValueWithUnit(
                value * maxIntensity,
                unit: getLocalizedText(unit.key)
            )
        }
        self.minutelyView.beginTime = formateTime(
            timeIntervalSine1970: minutely.beginTime,
            twelveHour: isTwelveHour()
        )
        self.minutelyView.centerTime = formateTime(
            timeIntervalSine1970: (minutely.beginTime + minutely.endTime) / 2.0,
            twelveHour: isTwelveHour()
        )
        self.minutelyView.endTime = formateTime(
            timeIntervalSine1970: minutely.endTime,
            twelveHour: isTwelveHour()
        )

        self.minutelyTitleVibrancyContainer.isHidden = false
        self.minutelyView.isHidden = false
        self.updateNoticeSeparatorVisibility()
    }

    private func updateNoticeSeparatorVisibility() {
        self.noticeSeparator.isHidden = self.noticeContainer.isHidden
            && self.minutelyTitleVibrancyContainer.isHidden
            && self.minutelyView.isHidden
    }

    private func applyReadableHourlyColors(location: Location?) {
        self.minutelyTitle.textColor = self.readableCardTitleColor(location: location)
        self.summaryLabel.textColor = self.readableCardSecondaryTextColor()
    }

    private func logHourlyAlignmentDebugIfNeeded(
        location: Location,
        hourly: [Hourly],
        index: Int
    ) {
        #if DEBUG
        guard !self.hasLoggedHourlyAlignmentDebug else {
            return
        }
        self.hasLoggedHourlyAlignmentDebug = true
        let selected = hourly.get(index)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm zzz"
        formatter.timeZone = .current
        printLog(
            keyword: "hourlyAlignment",
            content: [
                "Hourly alignment debug:",
                "device timezone = \(TimeZone.current.identifier)",
                "location timezone = \(location.timezone.identifier)",
                "first hourly date = \(hourly.first.map { formatter.string(from: Date(timeIntervalSince1970: $0.time)) } ?? "nil")",
                "now = \(formatter.string(from: Date()))",
                "selected index = \(index)",
                "selected hour label = \(selected.map { formatter.string(from: Date(timeIntervalSince1970: $0.time)) } ?? "nil")"
            ].joined(separator: " ")
        )
        #endif
    }

}
