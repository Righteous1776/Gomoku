import Foundation

/// Production model binding supplied by the specialized Training Agent.
///
/// The actual 214-tree/R29 C++ scorer is built/installed by the Training
/// Agent, not synthesized from an old R10 model. This registry merely binds
/// that already-loaded C++ checkpoint to the real AppController.
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