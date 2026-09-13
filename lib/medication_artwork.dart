import 'package:flutter/material.dart';

/// A deterministic, generated illustration for a live catalog medication.
///
/// RxNorm and openFDA provide clinical metadata and labels, but do not expose a
/// consistent product-image field for every RxCUI. This artwork gives every
/// live result a distinct visual identity without pretending that an unrelated
/// pill photo is the selected product.
class MedicationArtwork extends StatelessWidget {
  const MedicationArtwork({
    super.key,
    required this.seed,
    this.label,
    this.size = 48,
  });

  final String seed;
  final String? label;
  final double size;

  static const _palettes = <(Color, Color)>[
    (Color(0xFFDBEAFE), Color(0xFF1D4ED8)),
    (Color(0xFFDCFCE7), Color(0xFF15803D)),
    (Color(0xFFFFEDD5), Color(0xFFC2410C)),
    (Color(0xFFF3E8FF), Color(0xFF7E22CE)),
    (Color(0xFFFCE7F3), Color(0xFFBE185D)),
    (Color(0xFFCCFBF1), Color(0xFF0F766E)),
  ];

  static const _icons = <IconData>[
    Icons.medication_outlined,
    Icons.local_pharmacy_outlined,
    Icons.vaccines_outlined,
    Icons.healing_outlined,
    Icons.science_outlined,
    Icons.health_and_safety_outlined,
  ];

  int _hash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.runes) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  @override
  Widget build(BuildContext context) {
    final hash = _hash(seed);
    final palette = _palettes[hash % _palettes.length];
    final icon = _icons[(hash ~/ _palettes.length) % _icons.length];
    return Semantics(
      image: true,
      label: label == null ? 'Medication artwork' : 'Artwork for $label',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.$1,
          borderRadius: BorderRadius.circular(size * .28),
          border: Border.all(color: palette.$2.withValues(alpha: .18)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              right: size * .08,
              top: size * .08,
              child: Container(
                width: size * .22,
                height: size * .22,
                decoration: BoxDecoration(
                  color: palette.$2.withValues(alpha: .18),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Icon(icon, color: palette.$2, size: size * .53),
          ],
        ),
      ),
    );
  }
}
