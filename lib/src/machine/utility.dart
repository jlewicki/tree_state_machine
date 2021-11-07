import 'dart:async';

//==================================================================================================
//
// Type trickery
//

// See https://github.com/dart-lang/sdk/issues/33297
class TypeLiteral<T> {
  const TypeLiteral();
  Type get type => T;
}

bool isTypeOf<ThisType, OfType>() => _Instance<ThisType>() is _Instance<OfType>;

bool isTypeOfExact<ThisType, OfType>() =>
    isTypeOf<ThisType, OfType>() && isTypeOf<OfType, ThisType>();

class _Instance<T> {}

/// Returns `true` if [value] is a member of an enumeration.
bool isEnumValue(Object value) {
  final split = value.toString().split('.');
  return split.length > 1 && split[0] == value.runtimeType.toString();
}

/// Returns a short description of an enum value.
///
/// This is indentical to `describeEnum` from Flutter, which can't be used directly from a pure Dart
/// library.
String describeEnum(Object enumEntry) {
  final String description = enumEntry.toString();
  final int indexOfDot = description.indexOf('.');
  assert(
    indexOfDot != -1 && indexOfDot < description.length - 1,
    'The provided object "$enumEntry" is not an enum.',
  );
  return description.substring(indexOfDot + 1);
}

//==================================================================================================
//
// Errors
//

class DisposedError extends StateError {
  /// Constructs a [DisposedError] with an optional error message.
  DisposedError([String message = 'This object has been disposed']) : super(message);
}

//==================================================================================================
//
// Lazy
//

/// Holds a lazily-evaluated instance of type [T].
class Lazy<T> {
  _LazyValue<T> _value;

  /// Constructs a [Lazy] instance.
  ///
  /// [evaluator] will be used to evaluate the instance of T when the [value] property is first
  /// read.
  Lazy(T Function() evaluator) : _value = _Deferred(evaluator);

  /// The lazily-evaluated value.
  T get value {
    if (!hasValue) {
      _value = (_value as _Deferred<T>).eval();
    }
    return (_value as _Evaluated<T>).value;
  }

  /// Returns `true` if [value] has been evaluated.
  bool get hasValue {
    return _value is _Evaluated<T>;
  }

  /// Resets this [Lazy] so that the next call to [value] will re-evaluate the value.
  void reset() {
    if (hasValue) {
      _value = (_value as _Evaluated<T>).deferred;
    }
  }
}

class MutableLazy<T> extends Lazy<T> {
  /// Constructs a [MutableLazy] instance.
  ///
  /// [evaluator] will be used to evaluate the instance of T when the [value] property is first
  /// read.
  MutableLazy(T Function() evaluator) : super(evaluator);

  set value(T value) {
    if (hasValue) {
      (_value as _Evaluated<T>).value = value;
    } else {
      _value = _Evaluated(value, _value as _Deferred<T>);
    }
  }
}

abstract class _LazyValue<T> {}

class _Deferred<T> implements _LazyValue<T> {
  final T Function() evaluator;
  _Deferred(this.evaluator);
  _Evaluated<T> eval() => _Evaluated(evaluator(), this);
}

class _Evaluated<T> implements _LazyValue<T> {
  T value;
  final _Deferred<T> deferred;
  _Evaluated(this.value, this.deferred);
}

//==================================================================================================
//
// Ref
//
class Ref<T> {
  T value;
  Ref(this.value);
}

//==================================================================================================
//
// Disposable
//

/// Indicates that a type maintains resources that need to be released outside of garbage collection.
abstract class Disposable {
  ///
  void dispose();
}

//==================================================================================================
//
// Extension methods
//
typedef FutureOrBinder<T, R> = FutureOr<R> Function(T value);

extension FutureOrExtensions<T> on FutureOr<T> {
  /// Monadic bind operation for [FutureOr].
  FutureOr<R> bind<R>(FutureOrBinder<T, R> binder) {
    var futureOr = this;
    return futureOr is Future<T> ? futureOr.then(binder) : binder(futureOr);
  }
}