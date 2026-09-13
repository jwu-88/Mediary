/// Formats catalog and schedule text for consistent, readable UI labels.
///
/// Public catalog values are intentionally stored as received. This helper is
/// display-only, preserving short medical abbreviations such as `MG`, `IU`,
/// and `Rx` while title-casing ordinary words.
String titleCaseDisplay(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  final tokenPattern = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]+|[^A-Za-zÀ-ÖØ-öø-ÿ]+');
  return tokenPattern.allMatches(trimmed).map((match) {
    final token = match.group(0)!;
    if (!RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(token)) return token;
    final letters = token.replaceAll(RegExp(r'[^A-Za-zÀ-ÖØ-öø-ÿ]'), '');
    const unitAbbreviations = {'g', 'kg', 'mcg', 'mg', 'ml', 'l', 'iu'};
    if (unitAbbreviations.contains(letters.toLowerCase())) {
      return letters.toUpperCase();
    }
    if (letters.length <= 3 && letters == letters.toUpperCase()) {
      return token;
    }
    final lower = token.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }).join();
}
