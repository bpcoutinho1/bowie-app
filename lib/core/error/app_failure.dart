class AppFailure implements Exception {
  const AppFailure(this.message, {this.retryable = false});

  final String message;

  /// True when the same action can succeed later without user changes.
  final bool retryable;

  @override
  String toString() => message;
}
