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

/// Whether [relativePath] is a safe library-relative path under one of
/// [allowedRoots].
///
/// Relative paths in the database always use forward slashes and always stay
/// inside the library. Anything that could escape it — an absolute path, a
/// drive letter, a backslash, a `.` or `..` segment, an empty segment — is
/// refused, because a restored backup is the one place where such a value
/// could arrive from outside this bridge.
bool isSafeLibraryRelativePath(
  String relativePath, {
  required Set<String> allowedRoots,
}) {
  if (relativePath.isEmpty ||
      relativePath.startsWith('/') ||
      relativePath.contains(r'\') ||
      relativePath.contains(':')) {
    return false;
  }
  final segments = relativePath.split('/');
  if (segments.length < 2 || !allowedRoots.contains(segments.first)) {
    return false;
  }
  return segments.every(
    (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
  );
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
