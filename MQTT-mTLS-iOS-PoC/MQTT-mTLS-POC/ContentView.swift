import SwiftUI

struct ContentView: View {
    private let service = MQTTService()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .onAppear {
            service.connect()
        }
    }
}

#Preview {
    ContentView()
}
