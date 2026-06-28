// CubeClicker/Models/GameState.swift
import Foundation

struct GameState: Codable {
    var wood: Double = 0
    var stone: Double = 0
    var metal: Double = 0
    var totalResourcesGathered: Double = 0
    var buildings: [String: Int] = [:]

    func buildingCount(_ type: BuildingType) -> Int {
        buildings[type.rawValue] ?? 0
    }

    mutating func incrementBuilding(_ type: BuildingType) {
        buildings[type.rawValue, default: 0] += 1
    }
}
