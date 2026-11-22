import 'dart:async';

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class SwipeReply extends StatefulWidget {
  const SwipeReply({
    super.key,
    required this.onActions,
    required this.onReply,
    required this.child,
  });

  final VoidCallback onActions;
  final VoidCallback? onReply;
  final Widget child;

  @override
  State<SwipeReply> createState() => _SwipeReplyState();
}

class _SwipeReplyState extends State<SwipeReply>
    with SingleTickerProviderStateMixin {
  static const _threshold = 44.0;
  static const _maxDistance = 62.0;
  static const _replyAction = CustomSemanticsAction(label: 'Reply');

  late final _slide = AnimationController.unbounded(vsync: this);

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails details) {
    final previous = _slide.value;
    _slide.value = (previous + details.delta.dx).clamp(0.0, _maxDistance);
    if (previous < _threshold && _slide.value >= _threshold) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  void _reset() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _slide.value = 0;
    } else {
      unawaited(
        _slide.animateTo(
          0,
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _release(DragEndDetails _) {
    final shouldReply = _slide.value >= _threshold;
    _reset();
    if (shouldReply) widget.onReply?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final onReply = widget.onReply;
    return Semantics(
      customSemanticsActions: onReply == null ? null : {_replyAction: onReply},
      child: GestureDetector(
        onLongPress: widget.onActions,
        onSecondaryTap: widget.onActions,
        onHorizontalDragStart: onReply == null ? null : (_) => _slide.stop(),
        onHorizontalDragUpdate: onReply == null ? null : _drag,
        onHorizontalDragEnd: onReply == null ? null : _release,
        onHorizontalDragCancel: onReply == null ? null : _reset,
        child: AnimatedBuilder(
          animation: _slide,
          child: widget.child,
          builder: (context, child) {
            final distance = _slide.value;
            final replyIcon = IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: (distance / _threshold).clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: distance >= _threshold
                          ? colors.primary
                          : colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 30,
                      child: Icon(
                        Icons.reply_rounded,
                        color: distance >= _threshold
                            ? colors.onPrimary
                            : colors.onPrimaryContainer,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              ),
            );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (!reduceMotion)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: replyIcon,
                    ),
                  ),
                Transform.translate(
                  offset: Offset(reduceMotion ? 0 : distance, 0),
                  child: child,
                ),
                if (reduceMotion)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: replyIcon,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
