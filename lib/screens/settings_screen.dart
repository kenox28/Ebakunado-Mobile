import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import '../services/api_client.dart';
import '../models/user_profile.dart';
import '../providers/user_profile_provider.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../mixins/animated_alert_mixin.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AnimatedAlertMixin {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  // Loading states
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isUploadingPhoto = false;

  // Profile data
  UserProfile? _profile;

  // Form controllers
  final _fnameController = TextEditingController();
  final _lnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _placeController = TextEditingController();
  final _philhealthController = TextEditingController();
  final _nhtsController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Form values
  String _gender = '';
  bool _showPasswordFields = false;
  File? _selectedPhoto;

  // Gender options
  final List<String> _genderOptions = ['', 'Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _fnameController.dispose();
    _lnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _placeController.dispose();
    _philhealthController.dispose();
    _nhtsController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWithAlerts(
      Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: AppConstants.primaryGreen,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: _isUpdating ? null : _updateProfile,
              icon: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              tooltip: 'Save Changes',
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load profile data',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfileData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notifications & Permissions entry
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings_applications),
                title: const Text('Notifications & Permissions'),
                subtitle: const Text('Set daily time and open phone settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/app-notifications'),
              ),
            ),

            // Profile Header Section
            _buildProfileHeader(),

            const SizedBox(height: 24),

            // Profile Form Section
            _buildProfileForm(),

            const SizedBox(height: 24),

            // Password Change Section
            _buildPasswordSection(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            // Profile Avatar with Camera Overlay
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppConstants.primaryGreen.withValues(
                    alpha: 0.1,
                  ),
                  backgroundImage: _selectedPhoto != null
                      ? FileImage(_selectedPhoto!)
                      : (_profile?.profileImg != null &&
                            _profile!.profileImg!.isNotEmpty)
                      ? NetworkImage(_profile!.profileImg!)
                      : null,
                  child:
                      _selectedPhoto == null &&
                          (_profile?.profileImg == null ||
                              _profile!.profileImg!.isEmpty)
                      ? const Icon(
                          Icons.person,
                          size: 40,
                          color: AppConstants.primaryGreen,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUploadingPhoto ? null : _showPhotoOptions,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppConstants.primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _isUploadingPhoto
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Display Information
            Text(
              _profile?.displayName ?? 'User',
              style: AppConstants.subheadingStyle.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppConstants.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _profile?.role.toUpperCase() ?? 'USER',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(_profile?.email ?? '', style: AppConstants.captionStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileForm() {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile Information',
              style: AppConstants.subheadingStyle.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Two-column responsive grid
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 400) {
                  // Stack vertically on small screens
                  return Column(
                    children: [
                      _buildTextFormField(
                        controller: _fnameController,
                        label: 'First Name *',
                        validator: _validateRequired,
                      ),
                      _buildTextFormField(
                        controller: _lnameController,
                        label: 'Last Name *',
                        validator: _validateRequired,
                      ),
                      _buildTextFormField(
                        controller: _emailController,
                        label: 'Email *',
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      _buildTextFormField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        keyboardType: TextInputType.phone,
                      ),
                      _buildDropdownField(
                        label: 'Gender',
                        value: _gender,
                        items: _genderOptions,
                        onChanged: (value) => setState(() => _gender = value!),
                      ),
                      _buildTextFormField(
                        controller: _placeController,
                        label: 'Place/Address',
                        hintText: 'e.g., Barangay Linao, Ormoc City',
                      ),
                      _buildTextFormField(
                        controller: _philhealthController,
                        label: 'PhilHealth No.',
                        hintText: 'Optional',
                      ),
                      _buildTextFormField(
                        controller: _nhtsController,
                        label: 'NHTS',
                        hintText: 'Optional (Yes/No or ID)',
                      ),
                    ],
                  );
                } else {
                  // Two-column layout on larger screens
                  return Column(
                    children: [
                      // Row 1: First Name, Last Name
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextFormField(
                              controller: _fnameController,
                              label: 'First Name *',
                              validator: _validateRequired,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextFormField(
                              controller: _lnameController,
                              label: 'Last Name *',
                              validator: _validateRequired,
                            ),
                          ),
                        ],
                      ),

                      // Row 2: Email, Phone Number
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextFormField(
                              controller: _emailController,
                              label: 'Email *',
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextFormField(
                              controller: _phoneController,
                              label: 'Phone Number',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),

                      // Row 3: Gender, Place/Address
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownField(
                              label: 'Gender',
                              value: _gender,
                              items: _genderOptions,
                              onChanged: (value) =>
                                  setState(() => _gender = value!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextFormField(
                              controller: _placeController,
                              label: 'Place/Address',
                              hintText: 'e.g., Barangay Linao, Ormoc City',
                            ),
                          ),
                        ],
                      ),

                      // Row 4: PhilHealth No., NHTS
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextFormField(
                              controller: _philhealthController,
                              label: 'PhilHealth No.',
                              hintText: 'Optional',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextFormField(
                              controller: _nhtsController,
                              label: 'NHTS',
                              hintText: 'Optional (Yes/No or ID)',
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: const BorderSide(color: AppConstants.primaryGreen, width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          color: AppConstants.secondaryGray.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock, color: AppConstants.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  'Change Password',
                  style: AppConstants.subheadingStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryGreen,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _showPasswordFields,
                  onChanged: (value) {
                    setState(() {
                      _showPasswordFields = value;
                      if (!value) {
                        _currentPasswordController.clear();
                        _newPasswordController.clear();
                        _confirmPasswordController.clear();
                      }
                    });
                  },
                  activeColor: AppConstants.primaryGreen,
                ),
              ],
            ),

            if (_showPasswordFields) ...[
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _currentPasswordController,
                label: 'Current Password',
                obscureText: true,
                validator: _showPasswordFields ? _validateRequired : null,
              ),
              _buildTextFormField(
                controller: _newPasswordController,
                label: 'New Password',
                obscureText: true,
                validator: _showPasswordFields ? _validatePassword : null,
              ),
              _buildTextFormField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
                obscureText: true,
                validator: _showPasswordFields
                    ? _validateConfirmPassword
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            borderSide: const BorderSide(
              color: AppConstants.primaryBlue,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value.isEmpty ? null : value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            borderSide: const BorderSide(
              color: AppConstants.primaryBlue,
              width: 2,
            ),
          ),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item.isEmpty ? null : item,
            child: Text(item.isEmpty ? 'Select Gender' : item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // Validation methods
  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (_showPasswordFields && (value == null || value.trim().isEmpty)) {
      return 'New password is required';
    }
    if (value != null && value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_showPasswordFields && (value == null || value.trim().isEmpty)) {
      return 'Please confirm your new password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Photo picker methods
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedPhoto = File(image.path));
        _uploadProfilePhoto();
      }
    } catch (e) {
      showErrorAlert('Failed to pick image from camera: ${e.toString()}');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedPhoto = File(image.path));
        _uploadProfilePhoto();
      }
    } catch (e) {
      showErrorAlert('Failed to pick image from gallery: ${e.toString()}');
    }
  }

  // API methods
  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiClient.instance.getProfileData();

      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      final profileResponse = ProfileDataResponse.fromJson(responseData);

      if (profileResponse.success && profileResponse.profile != null) {
        setState(() {
          _profile = profileResponse.profile!;
          _populateForm();
          _isLoading = false;
        });

        // Update the profile provider
        final profileProvider = Provider.of<UserProfileProvider>(
          context,
          listen: false,
        );
        profileProvider.updateProfile(_profile!);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if (mounted) {
          ErrorHandler.handleError(
            context,
            AuthExpiredException('Session expired'),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) {
          ErrorHandler.handleError(context, e);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _populateForm() {
    if (_profile != null) {
      _fnameController.text = _profile!.fname;
      _lnameController.text = _profile!.lname;
      _emailController.text = _profile!.email;
      _phoneController.text = _profile!.phoneNumber ?? '';
      _gender = _profile!.gender ?? '';
      _placeController.text = _profile!.place ?? '';
      _philhealthController.text = _profile!.philhealthNo ?? '';
      _nhtsController.text = _profile!.nhts ?? '';
    }
  }

  Future<void> _uploadProfilePhoto() async {
    if (_selectedPhoto == null) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final response = await ApiClient.instance.uploadProfilePhoto(
        _selectedPhoto!,
      );

      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      final uploadResponse = PhotoUploadResponse.fromJson(responseData);

      if (uploadResponse.success) {
        showSuccessAlert('Profile photo updated successfully!');
        setState(() {
          _selectedPhoto = null; // Clear selected photo after successful upload
        });

        // Auto-refresh profile data
        await _loadProfileData();

        // Update the profile provider
        final profileProvider = Provider.of<UserProfileProvider>(
          context,
          listen: false,
        );
        profileProvider.refreshProfile();
      } else {
        showErrorAlert(uploadResponse.message);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if (mounted) {
          ErrorHandler.handleError(
            context,
            AuthExpiredException('Session expired'),
          );
        }
      } else {
        showErrorAlert('Network error. Please try again.');
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) {
          ErrorHandler.handleError(context, e);
        }
      } else {
        showErrorAlert('Failed to upload photo. Please try again.');
      }
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final updateRequest = ProfileUpdateRequest(
        fname: _fnameController.text.trim(),
        lname: _lnameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        gender: _gender.isEmpty ? null : _gender,
        place: _placeController.text.trim().isEmpty
            ? null
            : _placeController.text.trim(),
        philhealthNo: _philhealthController.text.trim().isEmpty
            ? null
            : _philhealthController.text.trim(),
        nhts: _nhtsController.text.trim().isEmpty
            ? null
            : _nhtsController.text.trim(),
        currentPassword: _showPasswordFields
            ? _currentPasswordController.text.trim()
            : null,
        newPassword: _showPasswordFields
            ? _newPasswordController.text.trim()
            : null,
        confirmPassword: _showPasswordFields
            ? _confirmPasswordController.text.trim()
            : null,
      );

      final response = await ApiClient.instance.updateProfile(
        updateRequest.toFormData(),
      );

      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      final updateResponse = ProfileUpdateResponse.fromJson(responseData);

      if (updateResponse.success) {
        showSuccessAlert(updateResponse.message);
        setState(() {
          if (_showPasswordFields) {
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _confirmPasswordController.clear();
            _showPasswordFields = false;
          }
        });

        // Auto-refresh profile data
        await _loadProfileData();

        // Update the profile provider
        final profileProvider = Provider.of<UserProfileProvider>(
          context,
          listen: false,
        );
        profileProvider.refreshProfile();
      } else {
        showErrorAlert(updateResponse.message);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if (mounted) {
          ErrorHandler.handleError(
            context,
            AuthExpiredException('Session expired'),
          );
        }
      } else {
        showErrorAlert('Network error. Please try again.');
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) {
          ErrorHandler.handleError(context, e);
        }
      } else {
        showErrorAlert('Failed to update profile. Please try again.');
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }
}
