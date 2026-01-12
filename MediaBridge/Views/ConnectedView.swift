import SwiftUI

struct ConnectedView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State private var isSpinning = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                // Animated sync icon
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 2)
                            .repeatForever(autoreverses: false),
                        value: isSpinning
                    )

                Text(deviceStatusText)
                    .font(.headline)

                if let deviceName = viewModel.connectedDevice?.name {
                    Text(deviceName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Progress Section
            VStack(spacing: 12) {
                Text("Syncing...")
                    .font(.body)
                    .foregroundColor(.secondary)

                ProgressView(value: viewModel.syncProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding(.horizontal, 40)

                Text("\(Int(viewModel.syncProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Asset count preview
            if viewModel.assetCount > 0 {
                HStack(spacing: 20) {
                    Label("\(viewModel.photoCount) photos", systemImage: "photo")
                    Label("\(viewModel.videoCount) videos", systemImage: "video")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                triggerHaptic()
                viewModel.disconnect()
            }) {
                Text("Cancel")
                    .foregroundColor(.red)
                    .padding()
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            isSpinning = true
        }
    }

    private var deviceStatusText: String {
        if viewModel.syncProgress < 0.3 {
            return "Connecting..."
        } else if viewModel.syncProgress < 0.7 {
            return "Preparing..."
        } else {
            return "Almost ready..."
        }
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

#Preview {
    ConnectedView()
        .environmentObject(MainViewModel())
}
