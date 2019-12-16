/// Error throwm when accessing an object that has been disposed.
class DisposedError extends StateError {
  DisposedError([String message = 'This object has been disposed']) : super(message);
}
