import Foundation
import Testing

@Suite struct Task5LocalizationAuditTests {
    @Test func task5SourcesDoNotUseDirectStaticSwiftUILiterals() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceRoots = [
            "Sources/AppFeature",
            "Sources/FeatureList",
            "Sources/FeatureCreate",
            "Sources/FeatureDetail"
        ].map { packageRoot.appendingPathComponent($0) }

        let patterns = [
            #"Text\s*\(\s*""#,
            #"Button\s*\(\s*""#,
            #"TextField\s*\(\s*""#,
            #"Section\s*\(\s*""#,
            #"\.navigationTitle\s*\(\s*""#,
            #"\.alert\s*\(\s*""#,
            #"\.accessibilityLabel\s*\(\s*""#,
            #"\.accessibilityHint\s*\(\s*""#
        ].map { try! NSRegularExpression(pattern: $0) }

        let allowed: Set<String> = [
            "Sources/FeatureCreate/CameraPicker.swift",
            "Sources/FeatureCreate/LocationTimeStrip.swift"
        ]

        var violations: [String] = []
        for root in sourceRoots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let relative = url.path.replacingOccurrences(of: packageRoot.path + "/", with: "")
                guard !allowed.contains(relative) else { continue }

                let contents = try String(contentsOf: url)
                for (index, line) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                    if patterns.contains(where: { $0.firstMatch(in: String(line), range: nsRange) != nil }) {
                        violations.append("\(relative):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
                    }
                }
            }
        }

        #expect(violations == [], Comment(rawValue: violations.joined(separator: "\n")))
    }
}
