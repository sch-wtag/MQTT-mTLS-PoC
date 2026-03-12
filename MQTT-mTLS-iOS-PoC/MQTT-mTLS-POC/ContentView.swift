import SwiftUI

struct ContentView: View {
    private let service = MQTTService()
    @State private var id: String = ""
    
    var body: some View {
        VStack {
            TextField("Enter your name", text: $id)
            
            HStack {
                Button {
                    service.disconnect()
                    service.connect()
                } label: {
                    Text("CONNECT")
                }
                
                Button {
                    service.subscribe(id: id)
                } label: {
                    Text("SUBSCRIBE")
                }
                
                Button {
                    service.publish(id: id)
                } label: {
                    Text("PUBLISH")
                }
            }
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
