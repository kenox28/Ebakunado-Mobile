class VaccineOption {
  final String payloadName;
  final String displayLabel;
  final String? description;

  const VaccineOption({
    required this.payloadName,
    required this.displayLabel,
    this.description,
  });
}

class VaccineDoseInfo {
  final String canonicalName;
  final String seriesLabel;
  final int totalDoses;
  final int? seriesDose;

  const VaccineDoseInfo({
    required this.canonicalName,
    required this.seriesLabel,
    required this.totalDoses,
    this.seriesDose,
  });

  bool get hasSeriesTracking => seriesDose != null && totalDoses > 0;

  String get doseDisplay {
    if (seriesDose == null) return '';
    if (totalDoses <= 0) {
      return 'Dose $seriesDose';
    }
    return 'Dose $seriesDose of $totalDoses';
  }

  String get seriesWithDose {
    if (seriesDose == null) {
      return seriesLabel;
    }
    final doseText = doseDisplay;
    return doseText.isEmpty ? seriesLabel : '$seriesLabel ($doseText)';
  }
}

class VaccineCatalog {
  /// Accepted payload values expected by the PHP endpoints.
  static const List<String> acceptedPayloads = [
    'BCG',
    'Hepatitis B',
    'Pentavalent (DPT-HepB-Hib) - 1st',
    'Pentavalent (DPT-HepB-Hib) - 2nd',
    'Pentavalent (DPT-HepB-Hib) - 3rd',
    'OPV - 1st',
    'OPV - 2nd',
    'OPV - 3rd',
    'IPV - 1st',
    'IPV - 2nd',
    'IPV - 3rd',
    'PCV - 1st',
    'PCV - 2nd',
    'PCV - 3rd',
    'MCV1 (AMV)',
    'MCV2 (MMR)',
  ];

  static const List<VaccineOption> options = [
    VaccineOption(
      payloadName: 'BCG',
      displayLabel: 'BCG (Tuberculosis)',
      description: 'At birth',
    ),
    VaccineOption(
      payloadName: 'Hepatitis B',
      displayLabel: 'Hepatitis B (within 24 hrs)',
    ),
    VaccineOption(
      payloadName: 'Pentavalent (DPT-HepB-Hib) - 1st',
      displayLabel: 'Pentavalent – 1st dose',
    ),
    VaccineOption(
      payloadName: 'Pentavalent (DPT-HepB-Hib) - 2nd',
      displayLabel: 'Pentavalent – 2nd dose',
    ),
    VaccineOption(
      payloadName: 'Pentavalent (DPT-HepB-Hib) - 3rd',
      displayLabel: 'Pentavalent – 3rd dose',
    ),
    VaccineOption(payloadName: 'OPV - 1st', displayLabel: 'OPV – 1st dose'),
    VaccineOption(payloadName: 'OPV - 2nd', displayLabel: 'OPV – 2nd dose'),
    VaccineOption(payloadName: 'OPV - 3rd', displayLabel: 'OPV – 3rd dose'),
    VaccineOption(payloadName: 'IPV - 1st', displayLabel: 'IPV – 1st dose'),
    VaccineOption(payloadName: 'IPV - 2nd', displayLabel: 'IPV – 2nd dose'),
    VaccineOption(payloadName: 'IPV - 3rd', displayLabel: 'IPV – 3rd dose'),
    VaccineOption(payloadName: 'PCV - 1st', displayLabel: 'PCV – 1st dose'),
    VaccineOption(payloadName: 'PCV - 2nd', displayLabel: 'PCV – 2nd dose'),
    VaccineOption(payloadName: 'PCV - 3rd', displayLabel: 'PCV – 3rd dose'),
    VaccineOption(
      payloadName: 'MCV1 (AMV)',
      displayLabel: 'MCV1 (Anti-Measles Vaccine)',
    ),
    VaccineOption(
      payloadName: 'MCV2 (MMR)',
      displayLabel: 'MCV2 (Measles-Mumps-Rubella)',
    ),
  ];

  static const Map<String, String> _legacyNameMap = {
    'hepab1 (w/in 24 hrs)': 'Hepatitis B',
    'hepab1 (more than 24hrs)': 'Hepatitis B',
    'hepab1 (more than 24 hrs)': 'Hepatitis B',
    'hepab1 (within 24 hrs)': 'Hepatitis B',
    'hepab1': 'Hepatitis B',
    'hepa b': 'Hepatitis B',
    'hepa-b': 'Hepatitis B',
    'hepatitis b (w/in 24 hrs)': 'Hepatitis B',
    'hepatitis b (within 24 hrs)': 'Hepatitis B',
  };

  static const Set<String> _ignoredLegacyNames = {
    'rota virus vaccine - 1st',
    'rota virus vaccine - 2nd',
  };

  static final Map<String, String> _acceptedLookup = {
    for (final payload in acceptedPayloads) payload.toLowerCase(): payload,
  };

  static final Map<String, _SeriesMeta> _seriesLookup = {
    'BCG': _SeriesMeta(seriesLabel: 'BCG', totalDoses: 1, doseNumber: 1),
    'Hepatitis B': _SeriesMeta(
      seriesLabel: 'Hepatitis B',
      totalDoses: 1,
      doseNumber: 1,
    ),
    'Pentavalent (DPT-HepB-Hib) - 1st': _SeriesMeta(
      seriesLabel: 'Pentavalent (DPT-HepB-Hib)',
      totalDoses: 3,
      doseNumber: 1,
    ),
    'Pentavalent (DPT-HepB-Hib) - 2nd': _SeriesMeta(
      seriesLabel: 'Pentavalent (DPT-HepB-Hib)',
      totalDoses: 3,
      doseNumber: 2,
    ),
    'Pentavalent (DPT-HepB-Hib) - 3rd': _SeriesMeta(
      seriesLabel: 'Pentavalent (DPT-HepB-Hib)',
      totalDoses: 3,
      doseNumber: 3,
    ),
    'OPV - 1st': _SeriesMeta(seriesLabel: 'OPV', totalDoses: 3, doseNumber: 1),
    'OPV - 2nd': _SeriesMeta(seriesLabel: 'OPV', totalDoses: 3, doseNumber: 2),
    'OPV - 3rd': _SeriesMeta(seriesLabel: 'OPV', totalDoses: 3, doseNumber: 3),
    'IPV - 1st': _SeriesMeta(seriesLabel: 'IPV', totalDoses: 3, doseNumber: 1),
    'IPV - 2nd': _SeriesMeta(seriesLabel: 'IPV', totalDoses: 3, doseNumber: 2),
    'IPV - 3rd': _SeriesMeta(seriesLabel: 'IPV', totalDoses: 3, doseNumber: 3),
    'PCV - 1st': _SeriesMeta(seriesLabel: 'PCV', totalDoses: 3, doseNumber: 1),
    'PCV - 2nd': _SeriesMeta(seriesLabel: 'PCV', totalDoses: 3, doseNumber: 2),
    'PCV - 3rd': _SeriesMeta(seriesLabel: 'PCV', totalDoses: 3, doseNumber: 3),
    'MCV1 (AMV)': _SeriesMeta(
      seriesLabel: 'Measles-Containing Vaccine',
      totalDoses: 2,
      doseNumber: 1,
    ),
    'MCV2 (MMR)': _SeriesMeta(
      seriesLabel: 'Measles-Containing Vaccine',
      totalDoses: 2,
      doseNumber: 2,
    ),
  };

  static bool isAccepted(String value) {
    return _acceptedLookup.containsKey(value.trim().toLowerCase());
  }

  static List<String> normalizeOutgoingSelections(Iterable<String> selections) {
    final normalizedSet = <String>{};
    for (final selection in selections) {
      final trimmed = selection.trim();
      if (trimmed.isEmpty) continue;
      final normalized = _acceptedLookup[trimmed.toLowerCase()];
      if (normalized != null) {
        normalizedSet.add(normalized);
      }
    }

    return acceptedPayloads
        .where((payload) => normalizedSet.contains(payload))
        .toList(growable: false);
  }

  static bool shouldIgnoreLegacyName(String rawName) {
    final normalized = rawName.trim().toLowerCase();
    return _ignoredLegacyNames.contains(normalized);
  }

  static String? normalizeIncomingName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final lower = trimmed.toLowerCase();

    if (_ignoredLegacyNames.contains(lower)) {
      return null;
    }

    if (_legacyNameMap.containsKey(lower)) {
      return _legacyNameMap[lower];
    }

    return _acceptedLookup[lower] ?? trimmed;
  }

  static VaccineDoseInfo describeDose(String canonicalName) {
    final meta = _seriesLookup[canonicalName];
    return VaccineDoseInfo(
      canonicalName: canonicalName,
      seriesLabel: meta?.seriesLabel ?? canonicalName,
      totalDoses: meta?.totalDoses ?? 1,
      seriesDose: meta?.doseNumber,
    );
  }
}

class _SeriesMeta {
  final String seriesLabel;
  final int totalDoses;
  final int? doseNumber;

  const _SeriesMeta({
    required this.seriesLabel,
    required this.totalDoses,
    this.doseNumber,
  });
}
