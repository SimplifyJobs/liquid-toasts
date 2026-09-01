import 'package:flutter/material.dart';
import 'package:liquid_toasts/liquid_toasts.dart';

/// Probe for the wall-clock auto-dismiss behaviors that must survive
/// backgrounding. Not a demo reel — it prints machine-readable markers and is
/// driven externally with `simctl` (background the app by launching another
/// app, foreground it with `simctl launch`):
///
///   `BGPROBE:READY`                     app is up
///   `BGPROBE:SHOWN:<n>`                 toast n shown
///   `BGPROBE:DISMISSED:<n>:<reason>`    toast n resolved, with its wire reason
///
/// Scenario A: a 5 s toast backgrounded for ~7 s must resolve
/// `appBackgrounded` on foregrounding (deadline passed while away).
/// Scenario B: a 10 s toast backgrounded for ~3 s must survive the trip and
/// later resolve `timeout` at its original wall-clock deadline.
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
    debugPrint('BGPROBE:READY');
    final a = toast.show('A: 5s toast — gets backgrounded past its deadline',
        duration: const Duration(seconds: 5));
    debugPrint('BGPROBE:SHOWN:a');
    final ra = await a.onDismissed;
    debugPrint('BGPROBE:DISMISSED:a:${ra.name}');

    final b = toast.show('B: 10s toast — survives a short background trip',
        duration: const Duration(seconds: 10));
    debugPrint('BGPROBE:SHOWN:b');
    final rb = await b.onDismissed;
    debugPrint('BGPROBE:DISMISSED:b:${rb.name}');
    debugPrint('BGPROBE:COMPLETE');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF12222E),
      body: Center(
        child: Text('bg probe', style: TextStyle(color: Colors.white38)),
      ),
    );
  }
}
