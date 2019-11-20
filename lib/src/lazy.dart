typedef Evaluator<T> = T Function<T>();

class Lazy<T> {
  _LazyValue<T> _value;

  Lazy(Evaluator<T> evaluator) {
    _value = _Deferred(evaluator);
  }

  T get value {
    if (_value is _Deferred<T>) {
      _value = (_value as _Deferred<T>).eval();
    }
    return (_value as _Evaluated<T>).value;
  }
}

abstract class _LazyValue<T> {}

class _Deferred<T> implements _LazyValue<T> {
  final Evaluator<T> evaluator;
  _Deferred(this.evaluator) {}
  _Evaluated<T> eval() => _Evaluated(evaluator());
}

class _Evaluated<T> implements _LazyValue<T> {
  final T value;
  _Evaluated(this.value) {}
}
