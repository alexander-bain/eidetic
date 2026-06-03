import Foundation

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Collection {
    var isNotEmpty: Bool { !isEmpty }
}
