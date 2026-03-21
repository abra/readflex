// String utility extensions.
//
// limit(n) truncates a string to n characters. Used when logging bloc states
// to prevent unreadable output from large serialized objects.
extension StringExtension on String {
  /// Returns the first [length] characters of this string.
  ///
  /// If [length] is negative the original string is returned.
  /// If [length] is zero an empty string is returned.
  String limit(int length) => length < 0
      ? this
      : (length == 0
            ? ''
            : (length < this.length ? substring(0, length) : this));
}
