/// An error raised by Tiktoken.
class TiktokenError extends Error {
  TiktokenError(this.message);

  /// The message
  final String message;

  @override
  String toString() => "TiktokenError: $message";
}
