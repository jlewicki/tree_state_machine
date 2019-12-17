/// Error throwm when accessing an object that has been disposed.
class DisposedError extends StateError {
  /// Constructs a [DisposedError] with an optional error message.
  DisposedError([String message = 'This object has been disposed']) : super(message);
}
