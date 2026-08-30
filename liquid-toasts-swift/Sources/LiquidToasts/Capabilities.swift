/// Value-level runtime capability checks.
///
/// NOTE: these are for *values* (wire strings, branching on data). Call sites
/// that USE availability-gated APIs (`glassEffect`, `.drawOn`, iOS 18 symbol
/// effects) must keep their `#if compiler(>=6.2)` / `if #available(...)`
/// blocks — the compiler requires syntactic availability there, and the
/// `#if compiler(...)` guard keeps the package building on older Xcode
/// toolchains that don't know the newer SDKs at all.
public enum Capabilities {
  /// Whether the OS renders native Liquid Glass (iOS 26+).
  public static var hasLiquidGlass: Bool {
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) { return true }
    #endif
    return false
  }

  /// The wire string advertised to Dart for the active glass implementation:
  /// `"liquidGlass"` or `"frosted"`.
  public static var glassModeString: String { hasLiquidGlass ? "liquidGlass" : "frosted" }
}
