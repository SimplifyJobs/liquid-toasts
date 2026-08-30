import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:meta/meta.dart';

import 'toast_position.dart';
import 'toast_style.dart';

/// What to drop when more toasts are queued than the stack can hold.
enum ToastDropPolicy { dropOldest, dropNewest }

/// App-wide defaults, applied via [LiquidToasts.setDefaults].
///
/// [defaultPosition], [defaultDuration], [defaultGlass], [maxLines] and
/// [titleMaxLines] are applied when an individual toast omits them.
/// [safeArea] reserves app-owned space in addition to the device geometry,
/// while [maxVisible], [maxQueue] and [dropPolicy] govern the native stack.
@immutable
class LiquidToastsConfig {
  const LiquidToastsConfig({
    this.defaultPosition = ToastPosition.topCenter,
    this.defaultDuration,
    this.defaultGlass = ToastGlass.adaptive,
    this.maxLines,
    this.titleMaxLines,
    this.safeArea = EdgeInsets.zero,
    this.maxVisible = 5,
    this.maxQueue = 8,
    this.dropPolicy = ToastDropPolicy.dropOldest,
  })  : assert(maxLines == null || maxLines > 0),
        assert(titleMaxLines == null || titleMaxLines > 0);

  final ToastPosition defaultPosition;

  /// Auto-dismiss duration applied when a call site omits `duration`. Null (the
  /// default) means "use the per-semantic defaults" (success/info/warning 3s,
  /// error 4s); a non-null value overrides them all uniformly.
  final Duration? defaultDuration;
  final ToastGlass defaultGlass;

  /// App-wide message line cap. Null keeps the semantic defaults (two lines
  /// for errors/warnings and one for other toasts). A per-toast `maxLines`
  /// value always wins.
  final int? maxLines;

  /// App-wide title line cap. Null keeps the one-line default. A per-toast
  /// `titleMaxLines` value always wins.
  final int? titleMaxLines;

  /// Minimum logical-pixel inset to keep clear at each screen edge.
  ///
  /// The real system safe area is always honored; native rendering takes the
  /// larger of the device inset and this value independently for each edge.
  /// This can reserve space occupied by an app header, floating control, or
  /// bottom navigation without double-counting the status bar/home indicator.
  final EdgeInsets safeArea;

  /// Max toasts shown per position (a vertical list). When a new toast would
  /// exceed this, the oldest **auto-dismiss** toast in that position is
  /// dismissed to make room.
  ///
  /// Persistent and loading toasts (those with no auto-dismiss duration —
  /// `duration: Duration.zero`/`null`, and `promise`/`loading` spinners) are
  /// exempt: they are caller- or promise-owned and are never force-dismissed by
  /// overflow. A position may therefore exceed [maxVisible] while it is full of
  /// such toasts; they leave only when you dismiss them (or the user does).
  final int maxVisible;

  /// Reserved upper bound on total tracked toasts.
  final int maxQueue;

  final ToastDropPolicy dropPolicy;

  /// Only the native-relevant knobs are sent over the channel.
  Map<String, Object?> toMap() => {
        'maxVisible': maxVisible,
        'maxQueue': maxQueue,
        'dropPolicy': dropPolicy.name,
        'defaultGlass': defaultGlass.name,
        'safeArea': {
          'left': safeArea.left,
          'top': safeArea.top,
          'right': safeArea.right,
          'bottom': safeArea.bottom,
        },
      };
}
