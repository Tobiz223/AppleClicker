// CubeClicker/ViewModels/GameViewModel.swift
import Foundation
import Combine

class GameViewModel: ObservableObject {
    @Published var state: GameState
    let clickPublisher = PassthroughSubject<Void, Never>()

    private var timer: Timer?
    private static let saveKey = "CubeClickerSave"
    private var tickCount = 0

    init() {
        self.state = GameViewModel.load()
        startTimer()
    }

    deinit { timer?.invalidate() }

    // MARK: - Click

    func click() {
        let output = clickOutput
        state.wood += output
        state.totalResourcesGathered += output
        clickPublisher.send()
    }

    var clickOutput: Double {
        pow(2.0, Double(state.buildingCount(.workshop)))
    }

    var cubeTier: Int {
        let t = state.totalResourcesGathered
        if t >= 10000 { return 3 }
        if t >= 2000  { return 2 }
        if t >= 500   { return 1 }
        return 0
    }

    // MARK: - Shop

    func canPurchase(_ type: BuildingType) -> Bool {
        guard isUnlocked(type) else { return false }
        return state.wood  >= type.woodCost  &&
               state.stone >= type.stoneCost &&
               state.metal >= type.metalCost
    }

    func isUnlocked(_ type: BuildingType) -> Bool {
        guard let req = type.unlockRequirement else { return true }
        return state.buildingCount(req) >= 1
    }

    func purchase(_ type: BuildingType) {
        guard canPurchase(type) else { return }
        state.wood  -= type.woodCost
        state.stone -= type.stoneCost
        state.metal -= type.metalCost
        state.incrementBuilding(type)
    }

    func buildingCount(_ type: BuildingType) -> Int {
        state.buildingCount(type)
    }

    // MARK: - Tick (internal so tests can call it directly)

    func tick() {
        for type in BuildingType.allCases {
            let n = Double(state.buildingCount(type))
            let dWood  = type.woodPerSecond  * n
            let dStone = type.stonePerSecond * n
            let dMetal = type.metalPerSecond * n
            state.wood  += dWood
            state.stone += dStone
            state.metal += dMetal
            state.totalResourcesGathered += (dWood + dStone + dMetal)
        }
        tickCount += 1
        if tickCount % 10 == 0 { save() }
    }

    private func startTimer() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Persistence

    func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.saveKey)
    }

    static func load() -> GameState {
        guard
            let data  = UserDefaults.standard.data(forKey: GameViewModel.saveKey),
            let state = try? JSONDecoder().decode(GameState.self, from: data)
        else { return GameState() }
        return state
    }
}

