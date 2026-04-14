import SwiftUI

struct TaskSwitcherView: View {
    @Bindable var store: TaskProjectStore
    @Binding var isPresented: Bool
    @State private var showNewTask = false

    var body: some View {
        NavigationStack {
            List {
                // Active projects
                if !store.activeProjects.isEmpty {
                    Section("进行中") {
                        ForEach(store.activeProjects) { project in
                            taskRow(project)
                        }
                    }
                }

                // Other projects
                let others = store.projects.filter { $0.status != .active }
                if !others.isEmpty {
                    Section("其他") {
                        ForEach(others) { project in
                            taskRow(project)
                        }
                    }
                }
            }
            .overlay {
                if store.projects.isEmpty {
                    ContentUnavailableView {
                        Label("还没有任务", systemImage: "tray")
                    } description: {
                        Text("点击右上角 + 创建你的第一个任务")
                    }
                }
            }
            .navigationTitle("我的任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewTask) {
                NewTaskSheet(isPresented: $showNewTask) { name, type in
                    _ = store.createProject(name: name, type: type)
                    isPresented = false
                }
            }
        }
    }

    private func taskRow(_ project: TaskProject) -> some View {
        Button {
            store.switchTo(project)
            isPresented = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: project.type.iconName)
                    .font(.title3)
                    .frame(width: 32)
                    .foregroundStyle(project.id == store.currentProjectId ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(project.name)
                            .font(.body)
                            .fontWeight(project.id == store.currentProjectId ? .semibold : .regular)

                        if project.id == store.currentProjectId {
                            Text("当前")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.15), in: Capsule())
                                .foregroundStyle(.blue)
                        }
                    }

                    HStack(spacing: 4) {
                        Text(project.type.rawValue)
                        Text("·")
                        Text(project.status.rawValue)
                        Text("·")
                        Text(project.updatedAt, style: .relative)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .foregroundStyle(.primary)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.deleteProject(project)
            } label: {
                Label("删除", systemImage: "trash")
            }

            if project.status == .active {
                Button {
                    store.updateProjectStatus(project, status: .paused)
                } label: {
                    Label("暂停", systemImage: "pause")
                }
                .tint(.orange)
            } else {
                Button {
                    store.updateProjectStatus(project, status: .active)
                } label: {
                    Label("继续", systemImage: "play")
                }
                .tint(.green)
            }
        }
    }
}
