import Flutter
import UIKit
import CryptoKit

public final class EverifFaceSdkPlugin: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "com.everif.face-sdk", qos: .userInitiated)
  private var engine: FaceEngine?
  private let modelStore: ModelStore?

  init(registrar: FlutterPluginRegistrar) {
    self.modelStore = try? ModelStore()
  }

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
        let args = call.arguments as? [String: Any]
        let value: Any?
        switch call.method {
        case "hasModelPack": value = self.modelStore?.has(version: args?["version"] as? String ?? "") ?? false
        case "installModelPack":
          self.engine?.close(); self.engine = nil
          guard let modelStore = self.modelStore, let version = args?["version"] as? String, let models = args?["models"] as? [String: FlutterStandardTypedData] else { throw FaceEngineError.modelUnavailable }
          try modelStore.install(version: version, models: models); value = nil
        case "createTemplate": value = try self.faceEngine().createTemplate(bytes: args?["image"] as? FlutterStandardTypedData)
        case "verify": value = try self.faceEngine().verify(bytes: args?["image"] as? FlutterStandardTypedData, template: args?["template"] as? [Double], liveness: args?["liveness"] as? Bool ?? true)
        case "resetLiveness": self.engine?.reset(); value = nil
        case "dispose": self.engine?.close(); self.engine = nil; value = nil
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

  private func faceEngine() throws -> FaceEngine {
    if let engine { return engine }
    guard let modelStore else { throw FaceEngineError.modelUnavailable }
    let value = try FaceEngine(modelPaths: modelStore.paths(version: "1"))
    engine = value
    return value
  }
}
