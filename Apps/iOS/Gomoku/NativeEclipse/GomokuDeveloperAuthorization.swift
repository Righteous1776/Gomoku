import Combine
import Foundation
import LocalAuthentication

/// Standalone device-owner gate for private lesson capture and training import.
/// A successful device passcode/biometric challenge grants at most ten minutes;
/// ordinary game UI never receives a persistent capability.
@MainActor
final class GomokuDeveloperAuthorization: ObservableObject {
    @Published private(set) var authorizedUntil: Date?
    @Published private(set) var failure: String?
    private let permit = GomokuDeveloperPermit()

    var importPermit: GomokuDeveloperPermit.Authorization? {
        isAuthorized ? permit.currentAuthorization() : nil
    }

    var isAuthorized: Bool {
        guard let authorizedUntil, authorizedUntil > Date() else { return false }
        return true
    }

    @discardableResult
    func authorize() async -> Bool {
        revoke()
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            failure = "此设备未设置可用的系统解锁方式，无法开启开发者训练入口。"
            return false
        }
        do {
            guard try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "验证设备持有人身份，以修改 Gomoku 的私有 ECLIPSE 训练知识库"
            ) else {
                failure = "未通过设备身份验证。"
                return false
            }
            let expiry = Date().addingTimeInterval(10 * 60)
            authorizedUntil = expiry
            _ = permit.grant(until: expiry)
            failure = nil
            return true
        } catch {
            failure = error.localizedDescription
            return false
        }
    }

    func revoke() {
        permit.revoke()
        authorizedUntil = nil
        failure = nil
    }
}
