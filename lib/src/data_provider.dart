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
  final D Function() _eval;
  final StreamController<D> _controller = StreamController.broadcast();
  D _data;

  OwnedDataProvider(this._eval, this.encoder, this.decoder);

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
  D get data => _data ??= _eval();

  @override
  Stream<D> get stream => _controller.stream;

  @override
  Object encode() => encoder(data);

  @override
  void decodeInto(Object input) {
    ArgumentError.checkNotNull('input');
    _data = decoder(input);
  }

  @override
  void replace(D Function() replace) {
    _data = replace();
    _controller.add(_data);
  }

  @override
  void update(void Function() update) {
    replace(() {
      update();
      return data;
    });
  }

  @override
  void dispose() {
    _controller.close();
  }
}

/// A data provider that provides a view of a data instance that is owned by the current leaf state
/// of a state machine.
class CurrentLeafDataProvider<D> implements DataProvider<D>, ObservableData<D> {
  ObservableData<Object> _observableLeafData;
  StreamController<D> _controller = StreamController.broadcast();
  Stream<D> _stream;

  void initializeLeafData(ObservableData<Object> observableLeafData) {
    ArgumentError.checkNotNull(observableLeafData, 'observableLeafData');
    _observableLeafData = observableLeafData;
    _stream = _observableLeafData.stream.map(_leafDataAsD).mergeWith([_controller.stream]);
  }

  @override
  D get data {
    assert(_observableLeafData != null, 'initializeLeafData has not been called.');
    return _leafDataAsD(_observableLeafData.data);
  }

  @override
  Stream<D> get stream {
    assert(_stream != null, 'initializeLeafData has not been called.');
    return _stream;
  }

  @override
  Object encode() => null;

  @override
  void decodeInto(Object input) {}

  @override
  void update(void Function() update) {
    update();
    _controller.add(data);
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
    _controller.close();
  }

  D _leafDataAsD(Object leafData) {
    if (leafData is! D) {
      throw StateError(
          'Expected leaf data of type ${TypeLiteral<D>().type}, but received ${leafData?.runtimeType}');
    }
    return leafData as D;
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
