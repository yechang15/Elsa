import Foundation
import EventKit

// MARK: - AppleCalendarTool

/// 苹果日历工具，使用 EventKit 读取日历事件
/// params:
///   - range: String      "today" | "week"，默认 "today"
///   - calendar_ids: [String]?  可选，指定日历 ID 列表
final class AppleCalendarTool: AgentTool, @unchecked Sendable {
    let name = "calendar"
    let description = "读取苹果日历事件，提供今日/本周日程"

    private let eventStore = EKEventStore()

    func execute(params: [String: Any]) async throws -> String {
        let range = params["range"] as? String ?? "today"

        // 请求权限
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarError.permissionDenied
        }

        // 获取事件
        let events = try await fetchEvents(range: range)

        guard !events.isEmpty else {
            return range == "today" ? "今日无日程安排" : "本周无日程安排"
        }

        return formatEvents(events, range: range)
    }

    // MARK: - Private Methods

    private func requestAccess() async throws -> Bool {
        #if os(macOS)
        return try await eventStore.requestAccess(to: .event)
        #else
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await eventStore.requestAccess(to: .event)
        }
        #endif
    }

    private func fetchEvents(range: String) async throws -> [EKEvent] {
        let calendar = Calendar.current
        let now = Date()

        let (startDate, endDate): (Date, Date)
        switch range {
        case "today":
            startDate = calendar.startOfDay(for: now)
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        case "week":
            startDate = calendar.startOfDay(for: now)
            endDate = calendar.date(byAdding: .day, value: 7, to: startDate)!
        default:
            startDate = calendar.startOfDay(for: now)
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
        return events.sorted { $0.startDate < $1.startDate }
    }

    private func formatEvents(_ events: [EKEvent], range: String) -> String {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        var result = range == "today" ? "今日日程：\n" : "本周日程：\n"

        var currentDay: Date?
        for event in events {
            let eventDay = calendar.startOfDay(for: event.startDate)

            // 如果是本周视图，且日期变化了，添加日期分隔
            if range == "week" && eventDay != currentDay {
                currentDay = eventDay
                let dayOffset = calendar.dateComponents([.day], from: today, to: eventDay).day ?? 0
                let dayLabel = formatDayLabel(dayOffset: dayOffset, date: eventDay)
                result += "\n【\(dayLabel)】\n"
            }

            // 格式化事件
            let timeStr: String
            if event.isAllDay {
                timeStr = "全天"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                timeStr = formatter.string(from: event.startDate)
            }

            result += "- \(timeStr) \(event.title ?? "无标题")"

            if let location = event.location, !location.isEmpty {
                result += " @ \(location)"
            }

            result += "\n"
        }

        return result
    }

    private func formatDayLabel(dayOffset: Int, date: Date) -> String {
        switch dayOffset {
        case 0: return "今天"
        case 1: return "明天"
        case 2: return "后天"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "MM月dd日 EEEE"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        }
    }
}

// MARK: - Errors

enum CalendarError: LocalizedError {
    case permissionDenied
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "日历权限被拒绝"
        case .fetchFailed: return "获取日历事件失败"
        }
    }
}
