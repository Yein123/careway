import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';

/// Renders loading, error (with Retry), empty and data states for an AsyncValue.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.empty,
    this.isEmpty,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T) data;
  final Widget? empty;
  final bool Function(T)? isEmpty;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (v) =>
          (isEmpty?.call(v) ?? false) && empty != null ? empty! : data(v),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: CwColors.muted, size: 32),
              const SizedBox(height: 8),
              const Text(
                'Something went wrong loading this.',
                style: CwText.muted,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Friendly empty state with an icon and message.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: CwColors.lilac,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: CwColors.primary, size: 30),
        ),
        const SizedBox(height: 12),
        Text(title, style: CwText.h3, textAlign: TextAlign.center),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(message!, style: CwText.muted, textAlign: TextAlign.center),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}
