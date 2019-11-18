typedef T Factory<T>();

// Adapted from https://stackoverflow.com/a/33219409
class Lazy<T> {
  static final _cache = new Expando();
  final Factory<T> _factory;
  
  const Lazy(this._factory);

  T get value {
    var result = _cache[this];
    if (identical(this, result)) return null;
    if (result != null) return result;
    result = _factory();
    _cache[this] = (result == null) ? this : result;
    return result;
  }
}
