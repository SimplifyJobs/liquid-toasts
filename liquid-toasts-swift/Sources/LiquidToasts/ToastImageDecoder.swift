import UIKit

/// Off-main image decoding for the leading avatar. Previously the bytes were
/// decoded synchronously inside the method-channel call (blocking the main
/// thread on large sources); now decode — and, for big images, downsampling —
/// happens on a background task and the pixels are attached to the model when
/// ready.
enum ToastImageDecoder {
  /// Fully decodes [data]; sources meaningfully larger than the avatar slot
  /// are thumbnailed to ~3× the 26 pt slot (Retina headroom) so a photo-sized
  /// payload never lives in memory at full resolution. Returns nil for
  /// undecodable bytes.
  static func decode(_ data: Data) async -> UIImage? {
    guard let image = UIImage(data: data) else { return nil }
    let pixelMax = max(image.size.width, image.size.height) * image.scale
    let targetPoints = ToastMetrics.avatarSize * 3
    if pixelMax > 256 {
      let scale = targetPoints / max(image.size.width, image.size.height)
      let size = CGSize(width: image.size.width * scale,
                        height: image.size.height * scale)
      return await image.byPreparingThumbnail(ofSize: size) ?? image
    }
    // Small source: just force the decode off the render path.
    return await image.byPreparingForDisplay() ?? image
  }
}
