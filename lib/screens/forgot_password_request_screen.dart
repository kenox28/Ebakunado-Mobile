import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../utils/constants.dart';
import '../mixins/animated_alert_mixin.dart';
import '../models/forgot_password_response.dart';

class ForgotPasswordRequestScreen extends StatefulWidget {
  const ForgotPasswordRequestScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordRequestScreen> createState() =>
      _ForgotPasswordRequestScreenState();
}

class _ForgotPasswordRequestScreenState
    extends State<ForgotPasswordRequestScreen>
    with AnimatedAlertMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailPhoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailPhoneController.dispose();
    super.dispose();
  }

  Future<void> _sendResetOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final emailPhone = _emailPhoneController.text.trim();

    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.forgotPassword(emailPhone);
      final forgotPasswordResponse = ForgotPasswordResponse.fromJson(
        response.data,
      );

      if (forgotPasswordResponse.success) {
        showSuccessAlert(forgotPasswordResponse.message);

        // Navigate to verify OTP screen
        Navigator.pushNamed(
          context,
          AppConstants.forgotPasswordVerifyRoute,
          arguments: {
            'email_phone': emailPhone,
            'contact_type': forgotPasswordResponse.contactType,
            'expires_in': forgotPasswordResponse.expiresIn ?? 300,
          },
        );
      } else {
        showErrorAlert(forgotPasswordResponse.message);
      }
    } catch (e) {
      print('Forgot Password Error: $e');
      showErrorAlert('Failed to send OTP. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _validateEmailPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email or phone number is required';
    }

    final trimmedValue = value.trim();

    // Check if it's an email
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    // If it looks like an email, validate as email
    if (emailRegex.hasMatch(trimmedValue)) {
      return null;
    }

    // Otherwise, check if it's a phone number (Philippine format)
    // Remove all spaces, dashes, and parentheses for validation
    final cleanedValue = trimmedValue.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Accept these formats:
    // - 09123456789 (11 digits starting with 09)
    // - +639123456789 (13 chars starting with +639)
    // - 9123456789 (10 digits starting with 9)
    final phoneRegex = RegExp(r'^(09\d{9}|\+639\d{9}|9\d{9})$');

    if (phoneRegex.hasMatch(cleanedValue)) {
      return null;
    }

    return 'Please enter a valid email or phone number';
  }

  @override
  Widget build(BuildContext context) {
    return buildWithAlerts(
      Scaffold(
        backgroundColor: AppConstants.backgroundWhite,
        appBar: AppBar(
          title: const Text('Forgot Password'),
          backgroundColor: AppConstants.primaryGreen,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  // Lock Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      size: 40,
                      color: AppConstants.primaryGreen,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Reset Your Password',
                    style: AppConstants.headingStyle.copyWith(
                      color: AppConstants.primaryGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Instructions
                  Text(
                    'Enter your email address or phone number and we\'ll send you a verification code to reset your password.',
                    style: AppConstants.bodyStyle.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Email/Phone Input
                  TextFormField(
                    controller: _emailPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Email or Phone Number',
                      hintText: 'example@email.com or 09123456789',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppConstants.primaryGreen,
                          width: 2,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: _validateEmailPhone,
                    onFieldSubmitted: (_) => _sendResetOtp(),
                  ),

                  const SizedBox(height: 32),

                  // Send OTP Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendResetOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                            'Send Verification Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Back to Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Remember your password?',
                        style: AppConstants.bodyStyle,
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: AppConstants.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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
