import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';

class QrCodeModal extends StatefulWidget {
  final String childName;
  final String qrCodeUrl;

  const QrCodeModal({
    super.key,
    required this.childName,
    required this.qrCodeUrl,
  });

  @override
  State<QrCodeModal> createState() => _QrCodeModalState();
}

class _QrCodeModalState extends State<QrCodeModal> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final childName = widget.childName;
    final qrCodeUrl = widget.qrCodeUrl;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85, // Max 85% of screen height
          maxWidth: 400, // Max width for larger screens
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$childName\'s QR Code',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),

                // QR Code Image
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      qrCodeUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.qr_code_2,
                            size: 120,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Instruction text
                Text(
                  'Present this QR code at vaccination appointments',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Download button - Always visible at the bottom
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading
                        ? null
                        : _downloadQrCodeWithHeader,
                    icon: _isDownloading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(
                      _isDownloading ? 'Downloading...' : 'Download QR',
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

  Future<void> _downloadQrCodeWithHeader() async {
    if (widget.qrCodeUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QR code not available')));
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      // 1. Download QR image bytes
      final dio = Dio();
      final response = await dio.get<List<int>>(
        widget.qrCodeUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Failed to download QR image');
      }

      final qrBytes = Uint8List.fromList(response.data!);
      final qrImage = await _decodeImageFromBytes(qrBytes);

      // 2. Load logo from assets (optional)
      ui.Image? logoImage;
      try {
        final logoData = await rootBundle.load(
          'assets/images/ebakunado-logo-without-label.png',
        );
        logoImage = await _decodeImageFromBytes(logoData.buffer.asUint8List());
      } catch (_) {
        logoImage = null;
      }

      // 3. Get parent info (user profile image and name)
      String? parentName;
      String? parentProfileImgUrl;
      ui.Image? parentProfileImage;

      try {
        final userId = await _getCurrentUserId();
        debugPrint('🔍 Getting parent info for user_id: $userId');

        if (userId != null) {
          // Try to get from getUserInfo endpoint first
          try {
            final userInfoResponse = await ApiClient.instance.getUserInfo(
              userId,
            );
            Map<String, dynamic> userInfoData;
            if (userInfoResponse.data is String) {
              userInfoData = json.decode(userInfoResponse.data);
            } else {
              userInfoData = userInfoResponse.data;
            }

            debugPrint('📥 getUserInfo response: $userInfoData');

            if (userInfoData['status'] == 'success' &&
                userInfoData['data'] != null) {
              final userData = userInfoData['data'] as Map<String, dynamic>;
              parentName =
                  '${userData['fname'] ?? ''} ${userData['lname'] ?? ''}'
                      .trim();
              parentProfileImgUrl = userData['profileimg']?.toString();
              debugPrint(
                '✅ Got parent info from getUserInfo: $parentName, image: $parentProfileImgUrl',
              );
            } else {
              debugPrint(
                '⚠️ getUserInfo returned error: ${userInfoData['message']}',
              );
              // Fallback to profile data
              throw Exception('getUserInfo failed, trying profile data');
            }
          } catch (e) {
            debugPrint(
              '⚠️ getUserInfo endpoint failed: $e, trying profile data fallback',
            );
            // Fallback: Try to get from profile data (SharedPreferences or API)
            try {
              final prefs = await SharedPreferences.getInstance();
              final profileJson = prefs.getString('user_profile_data');

              if (profileJson != null) {
                final profileData = Map<String, dynamic>.from(
                  json.decode(profileJson) as Map,
                );
                final fname = profileData['fname']?.toString() ?? '';
                final lname = profileData['lname']?.toString() ?? '';
                parentName = '$fname $lname'.trim();
                parentProfileImgUrl =
                    profileData['profile_img']?.toString() ??
                    profileData['profileimg']?.toString();
                debugPrint(
                  '✅ Got parent info from SharedPreferences: $parentName, image: $parentProfileImgUrl',
                );
              } else {
                // Try profile API
                final profileResponse = await ApiClient.instance
                    .getProfileData();
                Map<String, dynamic> profileResponseData;
                if (profileResponse.data is String) {
                  profileResponseData = json.decode(profileResponse.data);
                } else {
                  profileResponseData = profileResponse.data;
                }

                if (profileResponseData['status'] == 'success' &&
                    profileResponseData['data'] != null) {
                  final profile =
                      profileResponseData['data'] as Map<String, dynamic>;
                  final fname = profile['fname']?.toString() ?? '';
                  final lname = profile['lname']?.toString() ?? '';
                  parentName = '$fname $lname'.trim();
                  parentProfileImgUrl =
                      profile['profile_img']?.toString() ??
                      profile['profileimg']?.toString();
                  debugPrint(
                    '✅ Got parent info from profile API: $parentName, image: $parentProfileImgUrl',
                  );
                }
              }
            } catch (profileError) {
              debugPrint(
                '❌ Failed to get parent info from profile: $profileError',
              );
            }
          }

          // Download parent profile image if available
          if (parentProfileImgUrl != null && parentProfileImgUrl.isNotEmpty) {
            try {
              debugPrint(
                '📥 Downloading parent profile image from: $parentProfileImgUrl',
              );
              final dio = Dio();
              final profileResponse = await dio.get<List<int>>(
                parentProfileImgUrl,
                options: Options(responseType: ResponseType.bytes),
              );
              if (profileResponse.statusCode == 200 &&
                  profileResponse.data != null) {
                final profileBytes = Uint8List.fromList(profileResponse.data!);
                parentProfileImage = await _decodeImageFromBytes(profileBytes);
                debugPrint('✅ Successfully loaded parent profile image');
              } else {
                debugPrint(
                  '⚠️ Profile image download returned status: ${profileResponse.statusCode}',
                );
              }
            } catch (e) {
              // If profile image download fails, continue without it
              debugPrint('❌ Failed to load parent profile image: $e');
            }
          } else {
            debugPrint('⚠️ No parent profile image URL available');
          }
        } else {
          debugPrint('⚠️ No user_id found, skipping parent info');
        }
      } catch (e) {
        debugPrint('❌ Failed to get parent info: $e');
        // Continue without parent info
      }

      debugPrint(
        '📊 Final parent info - Name: $parentName, Has Image: ${parentProfileImage != null}',
      );

      // 4. Compose final image on canvas (match website layout)
      final composed = await _composeQrCanvas(
        qrImage: qrImage,
        logoImage: logoImage,
        childName: widget.childName,
        parentProfileImage: parentProfileImage,
        parentName: parentName,
      );

      final pngBytes = await composed.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (pngBytes == null) {
        throw Exception('Failed to encode QR image');
      }

      final fileName = _buildFileName(widget.childName);

      // 5. Request permissions and save to appropriate directory
      String filePath;
      if (Platform.isAndroid) {
        final isAndroid13OrHigher = await _isAndroid13OrHigher();

        if (isAndroid13OrHigher) {
          // Android 13+ requires manage external storage permission
          final managePermission = await Permission.manageExternalStorage
              .request();
          if (managePermission.isGranted) {
            filePath = await _savePngToDownloadsDirectory(
              pngBytes.buffer.asUint8List(),
              fileName,
            );
          } else {
            // Fallback to private directory if permission denied
            filePath = await _savePngToPrivateDirectory(
              pngBytes.buffer.asUint8List(),
              fileName,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'QR saved to app folder. Enable "All files access" in settings to save to Downloads.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          // Android 12 and below - request storage permission
          final storagePermission = await Permission.storage.request();
          if (storagePermission.isGranted) {
            filePath = await _savePngToDownloadsDirectory(
              pngBytes.buffer.asUint8List(),
              fileName,
            );
          } else {
            // Fallback to private directory
            filePath = await _savePngToPrivateDirectory(
              pngBytes.buffer.asUint8List(),
              fileName,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission denied. QR saved to app folder.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // iOS - use app documents directory
        filePath = await _savePngToPrivateDirectory(
          pngBytes.buffer.asUint8List(),
          fileName,
        );
      }

      // 6. Open the file so user can view/share it
      await OpenFilex.open(filePath);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('QR downloaded to: $filePath')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR download failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<ui.Image> _decodeImageFromBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<ui.Image> _composeQrCanvas({
    required ui.Image qrImage,
    required ui.Image? logoImage,
    required String childName,
    ui.Image? parentProfileImage,
    String? parentName,
  }) async {
    final qrWidth = qrImage.width.toDouble();
    final qrHeight = qrImage.height.toDouble();

    // QR should be large in center - keep original size or scale up
    final headerHeight = math.max(72.0, qrWidth * 0.18);
    // Footer needs space for: parent image (left), child name (right), date (centered below)
    final footerHeight = math.max(80.0, qrWidth * 0.20);

    final totalHeight = headerHeight + qrHeight + footerHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(qrWidth, totalHeight);

    // Background
    final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Offset.zero & size, bgPaint);

    const paddingX = 16.0;
    final headerY = headerHeight / 2;

    // Draw logos (left and right) if available
    if (logoImage != null) {
      final logoMaxHeight = headerHeight - 20;
      final logoScale = logoMaxHeight / logoImage.height.toDouble();
      final logoH = logoImage.height.toDouble() * logoScale;
      final logoW = logoImage.width.toDouble() * logoScale;
      final logoY = (headerHeight - logoH) / 2;

      final leftRect = Rect.fromLTWH(paddingX, logoY, logoW, logoH);
      canvas.drawImageRect(
        logoImage,
        Rect.fromLTWH(
          0,
          0,
          logoImage.width.toDouble(),
          logoImage.height.toDouble(),
        ),
        leftRect,
        Paint(),
      );

      final rightRect = Rect.fromLTWH(
        math.max(paddingX, qrWidth - paddingX - logoW),
        logoY,
        logoW,
        logoH,
      );
      canvas.drawImageRect(
        logoImage,
        Rect.fromLTWH(
          0,
          0,
          logoImage.width.toDouble(),
          logoImage.height.toDouble(),
        ),
        rightRect,
        Paint(),
      );
    }

    // Text helper
    void drawText(
      String text,
      double y, {
      double fontSize = 14,
      FontWeight fontWeight = FontWeight.normal,
      Color color = const Color(0xFF000000),
    }) {
      final textStyle = ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
      );
      // Use full QR width and center via textAlign to avoid horizontal shifting
      final paragraphStyle = ui.ParagraphStyle(textAlign: TextAlign.center);
      final builder = ui.ParagraphBuilder(paragraphStyle)
        ..pushStyle(textStyle)
        ..addText(text);
      final paragraph = builder.build()
        ..layout(
          ui.ParagraphConstraints(
            // Let the paragraph take the full width; centering is handled by textAlign
            width: qrWidth,
          ),
        );
      final offset = Offset(0, y - paragraph.height / 2);
      canvas.drawParagraph(paragraph, offset);
    }

    // Header texts
    final mainFontSize = math.max(16.0, qrWidth * 0.045);
    final subFontSize = math.max(12.0, qrWidth * 0.03);

    final healthY = headerY - (subFontSize * 0.9);
    drawText(
      'Linao Health Center',
      healthY,
      fontSize: mainFontSize,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF006C35),
    );

    final barangayY = headerY + (subFontSize * 0.9);
    drawText(
      'Barangay Linao, Ormoc City',
      barangayY,
      fontSize: subFontSize,
      color: const Color(0xFF0F172A),
    );

    final titleFontSize = math.max(13.0, qrWidth * 0.028);
    final titleY = headerY + (subFontSize * 2.6);
    drawText(
      'QR Code for Child Immunization Record',
      titleY,
      fontSize: titleFontSize,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF0F172A),
    );

    // Draw QR image - large in center
    final qrRect = Rect.fromLTWH(0, headerHeight, qrWidth, qrHeight);
    canvas.drawImageRect(
      qrImage,
      Rect.fromLTWH(0, 0, qrWidth, qrHeight),
      qrRect,
      Paint(),
    );

    // Footer layout:
    // - Parent profile image (circular) on left bottom
    // - Child name on right bottom
    // - Download date centered on its own row below

    final footerTop = headerHeight + qrHeight;

    // Parent profile image (left bottom, circular, max 45px proportional to QR width)
    final maxParentImageSize = math.min(45.0, qrWidth * 0.12);
    double? parentImageY;
    double? parentImageSize;

    if (parentProfileImage != null) {
      parentImageSize = math.min(
        maxParentImageSize,
        math.min(
          parentProfileImage.width.toDouble(),
          parentProfileImage.height.toDouble(),
        ),
      );
      final parentImageX = paddingX;
      // Align parent image to top of footer row (same level as child name)
      parentImageY = footerTop + (footerHeight * 0.2);

      // Draw circular clip for parent image
      final parentImageRect = Rect.fromLTWH(
        parentImageX,
        parentImageY,
        parentImageSize,
        parentImageSize,
      );

      // Create circular path
      final parentImagePath = Path()..addOval(parentImageRect);

      canvas.save();
      canvas.clipPath(parentImagePath);

      // Scale and draw parent image
      final scale =
          parentImageSize /
          math.max(
            parentProfileImage.width.toDouble(),
            parentProfileImage.height.toDouble(),
          );
      final scaledWidth = parentProfileImage.width.toDouble() * scale;
      final scaledHeight = parentProfileImage.height.toDouble() * scale;
      final offsetX = parentImageX + (parentImageSize - scaledWidth) / 2;
      final offsetY = parentImageY + (parentImageSize - scaledHeight) / 2;

      canvas.drawImageRect(
        parentProfileImage,
        Rect.fromLTWH(
          0,
          0,
          parentProfileImage.width.toDouble(),
          parentProfileImage.height.toDouble(),
        ),
        Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight),
        Paint(),
      );

      canvas.restore();
    }

    // Parent name (next to parent image, vertically centered with image) - truncate if too long
    if (parentName != null && parentName.isNotEmpty) {
      final parentNameFontSize = math.max(12.0, qrWidth * 0.028);
      // Truncate long parent names to avoid overlap
      final maxParentNameLength = ((qrWidth * 0.3) / parentNameFontSize)
          .round();
      final displayParentName = parentName.length > maxParentNameLength
          ? '${parentName.substring(0, maxParentNameLength - 3)}...'
          : parentName;

      void drawLeftAlignedText(
        String text,
        double x,
        double y, {
        double fontSize = 12,
        FontWeight fontWeight = FontWeight.normal,
        Color color = const Color(0xFF000000),
      }) {
        final textStyle = ui.TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        );
        final paragraphStyle = ui.ParagraphStyle(textAlign: TextAlign.left);
        final builder = ui.ParagraphBuilder(paragraphStyle)
          ..pushStyle(textStyle)
          ..addText(text);
        final paragraph = builder.build()
          ..layout(ui.ParagraphConstraints(width: qrWidth - paddingX * 2));
        canvas.drawParagraph(paragraph, Offset(x, y - paragraph.height / 2));
      }

      // Position parent name: vertically centered with parent image (if exists), otherwise same level as child name
      final parentNameY = parentImageY != null && parentImageSize != null
          ? parentImageY +
                (parentImageSize / 2) // Vertically centered with image
          : footerTop +
                (footerHeight * 0.4); // Same level as child name if no image

      // Calculate X position: if image exists, place name to the right of image, otherwise at left padding
      final parentNameX = parentImageSize != null
          ? paddingX +
                parentImageSize +
                8 // Right of image with spacing
          : paddingX; // Left edge if no image

      drawLeftAlignedText(
        displayParentName,
        parentNameX,
        parentNameY,
        fontSize: parentNameFontSize,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF111827),
      );
    }

    // Child name (right bottom) - truncate if too long
    // Align child name vertically with parent image/name (same level)
    final nameFontSize = math.max(14.0, qrWidth * 0.032);
    final trimmedChildName = childName.trim().isEmpty
        ? 'Child'
        : childName.trim();
    // Truncate long names to avoid overlap (max ~30 chars or adjust based on width)
    final maxNameLength = (qrWidth * 0.4 / nameFontSize).round();
    final displayChildName = trimmedChildName.length > maxNameLength
        ? '${trimmedChildName.substring(0, maxNameLength - 3)}...'
        : trimmedChildName;

    // Align child name vertically with parent image/name
    final nameY = parentImageY != null && parentImageSize != null
        ? parentImageY +
              (parentImageSize / 2) // Same level as parent image center
        : footerTop + (footerHeight * 0.4); // Fallback if no parent image
    final nameX = qrWidth - paddingX;

    void drawRightAlignedText(
      String text,
      double x,
      double y, {
      double fontSize = 14,
      FontWeight fontWeight = FontWeight.normal,
      Color color = const Color(0xFF000000),
    }) {
      final textStyle = ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
      );
      final paragraphStyle = ui.ParagraphStyle(textAlign: TextAlign.right);
      final builder = ui.ParagraphBuilder(paragraphStyle)
        ..pushStyle(textStyle)
        ..addText(text);
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: x - paddingX));
      canvas.drawParagraph(
        paragraph,
        Offset(paddingX, y - paragraph.height / 2),
      );
    }

    drawRightAlignedText(
      displayChildName,
      nameX,
      nameY,
      fontSize: nameFontSize,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF111827),
    );

    // Download date (centered on its own row below)
    final dateFontSize = math.max(12.0, qrWidth * 0.028);
    final now = DateTime.now();
    final dateText = 'Downloaded: ${now.month}/${now.day}/${now.year}';
    final dateY = footerTop + (footerHeight * 0.75);
    drawText(
      dateText,
      dateY,
      fontSize: dateFontSize,
      color: const Color(0xFF111827),
    );

    final picture = recorder.endRecording();
    return picture.toImage(qrWidth.toInt(), totalHeight.toInt());
  }

  Future<String> _savePngToPrivateDirectory(
    Uint8List bytes,
    String fileName,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<String> _savePngToDownloadsDirectory(
    Uint8List bytes,
    String fileName,
  ) async {
    if (Platform.isAndroid) {
      // Get external storage directory
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // Navigate to Downloads folder
        final downloadsPath = '${externalDir.path.split('Android')[0]}Download';
        final downloadsDir = Directory(downloadsPath);

        // Create Downloads directory if it doesn't exist
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        final file = File('${downloadsDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return file.path;
      }
    }

    // Fallback to private directory if external storage is not available
    return await _savePngToPrivateDirectory(bytes, fileName);
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

  String _buildFileName(String childName) {
    final safeName = childName.trim().isEmpty
        ? 'child'
        : childName.trim().replaceAll(RegExp(r'\s+'), '_');
    return 'QR_${safeName}.png';
  }

  // Get current user ID from SharedPreferences or profile
  Future<String?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile_data');

      if (profileJson != null) {
        try {
          final profileData = Map<String, dynamic>.from(
            json.decode(profileJson) as Map,
          );
          final userId = profileData['user_id']?.toString();
          if (userId != null && userId.isNotEmpty) {
            return userId;
          }
        } catch (e) {
          debugPrint('Error parsing profile data: $e');
        }
      }

      // Try to get from profile API
      try {
        final profileResponse = await ApiClient.instance.getProfileData();
        Map<String, dynamic> responseData;
        if (profileResponse.data is String) {
          responseData = json.decode(profileResponse.data);
        } else {
          responseData = profileResponse.data;
        }

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final profile = responseData['data'] as Map<String, dynamic>;
          final userId = profile['user_id']?.toString();
          if (userId != null && userId.isNotEmpty) {
            return userId;
          }
        }
      } catch (e) {
        debugPrint('Error getting user_id from profile API: $e');
      }

      return null;
    } catch (e) {
      debugPrint('Error getting current user ID: $e');
      return null;
    }
  }
}
