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

            ScrollView {
                Text(transcriptText.isEmpty ? "..." : transcriptText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 140)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Recall last \(Int(model.recallSeconds))s")
                    Spacer()
                    Button("Clear transcript", role: .destructive) {
                        model.clearTranscript()
                    }
                    .buttonStyle(.bordered)
                    .disabled(transcriptText.isEmpty && model.latestAnswer.isEmpty && model.lastFacts.isEmpty)
                }
                Slider(value: $model.recallSeconds, in: 30...300, step: 5)
            }

            Toggle("Auto-answer when a question is heard", isOn: $model.autoMode)
            Toggle("Web search (free - Wikipedia + DuckDuckGo)", isOn: $model.webSearchEnabled)
            Toggle("Headphone play/pause triggers Genius", isOn: $model.headphoneButtonEnabled)

            VStack(alignment: .leading, spacing: 8) {
                Picker("Answer model", selection: $model.brainMode) {
                    ForEach(BrainMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if model.brainMode == .localQwen {
                    Text(model.localQwenModelName)
                        .font(.headline)

                    Text("Targeting 4B first because it is much more realistic for fast local iPhone answers than 8B/27B. Runtime/model install still needs to be wired.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: model.triggerAnswer) {
                Text(model.isThinking ? "Thinking..." : "Answer now")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isThinking)

            if !model.latestAnswer.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Answer preview")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(model.latestAnswer)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 80, maxHeight: 180)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            if !model.lastFacts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fetched facts")
                        .font(.caption.bold())
                    ScrollView {
                        Text(model.lastFacts)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 44, maxHeight: 110)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
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
