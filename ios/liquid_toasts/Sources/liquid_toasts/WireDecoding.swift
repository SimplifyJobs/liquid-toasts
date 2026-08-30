import CoreGraphics
import Foundation

/// Primitive decoding helpers for method-channel payloads. `StandardMessageCodec`
/// bridges Dart ints/doubles/bools as `NSNumber`, so plain `as?` casts on the
/// primitive types are unreliable — always go through these.
///
/// Bridge-side only (the models in `Models.swift` are Flutter-free); the model
/// decoders that build on these live in `WireModels.swift`.
extension Dictionary where Key == String, Value == Any {
  func int(_ key: String) -> Int? {
    if let n = self[key] as? NSNumber { return n.intValue }
    return self[key] as? Int
  }

  func double(_ key: String) -> Double? {
    if let n = self[key] as? NSNumber { return n.doubleValue }
    return self[key] as? Double
  }

  func cgFloat(_ key: String) -> CGFloat? {
    double(key).map { CGFloat($0) }
  }

  func bool(_ key: String, default defaultValue: Bool) -> Bool {
    if let n = self[key] as? NSNumber { return n.boolValue }
    return self[key] as? Bool ?? defaultValue
  }

  func string(_ key: String) -> String? { self[key] as? String }

  /// Decodes a wire enum (Dart `.name` string) with a fallback.
  func enumValue<E: RawRepresentable>(_ key: String, default defaultValue: E) -> E
  where E.RawValue == String {
    (self[key] as? String).flatMap(E.init(rawValue:)) ?? defaultValue
  }

  /// Decodes an optional wire enum (nil when absent or unknown).
  func enumValue<E: RawRepresentable>(_ key: String) -> E?
  where E.RawValue == String {
    (self[key] as? String).flatMap(E.init(rawValue:))
  }
}
