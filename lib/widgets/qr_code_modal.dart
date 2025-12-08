import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
                    onPressed: _isDownloading ? null : _downloadQrCodeWithHeader,
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
                    label: Text(_isDownloading ? 'Downloading...' : 'Download QR'),
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

      // 3. Compose final image on canvas (match website layout)
      final composed = await _composeQrCanvas(
        qrImage: qrImage,
        logoImage: logoImage,
        childName: widget.childName,
      );

      final pngBytes = await composed.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (pngBytes == null) {
        throw Exception('Failed to encode QR image');
      }

      final fileName = _buildFileName(widget.childName);
      
      // 4. Request permissions and save to appropriate directory
      String filePath;
      if (Platform.isAndroid) {
        final isAndroid13OrHigher = await _isAndroid13OrHigher();
        
        if (isAndroid13OrHigher) {
          // Android 13+ requires manage external storage permission
          final managePermission = await Permission.manageExternalStorage.request();
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

      // 5. Open the file so user can view/share it
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
  }) async {
    final qrWidth = qrImage.width.toDouble();
    final qrHeight = qrImage.height.toDouble();

    final headerHeight = math.max(72.0, qrWidth * 0.18);
    final footerHeight = math.max(48.0, qrWidth * 0.12);

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

    // Draw QR image
    final qrRect = Rect.fromLTWH(0, headerHeight, qrWidth, qrHeight);
    canvas.drawImageRect(
      qrImage,
      Rect.fromLTWH(0, 0, qrWidth, qrHeight),
      qrRect,
      Paint(),
    );

    // Footer texts
    final footerCenterY = headerHeight + qrHeight + (footerHeight / 2);
    final nameFontSize = math.max(14.0, qrWidth * 0.032);
    final dateFontSize = math.max(12.0, qrWidth * 0.028);

    final trimmedName = childName.trim().isEmpty ? 'Child' : childName.trim();
    drawText(
      'Name: $trimmedName',
      footerCenterY - 8,
      fontSize: nameFontSize,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF111827),
    );

    final now = DateTime.now();
    final dateText = 'Downloaded: ${now.month}/${now.day}/${now.year}';
    drawText(
      dateText,
      footerCenterY + 16,
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
}
