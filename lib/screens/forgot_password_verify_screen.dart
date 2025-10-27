import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import '../services/api_client.dart';
import '../utils/constants.dart';
import '../mixins/animated_alert_mixin.dart';
import '../models/verify_reset_otp_response.dart';

class ForgotPasswordVerifyScreen extends StatefulWidget {
  const ForgotPasswordVerifyScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordVerifyScreen> createState() =>
      _ForgotPasswordVerifyScreenState();
}

class _ForgotPasswordVerifyScreenState extends State<ForgotPasswordVerifyScreen>
    with AnimatedAlertMixin {
  String _otp = '';
  bool _isLoading = false;
  Timer? _otpTimer;
  int _otpCountdown = 300; // 5 minutes
  bool _canResend = false;

  String? _emailPhone;
  String? _contactType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get arguments passed from previous screen
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _emailPhone = args['email_phone'];
          _contactType = args['contact_type'];
          _otpCountdown = args['expires_in'] ?? 300;
        });
        _startOtpTimer();
      }
    });
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    setState(() {
      _canResend = false;
      _otpCountdown = 300; // Reset to 5 minutes
    });

    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_otpCountdown > 0) {
          _otpCountdown--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String _formatCountdown() {
    final minutes = (_otpCountdown ~/ 60).toString().padLeft(2, '0');
    final seconds = (_otpCountdown % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      showErrorAlert('Please enter the complete 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.verifyResetOtp(_otp);
      final verifyResponse = VerifyResetOtpResponse.fromJson(response.data);

      if (verifyResponse.success) {
        showSuccessAlert(verifyResponse.message);

        // Navigate to reset password screen
        Navigator.pushReplacementNamed(
          context,
          AppConstants.forgotPasswordResetRoute,
        );
      } else {
        showErrorAlert(verifyResponse.message);
      }
    } catch (e) {
      print('Verify OTP Error: $e');
      showErrorAlert('Failed to verify OTP. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend || _emailPhone == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.forgotPassword(_emailPhone!);
      final responseData = response.data as Map<String, dynamic>;

      if (responseData['status'] == 'success') {
        showSuccessAlert('OTP resent successfully!');
        _startOtpTimer();
        setState(() => _otp = ''); // Clear OTP field
      } else {
        showErrorAlert(responseData['message'] ?? 'Failed to resend OTP');
      }
    } catch (e) {
      print('Resend OTP Error: $e');
      showErrorAlert('Failed to resend OTP. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildWithAlerts(
      Scaffold(
        backgroundColor: AppConstants.backgroundWhite,
        appBar: AppBar(
          title: const Text('Verify OTP'),
          backgroundColor: AppConstants.primaryGreen,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // Key Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppConstants.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.vpn_key_rounded,
                    size: 40,
                    color: AppConstants.primaryGreen,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  'Enter Verification Code',
                  style: AppConstants.headingStyle.copyWith(
                    color: AppConstants.primaryGreen,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Instructions
                if (_contactType != null)
                  Text(
                    _contactType == 'email'
                        ? 'We sent a 6-digit code to your email'
                        : 'We sent a 6-digit code to your phone',
                    style: AppConstants.bodyStyle.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                if (_emailPhone != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _emailPhone!,
                    style: AppConstants.bodyStyle.copyWith(
                      color: AppConstants.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 40),

                // OTP Input Field using flutter_otp_text_field
                Material(
                  color: Colors.transparent,
                  child: OtpTextField(
                    numberOfFields: 6,
                    borderColor: AppConstants.primaryGreen,
                    focusedBorderColor: AppConstants.primaryGreen,
                    showFieldAsBox: true,
                    borderWidth: 2,
                    borderRadius: BorderRadius.circular(8),
                    fieldWidth: 45,
                    fieldHeight: 55,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    onCodeChanged: (String code) {
                      setState(() {
                        _otp = code;
                      });
                    },
                    onSubmit: (String verificationCode) {
                      _otp = verificationCode;
                      _verifyOtp();
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Timer Display
                if (_otpCountdown > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: AppConstants.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Code expires in ${_formatCountdown()}',
                          style: AppConstants.bodyStyle.copyWith(
                            color: AppConstants.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Verify Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
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
                          'Verify Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),

                const SizedBox(height: 24),

                // Resend OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Didn\'t receive the code?',
                      style: AppConstants.bodyStyle,
                    ),
                    TextButton(
                      onPressed: _canResend && !_isLoading ? _resendOtp : null,
                      child: Text(
                        _canResend ? 'Resend' : 'Wait...',
                        style: TextStyle(
                          color: _canResend
                              ? AppConstants.primaryGreen
                              : AppConstants.textSecondary,
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
    );
  }
}

