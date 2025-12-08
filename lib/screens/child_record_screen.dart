import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../models/child_detail.dart';
import '../models/immunization.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../mixins/animated_alert_mixin.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bottom_navigation.dart';

class ChildRecordScreen extends StatefulWidget {
  final String babyId;

  const ChildRecordScreen({super.key, required this.babyId});

  @override
  State<ChildRecordScreen> createState() => _ChildRecordScreenState();
}

class _ChildRecordScreenState extends State<ChildRecordScreen>
    with AnimatedAlertMixin {
  ChildDetail? _childDetail;
  List<ImmunizationItem> _vaccinations = [];
  bool _isLoading = true;
  bool _isLoadingVaccinations = false;
  String? _error;
  Set<String> _requestingTypes = {};

  @override
  void initState() {
    super.initState();
    _loadChildDetails();
    _loadVaccinationData();
  }

  Future<void> _loadChildDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.getChildDetails(widget.babyId);

      // Handle JSON string response
      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      final childResponse = ChildDetailResponse.fromJson(responseData);

      if (childResponse.status == 'success' && childResponse.data.isNotEmpty) {
        setState(() {
          _childDetail = childResponse.data.first;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Record not found.';
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
          _error = 'Network error. Please try again.';
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
          _error = 'Failed to load child details. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadVaccinationData() async {
    setState(() => _isLoadingVaccinations = true);

    try {
      // Pass babyId to ensure transferred children's vaccination records are included
      final response = await ApiClient.instance.getImmunizationSchedule(
        babyId: widget.babyId,
      );
      if (response.data['status'] == 'success') {
        final scheduleResponse = ImmunizationScheduleResponse.fromJson(
          response.data,
        );
        final allVaccinations = scheduleResponse.data;
        // Filter vaccinations for this child
        final childVaccinations = allVaccinations
            .where((v) => v.babyId == widget.babyId)
            .toList();

        // Calculate next_schedule_date for each vaccination
        final vaccinationsWithNextSchedule = _calculateNextScheduleDates(
          childVaccinations,
        );

        // Filter to get only TAKEN ones
        setState(() {
          _vaccinations = vaccinationsWithNextSchedule
              .where((v) => v.isTaken || v.status == 'taken')
              .toList();
          _isLoadingVaccinations = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingVaccinations = false);
    }
  }

  /// Calculate next_schedule_date for each vaccination based on canonical vaccine order
  /// This matches the JavaScript logic from the web version
  List<ImmunizationItem> _calculateNextScheduleDates(
    List<ImmunizationItem> vaccinations,
  ) {
    // Canonical vaccine order (matching JavaScript)
    final canonicalOrder = [
      'bcg',
      'hepb_birth',
      'penta1',
      'opv1',
      'pcv1',
      'rota1',
      'penta2',
      'opv2',
      'pcv2',
      'rota2',
      'penta3',
      'opv3',
      'pcv3',
      'mcv1',
      'mcv2',
    ];

    // Map vaccine names to canonical keys
    String? getCanonicalKey(String vaccineName) {
      final name = vaccineName.toLowerCase().trim();
      if (name.contains('bcg')) return 'bcg';
      if (name.contains('hepb') ||
          name.contains('hepatitis b') ||
          name.contains('hepab1'))
        return 'hepb_birth';
      if (name.contains('penta') && name.contains('1st')) return 'penta1';
      if (name.contains('penta') && name.contains('2nd')) return 'penta2';
      if (name.contains('penta') && name.contains('3rd')) return 'penta3';
      if (name.contains('opv') && name.contains('1st')) return 'opv1';
      if (name.contains('opv') && name.contains('2nd')) return 'opv2';
      if (name.contains('opv') && name.contains('3rd')) return 'opv3';
      if (name.contains('pcv') && name.contains('1st')) return 'pcv1';
      if (name.contains('pcv') && name.contains('2nd')) return 'pcv2';
      if (name.contains('pcv') && name.contains('3rd')) return 'pcv3';
      if (name.contains('rota') && name.contains('1st')) return 'rota1';
      if (name.contains('rota') && name.contains('2nd')) return 'rota2';
      if (name.contains('mcv1') || name.contains('amv')) return 'mcv1';
      if (name.contains('mcv2') || name.contains('mmr')) return 'mcv2';
      return null;
    }

    // Get due date with priority: batch_schedule_date > catch_up_date > schedule_date
    String? getDueDate(ImmunizationItem item) {
      if (item.batchScheduleDate != null &&
          item.batchScheduleDate!.isNotEmpty) {
        return item.batchScheduleDate;
      }
      if (item.catchUpDate != null && item.catchUpDate!.isNotEmpty) {
        return item.catchUpDate;
      }
      if (item.scheduleDate.isNotEmpty) {
        return item.scheduleDate;
      }
      return null;
    }

    // Group vaccinations by canonical key
    final Map<String, List<ImmunizationItem>> byKey = {};
    for (final vac in vaccinations) {
      final key = getCanonicalKey(vac.vaccineName);
      if (key != null) {
        byKey.putIfAbsent(key, () => []).add(vac);
      }
    }

    // Calculate next schedule for each vaccination
    return vaccinations.map((currentVac) {
      final currentKey = getCanonicalKey(currentVac.vaccineName);
      if (currentKey == null) return currentVac;

      // Find index in canonical order
      final currentIndex = canonicalOrder.indexOf(currentKey);
      if (currentIndex == -1) return currentVac;

      // Find next vaccine in sequence
      ImmunizationItem? nextRecord;
      for (int i = currentIndex + 1; i < canonicalOrder.length; i++) {
        final nextKey = canonicalOrder[i];
        final nextVaccinations = byKey[nextKey];
        if (nextVaccinations != null && nextVaccinations.isNotEmpty) {
          // Priority: upcoming > taken > any
          nextRecord = nextVaccinations.firstWhere(
            (v) => v.isScheduled || v.status == 'scheduled',
            orElse: () => nextVaccinations.firstWhere(
              (v) => v.isTaken || v.status == 'taken',
              orElse: () => nextVaccinations.first,
            ),
          );
          break;
        }
      }

      // Calculate next schedule date
      String? nextScheduleDate;
      if (nextRecord != null) {
        // Priority: batch_schedule_date > catch_up_date > schedule_date
        nextScheduleDate = getDueDate(nextRecord);
      }

      // Create new instance with next_schedule_date
      return ImmunizationItem(
        id: currentVac.id,
        babyId: currentVac.babyId,
        childName: currentVac.childName,
        vaccineName: currentVac.vaccineName,
        doseNumber: currentVac.doseNumber,
        scheduleDate: currentVac.scheduleDate,
        batchScheduleDate: currentVac.batchScheduleDate,
        catchUpDate: currentVac.catchUpDate,
        dateGiven: currentVac.dateGiven,
        status: currentVac.status,
        originalVaccineName: currentVac.originalVaccineName,
        doseInfo: currentVac.doseInfo,
        isSuppressed: currentVac.isSuppressed,
        height: currentVac.height,
        weight: currentVac.weight,
        muac: currentVac.muac,
        remarks: currentVac.remarks,
        nextScheduleDate: nextScheduleDate,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return buildWithAlerts(
      Scaffold(
        appBar: AppBar(
          title: const Text('Child Health Record'),
          backgroundColor: AppConstants.primaryGreen,
          foregroundColor: Colors.white,
        ),
        drawer: const AppDrawer(),
        body: _buildBody(),
        bottomNavigationBar: const AppBottomNavigation(
          current: BottomNavDestination.myChildren,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChildDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_childDetail == null) {
      return const Center(child: Text('No data available'));
    }

    // Check if tablet (> 600px width)
    final isTablet = MediaQuery.of(context).size.width > 600;

    return RefreshIndicator(
      onRefresh: _loadChildDetails,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBasicInfo(),
        const SizedBox(height: 24),
        _buildBirthInfo(),
        const SizedBox(height: 24),
        _buildParentInfo(),
        const SizedBox(height: 24),
        _buildHealthInfo(),
        const SizedBox(height: 24),
        _buildBreastfeedingInfo(),
        const SizedBox(height: 24),
        _buildMotherTDInfo(),
        const SizedBox(height: 24),
        _buildVaccinationLedger(),
        const SizedBox(height: 24),
        _buildRequestButtons(),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Basic Info + Birth Info (2 columns)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildBasicInfo()),
            const SizedBox(width: 16),
            Expanded(child: _buildBirthInfo()),
          ],
        ),
        const SizedBox(height: 24),
        // Row 2: Parent Info + Health Info (2 columns)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildParentInfo()),
            const SizedBox(width: 16),
            Expanded(child: _buildHealthInfo()),
          ],
        ),
        const SizedBox(height: 24),
        // Breastfeeding (full width)
        _buildBreastfeedingInfo(),
        const SizedBox(height: 24),
        // Mother's TD (full width)
        _buildMotherTDInfo(),
        const SizedBox(height: 24),
        // Vaccination Ledger (full width)
        _buildVaccinationLedger(),
        const SizedBox(height: 24),
        // Request Buttons (full width)
        _buildRequestButtons(),
      ],
    );
  }

  Widget _buildBasicInfo() {
    return _buildSection('Basic Information', [
      _buildInfoRow('Name', _childDetail!.name),
      _buildInfoRow('Gender', _childDetail!.childGender),
      _buildInfoRow('Birth Date', _childDetail!.childBirthDate),
      _buildInfoRow(
        'Age',
        '${_childDetail!.age} years (${_childDetail!.weeksOld.toStringAsFixed(1)} weeks)',
      ),
      _buildInfoRow('Status', _childDetail!.status.toUpperCase()),
      _buildInfoRow('Baby ID', _childDetail!.babyId),
    ]);
  }

  Widget _buildBirthInfo() {
    return _buildSection('Birth Information', [
      _buildInfoRow('Place of Birth', _childDetail!.placeOfBirth),
      _buildInfoRow('Birth Weight', '${_childDetail!.birthWeight} kg'),
      _buildInfoRow('Birth Height', '${_childDetail!.birthHeight} cm'),
      _buildInfoRow('Birth Attendant', _childDetail!.birthAttendant),
      _buildInfoRow('Delivery Type', _childDetail!.deliveryType),
      _buildInfoRow('Birth Order', _childDetail!.birthOrder),
    ]);
  }

  Widget _buildParentInfo() {
    return _buildSection('Parent Information', [
      _buildInfoRow('Mother\'s Name', _childDetail!.motherName),
      _buildInfoRow('Father\'s Name', _childDetail!.fatherName),
      _buildInfoRow('Address', _childDetail!.address),
      _buildInfoRow('Family Number', _childDetail!.familyNumber),
      _buildInfoRow('PhilHealth No.', _childDetail!.philhealthNo),
      _buildInfoRow(
        'NHTS',
        _childDetail!.nhts.isEmpty ? 'N/A' : _childDetail!.nhts,
      ),
    ]);
  }

  Widget _buildHealthInfo() {
    return _buildSection('Health Information', [
      _buildInfoRow(
        'Blood Type',
        _childDetail!.bloodType.isEmpty
            ? 'Not specified'
            : _childDetail!.bloodType,
      ),
      _buildInfoRow(
        'Allergies',
        _childDetail!.allergies.isEmpty ? 'None' : _childDetail!.allergies,
      ),
      _buildInfoRow(
        'LMP',
        _childDetail!.lpm.isEmpty ? 'Not specified' : _childDetail!.lpm,
      ),
      _buildInfoRow(
        'Family Planning',
        _childDetail!.familyPlanning.isEmpty
            ? 'Not specified'
            : _childDetail!.familyPlanning,
      ),
    ]);
  }

  Widget _buildBreastfeedingInfo() {
    return _buildSection('Breastfeeding Information', [
      _buildBooleanRow('1 Month', _childDetail!.exclusiveBreastfeeding1mo),
      _buildBooleanRow('2 Months', _childDetail!.exclusiveBreastfeeding2mo),
      _buildBooleanRow('3 Months', _childDetail!.exclusiveBreastfeeding3mo),
      _buildBooleanRow('4 Months', _childDetail!.exclusiveBreastfeeding4mo),
      _buildBooleanRow('5 Months', _childDetail!.exclusiveBreastfeeding5mo),
      _buildBooleanRow('6 Months', _childDetail!.exclusiveBreastfeeding6mo),
      const Divider(),
      _buildInfoRow(
        'Complementary Feeding (6mo)',
        _childDetail!.complementaryFeeding6mo.isEmpty
            ? 'Not specified'
            : _childDetail!.complementaryFeeding6mo,
      ),
      _buildInfoRow(
        'Complementary Feeding (7mo)',
        _childDetail!.complementaryFeeding7mo.isEmpty
            ? 'Not specified'
            : _childDetail!.complementaryFeeding7mo,
      ),
      _buildInfoRow(
        'Complementary Feeding (8mo)',
        _childDetail!.complementaryFeeding8mo.isEmpty
            ? 'Not specified'
            : _childDetail!.complementaryFeeding8mo,
      ),
    ]);
  }

  Widget _buildMotherTDInfo() {
    return _buildSection('Mother\'s Tetanus Doses', [
      _buildInfoRow(
        'Dose 1',
        _childDetail!.motherTdDose1Date.isEmpty
            ? 'Not given'
            : _childDetail!.motherTdDose1Date,
      ),
      _buildInfoRow(
        'Dose 2',
        _childDetail!.motherTdDose2Date.isEmpty
            ? 'Not given'
            : _childDetail!.motherTdDose2Date,
      ),
      _buildInfoRow(
        'Dose 3',
        _childDetail!.motherTdDose3Date.isEmpty
            ? 'Not given'
            : _childDetail!.motherTdDose3Date,
      ),
      _buildInfoRow(
        'Dose 4',
        _childDetail!.motherTdDose4Date.isEmpty
            ? 'Not given'
            : _childDetail!.motherTdDose4Date,
      ),
      _buildInfoRow(
        'Dose 5',
        _childDetail!.motherTdDose5Date.isEmpty
            ? 'Not given'
            : _childDetail!.motherTdDose5Date,
      ),
    ]);
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: AppConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppConstants.subheadingStyle),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppConstants.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not specified' : value,
              style: const TextStyle(color: AppConstants.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooleanRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppConstants.textSecondary,
              ),
            ),
          ),
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? AppConstants.successGreen : AppConstants.errorRed,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            value ? 'Yes' : 'No',
            style: TextStyle(
              color: value ? AppConstants.successGreen : AppConstants.errorRed,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestChrCertificate(String requestType) async {
    setState(() {
      _requestingTypes.add(requestType);
    });

    try {
      final response = await ApiClient.instance.requestChrDoc(
        widget.babyId,
        requestType,
      );

      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      if (responseData['status'] == 'success') {
        showSuccessAlert(
          '${requestType == 'school' ? 'School' : 'Transfer'} certificate request submitted successfully',
        );
      } else {
        showErrorAlert(responseData['message'] ?? 'Request failed');
      }
    } catch (e) {
      showErrorAlert('Failed to submit request. Please try again.');
    } finally {
      setState(() {
        _requestingTypes.remove(requestType);
      });
    }
  }

  Widget _buildRequestButtons() {
    return Card(
      elevation: AppConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Baby Card & Transfer',
              style: AppConstants.subheadingStyle,
            ),
            const SizedBox(height: 12),
            Text(
              'Request official documents for ${_childDetail!.name}',
              style: AppConstants.captionStyle,
            ),
            const SizedBox(height: 16),
            // Always show buttons in one row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _requestingTypes.contains('school')
                        ? null
                        : () => _requestChrCertificate('school'),
                    icon: _requestingTypes.contains('school')
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppConstants.primaryGreen,
                              ),
                            ),
                          )
                        : const Icon(Icons.school, size: 18),
                    label: SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _requestingTypes.contains('school')
                              ? 'Requesting...'
                              : 'Request Baby Card',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.primaryGreen,
                      side: const BorderSide(color: AppConstants.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _requestingTypes.contains('transfer')
                        ? null
                        : () => _requestChrCertificate('transfer'),
                    icon: _requestingTypes.contains('transfer')
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
                        : const Icon(Icons.swap_horiz, size: 18),
                    label: SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _requestingTypes.contains('transfer')
                              ? 'Requesting...'
                              : 'Request Transfer',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.mediumGreen,
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
          ],
        ),
      ),
    );
  }

  Widget _buildVaccinationLedger() {
    return _buildSection('Vaccination Ledger', [
      _isLoadingVaccinations
          ? const Center(child: CircularProgressIndicator())
          : _vaccinations.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No vaccination records available',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visual hint for horizontal scrolling
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chevron_left,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Swipe left/right',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'to see all columns',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildVaccinationTable(),
              ],
            ),
    ]);
  }

  Widget _buildVaccinationTable() {
    final isTablet = MediaQuery.of(context).size.width > 600;
    // Calculate minimum width needed for all columns
    // Date: 60, Purpose: 100, HT: 40, WT: 40, ME/AC: 60, STATUS: 70, Cond: 60, Advice: 80, Next Sched: 90, Remarks: 80
    // Total: ~720px minimum, but we'll use 900px to be safe
    final minTableWidth = isTablet ? 1200.0 : 900.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Container(
          width: minTableWidth,
          child: DataTable(
            columnSpacing: 8,
            horizontalMargin: 12,
            headingRowColor: MaterialStateProperty.all(
              AppConstants.primaryGreen.withValues(alpha: 0.1),
            ),
            columns: const [
              DataColumn(
                label: SizedBox(
                  width: 60,
                  child: Text(
                    'Date',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 100,
                  child: Text(
                    'Purpose',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 40,
                  child: Text(
                    'HT',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 40,
                  child: Text(
                    'WT',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 60,
                  child: Text(
                    'ME/AC',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 70,
                  child: Text(
                    'STATUS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 60,
                  child: Text(
                    'Cond.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 80,
                  child: Text(
                    'Advice',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 90,
                  child: Text(
                    'Next Sched',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 80,
                  child: Text(
                    'Remarks',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            rows: _vaccinations.map((vaccination) {
              final dateGiven = vaccination.dateGiven ?? '';
              final formattedDate = dateGiven.isNotEmpty
                  ? _formatDateForTable(dateGiven)
                  : '';
              final vaccineName = vaccination.vaccineWithDose;
              final status = vaccination.status.toUpperCase();
              final nextScheduleFormatted =
                  vaccination.nextScheduleDate != null &&
                      vaccination.nextScheduleDate!.isNotEmpty
                  ? _formatDateForTable(vaccination.nextScheduleDate!)
                  : '-';

              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 60,
                      child: Text(
                        formattedDate,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 100,
                      child: Tooltip(
                        message: vaccineName,
                        child: Text(
                          vaccineName.length > 18
                              ? '${vaccineName.substring(0, 18)}...'
                              : vaccineName,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  // HT (Height) column
                  DataCell(
                    SizedBox(
                      width: 40,
                      child: Text(
                        _formatHeight(vaccination.height),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  // WT (Weight) column
                  DataCell(
                    SizedBox(
                      width: 40,
                      child: Text(
                        _formatWeight(vaccination.weight),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  // ME/AC (MUAC) column
                  DataCell(
                    SizedBox(
                      width: 60,
                      child: Text(
                        _formatMuac(vaccination.muac),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 70,
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          color: status == 'TAKEN' || status == 'COMPLETED'
                              ? AppConstants.successGreen
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Cond. column (empty for now)
                  const DataCell(
                    SizedBox(
                      width: 60,
                      child: Text('-', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                  // Advice column (empty for now)
                  const DataCell(
                    SizedBox(
                      width: 80,
                      child: Text('-', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                  // Next Sched column
                  DataCell(
                    SizedBox(
                      width: 90,
                      child: Text(
                        nextScheduleFormatted,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  // Remarks column
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: Tooltip(
                        message: _formatRemarks(vaccination.remarks),
                        child: Text(
                          _formatRemarks(vaccination.remarks).length > 12
                              ? '${_formatRemarks(vaccination.remarks).substring(0, 12)}...'
                              : _formatRemarks(vaccination.remarks),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _formatDateForTable(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final year = date.year.toString().substring(2);
      return '$month/$day/$year';
    } catch (e) {
      return '';
    }
  }

  String _formatHeight(double? height) {
    if (height == null) return '-';
    return '${height.toStringAsFixed(1)} cm';
  }

  String _formatWeight(double? weight) {
    if (weight == null) return '-';
    return '${weight.toStringAsFixed(1)} kg';
  }

  String _formatMuac(String? muac) {
    if (muac == null || muac.isEmpty) return '-';
    return muac;
  }

  String _formatRemarks(String? remarks) {
    if (remarks == null || remarks.isEmpty) return '-';
    return remarks;
  }
}
