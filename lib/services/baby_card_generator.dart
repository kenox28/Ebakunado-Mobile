import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/baby_card_layout.dart';

/// Service for generating Baby Card PDFs
class BabyCardGenerator {
  // A4 Landscape dimensions in points (PDF unit)
  // A4 Landscape: 297mm × 210mm = 841.89pt × 595.28pt
  static const double a4LandscapeWidthPt = 841.89; // 297mm × 2.83465
  static const double a4LandscapeHeightPt = 595.28; // 210mm × 2.83465
  /// Generate a Baby Card PDF
  static Future<Uint8List> generatePdf({
    required BabyCardLayout layout,
    required Map<String, dynamic> childData,
    required List<Map<String, dynamic>> immunizations,
    required List<int> backgroundImageBytes,
  }) async {
    final pdf = pw.Document();

    // Create the PDF page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) {
          return pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              // Background image (full page)
              pw.Positioned.fill(
                child: pw.Image(
                  pw.MemoryImage(Uint8List.fromList(backgroundImageBytes)),
                  fit: pw.BoxFit.cover,
                ),
              ),

              // Child information boxes
              ..._buildChildInfoBoxes(layout, childData, context),

              // Immunization records
              ..._buildImmunizationRecords(layout, immunizations, context),

              // Extras (health center, barangay, family no)
              ..._buildExtrasBoxes(layout, childData, context),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Build text boxes for child information
  static List<pw.Widget> _buildChildInfoBoxes(
    BabyCardLayout layout,
    Map<String, dynamic> childData,
    pw.Context context,
  ) {
    final boxes = <pw.Widget>[];
    // Use explicit A4 landscape dimensions in points (matches layout JSON)
    final pageWidth = a4LandscapeWidthPt; // 297mm = 841.89pt
    final pageHeight = a4LandscapeHeightPt; // 210mm = 595.28pt

    final boxesConfig = layout.boxes;
    final fontSize = layout.fonts.detailsPt;

    // Row 1: Child Name (left), Birth Date (right)
    final r1Y = boxesConfig.getRowY('r1');
    if (r1Y != null) {
      // Left: Full Name
      final childName =
          '${childData['child_fname'] ?? ''} ${childData['child_lname'] ?? ''}'
              .trim()
              .toUpperCase();
      boxes.add(
        pw.Positioned(
          left: (boxesConfig.leftXPct / 100) * pageWidth,
          top: (r1Y / 100) * pageHeight,
          child: pw.Text(childName, style: pw.TextStyle(fontSize: fontSize)),
        ),
      );

      // Right: Birth Date
      final birthDate = _formatDate(childData['child_birth_date']);
      boxes.add(
        pw.Positioned(
          left: (boxesConfig.rightXPct / 100) * pageWidth,
          top: (r1Y / 100) * pageHeight,
          child: pw.Text(birthDate, style: pw.TextStyle(fontSize: fontSize)),
        ),
      );
    }

    // Row 2: Place of Birth (left), Address (right)
    final r2Y = boxesConfig.getRowY('r2');
    if (r2Y != null) {
      // Left: Place of Birth
      final placeOfBirth = childData['place_of_birth']?.toString() ?? '';
      if (placeOfBirth.isNotEmpty) {
        boxes.add(
          pw.Positioned(
            left: (boxesConfig.leftXPct / 100) * pageWidth,
            top: (r2Y / 100) * pageHeight,
            child: pw.Text(
              placeOfBirth.toUpperCase(),
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
        );
      }

      // Right: Address
      final address = childData['address']?.toString() ?? '';
      if (address.isNotEmpty) {
        boxes.add(
          pw.Positioned(
            left: (boxesConfig.rightXPct / 100) * pageWidth,
            top: (r2Y / 100) * pageHeight,
            child: pw.Text(
              address.toUpperCase(),
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
        );
      }
    }

    // Row 3: Mother Name (left), Father Name (right)
    final r3Y = boxesConfig.getRowY('r3');
    if (r3Y != null) {
      // Left: Mother Name
      final motherName = childData['mother_name']?.toString() ?? '';
      if (motherName.isNotEmpty) {
        boxes.add(
          pw.Positioned(
            left: (boxesConfig.leftXPct / 100) * pageWidth,
            top: (r3Y / 100) * pageHeight,
            child: pw.Text(
              motherName.toUpperCase(),
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
        );
      }

      // Right: Father Name
      final fatherName = childData['father_name']?.toString() ?? '';
      if (fatherName.isNotEmpty) {
        boxes.add(
          pw.Positioned(
            left: (boxesConfig.rightXPct / 100) * pageWidth,
            top: (r3Y / 100) * pageHeight,
            child: pw.Text(
              fatherName.toUpperCase(),
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
        );
      }
    }

    // Row 4: Birth Weight & Height (left), Blood Type (right)
    final r4Y = boxesConfig.getRowY('r4');
    if (r4Y != null) {
      // Left: Birth Weight & Height
      final birthWeight = childData['birth_weight']?.toString() ?? '';
      final birthHeight = childData['birth_height']?.toString() ?? '';
      if (birthWeight.isNotEmpty && birthHeight.isNotEmpty) {
        boxes.add(
          pw.Positioned(
            left: (boxesConfig.leftXPct / 100) * pageWidth,
            top: (r4Y / 100) * pageHeight,
            child: pw.Text(
              '$birthWeight kg / $birthHeight cm',
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
        );
      }

      // Right: Blood Type
      final bloodType = childData['blood_type']?.toString() ?? '';
      if (bloodType.isNotEmpty) {
        boxes.add(
          pw.Positioned(
            left: (boxesConfig.rightR4XPct / 100) * pageWidth,
            top: (boxesConfig.rightR4YPct / 100) * pageHeight,
            child: pw.Text(bloodType, style: pw.TextStyle(fontSize: fontSize)),
          ),
        );
      }
    }

    // Gender checkbox (use 'X' instead of checkmark for font compatibility)
    final gender = childData['child_gender']?.toString().toLowerCase() ?? '';
    if (gender == 'male' && boxesConfig.sexM != null) {
      boxes.add(
        pw.Positioned(
          left: (boxesConfig.sexM!.xPct / 100) * pageWidth,
          top: (boxesConfig.sexM!.yPct / 100) * pageHeight,
          child: pw.Text('X', style: pw.TextStyle(fontSize: fontSize)),
        ),
      );
    } else if (gender == 'female' && boxesConfig.sexF != null) {
      boxes.add(
        pw.Positioned(
          left: (boxesConfig.sexF!.xPct / 100) * pageWidth,
          top: (boxesConfig.sexF!.yPct / 100) * pageHeight,
          child: pw.Text('X', style: pw.TextStyle(fontSize: fontSize)),
        ),
      );
    }

    return boxes;
  }

  /// Build immunization records table
  static List<pw.Widget> _buildImmunizationRecords(
    BabyCardLayout layout,
    List<Map<String, dynamic>> immunizations,
    pw.Context context,
  ) {
    final boxes = <pw.Widget>[];
    // Use explicit A4 landscape dimensions in points (matches layout JSON)
    final pageWidth = a4LandscapeWidthPt; // 297mm = 841.89pt
    final pageHeight = a4LandscapeHeightPt; // 210mm = 595.28pt
    final fontSize = layout.fonts.vaccinesPt;

    for (final imm in immunizations) {
      final vaccineName = imm['vaccine_name']?.toString() ?? '';
      final doseNumber = imm['dose_number'] as int? ?? 1;
      final dateGiven = imm['date_given']?.toString();
      final status = imm['status']?.toString() ?? '';

      // Only show if vaccine was taken
      if (status != 'taken' || dateGiven == null || dateGiven.isEmpty) {
        continue;
      }

      // Map vaccine name to row key
      final rowKey = _mapVaccineToRowKey(vaccineName);
      if (rowKey == null) {
        continue; // Unknown vaccine or ignored (IPV/Rota)
      }

      // Get column key based on dose number
      final columnKey = _getColumnKey(rowKey, doseNumber);
      if (columnKey == null) {
        continue;
      }

      // Get position from layout
      final rowY = layout.vaccines.getRowY(rowKey);
      final columnX = layout.vaccines.getColumnX(columnKey);

      if (rowY != null && columnX != null) {
        // Format date as M/D/YY
        final formattedDate = _formatDateShort(dateGiven);

        boxes.add(
          pw.Positioned(
            left: (columnX / 100) * pageWidth,
            top: (rowY / 100) * pageHeight,
            child: pw.Text(
              formattedDate,
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
        );
      }
    }

    return boxes;
  }

  /// Build extras boxes (health center, barangay, family no)
  static List<pw.Widget> _buildExtrasBoxes(
    BabyCardLayout layout,
    Map<String, dynamic> childData,
    pw.Context context,
  ) {
    final boxes = <pw.Widget>[];
    // Use explicit A4 landscape dimensions in points (matches layout JSON)
    final pageWidth = a4LandscapeWidthPt; // 297mm = 841.89pt
    final pageHeight = a4LandscapeHeightPt; // 210mm = 595.28pt
    final fontSize = layout.fonts.detailsPt;

    final extras = layout.extras;

    // Health Center
    if (extras?.healthCenter != null) {
      final hc = extras!.healthCenter!;
      boxes.add(
        pw.Positioned(
          left: (hc.xPct / 100) * pageWidth,
          top: (hc.yPct / 100) * pageHeight,
          child: pw.Text(
            hc.text ?? '',
            style: pw.TextStyle(fontSize: fontSize),
          ),
        ),
      );
    }

    // Barangay (from child address or child data)
    if (extras?.barangay != null) {
      final barangay = extras!.barangay!;
      // Try to extract barangay from address or use barangay field
      final barangayText =
          childData['barangay']?.toString() ??
          childData['address']?.toString() ??
          '';
      if (barangayText.isNotEmpty) {
        boxes.add(
          pw.Positioned(
            left: (barangay.xPct / 100) * pageWidth,
            top: (barangay.yPct / 100) * pageHeight,
            child: pw.Text(
              barangayText.toUpperCase(),
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
        );
      }
    }

    // Family Number
    if (extras?.familyNo != null) {
      final familyNo = extras!.familyNo!;
      final familyNoText =
          childData['family_no']?.toString() ??
          childData['family_number']?.toString() ??
          '';
      if (familyNoText.isNotEmpty) {
        boxes.add(
          pw.Positioned(
            left: (familyNo.xPct / 100) * pageWidth,
            top: (familyNo.yPct / 100) * pageHeight,
            child: pw.Text(
              familyNoText,
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
        );
      }
    }

    return boxes;
  }

  /// Map vaccine name to row key (case-insensitive contains)
  static String? _mapVaccineToRowKey(String vaccineName) {
    final name = vaccineName.toLowerCase();

    // Ignore IPV and Rota
    if (name.contains('ipv') || name.contains('rota')) {
      return null;
    }

    // Map to row keys
    if (name.contains('bcg')) return 'BCG';
    if (name.contains('hep') || name.contains('hepatitis')) {
      return 'HEPATITIS B';
    }
    if (name.contains('penta') || name.contains('hib')) return 'PENTAVALENT';
    if (name.contains('opv') || name.contains('oral polio')) return 'OPV';
    if (name.contains('pcv') || name.contains('pneumo')) return 'PCV';
    if (name.contains('mmr') ||
        name.contains('measles') ||
        name.contains('mcv'))
      return 'MMR';

    return null;
  }

  /// Get column key based on vaccine series and dose number
  static String? _getColumnKey(String rowKey, int doseNumber) {
    switch (rowKey) {
      case 'BCG':
      case 'HEPATITIS B':
        // Single dose vaccines - always column 1
        return doseNumber == 1 ? 'c1' : null;

      case 'PENTAVALENT':
      case 'OPV':
      case 'PCV':
        // 3-dose series
        if (doseNumber == 1) return 'c1';
        if (doseNumber == 2) return 'c2';
        if (doseNumber == 3) return 'c3';
        return null;

      case 'MMR':
        // 2-dose series (MCV1, MCV2)
        if (doseNumber == 1) return 'c1';
        if (doseNumber == 2) return 'c2';
        return null;

      default:
        return null;
    }
  }

  /// Format date as "Month DD, YYYY"
  static String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '';

    try {
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return dateValue.toString();
      }

      return DateFormat('MMMM dd, yyyy').format(date);
    } catch (e) {
      return dateValue.toString();
    }
  }

  /// Format date as "M/D/YY" for immunization table
  static String _formatDateShort(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('M/d/yy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}
