import 'package:flutter/material.dart';
import '../widgets/animated_alert.dart';

mixin AnimatedAlertMixin<T extends StatefulWidget> on State<T> {
  final List<AnimatedAlert> _alerts = [];

  @override
  void initState() {
    super.initState();
    AlertManager.setOnAlertsChanged(_onAlertsChanged);
  }

  @override
  void dispose() {
    AlertManager.setOnAlertsChanged(null);
    super.dispose();
  }

  void _onAlertsChanged() {
    if (mounted) {
      setState(() {
        _alerts.clear();
        _alerts.addAll(AlertManager.alerts);
      });
    }
  }

  void showSuccessAlert(String message, {Duration? duration}) {
    AlertManager.showSuccess(message, duration: duration);
  }

  void showErrorAlert(String message, {Duration? duration}) {
    AlertManager.showError(message, duration: duration);
  }

  void showWarningAlert(String message, {Duration? duration}) {
    AlertManager.showWarning(message, duration: duration);
  }

  void showInfoAlert(String message, {Duration? duration}) {
    AlertManager.showInfo(message, duration: duration);
  }

  Widget buildWithAlerts(Widget child) {
    return AnimatedAlertOverlay(alerts: _alerts, child: child);
  }
}
