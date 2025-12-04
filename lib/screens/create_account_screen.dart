import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'dart:async';
import '../services/api_client.dart';
import '../models/create_account_request.dart';
import '../utils/constants.dart';
import '../mixins/animated_alert_mixin.dart';
import '../widgets/privacy_policy_consent_card.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with AnimatedAlertMixin {
  // Stepper
  int _currentStep = 0;
  final int _totalSteps = 3;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _fnameController = TextEditingController();
  final _lnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _barangayController = TextEditingController();
  final _purokController = TextEditingController();
  final _otpInputController = TextEditingController();

  // Form state
  String _gender = '';
  bool _agreedToTerms = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  // OTP state
  String _otp = '';
  bool _isOtpModalVisible = false;
  Timer? _otpTimer;
  int _otpCountdown = 300; // 5 minutes
  String _verifiedPhone = '';

  // Phone number country
  Country _selectedCountry = Country.parse('PH');

  @override
  void dispose() {
    _fnameController.dispose();
    _lnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _barangayController.dispose();
    _purokController.dispose();
    _otpInputController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  void _startOtpTimer() {
    _otpCountdown = 300; // 5 minutes
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_otpCountdown > 0) {
          _otpCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String _formatCountdown(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _sendOtp() async {
    final phoneNumber = _formatPhoneNumber(_phoneController.text.trim());

    if (phoneNumber.isEmpty) {
      showErrorAlert('Please enter a valid phone number');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.sendOtp(phoneNumber);
      if (response.success) {
        _verifiedPhone = response.message.contains('+')
            ? response.message.split('to ')[1]
            : phoneNumber;
        _startOtpTimer();
        setState(() {
          _otp = '';
          _otpInputController.clear();
          _isOtpModalVisible = true;
        });
        showSuccessAlert('OTP sent successfully! Check your phone.');
      } else {
        showErrorAlert(response.message);
      }
    } catch (e) {
      print('OTP Error Details: $e');
      showErrorAlert('Failed to send OTP: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      showErrorAlert('Please enter the complete 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.verifyOtp(_otp);
      if (response.success) {
        _closeOtpModal();
        showSuccessAlert('Phone number verified successfully!');
        // Move to next step
        _nextStep();
      } else {
        showErrorAlert(response.message);
      }
    } catch (e) {
      showErrorAlert('Failed to verify OTP. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _closeOtpModal() {
    setState(() {
      _isOtpModalVisible = false;
      _otp = '';
      _otpInputController.clear();
    });
    _otpTimer?.cancel();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  String _formatPhoneNumber(String phoneNumber) {
    // Remove all non-digits
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Check if it's already in international format
    if (cleanNumber.startsWith('63')) {
      return '+$cleanNumber';
    }

    // Check if it starts with 0 (Philippine format)
    if (cleanNumber.startsWith('0')) {
      return '+63${cleanNumber.substring(1)}';
    }

    // If it doesn't start with 0 or 63, assume it's already clean
    if (cleanNumber.length == 10) {
      return '+63$cleanNumber';
    }

    return cleanNumber;
  }

  bool _validateStep1() {
    if (_fnameController.text.trim().isEmpty) {
      showErrorAlert('Please enter your first name');
      return false;
    }
    if (_lnameController.text.trim().isEmpty) {
      showErrorAlert('Please enter your last name');
      return false;
    }
    if (_emailController.text.trim().isEmpty ||
        !_isValidEmail(_emailController.text.trim())) {
      showErrorAlert('Please enter a valid email address');
      return false;
    }
    if (_phoneController.text.trim().isEmpty ||
        !_isValidPhoneNumber(_phoneController.text.trim())) {
      showErrorAlert('Please enter a valid phone number');
      return false;
    }
    if (_gender.isEmpty) {
      showErrorAlert('Please select your gender');
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_provinceController.text.trim().isEmpty) {
      showErrorAlert('Please enter your province');
      return false;
    }
    if (_cityController.text.trim().isEmpty) {
      showErrorAlert('Please enter your city or municipality');
      return false;
    }
    if (_barangayController.text.trim().isEmpty) {
      showErrorAlert('Please enter your barangay');
      return false;
    }
    if (_purokController.text.trim().isEmpty) {
      showErrorAlert('Please enter your purok / street / block');
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (_passwordController.text.length < 8) {
      showErrorAlert('Password must be at least 8 characters long');
      return false;
    }
    if (!_isStrongPassword(_passwordController.text)) {
      showErrorAlert(
        'Password must contain uppercase, lowercase, number, and special character',
      );
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      showErrorAlert('Passwords do not match');
      return false;
    }
    if (!_agreedToTerms) {
      showErrorAlert('Please agree to the Terms of Service and Privacy Policy');
      return false;
    }
    return true;
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return cleanNumber.length >= 10 && cleanNumber.length <= 15;
  }

  bool _isStrongPassword(String password) {
    // Check for at least one uppercase, one lowercase, one digit, one special character
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    final hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    // Check against common weak passwords
    final weakPasswords = [
      'password',
      '123456',
      'qwerty',
      'admin',
      'letmein',
      'welcome',
    ];
    final isNotWeak = !weakPasswords.contains(password.toLowerCase());

    return hasUppercase &&
        hasLowercase &&
        hasDigit &&
        hasSpecialChar &&
        isNotWeak;
  }

  Future<void> _createAccount() async {
    if (!_validateStep3()) return;

    setState(() => _isLoading = true);
    try {
      // Format phone number for PHP: send as 09XXXXXXXXX format
      final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());
      // Convert +639460017277 to 09460017277 for PHP compatibility
      String phoneForApi = formattedPhone;
      if (phoneForApi.startsWith('+63')) {
        phoneForApi =
            '0' + phoneForApi.substring(3); // +639460017277 -> 09460017277
      } else if (phoneForApi.startsWith('63')) {
        phoneForApi =
            '0' + phoneForApi.substring(2); // 639460017277 -> 09460017277
      }

      final request = CreateAccountRequest(
        fname: _fnameController.text.trim(),
        lname: _lnameController.text.trim(),
        email: _emailController.text.trim(),
        number: phoneForApi, // Send without '+' sign
        gender: _gender,
        province: _provinceController.text.trim(),
        cityMunicipality: _cityController.text.trim(),
        barangay: _barangayController.text.trim(),
        purok: _purokController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        csrfToken: '', // Will be set by API client with mobile app token
        mobileAppRequest: true,
        skipOtp: false,
        agreedToTerms: _agreedToTerms,
      );

      print('Creating account for: ${_emailController.text.trim()}');
      print('Phone number sent: $phoneForApi');
      final response = await ApiClient.instance.createAccount(request);

      if (response.success) {
        showSuccessAlert('Account created successfully! Please log in.');
        // Navigate to login screen
        Navigator.pushReplacementNamed(context, AppConstants.loginRoute);
      } else {
        showErrorAlert(response.message);
      }
    } catch (e) {
      showErrorAlert('Failed to create account. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildWithAlerts(
      Stack(
        children: [
          Scaffold(
            backgroundColor: AppConstants.backgroundWhite,
            appBar: AppBar(
              title: const Text('Create Account'),
              backgroundColor: AppConstants.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // Stepper Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppConstants.secondaryGray,
                    child: Column(
                      children: [
                        // Progress indicator
                        LinearProgressIndicator(
                          value: (_currentStep + 1) / _totalSteps,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppConstants.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Step titles
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStepIndicator(0, 'Personal'),
                            _buildStepIndicator(1, 'Address'),
                            _buildStepIndicator(2, 'Security'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Form content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Step 1: Personal Information
                            if (_currentStep == 0) _buildPersonalInfoStep(),
                            // Step 2: Address Information
                            if (_currentStep == 1) _buildAddressInfoStep(),
                            // Step 3: Security Information
                            if (_currentStep == 2) _buildSecurityInfoStep(),

                            const SizedBox(height: 32),

                            // Navigation buttons
                            Row(
                              children: [
                                if (_currentStep > 0)
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _previousStep,
                                      child: const Text('Previous'),
                                    ),
                                  ),
                                if (_currentStep > 0) const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _currentStep == 0
                                        ? () async {
                                            if (_validateStep1()) {
                                              await _sendOtp();
                                            }
                                          }
                                        : _currentStep == 1
                                        ? () {
                                            if (_validateStep2()) {
                                              _nextStep();
                                            }
                                          }
                                        : () {
                                            if (_validateStep3()) {
                                              _createAccount();
                                            }
                                          },
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Text(
                                            _currentStep == 0
                                                ? 'Send OTP'
                                                : _currentStep == 1
                                                ? 'Next'
                                                : 'Create Account',
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
                ],
              ),
            ),
          ),

          // OTP Modal
          if (_isOtpModalVisible)
            GestureDetector(
              onTap: _closeOtpModal,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.5),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final mediaQuery = MediaQuery.of(context);
                    final double viewInsets = mediaQuery.viewInsets.bottom;
                    final double modalWidth = (mediaQuery.size.width * 0.9)
                        .clamp(280.0, 460.0)
                        .toDouble();

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(24, 32, 24, 32 + viewInsets),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 460,
                            minWidth: modalWidth,
                          ),
                          child: Material(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white,
                            elevation: 8,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 28,
                              ),
                              child: LayoutBuilder(
                                builder: (context, modalConstraints) {
                                  final bool isNarrow =
                                      modalConstraints.maxWidth < 360;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.sms,
                                        size: 48,
                                        color: AppConstants.primaryGreen,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Verify Phone Number',
                                        style: AppConstants.headingStyle
                                            .copyWith(fontSize: 20),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Enter the 6-digit code sent to',
                                        style: AppConstants.bodyStyle.copyWith(
                                          color: AppConstants.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _verifiedPhone,
                                        style: AppConstants.bodyStyle.copyWith(
                                          color: AppConstants.primaryGreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 28),

                                      // OTP Input Field (single line)
                                      SizedBox(
                                        width: double.infinity,
                                        child: TextFormField(
                                          controller: _otpInputController,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(6),
                                          ],
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 12,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: '••••••',
                                            hintStyle: TextStyle(
                                              color: Colors.grey.shade400,
                                              letterSpacing: 12,
                                            ),
                                            counterText: '',
                                            filled: true,
                                            fillColor: Colors.grey.shade100,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 14,
                                                  horizontal: 12,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color:
                                                    AppConstants.primaryGreen,
                                                width: 2,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color:
                                                    AppConstants.primaryGreen,
                                                width: 2.5,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: Colors.grey.shade300,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            setState(() => _otp = value);
                                            if (value.length == 6) {
                                              FocusScope.of(context).unfocus();
                                            }
                                          },
                                        ),
                                      ),

                                      const SizedBox(height: 14),

                                      // Countdown Timer
                                      if (_otpCountdown > 0)
                                        Text(
                                          'Code expires in ${_formatCountdown(_otpCountdown)}',
                                          style: AppConstants.bodyStyle
                                              .copyWith(
                                                color:
                                                    AppConstants.warningOrange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                          textAlign: TextAlign.center,
                                        )
                                      else
                                        Text(
                                          'Code has expired. Please request a new one.',
                                          style: AppConstants.bodyStyle
                                              .copyWith(
                                                color: AppConstants.errorRed,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),

                                      const SizedBox(height: 22),

                                      // Buttons
                                      if (isNarrow)
                                        Column(
                                          children: [
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton(
                                                onPressed: _closeOtpModal,
                                                child: const Text('Cancel'),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: _otp.length == 6
                                                    ? _verifyOtp
                                                    : null,
                                                child: _isLoading
                                                    ? const SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(Colors.white),
                                                        ),
                                                      )
                                                    : const Text('Verify'),
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: _closeOtpModal,
                                                child: const Text('Cancel'),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: _otp.length == 6
                                                    ? _verifyOtp
                                                    : null,
                                                child: _isLoading
                                                    ? const SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(Colors.white),
                                                        ),
                                                      )
                                                    : const Text('Verify'),
                                              ),
                                            ),
                                          ],
                                        ),

                                      const SizedBox(height: 16),

                                      // Resend OTP
                                      if (_otpCountdown == 0)
                                        TextButton(
                                          onPressed: () async {
                                            await _sendOtp();
                                          },
                                          child: Text(
                                            'Resend OTP',
                                            style: TextStyle(
                                              color: AppConstants.primaryGreen,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String title) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: isActive
              ? AppConstants.primaryGreen
              : isCompleted
              ? AppConstants.successGreen
              : Colors.grey[300],
          child: Text(
            '${step + 1}',
            style: TextStyle(
              color: isActive || isCompleted ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppConstants.primaryGreen : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'Personal Information',
          style: AppConstants.headingStyle.copyWith(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Tell us about yourself',
          style: AppConstants.bodyStyle.copyWith(
            color: AppConstants.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // First Name
        TextFormField(
          controller: _fnameController,
          decoration: const InputDecoration(
            labelText: 'First Name',
            hintText: 'Enter first name',
            prefixIcon: Icon(Icons.person),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your first name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Last Name
        TextFormField(
          controller: _lnameController,
          decoration: const InputDecoration(
            labelText: 'Last Name',
            hintText: 'Enter last name',
            prefixIcon: Icon(Icons.person),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your last name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Email
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'Enter email address',
            prefixIcon: Icon(Icons.email),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email address';
            }
            if (!_isValidEmail(value.trim())) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Phone Number with Country Picker
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: '09xxxxxxxxx',
            prefixIcon: GestureDetector(
              onTap: () {
                showCountryPicker(
                  context: context,
                  showPhoneCode: true,
                  onSelect: (Country country) {
                    setState(() {
                      _selectedCountry = country;
                    });
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Text(
                  '${_selectedCountry.flagEmoji} +${_selectedCountry.phoneCode}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your phone number';
            }
            if (!_isValidPhoneNumber(value.trim())) {
              return 'Please enter a valid phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Gender Dropdown
        DropdownButtonFormField<String>(
          value: _gender.isEmpty ? null : _gender,
          decoration: const InputDecoration(
            labelText: 'Gender',
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
          ],
          onChanged: (value) {
            setState(() {
              _gender = value ?? '';
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your gender';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAddressInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'Address Information',
          style: AppConstants.headingStyle.copyWith(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Where are you located?',
          style: AppConstants.bodyStyle.copyWith(
            color: AppConstants.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Province
        TextFormField(
          controller: _provinceController,
          decoration: const InputDecoration(
            labelText: 'Province',
            hintText: 'Enter province',
            prefixIcon: Icon(Icons.map),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your province';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // City / Municipality
        TextFormField(
          controller: _cityController,
          decoration: const InputDecoration(
            labelText: 'City / Municipality',
            hintText: 'Enter city or municipality',
            prefixIcon: Icon(Icons.location_city),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your city or municipality';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Barangay
        TextFormField(
          controller: _barangayController,
          decoration: const InputDecoration(
            labelText: 'Barangay',
            hintText: 'Enter barangay',
            prefixIcon: Icon(Icons.home),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your barangay';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Purok / Street / Block
        TextFormField(
          controller: _purokController,
          decoration: const InputDecoration(
            labelText: 'Purok / Street / Block',
            hintText: 'Enter purok, street, or block',
            prefixIcon: Icon(Icons.place),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your purok / street / block';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSecurityInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'Account Security',
          style: AppConstants.headingStyle.copyWith(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Create a strong password',
          style: AppConstants.bodyStyle.copyWith(
            color: AppConstants.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Password
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter password',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
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
              return 'Please enter a password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            if (!_isStrongPassword(value)) {
              return 'Password must contain uppercase, lowercase, number, and special character';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Confirm Password
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: !_isConfirmPasswordVisible,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Confirm your password',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _isConfirmPasswordVisible
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Password Requirements
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppConstants.secondaryGray,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Password Requirements:',
                style: AppConstants.subheadingStyle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildRequirementItem(
                'At least 8 characters',
                _passwordController.text.length >= 8,
              ),
              _buildRequirementItem(
                'One uppercase letter (A-Z)',
                RegExp(r'[A-Z]').hasMatch(_passwordController.text),
              ),
              _buildRequirementItem(
                'One lowercase letter (a-z)',
                RegExp(r'[a-z]').hasMatch(_passwordController.text),
              ),
              _buildRequirementItem(
                'One number (0-9)',
                RegExp(r'\d').hasMatch(_passwordController.text),
              ),
              _buildRequirementItem(
                'One special character (!@#\$%^&)',
                RegExp(
                  r'[!@#$%^&*(),.?":{}|<>]',
                ).hasMatch(_passwordController.text),
              ),
              _buildRequirementItem(
                'Not a common password',
                !_isWeakPassword(_passwordController.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Privacy Policy & Terms of Service
        PrivacyPolicyConsentCard(
          agreed: _agreedToTerms,
          onChanged: (value) {
            setState(() {
              _agreedToTerms = value ?? false;
            });
          },
          onOpenPrivacy: () {
            // TODO: Open privacy policy URL or PDF
            // You can use url_launcher package here
            // Example: launchUrl(Uri.parse('https://your-privacy-policy-url.com'));
          },
          onOpenTerms: () {
            // TODO: Open terms of service URL or PDF
            // You can use url_launcher package here
            // Example: launchUrl(Uri.parse('https://your-terms-url.com'));
          },
        ),
      ],
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.circle,
          size: 16,
          color: isMet ? AppConstants.successGreen : Colors.grey[400],
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isMet ? AppConstants.successGreen : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  bool _isWeakPassword(String password) {
    final weakPasswords = [
      'password',
      '123456',
      'qwerty',
      'admin',
      'letmein',
      'welcome',
    ];
    return weakPasswords.contains(password.toLowerCase());
  }
}
