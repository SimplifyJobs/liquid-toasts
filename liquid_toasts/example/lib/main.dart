import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_toasts/liquid_toasts.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid Toasts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _replaceCount = 0;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// A pretend async unit of work that succeeds after [ms] or throws.
  Future<String> _fakeWork({int ms = 2500, bool fail = false}) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    if (fail) throw Exception('Network unreachable');
    return 'OK';
  }

  /// Draws a square gradient tile with centered initials and returns PNG bytes.
  /// The native side clips it to a circle, so the square fills the avatar.
  Future<Uint8List> _avatar(String initials, List<Color> colors) async {
    const size = 120.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const rect = Rect.fromLTWH(0, 0, size, size);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 52,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  // ---------------------------------------------------------------------------
  // Toast triggers
  // ---------------------------------------------------------------------------

  void _titledMessage() {
    toast.success(
      'Your changes have been published and are now live.',
      title: 'Published',
      duration: const Duration(seconds: 4),
    );
  }

  void _multiline() {
    toast.error(
      'We couldn’t reach the server. Check your connection and try again in a '
      'few moments — your work has been saved locally.',
      title: 'Sync failed',
      maxLines: 3,
      duration: const Duration(seconds: 5),
    );
  }

  void _customIcon() {
    toast(
      'You have 3 new notifications',
      icon: 'bell.fill',
      style: const ToastStyleOverride(symbolEffect: ToastSymbolEffect.bounce),
    );
  }

  void _sparklesIcon() {
    toast(
      'Magic applied ✨',
      icon: 'sparkles',
      style: const ToastStyleOverride(symbolEffect: ToastSymbolEffect.pulse),
    );
  }

  void _undoAction() {
    toast(
      'Conversation archived',
      icon: 'archivebox.fill',
      duration: const Duration(seconds: 5),
      action: ToastAction(
        label: 'Undo',
        role: ToastActionRole.primary,
        // dismissOnPress defaults to true — tapping removes the toast.
        onPressed: () => toast.info('Restored to Inbox'),
      ),
    );
  }

  void _asyncAction() {
    toast.raw(Toast(
      message: 'Save changes to your profile?',
      icon: 'square.and.pencil',
      duration: null,
      action: ToastAction(
        label: 'Save',
        role: ToastActionRole.success,
        loadingOnPress: true, // spinner until onPressed resolves, then dismiss
        onPressed: () => _fakeWork(ms: 2000),
      ),
    ));
  }

  Future<void> _promiseSuccess() async {
    await toast.promise<String>(
      _fakeWork(),
      loading: 'Syncing your library…',
      success: 'Library synced',
    );
  }

  Future<void> _promiseError() async {
    try {
      await toast.promise<String>(
        _fakeWork(fail: true),
        loading: 'Uploading…',
        error: 'Upload failed',
      );
    } catch (_) {
      // The failure is surfaced by the toast; swallow the rethrow here.
    }
  }

  Future<void> _progressLinear() async {
    final handle = toast.raw(const Toast(
      title: 'Downloading',
      message: 'season-2.zip',
      icon: 'arrow.down.circle',
      duration: null,
      progress: 0,
    ));
    for (var p = 1; p <= 10; p++) {
      await Future<void>.delayed(const Duration(milliseconds: 240));
      await handle.update(progress: p / 10);
    }
    await handle.replace(const Toast(
      message: 'Download complete',
      icon: 'checkmark.circle.fill',
      semantic: ToastSemantic.success,
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _progressCircular() async {
    final handle = toast.raw(const Toast(
      message: 'Downloading update',
      duration: null,
      progress: 0,
      progressStyle: ToastProgressStyle.circular,
    ));
    for (var p = 1; p <= 10; p++) {
      await Future<void>.delayed(const Duration(milliseconds: 240));
      await handle.update(progress: p / 10);
    }
    await handle.replace(const Toast(
      message: 'Up to date',
      icon: 'checkmark.circle.fill',
      semantic: ToastSemantic.success,
      duration: Duration(seconds: 2),
    ));
  }

  void _atPosition(ToastPosition position, String label) {
    toast(
      label,
      icon: 'location.fill',
      position: position,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _stackThree() async {
    for (var i = 1; i <= 3; i++) {
      toast.info(
        'Notification #$i',
        position: ToastPosition.bottomCenter,
        duration: const Duration(seconds: 3),
      );
      await Future<void>.delayed(const Duration(milliseconds: 260));
    }
  }

  void _groupKeyReplace() {
    _replaceCount++;
    toast.info(
      'Tapped $_replaceCount time(s)',
      icon: 'hand.tap.fill',
      groupKey: 'counter',
      duration: const Duration(seconds: 4),
    );
  }

  void _persistent() {
    toast.raw(const Toast(
      title: 'Connecting…',
      message: 'Waiting for the network',
      icon: 'wifi',
      duration: null, // persistent — clear it with "Dismiss all"
    ));
  }

  Future<void> _avatarToast() async {
    final bytes =
        await _avatar('AR', const [Color(0xFF7C3AED), Color(0xFF4F46E5)]);
    toast.raw(Toast(
      title: 'Alex Rivera',
      message: 'sent you a message',
      leadingImage: MemoryImage(bytes),
      duration: const Duration(seconds: 4),
    ));
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liquid Toasts')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const _Section('Semantics'),
          _Btn('Plain', () => toast('Copied to clipboard')),
          _Btn('Success', () => toast.success('Saved to favorites')),
          _Btn('Error', () => toast.error('Could not connect')),
          _Btn('Warning', () => toast.warning('Low storage')),
          _Btn('Info', () => toast.info('3 updates available')),
          const _Section('Content'),
          _Btn('Title + message', _titledMessage),
          _Btn('Long multiline (maxLines 3)', _multiline),
          _Btn('Custom icon — bell.fill', _customIcon),
          _Btn('Custom icon — sparkles', _sparklesIcon),
          _Btn('Avatar image', _avatarToast),
          const _Section('Actions'),
          _Btn('Undo (dismiss on press)', _undoAction),
          _Btn('Async action (loading on press)', _asyncAction),
          const _Section('Loading / promise'),
          _Btn('Promise → success', _promiseSuccess),
          _Btn('Promise → error', _promiseError),
          const _Section('Progress'),
          _Btn('Linear download', _progressLinear),
          _Btn('Circular download', _progressCircular),
          const _Section('Positions'),
          _PositionGrid(onPick: _atPosition),
          const _Section('Stacking & replace'),
          _Btn('Show 3 stacked (bottom)', _stackThree),
          _Btn('groupKey replace (tap repeatedly)', _groupKeyReplace),
          _Btn('Persistent toast', _persistent),
          const _Section('Bulk'),
          _Btn('Dismiss all', () => toast.dismissAll()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6, left: 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                letterSpacing: 0.4,
              ),
        ),
      );
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// A compact 3x3 grid mirroring the [ToastPosition] anchors on screen.
class _PositionGrid extends StatelessWidget {
  const _PositionGrid({required this.onPick});

  final void Function(ToastPosition position, String label) onPick;

  static const _cells = <(ToastPosition?, String)>[
    (ToastPosition.topLeading, 'Top\nleading'),
    (ToastPosition.topCenter, 'Top\ncenter'),
    (ToastPosition.topTrailing, 'Top\ntrailing'),
    (null, ''),
    (ToastPosition.center, 'Center'),
    (null, ''),
    (ToastPosition.bottomLeading, 'Bottom\nleading'),
    (ToastPosition.bottomCenter, 'Bottom\ncenter'),
    (ToastPosition.bottomTrailing, 'Bottom\ntrailing'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final (position, label) in _cells)
          if (position == null)
            const SizedBox.shrink()
          else
            OutlinedButton(
              onPressed: () => onPick(position, label.replaceAll('\n', ' ')),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
              ),
              child: Text(label, textAlign: TextAlign.center),
            ),
      ],
    );
  }
}
