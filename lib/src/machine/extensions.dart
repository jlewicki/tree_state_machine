import 'package:tree_state_machine/async.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

/// Utility extensions on [TransitionContext].
extension TransitionContextExtensions on TransitionContext {
  DataValue<D> dataOrThrow<D>([DataStateKey<D>? key]) {
    var data = this.data<D>(key);
    if (data == null) {
      throw StateError('Unable to find data of type ${TypeLiteral<D>().type}');
    }
    return data;
  }

  D dataValueOrThrow<D>([DataStateKey<D>? key]) {
    var data = this.data<D>(key);
    if (data == null) {
      return isTypeOf<Object, void>()
          ? data as D
          : throw StateError(
              'Unable to find data value of type ${TypeLiteral<D>().type}');
    }
    return data.value;
  }

  P payloadOrThrow<P>() {
    var payload = this.payload;
    if (payload != null) {
      return payload is P
          ? payload as P
          : throw StateError('Unexpected payload type.');
    }
    throw StateError('The transition context does not have a payload.');
  }

  D updateOrThrow<D>(D Function(D current) update, {StateKey? key}) {
    var data = dataOrThrow<D>();
    data.update(update);
    return data.value;
  }
}

/// Utility extensions on [MessageContext].
extension MessageContextExtensions on MessageContext {
  DataValue<D> dataOrThrow<D>([DataStateKey<D>? key]) {
    var dataVal = data<D>(key);
    if (dataVal == null) {
      throw StateError(
          'Unable to find data value of type ${TypeLiteral<D>().type} in active data states');
    }
    return dataVal;
  }

  D dataValueOrThrow<D>([DataStateKey<D>? key]) {
    var dataVal = data<D>(key);
    if (dataVal == null) {
      return isTypeOf<Object, void>()
          ? data as D
          : throw StateError(
              'Unable to find data value of type ${TypeLiteral<D>().type}');
    }
    return dataVal.value;
  }

  M messageAsOrThrow<M>() {
    if (message is M) {
      return message as M;
    }
    throw StateError(
        'Message of type ${message.runtimeType} is not of expected type ${TypeLiteral<M>().type}');
  }

  D updateOrThrow<D>(D Function(D current) update, {DataStateKey<D>? key}) {
    var data = dataOrThrow<D>(key);
    data.update(update);
    return data.value;
  }
}

/// Utility extensions on `ValueStream<LifecycleState>`.
extension LifecycleStreamExtensions on ValueStream<LifecycleState> {
  /// Indicates if the current value is [LifecycleState.constructed].
  bool get isConstructed => value == LifecycleState.constructed;

  /// Indicates if the current value is [LifecycleState.starting].
  bool get isStarting => value == LifecycleState.starting;

  /// Indicates if the current value is [LifecycleState.started].
  bool get isStarted => value == LifecycleState.started;

  /// Indicates if the current value is [LifecycleState.stopping].
  bool get isStopping => value == LifecycleState.stopping;

  /// Indicates if the current value is [LifecycleState.stopped].
  bool get isStopped => value == LifecycleState.stopped;

  /// Indicates if the current value is [LifecycleState.disposed].
  bool get isDisposed => value == LifecycleState.disposed;
}
