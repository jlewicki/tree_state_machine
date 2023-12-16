import 'dart:async';

import 'package:tree_state_machine/async.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

/// Provides access to a data value of type [T] associated with a data state.
///
/// The [value] property can be used to read the current value, and [update] can be used to update
/// the value. Additionally, the [listen] method can be used to receive notifications as the value
/// changes over time.
///
/// The [DataValue] for a data state is created each time the state is entered. If the data state is
/// reentered in the future, the state does not 'remember' its earlier data value.
///
/// A [DataValue] is typically used when processing a message or during a state transition.
/// [MessageContext] or [TransitionContext] can be used to obtain the data value for an active
/// state.
///
/// ```dart
/// class MyData {
///   int counter;
/// }
///
/// class Increment { }
///
/// var state1 = StateKey('state1');
/// var treeBuilder = StateTreeBuilder(initialChild: state1);
///
/// treeBuilder.dataState<MyData>(state1, (b) {
///   b.runOnMessage((MessageContext msgCtx) {
///     if (msgCtx.message is Increment) {
///       // Get data value of type MyData from the message context
///       var dataVal = msgCtx.data<MyData>();
///       // Update the current state data value
///       dataVal!.update((cur) => cur..counter += 1);
///       return msgCtx.stay();
///     }
///     return msgCtx.unhandled();
///   });
/// });
/// ```
///
/// [DataValue] is typically created implicitly when constructing a state tree. Application code
/// will usually not need to create a [DataValue] directly.
class DataValue<T> extends StreamView<T> implements ValueStream<T> {
  ValueSubject<T> _subject;

  DataValue._(this._subject) : super(_subject);

  /// Constructs a [DataValue] with the [initialValue]
  factory DataValue(T initialValue) {
    var subject = ValueSubject.initialValue(initialValue);
    return DataValue._(subject);
  }

  /// Constructs a [DataValue] with an [initialValue] function that is evaluated the first time
  /// [value] is accessed.
  factory DataValue.lazy(T Function() initialValue) {
    var subject = ValueSubject.lazy(initialValue);
    return DataValue._(subject);
  }

  /// The type of the state data [T].
  Type get dataType => T;

  @override
  bool get hasValue => _subject.hasValue;

  @override
  T get value => _subject.value;

  @override
  bool get hasError => _subject.hasError;

  @override
  AsyncError get error => _subject.error;

  /// Calls the [update] function with the current data value, and updates the current value with
  /// the returned value.
  ///
  /// This will result in a new value being published to any listeners of this stream, even if the
  /// update function returns the some object instance it as passed.
  void update(T Function(T current) update) {
    try {
      var newValue = update(_subject.value);
      _subject.add(newValue);
    } on StateError catch (_) {
      throw StateError(
          'Cannot update value after DataValue is done. Has the state for this data value exited?');
    }
  }
}

class ClosableDataValue<T> extends DataValue<T> {
  ClosableDataValue._(super.subject) : super._();
  factory ClosableDataValue(T initialValue) {
    var subject = ValueSubject.initialValue(initialValue);
    return ClosableDataValue._(subject);
  }

  factory ClosableDataValue.lazy(T Function() initialValue) {
    var subject = ValueSubject.lazy(initialValue);
    return ClosableDataValue._(subject);
  }

  void close() {
    _subject.close();
  }

  void setValue(Object value) {
    if (value is! T) {
      throw ArgumentError(
          'Value of type ${value.runtimeType} is not of expected type $T');
    }
    _subject.add(value as T);
  }
}

class VoidDataValue extends ClosableDataValue<void> {
  VoidDataValue() : super._(ValueSubject<void>.initialValue(null));

  /// Calling this method has no effect, since a void value cannot be updated.
  @override
  void update(void Function(void current) update) {
    // This is a deliberate no-op, since a void value cannot be updated.
  }

  @override
  void setValue(Object value) {
    // This is a deliberate no-op, since a void value cannot be updated.
  }
}
