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

            if model.listeningEnabled {
                Button(action: model.toggleListening) {
                    Text("Turn listening off")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: model.toggleListening) {
                    Text("Turn listening on")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

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

                if model.brainMode == .appleOnDevice {
                    Picker("Apple model", selection: $model.appleModelPreference) {
                        ForEach(model.appleModelOptions, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    Text("Apple Foundation Models exposes the on-device system default model only; this preference is saved for future model variants.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if model.brainMode == .localQwen {
                    Text(model.localQwenModelName)
                        .font(.headline)

                    TextField("GGUF filename", text: $model.qwenModelFileName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    Text(LocalQwenProvider.installHint(fileName: model.qwenModelFileName))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if model.brainMode == .geminiFlashLite {
                    Picker("Gemini model", selection: $model.geminiModelName) {
                        ForEach(model.geminiModelOptions, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    TextField("Custom Gemini model", text: $model.geminiModelName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField("Gemini API key", text: $model.geminiAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    Text("Key stored in Keychain. Gemini thinking is set to minimal for low latency.")
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
