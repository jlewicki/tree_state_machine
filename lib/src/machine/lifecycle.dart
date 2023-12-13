import 'dart:async';

import 'package:async/async.dart';
import 'package:tree_state_machine/async.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

/// Enumerates the lifecycle of a [TreeStateMachine].
enum LifecycleState {
  /// The state machine has been created, but not started.
  constructed,

  /// [TreeStateMachine.start] has been called, but the returned future has not yet completed.
  starting,

  /// [TreeStateMachine.start] has been called, and the returned future has completed.
  started,

  /// [TreeStateMachine.stop] has been called, and the returned future has not yet completed.
  stopping,

  /// [TreeStateMachine.stop] has been called, and the returned future has completed.
  stopped,

  /// [TreeStateMachine.dispose] has been called. The state machine will never leave this state.
  disposed,
}

/// Defines the lifecycle of a [TreeStateMachine].
///
/// It's the state machine for the state machine.
class Lifecycle {
  // This is sync stream so that [states] will map the latest value as soon as it arrives on this
  // subject.
  final _stateSubject = ValueSubject<_LifecycleState>.initialValue(_Constructed(), sync: true);

  /// A broadcast [ValueStream] of the state changes of this lifecycle.
  late final ValueStream<LifecycleState> states = _stateSubject.mapValueStream((s) => s.status);

  /// The current state of this lifecycle.
  LifecycleState get state => _stateSubject.value.status;

  /// Starts the lifecycle, moving it to the Starting state.
  ///
  /// When the returned future completes, the lifecycle will be in the Started state.
  Future<void> start(Future<Object> Function() doStart) {
    final transition = _stateSubject.value.start(() async {
      var val = await doStart();
      var next = _Started(val);
      _stateSubject.add(next);
      return next;
    });
    if (_stateSubject.value != transition.state) _stateSubject.add(transition.state);
    return transition.nextState;
  }

  /// Stops the lifecycle, moving it to the Stopping state.
  ///
  /// When the returned future completes, the lifecycle will be in the Stopped state.
  Future<void> stop(Future<Object> Function() doStop) {
    final transition = _stateSubject.value.stop(() async {
      var val = await doStop();
      var next = _Stopped(val);
      _stateSubject.add(next);
      return next;
    });
    if (_stateSubject.value != transition.state) _stateSubject.add(transition.state);
    return transition.nextState;
  }

  /// Disposes the lifecycle, moving it to the Disposed state.
  ///
  /// This is irrevocable, and the lifeecycle is permanently disposed.
  void dispose(void Function() doDispose) {
    var next = _stateSubject.value.dispose(doDispose);
    if (next != _stateSubject.value) {
      _stateSubject.add(next);
      // Close the subject so Done notifications will be sent to listeners.  We have to do this
      // in a microtask, otherwise close() will interfere with the add() in the previous line.
      scheduleMicrotask(_stateSubject.close);
    }
  }

  /// Throws [DisposedError] if this lifecycle has been disposed.
  void throwIfDisposed([String? message]) {
    if (state == LifecycleState.disposed) {
      throw DisposedError(message ?? 'This object has been disposed');
    }
  }
}

/// Base class for states representing [TreeStateMachine] lifecycle.
abstract class _LifecycleState {
  _Disposed dispose(void Function() onDispose);
  LifecycleState get status;

  _LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      throw StateError('Unable to start from lifecycle state $runtimeType');

  _LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) =>
      throw StateError('Unable to start from lifecycle state $runtimeType');
}

/// An asynchronous transition between lifecycle states.
class _LifecycleTransition<T extends _LifecycleState> {
  final _LifecycleState state;
  final Future<T> nextState;
  _LifecycleTransition(this.state, this.nextState);
}

class _Constructed extends _LifecycleState {
  @override
  LifecycleState get status => LifecycleState.constructed;

  @override
  _Disposed dispose(void Function() onDispose) {
    onDispose();
    return _Disposed();
  }

  @override
  _LifecycleTransition<_Started> start(Future<_Started> Function() doStart) {
    final starting = _Starting(doStart());
    return _LifecycleTransition(starting, starting.future);
  }
}

class _Disposed extends _LifecycleState {
  @override
  LifecycleState get status => LifecycleState.disposed;
  @override
  _Disposed dispose(void Function() onDispose) => this;
  @override
  _LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      throw DisposedError();
  @override
  _LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) => throw DisposedError();
}

class _Started extends _LifecycleState {
  final Object value;
  @override
  LifecycleState get status => LifecycleState.started;

  _Started(this.value);

  @override
  _Disposed dispose(void Function() onDispose) {
    onDispose();
    return _Disposed();
  }

  @override
  _LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      _LifecycleTransition(this, Future.value(this));

  @override
  _LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) {
    final stopping = _Stopping(doStop());
    return _LifecycleTransition(stopping, stopping.future);
  }
}

class _Starting extends _LifecycleState {
  final CancelableOperation<_Started> _operation;
  _Starting(Future<_Started> future) : _operation = CancelableOperation.fromFuture(future);
  Future<_Started> get future => _operation.value;

  @override
  LifecycleState get status => LifecycleState.starting;

  @override
  _Disposed dispose(void Function() onDispose) {
    _operation.cancel();
    onDispose();
    return _Disposed();
  }

  @override
  _LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      _LifecycleTransition(this, future);

  @override
  _LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) => _LifecycleTransition(
        this,
        future.then((started) => started.stop(doStop).nextState),
      );
}

class _Stopped extends _LifecycleState {
  final Object value;
  _Stopped(this.value);

  @override
  LifecycleState get status => LifecycleState.stopped;

  @override
  _Disposed dispose(void Function() onDispose) {
    onDispose();
    return _Disposed();
  }

  @override
  _LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      _Constructed().start(doStart);
  @override
  _LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) =>
      _LifecycleTransition(this, Future.value(this));
}

class _Stopping extends _LifecycleState {
  final CancelableOperation<_Stopped> _operation;
  _Stopping(Future<_Stopped> future) : _operation = CancelableOperation.fromFuture(future);

  Future<_Stopped> get future => _operation.value;

  @override
  LifecycleState get status => LifecycleState.stopping;

  @override
  _Disposed dispose(void Function() onDispose) {
    _operation.cancel();
    onDispose();
    return _Disposed();
  }

  @override
  _LifecycleTransition<_Started> start(Future<_Started> Function() doStart) => _LifecycleTransition(
        this,
        future.then((_) => _Constructed().start(doStart).nextState),
      );

  @override
  _LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) =>
      _LifecycleTransition(this, future);
}
