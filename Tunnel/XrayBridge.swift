import Foundation
import LibXray

enum XrayBridge {
    static func invoke(_ method: String, payload: [String: Any] = [:]) throws {
        let data = try JSONSerialization.data(withJSONObject: ["apiVersion": 3, "method": method, "payload": payload])
        var request = Array(String(decoding: data, as: UTF8.self).utf8CString)
        let pointer = request.withUnsafeMutableBufferPointer { CGoInvoke($0.baseAddress) }
        guard let pointer else { throw CoreError.unavailable }
        defer { CGoFree(pointer) }
        let response = Data(String(cString: pointer).utf8)
        guard let object = try JSONSerialization.jsonObject(with: response) as? [String: Any], object["success"] as? Bool == true else {
            // Core errors can contain server credentials. Do not surface/log their raw text.
            throw CoreError.rejected
        }
    }
    enum CoreError: LocalizedError {
        case unavailable, rejected
        var errorDescription: String? { "Ядро Xray не смогло запустить туннель. Проверьте параметры VLESS и совместимость сборки." }
    }
}
