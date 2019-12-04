import 'dart:async';
import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/utility.dart';

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

abstract class DataTreeState3<D> extends TreeState {
  D _data;
  D get data => _data ?? createData();
  D createData();
}

class DataProvider2<D> {
  final Codec<D, Map<String, dynamic>> codec;
  final D Function() _eval;
  D _data;
  DataProvider2._(this._eval, this.codec);

  factory DataProvider2(
    D Function() eval,
    Map<String, dynamic> Function(D data) encode,
    D Function(Map<String, dynamic> json) decode,
  ) =>
      DataProvider2._(eval, DelegatingCodec(encode, decode));

  /// The data instance managed by this provider.
  ///
  /// The instance is created on demand using the `create` function provided in the constructor.
  D get data => _data ??= _eval();

  /// Encodes the [data] value using the [Codec] provided in the constructor.
  Object encode() => codec.encoder.convert(data);

  void decodeInto(Object input) {
    ArgumentError.checkNotNull('input');
    _data = codec.decoder.convert(input);
  }
}

// Move to utility
class DelegatingCodec<S, T> extends Codec<S, T> {
  final Converter<S, T> encoder;
  final Converter<T, S> decoder;
  DelegatingCodec(
    T Function(S data) encode,
    S Function(T encoded) decode,
  )   : encoder = DelegatingConverter(encode),
        decoder = DelegatingConverter(decode);
}

class DelegatingConverter<S, T> extends Converter<S, T> {
  final T Function(S data) _encode;
  DelegatingConverter(this._encode);
  @override
  T convert(S input) => _encode(input);
}
