import Foundation

public protocol NotationCatalogProvider: Sendable {
    func notation(with code: String) async throws -> Notation?
    func allNotations() async -> [Notation]
}

/// In-memory catalogue of parsed notations that can be shared by server and
/// client code. The catalogue lazily loads YAML files from disk or raw strings
/// and exposes lookup helpers for downstream services.
public actor NotationCatalog: NotationCatalogProvider {
    private var notations: [String: Notation] = [:]
    private var rawDocuments: [String: String] = [:]

    public init() {}

    @discardableResult
    public func loadDirectory(_ url: URL, recursive: Bool = true) async throws -> [Notation] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil) else {
            return []
        }

        var parsed: [Notation] = []

        while let fileURL = enumerator.nextObject() as? URL {
            if !recursive, fileURL.deletingLastPathComponent() != url {
                enumerator.skipDescendants()
                continue
            }

            guard fileURL.pathExtension.lowercased() == "yaml" else { continue }

            let yaml = try String(contentsOf: fileURL, encoding: .utf8)
            let notation = try NotationParser.parse(yaml: yaml, source: fileURL)
            notations[notation.code] = notation
            rawDocuments[notation.code] = yaml
            parsed.append(notation)
        }

        return parsed
    }

    public func addNotation(_ notation: Notation) {
        notations[notation.code] = notation
    }

    public func notation(with code: String) async throws -> Notation? {
        notations[code]
    }

    public func allNotations() async -> [Notation] {
        Array(notations.values)
    }

    public func rawNotation(with code: String) async -> String? {
        rawDocuments[code]
    }
}
