import 'src/toaster.dart';

export 'src/liquid_toasts_config.dart';
export 'src/toast.dart';
export 'src/toast_action.dart';
export 'src/toast_event.dart';
export 'src/toast_handle.dart' show ToastHandle;
export 'src/toast_position.dart';
export 'src/toast_style.dart';
export 'src/toaster.dart' show Toaster;

/// The global toaster — the package's primary API:
///
/// ```dart
/// toast.success('Saved to favorites');
/// toast('Plain message');
/// final t = toast.show('Uploading…', duration: null, progress: 0);
/// t.update(progress: 0.6);
/// final user = await toast.promise(api.signIn(), loading: 'Signing in…');
/// ```
///
/// If the name collides with one of your identifiers,
/// `import 'package:liquid_toasts/liquid_toasts.dart' hide toast;` and use
/// [Toaster.instance] instead.
const Toaster toast = Toaster.instance;
