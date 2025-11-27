import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../utils/constants.dart';
import '../mixins/animated_alert_mixin.dart';
import '../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with AnimatedAlertMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<UserProfileProvider>(
        context,
        listen: false,
      );

      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
        showGlobalLoading: false,
      );

      if (success && mounted) {
        authProvider.setGlobalLoading(true);
        try {
          await profileProvider.loadProfileData();

          if (profileProvider.profile == null) {
            debugPrint('LoginScreen: profile null after load, retrying once...');
            await profileProvider.loadProfileData();
          }

          await NotificationService.scheduleDailyNotificationCheck();
          if (mounted) {
            await _checkBatteryOptimizationAfterLogin();
            Navigator.pushReplacementNamed(context, AppConstants.homeRoute);
          }
        } finally {
          authProvider.setGlobalLoading(false);
        }
      } else if (mounted) {
        await _showLoginErrorDialog(
          'Incorrect email or password. Please check your credentials and try again.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('LoginScreen: login error - $e\n$stackTrace');
      final errorMessage = _extractLoginErrorMessage(e);
      if (mounted) {
        await Future.microtask(() async {
          if (mounted) {
            await _showLoginErrorDialog(errorMessage);
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _extractLoginErrorMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('Network error')) {
      return 'Network error. Please check your connection.';
    }
    if (raw.contains('Incorrect') || raw.contains('invalid')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (raw.isNotEmpty) {
      return raw.replaceFirst('Exception: ', '');
    }
    return 'Login failed. Please try again.';
  }

  Future<void> _showLoginErrorDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: AppConstants.errorRed),
              const SizedBox(width: 12),
              const Text('Login Failed'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkBatteryOptimizationAfterLogin() async {
    if (!Platform.isAndroid) {
      return; // Only for Android
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final batteryCheckShown = prefs.getBool('battery_optimization_check_shown') ?? false;

      // Only show once after login
      if (batteryCheckShown) {
        return;
      }

      // Check if battery optimization is disabled
      final isBatteryOptimized = await NotificationService.isBatteryOptimizationDisabled();

      if (!isBatteryOptimized && mounted) {
        // Show dialog explaining battery optimization
        final shouldOpen = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.battery_alert, color: AppConstants.primaryGreen),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Battery Optimization'),
                ),
              ],
            ),
            content: const Text(
              'For notifications to work properly when the app is closed, '
              'please disable battery optimization for Ebakunado.\n\n'
              'This ensures you receive timely immunization reminders.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text('Remind Me Later'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );

        if (shouldOpen == true && mounted) {
          // Open battery optimization settings
          await NotificationService.openSystemBatterySettings();
        }

        // Mark as shown
        await prefs.setBool('battery_optimization_check_shown', true);
      }
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildWithAlerts(
      Scaffold(
        backgroundColor: AppConstants.backgroundWhite,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),

                  // Logo and Title
                  Image.asset(
                    'assets/ebakunado-logo-without-label.png',
                    height: 80,
                    width: 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ebakunado',
                    style: AppConstants.headingStyle.copyWith(
                      fontSize: 32,
                      color: AppConstants.primaryGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Child Immunization Tracker',
                    style: AppConstants.bodyStyle.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),

                  // Email/Phone Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email or Phone Number',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email or phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Login Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppConstants.createAccountRoute,
                      );
                    },
                    child: Text(
                      'Create Account?',
                      style: TextStyle(color: AppConstants.primaryGreen),
                    ),
                  ),
                  // Forgot Password
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppConstants.forgotPasswordRequestRoute,
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color: AppConstants.primaryGreen),
                    ),
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
