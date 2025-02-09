import SwiftUI

struct ClipTrimControls: View {
    let totalDuration: Double
    @Binding var clipStart: Double
    @Binding var clipEnd: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Start: \(String(format: "%.1f", clipStart))s")
                Spacer()
                Text("End: \(String(format: "%.1f", clipEnd))s")
            }
            .font(.subheadline)
            
            // Ensure a safe range where the maximum is at least 0.1 greater than the lower bound.
            let safeClipEnd = clipEnd > clipStart ? clipEnd : clipStart + 0.1
            let safeTotalDuration = totalDuration > clipStart ? totalDuration : clipStart + 0.1
            
            // Slider for clip start, cannot exceed safeClipEnd
            Slider(value: $clipStart, in: 0...safeClipEnd, step: 0.1) {
                Text("Start")
            }
            
            // Slider for clip end, cannot be before clipStart
            Slider(value: $clipEnd, in: clipStart...safeTotalDuration, step: 0.1) {
                Text("End")
            }
        }
        .padding()
    }
}

struct ClipTrimControls_Previews: PreviewProvider {
    static var previews: some View {
        ClipTrimControls(totalDuration: 120, clipStart: .constant(10), clipEnd: .constant(50))
            .previewLayout(.sizeThatFits)
    }
} 