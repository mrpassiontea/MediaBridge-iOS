import Foundation

class PINService {
    static let shared = PINService()
    
    func generatePIN() -> String {
        let pin = Int.random(in: 1000...9999)
        return String(pin)
    }
}
