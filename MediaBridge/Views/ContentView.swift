import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State private var showingError = false

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
        .onAppear {
            viewModel.startServices()
        }
        .onDisappear {
            viewModel.stopServices()
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
        .alert("Connection Error", isPresented: $showingError) {
            Button("Retry") {
                viewModel.retryConnection()
            }
            Button("Cancel", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MainViewModel())
}
