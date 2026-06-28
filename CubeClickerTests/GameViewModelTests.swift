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
