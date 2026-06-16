//
//  MainFooterCell.swift
//  GeometricWeather
//
//  Created by 王大爷 on 2022/2/28.
//

import Foundation
import GeometricWeatherCore
import GeometricWeatherResources
import GeometricWeatherSettings
import GeometricWeatherDB
import GeometricWeatherTheme

struct MainFooterEditButtonTapAction {}

class MainFooterCell: UITableViewCell, AbstractMainItem {
    
    private let addressLabel = UILabel(frame: .zero)
    private let titleLabel = UILabel(frame: .zero)
    private let editButton = CornerButton(frame: .zero, useLittleMargin: true)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        
        self.addressLabel.font = .systemFont(
            ofSize: miniCaptionFont.pointSize,
            weight: .medium
        )
        self.addressLabel.textColor = .white.withAlphaComponent(0.72)
        self.addressLabel.textAlignment = .center
        self.addressLabel.numberOfLines = 2
        self.addressLabel.lineBreakMode = .byTruncatingTail
        self.contentView.addSubview(self.addressLabel)
        
        self.titleLabel.font = .systemFont(
            ofSize: captionFont.pointSize,
            weight: .bold
        )
        self.titleLabel.textColor = .white
        self.titleLabel.textAlignment = .center
        self.contentView.addSubview(self.titleLabel)
        
        self.editButton.titleLabel?.font = .systemFont(
            ofSize: miniCaptionFont.pointSize,
            weight: .semibold
        )
        self.editButton.setTitleColor(.white, for: .normal)
        self.editButton.backgroundColor = .white.withAlphaComponent(0.33)
        self.editButton.addTarget(
            self,
            action: #selector(self.onEditTapped),
            for: .touchUpInside
        )
        self.contentView.addSubview(self.editButton)

        self.addressLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(normalMargin)
            make.trailing.lessThanOrEqualToSuperview().offset(-normalMargin)
            make.centerX.equalToSuperview()
        }
        self.titleLabel.snp.makeConstraints { make in
            make.top.equalTo(self.addressLabel.snp.bottom).offset(4.0)
            make.centerX.equalToSuperview()
        }
        self.editButton.snp.makeConstraints { make in
            make.top.equalTo(self.titleLabel.snp.bottom).offset(littleMargin)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func bindData(location: Location, timeBar: MainTimeBarView?) {
        if let detail = getLocationDetailText(location: location), !detail.isEmpty {
            self.addressLabel.isHidden = false
            self.addressLabel.text = (
                location.currentPosition
                ? getLocalizedText("current_location_prefix")
                : getLocalizedText("data_location_prefix")
            ) + detail
        } else {
            self.addressLabel.isHidden = true
            self.addressLabel.text = nil
        }
        self.titleLabel.text = "Powered by " + location.weatherSource.url
        self.editButton.setTitle(
            getLocalizedText("edit"),
            for: .normal
        )
    }
    
    @objc private func onEditTapped() {
        self.window?.windowScene?.eventBus.post(
            MainFooterEditButtonTapAction()
        )
    }
}
