import 'dart:convert';

////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Errors
//

class DisposedError extends StateError {
  DisposedError([String message = 'This object has been disposed']) : super(message);
}

////////////////////////////////////////////////////////////////////////////////////////////////////
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
  Lazy(T Function() evaluator) {
    _value = _Deferred(evaluator);
  }

  /// The lazily-evaluated value.
  T get value {
    if (_value is _Deferred<T>) {
      _value = (_value as _Deferred<T>).eval();
    }
    return (_value as _Evaluated<T>).value;
  }

  bool get hasValue {
    return _value is _Evaluated<T>;
  }
}

abstract class _LazyValue<T> {}

class _Deferred<T> implements _LazyValue<T> {
  final T Function() evaluator;
  _Deferred(this.evaluator);
  _Evaluated<T> eval() => _Evaluated(evaluator());
}

class _Evaluated<T> implements _LazyValue<T> {
  final T value;
  _Evaluated(this.value);
}

////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Type trickery
//

// See https://github.com/dart-lang/sdk/issues/33297
class TypeLiteral<T> {
  Type get type => T;
}

bool isTypeOf<ThisType, OfType>() => _Instance<ThisType>() is _Instance<OfType>;

class _Instance<T> {}

////////////////////////////////////////////////////////////////////////////////////////////////////
///
/// Codecs
///

class JsonDataCodec<D> extends Codec<D, Object> {
  final JsonDataEncoder<D> _encoder;
  final JsonDataDecoder<D> _decoder;

  JsonDataCodec(
    Map<String, dynamic> Function(D data) encode,
    D Function(Map<String, dynamic> json) decode,
  )   : _encoder = JsonDataEncoder(encode),
        _decoder = JsonDataDecoder(decode);

  @override
  Converter<Object, D> get decoder => _decoder;
  @override
  Converter<D, Object> get encoder => _encoder;
}

class JsonDataEncoder<D> extends Converter<D, Object> {
  final Map<String, dynamic> Function(D data) _encode;
  JsonDataEncoder(this._encode);
  @override
  Object convert(D input) => _encode(input);
}

class JsonDataDecoder<D> extends Converter<Object, D> {
  final D Function(Map<String, dynamic> json) _decode;
  JsonDataDecoder(this._decode);
  @override
  D convert(Object input) => input is Map<String, dynamic>
      ? _decode(input)
      : throw ArgumentError.value(input, 'input', 'Input must be Map<String, dynamic>');
}
