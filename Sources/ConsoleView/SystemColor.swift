import SwiftUI

#if os(iOS) || os(tvOS) || os(watchOS)
  import UIKit

  typealias SystemColor = UIColor
#elseif os(macOS)
  import AppKit

  typealias SystemColor = NSColor
#endif

private func clip<T: Comparable>(_ v: T, _ minimum: T, _ maximum: T) -> T {
  max(min(v, maximum), minimum)
}

private func moda(_ x: CGFloat, m: CGFloat) -> CGFloat {
  (x.truncatingRemainder(dividingBy: m) + m).truncatingRemainder(dividingBy: m)
}

private func roundDecimal(_ x: CGFloat, precision: CGFloat = 10000.0) -> CGFloat {
  CGFloat(Int(round(x * precision))) / precision
}

private func roundToHex(_ x: CGFloat) -> UInt32 {
  guard x > 0 else { return 0 }
  let rounded: CGFloat = round(x * 255.0)

  return UInt32(rounded)
}

enum GrayscalingMode {
  case luminance
  case lightness
  case average
  case value
}
enum SystemColorSpace {
  case rgb
  case hsl
  case hsb
  case lab
}

extension SystemColor {

  convenience init(hexString: String) {
    let hexString = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
    let scanner = Scanner(string: hexString)
    scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")

    var color: UInt64 = 0

    if scanner.scanHexInt64(&color) {
      self.init(hex: color, useAlpha: hexString.count > 7)
    } else {
      self.init(hex: 0x000000)
    }
  }

  convenience init(hex: UInt64, useAlpha alphaChannel: Bool = false) {
    let mask = UInt64(0xFF)
    let cappedHex = !alphaChannel && hex > 0xFFFFFF ? 0xFFFFFF : hex

    let r = cappedHex >> (alphaChannel ? 24 : 16) & mask
    let g = cappedHex >> (alphaChannel ? 16 : 8) & mask
    let b = cappedHex >> (alphaChannel ? 8 : 0) & mask
    let a = alphaChannel ? cappedHex & mask : 255

    let red = CGFloat(r) / 255.0
    let green = CGFloat(g) / 255.0
    let blue = CGFloat(b) / 255.0
    let alpha = CGFloat(a) / 255.0

    self.init(red: red, green: green, blue: blue, alpha: alpha)
  }

  var hexString: String {
    return String(format: "#%06x", hex)
  }

  var hex: UInt32 {
    let rgba = rgbaComponents

    return roundToHex(rgba.r) << 16 | roundToHex(rgba.g) << 8 | roundToHex(rgba.b)
  }

  var RGBA: UInt32 {
    let rgba = rgbaComponents

    return roundToHex(rgba.r) << 24 | roundToHex(rgba.g) << 16 | roundToHex(rgba.b) << 8
      | roundToHex(rgba.a)
  }

  var AGBR: UInt32 {
    let rgba = rgbaComponents

    return roundToHex(rgba.a) << 24 | roundToHex(rgba.b) << 16 | roundToHex(rgba.g) << 8
      | roundToHex(rgba.r)
  }

  func isEqual(toHexString hexString: String) -> Bool {
    self.hexString == hexString
  }

  func isEqual(toHex hex: UInt32) -> Bool {
    self.hex == hex
  }

  func isLight() -> Bool {
    let components = rgbaComponents
    let brightness =
      ((components.r * 299.0) + (components.g * 587.0) + (components.b * 114.0)) / 1000.0

    return brightness >= 0.5
  }

  var luminance: CGFloat {
    let components = rgbaComponents

    let componentsArray = [components.r, components.g, components.b].map { val -> CGFloat in
      guard val <= 0.03928 else { return pow((val + 0.055) / 1.055, 2.4) }

      return val / 12.92
    }

    return (0.2126 * componentsArray[0]) + (0.7152 * componentsArray[1])
      + (0.0722 * componentsArray[2])
  }

  func contrastRatio(with otherColor: SystemColor) -> CGFloat {
    let otherLuminance = otherColor.luminance

    let l1 = max(luminance, otherLuminance)
    let l2 = min(luminance, otherLuminance)

    return (l1 + 0.05) / (l2 + 0.05)
  }
}

extension SystemColor {
  var rgbaComponents: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0

    #if os(iOS) || os(tvOS) || os(watchOS)
      getRed(&r, green: &g, blue: &b, alpha: &a)

      return (r, g, b, a)
    #elseif os(macOS)
      guard let rgbaColor = usingColorSpace(.deviceRGB) else {
        fatalError("Could not convert color to RGBA.")
      }

      rgbaColor.getRed(&r, green: &g, blue: &b, alpha: &a)

      return (r, g, b, a)
    #endif
  }

  #if os(iOS) || os(tvOS) || os(watchOS)

    var redComponent: CGFloat {
      return rgbaComponents.r
    }

    var greenComponent: CGFloat {
      return rgbaComponents.g
    }

    var blueComponent: CGFloat {
      return rgbaComponents.b
    }

    var alphaComponent: CGFloat {
      return rgbaComponents.a
    }
  #endif

  func adjustedAlpha(amount: CGFloat) -> SystemColor {
    let components = rgbaComponents
    let normalizedAlpha = clip(components.a + amount, 0.0, 1.0)

    return SystemColor(
      red: components.r, green: components.g, blue: components.b, alpha: normalizedAlpha
    )
  }
}

extension SystemColor {

  convenience init(L: CGFloat, a: CGFloat, b: CGFloat, alpha: CGFloat = 1) {
    let clippedL = clip(L, 0.0, 100.0)
    let clippedA = clip(a, -128.0, 127.0)
    let clippedB = clip(b, -128.0, 127.0)

    let normalized = { (c: CGFloat) -> CGFloat in
      pow(c, 3) > 0.008856 ? pow(c, 3) : (c - (16 / 116)) / 7.787
    }

    let preY = (clippedL + 16.0) / 116.0
    let preX = (clippedA / 500.0) + preY
    let preZ = preY - (clippedB / 200.0)

    let X = 95.05 * normalized(preX)
    let Y = 100.0 * normalized(preY)
    let Z = 108.9 * normalized(preZ)

    self.init(X: X, Y: Y, Z: Z, alpha: alpha)
  }

  var labComponents: (L: CGFloat, a: CGFloat, b: CGFloat) {
    let normalized = { (c: CGFloat) -> CGFloat in
      c > 0.008856 ? pow(c, 1.0 / 3.0) : (7.787 * c) + (16.0 / 116.0)
    }

    let xyz = xyzComponents
    let normalizedX = normalized(xyz.X / 95.05)
    let normalizedY = normalized(xyz.Y / 100.0)
    let normalizedZ = normalized(xyz.Z / 108.9)

    let L = roundDecimal((116.0 * normalizedY) - 16.0, precision: 1000)
    let a = roundDecimal(500.0 * (normalizedX - normalizedY), precision: 1000)
    let b = roundDecimal(200.0 * (normalizedY - normalizedZ), precision: 1000)

    return (L: L, a: a, b: b)
  }
}
private struct HSL {
  var h: CGFloat = 0.0
  var s: CGFloat = 0.0
  var l: CGFloat = 0.0
  var a: CGFloat = 1.0

  init(hue: CGFloat, saturation: CGFloat, lightness: CGFloat, alpha: CGFloat = 1.0) {
    h = hue.truncatingRemainder(dividingBy: 360.0) / 360.0
    s = clip(saturation, 0.0, 1.0)
    l = clip(lightness, 0.0, 1.0)
    a = clip(alpha, 0.0, 1.0)
  }

  init(color: SystemColor) {
    let rgba = color.rgbaComponents

    let maximum = max(rgba.r, max(rgba.g, rgba.b))
    let minimum = min(rgba.r, min(rgba.g, rgba.b))

    let delta = maximum - minimum

    h = 0.0
    s = 0.0
    l = (maximum + minimum) / 2.0

    if delta != 0.0 {
      if l < 0.5 {
        s = delta / (maximum + minimum)
      } else {
        s = delta / (2.0 - maximum - minimum)
      }

      if rgba.r == maximum {
        h = ((rgba.g - rgba.b) / delta) + (rgba.g < rgba.b ? 6.0 : 0.0)
      } else if rgba.g == maximum {
        h = ((rgba.b - rgba.r) / delta) + 2.0
      } else if rgba.b == maximum {
        h = ((rgba.r - rgba.g) / delta) + 4.0
      }
    }

    h /= 6.0
    a = rgba.a
  }

  func systemColor() -> SystemColor {
    let (r, g, b, a) = rgbaComponents()

    return SystemColor(red: r, green: g, blue: b, alpha: a)
  }

  func rgbaComponents() -> (CGFloat, CGFloat, CGFloat, CGFloat) {
    let m2 = l <= 0.5 ? l * (s + 1.0) : (l + s) - (l * s)
    let m1 = (l * 2.0) - m2

    let r = hueToRGB(m1: m1, m2: m2, h: h + (1.0 / 3.0))
    let g = hueToRGB(m1: m1, m2: m2, h: h)
    let b = hueToRGB(m1: m1, m2: m2, h: h - (1.0 / 3.0))

    return (r, g, b, CGFloat(a))
  }

  private func hueToRGB(m1: CGFloat, m2: CGFloat, h: CGFloat) -> CGFloat {
    let hue = moda(h, m: 1)

    if hue * 6 < 1.0 {
      return m1 + ((m2 - m1) * hue * 6.0)
    } else if hue * 2.0 < 1.0 {
      return m2
    } else if hue * 3.0 < 1.9999 {
      return m1 + ((m2 - m1) * ((2.0 / 3.0) - hue) * 6.0)
    }

    return m1
  }

  func adjustedHue(amount: CGFloat) -> HSL {
    return HSL(hue: (h * 360.0) + amount, saturation: s, lightness: l, alpha: a)
  }

  func lighter(amount: CGFloat) -> HSL {
    return HSL(hue: h * 360.0, saturation: s, lightness: l + amount, alpha: a)
  }

  func darkened(amount: CGFloat) -> HSL {
    return lighter(amount: amount * -1.0)
  }

  func saturated(amount: CGFloat) -> HSL {
    return HSL(hue: h * 360.0, saturation: s + amount, lightness: l, alpha: a)
  }

  func desaturated(amount: CGFloat) -> HSL {
    return saturated(amount: amount * -1.0)
  }
}

extension SystemColor {

  func adjustedHue(amount: CGFloat) -> SystemColor {
    return HSL(color: self).adjustedHue(amount: amount).systemColor()
  }

  func complemented() -> SystemColor {
    return adjustedHue(amount: 180.0)
  }

  func lighter(amount: CGFloat = 0.2) -> SystemColor {
    return HSL(color: self).lighter(amount: amount).systemColor()
  }

  func darkened(amount: CGFloat = 0.2) -> SystemColor {
    return HSL(color: self).darkened(amount: amount).systemColor()
  }

  func saturated(amount: CGFloat = 0.2) -> SystemColor {
    return HSL(color: self).saturated(amount: amount).systemColor()
  }

  func desaturated(amount: CGFloat = 0.2) -> SystemColor {
    return HSL(color: self).desaturated(amount: amount).systemColor()
  }

  func grayscaled(mode: GrayscalingMode = .lightness) -> SystemColor {
    let (r, g, b, a) = rgbaComponents

    let l: CGFloat
    switch mode {
    case .luminance:
      l = (0.299 * r) + (0.587 * g) + (0.114 * b)
    case .lightness:
      l = 0.5 * (max(r, g, b) + min(r, g, b))
    case .average:
      l = (1.0 / 3.0) * (r + g + b)
    case .value:
      l = max(r, g, b)
    }

    return HSL(hue: 0.0, saturation: 0.0, lightness: l, alpha: a).systemColor()
  }

  func inverted() -> SystemColor {
    let rgba = rgbaComponents

    let invertedRed = 1.0 - rgba.r
    let invertedGreen = 1.0 - rgba.g
    let invertedBlue = 1.0 - rgba.b

    return SystemColor(red: invertedRed, green: invertedGreen, blue: invertedBlue, alpha: rgba.a)
  }
}

extension SystemColor {

  convenience init(hue: CGFloat, saturation: CGFloat, lightness: CGFloat, alpha: CGFloat = 1) {
    let color = HSL(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
      .systemColor()
    let components = color.rgbaComponents

    self.init(red: components.r, green: components.g, blue: components.b, alpha: components.a)
  }

  var hslComponents: (h: CGFloat, s: CGFloat, l: CGFloat) {
    let hsl = HSL(color: self)

    return (hsl.h * 360.0, hsl.s, hsl.l)
  }
}

extension SystemColor {

  convenience init(X: CGFloat, Y: CGFloat, Z: CGFloat, alpha: CGFloat = 1) {
    let clippedX = clip(X, 0.0, 95.05) / 100.0
    let clippedY = clip(Y, 0.0, 100) / 100.0
    let clippedZ = clip(Z, 0.0, 108.9) / 100.0

    let toRGB = { (c: CGFloat) -> CGFloat in
      let rgb = c > 0.0031308 ? 1.055 * pow(c, 1.0 / 2.4) - 0.055 : c * 12.92

      return abs(roundDecimal(rgb, precision: 1000.0))
    }

    let red = toRGB((clippedX * 3.2406) + (clippedY * -1.5372) + (clippedZ * -0.4986))
    let green = toRGB((clippedX * -0.9689) + (clippedY * 1.8758) + (clippedZ * 0.0415))
    let blue = toRGB((clippedX * 0.0557) + (clippedY * -0.2040) + (clippedZ * 1.0570))

    self.init(red: red, green: green, blue: blue, alpha: alpha)
  }

  var xyzComponents: (X: CGFloat, Y: CGFloat, Z: CGFloat) {
    let toSRGB = { (c: CGFloat) -> CGFloat in
      c > 0.04045 ? pow((c + 0.055) / 1.055, 2.4) : c / 12.92
    }

    let rgba = rgbaComponents
    let red = toSRGB(rgba.r)
    let green = toSRGB(rgba.g)
    let blue = toSRGB(rgba.b)

    let X = roundDecimal(
      ((red * 0.4124) + (green * 0.3576) + (blue * 0.1805)) * 100.0, precision: 1000.0
    )
    let Y = roundDecimal(
      ((red * 0.2126) + (green * 0.7152) + (blue * 0.0722)) * 100.0, precision: 1000.0
    )
    let Z = roundDecimal(
      ((red * 0.0193) + (green * 0.1192) + (blue * 0.9505)) * 100.0, precision: 1000.0
    )

    return (X: X, Y: Y, Z: Z)
  }
}

extension SystemColor {

  var hsbComponents: (h: CGFloat, s: CGFloat, b: CGFloat) {
    var h: CGFloat = 0.0
    var s: CGFloat = 0.0
    var b: CGFloat = 0.0

    #if os(iOS) || os(tvOS) || os(watchOS)
      getHue(&h, saturation: &s, brightness: &b, alpha: nil)

      return (h: h, s: s, b: b)
    #elseif os(macOS)
      if isEqual(SystemColor.black) {
        return (0.0, 0.0, 0.0)
      } else if isEqual(SystemColor.white) {
        return (0.0, 0.0, 1.0)
      }

      getHue(&h, saturation: &s, brightness: &b, alpha: nil)

      return (h: h, s: s, b: b)
    #endif
  }

  #if os(iOS) || os(tvOS) || os(watchOS)

    var hueComponent: CGFloat {
      return hsbComponents.h
    }

    var saturationComponent: CGFloat {
      return hsbComponents.s
    }

    var brightnessComponent: CGFloat {
      return hsbComponents.b
    }
  #endif
}

extension SystemColor {

  func mixed(
    withColor color: SystemColor, weight: CGFloat = 0.5,
    inColorSpace colorspace: SystemColorSpace = .rgb
  ) -> SystemColor {
    let normalizedWeight = clip(weight, 0.0, 1.0)

    switch colorspace {
    case .lab:
      return mixedLab(withColor: color, weight: normalizedWeight)
    case .hsl:
      return mixedHSL(withColor: color, weight: normalizedWeight)
    case .hsb:
      return mixedHSB(withColor: color, weight: normalizedWeight)
    case .rgb:
      return mixedRGB(withColor: color, weight: normalizedWeight)
    }
  }

  func tinted(amount: CGFloat = 0.2) -> SystemColor {
    return mixed(withColor: .white, weight: amount)
  }

  func shaded(amount: CGFloat = 0.2) -> SystemColor {
    return mixed(withColor: SystemColor(red: 0, green: 0, blue: 0, alpha: 1), weight: amount)
  }

  func mixedLab(withColor color: SystemColor, weight: CGFloat) -> SystemColor {
    let c1 = labComponents
    let c2 = color.labComponents

    let L = c1.L + (weight * (c2.L - c1.L))
    let a = c1.a + (weight * (c2.a - c1.a))
    let b = c1.b + (weight * (c2.b - c1.b))
    let alpha = alphaComponent + (weight * (color.alphaComponent - alphaComponent))

    return SystemColor(L: L, a: a, b: b, alpha: alpha)
  }

  func mixedHSL(withColor color: SystemColor, weight: CGFloat) -> SystemColor {
    let c1 = hslComponents
    let c2 = color.hslComponents

    let h = c1.h + (weight * mixedHue(source: c1.h, target: c2.h))
    let s = c1.s + (weight * (c2.s - c1.s))
    let l = c1.l + (weight * (c2.l - c1.l))
    let alpha = alphaComponent + (weight * (color.alphaComponent - alphaComponent))

    return SystemColor(hue: h, saturation: s, lightness: l, alpha: alpha)
  }

  func mixedHSB(withColor color: SystemColor, weight: CGFloat) -> SystemColor {
    let c1 = hsbComponents
    let c2 = color.hsbComponents

    let h = c1.h + (weight * mixedHue(source: c1.h, target: c2.h))
    let s = c1.s + (weight * (c2.s - c1.s))
    let b = c1.b + (weight * (c2.b - c1.b))
    let alpha = alphaComponent + (weight * (color.alphaComponent - alphaComponent))

    return SystemColor(hue: h, saturation: s, brightness: b, alpha: alpha)
  }

  func mixedRGB(withColor color: SystemColor, weight: CGFloat) -> SystemColor {
    let c1 = rgbaComponents
    let c2 = color.rgbaComponents

    let red = c1.r + (weight * (c2.r - c1.r))
    let green = c1.g + (weight * (c2.g - c1.g))
    let blue = c1.b + (weight * (c2.b - c1.b))
    let alpha = alphaComponent + (weight * (color.alphaComponent - alphaComponent))

    return SystemColor(red: red, green: green, blue: blue, alpha: alpha)
  }

  func mixedHue(source: CGFloat, target: CGFloat) -> CGFloat {
    if target > source && target - source > 180.0 {
      return target - source + 360.0
    } else if target < source && source - target > 180.0 {
      return target + 360.0 - source
    }

    return target - source
  }
}

extension Color {
  struct InvalidColorHexString: Error, CustomStringConvertible {
    init(_ description: String) {
      self.description = "Invalid color hex string: \(description)"
    }

    let description: String
  }

  init(hexString: String) {
    let hexString = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
    let scanner = Scanner(string: hexString)
    scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")

    var color: UInt64 = 0

    if scanner.scanHexInt64(&color) {
      self.init(hex: color, useOpacity: hexString.count > 7)
    } else {
      self.init(hex: 0x000000)
    }
  }

  init(validHexString: String) throws {
    let hexString = validHexString.trimmingCharacters(in: .whitespacesAndNewlines)
    let scanner = Scanner(string: hexString)
    scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")

    var color: UInt64 = 0

    if scanner.scanHexInt64(&color) {
      self.init(hex: color, useOpacity: hexString.count > 7)
    } else {
      throw InvalidColorHexString(validHexString)
    }
  }

  init(hex: UInt64, useOpacity opacityChannel: Bool = false) {
    let mask = UInt64(0xFF)
    let cappedHex = !opacityChannel && hex > 0xFFFFFF ? 0xFFFFFF : hex

    let r = cappedHex >> (opacityChannel ? 24 : 16) & mask
    let g = cappedHex >> (opacityChannel ? 16 : 8) & mask
    let b = cappedHex >> (opacityChannel ? 8 : 0) & mask
    let o = opacityChannel ? cappedHex & mask : 255

    let red = Double(r) / 255.0
    let green = Double(g) / 255.0
    let blue = Double(b) / 255.0
    let opacity = Double(o) / 255.0

    self.init(red: red, green: green, blue: blue, opacity: opacity)
  }
}

struct ColorModifier: ViewModifier {
  init(color: Color, into systemColor: Binding<SystemColor>) {
    _systemColor = systemColor
    self.color = color
  }

  @Binding var systemColor: SystemColor
  @State private var color: Color
  @State private var resolved: Color.Resolved = Color.clear.resolve(in: .init())
  @Environment(\.self) var environment
  func body(content: Content) -> some View {
    content.onChange(of: color, initial: true) {
      let resolved = color.resolve(in: environment)
      systemColor = .init(
        red: CGFloat(resolved.linearRed),
        green: CGFloat(resolved.linearGreen),
        blue: CGFloat(resolved.linearBlue),
        alpha: CGFloat(resolved.opacity)
      )
    }
  }
}

extension SystemColor {
  var swiftUIColor: Color {
    Color(self)
  }
}

struct WithResolvedColor<V: View>: View {
  init(color: Color, _ build: @escaping (_ color: Binding<SystemColor>) -> V) {
    self.color = color
    self.build = build
  }

  let build: (_ color: Binding<SystemColor>) -> V
  @State private var color: Color
  @State private var systemColor: SystemColor = .clear
  @Environment(\.self) var environment
  var body: some View {
    build($systemColor)
      .onChange(of: color, initial: true) {
        let resolved = color.resolve(in: environment)
        systemColor = .init(
          red: CGFloat(resolved.linearRed),
          green: CGFloat(resolved.linearGreen),
          blue: CGFloat(resolved.linearBlue),
          alpha: CGFloat(resolved.opacity)
        )
      }
  }
}

@available(iOS 17.0, tvOS 17.0, watchOS 10.0, macOS 14.0, *)
extension View {
  func resolveColor(color: Color, into systemColor: Binding<SystemColor>) -> some View {
    modifier(ColorModifier(color: color, into: systemColor))
  }
}
