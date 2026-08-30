import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_toasts/liquid_toasts.dart';

/// Recording harness for the README showcase clips, which live at the repo
/// root in `assets/showcase/*.mp4`.
///
/// It paints a full-bleed iOS wallpaper — so the Liquid Glass toasts have
/// something to refract — under a white status bar with no other chrome, then
/// plays each preview once, separated by clean wallpaper-only gaps so a single
/// screen recording can be sliced into one clip per preview.
///
/// Regenerate the clips (from `liquid_toasts/example/`):
///   1. flutter run -t lib/showcase.dart                  # on an iOS 26+ sim
///   2. xcrun simctl io booted recordVideo demo.mov       # ⌃C when it ends
///   3. ffmpeg -i demo.mov -vf fps=30 cfr.mp4             # VFR → constant fps
///   4. slice each preview, cropping to the top of the screen:
///      ffmpeg -i cfr.mp4 -ss START -t DURATION \
///        -vf "crop=1206:1150:0:0,scale=640:-2" \
///        -c:v libx264 -pix_fmt yuv420p -movflags +faststart -an out.mp4
///
/// The `SHOWCASE:<name>:START/END` log lines mark each preview's bounds to help
/// pick the `-ss`/`-t` window for step 4.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const ShowcaseApp());
}

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ShowcaseStage(),
    );
  }
}

class ShowcaseStage extends StatefulWidget {
  const ShowcaseStage({super.key});

  @override
  State<ShowcaseStage> createState() => _ShowcaseStageState();
}

class _ShowcaseStageState extends State<ShowcaseStage> {
  /// Wallpaper-only pause between previews — gives each sliced clip a clean
  /// lead-in and tail.
  static const _gap = Duration(milliseconds: 1800);

  /// How long a finished preview lingers before it's cleared.
  static const _hold = Duration(milliseconds: 1400);

  /// The previews, in the order they're played (and presented in the README).
  late final _previews = <String, Future<void> Function()>{
    'stacking': _stacking,
    'variable-color': _variableColor,
    'progress': _progress,
    'action': _action,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runReel());
  }

  Future<void> _runReel() async {
    await Future<void>.delayed(const Duration(seconds: 2)); // settle on launch
    for (final entry in _previews.entries) {
      await _clean();
      debugPrint('SHOWCASE:${entry.key}:START');
      await entry.value();
      debugPrint('SHOWCASE:${entry.key}:END');
    }
    await _clean();
    debugPrint('SHOWCASE:DONE');
  }

  Future<void> _clean() async {
    await toast.dismissAll();
    await Future<void>.delayed(_gap);
  }

  // 1. Several notifications stacking in with a small delay. Person mentions
  //    carry no icon; non-person notifications use an SF Symbol.
  Future<void> _stacking() async {
    const items = <(String, String?)>[
      ('Alex is online', null),
      ('Doom is online', null),
      ('Update is available', 'arrow.down.circle.fill'),
      ('New email', 'envelope.fill'),
    ];
    for (final (message, icon) in items) {
      toast.raw(
        Toast(
          message: message,
          icon: icon,
          duration: const Duration(milliseconds: 3500),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 520));
    }
    await Future<void>.delayed(const Duration(milliseconds: 4200) + _hold);
  }

  // 2. Variable-color SF Symbol effect on the Wi-Fi glyph.
  Future<void> _variableColor() async {
    toast.raw(
      Toast(
        message: 'Trying to rejoin',
        icon: 'wifi',
        style: const ToastStyleOverride(
          symbolEffect: ToastSymbolEffect.variableColor,
        ),
        duration: const Duration(milliseconds: 3800),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 3800) + _hold);
  }

  // 3. Upload with a determinate progress bar.
  Future<void> _progress() async {
    final handle = toast.raw(
      const Toast(
        message: 'Uploading 0%',
        icon: 'arrow.up.circle',
        duration: null,
        progress: 0,
      ),
    );
    for (var p = 1; p <= 10; p++) {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      await handle.replace(
        Toast(
          message: 'Uploading ${p * 10}%',
          icon: 'arrow.up.circle',
          duration: null,
          progress: p / 10,
        ),
      );
    }
    await handle.replace(
      const Toast(
        message: 'Upload complete',
        icon: 'checkmark.circle.fill',
        semantic: ToastSemantic.success,
        duration: Duration(seconds: 2),
        progress: 1,
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2) + _hold);
  }

  // 4. Action button with an inline Undo.
  Future<void> _action() async {
    final handle = toast.raw(
      Toast(
        message: 'Moved to trash',
        icon: 'trash.fill',
        duration: null,
        action: ToastAction(
          label: 'Undo',
          role: ToastActionRole.primary,
          onPressed: () {},
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 3800));
    await handle.dismiss();
    await Future<void>.delayed(_hold);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SizedBox.expand(
          child: Image.asset('assets/wallpaper.jpg', fit: BoxFit.cover),
        ),
      ),
    );
  }
}
