import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

void showTopNotificationBanner(
  BuildContext context, {
  required String title,
  required String message,
  String tone = 'info',
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  Color bgColor;
  Color iconColor;
  IconData icon;

  switch (tone) {
    case 'danger':
      bgColor = AppTheme.primary;
      iconColor = AppTheme.danger;
      icon = LucideIcons.alertTriangle;
      break;
    case 'warn':
      bgColor = AppTheme.primary;
      iconColor = AppTheme.warning;
      icon = LucideIcons.alertCircle;
      break;
    case 'good':
      bgColor = AppTheme.primary;
      iconColor = AppTheme.success;
      icon = LucideIcons.checkCircle2;
      break;
    case 'info':
    default:
      bgColor = AppTheme.primary;
      iconColor = AppTheme.accent;
      icon = LucideIcons.bellRing;
      break;
  }

  entry = OverlayEntry(
    builder: (context) => _TopBannerWidget(
      title: title,
      message: message,
      bgColor: bgColor,
      iconColor: iconColor,
      icon: icon,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 4), () {
    if (entry.mounted) entry.remove();
  });
}

class _TopBannerWidget extends StatefulWidget {
  final String title;
  final String message;
  final Color bgColor;
  final Color iconColor;
  final IconData icon;
  final VoidCallback onDismiss;

  const _TopBannerWidget({
    required this.title,
    required this.message,
    required this.bgColor,
    required this.iconColor,
    required this.icon,
    required this.onDismiss,
  });

  @override
  State<_TopBannerWidget> createState() => _TopBannerWidgetState();
}

class _TopBannerWidgetState extends State<_TopBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          elevation: 12,
          shadowColor: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          color: widget.bgColor,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _dismiss,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.iconColor.withOpacity(0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.iconColor.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(LucideIcons.x, color: Colors.white.withOpacity(0.6), size: 18),
                    onPressed: _dismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
