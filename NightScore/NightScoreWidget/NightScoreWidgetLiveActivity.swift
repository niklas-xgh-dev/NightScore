//
//  NightScoreWidgetLiveActivity.swift
//  NightScoreWidget
//
//  Created by iroot on 05.04.25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct NightScoreWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct NightScoreWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NightScoreWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension NightScoreWidgetAttributes {
    fileprivate static var preview: NightScoreWidgetAttributes {
        NightScoreWidgetAttributes(name: "World")
    }
}

extension NightScoreWidgetAttributes.ContentState {
    fileprivate static var smiley: NightScoreWidgetAttributes.ContentState {
        NightScoreWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: NightScoreWidgetAttributes.ContentState {
         NightScoreWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: NightScoreWidgetAttributes.preview) {
   NightScoreWidgetLiveActivity()
} contentStates: {
    NightScoreWidgetAttributes.ContentState.smiley
    NightScoreWidgetAttributes.ContentState.starEyes
}
