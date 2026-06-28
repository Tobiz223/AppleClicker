# Cube Clicker — Design Spec
**Date:** 2026-06-28  
**Platform:** macOS (Mac Mini)  
**Stack:** Swift + SwiftUI + SpriteKit  

---

## Overview

A voxel-style clicker-builder game for macOS. The player clicks a large pixelated cube to gather Wood, then spends resources to build structures that auto-generate resources over time. As buildings are purchased, they appear in a growing isometric 2D world rendered by SpriteKit.

---

## Architecture

### Technology Stack
- **SwiftUI** — main window, left panel (click button, resource counters, shop)
- **SpriteKit** — right panel world scene (isometric buildings, animations, particles)
- **GameViewModel** — `ObservableObject` containing all game state and logic; shared via `@EnvironmentObject`

### File Structure
```
CubeClicker/
├── CubeClickerApp.swift          # App entry point
├── ViewModels/
│   └── GameViewModel.swift       # All game state, timers, purchase logic
├── Views/
│   ├── ContentView.swift         # Root layout: left panel + SpriteView
│   ├── LeftPanelView.swift       # Click button, resource counters, shop
│   ├── ResourceRowView.swift     # Single resource display row
│   └── ShopItemView.swift        # Single shop building row
├── Scene/
│   └── WorldScene.swift          # SKScene — isometric world, building sprites
├── Models/
│   ├── GameState.swift           # Codable game state (resources, buildings)
│   └── BuildingType.swift        # Enum: sawmill, mine, forge, workshop
└── Assets.xcassets/              # Pixel art textures for cubes and buildings
```

---

## Game State & Data Model

### Resources
| Resource | Symbol | Initial |
|----------|--------|---------|
| Wood     | 🪵     | 0       |
| Stone    | 🪨     | 0       |
| Metal    | ⚙️     | 0       |

### Buildings
| Building   | Symbol | Cost              | Output        | Unlock Requirement |
|------------|--------|-------------------|---------------|--------------------|
| Sawmill    | 🏚     | 10 🪵             | +1 🪵/sec     | —                  |
| Mine       | ⛏      | 20 🪵             | +1 🪨/sec     | —                  |
| Forge      | 🔥     | 15 🪵 + 10 🪨     | +1 ⚙️/sec     | Mine owned ≥ 1     |
| Workshop   | 🔨     | 30 🪵 + 5 ⚙️      | +2 🪵/click   | Forge owned ≥ 1    |

`GameState` is `Codable` and persisted to `UserDefaults` for save/load.

---

## Click Mechanics

- Base click output: **1 🪵**
- Each Workshop owned multiplies click output by **2**
- Formula: `clickOutput = 1 * pow(2, workshopCount)`
- Click triggers bounce animation on the main cube + Wood particle burst

### Main Cube Visual Progression
The clickable cube texture upgrades based on total resources gathered:
- 0–500 total: Wood texture
- 500–2000 total: Stone texture
- 2000–10000 total: Metal texture
- 10000+: Gold texture

---

## Auto-Generation (Tick System)

- `GameViewModel` fires a 1-second `Timer` on `main` RunLoop
- Each tick: iterates all owned buildings and adds their output to resources
- UI updates reactively via `@Published` properties

---

## Window Layout

```
┌─────────────────────────────────────────────────────┐
│  🪵 125   🪨 40   ⚙️ 0              Cube Clicker    │
├──────────────────────┬──────────────────────────────┤
│                      │                              │
│  [  MAIN CUBE  ]     │   WorldScene (SpriteKit)    │
│  (tap to gather)     │                              │
│                      │   Isometric world grows      │
│  ── SHOP ──          │   left-to-right as           │
│  🏚 Sawmill    Buy   │   buildings are purchased    │
│  ⛏  Mine       Buy   │                              │
│  🔥 Forge      Buy   │                              │
│  🔨 Workshop   Buy   │                              │
│                      │                              │
└──────────────────────┴──────────────────────────────┘
```

Left panel width: ~320pt. Right panel: fills remaining space.  
Resource counters in toolbar at top.

---

## Visual World (SpriteKit — WorldScene)

### Scene Setup
- Background: sky gradient + static pixel clouds
- Ground row: grass-top cube tiles across the bottom
- Buildings placed left-to-right in fixed slots (max 12 slots visible, scene scrolls if needed)

### Building Sprites
Each building is a stack of pixel-art cube sprites (2–4 cubes tall):
- **Sawmill** — brown wood cubes + green tree top
- **Mine** — grey stone cubes + pickaxe icon
- **Forge** — red brick cubes + flame particle emitter
- **Workshop** — blue metal cubes + hammer icon

### Animations
| Event | Animation |
|-------|-----------|
| Building purchased | Cubes rise one-by-one from ground (0.3s each) |
| Click on main cube | Bounce (scale 1.0→1.15→1.0, 0.1s) + Wood particles burst |
| Auto-collect tick | Small resource icon floats up from building and fades out |
| Buildings idle | Subtle breathe loop (scale 1.0→1.02→1.0, 2s cycle) |

### Particles
SpriteKit `SKEmitterNode` used for:
- Click burst: 8 small wood-colored squares fly outward and fade
- Forge smoke: continuous grey particle stream upward

---

## Error Handling

- Purchase button disabled (greyed out) when resources insufficient
- Locked buildings show lock icon and required prerequisite text
- Game state auto-saves every 10 seconds and on app backgrounding

---

## Out of Scope (v1)

- Prestige / reset system
- Sound effects
- Mac App Store distribution
- iCloud sync
- Achievements
