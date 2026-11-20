import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/grocery_list.dart';

enum _CardAction { edit, active, completed, archived, delete }

/// One grocery list in the overview. Editing, status changes, and deletion are
/// delegated to the parent so the card stays reusable.
///
/// Horizontal swipes reveal the status action for the current status. The
/// transition table lives in [GroceryListStatusSwipeX], so the menu and swipe
/// flows cannot drift apart. The card owns only the gesture feedback: the
/// parent owns the repository-backed status update and reports whether it was
/// saved.
class GroceryListCard extends StatefulWidget {
  const GroceryListCard({
    super.key,
    required this.groceryList,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final GroceryList groceryList;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Returns `true` only after the new status has been persisted.
  final Future<bool> Function(GroceryListStatus status) onStatusChanged;

  @override
  State<GroceryListCard> createState() => _GroceryListCardState();
}

class _GroceryListCardState extends State<GroceryListCard>
    with SingleTickerProviderStateMixin {
  /// Enough travel to expose the action label without covering the whole card.
  static const double _maxSlide = 120;

  /// 44px on a phone is a deliberate, thumb-sized commit threshold.
  static const double _commitThreshold = 88;

  /// A fast flick commits even when the finger travelled a shorter distance.
  static const double _flingVelocityThreshold = 600;

  static const Duration _animationDuration = Duration(milliseconds: 180);

  late final AnimationController _slide = AnimationController(
    vsync: this,
    lowerBound: -1,
    upperBound: 1,
    value: 0,
  );

  bool _isCommitting = false;

  @override
  void didUpdateWidget(covariant GroceryListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groceryList.id != widget.groceryList.id ||
        oldWidget.groceryList.status != widget.groceryList.status) {
      _isCommitting = false;
      // When the active status filter keeps the card, it returns to its
      // resting position with its new badge instead of staying off-screen.
      unawaited(_animateTo(0));
    }
  }

  Future<void> _animateTo(double value) {
    if (!mounted) return Future<void>.value();
    return _slide
        .animateTo(value, duration: _animationDuration, curve: Curves.easeOut)
        .orCancel;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isCommitting) return;
    final double dragged = _slide.value * _maxSlide + details.delta.dx;
    final double clamped = dragged.clamp(-_maxSlide, _maxSlide);
    _slide.value = clamped / _maxSlide;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isCommitting) return;

    final double position = _slide.value;
    final double velocity = details.primaryVelocity ?? 0;
    final bool flungFarEnough =
        velocity.abs() >= _flingVelocityThreshold &&
        velocity.sign == position.sign;
    final bool shouldCommit =
        position.abs() * _maxSlide >= _commitThreshold || flungFarEnough;

    if (!shouldCommit) {
      unawaited(_animateTo(0));
      return;
    }

    final bool toEnd = position == 0 ? velocity > 0 : position > 0;
    final GroceryListSwipeAction action = widget.groceryList.status.swipeAction(
      toEnd: toEnd,
    );
    unawaited(_commitSwipe(action, toEnd ? 1 : -1));
  }

  Future<void> _commitSwipe(
    GroceryListSwipeAction action,
    double target,
  ) async {
    if (!mounted) return;
    setState(() => _isCommitting = true);

    // The card leaves first, so a status filter that excludes it removes an
    // already off-screen row instead of making it vanish abruptly.
    await _animateTo(target);
    if (!mounted) return;

    final bool saved = await widget.onStatusChanged(action.targetStatus);
    if (!mounted) return;

    if (!saved) {
      await _animateTo(0);
    }
    if (mounted) {
      setState(() => _isCommitting = false);
    }
  }

  void _handleAction(_CardAction action) {
    switch (action) {
      case _CardAction.edit:
        widget.onEdit();
      case _CardAction.active:
        unawaited(widget.onStatusChanged(GroceryListStatus.active));
      case _CardAction.completed:
        unawaited(widget.onStatusChanged(GroceryListStatus.completed));
      case _CardAction.archived:
        unawaited(widget.onStatusChanged(GroceryListStatus.archived));
      case _CardAction.delete:
        widget.onDelete();
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String categoryLabel =
        widget.groceryList.category?.name ?? 'No category';
    final GroceryListSwipeAction rightAction = widget.groceryList.status
        .swipeAction(toEnd: true);
    final GroceryListSwipeAction leftAction = widget.groceryList.status
        .swipeAction(toEnd: false);

    return Semantics(
      label:
          '${widget.groceryList.title}, ${widget.groceryList.status.label}. '
          'Swipe right to ${rightAction.label}, left to ${leftAction.label}.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: () => unawaited(_animateTo(0)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AnimatedBuilder(
            animation: _slide,
            builder: (BuildContext context, Widget? child) {
              final double position = _slide.value;
              final bool toEnd = position >= 0;
              final GroceryListSwipeAction action = toEnd
                  ? rightAction
                  : leftAction;

              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: _SwipeBackground(
                      action: action,
                      progress: position.abs().clamp(0.0, 1.0),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(position * _maxSlide, 0),
                    child: child,
                  ),
                ],
              );
            },
            child: Card(
              child: ListTile(
                onTap: widget.onTap,
                leading: CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: const Icon(Icons.shopping_basket_outlined),
                ),
                title: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.groceryList.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: widget.groceryList.status),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '$categoryLabel  •  ${widget.groceryList.itemCount} items',
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.groceryList.budget == null
                            ? 'Budget: Not set'
                            : 'Budget: ${_formatMoney(widget.groceryList.budget!)}',
                        style: TextStyle(
                          color: widget.groceryList.budget == null
                              ? colors.onSurfaceVariant
                              : colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Estimated total: ${_formatMoney(widget.groceryList.estimatedTotal)}',
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Updated ${MaterialLocalizations.of(context).formatCompactDate(widget.groceryList.updatedAt)}',
                      ),
                    ],
                  ),
                ),
                trailing: PopupMenuButton<_CardAction>(
                  tooltip: 'List options',
                  onSelected: _handleAction,
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<_CardAction>>[
                        const PopupMenuItem<_CardAction>(
                          value: _CardAction.edit,
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 12),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem<_CardAction>(
                          value: _CardAction.active,
                          enabled:
                              widget.groceryList.status !=
                              GroceryListStatus.active,
                          child: const Text('Mark as active'),
                        ),
                        PopupMenuItem<_CardAction>(
                          value: _CardAction.completed,
                          enabled:
                              widget.groceryList.status !=
                              GroceryListStatus.completed,
                          child: const Text('Mark as completed'),
                        ),
                        PopupMenuItem<_CardAction>(
                          value: _CardAction.archived,
                          enabled:
                              widget.groceryList.status !=
                              GroceryListStatus.archived,
                          child: const Text('Mark as archived'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<_CardAction>(
                          value: _CardAction.delete,
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.delete_outline),
                              SizedBox(width: 12),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatMoney(double amount) => '₱${amount.toStringAsFixed(2)}';

/// Color/icon/label feedback shown beneath a card while it is being swiped.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.action, required this.progress});

  final GroceryListSwipeAction action;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _SwipeVisual visual = _SwipeVisual.forAction(action);
    final bool toEnd =
        action == GroceryListSwipeAction.complete ||
        action == GroceryListSwipeAction.reactivate;

    return Opacity(
      opacity: 0.45 + 0.55 * progress,
      child: Container(
        decoration: BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: toEnd ? Alignment.centerLeft : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Semantics(
          label: action.label,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (toEnd) ...<Widget>[
                Icon(visual.icon, color: Colors.white, size: 28),
                const SizedBox(width: 10),
              ],
              Text(
                action.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!toEnd) ...<Widget>[
                const SizedBox(width: 10),
                Icon(visual.icon, color: Colors.white, size: 28),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Semantic colors keep each swipe action visually distinct in light/dark
/// themes while preserving readable white foreground text.
class _SwipeVisual {
  const _SwipeVisual._(this.background, this.icon);

  static const _SwipeVisual complete = _SwipeVisual._(
    Color(0xFF2E7D32),
    Icons.check_circle_outline,
  );
  static const _SwipeVisual archive = _SwipeVisual._(
    Color(0xFFE65100),
    Icons.archive_outlined,
  );
  static const _SwipeVisual reactivate = _SwipeVisual._(
    Color(0xFF1565C0),
    Icons.restore,
  );
  static const _SwipeVisual markCompleted = _SwipeVisual._(
    Color(0xFF00695C),
    Icons.task_alt,
  );

  final Color background;
  final IconData icon;

  static _SwipeVisual forAction(GroceryListSwipeAction action) =>
      switch (action) {
        GroceryListSwipeAction.complete => complete,
        GroceryListSwipeAction.archive => archive,
        GroceryListSwipeAction.reactivate => reactivate,
        GroceryListSwipeAction.markCompleted => markCompleted,
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final GroceryListStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status) {
      GroceryListStatus.active => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      GroceryListStatus.completed => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      GroceryListStatus.archived => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
