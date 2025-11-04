import 'package:flutter/material.dart';

enum AlertType { success, error, warning, info }

class AnimatedAlert extends StatefulWidget {
  final String message;
  final AlertType type;
  final Duration duration;
  final VoidCallback? onDismiss;
  final IconData? customIcon;

  const AnimatedAlert({
    super.key,
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 4),
    this.onDismiss,
    this.customIcon,
  });

  @override
  State<AnimatedAlert> createState() => _AnimatedAlertState();
}

class _AnimatedAlertState extends State<AnimatedAlert>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Slide animation controller
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Slide from right to left
    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(1.0, 0.0), // Start from right
          end: Offset.zero, // End at center
        ).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    // Fade out animation
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Start slide in animation
    _slideController.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismissAlert();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _dismissAlert() {
    _fadeController.forward().then((_) {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  // Modern color scheme - colored accents on white background
  Color _getAccentColor() {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF10B981); // Green
      case AlertType.error:
        return const Color(0xFFEF4444); // Red
      case AlertType.warning:
        return const Color(0xFFF59E0B); // Amber
      case AlertType.info:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  IconData _getIcon() {
    if (widget.customIcon != null) return widget.customIcon!;

    switch (widget.type) {
      case AlertType.success:
        return Icons.check_circle_rounded;
      case AlertType.error:
        return Icons.error_rounded;
      case AlertType.warning:
        return Icons.warning_rounded;
      case AlertType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _fadeAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value * MediaQuery.of(context).size.width,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(
                top: 60, // Below status bar
                right: 16,
                left: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(color: _getAccentColor(), width: 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Colored icon badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getAccentColor().withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIcon(),
                        color: _getAccentColor(),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Message text
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: const Color(0xFF374151), // Dark gray text
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                          height: 1.4,
                          decoration:
                              TextDecoration.none, // Fix underline issue
                        ),
                        selectionColor:
                            Colors.transparent, // Prevent selection highlight
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close button
                    GestureDetector(
                      onTap: _dismissAlert,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF3F4F6,
                          ), // Light gray background
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF6B7280), // Gray icon
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedAlertOverlay extends StatefulWidget {
  final Widget child;
  final List<AnimatedAlert> alerts;

  const AnimatedAlertOverlay({
    super.key,
    required this.child,
    required this.alerts,
  });

  @override
  State<AnimatedAlertOverlay> createState() => _AnimatedAlertOverlayState();
}

class _AnimatedAlertOverlayState extends State<AnimatedAlertOverlay> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ...widget.alerts.map(
          (alert) => Positioned(top: 0, left: 0, right: 0, child: alert),
        ),
      ],
    );
  }
}

// Helper class to manage alerts
class AlertManager {
  static final List<AnimatedAlert> _alerts = [];
  static VoidCallback? _onAlertsChanged;

  static void showAlert({
    required String message,
    required AlertType type,
    Duration duration = const Duration(seconds: 4),
    IconData? customIcon,
  }) {
    final alertIndex = _alerts.length;
    final newAlert = AnimatedAlert(
      message: message,
      type: type,
      duration: duration,
      customIcon: customIcon,
      onDismiss: () {
        if (alertIndex < _alerts.length) {
          _alerts.removeAt(alertIndex);
          _onAlertsChanged?.call();
        }
      },
    );

    _alerts.add(newAlert);
    _onAlertsChanged?.call();
  }

  static void showSuccess(String message, {Duration? duration}) {
    showAlert(
      message: message,
      type: AlertType.success,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void showError(String message, {Duration? duration}) {
    showAlert(
      message: message,
      type: AlertType.error,
      duration: duration ?? const Duration(seconds: 5),
    );
  }

  static void showWarning(String message, {Duration? duration}) {
    showAlert(
      message: message,
      type: AlertType.warning,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  static void showInfo(String message, {Duration? duration}) {
    showAlert(
      message: message,
      type: AlertType.info,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void clearAll() {
    _alerts.clear();
    _onAlertsChanged?.call();
  }

  static List<AnimatedAlert> get alerts => List.unmodifiable(_alerts);

  static void setOnAlertsChanged(VoidCallback? callback) {
    _onAlertsChanged = callback;
  }
}
