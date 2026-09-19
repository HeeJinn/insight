import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_theme.dart';

/// Themed replacement for a bare `AsyncValue.when(...)` call: renders a
/// skeleton placeholder while loading (instead of a centered spinner that
/// causes a layout jump once data arrives) and a themed error panel with an
/// optional retry action.
class AppAsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;
  final Widget Function(BuildContext context)? loading;
  final Widget Function(BuildContext context, Object error, StackTrace stackTrace)? error;
  final VoidCallback? onRetry;

  const AppAsyncView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.onRetry,
  });

  /// Combines two [AsyncValue]s so callers don't have to hand-nest
  /// `.when(... .when(...))` — the loading/error state of either source
  /// is surfaced first, and [data] only runs once both have resolved.
  static Widget combine2<A, B>({
    Key? key,
    required AsyncValue<A> a,
    required AsyncValue<B> b,
    required Widget Function(BuildContext context, A a, B b) data,
    Widget Function(BuildContext context)? loading,
    Widget Function(BuildContext context, Object error, StackTrace stackTrace)? error,
    VoidCallback? onRetry,
  }) {
    return AppAsyncView<A>(
      key: key,
      value: a,
      loading: loading,
      error: error,
      onRetry: onRetry,
      data: (context, aValue) => AppAsyncView<B>(
        value: b,
        loading: loading,
        error: error,
        onRetry: onRetry,
        data: (context, bValue) => data(context, aValue, bValue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (resolved) => data(context, resolved),
      loading: () => loading?.call(context) ?? const _AppAsyncSkeleton(),
      error: (err, stack) =>
          error?.call(context, err, stack) ??
          _AppAsyncError(error: err, onRetry: onRetry),
    );
  }
}

class _AppAsyncSkeleton extends StatefulWidget {
  const _AppAsyncSkeleton();

  @override
  State<_AppAsyncSkeleton> createState() => _AppAsyncSkeletonState();
}

class _AppAsyncSkeletonState extends State<_AppAsyncSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.appColors.surface;
    final highlight = context.appColors.elevatedSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Color.lerp(base, highlight, _controller.value),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.appColors.border, width: 0.5),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AppAsyncError extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const _AppAsyncError({required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: context.appColors.danger, size: 28),
            const SizedBox(height: 10),
            Text(
              'Something went wrong',
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              style: context.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
