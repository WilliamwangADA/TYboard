import SwiftUI

struct NewTaskSheet: View {
    @Binding var isPresented: Bool
    var onCreate: (String, TaskProject.TaskType) -> Void

    @State private var taskName = ""
    @State private var selectedType: TaskProject.TaskType = .webApp

    var body: some View {
        NavigationStack {
            Form {
                Section("任务名称") {
                    TextField("给你的任务起个名字", text: $taskName)
                }

                Section("任务类型") {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 10)
                    ], spacing: 10) {
                        ForEach(TaskProject.TaskType.allCases, id: \.self) { type in
                            Button {
                                selectedType = type
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: type.iconName)
                                        .font(.title2)
                                    Text(type.rawValue)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    selectedType == type
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.secondary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(
                                            selectedType == type ? Color.accentColor : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                            }
                            .foregroundStyle(selectedType == type ? .primary : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("新建任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("创建") {
                        guard !taskName.isEmpty else { return }
                        onCreate(taskName, selectedType)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(taskName.isEmpty)
                }
            }
        }
    }
}
