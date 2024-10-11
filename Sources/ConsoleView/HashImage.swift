import SwiftUI

extension Image {
  init?(
    hashing: some Encodable,
    size: Int,
    scale: Int
  ) {
    if let data = try? JSONEncoder().encode(hashing),
      let this = HashImage(data: data, size: size, scale: scale).createImage()
    {
      self = this
    } else {
      return nil
    }
  }
}

final class HashImage {
  // MARK: - Properties

  private var seed: [UInt32]

  var size: Int
  var scale: Int

  var color: Color
  var bgColor: Color
  var spotColor: Color

  init(
    data: Data,
    size: Int = 8,
    scale: Int = 10,
    color: Color? = nil,
    bgColor _: Color? = nil,
    spotColor _: Color? = nil
  ) {
    var seed = Self.uIntSeed(seed: data)
    self.size = size
    self.scale = scale
    self.color = color ?? Self.color(from: &seed)
    bgColor = color ?? Self.color(from: &seed)
    spotColor = color ?? Self.color(from: &seed)
    self.seed = seed
  }

  func createImage(scaleMultiple: Int = 1) -> Image? {
    image(data: imageData(), scaleMultiple: scaleMultiple)
  }

  private static func rand(_ seed: inout [UInt32]) -> Double {
    let t = seed[0] ^ (seed[0] << 11)
    seed[0] = seed[1]
    seed[1] = seed[2]
    seed[2] = seed[3]
    let tmp = Int32(bitPattern: seed[3])
    let tmpT = Int32(bitPattern: t)
    seed[3] = UInt32(bitPattern: tmp ^ (tmp >> 19) ^ tmpT ^ (tmpT >> 8))
    let divisor = Int32.max

    return Double(UInt32(seed[3]) >> UInt32(0)) / Double(divisor)
  }

  private static func color(from seed: inout [UInt32]) -> Color {
    let h = Double(rand(&seed) * 360)
    let s = Double((rand(&seed) * 60) + 40) / Double(100)
    let l = Double((rand(&seed) + rand(&seed) + rand(&seed) + rand(&seed)) * 25) / Double(100)

    return SystemColor(hue: h, saturation: s, lightness: l).swiftUIColor
  }

  private func imageData() -> [Double] {
    let width = size
    let height = size

    let dataWidth = Int(ceil(Double(width) / Double(2)))
    let mirrorWidth = width - dataWidth

    var data: [Double] = []
    for _ in 0..<height {
      var row = [Double](repeating: 0, count: dataWidth)
      for x in 0..<dataWidth {
        row[x] = floor(Double(Self.rand(&seed)) * 2.3)
      }
      let r = [Double](row[0..<mirrorWidth]).reversed()
      row.append(contentsOf: r)
      for i in 0..<row.count {
        data.append(row[i])
      }
    }

    return data
  }

  private func image(data: [Double], scaleMultiple: Int) -> Image? {
    let finalSize = size * scale * scaleMultiple
    #if os(iOS) || os(tvOS) || os(watchOS)
      UIGraphicsBeginImageContext(CGSize(width: finalSize, height: finalSize))
      let nilContext = UIGraphicsGetCurrentContext()
    #elseif os(macOS)
      let colorSpace = CGColorSpaceCreateDeviceRGB()
      let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
      let nilContext = CGContext(
        data: nil, width: finalSize, height: finalSize, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: bitmapInfo.rawValue
      )
    #endif

    guard let context = nilContext else {
      return nil
    }

    let width = Int(sqrt(Double(data.count)))

    context.setFillColor(bgColor.cgColor ?? CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: size * scale, height: size * scale))

    for i in 0..<data.count {
      let row = Int(floor(Double(i) / Double(width)))
      let col = i % width

      let number = data[i]

      let uiColor: Color
      if number == 0 {
        uiColor = bgColor
      } else if number == 1 {
        uiColor = color
      } else if number == 2 {
        uiColor = spotColor
      } else {
        uiColor = Color.black
      }

      context.setFillColor(uiColor.cgColor ?? CGColor(red: 0, green: 0, blue: 0, alpha: 1))
      context.fill(
        CGRect(
          x: CGFloat(col * scale * scaleMultiple), y: CGFloat(row * scale * scaleMultiple),
          width: CGFloat(scale * scaleMultiple), height: CGFloat(scale * scaleMultiple)
        ))
    }

    #if os(iOS) || os(tvOS) || os(watchOS)
      let output = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()

      return output.map { Image(uiImage: $0) }
    #elseif os(macOS)
      guard let output = context.makeImage() else {
        return nil
      }

      return Image(
        nsImage: NSImage(cgImage: output, size: CGSize(width: finalSize, height: finalSize)))
    #endif
  }

  static func uIntSeed(seed: Data) -> [UInt32] {
    var uintSeed = [UInt32](repeating: 0, count: 4)
    for i in 0..<seed.count {
      uintSeed[i % 4] = ((uintSeed[i % 4] &* (2 << 4)) &- uintSeed[i % 4])
      let index = seed.index(seed.startIndex, offsetBy: i)
      uintSeed[i % 4] = uintSeed[i % 4] &+ UInt32(seed[index])
    }
    return uintSeed
  }
}

extension Double {
  fileprivate static var unitRandom: Double {
    return Double(arc4random()) / 0xFFFF_FFFF
  }
}

extension Character {
  fileprivate var asciiValue: UInt32 {
    let s = String(self).unicodeScalars
    return s[s.startIndex].value
  }
}
