import Foundation
import Combine

class PINService: ObservableObject {
    static let shared = PINService()

    @Published private(set) var currentPIN: String?
    @Published private(set) var timeRemaining: Int = 0
    @Published private(set) var failedAttempts: Int = 0

    private var expirationTimer: Timer?
    private var countdownTimer: Timer?

    // Configuration
    let pinTimeout: TimeInterval = 30  // 30 seconds
    let maxFailedAttempts = 3

    private init() {}

    // MARK: - PIN Generation

    func generatePIN() -> String {
        // Cancel any existing PIN session
        cancelPIN()

        // Generate 4-digit PIN
        let pin = String(format: "%04d", Int.random(in: 0...9999))
        currentPIN = pin
        timeRemaining = Int(pinTimeout)
        failedAttempts = 0

        // Start countdown
        startCountdown()

        print("[PIN] Generated new PIN: \(pin)")
        return pin
    }

    private func startCountdown() {
        // Clear existing timers
        expirationTimer?.invalidate()
        countdownTimer?.invalidate()

        // Countdown timer (updates every second)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            }
        }

        // Expiration timer
        expirationTimer = Timer.scheduledTimer(withTimeInterval: pinTimeout, repeats: false) { [weak self] _ in
            self?.expirePIN()
        }
    }

    // MARK: - PIN Verification

    func verify(pin: String) -> PINVerificationResult {
        guard let currentPIN = currentPIN else {
            return .expired
        }

        guard timeRemaining > 0 else {
            return .expired
        }

        if pin == currentPIN {
            // Success - clear the PIN
            cancelPIN()
            print("[PIN] Verification successful")
            return .success
        } else {
            failedAttempts += 1
            print("[PIN] Verification failed (attempt \(failedAttempts)/\(maxFailedAttempts))")

            if failedAttempts >= maxFailedAttempts {
                cancelPIN()
                return .maxAttemptsReached
            }

            return .failed(attemptsRemaining: maxFailedAttempts - failedAttempts)
        }
    }

    // MARK: - PIN Lifecycle

    func cancelPIN() {
        expirationTimer?.invalidate()
        expirationTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil

        currentPIN = nil
        timeRemaining = 0

        print("[PIN] PIN session cancelled")
    }

    private func expirePIN() {
        cancelPIN()
        print("[PIN] PIN expired")
    }

    var isPINActive: Bool {
        currentPIN != nil && timeRemaining > 0
    }
}

// MARK: - Verification Result

enum PINVerificationResult {
    case success
    case failed(attemptsRemaining: Int)
    case expired
    case maxAttemptsReached

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
