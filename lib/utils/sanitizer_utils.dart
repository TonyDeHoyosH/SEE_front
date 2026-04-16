class SanitizerUtils {
  /// Basic sanitize string function that removes or escapes HTML tags
  /// to prevent XSS or sending raw HTML labels.
  static String sanitizeHtml(String text) {
    if (text.isEmpty) return text;
    
    // Replace < and > to prevent HTML tag generation
    return text
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
