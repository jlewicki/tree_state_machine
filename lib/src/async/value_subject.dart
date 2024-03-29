import 'dart:async';

import 'package:tree_state_machine/src/machine/utility.dart';

/// A [Subject] acts a both a [Stream], and a [StreamConsumer].
///
/// Note that [Subject] is conceptually similar to Subjects from other Rx.net oriented
/// libraries.
abstract class Subject<T>
    implements Stream<T>, EventSink<T>, StreamConsumer<T> {}

/// A [Stream] that provides synchronous access to the last emitted item or error.
abstract class ValueStream<T> implements Stream<T> {
  /// `True` if at least one event has been emitted.
  bool get hasValue;

  /// The last emitted value.
  ///
  /// A [StateError] is thrown if a value has not been emitted (that is, if [hasValue] returns
  /// false).
  T get value;

  /// `True` if an error has been emitted.
  bool get hasError;

  /// The last emitted error,
  ///
  /// A [StateError] is thrown if a error has not been emitted (that is, if [hasError] returns
  /// false).
  AsyncError get error;
}

/// A subject that provides synchronous access to the most recently added item. Additionally, if
/// a value has been added subscribers are notified immediately of that value on subscription (as
/// well as the events that are added in the future).
///
/// [ValueSubject] always behaves as a broadcast stream, and as such supports multiple subscribers.
///
/// Note that [ValueSubject] is conceptually identical to BehaviorSubject from other Rx.net oriented
/// libraries.
class ValueSubject<T> extends StreamView<T>
    implements Subject<T>, ValueStream<T> {
  ValueSubject._(this._controller, this._currentValue, this._sync)
      : super(_controller.stream);

  /// Contructs a new [ValueSubject].
  ///
  /// The subject has no value until [add] is called for the first time.
  factory ValueSubject({bool sync = false}) {
    var controller = StreamController<T>.broadcast(sync: sync);
    var currentValue = _CurrentValue<T>();
    return ValueSubject._(controller, currentValue, sync);
  }

  /// Constructs a new [ValueSubject] seeded with an initial value.
  ///
  /// After construction, [hasValue] will be `true` and [value] will return [initialValue].
  factory ValueSubject.initialValue(T initialValue, {bool sync = false}) {
    var controller = StreamController<T>.broadcast(sync: sync);
    var currentValue = _CurrentValue<T>();
    currentValue.setValue(initialValue);
    return ValueSubject._(controller, currentValue, sync);
  }

  /// Constructs a new [ValueSubject] with an initial value that is not generated until [value] is
  /// read.
  ///
  /// After construction, [hasValue] will be `true` and [value] will return the result of calling
  /// the [initialValue] function.
  ///
  /// Note that if [add] is called before [value] is read, then [initialValue] will never be called.
  factory ValueSubject.lazy(T Function() initialValue, {bool sync = false}) {
    var controller = StreamController<T>.broadcast(sync: sync);
    var currentValue = _CurrentValue<T>(_LazyValue<T>(initialValue));
    return ValueSubject._(controller, currentValue, sync);
  }

  final StreamController<T> _controller;
  final _CurrentValue<T> _currentValue;
  final bool _sync;

  @override
  AsyncError get error => _currentValue.error;

  @override
  bool get hasError => _currentValue.hasError;

  @override
  bool get hasValue => _currentValue.hasValue;

  @override
  T get value => _currentValue.value;

  @override
  bool get isBroadcast => _controller.stream.isBroadcast;

  @override
  void add(T event) {
    _currentValue.setValue(event);
    _controller.add(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _currentValue.setError(error, stackTrace);
    _controller.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<T> stream, {bool? cancelOnError}) {
    var setCurrentValueTransformer = StreamTransformer<T, T>.fromHandlers(
      handleData: (data, sink) {
        _currentValue.setValue(data);
        sink.add(data);
      },
      handleError: (error, stackTrace, sink) {
        _currentValue.setError(error, stackTrace);
        sink.addError(error, stackTrace);
      },
    );
    return _controller.addStream(
      stream.transform(setCurrentValueTransformer),
      cancelOnError: cancelOnError,
    );
  }

  @override
  StreamSubscription<T> listen(
    void Function(T value)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  /// Returns a [ValueStream] that converts each element of this stream to a new value using the
  /// [convert] function, and emits the result.
  ///
  /// For each data event, `o`, in this stream, the returned stream provides a data event with the
  /// value `convert(o)`. If [convert] throws, the returned stream reports it as an error event
  /// instead.
  ///
  /// Error and done events are passed through unchanged to the returned stream.
  ///
  /// If [hasValue] is true for this subject, the [ValueStream.value] of the returned stream will
  /// synchronously return the mapped value.
  ValueStream<R> mapValueStream<R>(R Function(T value) convert,
      {bool sync = false}) {
    var mappedSubject = ValueSubject<R>(sync: sync);
    _listen(
      (value) {
        try {
          mappedSubject.add(convert(value));
        } catch (e, st) {
          mappedSubject.addError(e, st);
        }
      },
      onError: (Object error, StackTrace? st) {
        mappedSubject.addError(error, st);
      },
      onDone: () {
        mappedSubject.close();
      },
      syncNotifyInitalValue: true,
    );
    return mappedSubject;
  }

  @override
  Future<void> close() => _controller.close();

  StreamSubscription<T> _listen(
    void Function(T value)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
    bool syncNotifyInitalValue = false,
  }) {
    var subscription = _controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    // We use IIFEs here so that we capture current values before notifying listeners (which will
    // happen in the future if we are an async subject).
    if (onData != null && _currentValue.hasValue) {
      _callOrSchedule((() {
        var val = _currentValue.value;
        return () => onData(val);
      })(), forceSync: syncNotifyInitalValue);
    } else if (onError != null && _currentValue.hasError) {
      _callOrSchedule((() {
        var error = _currentValue.error.error;
        var stackTrace = _currentValue.error.stackTrace;
        return () => onError(error, stackTrace);
      })(), forceSync: syncNotifyInitalValue);
    }
    return subscription;
  }

  void _callOrSchedule(void Function() action, {bool forceSync = false}) {
    if (forceSync || _sync) {
      action();
    } else {
      scheduleMicrotask(action);
    }
  }
}

/// Describes the most recent value or error emitted on a stream.
class _CurrentValue<T> {
  _CurrentValue([_ValueOrError<T>? initialValue]) : _current = initialValue;

  _ValueOrError<T>? _current;

  bool get hasValue => _current is _Value<T>;

  T get value => switch (_current) {
        _Value(value: var v) => v,
        _ => throw StateError('No value is available')
      };

  bool get hasError => _current is _Error<T>;

  AsyncError get error => switch (_current) {
        _Error(error: var e) => e,
        _ => throw StateError('No value is available')
      };

  void setValue(T value) {
    if (hasValue) {
      (_current as _Value<T>).value = value;
    } else {
      _current = _Value<T>(value);
    }
  }

  void setError(Object error, [StackTrace? stackTrace]) {
    if (hasError) {
      (_current as _Error<T>).error = AsyncError(error, stackTrace);
    } else {
      _current = _Error<T>(error, stackTrace);
    }
  }
}

sealed class _ValueOrError<T> {}

final class _Value<T> implements _ValueOrError<T> {
  T value;
  _Value(this.value);
}

final class _LazyValue<T> implements _Value<T> {
  final MutableLazy<T> _lazyValue;

  _LazyValue(T Function() evaluator) : _lazyValue = MutableLazy(evaluator);

  @override
  T get value => _lazyValue.value;
  @override
  set value(T value) {
    _lazyValue.value = value;
  }
}

final class _Error<T> implements _ValueOrError<T> {
  AsyncError error;
  _Error(Object error, StackTrace? stackTrace)
      : error = AsyncError(error, stackTrace);
}
