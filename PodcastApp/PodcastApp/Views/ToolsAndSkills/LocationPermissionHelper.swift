import SwiftUI
import CoreLocation

/// 位置权限请求辅助视图
struct LocationPermissionHelper: NSViewRepresentable {
    let onStatusChanged: (CLAuthorizationStatus) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.requestPermission()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onStatusChanged: onStatusChanged)
    }

    class Coordinator: NSObject, CLLocationManagerDelegate {
        let locationManager = CLLocationManager()
        let onStatusChanged: (CLAuthorizationStatus) -> Void

        init(onStatusChanged: @escaping (CLAuthorizationStatus) -> Void) {
            self.onStatusChanged = onStatusChanged
            super.init()
            locationManager.delegate = self
        }

        func requestPermission() {
            let status = locationManager.authorizationStatus
            if status == .notDetermined {
                // 先请求一次位置，触发权限弹窗
                locationManager.requestAlwaysAuthorization()
                // 立即请求位置，确保系统记录权限请求
                locationManager.requestLocation()
            }
            onStatusChanged(status)
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            onStatusChanged(manager.authorizationStatus)
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            // 收到位置后停止
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            // 忽略错误
        }
    }
}

/// 权限请求按钮
struct RequestLocationPermissionButton: View {
    @State private var isRequesting = false
    @State private var currentStatus: CLAuthorizationStatus = .notDetermined
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                isRequesting = true
            }) {
                Label("请求位置权限", systemImage: "location.circle")
            }
            .buttonStyle(.borderedProminent)

            if isRequesting {
                LocationPermissionHelper { status in
                    currentStatus = status
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        onComplete()
                        isRequesting = false
                    }
                }
                .frame(width: 0, height: 0)

                Text("正在请求权限...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
