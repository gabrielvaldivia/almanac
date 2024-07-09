//
//  UpNextWidgetLiveActivity.swift
//  UpNextWidget
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct UpNextWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct UpNextWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: UpNextWidgetAttributes.self) { context in
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

extension UpNextWidgetAttributes {
    fileprivate static var preview: UpNextWidgetAttributes {
        UpNextWidgetAttributes(name: "World")
    }
}

extension UpNextWidgetAttributes.ContentState {
    fileprivate static var smiley: UpNextWidgetAttributes.ContentState {
        UpNextWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: UpNextWidgetAttributes.ContentState {
         UpNextWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: UpNextWidgetAttributes.preview) {
   UpNextWidgetLiveActivity()
} contentStates: {
    UpNextWidgetAttributes.ContentState.smiley
    UpNextWidgetAttributes.ContentState.starEyes
}
