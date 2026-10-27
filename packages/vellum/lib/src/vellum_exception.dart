/// A file that cannot be read as the format it claims to be.
///
/// Repositories map it to the domain's exceptions; the message is for logs,
/// not for the screen.
class VellumException implements Exception {
  const VellumException(this.message);

  final String message;

  @override
  String toString() => 'VellumException: $message';
}
