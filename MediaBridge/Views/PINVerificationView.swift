import SwiftUI

struct PINVerificationView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Text("Connection Request")
                .font(.title2)
                .bold()

            if let deviceName = viewModel.connectedDevice?.name {
                Text("Connecting to \(deviceName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("Enter this PIN on MediaBridge to approve the connection.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)

            // PIN Display
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(height: 80)

                HStack(spacing: 12) {
                    ForEach(Array(pinDigits), id: \.offset) { _, digit in
                        Text(String(digit))
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(width: 44)
                    }
                }
            }
            .padding(.horizontal, 40)
            .accessibilityLabel("PIN code: \(accessiblePIN)")

            // Countdown Timer
            ZStack {
                Circle()
                    .stroke(Color(UIColor.systemGray4), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: timeProgress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: viewModel.pinTimeRemaining)

                Text("\(viewModel.pinTimeRemaining)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(timerColor)
            }

            Text("Waiting for PIN entry...")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                triggerHaptic()
                viewModel.cancelConnection()
            }) {
                Text("Cancel Request")
                    .foregroundColor(.red)
                    .padding()
            }
            .padding(.bottom)
        }
    }

    // MARK: - Computed Properties

    private var pinDigits: [(offset: Int, element: Character)] {
        let pin = viewModel.pinCode ?? "----"
        return Array(pin.enumerated())
    }

    private var accessiblePIN: String {
        let pin = viewModel.pinCode ?? "----"
        return pin.map { String($0) }.joined(separator: ", ")
    }

    private var timeProgress: Double {
        Double(viewModel.pinTimeRemaining) / 30.0
    }

    private var timerColor: Color {
        if viewModel.pinTimeRemaining <= 5 {
            return .red
        } else if viewModel.pinTimeRemaining <= 10 {
            return .orange
        }
        return .blue
    }

    // MARK: - Haptics

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

#Preview {
    PINVerificationView()
        .environmentObject(MainViewModel())
}
