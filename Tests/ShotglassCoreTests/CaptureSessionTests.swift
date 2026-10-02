import XCTest
@testable import ShotglassCore

final class CaptureSessionTests: XCTestCase {
    func testLetterKeysChooseAllModes() {
        for (key,mode) in [("a",CaptureMode.area),("f",.fullscreen),("w",.window),("v",.activeWindow),("r",.lastRegion)] {
            XCTAssertEqual(CaptureKeyAction.resolve(key),.mode(mode))
        }
    }
    func testNumbersFollowLeftToRightToolbarOrder() {
        let expected: [CaptureMode] = [.fullscreen,.window,.area,.activeWindow,.lastRegion]
        XCTAssertEqual(CaptureMode.toolbarOrder,expected)
        for (index,mode) in expected.enumerated() {
            XCTAssertEqual(mode.key,String(index+1))
            XCTAssertEqual(CaptureKeyAction.resolve(String(index+1)),.mode(mode))
            XCTAssertNil(CaptureKeyAction.resolve(String(index+1),command: true))
        }
    }
    func testRapidPreviewReplacementRejectsEarlierTimersAndCompletions() {
        var preview = QuickPreviewLifetime()
        let first = preview.replace(),second = preview.replace(),third = preview.replace()
        XCTAssertFalse(preview.dismiss(first)); XCTAssertFalse(preview.dismiss(second))
        XCTAssertTrue(preview.isCurrent(third)); XCTAssertTrue(preview.isActive)
        XCTAssertTrue(preview.dismiss(third)); XCTAssertFalse(preview.isActive)
    }
    func testReopeningCaptureInvalidatesPreviewDismissal() {
        var preview = QuickPreviewLifetime()
        let previous = preview.replace()
        preview.invalidate()
        XCTAssertFalse(preview.dismiss(previous)); XCTAssertFalse(preview.isActive)
        let current = preview.replace()
        XCTAssertFalse(preview.dismiss(previous)); XCTAssertTrue(preview.isCurrent(current))
    }
    func testDismissalIsIdempotent() {
        var preview = QuickPreviewLifetime()
        let token = preview.replace()
        XCTAssertTrue(preview.dismiss(token)); XCTAssertFalse(preview.dismiss(token))
    }
    func testDrawKeysWorkWithEitherCase() {
        for key in ["d","D","n","N"] { XCTAssertEqual(CaptureKeyAction.resolve(key),.drawNew) }
    }
    func testOrdinaryAppShortcutsAreNotHijacked() {
        for key in ["a","d","f","w","v","r"] {
            XCTAssertNil(CaptureKeyAction.resolve(key,command: true))
            XCTAssertNil(CaptureKeyAction.resolve(key,otherModifier: true))
        }
        XCTAssertEqual(CaptureKeyAction.resolve(",",command: true),.settings)
        XCTAssertEqual(CaptureKeyAction.resolve("l",command: true),.library)
    }
    func testUnknownKeysAreIgnored() {
        XCTAssertNil(CaptureKeyAction.resolve("q")); XCTAssertNil(CaptureKeyAction.resolve(""))
    }
    func testFirstLaunchDefaultsToReusableArea() {
        XCTAssertEqual(CaptureSelection(),CaptureSelection(mode: .area,drawNew: false))
    }
    func testEveryModeSurvivesProcessRestart() throws {
        for mode in CaptureMode.allCases {
            let stored = CaptureSelection(mode: mode)
            XCTAssertEqual(try JSONDecoder().decode(CaptureSelection.self,from: JSONEncoder().encode(stored)),stored)
        }
    }
    func testDrawNewIsRememberedIndependentlyOfSavedRectangle() throws {
        let stored = CaptureSelection(mode: .area,drawNew: true)
        XCTAssertEqual(try JSONDecoder().decode(CaptureSelection.self,from: JSONEncoder().encode(stored)),stored)
        XCTAssertFalse(CaptureSelection(mode: .fullscreen,drawNew: true).drawNew)
    }
    func testEmptySessionExits() { XCTAssertTrue(SessionActivity().shouldExit) }
    func testCaptureMustFinishWritingBeforeExit() {
        var state: SessionActivity = [.selection]
        XCTAssertFalse(state.shouldExit)
        state.remove(.selection); state.insert(.processing)
        XCTAssertFalse(state.shouldExit)
        state.remove(.processing)
        XCTAssertTrue(state.shouldExit)
    }
    func testPreviewDismissalEndsSession() {
        var state: SessionActivity = [.preview]
        XCTAssertFalse(state.shouldExit)
        state.remove(.preview)
        XCTAssertTrue(state.shouldExit)
    }
    func testSettingsAndEditorsRemainOpenUntilClosed() {
        var state: SessionActivity = [.toolWindow]
        XCTAssertFalse(state.shouldExit)
        state.remove(.toolWindow)
        XCTAssertTrue(state.shouldExit)
    }
    func testRecordingsAndScrollingNeverExitWhileActive() {
        XCTAssertFalse(SessionActivity.recording.shouldExit)
        XCTAssertFalse(SessionActivity.scrolling.shouldExit)
        XCTAssertFalse(SessionActivity([.processing,.recording]).shouldExit)
    }
}
