import Foundation

let testData = Data([0x11, 0x94, 0x10, 0x00, 0x00, 0x00, 0x00, 0x96, 0x00, 0x00, 0x00, 0x07])

print("测试数据解析:")
print("原始: \(testData.map { String(format: "%02x", $0) }.joined(separator: " "))")

let eventBytes = testData[4..<8]
let eventValue = eventBytes.withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
print("Event (big-endian): \(eventValue)")

let eventValueLittle = eventBytes.withUnsafeBytes { $0.load(as: Int32.self) }
print("Event (little-endian): \(eventValueLittle)")

print("\n实际应该是: 150 (SessionStarted)")
print("0x96 = \(0x96)")
