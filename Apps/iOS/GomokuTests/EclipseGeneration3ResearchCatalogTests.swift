import Foundation
import XCTest
@testable import Gomoku

final class EclipseGeneration3ResearchCatalogTests: XCTestCase {
    private func fixture() throws -> Data {
        let filename = "ECLIPSE_3_0_RESEARCH_MODELS"
        let path = Bundle.main.url(forResource: filename, withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(path,
            "Gomoku V2.0 must include the small ECLIPSE 3.0 research ID manifest"))
    }

    func testAppV2AndModelV3RemainIndependentImmutableIdentities() throws {
        let catalog = try XCTUnwrap(
            EclipseGeneration3ResearchCatalog.validate(fixture())
        )
        XCTAssertEqual(catalog.applicationVersion, "2.0.0")
        XCTAssertEqual(catalog.label, "ECLIPSE 3.0")
        XCTAssertEqual(catalog.generation, "3.0")
        XCTAssertEqual(catalog.flagshipAliasName, "3.0 Astra")
        XCTAssertEqual(catalog.flagshipAliasId, "eclipse-3.0-astra")
        XCTAssertEqual(catalog.flagshipCheckpointId, "eclipse-3.0-r07-249")
        XCTAssertEqual(catalog.checkpoints.map(\.trees), [244, 249, 259, 274, 289])
        XCTAssertEqual(catalog.preferredResearchCandidate?.id,
                       "eclipse-3.0-r07-249")
        XCTAssertEqual(catalog.preferredResearchCandidate?.sha256,
                       "d4cea7f62e9e8ffc119d60861ce05df43aafdbdc280b51707dc1b7e40e5fc234")
        XCTAssertEqual(catalog.preferredResearchCandidate?.exploratoryGatesPassed, 8)
        XCTAssertEqual(catalog.preferredResearchCandidate?.exploratoryGatesTotal, 9)
        XCTAssertFalse(catalog.productionExecutable)
        XCTAssertFalse(catalog.productionEnabled)
        XCTAssertFalse(catalog.iosRuntimeLoaded)
        XCTAssertEqual(catalog.nativeFeatureAbi, "34D-r07-compatibility-port-experimental")
        XCTAssertFalse(EclipseModelID.allCases.contains {
            $0.rawValue.hasPrefix("eclipse-3.0-")
        })
        XCTAssertNil(EclipseModelID.fromStoredIdentifier("eclipse-3.0-r07-249"))
        XCTAssertEqual(EclipseModelID.astra20.name, "2.0 Astra")
        XCTAssertEqual(EclipseModelID.sol20.name, "2.0 Sol")
    }

    func testResearchManifestCannotBePromotedByEditingOnlyDisplayMetadata() throws {
        func mutated(_ edits: (inout [String: Any]) -> Void) throws -> Data {
            var source = try XCTUnwrap(
                JSONSerialization.jsonObject(with: fixture()) as? [String: Any]
            )
            edits(&source)
            return try JSONSerialization.data(withJSONObject: source)
        }
        XCTAssertNil(EclipseGeneration3ResearchCatalog.validate(
            try mutated { $0["flagship_alias_name"] = "2.0 Astra" }
        ))
        XCTAssertNil(EclipseGeneration3ResearchCatalog.validate(
            try mutated { $0["flagship_checkpoint_id"] = "eclipse-3.0-r07-244" }
        ))
        XCTAssertNil(EclipseGeneration3ResearchCatalog.validate(
            try mutated { $0["production_enabled"] = true }
        ))
        XCTAssertNil(EclipseGeneration3ResearchCatalog.validate(
            try mutated { $0["ios_runtime_loaded"] = true }
        ))
        XCTAssertNil(EclipseGeneration3ResearchCatalog.validate(
            try mutated { $0["native_feature_abi"] = "26D-v9" }
        ))
        XCTAssertNil(EclipseGeneration3ResearchCatalog.validate(
            try mutated { data in
                var list = data["checkpoints"] as! [[String: Any]]
                list[1]["features"] = 26
                data["checkpoints"] = list
            }
        ))
        XCTAssertNil(EclipseGeneration3ResearchCatalog.validate(
            try mutated { data in
                var list = data["checkpoints"] as! [[String: Any]]
                list[1]["production_eligible"] = true
                data["checkpoints"] = list
            }
        ))
    }
}
