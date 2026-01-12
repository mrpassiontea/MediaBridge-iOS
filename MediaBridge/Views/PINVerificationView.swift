import SwiftUI

struct PINVerificationView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State private var timeRemaining = 30
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("Connection Request")
                .font(.title2)
                .bold()
            
            Text("Enter this PIN on your computer to approve connection.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(height: 80)
                
                Text(viewModel.pinCode ?? "----")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 40)
            
            HStack {
                Text("Expires in \(timeRemaining)s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.cancelConnection()
            }) {
                Text("Cancel Request")
                    .foregroundColor(.red)
                    .padding()
            }
            .padding(.bottom)
        }
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                // In real app, timeout logic would be handled by service
                // viewModel.cancelConnection()
            }
        }
    }
}
