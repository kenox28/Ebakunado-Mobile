import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/api_client.dart';
import '../models/chr_requests.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bottom_navigation.dart';

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
    final fileName = _getFileName(childName);
    String filePath;

    if (Platform.isAndroid) {
      final isAndroid13OrHigher = await _isAndroid13OrHigher();

      if (isAndroid13OrHigher) {
        // Android 13+ requires manage external storage permission
        final managePermission = await Permission.manageExternalStorage
            .request();

        if (managePermission.isGranted) {
          // Try to save to Downloads directory
          try {
            filePath = await _savePdfToDownloadsDirectory(pdfBytes, fileName);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Baby Card saved to Downloads: $fileName'),
                  backgroundColor: AppConstants.successGreen,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            return filePath;
          } catch (e) {
            debugPrint('⚠️ Failed to save to Downloads directory: $e');
            // Show specific error message
            if (mounted) {
              final errorMsg =
                  e.toString().contains('Permission') ||
                      e.toString().contains('permission')
                  ? 'Storage permission issue. Saving to app folder instead.'
                  : 'Cannot save to Downloads folder. Saving to app folder instead.';

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMsg),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            // Fall through to private directory fallback
          }
        } else if (managePermission.isPermanentlyDenied) {
          // Permission permanently denied - need to open settings
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Storage permission required. Please enable "All files access" in settings.',
                ),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Open Settings',
                  textColor: Colors.white,
                  onPressed: () async {
                    await Permission.manageExternalStorage.request();
                  },
                ),
              ),
            );
          }
        } else {
          // Permission denied (but not permanently)
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission denied. Baby Card will be saved to app folder.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }

        // Fallback to private directory
        filePath = await _savePdfToPrivateDirectory(pdfBytes, fileName);
        if (mounted && !managePermission.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Baby Card saved to app folder. Enable "All files access" in settings to save to Downloads.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Android 12 and below - request storage permission
        final storagePermission = await Permission.storage.request();

        if (storagePermission.isGranted) {
          // Try to save to Downloads directory
          try {
            filePath = await _savePdfToDownloadsDirectory(pdfBytes, fileName);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Baby Card saved to Downloads: $fileName'),
                  backgroundColor: AppConstants.successGreen,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            return filePath;
          } catch (e) {
            debugPrint('⚠️ Failed to save to Downloads directory: $e');
            // Show specific error message
            if (mounted) {
              final errorMsg =
                  e.toString().contains('Permission') ||
                      e.toString().contains('permission')
                  ? 'Storage permission issue. Saving to app folder instead.'
                  : 'Cannot save to Downloads folder. Saving to app folder instead.';

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMsg),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            // Fall through to private directory fallback
          }
        } else if (storagePermission.isPermanentlyDenied) {
          // Permission permanently denied - need to open settings
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Storage permission required. Please enable storage access in settings.',
                ),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Open Settings',
                  textColor: Colors.white,
                  onPressed: () async {
                    await openAppSettings();
                  },
                ),
              ),
            );
          }
        } else {
          // Permission denied (but not permanently)
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission denied. Baby Card will be saved to app folder.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }

        // Fallback to private directory
        filePath = await _savePdfToPrivateDirectory(pdfBytes, fileName);
        if (mounted && !storagePermission.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Storage permission denied. Baby Card saved to app folder.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      // iOS - use app documents directory
      filePath = await _savePdfToPrivateDirectory(pdfBytes, fileName);
    }

    return filePath;
  }

  Future<String> _savePdfToPrivateDirectory(
    Uint8List pdfBytes,
    String fileName,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  Future<String> _savePdfToDownloadsDirectory(
    Uint8List pdfBytes,
    String fileName,
  ) async {
    if (Platform.isAndroid) {
      try {
        // Get external storage directory
        final externalDir = await getExternalStorageDirectory();
        if (externalDir == null) {
          throw Exception('External storage directory not available');
        }

        // Navigate to Downloads folder
        // Handle different path structures for different devices
        final externalPath = externalDir.path;

        debugPrint('External storage path: $externalPath');

        // Try multiple common Downloads paths
        final possiblePaths = [
          // Standard Android path
          externalPath.contains('Android')
              ? '${externalPath.split('Android')[0]}Download'
              : null,
          // Direct emulated path
          '/storage/emulated/0/Download',
          // Alternative path
          '/sdcard/Download',
          // External SD card path (if available)
          '/storage/sdcard1/Download',
        ];

        Directory? downloadsDir;
        String? selectedPath;

        // Try each path until we find one that works
        for (final path in possiblePaths) {
          if (path == null) continue;

          try {
            final dir = Directory(path);
            if (await dir.exists() || await _canCreateDirectory(dir)) {
              downloadsDir = dir;
              selectedPath = path;
              debugPrint('Using Downloads path: $path');
              break;
            }
          } catch (e) {
            debugPrint('Path $path not accessible: $e');
            continue;
          }
        }

        if (downloadsDir == null || selectedPath == null) {
          throw Exception('Downloads directory not accessible on this device');
        }

        // Create Downloads directory if it doesn't exist
        if (!await downloadsDir.exists()) {
          try {
            await downloadsDir.create(recursive: true);
          } catch (e) {
            debugPrint('Cannot create Downloads directory: $e');
            throw Exception('Cannot create Downloads directory: $e');
          }
        }

        // Check if we can write to the directory
        final testFile = File(
          '${downloadsDir.path}/.ebakunado_test_${DateTime.now().millisecondsSinceEpoch}',
        );
        try {
          await testFile.writeAsString('test');
          await testFile.delete();
        } catch (e) {
          debugPrint('Cannot write to Downloads directory: $e');
          throw Exception(
            'Cannot write to Downloads directory. Permission may be denied or directory is read-only.',
          );
        }

        // Save the actual file
        final file = File('${downloadsDir.path}/$fileName');
        try {
          await file.writeAsBytes(pdfBytes);
          debugPrint('✅ Baby Card saved to Downloads: ${file.path}');
          return file.path;
        } catch (e) {
          debugPrint('Failed to write file to Downloads: $e');
          throw Exception('Failed to save file: $e');
        }
      } catch (e) {
        debugPrint('❌ Error saving to Downloads directory: $e');
        // Re-throw with more context
        throw Exception('Downloads save failed: ${e.toString()}');
      }
    }

    // Fallback to private directory if external storage is not available
    return await _savePdfToPrivateDirectory(pdfBytes, fileName);
  }

  Future<bool> _canCreateDirectory(Directory dir) async {
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      // Test write
      final testFile = File('${dir.path}/.test');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 33; // Android 13 is API 33
    } catch (e) {
      return false;
    }
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
      drawer: const AppDrawer(),
      body: _buildBody(),
      bottomNavigationBar: const AppBottomNavigation(
        current: BottomNavDestination.dashboard,
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
