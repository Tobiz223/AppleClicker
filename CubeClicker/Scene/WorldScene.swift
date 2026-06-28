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
        node.run(rise) { [weak self, weak node] in
            guard let self, let node else { return }
            node.run(self.breathe())
        }

        scheduleFloatingResource(above: node, for: type)
        nextSlotX += slotWidth
    }

    // MARK: - Building Node Construction

    private func buildingNode(for type: BuildingType) -> SKNode {
        let container = SKNode()
        let (base, accent, emoji) = buildingPalette(for: type)

        let cube1 = block(color: base, size: CGSize(width: 52, height: 52))
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
        case .workshop: emoji = "⚙️"
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
