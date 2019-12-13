import 'dart:async';

import 'package:async/async.dart';

enum LifecycleStates { constructed, starting, started, stopping, stopped, disposed }

class LifecycleTransition<T extends _LifecycleState> {
  final _LifecycleState status;
  final Future<T> nextStatus;
  LifecycleTransition(this.status, this.nextStatus);
}

abstract class _LifecycleState {
  final LifecycleStates state;
  _LifecycleState(this.state);

  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      throw StateError('Unable to start from lifecycle state $state');

  LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) =>
      throw StateError('Unable to start from lifecycle state $state');

  _Disposed dispose(void Function() onDispose);
}

// abstract class _LifecycleState2 {
//   final LifecycleStates state;
//   final LifecycleTransition<_Started> Function(Future<_Started> Function() doStart) _start;
//   final LifecycleTransition<_Stopped> Function(Future<_Stopped> Function() doStop) _stop;
//   final _Disposed Function(void Function() onDispose) _dispose;

//   _LifecycleState2(this.state, this._start, this._stop, this._dispose);

//   LifecycleTransition<_Started> start(Future<_Started> Function() doStart) => _start(doStart);

//   LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) => _stop(doStop);

//   _Disposed dispose(void Function() onDispose) => _dispose(onDispose);

//   factory _LifecycleState2.constructed() {
//     return _LifecycleState2(
//       LifecycleStates.constructed,
//       (doStart) {
//         final starting = _Starting(doStart());
//         return LifecycleTransition(starting, starting.future);
//   }

//    factory _LifecycleState2.starting() {

// }

class _Constructed extends _LifecycleState {
  _Constructed() : super(LifecycleStates.constructed);

  @override
  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) {
    final starting = _Starting(doStart());
    return LifecycleTransition(starting, starting.future);
  }

  _Disposed dispose(void Function() onDispose) => _Disposed();
}

class _Starting extends _LifecycleState {
  final CancelableOperation<_Started> _operation;
  _Starting(Future<_Started> future)
      : _operation = CancelableOperation.fromFuture(future),
        super(LifecycleStates.starting);
  Future<_Started> get future => _operation.value;

  @override
  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      LifecycleTransition(this, this.future);

  LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) => LifecycleTransition(
        this,
        this.future.then((started) => started.stop(doStop).nextStatus),
      );

  _Disposed dispose(void Function() onDispose) {
    _operation.cancel();
    onDispose();
    return _Disposed();
  }
}

class _Started extends _LifecycleState {
  final Object value;
  _Started(this.value) : super(LifecycleStates.started);

  @override
  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      LifecycleTransition(this, Future.value(this));

  @override
  LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) {
    final stopping = _Stopping(doStop());
    return LifecycleTransition(stopping, stopping.future);
  }

  _Disposed dispose(void Function() onDispose) {
    onDispose();
    return _Disposed();
  }
}

class _Stopping extends _LifecycleState {
  final CancelableOperation<_Stopped> _operation;

  _Stopping(Future<_Stopped> future)
      : _operation = CancelableOperation.fromFuture(future),
        super(LifecycleStates.stopping);

  Future<_Stopped> get future => _operation.value;

  @override
  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      LifecycleTransition(this, this.future.then((_) => _Constructed().start(doStart).nextStatus));

  @override
  LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) =>
      LifecycleTransition(this, this.future);

  _Disposed dispose(void Function() onDispose) {
    _operation.cancel();
    onDispose();
    return _Disposed();
  }
}

class _Stopped extends _LifecycleState {
  final Object value;
  _Stopped(this.value) : super(LifecycleStates.stopped);

  @override
  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) =>
      _Constructed().start(doStart);

  @override
  LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) =>
      LifecycleTransition(this, Future.value(this));

  _Disposed dispose(void Function() onDispose) => _Disposed();
}

class _Disposed extends _LifecycleState {
  _Disposed() : super(LifecycleStates.disposed);

  @override
  LifecycleTransition<_Started> start(Future<_Started> Function() doStart) => throw DisposedError();

  @override
  LifecycleTransition<_Stopped> stop(Future<_Stopped> Function() doStop) => throw DisposedError();

  _Disposed dispose(void Function() onDispose) => this;
}

class DisposedError extends StateError {
  DisposedError() : super('This object has been disposed');
}

class Lifecycle {
  final void Function() _doDispose;

  Lifecycle(this._doDispose);

  bool get isConstructed => status.state == LifecycleStates.constructed;
  bool get isStarting => status.state == LifecycleStates.starting;
  bool get isStarted => status.state == LifecycleStates.started;
  bool get isStopping => status.state == LifecycleStates.stopping;
  bool get isStopped => status.state == LifecycleStates.stopped;
  bool get isDisposed => status.state == LifecycleStates.disposed;

  _LifecycleState status = _Constructed();

  Future start(Future<Object> Function() doStart) {
    final transition = status.start(() async {
      final val = await doStart();
      return status = _Started(val);
    });
    status = transition.status;
    return transition.nextStatus;
  }

  Future stop(Future<Object> Function() doStop) {
    final transition = status.stop(() async {
      final val = await doStop();
      return status = _Stopped(val);
    });
    status = transition.status;
    return transition.nextStatus;
  }

  void dispose() {
    status = status.dispose(_doDispose);
  }
}
