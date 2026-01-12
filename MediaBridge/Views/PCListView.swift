import SwiftUI

struct PCListView: View {
    @EnvironmentObject var viewModel: MainViewModel
    
    var body: some View {
        NavigationView {
            List(viewModel.devices) { device in
                Button(action: {
                    viewModel.connect(to: device)
                }) {
                    HStack {
                        Image(systemName: "laptopcomputer")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                        
                        VStack(alignment: .leading) {
                            Text(device.name)
                                .font(.headline)
                            Text(device.ipAddress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Connect to PC")
        }
    }
}
