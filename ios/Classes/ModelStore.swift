import Flutter
import Foundation
import TensorFlowLite

final class ModelStore {
  private let root: URL
  private let names: Set<String> = [
    "mobileFaceNetARCNET.tflite",
    "minifas_v2_2.7_80.tflite",
    "minifas_v1se_4.0_80.tflite",
  ]

  init() throws {
    guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { throw FaceEngineError.modelUnavailable }
    root = base.appendingPathComponent("MmlFaceSdk/model_packs", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    var values = URLResourceValues(); values.isExcludedFromBackup = true
    var mutableRoot = root; try? mutableRoot.setResourceValues(values)
  }

  func has(version: String) -> Bool {
    guard safe(version) else { return false }
    return names.allSatisfy { FileManager.default.fileExists(atPath: root.appendingPathComponent(version).appendingPathComponent($0).path) }
  }

  func paths(version: String) throws -> [String: String] {
    guard has(version: version) else { throw FaceEngineError.modelUnavailable }
    return Dictionary(uniqueKeysWithValues: names.map { ($0, root.appendingPathComponent(version).appendingPathComponent($0).path) })
  }

  func install(version: String, models: [String: FlutterStandardTypedData]) throws {
    guard safe(version), Set(models.keys) == names else { throw FaceEngineError.modelUnavailable }
    let stage = root.appendingPathComponent(".stage-\(version)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: stage) }
    for name in names {
      guard let data = models[name]?.data, !data.isEmpty else { throw FaceEngineError.modelUnavailable }
      try data.write(to: stage.appendingPathComponent(name), options: .atomic)
    }
    try validate(stage)
    let target = root.appendingPathComponent(version, isDirectory: true)
    if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
    try FileManager.default.moveItem(at: stage, to: target)
  }

  private func validate(_ directory: URL) throws {
    func model(_ name: String) throws -> Interpreter {
      var options = Interpreter.Options(); options.threadCount = 1
      var value = try Interpreter(modelPath: directory.appendingPathComponent(name).path, options: options)
      try value.allocateTensors(); return value
    }
    let recognition = try model("mobileFaceNetARCNET.tflite")
    guard try recognition.input(at: 0).shape.dimensions == [1, 112, 112, 3], try recognition.output(at: 0).shape.dimensions.last ?? 0 > 0 else { throw FaceEngineError.modelUnavailable }
    for name in ["minifas_v2_2.7_80.tflite", "minifas_v1se_4.0_80.tflite"] {
      let liveness = try model(name)
      guard try liveness.input(at: 0).shape.dimensions == [1, 80, 80, 3], try liveness.output(at: 0).shape.dimensions == [1, 3] else { throw FaceEngineError.modelUnavailable }
    }
  }

  private func safe(_ version: String) -> Bool { version.range(of: "^[0-9]{1,8}$", options: .regularExpression) != nil }
}
