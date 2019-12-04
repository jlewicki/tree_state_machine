import 'dart:async';
import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import 'package:tree_state_machine/src/tree_state.dart';

////////////////////////////////////////////////////////////////////////////////////////////////////
///
/// Experimental
///
class StateData2<D extends StateData2<D>> {
  @JsonKey(ignore: true)
  final StreamController<D> _streamController = StreamController.broadcast();
  @JsonKey(ignore: true)
  Stream<D> get stream => _streamController.stream;
  void setData(void Function() callback) {
    callback();
    _streamController.add(this);
  }
}

abstract class DataTreeState2<D extends StateData2<D>> extends TreeState {
  D _data;
  D get data => _data ?? createData();
  D createData();
}

class StateData3<D> {
  @JsonKey(ignore: true)
  final StreamController<D> _streamController = StreamController.broadcast();
  @JsonKey(ignore: true)
  Stream<D> get stream => _streamController.stream;
  void setData(D Function() callback) {
    D val = callback();
    _streamController.add(val);
  }
}
///////////////////////////////////////////////////////////////////////////////////////////////////

abstract class DataProvider2<D> {
  D get data;
  Object encode();
  void decodeInto(Object input);
}

typedef CreateProvider2<D> = DataProvider2<D> Function(Object Function() currentLeafData);

CreateProvider2<D> ownedDataProvider<D>(
  D Function() eval,
  Map<String, dynamic> Function(D data) encode,
  D Function(Map<String, dynamic> json) decode,
) =>
    (_) => OwnedDataProvider2(eval, encode, decode);

CreateProvider2<D> leafDataProvider<D>() => (currentLeafData) => LeafDataProvider2(currentLeafData);

class OwnedDataProvider2<D> implements DataProvider2<D> {
  final Map<String, dynamic> Function(D data) _encode;
  final D Function(Map<String, dynamic> json) _decode;
  final D Function() _eval;
  D _data;
  OwnedDataProvider2(this._eval, this._encode, this._decode);

  D get data => _data ??= _eval();

  /// Encodes the [data] value using the [Codec] provided in the constructor.
  Object encode() => _encode(data);

  void decodeInto(Object input) {
    ArgumentError.checkNotNull('input');
    _data = _decode(input);
  }
}

class LeafDataProvider2<D> implements DataProvider2<D> {
  D Function() _currentLeafData;
  LeafDataProvider2(this._currentLeafData);
  D get data => _currentLeafData();
  Object encode() => null;
  void decodeInto(Object input) {}
}

abstract class DataTreeState3<D, P extends DataProvider2<D>> extends TreeState {
  final P provider;
  DataTreeState3(this.provider);
  D get data => provider.data;
}

// Move to utility
// class DelegatingCodec<S, T> extends Codec<S, T> {
//   final Converter<S, T> encoder;
//   final Converter<T, S> decoder;
//   DelegatingCodec(
//     T Function(S data) encode,
//     S Function(T encoded) decode,
//   )   : encoder = DelegatingConverter(encode),
//         decoder = DelegatingConverter(decode);
// }

// class DelegatingConverter<S, T> extends Converter<S, T> {
//   final T Function(S data) _encode;
//   DelegatingConverter(this._encode);
//   @override
//   T convert(S input) => _encode(input);
// }
