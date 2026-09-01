import 'dart:math';

/// A random prefix minted once per isolate. Combined with a monotonic counter
/// it yields collision-free, opaque toast ids that are also safe across a hot
/// restart: a restarted isolate gets a fresh prefix, so it can never collide
/// with ids a stale native overlay might still be holding.
final String _sessionPrefix = _generateSessionPrefix();

int _toastCounter = 0;
int _actionCounter = 0;

String _generateSessionPrefix() {
  final rnd = Random();
  final hi = rnd.nextInt(0x7fffffff).toRadixString(36);
  final lo = rnd.nextInt(0x7fffffff).toRadixString(36);
  return '$hi$lo';
}

/// The per-isolate session prefix, sent to native in the handshake so the
/// platform side can detect and flush state left over from a previous run.
String get sessionPrefix => _sessionPrefix;

/// Mints a globally-unique (within this run) opaque toast id.
String nextToastId() =>
    'lt_${_sessionPrefix}_${(_toastCounter++).toString().padLeft(4, '0')}';

/// Mints an action id, unique within the toast it belongs to.
String nextActionId() => 'a${_actionCounter++}';
