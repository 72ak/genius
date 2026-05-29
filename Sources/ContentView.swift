import SwiftUI

struct ContentView: View {
    @ObservedObject private var model = AppModel.shared

    private var transcriptText: String {
        [model.transcriber.transcript, model.transcriber.livePartial]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Genius")
                .font(.largeTitle.bold())

            Text(model.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Live transcript
            ScrollView {
                Text(transcriptText.isEmpty ? "…" : transcriptText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 140)

            // Recall window
            VStack(alignment: .leading, spacing: 6) {
                Text("Recall last \(Int(model.recallSeconds))s")
                Slider(value: $model.recallSeconds, in: 30...300, step: 5)
            }

            Toggle("Auto-answer when a question is heard", isOn: $model.autoMode)
            Toggle("Web search (free — Wikipedia + DuckDuckGo)", isOn: $model.webSearchEnabled)
            Toggle("Headphone play/pause triggers Genius", isOn: $model.headphoneButtonEnabled)

            Button(action: model.triggerAnswer) {
                Text(model.isThinking ? "Thinking…" : "Answer now")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isThinking)

            if !model.latestAnswer.isEmpty {
                Text(model.latestAnswer)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            if !model.lastFacts.isEmpty {
                Text("🔎 " + model.lastFacts)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            Spacer()
        }
        .padding()
        .task { await model.onAppear() }
    }
}

#Preview {
    ContentView()
}
