import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../utils/constants.dart';
import '../mixins/animated_alert_mixin.dart';
import '../models/google_sign_in_response.dart';
import '../widgets/privacy_policy_consent_card.dart';
import '../services/notification_service.dart';

/// Google Complete Profile Screen
/// For new users signing up via Google - they need to provide additional info
/// (phone number, address, gender) to complete registration
class GoogleCompleteProfileScreen extends StatefulWidget {
  const GoogleCompleteProfileScreen({super.key});

  @override
  State<GoogleCompleteProfileScreen> createState() =>
      _GoogleCompleteProfileScreenState();
}

class _GoogleCompleteProfileScreenState
    extends State<GoogleCompleteProfileScreen>
    with AnimatedAlertMixin {
  // Stepper
  int _currentStep = 0;
  final int _totalSteps = 2;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _barangayController = TextEditingController();
  final _purokController = TextEditingController();

  // Form state
  String _gender = '';
  bool _agreedToTerms = false;
  bool _isLoading = false;

  // Phone number country
  Country _selectedCountry = Country.parse('PH');

  @override
  void dispose() {
    _phoneController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _barangayController.dispose();
    _purokController.dispose();
    super.dispose();
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
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanNumber.startsWith('63')) {
      return '+$cleanNumber';
    }

    if (cleanNumber.startsWith('0')) {
      return '+63${cleanNumber.substring(1)}';
    }

    if (cleanNumber.length == 10) {
      return '+63$cleanNumber';
    }

    return cleanNumber;
  }

  bool _validateStep1() {
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
    if (!_agreedToTerms) {
      showErrorAlert('Please agree to the Terms of Service and Privacy Policy');
      return false;
    }
    return true;
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return cleanNumber.length >= 10 && cleanNumber.length <= 15;
  }

  Future<void> _submitProfile() async {
    if (!_validateStep2()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.pendingGoogleCredential == null) {
      showErrorAlert('Google authentication expired. Please try again.');
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppConstants.loginRoute, (route) => false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Format phone number for PHP
      final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());
      String phoneForApi = formattedPhone;
      if (phoneForApi.startsWith('+63')) {
        phoneForApi = '0${phoneForApi.substring(3)}';
      } else if (phoneForApi.startsWith('63')) {
        phoneForApi = '0${phoneForApi.substring(2)}';
      }

      final request = GoogleSignUpRequest(
        credential: authProvider.pendingGoogleCredential!,
        phoneNumber: phoneForApi,
        gender: _gender,
        province: _provinceController.text.trim(),
        cityMunicipality: _cityController.text.trim(),
        barangay: _barangayController.text.trim(),
        purok: _purokController.text.trim(),
      );

      final response = await authProvider.googleSignUpComplete(
        request,
        showGlobalLoading: false,
      );

      if (!mounted) return;

      if (response.isAuthenticated) {
        showSuccessAlert(response.message);
        await _handleSuccessfulLogin();
      } else if (response.isExists) {
        // User already exists - they're logged in
        showSuccessAlert('Account already exists. You are now logged in.');
        await _handleSuccessfulLogin();
      } else {
        showErrorAlert(response.message);
      }
    } catch (e) {
      debugPrint('Google Complete Profile error: $e');
      if (mounted) {
        showErrorAlert('Failed to create account. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSuccessfulLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<UserProfileProvider>(
      context,
      listen: false,
    );

    authProvider.setGlobalLoading(true);
    try {
      await profileProvider.loadProfileData();
      if (profileProvider.profile == null) {
        await profileProvider.loadProfileData();
      }
      await NotificationService.scheduleDailyNotificationCheck();
      if (mounted) {
        await _checkBatteryOptimizationAfterLogin();
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppConstants.homeRoute, (route) => false);
      }
    } finally {
      authProvider.setGlobalLoading(false);
    }
  }

  Future<void> _checkBatteryOptimizationAfterLogin() async {
    if (!Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final batteryCheckShown =
          prefs.getBool('battery_optimization_check_shown') ?? false;

      if (batteryCheckShown) return;

      final isBatteryOptimized =
          await NotificationService.isBatteryOptimizationDisabled();

      if (!isBatteryOptimized && mounted) {
        final shouldOpen = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.battery_alert, color: AppConstants.primaryGreen),
                const SizedBox(width: 12),
                const Expanded(child: Text('Battery Optimization')),
              ],
            ),
            content: const Text(
              'For notifications to work properly when the app is closed, '
              'please disable battery optimization for Ebakunado.\n\n'
              'This ensures you receive timely immunization reminders.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Remind Me Later'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
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
          await NotificationService.openSystemBatterySettings();
        }

        await prefs.setBool('battery_optimization_check_shown', true);
      }
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
    }
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Registration?'),
        content: const Text(
          'If you cancel, you will need to sign in with Google again to complete registration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Continue'),
          ),
          TextButton(
            onPressed: () {
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              authProvider.clearPendingGoogleData();
              Navigator.pop(context, true);
            },
            child: Text(
              'Yes, Cancel',
              style: TextStyle(color: AppConstants.errorRed),
            ),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final googleAccount = authProvider.pendingGoogleAccount;

    return buildWithAlerts(
      WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: AppConstants.backgroundWhite,
          appBar: AppBar(
            title: const Text('Complete Your Profile'),
            backgroundColor: AppConstants.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                final shouldPop = await _onWillPop();
                if (shouldPop && mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppConstants.loginRoute,
                    (route) => false,
                  );
                }
              },
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Google account info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: AppConstants.secondaryGray,
                  child: Row(
                    children: [
                      // Google profile picture
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: googleAccount?.photoUrl != null
                            ? NetworkImage(googleAccount!.photoUrl!)
                            : null,
                        backgroundColor: AppConstants.primaryGreen,
                        child: googleAccount?.photoUrl == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              googleAccount?.displayName ?? 'Google User',
                              style: AppConstants.bodyStyle.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              googleAccount?.email ?? '',
                              style: AppConstants.captionStyle.copyWith(
                                color: AppConstants.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.network(
                              'https://www.google.com/favicon.ico',
                              width: 16,
                              height: 16,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.g_mobiledata,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Google',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Stepper Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: (_currentStep + 1) / _totalSteps,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppConstants.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStepIndicator(0, 'Contact'),
                          _buildStepIndicator(1, 'Address'),
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
                          if (_currentStep == 0) _buildContactInfoStep(),
                          if (_currentStep == 1) _buildAddressInfoStep(),

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
                                  onPressed: _isLoading
                                      ? null
                                      : _currentStep == 0
                                      ? () {
                                          if (_validateStep1()) {
                                            _nextStep();
                                          }
                                        }
                                      : _submitProfile,
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
                                              ? 'Next'
                                              : 'Create Account',
                                          style: const TextStyle(fontSize: 16),
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

  Widget _buildContactInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Contact Information',
          style: AppConstants.headingStyle.copyWith(fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We need a few more details to complete your registration',
          style: AppConstants.bodyStyle.copyWith(
            color: AppConstants.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Phone Number
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
        ),

        const SizedBox(height: 24),

        // Info about Google data
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your name and email are from your Google account. You can update them later in settings.',
                  style: AppConstants.captionStyle.copyWith(
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Address Information',
          style: AppConstants.headingStyle.copyWith(fontSize: 20),
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
        const SizedBox(height: 24),

        // Province
        TextFormField(
          controller: _provinceController,
          decoration: const InputDecoration(
            labelText: 'Province',
            hintText: 'Enter province',
            prefixIcon: Icon(Icons.map),
          ),
          textCapitalization: TextCapitalization.words,
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
        ),
        const SizedBox(height: 16),

        // Purok / Street / Block (Optional)
        TextFormField(
          controller: _purokController,
          decoration: const InputDecoration(
            labelText: 'Purok / Street / Block (Optional)',
            hintText: 'Enter purok, street, or block',
            prefixIcon: Icon(Icons.place),
          ),
          textCapitalization: TextCapitalization.words,
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
          },
          onOpenTerms: () {
            // TODO: Open terms of service URL or PDF
          },
        ),
      ],
    );
  }
}
