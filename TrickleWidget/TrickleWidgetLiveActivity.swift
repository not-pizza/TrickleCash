//
//  TrickleWidgetLiveActivity.swift
//  TrickleWidget
//
//  Created by Andre Popovitch on 7/6/24.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TrickleWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TrickleWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrickleWidgetAttributes.self) { context in
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

extension TrickleWidgetAttributes {
    fileprivate static var preview: TrickleWidgetAttributes {
        TrickleWidgetAttributes(name: "World")
    }
}

extension TrickleWidgetAttributes.ContentState {
    fileprivate static var smiley: TrickleWidgetAttributes.ContentState {
        TrickleWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TrickleWidgetAttributes.ContentState {
         TrickleWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TrickleWidgetAttributes.preview) {
   TrickleWidgetLiveActivity()
} contentStates: {
    TrickleWidgetAttributes.ContentState.smiley
    TrickleWidgetAttributes.ContentState.starEyes
}
