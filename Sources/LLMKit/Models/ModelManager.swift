import Foundation

/// Errors specific to Model Management
public enum ModelManagerError: Error {
    case invalidURL
    case downloadFailed(Int)
    case fileMoveError
}

/// Manages the downloading, caching, and importing of GGUF models on Apple devices.
public class ModelManager {
    
    // MARK: - Standard Download
    
    /// Downloads any raw .gguf direct link (e.g., from a user pasting a specific HuggingFace resolve link).
    /// Perfect for PRO users who want specific quantizations (Q4_K_M, Q8_0, etc.).
    /// - Parameters:
    ///   - directURLString: The exact download URL (e.g., "https://huggingface.co/.../resolve/main/model-q4_k_m.gguf")
    ///   - customFileName: Optional. If nil, it tries to extract the name from the URL.
    /// - Returns: The local URL path where the model is stored on the device.
    public static func download(from directURLString: String, customFileName: String? = nil) async throws -> URL {
        guard let url = URL(string: directURLString) else {
            throw ModelManagerError.invalidURL
        }
        
        // Extract filename from URL or use the custom one provided
        let fileName = customFileName ?? url.lastPathComponent
        let safeFileName = fileName.hasSuffix(".gguf") ? fileName : "\(fileName).gguf"
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsDirectory.appendingPathComponent(safeFileName)
        
        // Smart Caching: If the exact quantization is already downloaded, skip!
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("🧠 LLMKit: [Cache Hit] Model '\(safeFileName)' already exists on device!")
            return destinationURL
        }
        
        print("⏳ LLMKit: Downloading '\(safeFileName)' to local storage...")
        
        // Start the native async download
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw ModelManagerError.downloadFailed((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        // Securely move to the App's Documents folder
        do {
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            print("✅ LLMKit: Download complete! Model stored at: \(destinationURL.path)")
            return destinationURL
        } catch {
            throw ModelManagerError.fileMoveError
        }
    }
    
    // MARK: - HuggingFace Smart Helper
    
    /// A helper for standard HuggingFace paths.
    /// Generates the exact download link for a specific quantization.
    public static func getHuggingFaceURL(repo: String, modelPrefix: String, quantization: String = "Q4_K_M") -> String {
        // Example output: "https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGUF/resolve/main/llama-2-7b-chat.Q4_K_M.gguf"
        return "https://huggingface.co/\(repo)/resolve/main/\(modelPrefix).\(quantization).gguf"
    }
}
