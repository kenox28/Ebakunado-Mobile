import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_client.dart';
import '../models/chr_requests.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';

class ApprovedRequestsScreen extends StatefulWidget {
  const ApprovedRequestsScreen({super.key});

  @override
  State<ApprovedRequestsScreen> createState() => _ApprovedRequestsScreenState();
}

class _ApprovedRequestsScreenState extends State<ApprovedRequestsScreen> {
  List<ChrRequest> _approvedRequests = [];
  bool _isLoading = true;
  String? _error;
  Set<int> _downloadingRequests = {};

  @override
  void initState() {
    super.initState();
    _loadApprovedRequests();
  }

  Future<void> _loadApprovedRequests() async {
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
          _approvedRequests = chrRequestsResponse.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load approved requests';
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
          _error = 'Failed to load approved requests. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generateAndDownloadBabyCard(ChrRequest request) async {
    if (_downloadingRequests.contains(request.id)) {
      return; // Already downloading
    }

    // Check if request is approved and has doc_url
    if (!request.isApproved || request.docUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Document not available yet. Please wait for approval.',
            ),
            backgroundColor: AppConstants.errorRed,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _downloadingRequests.add(request.id);
    });

    try {
      debugPrint('Downloading Baby Card from: ${request.docUrl}');

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Downloading Baby Card...')),
              ],
            ),
          ),
        );
      }

      // Download pre-generated Baby Card PDF directly from Cloudinary
      final pdfBytes = await ApiClient.instance.downloadBabyCardFromUrl(
        request.docUrl,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Save PDF
      final filePath = await _savePdf(pdfBytes, request.childName);

      debugPrint('Baby Card saved to: $filePath');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Baby Card downloaded: ${_getFileName(request.childName)}',
            ),
            backgroundColor: AppConstants.successGreen,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  await OpenFilex.open(filePath);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to open file: $e'),
                        backgroundColor: AppConstants.errorRed,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Baby Card download error: $e');

      // Close loading dialog if open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download Baby Card: ${e.toString()}'),
            backgroundColor: AppConstants.errorRed,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _generateAndDownloadBabyCard(request),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingRequests.remove(request.id);
        });
      }
    }
  }

  Future<String> _savePdf(Uint8List pdfBytes, String childName) async {
    // Request storage permission if needed
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission denied');
      }
    }

    // Get downloads directory
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
      // Navigate to Downloads folder
      if (directory != null) {
        final downloadsPath = directory.path.split('Android')[0] + 'Download';
        directory = Directory(downloadsPath);
        if (!await directory.exists()) {
          directory = await getApplicationDocumentsDirectory();
        }
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final fileName = _getFileName(childName);
    final file = File('${directory!.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    return file.path;
  }

  String _getFileName(String childName) {
    // Sanitize child name for filename
    final safeName = childName
        .replaceAll(RegExp(r'[^\w\s]+'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    return 'BabyCard_${safeName.isEmpty ? 'Child' : safeName}.pdf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approved Requests'),
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
              onPressed: _loadApprovedRequests,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_approvedRequests.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadApprovedRequests,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approved Baby Cards (${_approvedRequests.length})',
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
            const Text(
              'No approved requests yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppConstants.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Approved Baby Card requests will appear here',
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
      children: _approvedRequests.map((request) {
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
      onPressed: isDownloading
          ? null
          : () => _generateAndDownloadBabyCard(request),
      icon: isDownloading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.picture_as_pdf, size: 18),
      label: Text(isDownloading ? 'Generating...' : 'Download Baby Card'),
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
