import ActivityKit
import SwiftUI
import WidgetKit

struct ListeningActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ListeningActivityAttributes.self) { context in
            Link(destination: URL(string: "genius://toggle-listening")!) {
                HStack {
                    Image(systemName: context.state.isListening ? "mic.fill" : "mic.slash.fill")
                    Text(context.state.status)
                        .lineLimit(1)
                }
                .padding()
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.isListening ? "Listening" : "Off",
                          systemImage: context.state.isListening ? "mic.fill" : "mic.slash.fill")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: "genius://toggle-listening")!) {
                        Text(context.state.isListening ? "Stop" : "Start")
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.status)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: context.state.isListening ? "mic.fill" : "mic.slash.fill")
            } compactTrailing: {
                Link(destination: URL(string: "genius://toggle-listening")!) {
                    Image(systemName: context.state.isListening ? "pause.fill" : "play.fill")
                }
            } minimal: {
                Image(systemName: context.state.isListening ? "mic.fill" : "mic.slash.fill")
            }
        }
    }
}

@main
struct GeniusWidgets: WidgetBundle {
    var body: some Widget {
        ListeningActivityWidget()
    }
}
