import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import '../services/api_client.dart';
import '../models/child_registration_form.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../utils/vaccine_catalog.dart';
import '../mixins/animated_alert_mixin.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_drawer.dart';

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
  bool _isLinkingChild = false;
  bool _isRegisteringChild = false;
  UserProfile? _userProfile;

  // Form controllers for new child registration
  final _childFnameController = TextEditingController();
  final _childLnameController = TextEditingController();
  final _placeOfBirthController = TextEditingController();
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _barangayController = TextEditingController();
  final _purokController = TextEditingController();
  final _birthWeightController = TextEditingController();
  final _birthHeightController = TextEditingController();
  final _bloodTypeController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _familyPlanningController = TextEditingController();
  final _birthAttendantOthersController = TextEditingController();
  final _placeNewbornScreeningController = TextEditingController();

  // Form values
  DateTime? _birthDate;
  DateTime? _lmp;
  DateTime? _newbornScreeningDate;
  String _gender = 'Male';
  String _deliveryType = 'Normal';
  String _birthOrder = 'Single';
  String _birthAttendant = 'Doctor';
  String? _bloodType;
  File? _babysCard;
  final Set<String> _vaccinesReceived = {};

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
    _provinceController.dispose();
    _cityController.dispose();
    _barangayController.dispose();
    _purokController.dispose();
    _birthWeightController.dispose();
    _birthHeightController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _motherNameController.dispose();
    _fatherNameController.dispose();
    _familyPlanningController.dispose();
    _birthAttendantOthersController.dispose();
    _placeNewbornScreeningController.dispose();
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
        drawer: const AppDrawer(),
        body: _buildBody(),
        bottomNavigationBar: const AppBottomNavigation(
          current: BottomNavDestination.addChild,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Family Code Linking
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
              'Enter the code shared by your BHW/Midwife to add your child',
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
                onPressed: _isLinkingChild ? null : _startLinkChildFlow,
                icon: _isLinkingChild
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
                    : const Icon(Icons.link, size: 18),
                label: Text(_isLinkingChild ? 'Adding...' : 'Add Child'),
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
                label: 'Place of Birth *',
                validator: (value) => value?.trim().isEmpty == true
                    ? 'Place of birth is required'
                    : null,
              ),
              _buildTextFormField(
                controller: _provinceController,
                label: 'Province *',
                hint: 'Enter province',
                textCapitalization: TextCapitalization.words,
                validator: (value) => value?.trim().isEmpty == true
                    ? 'Province is required'
                    : null,
              ),
              _buildTextFormField(
                controller: _cityController,
                label: 'City / Municipality *',
                hint: 'Enter city or municipality',
                textCapitalization: TextCapitalization.words,
                validator: (value) => value?.trim().isEmpty == true
                    ? 'City / Municipality is required'
                    : null,
              ),
              _buildTextFormField(
                controller: _barangayController,
                label: 'Barangay *',
                hint: 'Enter barangay',
                textCapitalization: TextCapitalization.words,
                validator: (value) => value?.trim().isEmpty == true
                    ? 'Barangay is required'
                    : null,
              ),
              _buildTextFormField(
                controller: _purokController,
                label: 'Purok / Street / Block *',
                hint: 'Enter purok, street, or block',
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Purok is required' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      controller: _birthWeightController,
                      label: 'Birth Weight (kg) *',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Birth weight is required';
                        }
                        final v = double.tryParse(value);
                        if (v == null || v <= 0) {
                          return 'Enter a valid weight';
                        }
                        if (v < 0.5 || v > 10.0) {
                          return 'Weight must be between 0.5 and 10.0 kg';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextFormField(
                      controller: _birthHeightController,
                      label: 'Birth Height (cm) *',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Birth height is required';
                        }
                        final v = double.tryParse(value);
                        if (v == null || v <= 0) {
                          return 'Enter a valid height';
                        }
                        if (v < 25 || v > 70) {
                          return 'Height must be between 25 and 70 cm';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              _buildDropdownField(
                label: 'Blood Type',
                value: _bloodType,
                items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                onChanged: (value) => setState(() => _bloodType = value),
                hint: 'Select blood type (optional)',
              ),
              _buildTextFormField(
                controller: _allergiesController,
                label: 'Allergies',
                hint: 'Enter allergies (optional)',
              ),
              _buildDateField(
                label: 'Date of Newborn Screening',
                value: _newbornScreeningDate,
                onTap: _selectNewbornScreeningDate,
                optionalHint: 'Select date (optional)',
              ),
              _buildTextFormField(
                controller: _placeNewbornScreeningController,
                label: 'Place of Newborn Screening',
                hint: 'Enter place (optional)',
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
                label: '${_getParentLabel('mother')} *',
                validator: (value) =>
                    value?.isEmpty == true ? 'Mother name is required' : null,
              ),
              _buildTextFormField(
                controller: _fatherNameController,
                label: '${_getParentLabel('father')} *',
                validator: (value) => value?.trim().isEmpty == true
                    ? 'Father name is required'
                    : null,
              ),
              _buildDateField(
                label: 'LMP (Last Menstrual Period)',
                value: _lmp,
                onTap: _selectLMP,
                optionalHint: 'Select date (optional)',
              ),
              _buildTextFormField(
                controller: _familyPlanningController,
                label: 'Family Planning',
                hint: 'Enter family planning method (optional)',
              ),

              const SizedBox(height: 24),

              // Birth Details
              _buildSectionTitle('Birth Details'),
              _buildDropdownField(
                label: 'Type of Delivery *',
                value: _deliveryType,
                items: const ['Normal', 'Caesarean Section'],
                onChanged: (value) => setState(() => _deliveryType = value!),
                validator: (value) => value == null || value.isEmpty
                    ? 'Type of delivery is required'
                    : null,
              ),
              _buildDropdownField(
                label: 'Birth Order *',
                value: _birthOrder,
                items: const ['Single', 'Twin'],
                onChanged: (value) => setState(() => _birthOrder = value!),
                validator: (value) => value == null || value.isEmpty
                    ? 'Birth order is required'
                    : null,
              ),
              _buildDropdownField(
                label: 'Birth Attendant *',
                value: _birthAttendant,
                items: const ['Doctor', 'Midwife', 'Nurse', 'Hilot', 'Other'],
                onChanged: (value) => setState(() => _birthAttendant = value!),
                validator: (value) => value == null || value.isEmpty
                    ? 'Birth attendant is required'
                    : null,
              ),
              if (_birthAttendant == 'Other')
                _buildTextFormField(
                  controller: _birthAttendantOthersController,
                  label: 'Specify Birth Attendant *',
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Please specify birth attendant'
                      : null,
                ),

              const SizedBox(height: 24),

              // File Upload
              _buildSectionTitle('File Upload'),
              _buildFileUploadField(),

              const SizedBox(height: 24),

              // Vaccines Already Received (using VaccineCatalog)
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
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
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
    String? optionalHint,
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
              ? (optionalHint ?? 'Select date')
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
    String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        validator: validator,
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
      children: VaccineCatalog.options.map((vaccine) {
        return CheckboxListTile(
          title: Text(vaccine.displayLabel),
          subtitle: vaccine.description != null
              ? Text(vaccine.description!, style: AppConstants.captionStyle)
              : null,
          value: _vaccinesReceived.contains(vaccine.payloadName),
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _vaccinesReceived.add(vaccine.payloadName);
              } else {
                _vaccinesReceived.remove(vaccine.payloadName);
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
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31), // Allow up to end of next year
    );
    if (picked != null && picked != _birthDate) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _selectLMP() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 280)),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31), // Allow up to end of next year
    );
    if (picked != null && picked != _lmp) {
      setState(() => _lmp = picked);
    }
  }

  Future<void> _selectNewbornScreeningDate() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31), // Allow up to end of next year
    );
    if (picked != null && picked != _newbornScreeningDate) {
      setState(() => _newbornScreeningDate = picked);
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
          _prefillAddressFields(_userProfile!.place);

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

  Future<void> _startLinkChildFlow() async {
    final code = _familyCodeController.text.trim();
    if (code.isEmpty) {
      showErrorAlert('Please enter a family code');
      return;
    }

    setState(() => _isLinkingChild = true);

    ClaimChildResult? previewResult;
    try {
      previewResult = await ApiClient.instance.previewChildByCode(code);
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
      return;
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) {
          ErrorHandler.handleError(context, e);
        }
      } else {
        showErrorAlert('Unable to verify family code. Please try again.');
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isLinkingChild = false);
      }
    }

    if (!previewResult.isSuccess) {
      showErrorAlert(previewResult.message);
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Child?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Child: ${previewResult!.childName ?? 'Unknown'}',
                style: AppConstants.subheadingStyle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (previewResult.babyId != null &&
                  previewResult.babyId!.trim().isNotEmpty)
                Text('Baby ID: ${previewResult.babyId}'),
              const SizedBox(height: 12),
              const Text(
                'Please confirm you want to Add this child to your account.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add Child'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _linkChildRecord(code);
    }
  }

  Future<void> _linkChildRecord(String code) async {
    setState(() => _isLinkingChild = true);

    try {
      final result = await ApiClient.instance.claimChildWithCode(code);

      if (result.isSuccess) {
        showSuccessAlert(
          'Child "${result.childName ?? 'Child'}" added successfully! Baby ID: ${result.babyId ?? 'N/A'}',
          duration: const Duration(seconds: 3),
        );
        _familyCodeController.clear();

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } else {
        showErrorAlert(result.message);
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
        showErrorAlert('Failed to add child. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLinkingChild = false);
      }
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
      final formattedAddress = _composeAddress();

      final dateFormatter = DateFormat('yyyy-MM-dd');

      final request = ChildRegistrationRequest(
        childFname: _childFnameController.text.trim(),
        childLname: _childLnameController.text.trim(),
        childGender: _gender,
        childBirthDate: dateFormatter.format(_birthDate!),
        childAddress: formattedAddress,
        placeOfBirth: _placeOfBirthController.text.trim().isEmpty
            ? null
            : _placeOfBirthController.text.trim(),
        motherName: _motherNameController.text.trim().isEmpty
            ? null
            : _motherNameController.text.trim(),
        fatherName: _fatherNameController.text.trim().isEmpty
            ? null
            : _fatherNameController.text.trim(),
        birthWeight: _birthWeightController.text.trim().isEmpty
            ? null
            : _birthWeightController.text.trim(),
        birthHeight: _birthHeightController.text.trim().isEmpty
            ? null
            : _birthHeightController.text.trim(),
        birthAttendant: _birthAttendant == 'Other'
            ? _birthAttendantOthersController.text.trim()
            : _birthAttendant,
        birthAttendantOthers: _birthAttendant == 'Other'
            ? _birthAttendantOthersController.text.trim()
            : null,
        deliveryType: _deliveryType,
        birthOrder: _birthOrder,
        bloodType: _bloodType,
        allergies: _allergiesController.text.trim().isEmpty
            ? null
            : _allergiesController.text.trim(),
        lpm: _lmp != null ? dateFormatter.format(_lmp!) : null,
        familyPlanning: _familyPlanningController.text.trim().isEmpty
            ? null
            : _familyPlanningController.text.trim(),
        dateNewbornScreening: _newbornScreeningDate != null
            ? dateFormatter.format(_newbornScreeningDate!)
            : null,
        placeNewbornScreening:
            _placeNewbornScreeningController.text.trim().isEmpty
            ? null
            : _placeNewbornScreeningController.text.trim(),
        vaccinesReceived: _vaccinesReceived.toList(),
      );

      final result = await ApiClient.instance.requestImmunization(
        request,
        babysCard: _babysCard,
      );

      if (result.isSuccess) {
        // Get child name from response or form
        final childName = result.childName?.trim().isNotEmpty == true
            ? result.childName!.trim()
            : '${_childFnameController.text.trim()} ${_childLnameController.text.trim()}'
                  .trim();

        if (mounted) {
          _showSuccessSnackbar(childName);
          _showSuccessDialog(result, childName);
          _resetForm();
        }
      } else {
        final errorMsg = result.message.isNotEmpty
            ? result.message
            : 'Failed to register child. Please check your input and try again.';
        showErrorAlert(errorMsg);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if (mounted) {
          ErrorHandler.handleError(
            context,
            AuthExpiredException('Session expired'),
          );
        }
        return;
      }

      String errorMessage = 'Network error. Please try again.';
      if (e.response?.data != null) {
        try {
          Map<String, dynamic> errorData;
          if (e.response!.data is String) {
            errorData = json.decode(e.response!.data);
          } else {
            errorData = e.response!.data;
          }
          if (errorData['message'] != null) {
            errorMessage = errorData['message'].toString();
          }
        } catch (_) {}
      }
      showErrorAlert(errorMessage);
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) {
          ErrorHandler.handleError(context, e);
        }
      } else {
        showErrorAlert('Failed to register child: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isRegisteringChild = false);
      }
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
    } catch (e) {
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

  void _showSuccessDialog(ChildRegistrationResult response, String childName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppConstants.successGreen),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Child: $childName'),
            const SizedBox(height: 8),
            const Text('Child health record saved successfully!'),
            const SizedBox(height: 16),
            if (response.babyId != null) Text('Baby ID: ${response.babyId}'),
            if (response.babyId != null) const SizedBox(height: 8),
            if (response.totalRecordsCreated > 0)
              Text(
                'Total vaccine records created: ${response.totalRecordsCreated}',
              ),
            if (response.totalRecordsCreated > 0) const SizedBox(height: 8),
            Text('Vaccines taken: ${response.vaccinesTransferred}'),
            const SizedBox(height: 8),
            Text('Vaccines scheduled: ${response.vaccinesScheduled}'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // Auto-dismiss dialog after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  void _prefillAddressFields(String? place) {
    if (place == null || place.trim().isEmpty) {
      return;
    }
    final parts = place
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) {
      _provinceController.text = parts[0];
    }
    if (parts.length > 1) {
      _cityController.text = parts[1];
    }
    if (parts.length > 2) {
      _barangayController.text = parts[2];
    }
    if (parts.length > 3) {
      _purokController.text = parts[3];
    }
  }

  String _composeAddress() {
    final parts = [
      _provinceController.text.trim(),
      _cityController.text.trim(),
      _barangayController.text.trim(),
      _purokController.text.trim(),
    ].where((part) => part.isNotEmpty).toList();
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
      final savedPlace = _userProfile?.place;
      if (savedPlace == null || savedPlace.isEmpty) {
        _provinceController.clear();
        _cityController.clear();
        _barangayController.clear();
        _purokController.clear();
      } else {
        _prefillAddressFields(savedPlace);
      }
      _birthWeightController.clear();
      _birthHeightController.clear();
      _bloodTypeController.clear();
      _bloodType = null;
      _allergiesController.clear();
      _placeNewbornScreeningController.clear();
      // Keep pre-filled parent names from profile
      if (_userProfile == null || _userProfile!.gender == null) {
        _motherNameController.clear();
        _fatherNameController.clear();
      }
      _familyPlanningController.clear();
      _birthAttendantOthersController.clear();
      _birthDate = null;
      _lmp = null;
      _newbornScreeningDate = null;
      _gender = 'Male';
      _deliveryType = 'Normal';
      _birthOrder = 'Single';
      _birthAttendant = 'Doctor';
      _babysCard = null;
      _vaccinesReceived.clear();
    });
  }
}
