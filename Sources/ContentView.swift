import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Genius")
                .font(.largeTitle.bold())

            Text(model.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Live transcript
            ScrollView {
                Text(model.transcriber.livePartial.isEmpty ? "…" : model.transcriber.livePartial)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 110)

            // Recall window
            VStack(alignment: .leading, spacing: 6) {
                Text("Recall last \(Int(model.recallSeconds))s")
                Slider(value: $model.recallSeconds, in: 30...300, step: 5)
            }

            Toggle("Auto-answer when a question is heard", isOn: $model.autoMode)

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

            Spacer()
        }
        .padding()
        .task { await model.onAppear() }
    }
}

#Preview {
    ContentView()
}
