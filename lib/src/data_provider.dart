import 'utility.dart';

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
}

class OwnedDataProvider<D> implements DataProvider<D> {
  final Object Function(D data) encoder;
  final D Function(Object encoded) decoder;
  final D Function() _eval;
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
  Object encode() => encoder(data);

  @override
  void decodeInto(Object input) {
    ArgumentError.checkNotNull('input');
    _data = decoder(input);
  }

  @override
  void replace(D Function() replace) {
    _data = replace();
  }

  @override
  void update(void Function() update) {
    replace(() {
      update();
      return data;
    });
  }
}

class CurrentLeafDataProvider<D> implements DataProvider<D> {
  D Function() _getCurrentLeafData;
  @override
  D get data {
    assert(_getCurrentLeafData != null, 'initializeLeafDataAccessor has not been called.');
    return _getCurrentLeafData();
  }

  @override
  Object encode() => null;
  @override
  void decodeInto(Object input) {}

  void initializeLeafDataAccessor(Object Function() getCurrentLeafData) {
    ArgumentError.checkNotNull(getCurrentLeafData, 'getCurrentLeafData');
    _getCurrentLeafData = () {
      final leafData = getCurrentLeafData();
      if (leafData is! D) {
        throw StateError(
            'Expected leaf data of type ${TypeLiteral<D>().type}, but received ${leafData?.runtimeType}');
      }
      return leafData as D;
    };
  }

  @override
  void update(void Function() update) {
    // Placeholder for possible future change notification
    update();
  }

  /// Throws [UnsupportedError] if called.
  ///
  /// Because this provider does not own the leaf data (which is likely a subtype of `D`), replacing
  /// with a new value is not allowed.
  @override
  void replace(D Function() replace) {
    throw UnsupportedError('Leaf data provider cannot replace a value');
  }
}
