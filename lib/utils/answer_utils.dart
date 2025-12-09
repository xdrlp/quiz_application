String normalizeAnswerForComparison(String s) {
  // Convert to uppercase and remove all whitespace
  return s.toUpperCase().replaceAll(RegExp(r"\s+"), '');
}
