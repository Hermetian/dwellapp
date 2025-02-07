import SwiftUI

public struct RadialMenuItem: Identifiable {
    public let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
    
    public init(title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
}

public struct RadialMenu: View {
    let items: [RadialMenuItem]
    @Binding var isPressed: Bool
    @State private var dragLocation: CGPoint = .zero
    @State private var selectedIndex: Int?
    @State private var isDragging = false
    
    public init(items: [RadialMenuItem], isPressed: Binding<Bool>) {
        self.items = items
        self._isPressed = isPressed
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Menu items
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    MenuItemView(
                        item: item,
                        position: position(for: index, in: geometry.size),
                        isSelected: selectedIndex == index
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        selectedIndex = nearestItem(to: value.location, in: geometry.size)
                    }
                    .onEnded { value in
                        if let selected = selectedIndex {
                            items[selected].action()
                        }
                        selectedIndex = nil
                    }
            )
        }
    }
    
    private func position(for index: Int, in size: CGSize) -> CGPoint {
        let radius = min(size.width, size.height) * 0.45
        let angleRange = Double.pi
        let angleStep = angleRange / Double(max(1, items.count - 1))
        let startAngle = Double.pi
        let angle = startAngle - Double(index) * angleStep
        
        let yOffset: CGFloat = 10
        let x = size.width / 2 + radius * cos(angle)
        let y = size.height - yOffset - radius * sin(angle)
        return CGPoint(x: x, y: y)
    }
    
    private func nearestItem(to point: CGPoint, in size: CGSize) -> Int? {
        let yOffset: CGFloat = 10
        let center = CGPoint(x: size.width / 2, y: size.height - yOffset)
        let vector = CGPoint(x: point.x - center.x, y: point.y - center.y)
        
        let minDistance = min(size.width, size.height) * 0.1
        let distance = sqrt(vector.x * vector.x + vector.y * vector.y)
        if distance < minDistance {
            return nil
        }
        
        // Calculate angle in the range 0 to π (0° to 180°)
        var angle = atan2(-vector.y, vector.x)
        if angle < 0 {
            angle += 2 * Double.pi
        }
        
        // Only allow selection in the top semicircle
        if angle > Double.pi {
            return nil
        }
        
        let angleStep = Double.pi / Double(max(1, items.count - 1))
        // Use (π - angle) to maintain left-to-right ordering matching the position() function
        let index = Int(round((Double.pi - angle) / angleStep))
        
        // Only return an index if we're close enough to an item
        let radius = min(size.width, size.height) * 0.45
        if distance > radius * 1.3 { // Allow a bit of extra reach
            return nil
        }
        
        return index >= 0 && index < items.count ? index : nil
    }
}

private struct MenuItemView: View {
    let item: RadialMenuItem
    let position: CGPoint
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: item.icon)
                .font(.title2)
            Text(item.title)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80, height: 80)
        .background(
            Circle()
                .fill(isSelected ? Color.blue : Color.white)
                .shadow(radius: 4)
        )
        .foregroundColor(isSelected ? .white : .primary)
        .position(x: position.x, y: position.y)
    }
} 