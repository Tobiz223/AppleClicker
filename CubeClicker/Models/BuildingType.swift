// CubeClicker/Models/BuildingType.swift
import Foundation

enum BuildingType: String, CaseIterable, Codable {
    case sawmill
    case mine
    case forge
    case workshop

    var displayName: String {
        switch self {
        case .sawmill:  return "Лесопилка"
        case .mine:     return "Шахта"
        case .forge:    return "Кузница"
        case .workshop: return "Мастерская"
        }
    }

    var symbol: String {
        switch self {
        case .sawmill:  return "🏚"
        case .mine:     return "⛏"
        case .forge:    return "🔥"
        case .workshop: return "🔨"
        }
    }

    var woodCost: Double {
        switch self {
        case .sawmill:  return 10
        case .mine:     return 20
        case .forge:    return 15
        case .workshop: return 30
        }
    }

    var stoneCost: Double {
        switch self {
        case .forge: return 10
        default:     return 0
        }
    }

    var metalCost: Double {
        switch self {
        case .workshop: return 5
        default:        return 0
        }
    }

    var woodPerSecond: Double  { self == .sawmill  ? 1 : 0 }
    var stonePerSecond: Double { self == .mine     ? 1 : 0 }
    var metalPerSecond: Double { self == .forge    ? 1 : 0 }

    var unlockRequirement: BuildingType? {
        switch self {
        case .forge:    return .mine
        case .workshop: return .forge
        default:        return nil
        }
    }

    var outputDescription: String {
        switch self {
        case .sawmill:  return "+1 🪵/сек"
        case .mine:     return "+1 🪨/сек"
        case .forge:    return "+1 ⚙️/сек"
        case .workshop: return "+2 🪵 за клик"
        }
    }

    var costText: String {
        var parts: [String] = []
        if woodCost  > 0 { parts.append("\(Int(woodCost))🪵")  }
        if stoneCost > 0 { parts.append("\(Int(stoneCost))🪨") }
        if metalCost > 0 { parts.append("\(Int(metalCost))⚙️") }
        return parts.joined(separator: " + ")
    }
}
