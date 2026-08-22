import 'dart:io';

/// Joins [relative] onto [base] using the platform path separator.
String joinPath(String base, String relative) {
  if (base.endsWith('\\') || base.endsWith('/')) {
    return '$base$relative';
  }
  return '$base${Platform.pathSeparator}$relative';
}

/// Joins several segments left-to-right onto [base].
String joinAllPath(String base, Iterable<String> segments) {
  var result = base;
  for (final segment in segments) {
    result = joinPath(result, segment);
  }
  return result;
}

/// Converts a canonical forward-slash relative path into a platform path.
///
/// Relative paths stored in the database always use `/`; only when touching
/// the file system are they translated to the local separator.
String toPlatformRelativePath(String relativePath) {
  if (Platform.pathSeparator == r'/') {
    return relativePath;
  }
  return relativePath.replaceAll(r'/', Platform.pathSeparator);
}
