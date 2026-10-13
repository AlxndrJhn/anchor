import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Settled: fully in, on top, nothing moving over it, the keyboard down.
class PageSettledBuilder extends StatefulWidget {
  const PageSettledBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool settled) builder;

  @override
  State<PageSettledBuilder> createState() => _PageSettledBuilderState();
}

class _PageSettledBuilderState extends State<PageSettledBuilder> {
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    _listen(false);
    _route = route;
    _listen(true);
  }

  @override
  void dispose() {
    _listen(false);
    super.dispose();
  }

  void _listen(bool isListening) {
    for (final animation in [_route?.animation, _route?.secondaryAnimation]) {
      if (animation == null) continue;
      isListening
          ? animation.addStatusListener(_changed)
          : animation.removeStatusListener(_changed);
    }
  }

  void _changed(AnimationStatus _) {
    if (mounted) setState(() {});
  }

  bool get _settled {
    final route = _route;
    if (route == null) return true;
    final animation = route.animation?.status ?? AnimationStatus.completed;
    final secondary =
        route.secondaryAnimation?.status ?? AnimationStatus.dismissed;
    return route.isCurrent &&
        animation == AnimationStatus.completed &&
        secondary == AnimationStatus.dismissed;
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _settled &&
        !(PageCoverScope.maybeOf(context)?.value ?? false) &&
        MediaQuery.viewInsetsOf(context).bottom == 0,
  );
}

class PageCoverScope extends InheritedNotifier<ValueListenable<bool>> {
  const PageCoverScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  static ValueListenable<bool>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageCoverScope>()?.notifier;
}
