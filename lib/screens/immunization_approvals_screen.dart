import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_client.dart';
import '../models/immunization_approval.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';

class ImmunizationApprovalsScreen extends StatefulWidget {
  const ImmunizationApprovalsScreen({super.key});

  @override
  State<ImmunizationApprovalsScreen> createState() =>
      _ImmunizationApprovalsScreenState();
}

class _ImmunizationApprovalsScreenState
    extends State<ImmunizationApprovalsScreen> {
  List<ImmunizationApproval> _approvals = [];
  bool _isLoading = true;
  String? _error;
  Set<int> _downloadingApprovals = {};

  @override
  void initState() {
    super.initState();
    _loadImmunizationApprovals();
  }

  Future<void> _loadImmunizationApprovals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.getImmunizationApprovals();

      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      final approvalsResponse = ImmunizationApprovalsResponse.fromJson(
        responseData,
      );

      if (approvalsResponse.status == 'success') {
        setState(() {
          _approvals = approvalsResponse.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              approvalsResponse.message ??
              'Failed to load immunization approvals';
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
          _error = 'Failed to load immunization approvals. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadCertificate(ImmunizationApproval approval) async {
    setState(() {
      _downloadingApprovals.add(approval.id);
    });

    try {
      debugPrint('Starting download for: ${approval.getFileName()}');
      final result = await ApiClient.instance.downloadImmunizationCertificate(
        approval,
      );

      if (result.success) {
        if (mounted) {
          debugPrint('Download successful: ${result.filePath}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Certificate downloaded: ${approval.getFileName()}',
              ),
              backgroundColor: AppConstants.successGreen,
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    await OpenFilex.open(result.filePath!);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to open file: $e'),
                        backgroundColor: AppConstants.errorRed,
                      ),
                    );
                  }
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          debugPrint('Download failed: ${result.errorMessage}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errorMessage ??
                    'Download failed. Please check storage permissions.',
              ),
              backgroundColor: AppConstants.errorRed,
              action: result.errorMessage?.contains('permission') == true
                  ? SnackBarAction(
                      label: 'Settings',
                      textColor: Colors.white,
                      onPressed: () async {
                        await openAppSettings();
                      },
                    )
                  : null,
              duration: const Duration(
                seconds: 6,
              ), // Longer duration for permission messages
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Download exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Download failed: ${e.toString()}. Please check storage permissions.',
            ),
            backgroundColor: AppConstants.errorRed,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () async {
                await openAppSettings();
              },
            ),
            duration: const Duration(
              seconds: 6,
            ), // Longer duration for permission messages
          ),
        );
      }
    } finally {
      setState(() {
        _downloadingApprovals.remove(approval.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Immunization Approvals'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
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
              onPressed: _loadImmunizationApprovals,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_approvals.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadImmunizationApprovals,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approved Immunization Requests (${_approvals.length})',
              style: AppConstants.subheadingStyle,
            ),
            const SizedBox(height: 16),
            _buildApprovalsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vaccines_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No approved immunization requests yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppConstants.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Approved immunization certificates will appear here\n\nNote: For Android 13+, you may need to enable "All files access" in app settings to download certificates.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalsTable() {
    return Column(
      children: _approvals.map((approval) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: AppConstants.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with ID and Baby ID
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ID: ${approval.id}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Baby ID: ${approval.babyId}',
                        style: AppConstants.captionStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Child name
                Text(
                  approval.childName,
                  style: AppConstants.subheadingStyle,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Vaccine name and status in a row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vaccine', style: AppConstants.captionStyle),
                          const SizedBox(height: 2),
                          Text(
                            approval.vaccineName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppConstants.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status', style: AppConstants.captionStyle),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                approval.status,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              approval.statusDisplay,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(approval.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Request type and date in a row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Type', style: AppConstants.captionStyle),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppConstants.successGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              approval.requestType.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.successGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Requested At',
                            style: AppConstants.captionStyle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            approval.formattedRequestedAt,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppConstants.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Approved at (if approved)
                if (approval.isApproved &&
                    approval.formattedApprovedAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Approved At',
                              style: AppConstants.captionStyle,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              approval.formattedApprovedAt,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppConstants.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Download button
                SizedBox(
                  width: double.infinity,
                  child: _buildDownloadButton(approval),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppConstants.successGreen;
      case 'pending':
        return AppConstants.warningOrange;
      case 'rejected':
        return AppConstants.errorRed;
      default:
        return AppConstants.textSecondary;
    }
  }

  Widget _buildDownloadButton(ImmunizationApproval approval) {
    final isDownloading = _downloadingApprovals.contains(approval.id);
    final canDownload = approval.isApproved && approval.hasCertificate;

    return ElevatedButton.icon(
      onPressed: (isDownloading || !canDownload)
          ? null
          : () => _downloadCertificate(approval),
      icon: isDownloading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.download, size: 18),
      label: Text(isDownloading ? 'Downloading...' : 'Download Certificate'),
      style: ElevatedButton.styleFrom(
        backgroundColor: canDownload ? AppConstants.successGreen : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
    );
  }
}
