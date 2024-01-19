import 'package:tree_state_machine/async.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

/// Utility extensions on [TransitionContext].
extension TransitionContextExtensions on TransitionContext {
  P payloadOrThrow<P>() {
    var payload = this.payload;
    if (payload != null) {
      return payload is P
          ? payload as P
          : throw StateError('Unexpected payload type.');
    }
    throw StateError('The transition context does not have a payload.');
  }
}

/// Utility extensions on [MessageContext].
extension MessageContextExtensions on MessageContext {
  M messageAsOrThrow<M>() {
    if (message is M) {
      return message as M;
    }
    throw StateError(
        'Message of type ${message.runtimeType} is not of expected type ${TypeLiteral<M>().type}');
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
