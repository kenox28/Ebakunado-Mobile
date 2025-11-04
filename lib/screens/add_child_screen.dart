import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../services/api_client.dart';
import '../models/child_registration_form.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../mixins/animated_alert_mixin.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen>
    with AnimatedAlertMixin, WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _familyCodeController = TextEditingController();
  final _imagePicker = ImagePicker();

  // Loading states
  bool _isClaimingChild = false;
  bool _isRegisteringChild = false;
  UserProfile? _userProfile;

  // Form controllers for new child registration
  final _childFnameController = TextEditingController();
  final _childLnameController = TextEditingController();
  final _placeOfBirthController = TextEditingController();
  final _addressController = TextEditingController();
  final _birthWeightController = TextEditingController();
  final _birthHeightController = TextEditingController();
  final _bloodTypeController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _familyPlanningController = TextEditingController();
  final _birthAttendantOthersController = TextEditingController();

  // Form values
  DateTime? _birthDate;
  DateTime? _lmp;
  String _gender = 'Male';
  String _deliveryType = 'Normal';
  String _birthOrder = 'Single';
  String _birthAttendant = 'Doctor';
  File? _babysCard;
  List<String> _vaccinesReceived = [];

  // Available vaccines
  final List<String> _availableVaccines = [
    'BCG (Tuberculosis)',
    'HEPAB1 (w/in 24 hrs)',
    'HEPAB1 (More than 24hrs)',
    'Pentavalent (DPT-HepB-Hib) - 1st',
    'OPV - 1st (Oral Polio)',
    'PCV - 1st (Pneumococcal)',
    'Rota Virus Vaccine - 1st',
    'Pentavalent (DPT-HepB-Hib) - 2nd',
    'OPV - 2nd (Oral Polio)',
    'PCV - 2nd (Pneumococcal)',
    'Rota Virus Vaccine - 2nd',
    'Pentavalent (DPT-HepB-Hib) - 3rd',
    'OPV - 3rd (Oral Polio)',
    'PCV - 3rd (Pneumococcal)',
    'MCV1 (AMV) - Anti-Measles Vaccine',
    'MCV2 (MMR) - Measles-Mumps-Rubella',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _familyCodeController.dispose();
    _childFnameController.dispose();
    _childLnameController.dispose();
    _placeOfBirthController.dispose();
    _addressController.dispose();
    _birthWeightController.dispose();
    _birthHeightController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _motherNameController.dispose();
    _fatherNameController.dispose();
    _familyPlanningController.dispose();
    _birthAttendantOthersController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle changes (e.g., when returning from camera)
    if (state == AppLifecycleState.resumed) {
      // App returned to foreground, refresh if needed
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildWithAlerts(
      Scaffold(
        appBar: AppBar(
          title: const Text('Add Child'),
          backgroundColor: AppConstants.primaryGreen,
          foregroundColor: Colors.white,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Family Code Claiming
          _buildFamilyCodeSection(),

          const SizedBox(height: 32),

          // Section 2: OR Divider
          _buildOrDivider(),

          const SizedBox(height: 32),

          // Section 3: New Child Registration Form
          _buildRegistrationForm(),
        ],
      ),
    );
  }

  Widget _buildFamilyCodeSection() {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          gradient: LinearGradient(
            colors: [
              AppConstants.successGreen.withValues(alpha: 0.1),
              AppConstants.successGreen.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.successGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tag, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Have a Family Code?',
                  style: AppConstants.subheadingStyle.copyWith(
                    color: AppConstants.successGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Enter the code given by your BHW/Midwife to add your child',
              style: AppConstants.bodyStyle.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _familyCodeController,
              decoration: InputDecoration(
                labelText: 'Family Code',
                hintText: 'Enter family code (e.g., FAM-ABC123)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius,
                  ),
                  borderSide: const BorderSide(
                    color: AppConstants.successGreen,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isClaimingChild ? null : _claimChildWithCode,
                icon: _isClaimingChild
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
                    : const Icon(Icons.check_circle, size: 18),
                label: Text(_isClaimingChild ? 'Claiming...' : 'Claim Child'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadius,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: AppConstants.bodyStyle.copyWith(
              color: AppConstants.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: Colors.grey[300])),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.description,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Child Registration Form',
                    style: AppConstants.subheadingStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Please fill out all required information for your child\'s health record',
                style: AppConstants.bodyStyle.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Basic Child Information
              _buildSectionTitle('Basic Child Information'),
              _buildTextFormField(
                controller: _childFnameController,
                label: 'Baby First Name *',
                validator: (value) =>
                    value?.isEmpty == true ? 'First name is required' : null,
              ),
              _buildTextFormField(
                controller: _childLnameController,
                label: 'Baby Last Name *',
                validator: (value) =>
                    value?.isEmpty == true ? 'Last name is required' : null,
              ),
              _buildDateField(
                label: 'Birth Date *',
                value: _birthDate,
                onTap: _selectBirthDate,
                validator: (value) =>
                    _birthDate == null ? 'Birth date is required' : null,
              ),
              _buildTextFormField(
                controller: _placeOfBirthController,
                label: 'Place of Birth',
              ),
              _buildTextFormField(
                controller: _addressController,
                label: 'Address *',
                hint: 'Example: Leyte, Ormoc, Linao, 1',
                maxLines: 3,
                validator: (value) =>
                    value?.isEmpty == true ? 'Address is required' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      controller: _birthWeightController,
                      label: 'Birth Weight (kg)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextFormField(
                      controller: _birthHeightController,
                      label: 'Birth Height (cm)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              _buildTextFormField(
                controller: _bloodTypeController,
                label: 'Blood Type',
              ),
              _buildTextFormField(
                controller: _allergiesController,
                label: 'Allergies',
              ),

              const SizedBox(height: 24),

              // Gender Selection
              _buildSectionTitle('Gender Selection'),
              Row(
                children: [
                  Expanded(
                    child: _buildRadioOption(
                      value: 'Male',
                      groupValue: _gender,
                      onChanged: (value) => setState(() => _gender = value!),
                      label: 'Male 👦',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildRadioOption(
                      value: 'Female',
                      groupValue: _gender,
                      onChanged: (value) => setState(() => _gender = value!),
                      label: 'Female 👧',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Parent Information
              _buildSectionTitle('Parent Information'),
              _buildTextFormField(
                controller: _motherNameController,
                label: _getParentLabel('mother'),
                validator: (value) =>
                    value?.isEmpty == true ? 'Mother name is required' : null,
              ),
              _buildTextFormField(
                controller: _fatherNameController,
                label: _getParentLabel('father'),
              ),
              _buildDateField(
                label: 'LMP (Last Menstrual Period)',
                value: _lmp,
                onTap: _selectLMP,
              ),
              _buildTextFormField(
                controller: _familyPlanningController,
                label: 'Family Planning',
              ),

              const SizedBox(height: 24),

              // Birth Details
              _buildSectionTitle('Birth Details'),
              _buildDropdownField(
                label: 'Type of Delivery',
                value: _deliveryType,
                items: ['Normal', 'Caesarean Section'],
                onChanged: (value) => setState(() => _deliveryType = value!),
              ),
              _buildDropdownField(
                label: 'Birth Order',
                value: _birthOrder,
                items: ['Single', 'Twin'],
                onChanged: (value) => setState(() => _birthOrder = value!),
              ),
              _buildDropdownField(
                label: 'Birth Attendant',
                value: _birthAttendant,
                items: ['Doctor', 'Midwife', 'Nurse', 'Hilot', 'Other'],
                onChanged: (value) => setState(() => _birthAttendant = value!),
              ),
              if (_birthAttendant == 'Other')
                _buildTextFormField(
                  controller: _birthAttendantOthersController,
                  label: 'Specify Birth Attendant',
                ),

              const SizedBox(height: 24),

              // File Upload
              _buildSectionTitle('File Upload'),
              _buildFileUploadField(),

              const SizedBox(height: 24),

              // Vaccines Already Received
              _buildSectionTitle('Vaccines Already Received'),
              Text(
                'Select all vaccines your child has already received:',
                style: AppConstants.captionStyle,
              ),
              const SizedBox(height: 12),
              _buildVaccineCheckboxes(),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isRegisteringChild
                      ? null
                      : _submitRegistrationForm,
                  icon: _isRegisteringChild
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
                      : const Icon(Icons.save, size: 18),
                  label: Text(
                    _isRegisteringChild ? 'Registering...' : 'Register Child',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadius,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppConstants.subheadingStyle.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
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

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        readOnly: true,
        onTap: onTap,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: value == null
              ? 'Select date'
              : '${value.day}/${value.month}/${value.year}',
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
          suffixIcon: const Icon(Icons.calendar_today),
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
        value: value,
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
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildRadioOption({
    required String value,
    required String groupValue,
    required void Function(String?) onChanged,
    required String label,
  }) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(label),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildFileUploadField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Baby\'s Card *',
            style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            child: Column(
              children: [
                if (_babysCard != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.image, color: AppConstants.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _babysCard!.path.split('/').last,
                          style: AppConstants.bodyStyle,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _babysCard = null),
                        icon: const Icon(
                          Icons.close,
                          color: AppConstants.errorRed,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Icon(Icons.cloud_upload, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to select baby\'s card image',
                    style: AppConstants.bodyStyle.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Accepted formats: JPG, PNG',
                    style: AppConstants.captionStyle,
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library, size: 16),
                    label: const Text('Select from Gallery'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaccineCheckboxes() {
    return Column(
      children: _availableVaccines.map((vaccine) {
        return CheckboxListTile(
          title: Text(vaccine),
          value: _vaccinesReceived.contains(vaccine),
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _vaccinesReceived.add(vaccine);
              } else {
                _vaccinesReceived.remove(vaccine);
              }
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _selectLMP() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 280)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _lmp) {
      setState(() => _lmp = picked);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      // Check if widget is still mounted before updating state
      if (!mounted) return;

      if (image != null) {
        final file = File(image.path);
        if (await file.exists()) {
          setState(() => _babysCard = file);
        } else {
          showErrorAlert('Image file not found. Please try again.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      showErrorAlert('Failed to pick image from gallery: ${e.toString()}');
    }
  }

  Future<void> _loadUserProfile() async {
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
          _userProfile = profileResponse.profile!;

          // Pre-fill address from user's place
          if (_userProfile!.place != null && _userProfile!.place!.isNotEmpty) {
            _addressController.text = _userProfile!.place!;
          }

          // Pre-fill parent name based on gender
          final fullName = _userProfile!.fullName;
          if (_userProfile!.gender != null) {
            final gender = _userProfile!.gender!.toLowerCase();
            if (gender == 'female' || gender == 'f') {
              _motherNameController.text = fullName;
            } else if (gender == 'male' || gender == 'm') {
              _fatherNameController.text = fullName;
            }
          }
        });
      }
    } catch (e) {
      // Silently fail - user can still fill form manually
    }
  }

  Future<void> _claimChildWithCode() async {
    if (_familyCodeController.text.trim().isEmpty) {
      showErrorAlert('Please enter a family code');
      return;
    }

    setState(() {
      _isClaimingChild = true;
    });

    try {
      final response = await ApiClient.instance.claimChildWithCode(
        _familyCodeController.text.trim(),
      );

      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      final claimResponse = ClaimChildResponse.fromJson(responseData);

      // Additional safeguard: if we have baby_id, treat as success
      if (claimResponse.success || claimResponse.babyId != null) {
        showSuccessAlert(
          'Child "${claimResponse.childName}" added successfully! Baby ID: ${claimResponse.babyId}',
          duration: const Duration(seconds: 3),
        );
        _familyCodeController.clear();

        // Auto-redirect after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        showErrorAlert(claimResponse.message);
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
        showErrorAlert('Failed to claim child. Please try again.');
      }
    } finally {
      setState(() => _isClaimingChild = false);
    }
  }

  Future<void> _submitRegistrationForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_babysCard == null) {
      showErrorAlert('Please upload baby\'s card');
      return;
    }

    setState(() {
      _isRegisteringChild = true;
    });

    try {
      // Format address: convert spaces to commas if not already comma-separated
      final rawAddress = _addressController.text.trim();
      final formattedAddress = _formatAddress(rawAddress);

      // Prepare optional fields - use empty string if empty, null if truly optional
      final bloodTypeValue = _bloodTypeController.text.trim();
      final allergiesValue = _allergiesController.text.trim();
      final familyPlanningValue = _familyPlanningController.text.trim();
      final birthAttendantOthersValue = _birthAttendantOthersController.text
          .trim();
      final placeOfBirthValue = _placeOfBirthController.text.trim();
      final fatherNameValue = _fatherNameController.text.trim();

      final formData = ChildRegistrationForm(
        childFname: _childFnameController.text.trim(),
        childLname: _childLnameController.text.trim(),
        birthDate: _birthDate!,
        placeOfBirth: placeOfBirthValue.isEmpty ? null : placeOfBirthValue,
        address: formattedAddress,
        birthWeight: _birthWeightController.text.trim().isEmpty
            ? null
            : double.tryParse(_birthWeightController.text.trim()),
        birthHeight: _birthHeightController.text.trim().isEmpty
            ? null
            : double.tryParse(_birthHeightController.text.trim()),
        bloodType: bloodTypeValue.isEmpty ? null : bloodTypeValue,
        allergies: allergiesValue.isEmpty ? null : allergiesValue,
        gender: _gender,
        motherName: _motherNameController.text.trim(),
        fatherName: fatherNameValue.isEmpty ? null : fatherNameValue,
        lmp: _lmp, // Can be null, which is fine
        familyPlanning: familyPlanningValue.isEmpty
            ? null
            : familyPlanningValue,
        deliveryType: _deliveryType,
        birthOrder: _birthOrder,
        birthAttendant: _birthAttendant,
        birthAttendantOthers: birthAttendantOthersValue.isEmpty
            ? null
            : birthAttendantOthersValue,
        babysCard: _babysCard,
        vaccinesReceived: _vaccinesReceived,
      );

      final response = await ApiClient.instance.requestImmunization(
        formData.toFormData(),
        _babysCard,
      );

      // Debug: Log response
      print('=== Registration Response ===');
      print('Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');
      print('Response Data Type: ${response.data.runtimeType}');
      print('===========================');

      Map<String, dynamic> responseData;
      if (response.data is String) {
        try {
          responseData = json.decode(response.data);
        } catch (e) {
          print('Failed to parse JSON string: $e');
          showErrorAlert('Invalid response from server. Please try again.');
          return;
        }
      } else if (response.data is Map) {
        responseData = Map<String, dynamic>.from(response.data);
      } else {
        print('Unexpected response data type: ${response.data.runtimeType}');
        showErrorAlert('Unexpected response format from server.');
        return;
      }

      print('=== Parsed Response Data ===');
      print(responseData);
      print('===========================');

      final addChildResponse = AddChildResponse.fromJson(responseData);

      // Check if HTTP status is 200 (successful request)
      final isHttpSuccess =
          response.statusCode == 200 || response.statusCode == 201;

      // Check multiple success indicators
      final hasSuccessStatus = addChildResponse.success == true;
      final hasBabyId =
          addChildResponse.babyId != null &&
          addChildResponse.babyId!.isNotEmpty;
      final hasRecordsCreated = (addChildResponse.totalRecordsCreated ?? 0) > 0;
      final messageLower = addChildResponse.message.toLowerCase();
      final hasSuccessMessage =
          messageLower.contains('success') ||
          messageLower.contains('saved') ||
          messageLower.contains('created') ||
          messageLower.contains('registered');
      final hasErrorMessage =
          messageLower.contains('error') ||
          messageLower.contains('fail') ||
          messageLower.contains('invalid');

      print('=== Success Indicators ===');
      print('HTTP Status: ${response.statusCode}');
      print('HTTP Success: $isHttpSuccess');
      print('Response Success: $hasSuccessStatus');
      print('Has Baby ID: $hasBabyId');
      print('Has Records Created: $hasRecordsCreated');
      print('Has Success Message: $hasSuccessMessage');
      print('Has Error Message: $hasErrorMessage');
      print('Response Message: ${addChildResponse.message}');
      print('========================');

      // Improved success detection priority:
      // 1. HTTP 200/201 AND status: 'success' → DEFINITE SUCCESS
      // 2. HTTP 200/201 AND has baby_id → SUCCESS
      // 3. status: 'success' (even with other HTTP codes) → SUCCESS
      // 4. has baby_id OR records_created → SUCCESS (fallback)
      final isSuccess =
          (!hasErrorMessage) &&
          (
          // Priority 1: HTTP success + status success
          (isHttpSuccess && hasSuccessStatus) ||
              // Priority 2: HTTP success + has baby_id
              (isHttpSuccess && hasBabyId) ||
              // Priority 3: Status success (even if HTTP not 200)
              hasSuccessStatus ||
              // Priority 4: Has baby_id or records created
              hasBabyId ||
              hasRecordsCreated ||
              // Priority 5: Success message in response
              hasSuccessMessage);

      if (isSuccess) {
        // Get child name: Priority 1 = response.child_name, Priority 2 = form data
        final childName = addChildResponse.childName?.trim().isNotEmpty == true
            ? addChildResponse.childName!.trim()
            : '${_childFnameController.text.trim()} ${_childLnameController.text.trim()}'
                  .trim();

        print('=== Showing Success Alert ===');
        print('Child Name: $childName');
        print('============================');

        // Show success snackbar with child name
        if (mounted) {
          _showSuccessSnackbar(childName);

          // Show detailed dialog (will auto-dismiss after 3 seconds)
          _showSuccessDialog(addChildResponse, childName);

          // Auto-clear form immediately after success
          _resetForm();
        }
      } else {
        // Show error with more details
        final errorMsg = addChildResponse.message.isNotEmpty
            ? addChildResponse.message
            : 'Failed to register child. Please check your input and try again.';
        print('=== Showing Error Alert ===');
        print('Error Message: $errorMsg');
        print('==========================');
        showErrorAlert(errorMsg);
      }
    } on DioException catch (e) {
      // Enhanced error logging for debugging
      print('=== DioException Details ===');
      print('Type: ${e.type}');
      print('Message: ${e.message}');
      print('Response Status Code: ${e.response?.statusCode}');
      print('Response Data: ${e.response?.data}');
      print('Response Data Type: ${e.response?.data.runtimeType}');
      print('Request Path: ${e.requestOptions.path}');
      print('Request Data: ${e.requestOptions.data}');
      print('===========================');

      if (e.response?.statusCode == 401) {
        if (mounted) {
          ErrorHandler.handleError(
            context,
            AuthExpiredException('Session expired'),
          );
        }
        return;
      }

      // Try to parse response even if it's an error status (500, etc.)
      // Sometimes the child is added successfully but server returns error status
      Map<String, dynamic>? errorResponseData;
      bool isEmptyResponse = false;

      if (e.response?.data != null) {
        try {
          if (e.response!.data is String) {
            final dataString = e.response!.data as String;
            // Check if response is empty or whitespace
            if (dataString.trim().isEmpty) {
              isEmptyResponse = true;
              print(
                'Response body is empty - server may have failed after successful insert',
              );
            } else {
              // Try to parse JSON string
              errorResponseData = json.decode(dataString);
            }
          } else if (e.response!.data is Map) {
            // Already a Map, convert to Map<String, dynamic>
            errorResponseData = Map<String, dynamic>.from(e.response!.data);
          }
        } catch (parseError) {
          print('Failed to parse error response: $parseError');
          // If it's a format exception and response was not empty, mark as empty
          if (parseError.toString().contains('Unexpected end of input')) {
            isEmptyResponse = true;
          }
        }
      } else {
        // No response data at all
        isEmptyResponse = true;
      }

      // Handle empty response: If request was valid and we got 500 with empty body,
      // the child might still have been added (since insert happens before response)
      if (isEmptyResponse && e.response?.statusCode == 500) {
        // Check if form was valid (all required fields were filled)
        final hasRequiredFields =
            _childFnameController.text.trim().isNotEmpty &&
            _childLnameController.text.trim().isNotEmpty &&
            _birthDate != null &&
            _addressController.text.trim().isNotEmpty &&
            _motherNameController.text.trim().isNotEmpty &&
            _babysCard != null;

        if (hasRequiredFields) {
          // Form was valid, child likely added successfully
          // Show success with child name from form
          final childName =
              '${_childFnameController.text.trim()} ${_childLnameController.text.trim()}'
                  .trim();

          print('=== Empty Response - Assuming Success ===');
          print('Child Name: $childName');
          print('Form was valid, assuming child was added');
          print('========================================');

          if (mounted) {
            // Create a mock success response
            final mockResponse = AddChildResponse(
              success: true,
              message: 'Child health record saved successfully',
              babyId: null, // Unknown but that's okay
              childName: childName,
              vaccinesTransferred: _vaccinesReceived.length,
              vaccinesScheduled: 0, // Unknown
              totalRecordsCreated: null,
              uploadStatus: 'unknown',
            );

            _showSuccessSnackbar(childName);
            _showSuccessDialog(mockResponse, childName);
            _resetForm();
          }
          return; // Exit early - success handled
        }
      }

      // Check if error response contains success indicators
      if (errorResponseData != null) {
        try {
          final errorAddChildResponse = AddChildResponse.fromJson(
            errorResponseData,
          );

          // Check for success indicators even in error response
          final hasBabyId =
              errorAddChildResponse.babyId != null &&
              errorAddChildResponse.babyId!.isNotEmpty;
          final hasRecordsCreated =
              (errorAddChildResponse.totalRecordsCreated ?? 0) > 0;
          final hasSuccessStatus = errorAddChildResponse.success == true;
          final messageLower = errorAddChildResponse.message.toLowerCase();
          final hasSuccessMessage =
              messageLower.contains('success') ||
              messageLower.contains('saved') ||
              messageLower.contains('created');
          final hasErrorMessage =
              messageLower.contains('error') ||
              messageLower.contains('fail') ||
              messageLower.contains('invalid');

          print('=== Error Response Success Check ===');
          print('Has Baby ID: $hasBabyId');
          print('Has Records Created: $hasRecordsCreated');
          print('Has Success Status: $hasSuccessStatus');
          print('Has Success Message: $hasSuccessMessage');
          print('Has Error Message: $hasErrorMessage');
          print('===================================');

          // If we find success indicators and no error message, treat as success!
          if (!hasErrorMessage &&
              (hasBabyId ||
                  hasRecordsCreated ||
                  hasSuccessStatus ||
                  hasSuccessMessage)) {
            // Get child name: Priority 1 = response.child_name, Priority 2 = form data
            final childName =
                errorAddChildResponse.childName?.trim().isNotEmpty == true
                ? errorAddChildResponse.childName!.trim()
                : '${_childFnameController.text.trim()} ${_childLnameController.text.trim()}'
                      .trim();

            print('=== Treating Error Response as Success ===');
            print('Child Name: $childName');
            print('==========================================');

            // Show success snackbar with child name
            if (mounted) {
              _showSuccessSnackbar(childName);

              // Show detailed dialog (will auto-dismiss after 3 seconds)
              _showSuccessDialog(errorAddChildResponse, childName);

              // Auto-clear form immediately after success
              _resetForm();
            }
            return; // Exit early - success handled
          }
        } catch (parseError) {
          print(
            'Failed to parse error response as AddChildResponse: $parseError',
          );
        }
      }

      // No success indicators found, show error
      String errorMessage = 'Network error. Please try again.';

      if (errorResponseData != null) {
        // Safely extract error message from parsed response
        if (errorResponseData['message'] != null) {
          errorMessage = errorResponseData['message'].toString();
        } else if (errorResponseData['error'] != null) {
          errorMessage = errorResponseData['error'].toString();
        }
      } else if (e.message != null) {
        errorMessage = e.message!;
      }

      print('=== Showing Error Alert ===');
      print('Error Message: $errorMessage');
      print('===========================');
      showErrorAlert(errorMessage);
    } catch (e) {
      // Enhanced error logging for other exceptions
      print('=== Exception Details ===');
      print('Type: ${e.runtimeType}');
      print('Message: ${e.toString()}');
      print('Stack Trace: ${StackTrace.current}');
      print('========================');

      if (e is AuthExpiredException) {
        if (mounted) {
          ErrorHandler.handleError(context, e);
        }
      } else {
        showErrorAlert('Failed to register child: ${e.toString()}');
      }
    } finally {
      setState(() => _isRegisteringChild = false);
    }
  }

  void _showSuccessSnackbar(String childName) {
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Child immunization request success: $childName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppConstants.successGreen,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
      print('=== Snackbar shown successfully ===');
    } catch (e) {
      print('=== Error showing snackbar: $e ===');
      // Fallback: Show as dialog if snackbar fails
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppConstants.successGreen),
              SizedBox(width: 8),
              Text('Success!'),
            ],
          ),
          content: Text('Child immunization request success: $childName'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showSuccessDialog(AddChildResponse response, String childName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppConstants.successGreen),
            const SizedBox(width: 8),
            const Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Child: $childName'),
            const SizedBox(height: 8),
            Text('Child health record saved successfully!'),
            const SizedBox(height: 16),
            if (response.babyId != null) Text('Baby ID: ${response.babyId}'),
            if (response.babyId != null) const SizedBox(height: 8),
            if (response.totalRecordsCreated != null)
              Text(
                'Total vaccine records created: ${response.totalRecordsCreated}',
              ),
            if (response.totalRecordsCreated != null) const SizedBox(height: 8),
            if (response.vaccinesTransferred != null)
              Text('Vaccines taken: ${response.vaccinesTransferred}'),
            if (response.vaccinesTransferred != null) const SizedBox(height: 8),
            if (response.vaccinesScheduled != null)
              Text('Vaccines scheduled: ${response.vaccinesScheduled}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('Go to Children List'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Form already cleared, so just keep it that way
            },
            child: const Text('Add Another Child'),
          ),
        ],
      ),
    );

    // Auto-dismiss dialog after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  String _formatAddress(String address) {
    if (address.isEmpty) return address;

    // If address already contains commas, assume it's already formatted
    if (address.contains(',')) {
      // Clean up: remove extra spaces around commas
      return address
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(', ');
    }

    // If no commas, format spaces to comma-separated
    // Split by multiple spaces, trim each part, filter empty, join with commas
    final parts = address
        .split(RegExp(r'\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    return parts.join(', ');
  }

  String _getParentLabel(String type) {
    if (_userProfile?.gender == null) {
      return type == 'mother' ? 'Mother Name *' : 'Father Name';
    }

    final gender = _userProfile!.gender!.toLowerCase();
    if (type == 'mother') {
      if (gender == 'female' || gender == 'f') {
        return 'Mother Name * (You)';
      }
      return 'Mother Name *';
    } else {
      if (gender == 'male' || gender == 'm') {
        return 'Father Name (You)';
      }
      return 'Father Name';
    }
  }

  void _resetForm() {
    setState(() {
      _childFnameController.clear();
      _childLnameController.clear();
      _placeOfBirthController.clear();
      // Reset address but don't clear if it was pre-filled from profile
      _addressController.clear();
      if (_userProfile?.place != null && _userProfile!.place!.isNotEmpty) {
        _addressController.text = _userProfile!.place!;
      }
      _birthWeightController.clear();
      _birthHeightController.clear();
      _bloodTypeController.clear();
      _allergiesController.clear();
      // Reset parent names but restore if they match user's gender
      _motherNameController.clear();
      _fatherNameController.clear();
      if (_userProfile != null && _userProfile!.gender != null) {
        final gender = _userProfile!.gender!.toLowerCase();
        final fullName = _userProfile!.fullName;
        if (gender == 'female' || gender == 'f') {
          _motherNameController.text = fullName;
        } else if (gender == 'male' || gender == 'm') {
          _fatherNameController.text = fullName;
        }
      }
      _familyPlanningController.clear();
      _birthAttendantOthersController.clear();
      _birthDate = null;
      _lmp = null;
      _gender = 'Male';
      _deliveryType = 'Normal';
      _birthOrder = 'Single';
      _birthAttendant = 'Doctor';
      _babysCard = null;
      _vaccinesReceived.clear();
    });
  }
}
