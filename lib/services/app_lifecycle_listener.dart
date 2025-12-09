import 'package:flutter/widgets.dart';

/// Small helper that turns the global WidgetsBinding lifecycle callbacks
/// into simple callbacks. Keeps a reference so callers can `dispose()` it.
class AppLifecycleObserver with WidgetsBindingObserver {
  final VoidCallback? onShow;
  final VoidCallback? onHide;
  final VoidCallback? onResume;
  final VoidCallback? onPause;

  AppLifecycleObserver({this.onShow, this.onHide, this.onResume, this.onPause}) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      switch (state) {
        case AppLifecycleState.resumed:
          onResume?.call();
          onShow?.call();
          break;
        case AppLifecycleState.inactive:
        case AppLifecycleState.paused:
          onPause?.call();
          onHide?.call();
          break;
        case AppLifecycleState.detached:
          onHide?.call();
          break;
        default:
          // handle any platform-specific or future states
          break;
      }
    } catch (_) {
      // swallowing callback errors here — callers should handle their own errors
    }
  }

  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
  }
}
