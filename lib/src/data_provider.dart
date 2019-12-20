import 'dart:async';

import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'errors.dart';
import 'utility.dart';

/// A [Stream] that provides synchronous access to the last emitted item.
///
/// Note that this is identical to the `ValueStream` interface from RxDart. It is duplicated here
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

  OwnedDataProvider(D Function() eval, this.encoder, this.decoder) {
    _lazySubject = Lazy(() => DataSubject(BehaviorSubject<D>.seeded(eval())));
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
}

/// A data provider that provides a view of the data value of the current leaf state of the state
/// machine.
///
/// [CurrentLeafDataProvider] is a somewhat specialized implementation of [DataProvider] geared
/// towards a specific use-case. In general, if a leaf state and one or more of its ancestor states
/// are [DataTreeState]s, then when that leaf is the current state, the total set of data
/// comprising the active data values are distributed across several states and data providers.
/// This means that in order to obtain a complete picture the the current state data, an
/// application must make several calls to [CurrentState.dataStream], one for each active data
/// state.
///
/// Depending on the domain, it may be more convenient to maintain all data values for the active
/// states at the leaf. In other words, if the data type `D` for a current leaf state has a class
/// hierarchy that mirrors the state hierarchy, then a leaf data value of type `D` will give a
/// complete view of the the active state data.
///
/// [CurrentLeafDataProvider] facilitates this by providing a view of the current leaf data to an
/// the ancestor [DataTreeState]. It expects the the leaf data value is always a subclass of the
/// data type `D`, and a `StateError` is thrown from [data] and [dataStream] when that is not the
/// case.
@experimental
class CurrentLeafDataProvider<D> implements DataProvider<D>, ObservableData<D> {
  StreamSubscription _subscription;
  Lazy<DataSubject<D>> _lazySubject;
  bool _disposed = false;

  /// Called to initialize this provider with an [ObservableData] that provides access to the data
  /// of the current leaf state.
  ///
  /// This is called by during initialization of the state tree, and is not intended to be used by
  /// application code.
  @mustCallSuper
  void initializeLeafData(ObservableData<Object> observableLeafData) {
    ArgumentError.checkNotNull(observableLeafData, 'observableLeafData');
    _lazySubject = Lazy(() {
      // Seed with current value, which ensures that subscribers to the stream are sent the current
      // value (in a future microtask)
      var skippedFirstSame = false;
      var subject = BehaviorSubject.seeded(_leafDataAsD(observableLeafData.dataStream.value));
      // Note that we skip adding if it's the same value. Otherwise this subscription might
      // immediately receive (in a future microtask) the current leaf value (if the source is a
      // behavior subject). Since we seeded our subject with this value, we don't want to emit an
      // indentical value unnecessarily. We only do this once though, in case the source emits when
      // the current leaf value is mutated as opposed to producing a new instance.
      _subscription = observableLeafData.dataStream.map(_leafDataAsD).skipWhile((v) {
        if (skippedFirstSame) return false;
        if (identical(v, subject.value)) {
          skippedFirstSame = true;
          return true;
        }
        return false;
      }).listen(subject.add);
      return DataSubject(subject);
    });
  }

  @override
  DataStream<D> get dataStream {
    _throwIfDisposed();
    assert(_lazySubject != null, 'initializeLeafData has not been called.');
    return _lazySubject.value;
  }

  @override
  D get data => dataStream.value;

  @override
  Object encode() => null;

  @override
  void decodeInto(Object input) {}

  @override
  void update(void Function() update) {
    _throwIfDisposed();
    update();
    _lazySubject.value.wrappedSubject.add(data);
  }

  /// Throws [UnsupportedError] if called.
  ///
  /// Because this provider does not own the leaf data (which is likely a subtype of `D`), replacing
  /// with a new value is not allowed.
  @override
  @alwaysThrows
  void replace(D Function() replace) {
    throw UnsupportedError('Leaf data provider cannot replace a value');
  }

  @override
  void dispose() {
    _disposed = true;
    if (_lazySubject.hasValue) {
      _subscription?.cancel();
      _lazySubject.value.wrappedSubject.close();
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

/// Adapts a BehaviorSubject to the [DataStream] interface.
class DataSubject<T> extends StreamView<T> implements DataStream<T>, ValueStream<T> {
  final BehaviorSubject<T> _subject;
  DataSubject(this._subject) : super(_subject.stream);
  BehaviorSubject<T> get wrappedSubject => _subject;
  @override
  T get value => _subject.value;
  @override
  bool get hasValue => _subject.hasValue;
}

extension DataStreamExtensions<D> on DataStream<D> {
  /// Transforms each element of this data stream into a new stream event.
  ///
  /// In addition to the stream events, the [DataStream.value] of source data stream is also mapped
  /// by applying the `convert` function.
  DataStream<P> map<P>(P Function(D data) convert) {
    assert(convert != null);
    final subject = BehaviorSubject<P>.seeded(convert(this.value));
    subject.addStream(this.map(convert)).then((_) => subject.close());
    return DataSubject(subject);
  }
}
