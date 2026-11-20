import XCTest
@testable import Gomoku

final class GomokuNativeTrainingResourceTests: XCTestCase {
    func testBundledRealSelfPlaySeedIsValid() throws {
        let urls = [
            Bundle.main.url(forResource: "GomokuNativeTrainingSeed", withExtension: "json"),
            Bundle(for: Self.self).url(forResource: "GomokuNativeTrainingSeed", withExtension: "json")
        ]
        guard let url = urls.compactMap({ $0 }).first else {
            XCTFail("GomokuNativeTrainingSeed.json is not included in the app/test bundle.")
            return
        }
        let verified = try GomokuBundledNativeSeed.verify(from: url)
        XCTAssertFalse(verified.isEmpty)
        XCTAssertTrue(verified.allSatisfy { !$0.plies.isEmpty })
    }

    func testSelfPlayUsesValidCentralOpeningsAndOriginalBot() {
        XCTAssertEqual(NativeGomokuSelfPlay.openingIndices.count, 49)
        XCTAssertTrue(NativeGomokuSelfPlay.openingIndices.allSatisfy { (0..<225).contains($0) })
    }

    func testArchiveDirectoryIsInStandaloneSandbox() {
        let archive = VeilGomokuMatchArchive()
        XCTAssertTrue(archive.directory.path.contains("Gomoku"))
    }
}
