import Foundation

struct ProjectTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let category: Category
    let defaultPrompt: String

    enum Category: String, CaseIterable {
        case webApp = "Web应用"
        case game = "小游戏"
        case ppt = "演示文稿"
        case landing = "落地页"
        case dashboard = "仪表盘"
        case other = "其他"

        var iconName: String {
            switch self {
            case .webApp: "globe"
            case .game: "gamecontroller"
            case .ppt: "rectangle.on.rectangle.angled"
            case .landing: "doc.richtext"
            case .dashboard: "chart.bar"
            case .other: "star"
            }
        }
    }

    static let builtIn: [ProjectTemplate] = [
        ProjectTemplate(
            name: "待办事项App",
            description: "简洁的任务管理应用，支持添加、完成、删除",
            icon: "checklist",
            category: .webApp,
            defaultPrompt: "创建一个精美的待办事项Web应用，支持添加任务、标记完成、删除任务，使用现代UI设计"
        ),
        ProjectTemplate(
            name: "个人主页",
            description: "单页个人展示网站",
            icon: "person.circle",
            category: .landing,
            defaultPrompt: "创建一个现代风格的个人主页，包含头像、简介、技能展示、项目作品集和联系方式"
        ),
        ProjectTemplate(
            name: "贪吃蛇",
            description: "经典贪吃蛇小游戏",
            icon: "arrow.triangle.turn.up.right.diamond",
            category: .game,
            defaultPrompt: "创建一个网页版贪吃蛇游戏，使用Canvas绘制，支持方向键控制，记分和游戏结束重启"
        ),
        ProjectTemplate(
            name: "2048",
            description: "经典数字合并游戏",
            icon: "number.square",
            category: .game,
            defaultPrompt: "创建一个2048网页游戏，支持滑动操作，动画效果，分数记录"
        ),
        ProjectTemplate(
            name: "产品发布PPT",
            description: "适合产品发布会的演示模板",
            icon: "sparkles.rectangle.stack",
            category: .ppt,
            defaultPrompt: "为一个新产品发布创建一份演示文稿，包含：封面、产品痛点、解决方案、功能展示、市场分析、路线图、CTA"
        ),
        ProjectTemplate(
            name: "数据仪表盘",
            description: "实时数据展示面板",
            icon: "chart.bar.xaxis",
            category: .dashboard,
            defaultPrompt: "创建一个数据仪表盘页面，包含KPI卡片、折线图、柱状图、饼图，使用Chart.js，深色主题"
        ),
        ProjectTemplate(
            name: "计算器",
            description: "功能完整的科学计算器",
            icon: "plusminus.circle",
            category: .webApp,
            defaultPrompt: "创建一个美观的计算器Web应用，支持基础运算和括号，类似iOS计算器的UI设计"
        ),
        ProjectTemplate(
            name: "画板工具",
            description: "简单的在线画板",
            icon: "paintbrush",
            category: .webApp,
            defaultPrompt: "创建一个简单的在线画板工具，支持画笔、颜色选择、粗细调节、橡皮擦、清空和保存为图片"
        ),
    ]
}
