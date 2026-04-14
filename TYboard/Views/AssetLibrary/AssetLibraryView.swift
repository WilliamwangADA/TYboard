import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AssetLibraryView: View {
    @Bindable var store: AssetStore
    var onSelectAsset: ((AssetItem) -> Void)?

    @State private var showImportMenu = false
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var showAddReference = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var viewMode: ViewMode = .grid
    @State private var referenceName = ""
    @State private var referenceURL = ""
    @State private var editingAsset: AssetItem?

    enum ViewMode {
        case grid, list
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider()

            // Search + tags
            searchAndTags

            // Content
            if store.filteredAssets.isEmpty {
                emptyState
            } else {
                switch viewMode {
                case .grid:
                    gridView
                case .list:
                    listView
                }
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotos,
            maxSelectionCount: 20,
            matching: .images
        )
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .pdf, .plainText, .html, .json],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                _ = store.importFiles(from: urls)
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            importPhotos(newItems)
        }
        .alert("添加参考", isPresented: $showAddReference) {
            TextField("名称", text: $referenceName)
            TextField("URL或产品名", text: $referenceURL)
            Button("添加") {
                if !referenceName.isEmpty {
                    _ = store.addReference(name: referenceName, url: referenceURL)
                    referenceName = ""
                    referenceURL = ""
                }
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(item: $editingAsset) { asset in
            AssetDetailSheet(asset: asset, store: store)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Image(systemName: "tray.2")
            Text("素材库")
                .font(.headline)
            Text("(\(store.assets.count))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // View mode toggle
            Picker("", selection: $viewMode) {
                Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
                Image(systemName: "list.bullet").tag(ViewMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)

            // Import button
            Menu {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("从相册导入", systemImage: "photo.on.rectangle")
                }

                Button {
                    showFilePicker = true
                } label: {
                    Label("从文件导入", systemImage: "doc.badge.plus")
                }

                Button {
                    showAddReference = true
                } label: {
                    Label("添加参考链接", systemImage: "link.badge.plus")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Search + Tags

    private var searchAndTags: some View {
        VStack(spacing: 6) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索素材...", text: $store.searchQuery)
                    .textFieldStyle(.plain)
                if !store.searchQuery.isEmpty {
                    Button {
                        store.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            // Tags
            if !store.allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(store.allTags, id: \.self) { tag in
                            Button {
                                if store.selectedTags.contains(tag) {
                                    store.selectedTags.remove(tag)
                                } else {
                                    store.selectedTags.insert(tag)
                                }
                            } label: {
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        store.selectedTags.contains(tag)
                                        ? Color.accentColor.opacity(0.2)
                                        : Color.secondary.opacity(0.1),
                                        in: Capsule()
                                    )
                            }
                            .foregroundStyle(store.selectedTags.contains(tag) ? .primary : .secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)
            ], spacing: 8) {
                ForEach(store.filteredAssets) { asset in
                    AssetGridCell(asset: asset, store: store)
                        .onTapGesture {
                            onSelectAsset?(asset)
                        }
                        .onLongPressGesture {
                            editingAsset = asset
                        }
                        .contextMenu {
                            assetContextMenu(asset)
                        }
                }
            }
            .padding(12)
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(store.filteredAssets) { asset in
                AssetListRow(asset: asset, store: store)
                    .onTapGesture {
                        onSelectAsset?(asset)
                    }
                    .contextMenu {
                        assetContextMenu(asset)
                    }
            }
            .onDelete { indexSet in
                let assetsToDelete = indexSet.map { store.filteredAssets[$0] }
                assetsToDelete.forEach { store.deleteAsset($0) }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("素材库为空")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("点击 + 导入图片、文件或参考链接")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func assetContextMenu(_ asset: AssetItem) -> some View {
        Button {
            onSelectAsset?(asset)
        } label: {
            Label("使用素材", systemImage: "arrow.right.doc.on.clipboard")
        }

        Button {
            editingAsset = asset
        } label: {
            Label("编辑标签", systemImage: "tag")
        }

        Button(role: .destructive) {
            store.deleteAsset(asset)
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    // MARK: - Import helpers

    private func importPhotos(_ items: [PhotosPickerItem]) {
        for item in items {
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        _ = store.importImage(data, name: "照片_\(Date().formatted(.dateTime.month().day().hour().minute()))")
                    }
                }
            }
        }
        selectedPhotos = []
    }
}

// MARK: - Grid Cell

struct AssetGridCell: View {
    let asset: AssetItem
    let store: AssetStore

    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail
            if let thumbURL = store.thumbnailURL(for: asset),
               let data = try? Data(contentsOf: thumbURL),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 80)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 100, height: 80)
                    .overlay(
                        Image(systemName: asset.type.iconName)
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    )
            }

            Text(asset.name)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 100)
        }
    }
}

// MARK: - List Row

struct AssetListRow: View {
    let asset: AssetItem
    let store: AssetStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: asset.type.iconName)
                .font(.title3)
                .frame(width: 32)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.body)
                HStack(spacing: 4) {
                    Text(asset.type.displayName)
                    Text("·")
                    Text(ByteCountFormatter.string(fromByteCount: asset.fileSize, countStyle: .file))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if !asset.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(asset.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
    }
}

// MARK: - Detail Sheet

struct AssetDetailSheet: View {
    let asset: AssetItem
    @Bindable var store: AssetStore
    @Environment(\.dismiss) private var dismiss
    @State private var tags: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    LabeledContent("名称", value: asset.name)
                    LabeledContent("类型", value: asset.type.displayName)
                    LabeledContent("大小", value: ByteCountFormatter.string(fromByteCount: asset.fileSize, countStyle: .file))
                    LabeledContent("创建时间", value: asset.createdAt.formatted())
                }

                Section("标签") {
                    TextField("标签（逗号分隔）", text: $tags)
                }

                Section {
                    Button(role: .destructive) {
                        store.deleteAsset(asset)
                        dismiss()
                    } label: {
                        Label("删除素材", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("素材详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let newTags = tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                        store.updateTags(for: asset.id, tags: newTags)
                        dismiss()
                    }
                }
            }
            .onAppear {
                tags = asset.tags.joined(separator: ", ")
            }
        }
    }
}
