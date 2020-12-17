import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'errors.dart';
import 'utility.dart';

/// A [Stream] that provides synchronous access to the last emitted item.
///
/// Note that this is similar to the `ValueStream` interface from RxDart. It is duplicated here
/// to avoid exposing RxDart types as part of the public API of this library.
abstract class DataStream<T> implements Stream<T> {
  /// Last emitted value, or `null` if there has been no emission yet.
  T get value;

  /// `True` if at least one event has been emitted.
  bool get hasValue;
}

/// Provides access to a [DataStream] describing how a data value of type `D` changes over time.
///
/// [ObservableData] is typically used to provide read-only access to the data associated with a
/// [DataTreeState].
abstract class ObservableData<D> {
  /// A stream providing synchronous access to the current data value.
  DataStream<D> get dataStream;
}

/// Provides access to the data value associated with a [DataTreeState].
///
/// While a [TreeState] can maintain various data values during its lifecycle in member fields
/// private to the state, it can be convenient to package these values into their own type, and
/// mediate access to a value of that type using [DataTreeState] and its associated [DataProvider].
/// Doing so provides:
///
///   * Support for (de)serialization of this data when the state is active, and the state machine
///     is saved using [TreeStateMachine.saveTo].
///   * Support for change notification as the data changes over time. This can be useful for
///     keeping a user interface up to date with the data associated with the state.
abstract class DataProvider<D> {
  /// The current data value for this provider.
  D get data;

  /// Encodes the data associated with this provider into a format appropriate for serialization.
  Object encode();

  /// Decodes the specified object and and replaces [data] with the decoded value.
  ///
  /// [input] must be in the same format as produced by calling [encode].
  void decodeInto(Object input);

  /// Calls the specified function to produce a new data value, and replaces [data] with this value.
  ///
  /// This will result in a change notification if the implementation supports [ObservableData].
  void replace(D Function() replace);

  /// Calls the specified function that updates the current data value.
  ///
  /// This will result in a change notification if the implementation supports [ObservableData].
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
  Lazy<DataSubject<D>> _lazySubject;
  bool _disposed = false;

  OwnedDataProvider._(D Function() eval, this.encoder, this.decoder) {
    _lazySubject = Lazy(() => DataSubject(BehaviorSubject<D>.seeded(eval())));
  }

  /// Constructs an [OwnedDataProvider].
  ///
  /// The provider will obtain its initial value by calling the `eval` function when the [data]
  /// property is first accessed.
  ///
  /// The returned provider does not support serialization.
  factory OwnedDataProvider(
    D Function() eval,
  ) {
    ArgumentError.checkNotNull(eval, 'eval');
    return OwnedDataProvider<D>._(eval, _unsupportedEncoder, _unsupportedDecoder);
  }

  /// Constructs an [OwnedDataProvider].
  ///
  /// The provider will obtain its initial value by calling the `eval` function when the [data]
  /// property is first accessed.
  ///
  /// The returned provider support serialization by calling the `encoder` and `decoder` at the
  /// appropriate times.
  factory OwnedDataProvider.encodable(
    D Function() eval,
    Object Function(D data) encoder,
    D Function(Object encoded) decoder,
  ) {
    return OwnedDataProvider<D>._(eval, encoder, decoder);
  }

  factory OwnedDataProvider.json(
    D Function() eval,
    Map<String, dynamic> Function(D data) encoder,
    D Function(Map<String, Object> json) decoder,
  ) {
    return OwnedDataProvider<D>._(eval, encoder, (obj) {
      return obj is Map<String, dynamic>
          ? decoder(obj)
          : throw ArgumentError('Value to decode must me Map<String, dynamic>');
    });
  }

  @override
  DataStream<D> get dataStream {
    _throwIfDisposed();
    return _lazySubject.value;
  }

  @override
  D get data => dataStream.value;

  @override
  Object encode() => encoder(data);

  @override
  void decodeInto(Object input) {
    _throwIfDisposed();
    ArgumentError.checkNotNull('input');
    _lazySubject.value.wrappedSubject.add(decoder(input));
  }

  @override
  void replace(D Function() replace) {
    _throwIfDisposed();
    _lazySubject.value.wrappedSubject.add(replace());
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
      _lazySubject.value.wrappedSubject.close();
    }
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw DisposedError();
    }
  }

  static Object _unsupportedEncoder<D>(D data) {
    throw UnsupportedError('This provider does not support encoding');
  }

  static D _unsupportedDecoder<D>(Object encoded) {
    throw UnsupportedError('This provider does not support decoding');
  }
}

/// Adapts a BehaviorSubject to the [DataStream] interface.
class DataSubject<T> extends StreamView<T> implements DataStream<T> {
  final BehaviorSubject<T> _subject;
  DataSubject(this._subject) : super(_subject.stream);
  BehaviorSubject<T> get wrappedSubject => _subject;
  @override
  T get value => _subject.value;
  @override
  bool get hasValue => _subject.hasValue;
}

/// Extension methods for [DataStream].
extension DataStreamExtensions<D> on DataStream<D> {
  /// Transforms each element of this data stream into a new stream event.
  ///
  /// In addition to the stream events, the [DataStream.value] of source data stream is also mapped
  /// by applying the `convert` function.
  DataStream<P> mapWithValue<P>(P Function(D data) convert) {
    assert(convert != null);
    final subject = BehaviorSubject<P>.seeded(convert(this.value));
    subject.addStream(this.map(convert)).then<void>((dynamic _) => subject.close());
    return DataSubject(subject);
  }
}
