import 'package:flutter/material.dart';
import '../utils/constants.dart';

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

  Color _getBackgroundColor() {
    switch (widget.type) {
      case AlertType.success:
        return AppConstants.alertSuccess;
      case AlertType.error:
        return AppConstants.alertError;
      case AlertType.warning:
        return AppConstants.alertWarning;
      case AlertType.info:
        return AppConstants.alertInfo;
    }
  }

  IconData _getIcon() {
    if (widget.customIcon != null) return widget.customIcon!;

    switch (widget.type) {
      case AlertType.success:
        return Icons.check_circle;
      case AlertType.error:
        return Icons.error;
      case AlertType.warning:
        return Icons.warning;
      case AlertType.info:
        return Icons.info;
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: _getBackgroundColor().withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(_getIcon(), color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        height: 1.3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismissAlert,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
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
