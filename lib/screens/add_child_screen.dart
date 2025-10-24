import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../services/api_client.dart';
import '../models/child_registration_form.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../mixins/animated_alert_mixin.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen>
    with AnimatedAlertMixin {
  final _formKey = GlobalKey<FormState>();
  final _familyCodeController = TextEditingController();
  final _imagePicker = ImagePicker();

  // Loading states
  bool _isClaimingChild = false;
  bool _isRegisteringChild = false;

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
  void dispose() {
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
                label: 'Mother Name *',
                validator: (value) =>
                    value?.isEmpty == true ? 'Mother name is required' : null,
              ),
              _buildTextFormField(
                controller: _fatherNameController,
                label: 'Father Name',
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImageFromCamera,
                        icon: const Icon(Icons.camera_alt, size: 16),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(Icons.photo_library, size: 16),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
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

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _babysCard = File(image.path));
      }
    } catch (e) {
      showErrorAlert('Failed to pick image from camera: ${e.toString()}');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _babysCard = File(image.path));
      }
    } catch (e) {
      showErrorAlert('Failed to pick image from gallery: ${e.toString()}');
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
      final formData = ChildRegistrationForm(
        childFname: _childFnameController.text.trim(),
        childLname: _childLnameController.text.trim(),
        birthDate: _birthDate!,
        placeOfBirth: _placeOfBirthController.text.trim(),
        address: _addressController.text.trim(),
        birthWeight: double.tryParse(_birthWeightController.text.trim()),
        birthHeight: double.tryParse(_birthHeightController.text.trim()),
        bloodType: _bloodTypeController.text.trim(),
        allergies: _allergiesController.text.trim(),
        gender: _gender,
        motherName: _motherNameController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        lmp: _lmp,
        familyPlanning: _familyPlanningController.text.trim(),
        deliveryType: _deliveryType,
        birthOrder: _birthOrder,
        birthAttendant: _birthAttendant,
        birthAttendantOthers: _birthAttendantOthersController.text.trim(),
        babysCard: _babysCard,
        vaccinesReceived: _vaccinesReceived,
      );

      final response = await ApiClient.instance.requestImmunization(
        formData.toFormData(),
        _babysCard,
      );

      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      final addChildResponse = AddChildResponse.fromJson(responseData);

      // Additional safeguard: if we have baby_id or records created, treat as success
      if (addChildResponse.success ||
          addChildResponse.babyId != null ||
          (addChildResponse.totalRecordsCreated ?? 0) > 0) {
        _showSuccessDialog(addChildResponse);
      } else {
        showErrorAlert(addChildResponse.message);
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
        showErrorAlert('Failed to register child. Please try again.');
      }
    } finally {
      setState(() => _isRegisteringChild = false);
    }
  }

  void _showSuccessDialog(AddChildResponse response) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
            Text('Child health record saved successfully!'),
            const SizedBox(height: 16),
            Text('Baby ID: ${response.babyId}'),
            const SizedBox(height: 8),
            Text(
              'Total vaccine records created: ${response.totalRecordsCreated}',
            ),
            const SizedBox(height: 8),
            Text('Vaccines taken: ${response.vaccinesTransferred}'),
            const SizedBox(height: 8),
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
              _resetForm(); // Reset form for another child
            },
            child: const Text('Add Another Child'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _childFnameController.clear();
      _childLnameController.clear();
      _placeOfBirthController.clear();
      _addressController.clear();
      _birthWeightController.clear();
      _birthHeightController.clear();
      _bloodTypeController.clear();
      _allergiesController.clear();
      _motherNameController.clear();
      _fatherNameController.clear();
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
