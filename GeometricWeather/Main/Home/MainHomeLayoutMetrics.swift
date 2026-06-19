//
//  MainHomeLayoutMetrics.swift
//  GeometricWeather
//
//  Created by Codex on 2026/6/18.
//

import UIKit

enum MainHomeLayoutMetrics {
    static func firstCardTopRatio(for bounds: CGRect) -> CGFloat {
        let height = bounds.height
        if height <= 800.0 {
            return 0.56
        }
        if height <= 920.0 {
            return 0.59
        }
        return 0.60
    }

    static func weatherHeaderHeight(
        for bounds: CGRect,
        safeAreaTop: CGFloat,
        themeHeaderHeight: CGFloat
    ) -> CGFloat {
        let targetHeight = bounds.height * firstCardTopRatio(for: bounds) - safeAreaTop
        return max(0.0, min(themeHeaderHeight, targetHeight))
    }
}
