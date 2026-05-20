import Foundation
import Observation
import llama // This imports our C++ Engine!

/// Errors that can occur during LLM operations.
public enum LLMError: Error {
    case modelNotFound
    case failedToLoadModel
    case failedToCreateContext
}

/// The core engine responsible for managing the local LLM via llama.cpp.
@Observable
public class LocalLLMEngine {
    
    // MARK: - State
    /// The text currently being generated (useful for SwiftUI streaming).
    public var currentOutput: String = ""
    
    /// Indicates if a model is currently loaded in memory.
    public var isLoaded: Bool = false
    
    // MARK: - C++ Pointers (Hidden from the user)
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    
    public init() {
        // Initialize the llama.cpp backend and enable Metal (Apple GPU)
        llama_backend_init()
    }
    
    deinit {
        // Clean up memory to prevent RAM leaks
        if let ctx = context { llama_free(ctx) }
        if let mdl = model { llama_free_model(mdl) }
        llama_backend_free()
    }
    
    // MARK: - Public API
    
    /// Loads a GGUF model from the local file system into memory (Metal GPU).
    /// - Parameter fileURL: The local path to the .gguf file.
    public func load(modelPath fileURL: URL) async throws {
        // 1. Run on a background thread and return our Sendable wrapper
        let pointers = try await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw LLMError.modelNotFound
            }
            
            var modelParams = llama_model_default_params()
            modelParams.n_gpu_layers = 99
            
            guard let loadedModel = llama_load_model_from_file(fileURL.path.cString(using: .utf8), modelParams) else {
                throw LLMError.failedToLoadModel
            }
            
            var contextParams = llama_context_default_params()
            contextParams.n_ctx = 2048
            contextParams.n_threads = Int32(max(1, ProcessInfo.processInfo.processorCount - 2))
            
            guard let loadedContext = llama_new_context_with_model(loadedModel, contextParams) else {
                llama_free_model(loadedModel)
                throw LLMError.failedToCreateContext
            }
            
            // Pack the pointers safely!
            return LlamaPointers(model: loadedModel, context: loadedContext)
        }.value
        
        // 2. Update pointers safely on the main thread
        await MainActor.run {
            self.model = pointers.model
            self.context = pointers.context
            self.isLoaded = true
        }
        
        print("🧠 LLMKit: Model successfully loaded onto Metal GPU!")
    }
    
    // MARK: - Core AI Generation (Phase 6)
    /// The real streaming engine. Tokenizes the prompt, evaluates it on the Apple Silicon GPU, and yields text via streaming.
    public func generate(prompt: String) async {
        guard isLoaded, let ctx = context, let mdl = model else { return }
        
        // Clear the current output for the new response
        await MainActor.run { self.currentOutput = "" }
        
        // Isolate all C++ execution in a separate background thread to keep the SwiftUI UI completely fluid
        let generationTask = Task.detached(priority: .userInitiated) { () -> Void in
            
            // 1. Transform User Text into Numeric Tokens (The language the AI actually understands)
            let maxTokens = 1024
            var tokens = [llama_token](repeating: 0, count: maxTokens)
            let promptCString = prompt.cString(using: .utf8)!
            
            let nTokens = llama_tokenize(mdl, promptCString, Int32(prompt.utf8.count), &tokens, Int32(maxTokens), true, true)
            guard nTokens > 0 else { return }
            
            // 2. Prepare the Batch to send to the GPU
            var batch = llama_batch_init(Int32(maxTokens), 0, 1)
            defer { llama_batch_free(batch) } // Automatically free native memory when done
            
            // Feed the batch with our prompt tokens
            for i in 0..<Int(nTokens) {
                batch.token[i] = tokens[i]
                batch.pos[i] = Int32(i)
                batch.n_seq_id[i] = 1
                batch.seq_id[i]![0] = 0
                batch.logits[i] = 0 // 0 = false
            }
            // We only want the AI to predict the next word AFTER the user's last word
            batch.logits[Int(nTokens) - 1] = 1 // 1 = true
            batch.n_tokens = nTokens
            
            // 3. Process the Initial Prompt (This is the peak load for the Metal GPU)
            if llama_decode(ctx, batch) != 0 {
                print("🧠 LLMKit: Error decoding the initial prompt.")
                return
            }
            
            var nCur = nTokens
            let nVocab = llama_n_vocab(mdl)
            
            // 4. The Generation Loop (The AI answering in Real-Time)
            while nCur < 512 { // Hard limit to 512 generated tokens for this demo to protect RAM
                
                // Get the mathematical probabilities for the next word
                guard let logits = llama_get_logits_ith(ctx, batch.n_tokens - 1) else { break }
                
                // Greedy Sampling: Simply pick the word with the highest probability
                var maxVal = logits[0]
                var nextToken: llama_token = 0
                for i in 1..<nVocab {
                    if logits[Int(i)] > maxVal {
                        maxVal = logits[Int(i)]
                        nextToken = llama_token(i)
                    }
                }
                
                // 5. Check for End of Stream (EOS). If the AI says it's done, break the loop.
                if nextToken == llama_token_eos(mdl) {
                    print("🧠 LLMKit: Generation completed successfully.")
                    break
                }
                
                // 6. Convert the numeric token back to Human-Readable Text
                var buf = [CChar](repeating: 0, count: 32)
                _ = llama_token_to_piece(mdl, nextToken, &buf, Int32(buf.count), 0, false)
                
                if let piece = String(validatingUTF8: buf) {
                    // Update the Chat UI immediately (Typewriter Streaming Effect!)
                    Task { @MainActor in
                        self.currentOutput += piece
                    }
                }
                
                // 7. Prepare the newly generated word and feed it back to the AI to predict the next one!
                batch.token[0] = nextToken
                batch.pos[0] = nCur
                batch.n_seq_id[0] = 1
                batch.seq_id[0]![0] = 0
                batch.logits[0] = 1
                batch.n_tokens = 1
                
                if llama_decode(ctx, batch) != 0 { break }
                
                nCur += 1
            }
        }
        
        // Wait for the AI to finish its background task
        await generationTask.value
    }
    /// A safe wrapper to pass C++ pointers across thread boundaries in Swift 6.
    private struct LlamaPointers: @unchecked Sendable {
        let model: OpaquePointer
        let context: OpaquePointer
    }
}
