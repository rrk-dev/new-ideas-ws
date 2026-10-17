import 'package:flutter/material.dart';
import 'package:vaultvoice/core/widgets/empty_state.dart';

/// Centered icon + message (+ optional action) for empty and error states.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: icon,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}
