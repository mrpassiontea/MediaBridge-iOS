import SwiftUI

struct ReadyView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                // Success Icon with Animation
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)

                Text("Ready for Transfer")
                    .font(.title2)
                    .bold()

                if let deviceName = viewModel.connectedDevice?.name {
                    Text("Connected to \(deviceName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Select photos on your computer to start download.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Asset Stats
            HStack(spacing: 30) {
                StatView(
                    icon: "photo.fill",
                    count: viewModel.photoCount,
                    label: "Photos"
                )

                Divider()
                    .frame(height: 50)

                StatView(
                    icon: "video.fill",
                    count: viewModel.videoCount,
                    label: "Videos"
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            Button(action: {
                triggerHaptic()
                viewModel.disconnect()
            }) {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("Disconnect")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear {
            showCheckmark = true
            triggerSuccessHaptic()
        }
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func triggerSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Stat View

struct StatView: View {
    let icon: String
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)

            Text("\(count)")
                .font(.title)
                .bold()

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ReadyView()
        .environmentObject(MainViewModel())
}
