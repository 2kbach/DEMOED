import Foundation

enum URLHistory {
    private static let key = "demoed.urlHistory.v1"
    private static let maxCount = 10

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func add(_ url: URL) {
        let str = url.absoluteString
        var list = load()
        list.removeAll { $0 == str }
        list.insert(str, at: 0)
        if list.count > maxCount { list = Array(list.prefix(maxCount)) }
        UserDefaults.standard.set(list, forKey: key)
    }

    static func remove(_ str: String) {
        var list = load()
        list.removeAll { $0 == str }
        UserDefaults.standard.set(list, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func displayHost(_ str: String) -> String {
        guard let u = URL(string: str), let host = u.host else { return str }
        let path = u.path
        return path.isEmpty || path == "/" ? host : host + path
    }
}
