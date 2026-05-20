import SwiftUI
import LLMKit

/// A plug-and-play Chat View that developers can drop anywhere in their Apple apps!
public struct LLMChatView: View {
    @State private var engine = LocalLLMEngine()
    @State private var prompt: String = ""
    @State private var chatHistory: [String] = []
    @State private var isDownloading = false
    
    public init() {}
    
    public var body: some View {
        VStack {
            // Header
            HStack {
                Text("🧠 LLMKit Demo")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(engine.isLoaded ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(engine.isLoaded ? "Metal Active" : "No Model")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            // Chat Area
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(chatHistory, id: \.self) { message in
                        Text(message)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    if !engine.currentOutput.isEmpty {
                        Text(engine.currentOutput)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            
            // Download / Loading State
            if isDownloading {
                ProgressView("Downloading GGUF to device...")
                    .padding()
            }
            
            // Input Area
            HStack {
                TextField("Type a message...", text: $prompt)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(!engine.isLoaded)
                
                Button("Send") {
                    sendMessage()
                }
                .disabled(prompt.isEmpty || !engine.isLoaded)
            }
            .padding()
            
            // The "Magic" Button to load a model
            if !engine.isLoaded && !isDownloading {
                Button("Load Default Model (TinyLlama)") {
                    loadModel()
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            }
        }
    }
    
    private func loadModel() {
        isDownloading = true
        Task {
            do {
                // Here is where the magic of our SDK happens!
                let url = "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
                
                let localPath = try await ModelManager.download(from: url)
                try await engine.load(modelPath: localPath)
                
                await MainActor.run {
                    self.isDownloading = false
                }
            } catch {
                print("Error loading model: \(error)")
                await MainActor.run { self.isDownloading = false }
            }
        }
    }
    
    private func sendMessage() {
        let userMessage = "User: \(prompt)"
        chatHistory.append(userMessage)
        let promptToSend = prompt
        prompt = ""
        
        Task {
            await engine.generate(prompt: promptToSend)
            chatHistory.append("AI: \(engine.currentOutput)")
        }
    }
}
// MARK: - SwiftUI Preview
#Preview {
    LLMChatView()
}
