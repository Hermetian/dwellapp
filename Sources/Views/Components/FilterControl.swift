import SwiftUI

struct FilterControl: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let defaultValue: Float
    let onChange: (Float) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    value = defaultValue
                    onChange(defaultValue)
                } label: {
                    Text("Reset")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .opacity(value == defaultValue ? 0.5 : 1)
                .disabled(value == defaultValue)
            }
            
            HStack {
                Text(String(format: "%.1f", range.lowerBound))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: $value, in: range) { _ in
                    onChange(value)
                }
                
                Text(String(format: "%.1f", range.upperBound))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
} 