# macOS 位置权限问题解决方案

## 问题现象

- 日历权限弹窗正常
- 位置权限弹窗不出现
- 调用 `requestAlwaysAuthorization()` 后没有反应

## 根本原因

在 Xcode 开发环境下运行 Swift Package 项目时，macOS 的位置权限弹窗需要满足以下条件：

1. **Info.plist 必须被加载**
   - Swift Package 默认不会加载 `Resources/Info.plist`
   - 需要在 Xcode target 设置中配置

2. **权限描述字符串必须存在**
   - `NSLocationWhenInUseUsageDescription`（iOS）
   - `NSLocationAlwaysAndWhenInUseUsageDescription`（macOS）

3. **App 必须有正确的 Bundle ID 和签名**
   - 开发环境下可能没有正确配置

## 解决方案

### 方案 1：手动授权（推荐，最快）

1. 打开「系统设置」→「隐私与安全性」→「定位服务」
2. 找到 `PodcastApp`（如果没有，先运行一次 App 并测试天气工具）
3. 勾选开启

### 方案 2：在 Xcode 中配置 Info.plist

由于这是 Swift Package 项目，需要特殊处理：

1. 在 Xcode 中打开项目
2. 选择 `PodcastApp` scheme
3. Edit Scheme → Run → Options
4. 勾选「Use custom working directory」
5. 或者：创建一个 Xcode project wrapper

### 方案 3：转换为 Xcode Project（最彻底）

如果需要发布到 App Store，最终需要转换为 Xcode Project：

```bash
# 创建 Xcode project
swift package generate-xcodeproj
```

然后在 Xcode project 的 target 设置中：
- Info → Custom macOS Application Target Properties
- 添加 `NSLocationAlwaysAndWhenInUseUsageDescription`

### 方案 4：使用 Package.swift 的 resources（不推荐）

虽然我们已经创建了 `Info.plist`，但 Swift Package Manager 不支持将 Info.plist 作为资源打包。

## 当前实现

我们已经：
1. ✅ 创建了 `PodcastApp/Resources/Info.plist` 包含权限描述
2. ✅ 在工具管理页显示权限状态
3. ✅ 提供「前往系统设置」按钮
4. ✅ 添加开发环境提示

## 测试步骤

1. **手动授权位置权限**：
   - 系统设置 → 隐私与安全性 → 定位服务
   - 找到 PodcastApp → 开启

2. **测试天气工具**：
   - 打开 App → 工具与技能 → 工具 Tab
   - 点击天气工具的「测试」按钮
   - 应该能看到真实的天气数据

3. **验证权限状态**：
   - 授权后，工具管理页应该显示「📍 定位权限：已授权 ✅」
   - 天气工具状态变为「🟢 已就绪」

## 为什么日历权限正常？

日历权限（EventKit）的弹窗机制和位置权限不同：
- EventKit 不依赖 Info.plist 的权限描述（macOS 14+）
- 位置权限必须有 Info.plist 描述才能弹窗
- 这是 Apple 的安全机制差异

## 生产环境

如果要发布 App，必须：
1. 转换为 Xcode Project
2. 在 target 的 Info.plist 中配置权限描述
3. 配置正确的 Bundle ID 和签名
4. 通过 App Store 或公证（Notarization）发布

## 参考

- [Apple: Requesting Authorization for Location Services](https://developer.apple.com/documentation/corelocation/requesting_authorization_for_location_services)
- [Swift Package Manager Limitations](https://forums.swift.org/t/info-plist-in-swift-packages/32526)
