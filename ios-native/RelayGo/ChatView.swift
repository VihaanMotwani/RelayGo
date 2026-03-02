import SwiftUI
import AVFoundation

struct ChatView: View {
    @EnvironmentObject var relay: RelayService
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome message if empty
                            if relay.chatMessages.isEmpty {
                                WelcomeCard()
                                    .padding(.top, 20)
                            }

                            ForEach(relay.chatMessages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if relay.isThinking {
                                ThinkingIndicator()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: relay.chatMessages.count) { _, _ in
                        if let last = relay.chatMessages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input bar
                HStack(spacing: 12) {
                    // Microphone button
                    Button(action: toggleRecording) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title)
                            .foregroundStyle(isRecording ? .red : .orange)
                    }
                    .disabled(relay.isThinking)

                    TextField("Describe your emergency...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .focused($isInputFocused)
                        .onSubmit(send)

                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty || relay.isThinking)
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("Emergency Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if relay.isEngineReady {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .help("AI Engine Ready")
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false

        Task {
            await relay.sendToAI(text)
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
            recordingURL = audioFilename

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true

            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false

        guard let url = recordingURL else { return }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        Task {
            await relay.transcribeAndSend(audioPath: url.path)
        }
    }
}

// MARK: - Welcome Card

struct WelcomeCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cross.circle")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            Text("Emergency Assistant")
                .font(.headline)

            Text("Describe your situation and I'll provide verified emergency guidance from official sources.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Quick prompts
            VStack(spacing: 8) {
                QuickPrompt(text: "There's a fire nearby")
                QuickPrompt(text: "Someone is injured")
                QuickPrompt(text: "I felt an earthquake")
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct QuickPrompt: View {
    @EnvironmentObject var relay: RelayService
    let text: String

    var body: some View {
        Button {
            Task { await relay.sendToAI(text) }
        } label: {
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background(message.isUser ? .blue : Color(.systemGray5))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Verified badge for AI responses
                if !message.isUser && message.isVerified {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                        Text("Verified guidance")
                            .font(.caption2)
                    }
                    .foregroundStyle(.green)
                }
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Thinking Indicator

struct ThinkingIndicator: View {
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("AI is thinking...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(RelayService())
}
