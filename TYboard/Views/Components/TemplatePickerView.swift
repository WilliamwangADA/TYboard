import SwiftUI

struct TemplatePickerView: View {
    var onSelectTemplate: (ProjectTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: ProjectTemplate.Category?

    private var filteredTemplates: [ProjectTemplate] {
        if let category = selectedCategory {
            return ProjectTemplate.builtIn.filter { $0.category == category }
        }
        return ProjectTemplate.builtIn
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(nil, label: "全部")
                        ForEach(ProjectTemplate.Category.allCases, id: \.self) { category in
                            categoryChip(category, label: category.rawValue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                Divider()

                // Templates grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
                    ], spacing: 12) {
                        ForEach(filteredTemplates) { template in
                            TemplateCard(template: template)
                                .onTapGesture {
                                    onSelectTemplate(template)
                                    dismiss()
                                }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("选择模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func categoryChip(_ category: ProjectTemplate.Category?, label: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 4) {
                if let category {
                    Image(systemName: category.iconName)
                        .font(.caption)
                }
                Text(label)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                selectedCategory == category
                ? Color.accentColor.opacity(0.2)
                : Color.secondary.opacity(0.1),
                in: Capsule()
            )
        }
        .foregroundStyle(selectedCategory == category ? .primary : .secondary)
    }
}

struct TemplateCard: View {
    let template: ProjectTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: template.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                Spacer()
                Text(template.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.1), in: Capsule())
            }

            Text(template.name)
                .font(.headline)

            Text(template.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}
