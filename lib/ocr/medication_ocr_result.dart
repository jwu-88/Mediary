/// OCR text and whether uncertain readings were recovered for manual review.
class MedicationOcrEvidence {
  const MedicationOcrEvidence(this.text, {this.recoveredUncertainText = false});

  final String text;
  final bool recoveredUncertainText;
}
