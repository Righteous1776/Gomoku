import Foundation

/// Production model binding supplied by the specialized Training Agent.
///
/// Astra V9 (314 trees) and Sol V9 (160 trees) are distinct compiled forests.
/// Their complete exported nodes and original source digests are checked
/// by the mandatory engine provenance gate. This registry binds them to the
/// app without combining model identity, compute policy or saved match IDs.
enum EclipseTrainerProductionRegistry {
    private struct Binding: Decodable {
        let schema: String
        let modelID: String
        let trainingRevision: String
        let checkpointSHA256: String
        let computePolicySHA256: String
        let computePolicy: EclipseTrainerComputePolicy

        enum CodingKeys: String, CodingKey {
            case schema
            case modelID = "model_id"
            case trainingRevision = "training_revision"
            case checkpointSHA256 = "checkpoint_sha256"
            case computePolicySHA256 = "compute_policy_sha256"
            case computePolicy = "compute_policy"
        }
    }

    /// This file is a public-safe *identity + policy*, never training records
    /// or private forest checkpoint bytes. App code does not fabricate it.
    static let bundledManifestName = "ECLIPSE_ACTIVE_MODEL"
    static let bundledCatalogName = "ECLIPSE_ACTIVE_MODELS"

    static func resolve(
        manifestData: Data,
        cppLoadedCheckpointSHA256: String?
    ) -> EclipseVerifiedTrainerExecution? {
        // No raw owner games, private training paths or extra metadata may
        // be smuggled into the public app bundle beside the model identity.
        guard let object = try? JSONSerialization.jsonObject(
            with: manifestData
        ) as? [String: Any],
            Set(object.keys) == Set([
                "schema", "model_id", "training_revision",
                "checkpoint_sha256", "compute_policy_sha256",
                "compute_policy"
            ]),
            let computeFields = object["compute_policy"] as? [String: Any],
            Set(computeFields.keys) == Set([
                "mode", "max_wall_time_ms", "max_nodes",
                "max_depth", "root_width", "reply_width",
                "continuation_width", "forced_line_depth",
                "candidate_radius"
            ]),
            let manifest = try? JSONDecoder().decode(
                Binding.self, from: manifestData
            ), manifest.schema == "eclipse.production-model-binding.v1",
            let model = EclipseModelID(rawValue: manifest.modelID),
            model.requiresVerifiedCheckpoint,
            let actuallyLoaded = cppLoadedCheckpointSHA256,
            actuallyLoaded == manifest.checkpointSHA256,
            let actualPolicySHA256 = manifest.computePolicy.sha256,
            actualPolicySHA256 == manifest.computePolicySHA256
        else { return nil }

        return EclipseVerifiedTrainerExecution(
            model: model,
            trainingRevision: manifest.trainingRevision,
            checkpointSHA256: manifest.checkpointSHA256,
            loadedCheckpointSHA256: actuallyLoaded,
            computePolicy: manifest.computePolicy,
            approvedComputePolicySHA256: actualPolicySHA256,
            loadedComputePolicySHA256: actualPolicySHA256
        )
    }

    /// Both 2.0 checkpoints can be independently selected in one installed
    /// application. Source check sums MUST be confirmed by the live C++ V4
    /// forest binding, not merely present in this resource JSON.
    static func resolveCatalog(
        manifestData: Data,
        compiledIdentity: (EclipseModelID, String) -> String?
    ) -> [EclipseModelID: EclipseVerifiedTrainerExecution] {
        guard let object = try? JSONSerialization.jsonObject(
            with: manifestData
        ) as? [String: Any],
            Set(object.keys) == Set(["schema", "models"]),
            object["schema"] as? String
                == "eclipse.production-model-catalog.v2",
            let entries = object["models"] as? [[String: Any]],
            entries.count == 2
        else { return [:] }
        var result: [EclipseModelID: EclipseVerifiedTrainerExecution] = [:]
        for item in entries {
            guard let id = item["model_id"] as? String,
                  let model = EclipseModelID(rawValue: id),
                  model.requiresVerifiedCheckpoint,
                  result[model] == nil,
                  let checksum = item["checkpoint_sha256"] as? String,
                  let source = try? JSONSerialization.data(
                    withJSONObject: item, options: [.sortedKeys]
                  ),
                  let loaded = compiledIdentity(model, checksum),
                  let bound = resolve(
                    manifestData: source,
                    cppLoadedCheckpointSHA256: loaded
                  )
            else { return [:] }
            result[model] = bound
        }
        guard result[.astra20] != nil, result[.sol20] != nil
        else { return [:] }
        return result
    }

    /// Safe public app resource, storing metadata and two policy digests, not
    /// users' matches. Reject the whole catalog if either model is corrupted.
    static func loadAllFromBundle(_ bundle: Bundle = .main)
        -> [EclipseModelID: EclipseVerifiedTrainerExecution] {
        guard let url = bundle.url(
            forResource: bundledCatalogName, withExtension: "json"
        ), let data = try? Data(contentsOf: url) else { return [:] }
        var verified = resolveCatalog(manifestData: data) { model, checksum in
            EclipseCppProductionAdapter.loadedCheckpointSHA256(
                for: model, expectedSHA256: checksum
            )
        }
        // Separate opt-in experimental 3.0 path. Only genuine R07 raw bytes
        // parsed by native C++ AND an unchanged finite trainer policy permit
        // selecting it. It does NOT certify missing original R04 26D parity.
        if let research = EclipseGeneration3ResearchCatalog.loadFromBundle(bundle),
           let candidate = research.preferredResearchCandidate,
           candidate.id == research.flagshipCheckpointId,
           let astra2 = verified[.astra20],
           let digest = astra2.computePolicy.sha256,
           let loaded = EclipseCppProductionAdapter.loadedCheckpointSHA256(
               for: .astra30, expectedSHA256: candidate.sha256
           ),
           let v3 = EclipseVerifiedTrainerExecution(
               model: .astra30, trainingRevision: "R07",
               checkpointSHA256: candidate.sha256,
               loadedCheckpointSHA256: loaded,
               // Temporary same-geometry time ceiling as 2.0 Astra.
               // This is NOT represented as an R07-trained compute head.
               computePolicy: astra2.computePolicy,
               approvedComputePolicySHA256: digest,
               loadedComputePolicySHA256: digest
           ) {
            verified[.astra30] = v3
        }
        return verified
    }

    static func loadFromBundle(_ bundle: Bundle = .main)
        -> EclipseVerifiedTrainerExecution? {
        guard let url = bundle.url(
            forResource: bundledManifestName, withExtension: "json"
        ), let data = try? Data(contentsOf: url) else { return nil }
        // Do NOT trust manifest metadata without a genuine native C++
        // loaded-checkpoint identity. An R10 static core reports no model.
        return resolve(
            manifestData: data,
            cppLoadedCheckpointSHA256:
                EclipseCppProductionAdapter.loadedCheckpointSHA256()
        )
    }
}