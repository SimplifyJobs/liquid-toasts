import 'package:flutter/material.dart';
import 'package:liquid_toasts/liquid_toasts.dart';

import 'demo_harness.dart';

/// Demo reel for app-wide title/message line limits and a custom top safe area.
/// The toast intentionally supplies neither per-toast line-limit value.
///
/// Record it: tool/record_demo.sh --target lib/safe_area_lines_demo.dart \
///   --prefix SAFE_LINES --crop-height 920 --contact
void main() {
  runDemoReel(
    prefix: 'SAFE_LINES',
    overlay: const _ReservedHeader(),
    previews: {'global-defaults-and-safe-area': _showFeatureToast},
  );
}

Future<void> _showFeatureToast() async {
  await toast.setDefaults(const LiquidToastsConfig(
    maxLines: 3,
    titleMaxLines: 2,
    safeArea: EdgeInsets.only(top: 132),
  ));

  toast.success(
    'Everyone on the release team can now review the final build, notes, and '
    'rollout checklist before it goes live tomorrow morning.',
    title: 'Your scheduled release is ready for review',
    icon: 'checkmark.seal.fill',
    duration: const Duration(milliseconds: 6200),
  );
  await Future<void>.delayed(const Duration(milliseconds: 7500));
}

class _ReservedHeader extends StatelessWidget {
  const _ReservedHeader();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          color: const Color(0xA60D1117),
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(22, 58, 18, 14),
        child: Row(
          children: [
            const Icon(Icons.layers_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESERVED APP HEADER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Custom safe area · 132 px',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'TITLE 2\nMESSAGE 3',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
