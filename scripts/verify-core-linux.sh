#!/usr/bin/env bash
# Compila e roda, no Linux, a lógica pura (Core/) e os testes (Tests/) com um toolchain Swift.
# Não substitui a CI (não tem SwiftUI/UIKit), mas pega erros de compilação e testes quebrados
# da lógica antes do push. Uso: SWIFT=/caminho/para/swift scripts/verify-core-linux.sh [pasta-de-trabalho]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT="${SWIFT:-swift}"
WORK="${1:-$(mktemp -d)}/verify"
rm -rf "$WORK"
mkdir -p "$WORK/Sources/os" "$WORK/Sources/CoreGraphics" "$WORK/Sources/TimeRewind" "$WORK/Tests/TimeRewindTests"

cat > "$WORK/Package.swift" <<'EOF'
// swift-tools-version:5.10
import PackageDescription
let package = Package(
    name: "Verify",
    targets: [
        .target(name: "os"),
        .target(name: "CoreGraphics"),
        .target(name: "TimeRewind", dependencies: ["os", "CoreGraphics"]),
        .testTarget(name: "TimeRewindTests", dependencies: ["TimeRewind", "CoreGraphics"]),
    ],
    swiftLanguageVersions: [.v5]
)
EOF

# Stubs mínimos dos módulos da Apple que não existem no Linux.
echo '@_exported import Foundation' > "$WORK/Sources/CoreGraphics/Stub.swift"
cat > "$WORK/Sources/os/Stub.swift" <<'EOF'
public struct OSLogPrivacy { public static let `public` = OSLogPrivacy(); public static let `private` = OSLogPrivacy() }
public struct OSLogMessage: ExpressibleByStringInterpolation {
    public struct StringInterpolation: StringInterpolationProtocol {
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) {}
        public mutating func appendInterpolation<T>(_ value: T, privacy: OSLogPrivacy = .private) {}
    }
    public init(stringLiteral value: String) {}
    public init(stringInterpolation: StringInterpolation) {}
}
public struct Logger: Sendable {
    public init(subsystem: String, category: String) {}
    public func debug(_ message: OSLogMessage) {}
    public func info(_ message: OSLogMessage) {}
    public func error(_ message: OSLogMessage) {}
}
EOF

for file in "$ROOT"/Core/*.swift; do ln -s "$file" "$WORK/Sources/TimeRewind/"; done
for file in "$ROOT"/Tests/*.swift; do ln -s "$file" "$WORK/Tests/TimeRewindTests/"; done

cd "$WORK"
"$SWIFT" test
