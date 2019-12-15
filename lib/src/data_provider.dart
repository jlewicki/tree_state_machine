import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'utility.dart';

abstract class ObservableData<D> {
  D get data;
  Stream<D> get stream;
}

abstract class DataProvider<D> {
  /// The data associated with this provider.
  D get data;

  /// Encodes the data associated with this provider into a format appropriate for serialization.
  Object encode();

  /// Decodes the specified object and and replaces [data] with the decoded value.
  ///
  /// [input] must be in the same format as produced by calling [encode].
  void decodeInto(Object input);

  /// Calls the specified function to produce a new data value, and replaces [data] with this value.
  void replace(D Function() replace);

  /// Calls the specified function that updates the current data value.
  ///
  /// Note that in the future this may result in a change notification.
  void update(void Function() update);

  /// Releases any resources associated with this provider.
  ///
  /// It is assumed that this provider will never be accessed again after this method is called.
  void dispose();
}

/// A data provider that owns an updatable data instance of type `D`.
class OwnedDataProvider<D> implements DataProvider<D>, ObservableData<D> {
  final Object Function(D data) encoder;
  final D Function(Object encoded) decoder;
  Lazy<BehaviorSubject<D>> _lazySubject;
  bool _disposed = false;

  OwnedDataProvider(D Function() eval, this.encoder, this.decoder) {
    _lazySubject = Lazy(() => BehaviorSubject<D>.seeded(eval()));
  }

  factory OwnedDataProvider.json(
    D Function() eval,
    Map<String, dynamic> Function(D data) encoder,
    D Function(Map<String, Object> json) decoder,
  ) {
    return OwnedDataProvider(eval, encoder, (obj) {
      return obj is Map<String, dynamic>
          ? decoder(obj)
          : throw ArgumentError('Value to decode must me Map<String, dynamic>');
    });
  }

  @override
  D get data {
    _throwIfDisposed();
    return _lazySubject.value.value;
  }

  @override
  Stream<D> get stream {
    _throwIfDisposed();
    return _lazySubject.value.stream;
  }

  @override
  Object encode() => encoder(data);

  @override
  void decodeInto(Object input) {
    _throwIfDisposed();
    ArgumentError.checkNotNull('input');
    _lazySubject.value.add(decoder(input));
  }

  @override
  void replace(D Function() replace) {
    _throwIfDisposed();
    _lazySubject.value.add(replace());
  }

  @override
  void update(void Function() update) {
    _throwIfDisposed();
    replace(() {
      update();
      return data;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    if (_lazySubject.hasValue) {
      _lazySubject.value.close();
    }
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw DisposedError();
    }
  }
}

/// A data provider that provides a view of a data instance that is owned by the current leaf state
/// of a state machine.
class CurrentLeafDataProvider<D> implements DataProvider<D>, ObservableData<D> {
  StreamSubscription _subscription;
  Lazy<BehaviorSubject<D>> _lazySubject;
  bool _disposed = false;

  void initializeLeafData(ObservableData<Object> observableLeafData) {
    ArgumentError.checkNotNull(observableLeafData, 'observableLeafData');
    _lazySubject = Lazy(() {
      // Seed with current value, which ensures that subscribers to the stream are sent the current
      // value (in a future microtask)
      var skippedFirstSame = false;
      var subject = BehaviorSubject.seeded(_leafDataAsD(observableLeafData.data));
      // Note that we skip adding if its the same value. Otherwise this subscription might
      // immediately receive (in a future microtask) the current leaf value (if the source is a
      // behavior subject). Since we seeded our subject with this value, we don't want to emit an
      // indentical value unnecessarily. We only do this once though, in case the source emits when
      // the current leaf value is mutated as opposed to producing a new intstance.
      _subscription = observableLeafData.stream.map(_leafDataAsD).skipWhile((v) {
        if (skippedFirstSame) return false;
        if (identical(v, subject.value)) {
          skippedFirstSame = true;
          return true;
        }
        return false;
      }).listen(subject.add);
      return subject;
    });
  }

  BehaviorSubject<D> get subject => _lazySubject.value;

  @override
  D get data {
    _throwIfDisposed();
    assert(_lazySubject != null, 'initializeLeafData has not been called.');
    return _lazySubject.value.value;
  }

  @override
  Stream<D> get stream {
    _throwIfDisposed();
    assert(_lazySubject != null, 'initializeLeafData has not been called.');
    return _lazySubject.value;
  }

  @override
  Object encode() => null;

  @override
  void decodeInto(Object input) {}

  @override
  void update(void Function() update) {
    _throwIfDisposed();
    update();
    _lazySubject.value.add(data);
  }

  /// Throws [UnsupportedError] if called.
  ///
  /// Because this provider does not own the leaf data (which is likely a subtype of `D`), replacing
  /// with a new value is not allowed.
  @override
  void replace(D Function() replace) {
    throw UnsupportedError('Leaf data provider cannot replace a value');
  }

  @override
  void dispose() {
    _disposed = true;
    if (_lazySubject.hasValue) {
      _subscription?.cancel();
      _lazySubject.value.close();
    }
  }

  D _leafDataAsD(Object leafData) {
    if (leafData is! D) {
      throw StateError(
          'Expected leaf data of type ${TypeLiteral<D>().type}, but received ${leafData?.runtimeType}');
    }
    return leafData as D;
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw DisposedError();
    }
  }
}

/// An [ObservableData] that delegates its behavior to external functions.
class DelegateObservableData<D> extends ObservableData<D> {
  final D Function() _getData;
  final Lazy<Stream<D>> _lazyStream;

  DelegateObservableData({D Function() getData, Stream<D> Function() createStream})
      : _getData = getData ?? (() => null),
        _lazyStream = Lazy(createStream ?? () => Stream.empty());

  @override
  D get data => _getData();

  @override
  Stream<D> get stream => _lazyStream.value;
}
