import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AttachmentPicker: View {
    @Binding var selectedImageData: Data?
    @Binding var isPresented: Bool
    @State private var selectedItem: PhotosPickerItem?
    @State private var showFilePicker = false

    var body: some View {
        Menu {
            Button {
                showFilePicker = true
            } label: {
                Label("从文件选择", systemImage: "doc")
            }
        } label: {
            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .photosPicker(
            isPresented: $isPresented,
            selection: $selectedItem,
            matching: .images
        )
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        selectedImageData = data
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .pdf, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    selectedImageData = try? Data(contentsOf: url)
                }
            }
        }
    }
}
