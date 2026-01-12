import SwiftUI

struct SearchingView: View {
    @State private var isPulsing = false
    
    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0.0 : 1.0)
                    .animation(Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
                
                Image(systemName: "wifi")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 20)
            
            Text("Searching for PCs...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("Make sure MediaBridge is open on Windows")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 40)
        }
        .onAppear {
            isPulsing = true
        }
    }
}
