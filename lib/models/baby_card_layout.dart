/// Model for Baby Card PDF layout configuration
class BabyCardLayout {
  final String backgroundPath;
  final String? fallbackBackgroundPath;
  final PageConfig page;
  final FontConfig fonts;
  final BoxesConfig boxes;
  final VaccineLayout vaccines;
  final ExtrasConfig? extras;

  const BabyCardLayout({
    required this.backgroundPath,
    this.fallbackBackgroundPath,
    required this.page,
    required this.fonts,
    required this.boxes,
    required this.vaccines,
    this.extras,
  });

  factory BabyCardLayout.fromJson(Map<String, dynamic> json) {
    return BabyCardLayout(
      backgroundPath: json['background_path'] ?? '',
      fallbackBackgroundPath: json['fallback_background_path'],
      page: PageConfig.fromJson(json['page'] ?? {}),
      fonts: FontConfig.fromJson(json['fonts'] ?? {}),
      boxes: BoxesConfig.fromJson(json['boxes'] ?? {}),
      vaccines: VaccineLayout.fromJson(json['vaccines'] ?? {}),
      extras: json['extras'] != null
          ? ExtrasConfig.fromJson(json['extras'])
          : null,
    );
  }
}

/// Page configuration
class PageConfig {
  final String format;
  final String orientation;
  final String unit;

  const PageConfig({
    required this.format,
    required this.orientation,
    required this.unit,
  });

  factory PageConfig.fromJson(Map<String, dynamic> json) {
    return PageConfig(
      format: json['format'] ?? 'a4',
      orientation: json['orientation'] ?? 'landscape',
      unit: json['unit'] ?? 'mm',
    );
  }
}

/// Font configuration
class FontConfig {
  final double detailsPt;
  final double? wish;
  final double vaccinesPt;

  const FontConfig({
    required this.detailsPt,
    this.wish,
    required this.vaccinesPt,
  });

  factory FontConfig.fromJson(Map<String, dynamic> json) {
    return FontConfig(
      detailsPt: (json['details_pt'] as num?)?.toDouble() ?? 12.0,
      wish: (json['wish'] as num?)?.toDouble(),
      vaccinesPt: (json['vaccines_pt'] as num?)?.toDouble() ?? 11.0,
    );
  }
}

/// Boxes configuration for child information
class BoxesConfig {
  final double leftXPct;
  final double rightXPct;
  final double rightR4XPct;
  final double rightR4YPct;
  final Map<String, double> rowsYPct;
  final PositionConfig? sex;
  final PositionConfig? sexM;
  final PositionConfig? sexF;
  final double? maxWidthPct;

  const BoxesConfig({
    required this.leftXPct,
    required this.rightXPct,
    required this.rightR4XPct,
    required this.rightR4YPct,
    required this.rowsYPct,
    this.sex,
    this.sexM,
    this.sexF,
    this.maxWidthPct,
  });

  factory BoxesConfig.fromJson(Map<String, dynamic> json) {
    return BoxesConfig(
      leftXPct: (json['left_x_pct'] as num?)?.toDouble() ?? 0.0,
      rightXPct: (json['right_x_pct'] as num?)?.toDouble() ?? 0.0,
      rightR4XPct: (json['right_r4_x_pct'] as num?)?.toDouble() ?? 0.0,
      rightR4YPct: (json['right_r4_y_pct'] as num?)?.toDouble() ?? 0.0,
      rowsYPct: _parseRowsY(json['rows_y_pct']),
      sex: json['sex'] != null ? PositionConfig.fromJson(json['sex']) : null,
      sexM: json['sex_m'] != null
          ? PositionConfig.fromJson(json['sex_m'])
          : null,
      sexF: json['sex_f'] != null
          ? PositionConfig.fromJson(json['sex_f'])
          : null,
      maxWidthPct: (json['max_width_pct'] as num?)?.toDouble(),
    );
  }

  static Map<String, double> _parseRowsY(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, val) => MapEntry(key, (val as num).toDouble()));
    }
    return {};
  }

  /// Get Y position for a row (r1, r2, r3, r4)
  double? getRowY(String rowKey) {
    return rowsYPct[rowKey];
  }
}

/// Position configuration
class PositionConfig {
  final double xPct;
  final double yPct;

  const PositionConfig({required this.xPct, required this.yPct});

  factory PositionConfig.fromJson(Map<String, dynamic> json) {
    return PositionConfig(
      xPct: (json['x_pct'] as num?)?.toDouble() ?? 0.0,
      yPct: (json['y_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Vaccine layout configuration
class VaccineLayout {
  final Map<String, double> colsXPct; // Column positions (c1, c2, c3)
  final Map<String, double> rowsYPct; // Vaccine name -> Y position %

  const VaccineLayout({required this.colsXPct, required this.rowsYPct});

  factory VaccineLayout.fromJson(Map<String, dynamic> json) {
    return VaccineLayout(
      colsXPct: _parseColumns(json['cols_x_pct']),
      rowsYPct: _parseRows(json['rows_y_pct']),
    );
  }

  static Map<String, double> _parseColumns(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, val) => MapEntry(key, (val as num).toDouble()));
    }
    return {};
  }

  static Map<String, double> _parseRows(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, val) => MapEntry(key, (val as num).toDouble()));
    }
    return {};
  }

  /// Get Y position for a vaccine row
  double? getRowY(String vaccineKey) {
    return rowsYPct[vaccineKey];
  }

  /// Get X position for a column (c1, c2, c3)
  double? getColumnX(String columnKey) {
    return colsXPct[columnKey];
  }
}

/// Extras configuration
class ExtrasConfig {
  final TextFieldConfig? healthCenter;
  final TextFieldConfig? barangay;
  final TextFieldConfig? familyNo;

  const ExtrasConfig({this.healthCenter, this.barangay, this.familyNo});

  factory ExtrasConfig.fromJson(Map<String, dynamic> json) {
    return ExtrasConfig(
      healthCenter: json['health_center'] != null
          ? TextFieldConfig.fromJson(json['health_center'])
          : null,
      barangay: json['barangay'] != null
          ? TextFieldConfig.fromJson(json['barangay'])
          : null,
      familyNo: json['family_no'] != null
          ? TextFieldConfig.fromJson(json['family_no'])
          : null,
    );
  }
}

/// Text field configuration with text and position
class TextFieldConfig {
  final String? text;
  final double xPct;
  final double yPct;
  final double? maxWidthPct;

  const TextFieldConfig({
    this.text,
    required this.xPct,
    required this.yPct,
    this.maxWidthPct,
  });

  factory TextFieldConfig.fromJson(Map<String, dynamic> json) {
    return TextFieldConfig(
      text: json['text'],
      xPct: (json['x_pct'] as num?)?.toDouble() ?? 0.0,
      yPct: (json['y_pct'] as num?)?.toDouble() ?? 0.0,
      maxWidthPct: (json['max_width_pct'] as num?)?.toDouble(),
    );
  }
}
