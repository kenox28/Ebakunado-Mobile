import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'constants.dart';

class ErrorHandler {
  static void handleError(BuildContext context, dynamic error) {
    String message = 'An unexpected error occurred';

    if (error is AuthExpiredException) {
      _handleAuthExpired(context);
      return;
    }

    if (error is Exception) {
      message = error.toString().replaceFirst('Exception: ', '');
    }

    _showErrorSnackBar(context, message);
  }

  static void _handleAuthExpired(BuildContext context) {
    // Clear auth state
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout();

    // Navigate to login
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppConstants.loginRoute,
      (route) => false,
    );

    _showErrorSnackBar(context, 'Session expired. Please login again.');
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorRed,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showSuccessMessage(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showWarningMessage(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.warningOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
