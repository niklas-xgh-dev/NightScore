//
//  NightScoreWidgetBundle.swift
//  NightScoreWidget
//
//  Created by iroot on 05.04.25.
//

import WidgetKit
import SwiftUI

@main
struct NightScoreWidgetBundle: WidgetBundle {
    var body: some Widget {
        NightScoreWidget()
        NightScoreWidgetControl()
        NightScoreWidgetLiveActivity()
    }
}
