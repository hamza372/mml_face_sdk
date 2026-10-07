import Flutter
import UIKit
import Vision
import TensorFlowLite

enum FaceEngineError: String, Error { case invalidImage, noFace, multipleFaces, faceTooSmall, faceNotFrontal, landmarksMissing, templateIncompatible, internalError = "internal" }

final class FaceEngine {
  private var arc: Interpreter
  private var fas27: Interpreter
  private var fas40: Interpreter
  private var scores: [Double] = []
  private var lowRun = 0
  private var lowStarted: TimeInterval = 0
  private var spoofLatched = false

  init(assetPath: (String) -> String) throws {
    func model(_ name: String) throws -> Interpreter {
      guard let path = Bundle.main.path(forResource: assetPath("assets/models/\(name)"), ofType: nil) else { throw FaceEngineError.internalError }
      var options = Interpreter.Options(); options.threadCount = 2
      var interpreter = try Interpreter(modelPath: path, options: options); try interpreter.allocateTensors(); return interpreter
    }
    arc = try model("mobileFaceNetARCNET.tflite"); fas27 = try model("minifas_v2_2.7_80.tflite"); fas40 = try model("minifas_v1se_4.0_80.tflite")
  }

  func createTemplate(bytes: FlutterStandardTypedData?) throws -> [String: Any] {
    let (image, face) = try detect(bytes)
    return quality(image, face).merging(["embedding": try embedding(align(image, face))]) { _, new in new }
  }

  func verify(bytes: FlutterStandardTypedData?, template: [Double]?, liveness: Bool) throws -> [String: Any?] {
    guard let template else { throw FaceEngineError.templateIncompatible }
    let (image, face) = try detect(bytes); var output: [String: Any?] = quality(image, face)
    if liveness {
      if face.boundingBox.width < 0.72 { scores=[];lowRun=0;lowStarted=0;output["livenessPassed"]=false;output["spoofLatched"]=spoofLatched;return output }
      if spoofLatched { output["livenessPassed"] = false; output["spoofLatched"] = true; return output }
      let score = (try fasScore(&fas27, image, face, 2.7) + fasScore(&fas40, image, face, 4.0)) / 2
      scores.append(score); if scores.count > 4 { scores.removeFirst() }
      let now = Date().timeIntervalSince1970
      if score < 0.40 { if lowRun == 0 { lowStarted = now }; lowRun += 1; if lowRun >= 3 && now - lowStarted >= 0.6 { spoofLatched = true } } else { lowRun = 0; lowStarted = 0 }
      let sorted = scores.sorted(); let median = sorted.count % 2 == 0 ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2 : sorted[sorted.count / 2]
      output["livenessScore"] = median; output["spoofLatched"] = spoofLatched
      guard scores.count == 4 && median >= 0.75 && !spoofLatched else { output["livenessPassed"] = false; return output }
      output["livenessPassed"] = true
    } else { output["livenessPassed"] = nil }
    let current = try embedding(align(image, face)); guard current.count == template.count else { throw FaceEngineError.templateIncompatible }
    output["similarity"] = zip(current, template).reduce(0) { $0 + $1.0 * $1.1 }
    return output
  }

  private func detect(_ bytes: FlutterStandardTypedData?) throws -> (CGImage, VNFaceObservation) {
    guard let bytes, let ui = UIImage(data: bytes.data), let raw = normalized(ui).cgImage, let image = resize(raw, raw.width, raw.height) else { throw FaceEngineError.invalidImage }
    let request = VNDetectFaceLandmarksRequest(); try VNImageRequestHandler(cgImage: image).perform([request]); let faces = request.results ?? []
    guard !faces.isEmpty else { throw FaceEngineError.noFace }; guard faces.count == 1 else { throw FaceEngineError.multipleFaces }
    let face = faces[0]; guard face.boundingBox.width >= 0.20 else { throw FaceEngineError.faceTooSmall }
    guard abs(face.yaw?.doubleValue ?? 0) <= 0.35, abs(face.roll?.doubleValue ?? 0) <= 0.35 else { throw FaceEngineError.faceNotFrontal }
    return (image, face)
  }

  private func normalized(_ image: UIImage) -> UIImage { if image.imageOrientation == .up { return image }; UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale); image.draw(in: CGRect(origin: .zero, size: image.size)); let out = UIGraphicsGetImageFromCurrentImageContext()!; UIGraphicsEndImageContext(); return out }
  private func quality(_ image: CGImage, _ face: VNFaceObservation) -> [String: Any] { ["faceRatio": face.boundingBox.width, "yaw": (face.yaw?.doubleValue ?? 0) * 180 / .pi, "roll": (face.roll?.doubleValue ?? 0) * 180 / .pi] }

  private func points(_ face: VNFaceObservation, _ image: CGImage) throws -> [CGPoint] {
    guard let l = face.landmarks, let left = l.leftEye, let right = l.rightEye, let nose = l.nose, let lips = l.outerLips else { throw FaceEngineError.landmarksMissing }
    func mean(_ r: VNFaceLandmarkRegion2D) -> CGPoint { r.normalizedPoints.reduce(.zero) { CGPoint(x: $0.x + $1.x / CGFloat(r.pointCount), y: $0.y + $1.y / CGFloat(r.pointCount)) } }
    let lip = lips.normalizedPoints; guard let minLip = lip.min(by: {$0.x < $1.x}), let maxLip = lip.max(by: {$0.x < $1.x}) else { throw FaceEngineError.landmarksMissing }
    func pixel(_ p: CGPoint) -> CGPoint { let b=face.boundingBox; return CGPoint(x:(b.minX+p.x*b.width)*CGFloat(image.width), y:(1-(b.minY+p.y*b.height))*CGFloat(image.height)) }
    return [pixel(mean(left)), pixel(mean(right)), pixel(mean(nose)), pixel(minLip), pixel(maxLip)]
  }

  private func align(_ image: CGImage, _ face: VNFaceObservation) throws -> CGImage {
    var src = try points(face, image); let eyes = Array(src[0...1]).sorted{$0.x<$1.x}; let mouths = Array(src[3...4]).sorted{$0.x<$1.x}; src=[eyes[0],eyes[1],src[2],mouths[0],mouths[1]]
    let dst=[CGPoint(x:38.2946,y:51.6963),CGPoint(x:73.5318,y:51.5014),CGPoint(x:56.0252,y:71.7366),CGPoint(x:41.5493,y:92.3655),CGPoint(x:70.7299,y:92.2041)]
    let sc=src.reduce(.zero){CGPoint(x:$0.x+$1.x/5,y:$0.y+$1.y/5)}, dc=dst.reduce(.zero){CGPoint(x:$0.x+$1.x/5,y:$0.y+$1.y/5)}; var den=0.0,real=0.0,imag=0.0
    for i in 0..<5 { let x=src[i].x-sc.x,y=src[i].y-sc.y,u=dst[i].x-dc.x,v=dst[i].y-dc.y;den+=x*x+y*y;real+=u*x+v*y;imag+=v*x-u*y }; guard den>0 else { throw FaceEngineError.landmarksMissing }
    let a=real/den,b=imag/den,tx=dc.x-a*sc.x+b*sc.y,ty=dc.y-b*sc.x-a*sc.y,det=a*a+b*b
    guard let data=image.dataProvider?.data, let ptr=CFDataGetBytePtr(data) else { throw FaceEngineError.internalError }; let stride=image.bytesPerRow,bpp=image.bitsPerPixel/8; var out=[UInt8](repeating:0,count:112*112*4)
    for y in 0..<112 { for x in 0..<112 { let u=CGFloat(x)-tx,v=CGFloat(y)-ty,sx=Int(((a*u+b*v)/det).rounded()),sy=Int(((-b*u+a*v)/det).rounded()); if sx>=0&&sy>=0&&sx<image.width&&sy<image.height { let si=sy*stride+sx*bpp,di=(y*112+x)*4; out[di]=ptr[si];out[di+1]=ptr[si+1];out[di+2]=ptr[si+2];out[di+3]=255 } } }
    return out.withUnsafeMutableBytes { raw in CGContext(data: raw.baseAddress,width:112,height:112,bitsPerComponent:8,bytesPerRow:448,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()! }
  }

  private func fasScore(_ model: inout Interpreter, _ image: CGImage, _ face: VNFaceObservation, _ scale: CGFloat) throws -> Double {
    let b=face.boundingBox;let fw=b.width*CGFloat(image.width),fh=b.height*CGFloat(image.height),cx=b.midX*CGFloat(image.width),cy=(1-b.midY)*CGFloat(image.height);let w=min(fw*scale,CGFloat(image.width)),h=min(fh*scale,CGFloat(image.height));let rect=CGRect(x:max(0,min(CGFloat(image.width)-w,cx-w/2)),y:max(0,min(CGFloat(image.height)-h,cy-h/2)),width:w,height:h)
    guard let crop=image.cropping(to:rect),let resized=resize(crop,80,80) else { throw FaceEngineError.internalError }; let input=try bgr(resized, normalized:false);try model.copy(input,toInputAt:0);try model.invoke();return probability(try model.output(at:0).data)
  }
  private func embedding(_ image: CGImage) throws -> [Double] { let input=try bgr(image,normalized:true);try arc.copy(input,toInputAt:0);try arc.invoke();let values=try floats(arc.output(at:0).data).map(Double.init);let norm=sqrt(values.reduce(0){$0+$1*$1});guard norm>0 else{throw FaceEngineError.internalError};return values.map{$0/norm} }
  private func bgr(_ image:CGImage,normalized:Bool)throws->Data{guard let data=image.dataProvider?.data,let p=CFDataGetBytePtr(data)else{throw FaceEngineError.internalError};var values=[Float]();values.reserveCapacity(image.width*image.height*3);let bpp=image.bitsPerPixel/8;for y in 0..<image.height{for x in 0..<image.width{let i=y*image.bytesPerRow+x*bpp;for c in [2,1,0]{let v=Float(p[i+c]);values.append(normalized ? (v-127.5)/128:v)}}};return values.withUnsafeBufferPointer{Data(buffer:$0)} }
  private func floats(_ data:Data)throws->[Float]{guard data.count%4==0 else{throw FaceEngineError.internalError};return data.withUnsafeBytes{Array($0.bindMemory(to:Float.self))} }
  private func probability(_ data:Data)->Double{let v=data.withUnsafeBytes{Array($0.bindMemory(to:Float.self))};let sum=v.reduce(0,+);if v.allSatisfy({$0>=0&&$0<=1})&&abs(sum-1)<0.001{return Double(v[1])};let m=v.max()!,e=v.map{Foundation.exp(Double($0-m))};return e[1]/e.reduce(0,+)}
  private func resize(_ image:CGImage,_ w:Int,_ h:Int)->CGImage?{var bytes=[UInt8](repeating:0,count:w*h*4);return bytes.withUnsafeMutableBytes{raw in let c=CGContext(data:raw.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!;c.interpolationQuality = .high;c.draw(image,in:CGRect(x:0,y:0,width:w,height:h));return c.makeImage()} }
  func reset(){scores=[];lowRun=0;lowStarted=0;spoofLatched=false}
  func close(){reset()}
}
