import 'dart:typed_data' show Uint8List;
import 'dart:ui' show VoidCallback;

import 'package:flutter/painting.dart' show ImageProvider;
import 'package:meta/meta.dart';

import 'semantic_defaults.dart';
import 'toast_action.dart';
import 'toast_position.dart';
import 'toast_style.dart';

/// An immutable description of a toast.
///
/// A pure value type — no [BuildContext], no platform handles — so it is safe to
/// construct anywhere (services, blocs, isolated business logic). Use the named
/// constructors ([Toast.success], [Toast.error], [Toast.warning], [Toast.info],
/// [Toast.loading]) for ergonomics, or the default constructor for full control.
@immutable
class Toast {
  /// Canonical constructor — every other constructor funnels through this so
  /// the field list exists in exactly one place.
  const Toast._raw({
    required this.message,
    this.title,
    this.icon,
    this.leadingImage,
    this.semantic = ToastSemantic.none,
    this.style,
    this.position,
    this.duration,
    this.action,
    this.useDynamicIslandOrigin = true,
    this.onTap,
    this.tapToDismiss = true,
    this.groupKey,
    this.progress,
    this.progressStyle = ToastProgressStyle.linear,
    this.haptic,
    this.semanticsLabel,
    this._maxLines,
    this._titleMaxLines,
    required this.loading,
  });

  const Toast({
    required String message,
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastSemantic semantic = ToastSemantic.none,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration = const Duration(seconds: 3),
    ToastAction? action,
    bool useDynamicIslandOrigin = true,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
  }) : this._raw(
          message: message,
          title: title,
          icon: icon,
          leadingImage: leadingImage,
          semantic: semantic,
          style: style,
          position: position,
          duration: duration,
          action: action,
          useDynamicIslandOrigin: useDynamicIslandOrigin,
          onTap: onTap,
          tapToDismiss: tapToDismiss,
          groupKey: groupKey,
          progress: progress,
          progressStyle: progressStyle,
          haptic: haptic,
          semanticsLabel: semanticsLabel,
          maxLines: maxLines,
          titleMaxLines: titleMaxLines,
          loading: false,
        );

  /// A persistent spinner toast. Typically created for you by
  /// [LiquidToasts.showLoading], but also usable directly for a manual
  /// loading state you later [ToastHandle.update] or [ToastHandle.dismiss].
  const Toast.loading({
    required String message,
    String? title,
    String? icon,
    ToastStyleOverride? style,
    ToastPosition? position,
    bool useDynamicIslandOrigin = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
  }) : this._raw(
          message: message,
          title: title,
          icon: icon,
          style: style,
          position: position,
          useDynamicIslandOrigin: useDynamicIslandOrigin,
          groupKey: groupKey,
          progress: progress,
          progressStyle: progressStyle,
          semanticsLabel: semanticsLabel,
          maxLines: maxLines,
          titleMaxLines: titleMaxLines,
          tapToDismiss: false,
          loading: true,
        );

  /// Shared body of the semantic factories: the ONLY place a semantic
  /// convenience [Toast] is assembled. Per-semantic defaults come from
  /// [SemanticDefaults].
  factory Toast._semantic(
    ToastSemantic semantic, {
    required String message,
    required String? title,
    required String? icon,
    required ImageProvider? leadingImage,
    required ToastStyleOverride? style,
    required ToastPosition? position,
    required Duration? duration,
    required ToastAction? action,
    required VoidCallback? onTap,
    required bool tapToDismiss,
    required bool useDynamicIslandOrigin,
    required String? groupKey,
    required double? progress,
    required ToastProgressStyle progressStyle,
    required ToastHaptic? haptic,
    required String? semanticsLabel,
    required int? maxLines,
    required int? titleMaxLines,
  }) =>
      Toast._raw(
        message: message,
        title: title,
        icon: icon,
        leadingImage: leadingImage,
        semantic: semantic,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
        loading: false,
      );

  factory Toast.success({
    required String message,
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration = SemanticDefaults.successDuration,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    bool useDynamicIslandOrigin = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
  }) =>
      Toast._semantic(
        ToastSemantic.success,
        message: message,
        title: title,
        icon: icon,
        leadingImage: leadingImage,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
      );

  factory Toast.error({
    required String message,
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration = SemanticDefaults.errorDuration,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    bool useDynamicIslandOrigin = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
  }) =>
      Toast._semantic(
        ToastSemantic.error,
        message: message,
        title: title,
        icon: icon,
        leadingImage: leadingImage,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
      );

  factory Toast.warning({
    required String message,
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration = SemanticDefaults.warningDuration,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    bool useDynamicIslandOrigin = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
  }) =>
      Toast._semantic(
        ToastSemantic.warning,
        message: message,
        title: title,
        icon: icon,
        leadingImage: leadingImage,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
      );

  factory Toast.info({
    required String message,
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration = SemanticDefaults.infoDuration,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    bool useDynamicIslandOrigin = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
  }) =>
      Toast._semantic(
        ToastSemantic.info,
        message: message,
        title: title,
        icon: icon,
        leadingImage: leadingImage,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        titleMaxLines: titleMaxLines,
      );

  /// Primary line. Truncated to [maxLines] natively.
  final String message;

  /// Optional bold line above [message].
  final String? title;

  /// SF Symbol name (e.g. `'checkmark.circle.fill'`). When null, the symbol is
  /// derived from [semantic] natively. An explicit value wins.
  final String? icon;

  /// A raster image shown in the leading slot (a circular avatar / thumbnail),
  /// in place of the SF Symbol. Any Flutter [ImageProvider] works
  /// (`AssetImage`, `NetworkImage`, `MemoryImage`, …); it's resolved to bytes on
  /// the Dart side and handed to the native renderer, so the usual Flutter image
  /// pipeline (and its caching) applies. Wins over [icon] when set.
  final ImageProvider? leadingImage;

  final ToastSemantic semantic;
  final ToastStyleOverride? style;

  /// Where the toast anchors. `null` ⇒ the app-wide default
  /// ([LiquidToastsConfig.defaultPosition]), resolved at show time.
  final ToastPosition? position;

  /// `null` or [Duration.zero] ⇒ persistent (requires explicit dismissal).
  final Duration? duration;

  /// At most one action button.
  final ToastAction? action;

  /// Honored only for [ToastPosition.topCenter] on Dynamic Island devices.
  /// Set false to keep top-center placement but use a plain slide-in.
  final bool useDynamicIslandOrigin;

  /// Tapping the toast body invokes this (in addition to any [tapToDismiss]).
  final VoidCallback? onTap;

  /// Whether tapping the toast body dismisses it.
  final bool tapToDismiss;

  /// De-dup / replace key. Showing a toast whose [groupKey] matches a live one
  /// replaces it in place (morph) instead of stacking a duplicate.
  final String? groupKey;

  /// Determinate progress 0.0–1.0 for upload-style toasts. Null ⇒ no bar.
  final double? progress;

  /// How [progress] renders — a linear bar under the text or a circular ring in
  /// the leading slot. Ignored when [progress] is null.
  final ToastProgressStyle progressStyle;

  /// Haptic fired on appear. Null ⇒ derived from [semantic].
  final ToastHaptic? haptic;

  /// VoiceOver label. Falls back to `title` + `message` natively.
  final String? semanticsLabel;

  /// Explicit message line limit, if supplied. Kept private so the public
  /// [maxLines] getter remains non-null while the engine can still distinguish
  /// an omitted value from an explicit per-toast override.
  final int? _maxLines;

  /// Max lines for [message] before truncation. Before the toast is shown this
  /// exposes the semantic fallback; at show time an app-wide value may replace
  /// that fallback.
  int get maxLines => _maxLines ?? SemanticDefaults.maxLinesFor(semantic);

  final int? _titleMaxLines;

  /// Max lines the [title] wraps to before truncating (default 1). At show time
  /// an app-wide value may replace that fallback.
  int get titleMaxLines => _titleMaxLines ?? 1;

  /// True for a persistent spinner toast.
  final bool loading;

  bool get isPersistent =>
      loading || duration == null || duration == Duration.zero;

  /// A copy with the given fields replaced. Null means "keep the current
  /// value" — to *clear* a nullable field (title, action, progress, …), build a
  /// fresh [Toast] instead (e.g. via [ToastHandle.replace]). To make a copy
  /// persistent, pass `duration: Duration.zero`.
  Toast copyWith({
    String? message,
    String? title,
    String? icon,
    ImageProvider? leadingImage,
    ToastSemantic? semantic,
    ToastStyleOverride? style,
    ToastPosition? position,
    Duration? duration,
    ToastAction? action,
    bool? useDynamicIslandOrigin,
    VoidCallback? onTap,
    bool? tapToDismiss,
    String? groupKey,
    double? progress,
    ToastProgressStyle? progressStyle,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int? maxLines,
    int? titleMaxLines,
    bool? loading,
  }) =>
      Toast._raw(
        message: message ?? this.message,
        title: title ?? this.title,
        icon: icon ?? this.icon,
        leadingImage: leadingImage ?? this.leadingImage,
        semantic: semantic ?? this.semantic,
        style: style ?? this.style,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        action: action ?? this.action,
        useDynamicIslandOrigin:
            useDynamicIslandOrigin ?? this.useDynamicIslandOrigin,
        onTap: onTap ?? this.onTap,
        tapToDismiss: tapToDismiss ?? this.tapToDismiss,
        groupKey: groupKey ?? this.groupKey,
        progress: progress ?? this.progress,
        progressStyle: progressStyle ?? this.progressStyle,
        haptic: haptic ?? this.haptic,
        semanticsLabel: semanticsLabel ?? this.semanticsLabel,
        maxLines: maxLines ?? _maxLines,
        titleMaxLines: titleMaxLines ?? _titleMaxLines,
        loading: loading ?? this.loading,
      );

  /// Resolves inherited line limits without exposing nullable public fields.
  /// Per-toast values win, followed by app-wide values and semantic fallbacks.
  @internal
  Toast resolveLineLimits({int? maxLines, int? titleMaxLines}) => copyWith(
        maxLines:
            _maxLines ?? maxLines ?? SemanticDefaults.maxLinesFor(semantic),
        titleMaxLines: _titleMaxLines ?? titleMaxLines ?? 1,
      );

  /// Wire format. [actionId] is the id minted for [action] (omit when there is
  /// no action). Colors serialize as `{light,dark}` maps; durations as ms.
  Map<String, Object?> toMap({String? actionId, Uint8List? imageBytes}) => {
        'message': message,
        if (title != null) 'title': title,
        if (icon != null) 'icon': icon,
        'image': ?imageBytes,
        'semantic': semantic.name,
        if (style != null) 'style': style!.toMap(semantic: semantic),
        'position': (position ?? ToastPosition.topCenter).name,
        'state': loading ? 'loading' : 'static',
        'persistent': isPersistent,
        if (!isPersistent) 'durationMs': duration!.inMilliseconds,
        'useDynamicIslandOrigin': useDynamicIslandOrigin,
        if (progress != null) 'progress': progress,
        if (progress != null) 'progressStyle': progressStyle.name,
        if (groupKey != null) 'groupKey': groupKey,
        'haptic':
            (haptic ?? SemanticDefaults.hapticFor(semantic, loading: loading))
                .name,
        if (semanticsLabel != null) 'semanticsLabel': semanticsLabel,
        'maxLines': maxLines,
        'titleMaxLines': titleMaxLines,
        'tapToDismiss': tapToDismiss,
        'hasTap': onTap != null,
        if (action != null) 'action': action!.toMap(actionId ?? 'a0'),
      };
}
