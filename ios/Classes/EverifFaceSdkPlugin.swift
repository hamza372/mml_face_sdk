import Flutter
import UIKit
import CryptoKit

public final class EverifFaceSdkPlugin: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "com.everif.face-sdk", qos: .userInitiated)
  private var engine: FaceEngine?
  private let registrar: FlutterPluginRegistrar

  init(registrar: FlutterPluginRegistrar) { self.registrar = registrar }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "everif_face_sdk", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(EverifFaceSdkPlugin(registrar: registrar), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getDeviceBinding" {
      let appId = Bundle.main.bundleIdentifier ?? "unknown"
      let vendor = UIDevice.current.identifierForVendor?.uuidString ?? "unavailable"
      let digest = SHA256.hash(data: Data("ios:\(vendor):\(appId)".utf8)).map { String(format: "%02x", $0) }.joined()
      result(["appId": appId, "deviceId": digest, "platform": "ios"]); return
    }
    queue.async {
      do {
        if self.engine == nil { self.engine = try FaceEngine(assetPath: { self.registrar.lookupKey(forAsset: $0, fromPackage: "everif_face_sdk") }) }
        guard let engine = self.engine else { throw FaceEngineError.internalError }
        let args = call.arguments as? [String: Any]
        let value: Any?
        switch call.method {
        case "createTemplate": value = try engine.createTemplate(bytes: args?["image"] as? FlutterStandardTypedData)
        case "verify": value = try engine.verify(bytes: args?["image"] as? FlutterStandardTypedData, template: args?["template"] as? [Double], liveness: args?["liveness"] as? Bool ?? true)
        case "resetLiveness": engine.reset(); value = nil
        case "dispose": engine.close(); self.engine = nil; value = nil
        default: DispatchQueue.main.async { result(FlutterMethodNotImplemented) }; return
        }
        DispatchQueue.main.async { result(value) }
      } catch let error as FaceEngineError {
        DispatchQueue.main.async { result(FlutterError(code: error.rawValue, message: "Face operation failed.", details: nil)) }
      } catch {
        DispatchQueue.main.async { result(FlutterError(code: "internal", message: "Face operation failed.", details: nil)) }
      }
    }
  }
}
