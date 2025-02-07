import SwiftUI

public struct RangeSlider: View {
    @Binding var value: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    let step: Double
    
    public init(value: Binding<ClosedRange<Double>>, in bounds: ClosedRange<Double>, step: Double = 1) {
        self._value = value
        self.bounds = bounds
        self.step = step
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: width(for: value, in: geometry), height: 4)
                    .offset(x: position(for: value.lowerBound, in: geometry))
                
                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(radius: 2)
                        .offset(x: position(for: value.lowerBound, in: geometry))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    updateLowerBound(gesture: gesture, in: geometry)
                                }
                        )
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(radius: 2)
                        .offset(x: position(for: value.upperBound, in: geometry))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    updateUpperBound(gesture: gesture, in: geometry)
                                }
                        )
                }
            }
        }
    }
    
    private func position(for value: Double, in geometry: GeometryProxy) -> CGFloat {
        let range = bounds.upperBound - bounds.lowerBound
        let percentage = (value - bounds.lowerBound) / range
        return (geometry.size.width - 24) * CGFloat(percentage)
    }
    
    private func width(for range: ClosedRange<Double>, in geometry: GeometryProxy) -> CGFloat {
        let totalRange = bounds.upperBound - bounds.lowerBound
        let percentage = (range.upperBound - range.lowerBound) / totalRange
        return geometry.size.width * CGFloat(percentage)
    }
    
    private func updateLowerBound(gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let range = bounds.upperBound - bounds.lowerBound
        let percentage = Double(gesture.location.x / (geometry.size.width - 24))
        let newValue = bounds.lowerBound + (range * percentage)
        let steppedValue = round(newValue / step) * step
        
        if steppedValue < value.upperBound {
            value = Swift.max(bounds.lowerBound, steppedValue)...value.upperBound
        }
    }
    
    private func updateUpperBound(gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let range = bounds.upperBound - bounds.lowerBound
        let percentage = Double(gesture.location.x / (geometry.size.width - 24))
        let newValue = bounds.lowerBound + (range * percentage)
        let steppedValue = round(newValue / step) * step
        
        if steppedValue > value.lowerBound {
            value = value.lowerBound...Swift.min(bounds.upperBound, steppedValue)
        }
    }
} 