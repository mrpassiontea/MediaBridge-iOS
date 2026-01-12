import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: MainViewModel
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            Group {
                switch viewModel.state {
                case .searching:
                    if viewModel.devices.isEmpty {
                        SearchingView()
                    } else {
                        PCListView()
                    }
                case .pcList:
                    PCListView()
                case .verifying:
                    PINVerificationView()
                case .connected:
                    ConnectedView()
                case .ready:
                    ReadyView()
                }
            }
        }
        .animation(.easeInOut, value: viewModel.state)
    }
}
