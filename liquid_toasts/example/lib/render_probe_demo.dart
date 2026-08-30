import 'package:flutter/material.dart';
import 'package:liquid_toasts/liquid_toasts.dart';

/// Render-isolation probe: shows three persistent toasts, then patches only
/// the middle one's progress ten times. With a temporary
/// `Self._printChanges()` in `ToastView.body`, the flutter log shows exactly
/// how many toast bodies re-render per patch — ~1 with row equality gating,
/// ~3+ without. Markers:
///
///   RENDERPROBE:SETTLED        stack is up and idle
///   RENDERPROBE:UPDATE-START   patches begin
///   RENDERPROBE:UPDATE-END     patches done
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: _Probe()));
}

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    toast.show('Toast A — static bystander', duration: null);
    final b = toast.show('Toast B — receives patches', duration: null, progress: 0);
    toast.show('Toast C — static bystander', duration: null);
    // Let entrances + measurement probes fully settle.
    await Future<void>.delayed(const Duration(seconds: 3));
    debugPrint('RENDERPROBE:SETTLED');
    await Future<void>.delayed(const Duration(seconds: 1));
    debugPrint('RENDERPROBE:UPDATE-START');
    for (var i = 1; i <= 10; i++) {
      await b.update(progress: i / 10);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    debugPrint('RENDERPROBE:UPDATE-END');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF12222E),
      body: Center(
        child: Text('render probe', style: TextStyle(color: Colors.white38)),
      ),
    );
  }
}
