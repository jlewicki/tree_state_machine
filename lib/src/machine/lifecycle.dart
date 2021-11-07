import 'package:async/async.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

/// Defines the lifecycle of a [TreeStateMachine].
///
/// It's the state machine for the state machine.
class Lifecycle {
  _LifecycleState status = _Constructed();

  bool get isConstructed => status is _Constructed;
  bool get isDisposed => status is _Disposed;
  bool get isStarted => status is _Started;
  bool get isStarting => status is _Starting;
  bool get isStopped => status is _Stopped;
  bool get isStopping => status is _Stopping;

  /// Starts the lifecycle, moving it to the Starting state.
  ///
  /// When the returned future completes, the lifecycle will be in the Started state.
  Future start(Future<Object> Function() doStart) {
    final transition = status.start(() async {
      final val = await doStart();
      return status = _Started(val);
    });
    status = transition.state;
    return transition.nextState;
  }

  /// Stops the lifecycle, moving it to the Stopping state.
  ///
  /// When the returned future completes, the lifecycle will be in the Stopped state.
  Future stop(Future<Object> Function() doStop) {
    final transition = status.stop(() async {
      final val = await doStop();
      return status = _Stopped(val);
    });
    status = transition.state;
    return transition.nextState;
  }

  /// Disposes the lifecycle, moving it to the Disposed state.
  ///
  /// This is irrevocable, and the liefecycle is permanently disposed.
  void dispose(void Function() doDispose) {
    status = status.dispose(doDispose);
  }

  /// Throws [DisposedError] if this lifecycle has been disposed.
  void throwIfDisposed([String? message]) {
    if (isDisposed) {
      throw DisposedError(message ?? 'This object has been disposed');
    }
  }
}

/// Base class for states representing [TreeStateMachine] lifecycle.
abstract class _LifecycleState {
  _Disposed dispose(void Function() onDispose);

  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      throw StateError('Unable to start from lifecycle state $runtimeType');

  LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) =>
      throw StateError('Unable to start from lifecycle state $runtimeType');
}

/// An asynchronous transition between lifecycle states.
class LifecycleTransition<T extends _LifecycleState> {
  final _LifecycleState state;
  final Future<T> nextState;
  LifecycleTransition(this.state, this.nextState);
}

class _Constructed extends _LifecycleState {
  @override
  _Disposed dispose(void Function() onDispose) {
    onDispose();
    return _Disposed();
  }

  @override
  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) {
    final starting = _Starting(doStart());
    return LifecycleTransition(starting, starting.future);
  }
}

class _Disposed extends _LifecycleState {
  @override
  _Disposed dispose(void Function() onDispose) => this;
  @override
  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) => throw DisposedError();
  @override
  LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) => throw DisposedError();
}

class _Started extends _LifecycleState {
  final Object value;
  _Started(this.value);

  @override
  _Disposed dispose(void Function() onDispose) {
    onDispose();
    return _Disposed();
  }

  @override
  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      LifecycleTransition(this, Future.value(this));

  @override
  LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) {
    final stopping = _Stopping(doStop());
    return LifecycleTransition(stopping, stopping.future);
  }
}

class _Starting extends _LifecycleState {
  final CancelableOperation<_Started> _operation;
  _Starting(Future<_Started> future) : _operation = CancelableOperation.fromFuture(future);
  Future<_Started> get future => _operation.value;

  @override
  _Disposed dispose(void Function() onDispose) {
    _operation.cancel();
    onDispose();
    return _Disposed();
  }

  @override
  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      LifecycleTransition(this, future);

  @override
  LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) => LifecycleTransition(
        this,
        future.then((started) => started.stop(doStop).nextState),
      );
}

class _Stopped extends _LifecycleState {
  final Object value;
  _Stopped(this.value);

  @override
  _Disposed dispose(void Function() onDispose) {
    onDispose();
    return _Disposed();
  }

  @override
  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      _Constructed().start(doStart);
  @override
  LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) =>
      LifecycleTransition(this, Future.value(this));
}

class _Stopping extends _LifecycleState {
  final CancelableOperation<_Stopped> _operation;
  _Stopping(Future<_Stopped> future) : _operation = CancelableOperation.fromFuture(future);

  Future<_Stopped> get future => _operation.value;

  @override
  _Disposed dispose(void Function() onDispose) {
    _operation.cancel();
    onDispose();
    return _Disposed();
  }

  @override
  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) => LifecycleTransition(
        this,
        future.then((_) => _Constructed().start(doStart).nextState),
      );

  @override
  LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) =>
      LifecycleTransition(this, future);
}
