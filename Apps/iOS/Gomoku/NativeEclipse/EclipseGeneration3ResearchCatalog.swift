import Foundation

/// Owner-defined MODEL generation 3.0. This is intentionally independent of
/// Gomoku APP V2.0.0 and the actually compiled Astra/Sol V9 model generation.
/// R07 is a new 34D research forest, not an alias or relabel of V9 26D.
struct EclipseGeneration3ResearchCatalog: Decodable, Sendable {
    struct Checkpoint: Decodable, Sendable, Identifiable {
        let id: String
        let researchRevision: String
        let features: Int
        let trees: Int
        let sha256: String
        let sourceFile: String
        let productionEligible: Bool
        let exploratoryGatesPassed: Int?
        let exploratoryGatesTotal: Int?
    }

    let schema: String
    let applicationVersion: String
    let generation: String
    let label: String
    let modelFamily: String
    /// Product-facing identity chosen by the owner; mapped to one genuine
    /// R07-249 research checkpoint, NOT an independently trained Astra forest.
    let flagshipAliasId: String
    let flagshipAliasName: String
    let flagshipCheckpointId: String
    let productionEnabled: Bool
    let iosRuntimeLoaded: Bool
    let nativeFeatureAbi: String
    let oldRuntimePreserved: String
    let releaseGate: String
    let checkpoints: [Checkpoint]
    let note: String

    /// Read only this small metadata manifest; it contains no private games
    /// or weights. A 3.0 model is NOT added to playable EclipseModelID until
    /// 34D native features, model loading, checkpoint SHA and gates pass.
    static let bundled: Self? = loadFromBundle()

    static func loadFromBundle(_ bundle: Bundle = .main) -> Self? {
        guard let url = bundle.url(
            forResource: "ECLIPSE_3_0_RESEARCH_MODELS", withExtension: "json"
        ), let data = try? Data(contentsOf: url) else { return nil }
        return validate(data)
    }

    static func validate(_ data: Data) -> Self? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let catalog = try? decoder.decode(Self.self, from: data),
              catalog.schema == "eclipse.generation3.research-catalog.v1",
              catalog.applicationVersion == "2.0.0",
              catalog.generation == "3.0",
              catalog.label == "ECLIPSE 3.0",
              catalog.flagshipAliasId == "eclipse-3.0-astra",
              catalog.flagshipAliasName == "Astra 3.0",
              catalog.flagshipCheckpointId == "eclipse-3.0-r07-249",
              !catalog.productionEnabled,
              !catalog.iosRuntimeLoaded,
              catalog.nativeFeatureAbi == "34D-not-implemented",
              catalog.checkpoints.count == 5,
              catalog.checkpoints.map(\.trees) == [244, 249, 259, 274, 289],
              Set(catalog.checkpoints.map(\.id)).count == 5,
              catalog.checkpoints.allSatisfy({
                  !$0.productionEligible && $0.features == 34 &&
                  $0.id.hasPrefix("eclipse-3.0-r07-") &&
                  $0.sha256.count == 64 &&
                  $0.sha256.utf8.allSatisfy({ byte in
                      (48...57).contains(byte) || (97...102).contains(byte)
                  }) &&
                  $0.sourceFile == "eclipse_r07_34d_\($0.trees)_trees.txt"
              }),
              let best = catalog.checkpoints.first(where: { $0.trees == 249 }),
              best.id == catalog.flagshipCheckpointId,
              best.exploratoryGatesPassed == 8,
              best.exploratoryGatesTotal == 9
        else { return nil }
        return catalog
    }

    /// A research ranking is NEVER a production engine attestation.
    var productionExecutable: Bool { false }
    var preferredResearchCandidate: Checkpoint? {
        checkpoints.first(where: { $0.trees == 249 })
    }
}
