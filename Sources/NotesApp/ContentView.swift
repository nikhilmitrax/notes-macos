import SwiftUI

struct ContentView: View {
    var body: some View {
        MarkdownEditor()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.99, alpha: 1.0)),
                        Color(NSColor(calibratedRed: 0.91, green: 0.93, blue: 0.96, alpha: 1.0))
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea()
    }
}
