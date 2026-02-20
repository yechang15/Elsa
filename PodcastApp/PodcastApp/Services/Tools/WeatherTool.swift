import Foundation
import CoreLocation

// MARK: - WeatherTool

/// 天气工具，使用 Open-Meteo API 获取天气信息
/// params:
///   - location: String?  可选，"auto" 表示自动定位，或传入 "lat,lon" 格式
///   - range: String      "now" | "today" | "3day"，默认 "today"
final class WeatherTool: NSObject, AgentTool, @unchecked Sendable {
    let name = "weather"
    override var description: String { "获取当前及短期天气信息，支持自动定位" }

    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func execute(params: [String: Any]) async throws -> String {
        let range = params["range"] as? String ?? "today"
        let locationParam = params["location"] as? String ?? "auto"

        // 获取位置
        let location: CLLocation
        if locationParam == "auto" {
            location = try await requestLocation()
        } else if locationParam.contains(",") {
            let parts = locationParam.split(separator: ",")
            guard parts.count == 2,
                  let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                  let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) else {
                throw WeatherError.invalidLocation
            }
            location = CLLocation(latitude: lat, longitude: lon)
        } else {
            throw WeatherError.invalidLocation
        }

        // 获取天气数据
        let weatherData = try await fetchWeather(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            range: range
        )

        return formatWeather(weatherData, range: range)
    }

    // MARK: - Private Methods

    private func requestLocation() async throws -> CLLocation {
        // 检查权限
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            #if os(macOS)
            locationManager.requestAlwaysAuthorization()
            #else
            locationManager.requestWhenInUseAuthorization()
            #endif
        }

        #if os(macOS)
        guard status == .authorizedAlways else {
            throw WeatherError.locationPermissionDenied
        }
        #else
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            throw WeatherError.locationPermissionDenied
        }
        #endif

        // 请求位置
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    private func fetchWeather(latitude: Double, longitude: Double, range: String) async throws -> WeatherData {
        let baseURL = "https://api.open-meteo.com/v1/forecast"
        var components = URLComponents(string: baseURL)!

        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: range == "3day" ? "3" : "1")
        ]

        guard let url = components.url else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WeatherError.networkError
        }

        let decoder = JSONDecoder()
        return try decoder.decode(WeatherData.self, from: data)
    }

    private func formatWeather(_ data: WeatherData, range: String) -> String {
        var result = ""

        // 当前天气
        if let current = data.current {
            let condition = weatherCodeToDescription(current.weather_code)
            result += "当前天气：\(condition)，温度 \(Int(current.temperature_2m))°C"
            result += "，湿度 \(current.relative_humidity_2m)%"
            result += "，风速 \(String(format: "%.1f", current.wind_speed_10m)) km/h"
        }

        // 今日预报
        if let daily = data.daily, !daily.time.isEmpty {
            let _ = daily.time[0]
            let maxTemp = Int(daily.temperature_2m_max[0])
            let minTemp = Int(daily.temperature_2m_min[0])
            let precipitation = daily.precipitation_sum[0]

            result += "\n今日预报：最高 \(maxTemp)°C，最低 \(minTemp)°C"
            if precipitation > 0 {
                result += "，降水 \(String(format: "%.1f", precipitation)) mm"
            }
        }

        // 未来几天
        if range == "3day", let daily = data.daily, daily.time.count > 1 {
            result += "\n\n未来天气："
            for i in 1..<min(3, daily.time.count) {
                let date = daily.time[i]
                let maxTemp = Int(daily.temperature_2m_max[i])
                let minTemp = Int(daily.temperature_2m_min[i])
                let condition = weatherCodeToDescription(daily.weather_code[i])
                result += "\n\(formatDate(date))：\(condition)，\(minTemp)°C ~ \(maxTemp)°C"
            }
        }

        return result
    }

    private func weatherCodeToDescription(_ code: Int) -> String {
        switch code {
        case 0: return "晴朗"
        case 1, 2, 3: return "多云"
        case 45, 48: return "有雾"
        case 51, 53, 55: return "小雨"
        case 61, 63, 65: return "雨"
        case 71, 73, 75: return "雪"
        case 80, 81, 82: return "阵雨"
        case 95, 96, 99: return "雷暴"
        default: return "未知"
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherTool: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: WeatherError.locationFailed(error.localizedDescription))
        locationContinuation = nil
    }
}

// MARK: - Models

struct WeatherData: Codable {
    let current: CurrentWeather?
    let daily: DailyWeather?
}

struct CurrentWeather: Codable {
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let weather_code: Int
    let wind_speed_10m: Double
}

struct DailyWeather: Codable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_sum: [Double]
}

enum WeatherError: LocalizedError {
    case invalidLocation
    case locationPermissionDenied
    case locationFailed(String)
    case invalidURL
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidLocation: return "无效的位置参数"
        case .locationPermissionDenied: return "位置权限被拒绝"
        case .locationFailed(let msg): return "定位失败: \(msg)"
        case .invalidURL: return "无效的 URL"
        case .networkError: return "网络请求失败"
        }
    }
}
