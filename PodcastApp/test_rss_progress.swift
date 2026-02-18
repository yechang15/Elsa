#!/usr/bin/env swift

import Foundation

// 模拟RSS获取
func simulateFetchMultipleFeeds(urls: [String], progressHandler: ((Int, Int) -> Void)? = nil) async {
    let totalCount = urls.count
    var completedCount = 0

    print("开始获取 \(totalCount) 个RSS源...\n")

    for (index, url) in urls.enumerated() {
        // 模拟网络延迟
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

        completedCount += 1
        print("✅ 已获取: \(url)")

        // 报告进度
        progressHandler?(completedCount, totalCount)
    }

    print("\n✅ 全部完成！")
}

// 测试
let testURLs = [
    "https://example.com/feed1.xml",
    "https://example.com/feed2.xml",
    "https://example.com/feed3.xml",
    "https://example.com/feed4.xml",
    "https://example.com/feed5.xml",
]

Task {
    await simulateFetchMultipleFeeds(urls: testURLs) { completed, total in
        let percentage = Double(completed) / Double(total) * 100
        print("📊 进度: \(completed)/\(total) (\(String(format: "%.1f", percentage))%)")
    }

    exit(0)
}

RunLoop.main.run()
