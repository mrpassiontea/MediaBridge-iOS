import Foundation

enum AppState {
    case searching      // Looking for PCs
    case pcList         // Found PCs, showing list
    case connecting     // Connecting to selected PC
    case verifying      // Showing PIN, waiting for verification
    case connected      // PIN verified, syncing
    case ready          // Ready for transfers
    case error          // Error state
}
