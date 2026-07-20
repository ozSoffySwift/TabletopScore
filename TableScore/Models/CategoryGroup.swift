import Foundation

/// The kind of browse axis a category belongs to. Order here drives the
/// order of rows on Home.
enum CategoryGroup: String, Codable, CaseIterable {
    case genre
    case style
    case length
    case playerCount
    case mode
    case mood

    var homeOrder: Int {
        CategoryGroup.allCases.firstIndex(of: self) ?? .max
    }
}
