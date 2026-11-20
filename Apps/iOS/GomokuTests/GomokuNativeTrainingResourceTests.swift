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

    func testBundledSeedFirstImportIsValidatedAndIdempotent() throws {
        let source = [
            Bundle.main.url(forResource: "GomokuNativeTrainingSeed", withExtension: "json"),
            Bundle(for: Self.self).url(forResource: "GomokuNativeTrainingSeed", withExtension: "json")
        ].compactMap { $0 }
        let url = try XCTUnwrap(source.first)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GomokuSeedBoot-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = GomokuNativeTrainingJournal(directory: directory)
        let first = try GomokuBundledSeedBootstrap.importVerifiedSeed(from: url, into: journal)
        XCTAssertGreaterThan(first.accepted, 0)
        XCTAssertEqual(first.rejected, 0)
        let second = try GomokuBundledSeedBootstrap.importVerifiedSeed(from: url, into: journal)
        XCTAssertEqual(second.accepted, 0)
        XCTAssertEqual(second.rejected, 0)
        XCTAssertEqual(second.duplicate, first.accepted + first.duplicate)
        XCTAssertEqual(GomokuNativeTrainingJournal(directory: directory).count(), first.accepted)
    }

    func testArchiveDirectoryIsInStandaloneSandbox() {
        let archive = VeilGomokuMatchArchive()
        XCTAssertTrue(archive.directory.path.contains("Gomoku"))
    }
}
