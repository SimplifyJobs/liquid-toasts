import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_toasts/liquid_toasts.dart';

/// A single named preview in a demo reel: it shows toast(s) and awaits however
/// long they should stay on screen. Clearing the screen between previews is
/// handled by the reel runner, so a preview just needs to show and wait.
typedef DemoPreview = Future<void> Function();

/// Boots a full-screen "reel" used to record demo videos (see
/// `tool/record_demo.sh`). Writing a new demo is just a map of name → preview.
///
/// It paints a full-bleed [wallpaper] (so the Liquid Glass toasts have
/// something to refract) under a light status bar with no other chrome, waits a
/// beat to [settle], then plays each entry of [previews] in order, separated by
/// a clean wallpaper-only [gap].
///
/// Around the reel it prints the log markers the recorder keys off:
///
///   `<prefix>:<name>:START`   `<prefix>:<name>:END`   …   `<prefix>:DONE`
///
/// The recorder waits for the first `<prefix>:DONE` (build is good, screen is
/// clean), starts recording, hot-restarts to replay, and stops at the second
/// `<prefix>:DONE`. Keeping the marker contract here means new demos need zero
/// recorder changes.
///
/// Tip: a message only wraps to the native multiline layout when its `maxLines`
/// is ≥ 2 — a long message with the default `maxLines: 1` still truncates to a
/// single-line capsule.
void runDemoReel({
  required String prefix,
  required Map<String, DemoPreview> previews,
  String wallpaper = 'assets/wallpaper.jpg',
  Widget? overlay,
  Duration settle = const Duration(seconds: 2),
  Duration gap = const Duration(milliseconds: 1800),
}) {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(_DemoReelApp(
    prefix: prefix,
    previews: previews,
    wallpaper: wallpaper,
    overlay: overlay,
    settle: settle,
    gap: gap,
  ));
}

class _DemoReelApp extends StatelessWidget {
  const _DemoReelApp({
    required this.prefix,
    required this.previews,
    required this.wallpaper,
    required this.overlay,
    required this.settle,
    required this.gap,
  });

  final String prefix;
  final Map<String, DemoPreview> previews;
  final String wallpaper;
  final Widget? overlay;
  final Duration settle;
  final Duration gap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _DemoReelStage(
        prefix: prefix,
        previews: previews,
        wallpaper: wallpaper,
        overlay: overlay,
        settle: settle,
        gap: gap,
      ),
    );
  }
}

class _DemoReelStage extends StatefulWidget {
  const _DemoReelStage({
    required this.prefix,
    required this.previews,
    required this.wallpaper,
    required this.overlay,
    required this.settle,
    required this.gap,
  });

  final String prefix;
  final Map<String, DemoPreview> previews;
  final String wallpaper;
  final Widget? overlay;
  final Duration settle;
  final Duration gap;

  @override
  State<_DemoReelStage> createState() => _DemoReelStageState();
}

class _DemoReelStageState extends State<_DemoReelStage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runReel());
  }

  Future<void> _runReel() async {
    await Future<void>.delayed(widget.settle); // settle on launch / restart
    for (final entry in widget.previews.entries) {
      await _clean();
      debugPrint('${widget.prefix}:${entry.key}:START');
      await entry.value();
      debugPrint('${widget.prefix}:${entry.key}:END');
    }
    await _clean();
    debugPrint('${widget.prefix}:DONE');
  }

  Future<void> _clean() async {
    await toast.dismissAll();
    await Future<void>.delayed(widget.gap);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(widget.wallpaper, fit: BoxFit.cover),
            if (widget.overlay != null) widget.overlay!,
          ],
        ),
      ),
    );
  }
}
