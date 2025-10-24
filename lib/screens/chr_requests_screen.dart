import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_client.dart';
import '../models/chr_requests.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';

class ChrRequestsScreen extends StatefulWidget {
  const ChrRequestsScreen({super.key});

  @override
  State<ChrRequestsScreen> createState() => _ChrRequestsScreenState();
}

class _ChrRequestsScreenState extends State<ChrRequestsScreen> {
  List<ChrRequest> _chrRequests = [];
  bool _isLoading = true;
  String? _error;
  Set<int> _downloadingRequests = {};

  @override
  void initState() {
    super.initState();
    _loadChrRequests();
  }

  Future<void> _loadChrRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.getMyChrRequests();

      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      final chrRequestsResponse = ChrRequestsResponse.fromJson(responseData);

      if (chrRequestsResponse.status == 'success') {
        setState(() {
          _chrRequests = chrRequestsResponse.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load CHR requests';
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
          _error = 'Failed to load CHR requests. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadDocument(ChrRequest chrRequest) async {
    setState(() {
      _downloadingRequests.add(chrRequest.id);
    });

    try {
      debugPrint('Starting download for: ${chrRequest.getFileName()}');
      final result = await ApiClient.instance.downloadChrDocument(chrRequest);

      if (result.success) {
        if (mounted) {
          debugPrint('Download successful: ${result.filePath}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document downloaded: ${chrRequest.getFileName()}'),
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
        _downloadingRequests.remove(chrRequest.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHR Requests'),
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
              onPressed: _loadChrRequests,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_chrRequests.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadChrRequests,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approved CHR Documents (${_chrRequests.length})',
              style: AppConstants.subheadingStyle,
            ),
            const SizedBox(height: 16),
            _buildRequestsTable(),
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
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No approved requests yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppConstants.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Approved CHR documents will appear here\n\nNote: For Android 13+, you may need to enable "All files access" in app settings to download certificates.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTable() {
    return Column(
      children: _chrRequests.map((request) {
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
                        'ID: ${request.id}',
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
                        'Baby ID: ${request.babyId}',
                        style: AppConstants.captionStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Child name
                Text(
                  request.childName,
                  style: AppConstants.subheadingStyle,
                  overflow: TextOverflow.ellipsis,
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
                              request.requestTypeDisplay,
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
                          Text('Approved At', style: AppConstants.captionStyle),
                          const SizedBox(height: 2),
                          Text(
                            request.formattedApprovedAt,
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
                const SizedBox(height: 16),

                // Download button
                SizedBox(
                  width: double.infinity,
                  child: _buildDownloadButton(request),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDownloadButton(ChrRequest request) {
    final isDownloading = _downloadingRequests.contains(request.id);

    return ElevatedButton.icon(
      onPressed: isDownloading ? null : () => _downloadDocument(request),
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
        backgroundColor: AppConstants.successGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
    );
  }
}
