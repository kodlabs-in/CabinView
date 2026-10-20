import Foundation

enum BrowserAddress {
    private static let unsupportedSchemes: Set<String> = ["javascript", "file", "data", "http", "https", "about", "blob", "mailto", "tel", "ftp", "intent"]

    static func destination(for input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.contains("://") { return secureURL(text) }
        let prefix = text.split(separator: "/", maxSplits: 1).first ?? ""
        if prefix.contains("."), !text.contains(where: \.isWhitespace), !text.contains("@"),
           let address = secureURL("https://" + text) {
            return address
        }
        if let scheme = URLComponents(string: text)?.scheme?.lowercased(), unsupportedSchemes.contains(scheme) { return nil }
        var search = URLComponents(string: "https://www.google.com/search")!
        search.queryItems = [URLQueryItem(name: "q", value: text)]
        return search.url
    }

    static func secureURL(_ text: String) -> URL? {
        guard var components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil else { return nil }
        components.scheme = "https"
        return components.url
    }
}
