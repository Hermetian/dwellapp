import SwiftUI
import AVKit
import Core

public struct AIAssistedInteractiveEditingView: View {
    @Binding var videoURL: URL
    @State private var command: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String = ""
    
    let aiService: AIAssistedEditorService
    
    public init(videoURL: Binding<URL>, videoService: VideoService) {
        self._videoURL = videoURL
        self.aiService = AIAssistedEditorService(videoService: videoService)
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            TextField("Enter editing command (e.g., 'create a 1-minute highlight reel')", text: $command)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Apply Command") {
                Task {
                    await applyCommand()
                }
            }
            .disabled(command.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
            .buttonStyle(.borderedProminent)
            
            if isProcessing {
                ProgressView("Processing command...")
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    private func applyCommand() async {
        isProcessing = true
        errorMessage = ""
        do {
            let newURL = try await aiService.applyEditingCommand(command: command, on: videoURL)
            videoURL = newURL
        } catch {
            errorMessage = "Failed to apply command: \(error.localizedDescription)"
        }
        isProcessing = false
    }
}
