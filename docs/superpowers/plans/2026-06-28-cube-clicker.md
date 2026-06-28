# Cube Clicker — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS voxel-style clicker-builder game where clicking a cube gathers Wood, and purchased buildings auto-generate resources over time while populating a growing SpriteKit isometric world.

**Architecture:** SwiftUI left panel (click button + shop) + SpriteKit right panel (isometric world). A single `GameViewModel` (`ObservableObject`) holds all state, timers, and logic, shared via `@EnvironmentObject`. SpriteKit observes `$state` changes via Combine to sync building sprites.

**Tech Stack:** Swift 5.9+, SwiftUI, SpriteKit, Combine, XCTest, macOS 13+, Xcode 15+

## Global Constraints

- macOS deployment target: 13.0+
- Language: Swift 5.9+, no third-party dependencies
- All source files go inside `CubeClicker/` subdirectory of the project
- Test target name: `CubeClickerTests`
- `UserDefaults` save key: `"CubeClickerSave"`
- `tick()` must be `internal` (not `private`) so tests can call it directly
- No force-unwraps (`!`) except in tests' `setUp`

---

## File Map

```
CubeClicker/                          ← Xcode app target sources
  CubeClickerApp.swift                ← @main App entry point
  Models/
    BuildingType.swift                ← enum + costs/output/unlock rules
    GameState.swift                   ← Codable struct: resources + building counts
  ViewModels/
    GameViewModel.swift               ← ObservableObject: click, tick, purchase, save/load
  Views/
    ContentView.swift                 ← HStack: LeftPanelView + SpriteView(WorldScene)
    LeftPanelView.swift               ← Clickable cube + shop list
    ResourceRowView.swift             ← "🪵 42" single-line resource display
    ShopItemView.swift                ← One building row (name, cost, Buy button)
  Scene/
    WorldScene.swift                  ← SKScene: ground, clouds, building sprites, animations
CubeClickerTests/
  GameViewModelTests.swift            ← Unit tests for all ViewModel logic
```

---

## Task 1: Data Models

**Files:**
- Create: `CubeClicker/Models/BuildingType.swift`
- Create: `CubeClicker/Models/GameState.swift`

**Interfaces — Produces:**
- `BuildingType: String, CaseIterable, Codable` — enum with `.sawmill`, `.mine`, `.forge`, `.workshop`
- `BuildingType.woodCost: Double`, `.stoneCost: Double`, `.metalCost: Double`
- `BuildingType.woodPerSecond: Double`, `.stonePerSecond: Double`, `.metalPerSecond: Double`
- `BuildingType.unlockRequirement: BuildingType?`
- `BuildingType.displayName: String`, `.symbol: String`, `.outputDescription: String`
- `GameState: Codable` — struct with `wood`, `stone`, `metal`, `totalResourcesGathered: Double`, `buildings: [String: Int]`
- `GameState.buildingCount(_ type: BuildingType) -> Int`
- `GameState.incrementBuilding(_ type: BuildingType)`

- [ ] **Step 1: Create Models directory and BuildingType.swift**

```swift
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
```

- [ ] **Step 2: Create GameState.swift**

```swift
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
```

- [ ] **Step 3: Commit**

```bash
git add CubeClicker/Models/
git commit -m "feat: add BuildingType and GameState models"
```

---

## Task 2: GameViewModel + Unit Tests

**Files:**
- Create: `CubeClicker/ViewModels/GameViewModel.swift`
- Create: `CubeClickerTests/GameViewModelTests.swift`

**Interfaces — Consumes:** `BuildingType`, `GameState`

**Interfaces — Produces:**
- `GameViewModel: ObservableObject`
- `@Published var state: GameState`
- `let clickPublisher: PassthroughSubject<Void, Never>`
- `func click()`
- `var clickOutput: Double`
- `var cubeTier: Int` — 0=Wood, 1=Stone, 2=Metal, 3=Gold
- `func canPurchase(_ type: BuildingType) -> Bool`
- `func isUnlocked(_ type: BuildingType) -> Bool`
- `func purchase(_ type: BuildingType)`
- `func buildingCount(_ type: BuildingType) -> Int`
- `func tick()` — internal, called by Timer every 1s
- `func save()`
- `static func load() -> GameState`

- [ ] **Step 1: Write failing tests**

```swift
// CubeClickerTests/GameViewModelTests.swift
import XCTest
@testable import CubeClicker

final class GameViewModelTests: XCTestCase {
    private let saveKey = "CubeClickerSave"
    var sut: GameViewModel!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: saveKey)
        sut = GameViewModel()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: saveKey)
        sut = nil
        super.tearDown()
    }

    func testClickAddsOneWoodByDefault() {
        sut.click()
        XCTAssertEqual(sut.state.wood, 1.0)
    }

    func testClickOutputIsOneWithNoWorkshops() {
        XCTAssertEqual(sut.clickOutput, 1.0)
    }

    func testClickOutputDoublesPerWorkshop() {
        sut.state.wood = 1000; sut.state.stone = 1000; sut.state.metal = 1000
        sut.purchase(.mine)
        sut.purchase(.forge)
        sut.purchase(.workshop)
        XCTAssertEqual(sut.clickOutput, 2.0)
        sut.purchase(.workshop)
        XCTAssertEqual(sut.clickOutput, 4.0)
    }

    func testCannotPurchaseSawmillWithNoResources() {
        XCTAssertFalse(sut.canPurchase(.sawmill))
    }

    func testCanPurchaseSawmillWithExactWood() {
        sut.state.wood = 10
        XCTAssertTrue(sut.canPurchase(.sawmill))
    }

    func testPurchaseDeductsWoodAndIncrementsBuildingCount() {
        sut.state.wood = 15
        sut.purchase(.sawmill)
        XCTAssertEqual(sut.state.wood, 5.0)
        XCTAssertEqual(sut.buildingCount(.sawmill), 1)
    }

    func testForgeLockedWithoutMine() {
        XCTAssertFalse(sut.isUnlocked(.forge))
    }

    func testForgeUnlockedAfterBuyingMine() {
        sut.state.wood = 100
        sut.purchase(.mine)
        XCTAssertTrue(sut.isUnlocked(.forge))
    }

    func testWorkshopLockedWithoutForge() {
        XCTAssertFalse(sut.isUnlocked(.workshop))
    }

    func testTickGeneratesWoodFromSawmill() {
        sut.state.wood = 15
        sut.purchase(.sawmill)
        let woodBefore = sut.state.wood
        sut.tick()
        XCTAssertEqual(sut.state.wood, woodBefore + 1.0)
    }

    func testTickGeneratesStoneFromMine() {
        sut.state.wood = 100
        sut.purchase(.mine)
        sut.tick()
        XCTAssertEqual(sut.state.stone, 1.0)
    }

    func testCubeTierStartsAtWood() {
        XCTAssertEqual(sut.cubeTier, 0)
    }

    func testCubeTierIsStoneAt500() {
        sut.state.totalResourcesGathered = 500
        XCTAssertEqual(sut.cubeTier, 1)
    }

    func testCubeTierIsMetalAt2000() {
        sut.state.totalResourcesGathered = 2000
        XCTAssertEqual(sut.cubeTier, 2)
    }

    func testCubeTierIsGoldAt10000() {
        sut.state.totalResourcesGathered = 10000
        XCTAssertEqual(sut.cubeTier, 3)
    }

    func testSaveAndLoad() {
        sut.state.wood = 42; sut.state.stone = 17
        sut.save()
        let loaded = GameViewModel.load()
        XCTAssertEqual(loaded.wood, 42)
        XCTAssertEqual(loaded.stone, 17)
    }
}
```

- [ ] **Step 2: Run tests — expect compile error (GameViewModel not found)**

In Xcode: Product → Test (⌘U)  
Expected: Build fails — `GameViewModel` not defined yet.

- [ ] **Step 3: Implement GameViewModel.swift**

```swift
// CubeClicker/ViewModels/GameViewModel.swift
import Foundation
import Combine

class GameViewModel: ObservableObject {
    @Published var state: GameState
    let clickPublisher = PassthroughSubject<Void, Never>()

    private var timer: Timer?
    private let saveKey = "CubeClickerSave"
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
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    // MARK: - Persistence

    func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    static func load() -> GameState {
        guard
            let data  = UserDefaults.standard.data(forKey: "CubeClickerSave"),
            let state = try? JSONDecoder().decode(GameState.self, from: data)
        else { return GameState() }
        return state
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

In Xcode: Product → Test (⌘U)  
Expected: 15 tests pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add CubeClicker/ViewModels/ CubeClickerTests/
git commit -m "feat: implement GameViewModel with tick, click, purchase, save/load"
```

---

## Task 3: SwiftUI Views

**Files:**
- Create: `CubeClicker/Views/ResourceRowView.swift`
- Create: `CubeClicker/Views/ShopItemView.swift`
- Create: `CubeClicker/Views/LeftPanelView.swift`
- Create: `CubeClicker/Views/ContentView.swift`

**Interfaces — Consumes:** `GameViewModel` via `@EnvironmentObject`, `BuildingType`

- [ ] **Step 1: Create ResourceRowView.swift**

```swift
// CubeClicker/Views/ResourceRowView.swift
import SwiftUI

struct ResourceRowView: View {
    let symbol: String
    let value: Double

    var body: some View {
        HStack(spacing: 4) {
            Text(symbol)
            Text("\(Int(value))")
                .monospacedDigit()
                .fontWeight(.semibold)
        }
    }
}
```

- [ ] **Step 2: Create ShopItemView.swift**

```swift
// CubeClicker/Views/ShopItemView.swift
import SwiftUI

struct ShopItemView: View {
    let type: BuildingType
    @EnvironmentObject var viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 10) {
            Text(type.symbol)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(type.displayName).fontWeight(.semibold)
                    if viewModel.buildingCount(type) > 0 {
                        Text("×\(viewModel.buildingCount(type))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(type.outputDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(type.costText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Group {
                if !viewModel.isUnlocked(type) {
                    Text("🔒")
                        .font(.title3)
                } else {
                    Button("Купить") {
                        viewModel.purchase(type)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .disabled(!viewModel.canPurchase(type))
                }
            }
        }
        .padding(10)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 3: Create LeftPanelView.swift**

The file includes a private `CubeView` struct for the clickable cube graphic.

```swift
// CubeClicker/Views/LeftPanelView.swift
import SwiftUI

struct LeftPanelView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var isClicking = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                viewModel.click()
                withAnimation(.spring(response: 0.08, dampingFraction: 0.4)) {
                    isClicking = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.08, dampingFraction: 0.4)) {
                        isClicking = false
                    }
                }
            } label: {
                CubeView(tier: viewModel.cubeTier)
                    .frame(width: 110, height: 110)
                    .scaleEffect(isClicking ? 1.15 : 1.0)
            }
            .buttonStyle(.plain)
            .padding(.top, 28)

            Text("+\(Int(viewModel.clickOutput)) 🪵 за клик")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Divider().padding(.vertical, 14)

            Text("МАГАЗИН")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(BuildingType.allCases, id: \.self) { type in
                        ShopItemView(type: type)
                    }
                }
                .padding(12)
            }
        }
    }
}

// MARK: - CubeView

private struct CubeView: View {
    let tier: Int

    private var faceColor: Color {
        switch tier {
        case 0: return Color(red: 0.60, green: 0.38, blue: 0.18)  // Wood
        case 1: return Color(red: 0.58, green: 0.58, blue: 0.58)  // Stone
        case 2: return Color(red: 0.35, green: 0.40, blue: 0.65)  // Metal
        default: return Color(red: 0.85, green: 0.70, blue: 0.10) // Gold
        }
    }

    var body: some View {
        ZStack {
            // Bottom face (shadow)
            RoundedRectangle(cornerRadius: 10)
                .fill(faceColor.opacity(0.5))
                .frame(width: 100, height: 100)
                .offset(y: 6)

            // Main face
            RoundedRectangle(cornerRadius: 10)
                .fill(faceColor)
                .frame(width: 100, height: 100)

            // Top highlight
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.18))
                .frame(width: 80, height: 35)
                .offset(y: -22)

            // Pixel grid lines
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: 100, y: 0))
            }
            .stroke(Color.black.opacity(0.08), lineWidth: 1)
            .frame(width: 100, height: 100)
        }
    }
}
```

- [ ] **Step 4: Create ContentView.swift**

```swift
// CubeClicker/Views/ContentView.swift
import SwiftUI
import SpriteKit

struct ContentView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var worldScene = WorldScene()

    var body: some View {
        HStack(spacing: 0) {
            LeftPanelView()
                .frame(width: 300)
                .background(Color(.windowBackgroundColor))

            Divider()

            SpriteView(scene: worldScene)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 820, minHeight: 520)
        .onAppear {
            worldScene.scaleMode = .resizeFill
            worldScene.gameViewModel = viewModel
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 20) {
                    ResourceRowView(symbol: "🪵", value: viewModel.state.wood)
                    ResourceRowView(symbol: "🪨", value: viewModel.state.stone)
                    ResourceRowView(symbol: "⚙️", value: viewModel.state.metal)
                }
                .font(.headline)
            }
        }
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add CubeClicker/Views/
git commit -m "feat: add SwiftUI views (ResourceRow, ShopItem, LeftPanel, ContentView)"
```

---

## Task 4: SpriteKit World Scene

**Files:**
- Create: `CubeClicker/Scene/WorldScene.swift`

**Interfaces — Consumes:** `GameViewModel` (observes `$state` via Combine, `clickPublisher`)

**Interfaces — Produces:**
- `class WorldScene: SKScene`
- `var gameViewModel: GameViewModel?` — weak, triggers Combine subscription on set

- [ ] **Step 1: Create WorldScene.swift**

```swift
// CubeClicker/Scene/WorldScene.swift
import SpriteKit
import Combine

class WorldScene: SKScene {

    weak var gameViewModel: GameViewModel? {
        didSet { subscribeToViewModel() }
    }

    private var cancellables = Set<AnyCancellable>()
    private var trackedCounts: [BuildingType: Int] = [:]
    private var nextSlotX: CGFloat = 70
    private let groundY: CGFloat = 80
    private let slotWidth: CGFloat = 90

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.53, green: 0.81, blue: 0.98, alpha: 1)
        setupGround()
        setupClouds()
    }

    private func setupGround() {
        let tileW: CGFloat = 40
        let count = Int((max(size.width, 1400)) / tileW) + 2
        for i in 0..<count {
            let x = CGFloat(i) * tileW + tileW / 2
            // Grass top
            let grass = SKSpriteNode(
                color: SKColor(red: 0.30, green: 0.68, blue: 0.20, alpha: 1),
                size: CGSize(width: tileW, height: tileW / 2)
            )
            grass.position = CGPoint(x: x, y: groundY)
            addChild(grass)
            // Dirt body
            let dirt = SKSpriteNode(
                color: SKColor(red: 0.50, green: 0.33, blue: 0.14, alpha: 1),
                size: CGSize(width: tileW, height: groundY)
            )
            dirt.position = CGPoint(x: x, y: groundY / 2 - tileW / 4)
            addChild(dirt)
        }
    }

    private func setupClouds() {
        let positions: [CGFloat] = [80, 280, 500]
        for x in positions {
            let cloud = makeCloud()
            cloud.position = CGPoint(x: x, y: size.height > 0 ? size.height - 60 : 400)
            addChild(cloud)
        }
    }

    private func makeCloud() -> SKNode {
        let node = SKNode()
        let parts: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0, 0, 60, 28),
            (-28, -6, 40, 22),
            (28, -6, 40, 22)
        ]
        for (dx, dy, w, h) in parts {
            let s = SKSpriteNode(color: .white, size: CGSize(width: w, height: h))
            s.alpha = 0.82
            s.position = CGPoint(x: dx, y: dy)
            node.addChild(s)
        }
        return node
    }

    // MARK: - ViewModel Subscription

    private func subscribeToViewModel() {
        cancellables.removeAll()
        guard let vm = gameViewModel else { return }

        vm.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.syncBuildings(from: newState)
            }
            .store(in: &cancellables)

        vm.clickPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.playClickBurst()
            }
            .store(in: &cancellables)
    }

    // MARK: - Building Sync

    private func syncBuildings(from state: GameState) {
        for type in BuildingType.allCases {
            let newCount = state.buildingCount(type)
            let oldCount = trackedCounts[type] ?? 0
            guard newCount > oldCount else { continue }
            for _ in oldCount..<newCount {
                spawnBuilding(type)
            }
            trackedCounts[type] = newCount
        }
    }

    private func spawnBuilding(_ type: BuildingType) {
        let node = buildingNode(for: type)
        node.position = CGPoint(x: nextSlotX, y: groundY + 16)
        node.setScale(0.01)
        addChild(node)

        let rise = SKAction.scale(to: 1.0, duration: 0.35)
        rise.timingMode = .easeOut
        node.run(rise) { [weak node] in
            node?.run(self.breathe())
        }

        scheduleFloatingResource(above: node, for: type)
        nextSlotX += slotWidth
    }

    // MARK: - Building Node Construction

    private func buildingNode(for type: BuildingType) -> SKNode {
        let container = SKNode()
        let (base, accent, emoji) = buildingPalette(for: type)

        let cube1 = block(color: base,   size: CGSize(width: 52, height: 52))
        cube1.position = CGPoint(x: 0, y: 26)

        let cube2 = block(color: base.withAlphaComponent(0.85), size: CGSize(width: 52, height: 52))
        cube2.position = CGPoint(x: 0, y: 78)

        let top = block(color: accent, size: CGSize(width: 52, height: 36))
        top.position = CGPoint(x: 0, y: 122)

        let label = SKLabelNode(text: emoji)
        label.fontSize = 22
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 122)

        [cube1, cube2, top, label].forEach { container.addChild($0) }
        return container
    }

    private func block(color: SKColor, size: CGSize) -> SKSpriteNode {
        let node = SKSpriteNode(color: color, size: size)
        // Pixel outline
        let border = SKShapeNode(rectOf: size)
        border.strokeColor = SKColor.black.withAlphaComponent(0.15)
        border.fillColor = .clear
        border.lineWidth = 1
        node.addChild(border)
        return node
    }

    private func buildingPalette(for type: BuildingType) -> (SKColor, SKColor, String) {
        switch type {
        case .sawmill:
            return (SKColor(red: 0.60, green: 0.38, blue: 0.18, alpha: 1),
                    SKColor(red: 0.22, green: 0.60, blue: 0.22, alpha: 1),
                    "🌲")
        case .mine:
            return (SKColor(red: 0.52, green: 0.52, blue: 0.52, alpha: 1),
                    SKColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1),
                    "⛏")
        case .forge:
            return (SKColor(red: 0.70, green: 0.18, blue: 0.18, alpha: 1),
                    SKColor(red: 0.92, green: 0.50, blue: 0.08, alpha: 1),
                    "🔥")
        case .workshop:
            return (SKColor(red: 0.20, green: 0.28, blue: 0.70, alpha: 1),
                    SKColor(red: 0.40, green: 0.50, blue: 0.90, alpha: 1),
                    "🔨")
        }
    }

    // MARK: - Animations

    private func breathe() -> SKAction {
        let up   = SKAction.scale(to: 1.02, duration: 1.2)
        let down = SKAction.scale(to: 1.00, duration: 1.2)
        up.timingMode   = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        return SKAction.repeatForever(SKAction.sequence([up, down]))
    }

    private func scheduleFloatingResource(above node: SKNode?, for type: BuildingType) {
        guard type.woodPerSecond > 0 || type.stonePerSecond > 0 || type.metalPerSecond > 0,
              let node else { return }

        let emoji: String
        switch type {
        case .sawmill:  emoji = "🪵"
        case .mine:     emoji = "🪨"
        case .forge:    emoji = "⚙️"
        case .workshop: emoji = "🪵"
        }

        let wait  = SKAction.wait(forDuration: 1.0)
        let emit  = SKAction.run { [weak self, weak node] in
            guard let self, let nodePos = node?.position else { return }
            self.floatLabel("+1 \(emoji)", from: CGPoint(x: nodePos.x, y: nodePos.y + 140))
        }
        node.run(SKAction.repeatForever(SKAction.sequence([wait, emit])))
    }

    private func floatLabel(_ text: String, from point: CGPoint) {
        let label = SKLabelNode(text: text)
        label.fontSize = 13
        label.position = point
        addChild(label)
        let move = SKAction.moveBy(x: 0, y: 28, duration: 0.9)
        let fade = SKAction.fadeOut(withDuration: 0.9)
        label.run(SKAction.sequence([SKAction.group([move, fade]), .removeFromParent()]))
    }

    // MARK: - Click Burst

    private func playClickBurst() {
        let center = CGPoint(x: 60, y: size.height - 60)
        for _ in 0..<8 {
            let particle = SKSpriteNode(
                color: SKColor(red: 0.60, green: 0.38, blue: 0.18, alpha: 1),
                size: CGSize(width: 7, height: 7)
            )
            particle.position = center
            addChild(particle)

            let angle    = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 25...70)
            let move = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.4)
            let fade = SKAction.fadeOut(withDuration: 0.4)
            move.timingMode = .easeOut
            particle.run(SKAction.sequence([SKAction.group([move, fade]), .removeFromParent()]))
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add CubeClicker/Scene/
git commit -m "feat: implement SpriteKit WorldScene with buildings and animations"
```

---

## Task 5: App Entry Point + Xcode Project Setup

**Files:**
- Create: `CubeClicker/CubeClickerApp.swift`

- [ ] **Step 1: Create CubeClickerApp.swift**

```swift
// CubeClicker/CubeClickerApp.swift
import SwiftUI

@main
struct CubeClickerApp: App {
    @StateObject private var viewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onDisappear { viewModel.save() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 950, height: 580)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
```

- [ ] **Step 2: Set up Xcode project on Mac Mini**

> This step is done manually in Xcode on your Mac Mini.

1. Open Xcode → File → New → Project
2. Choose **macOS → App**
3. Product Name: `CubeClicker`
4. Interface: `SwiftUI`, Language: `Swift`
5. Uncheck "Include Tests" (you'll add the test target separately)
6. Save project inside the `Apple Clicker` git folder

7. Delete the auto-generated `ContentView.swift` and `CubeClickerApp.swift`
8. In the Project Navigator, right-click the `CubeClicker` group → **Add Files** → select all `.swift` files from `CubeClicker/` (maintaining folder structure)
9. Add a new **macOS Unit Testing Bundle** target named `CubeClickerTests`
10. Add `GameViewModelTests.swift` to that target
11. In `CubeClickerTests` target → Build Settings → search "Host Application" → set to `CubeClicker`

- [ ] **Step 3: Build and run (⌘R)**

Expected: Window opens with left panel (cube + shop) and blue sky SpriteKit world on the right.  
Verify: Clicking the cube increments 🪵 counter in toolbar.

- [ ] **Step 4: Run all tests (⌘U)**

Expected: 15 tests pass.

- [ ] **Step 5: Verify building purchase flow**

1. Click cube 10 times → 🪵 reaches 10
2. Buy Sawmill → appears in world, 🪵 auto-increments each second
3. Click 20 more times → buy Mine → appears right of Sawmill, 🪨 starts ticking
4. With enough resources: buy Forge → then Workshop → confirm click output doubles

- [ ] **Step 6: Final commit**

```bash
git add CubeClicker/CubeClickerApp.swift
git commit -m "feat: add app entry point, complete Cube Clicker v1"
```

---

## Spec Coverage Check

| Spec requirement | Covered by |
|---|---|
| Click gathers Wood | Task 2 `click()` + Task 3 button |
| click output = pow(2, workshopCount) | Task 2 `clickOutput` |
| Cube tier changes at 500/2000/10000 | Task 2 `cubeTier` + Task 3 `CubeView` |
| 4 buildings with correct costs | Task 1 `BuildingType` |
| Forge requires Mine, Workshop requires Forge | Task 2 `isUnlocked()` |
| 1-second auto-tick | Task 2 `startTimer()` |
| Auto-save every 10 ticks | Task 2 `tick()` |
| Save on app close | Task 5 `.onDisappear` |
| Buy button disabled when insufficient resources | Task 3 `ShopItemView` `.disabled()` |
| Lock icon for locked buildings | Task 3 `ShopItemView` |
| Buildings appear in isometric world | Task 4 `spawnBuilding()` |
| Rise animation on purchase | Task 4 `rise` action |
| Breathe idle animation | Task 4 `breathe()` |
| Floating resource icon on tick | Task 4 `floatLabel()` |
| Click burst particles | Task 4 `playClickBurst()` |
| Sky + ground + clouds background | Task 4 `setupGround()` + `setupClouds()` |
