import SwiftUI

struct ConnectedView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State private var isSpinning = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: isSpinning)
                
                Text(viewModel.connectedDevice.map { "Connected to \($0.name)" } ?? "Connected")
                    .font(.headline)
            }
            
            VStack(spacing: 8) {
                Text("Syncing Thumbnails...")
                    .font(.body)
                
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.disconnect()
            }) {
                Text("Disconnect")
                    .foregroundColor(.red)
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            isSpinning = true
        }
    }
}
