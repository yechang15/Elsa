import Foundation
import CoreLocation
import EventKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - ToolStatus

/// 工具状态
enum ToolStatus {
    case active          // 🟢 已连接/已授权，可用
    case needsConfig     // 🟡 已配置但未完全就绪（缺少权限或配置项）
    case inactive        // ⚫ 未启用

    var icon: String {
        switch self {
        case .active: return "🟢"
        case .needsConfig: return "🟡"
        case .inactive: return "⚫"
        }
    }

    var description: String {
        switch self {
        case .active: return "已就绪"
        case .needsConfig: return "需要配置"
        case .inactive: return "未启用"
        }
    }
}

// MARK: - PermissionStatus

/// 权限状态
enum PermissionStatus {
    case authorized      // 已授权
    case denied          // 已拒绝
    case notDetermined   // 未决定
    case notRequired     // 不需要权限

    var icon: String {
        switch self {
        case .authorized: return "✅"
        case .denied: return "⚠️"
        case .notDetermined: return "❓"
        case .notRequired: return ""
        }
    }

    var description: String {
        switch self {
        case .authorized: return "已授权"
        case .denied: return "未授权"
        case .notDetermined: return "未决定"
        case .notRequired: return ""
        }
    }
}

// MARK: - ToolInfo

/// 工具信息
struct ToolInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let type: String  // "In-App" | "MCP Server"
    var status: ToolStatus
    var permissions: [PermissionInfo]

    var needsPermission: Bool {
        !permissions.isEmpty
    }
}

/// 权限信息
struct PermissionInfo: Identifiable {
    let id = UUID()
    let name: String  // "定位权限" | "日历权限"
    let icon: String  // "📍" | "📅"
    var status: PermissionStatus
}

// MARK: - ToolsViewModel

@MainActor
class ToolsViewModel: ObservableObject {
    @Published var tools: [ToolInfo] = []

    private let locationManager = CLLocationManager()
    private let eventStore = EKEventStore()

    // 工具实例（用于测试）
    private var weatherTool: WeatherTool?
    private var calendarTool: AppleCalendarTool?
    private var rssTool: RSSTool?

    init() {
        // 初始化工具实例
        weatherTool = WeatherTool()
        calendarTool = AppleCalendarTool()
        rssTool = RSSTool(rssService: RSSService())

        loadTools()
    }

    func loadTools() {
        tools = [
            ToolInfo(
                id: "weather",
                name: "天气",
                description: "当前及短期天气，支持自动定位",
                type: "In-App",
                status: getWeatherStatus(),
                permissions: [
                    PermissionInfo(
                        name: "定位权限",
                        icon: "📍",
                        status: getLocationPermissionStatus()
                    )
                ]
            ),
            ToolInfo(
                id: "calendar",
                name: "苹果日历",
                description: "读取 EventKit 日历事件",
                type: "In-App",
                status: getCalendarStatus(),
                permissions: [
                    PermissionInfo(
                        name: "日历权限",
                        icon: "📅",
                        status: getCalendarPermissionStatus()
                    )
                ]
            ),
            ToolInfo(
                id: "rss",
                name: "RSS",
                description: "用户订阅的 RSS 源最新文章",
                type: "In-App",
                status: .active,
                permissions: []
            ),
            ToolInfo(
                id: "podcast",
                name: "播客",
                description: "播客生成与状态查询",
                type: "In-App",
                status: .active,
                permissions: []
            )
        ]
    }

    func refreshPermissions() {
        loadTools()
    }

    // MARK: - Permission Status Helpers

    private func getLocationPermissionStatus() -> PermissionStatus {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedAlways:
            return .authorized
        #if !os(macOS)
        case .authorizedWhenInUse:
            return .authorized
        #endif
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    private func getCalendarPermissionStatus() -> PermissionStatus {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    private func getWeatherStatus() -> ToolStatus {
        let permStatus = getLocationPermissionStatus()
        switch permStatus {
        case .authorized:
            return .active
        case .denied, .notDetermined:
            return .needsConfig
        case .notRequired:
            return .active
        }
    }

    private func getCalendarStatus() -> ToolStatus {
        let permStatus = getCalendarPermissionStatus()
        switch permStatus {
        case .authorized:
            return .active
        case .denied, .notDetermined:
            return .needsConfig
        case .notRequired:
            return .active
        }
    }

    // MARK: - Actions

    func testTool(id: String) async throws -> String {
        switch id {
        case "weather":
            guard let tool = weatherTool else {
                throw ToolError.notInitialized
            }
            return try await tool.execute(params: ["range": "today"])

        case "calendar":
            guard let tool = calendarTool else {
                throw ToolError.notInitialized
            }
            return try await tool.execute(params: ["range": "today"])

        case "rss":
            guard let tool = rssTool else {
                throw ToolError.notInitialized
            }
            // 使用示例 RSS 源测试
            return try await tool.execute(params: [
                "feed_urls": ["https://hnrss.org/frontpage"],
                "limit": 5
            ])

        case "podcast":
            return "播客工具状态：就绪\n当前无需测试"

        default:
            throw ToolError.unknownTool
        }
    }

    func openSystemSettings(for permission: String) {
        #if os(macOS)
        if permission == "定位权限" {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                NSWorkspace.shared.open(url)
            }
        } else if permission == "日历权限" {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
            }
        }
        #else
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - Errors

enum ToolError: LocalizedError {
    case notInitialized
    case unknownTool

    var errorDescription: String? {
        switch self {
        case .notInitialized: return "工具未初始化"
        case .unknownTool: return "未知工具"
        }
    }
}
