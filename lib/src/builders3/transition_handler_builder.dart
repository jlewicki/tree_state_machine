import 'dart:async';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import './handlers/transitions/transition_handler_descriptor.dart';
import './handlers/transitions/update_data_descriptor.dart';
import './handlers/transitions/when_result_descriptor.dart';
import './handlers/transitions/when_descriptor.dart';
import './handlers/transitions/run_descriptor.dart';
import './handlers/transitions/post_descriptor.dart';
import './handlers/transitions/schedule_descriptor.dart';

class TransitionHandlerBuilder<D, C> {
  final StateKey _forState;
  final Logger _log;
  final FutureOr<C> Function(TransitionContext) _makeContext;
  TransitionHandlerDescriptor<C>? descriptor;

  TransitionHandlerBuilder(
    this._forState,
    this._log,
    this._makeContext,
  );

  /// Runs [handler] when the transition occurs.
  ///
  /// ```dart
  /// void handleEnter(TransactionContext ctx) => print('State entered');
  /// void handleExit(TransactionContext ctx) => print('State exited');
  ///
  /// var state1 = StateKey('s1');
  /// var builder = StateTreeBuilder(initialState: state1);
  ///
  /// builder.state(state1, (b) {
  ///   // Run a function when the state is entered
  ///   b.onEnter((b) => b.run(handleEnter));
  ///
  ///   // Run a function when the state is exited
  ///   b.onExit((b) => b.run(handleExit));
  /// });
  /// ```
  /// The handler can be labeled when formatting a state tree by providing a [label].
  void run(
    FutureOr<void> Function(TransitionHandlerContext<D, C> ctx) handler, {
    String? label,
  }) {
    descriptor = makeRunDescriptor<D, C>(handler, _makeContext, _log, label);
  }

  /// Posts a message to be processed by the state machine when a transition occurs.
  ///
  /// If [getMessage] is provided, the function will be evaluated when the transition occurs, and
  /// the returned message will be posted. Otherwise a [message] must be provided.
  /// ```dart
  /// var state1 = StateKey('s1');
  /// var builder = StateTreeBuilder(initialState: state1);
  ///
  /// builder.state(state1, (b) {
  ///   // Post a MyMessage message when this state is entered.
  ///   b.onEnter((b) => b.post(getMessage: (transCtx) => MyMessage()));
  /// });
  /// ```
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  void post<M>({
    FutureOr<M> Function(TransitionHandlerContext<D, C> ctx)? getMessage,
    M? message,
    String? label,
  }) {
    if (getMessage == null && message == null) {
      throw ArgumentError('getMessage or message must be provided');
    } else if (getMessage != null && message != null) {
      throw ArgumentError('One of getMessage or message must be provided');
    }
    var _getMessage = getMessage ?? (_) => message!;
    descriptor = makePostDescriptor<D, C, M>(
      _getMessage,
      _makeContext,
      _log,
      label,
    );
  }

  /// Schedules a message to be processed by the state machine when a transition occurs.
  ///
  /// If [getMessage] is provided, the function will be evaluated when the scheduling occurs, and
  /// the returned message will be posted. Otherwise a [message] must be provided.
  ///
  /// The scheduling will be performed using [TransitionContext.schedule]. Refer to that method
  /// for further details of scheduling semantics.
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  void schedule<M>({
    M Function(TransitionHandlerContext<D, C> ctx)? getMessage,
    M? message,
    Duration duration = const Duration(),
    bool periodic = false,
    String? label,
  }) {
    if (getMessage == null && message == null) {
      throw ArgumentError('getMessage or message must be provided');
    } else if (getMessage != null && message != null) {
      throw ArgumentError('One of getMessage or message must be provided');
    }
    var _getMessage = getMessage ?? (_) => message!;
    descriptor = makeScheduleDescriptor<D, C, M>(
      _getMessage,
      duration,
      periodic,
      _makeContext,
      _log,
      label,
    );
  }

  void updateOwnData(
    D Function(TransitionHandlerContext<D, C> ctx) update, {
    StateKey? stateToUpdate,
    String? label,
  }) {
    descriptor = makeUpdateDataDescriptor(update, _makeContext, _forState, _log, label);
  }

  /// Updates state data of type [D] when the transition occurs.
  ///
  /// ```dart
  /// class MyStateData {
  ///   int value;
  /// }
  ///
  /// var state1 = StateKey('s1');
  /// var state2 = StateKey('s2');
  /// var builder = StateTreeBuilder(initialState: state1);
  ///
  /// builder.dataState<MyStateData>(
  ///   state1,
  ///   InitialData(() => MyStateData()),
  ///   emptyDataState,
  ///   initialChild: InitialChild(state2)
  /// });
  ///
  /// builder.state(state2, (b) {
  ///   // Update state data in ancestor state
  ///   b.onEnter((b) => b.updateData<MyStateData>((_, data) => data..value += 1)));
  /// }, parent: state1);
  /// ```
  ///
  /// If more than one ancestor data state share the same state data type of [D], [forState] can be
  /// provided to specify which state data should be updated.
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  void updateData<D2>(
    D2 Function(TransitionHandlerContext<D2, C> ctx) update, {
    StateKey? stateToUpdate,
    String? label,
  }) {
    descriptor = makeUpdateDataDescriptor(update, _makeContext, _forState, _log, label);
  }

  TransitionHandlerWhenBuilder<D, C> when(
    FutureOr<bool> Function(TransitionHandlerContext<D, C> ctx) condition,
    void Function(TransitionHandlerBuilder<D, C> builder) buildTrueHandler, {
    String? label,
  }) {
    var conditions = <TransitionConditionDescriptor<C>>[];
    var whenBuilder = TransitionHandlerWhenBuilder<D, C>._(
      conditions,
      () => TransitionHandlerBuilder<D, C>(_forState, _log, _makeContext),
    );

    whenBuilder.when(condition, buildTrueHandler, label: label);
    descriptor = makeWhenDescriptor(conditions, _makeContext, _log, label);
    return whenBuilder;
  }

  TransitionHandlerWhenBuilder<D, C2> whenWith<C2>(
    FutureOr<C2> Function(TransitionHandlerContext<D, C> ctx) context,
    FutureOr<bool> Function(TransitionHandlerContext<D, C2> ctx) condition,
    void Function(TransitionHandlerBuilder<D, C2> builder) buildTrueHandler, {
    String? label,
  }) {
    var contextRef = Ref<C2?>(null);
    var conditions = <TransitionConditionDescriptor<C2>>[];
    var whenBuilder = TransitionHandlerWhenBuilder<D, C2>._(
      conditions,
      () => TransitionHandlerBuilder<D, C2>(_forState, _log, (_) => contextRef.value!),
    );

    whenBuilder.when(condition, buildTrueHandler, label: label);
    descriptor = makeWhenWithContextDescriptor<D, C, C2>(
      context,
      conditions,
      _makeContext,
      _log,
      label,
    );
    return whenBuilder;
  }

  TransitionHandlerWhenResultBuilder<D> whenResult<T>(
    FutureOr<Result<T>> Function(TransitionHandlerContext<D, C> ctx) result,
    void Function(TransitionHandlerBuilder<D, T> builder) buildSuccessHandler, {
    String? label,
  }) {
    var resultRef = Ref<Result<T>?>(null);
    var successBuilder = TransitionHandlerBuilder<D, T>(
        _forState,
        _log,
        // This will only be called when the result is succesful, so this crazy property path will be
        // valid.
        (_) => resultRef.value!.asValue!.value);
    var failureBuilder = TransitionHandlerBuilder<D, AsyncError>(_forState, _log, (_) {
      var err = resultRef.value!.asError!;
      return AsyncError(err.error, err.stackTrace);
    });

    buildSuccessHandler(successBuilder);
    var successDesr = successBuilder.descriptor;

    var failureDescrRef = Ref<TransitionHandlerDescriptor<AsyncError>?>(null);
    descriptor = makeWhenResultDescriptor<C, D, T>(
      _forState,
      result,
      _makeContext,
      resultRef,
      successDesr!, // TODO check for null
      failureDescrRef,
      _log,
      label,
    );
    return TransitionHandlerWhenResultBuilder<D>(() => failureBuilder, failureDescrRef);
  }
}

class TransitionHandlerWhenResultBuilder<D> {
  final Ref<TransitionHandlerDescriptor<AsyncError>?> _failureDescrRef;
  final TransitionHandlerBuilder<D, AsyncError> Function() _makeErrorBuilder;

  TransitionHandlerWhenResultBuilder(this._makeErrorBuilder, this._failureDescrRef);

  void otherwise(
    void Function(TransitionHandlerBuilder<D, AsyncError> builder) buildErrorHandler, {
    String? label,
  }) {
    var errorBuilder = _makeErrorBuilder();
    buildErrorHandler(errorBuilder);
    _failureDescrRef.value = errorBuilder.descriptor;
  }
}

class TransitionHandlerWhenBuilder<D, C> {
  final List<TransitionConditionDescriptor<C>> _conditions;
  final TransitionHandlerBuilder<D, C> Function() _makeBuilder;
  TransitionHandlerWhenBuilder._(this._conditions, this._makeBuilder);

  TransitionHandlerWhenBuilder<D, C> when(
    FutureOr<bool> Function(TransitionHandlerContext<D, C> ctx) condition,
    void Function(TransitionHandlerBuilder<D, C> builder) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = _makeBuilder();
    buildTrueHandler(trueBuilder);

    var whenTrueDescr = trueBuilder.descriptor;
    if (whenTrueDescr != null) {
      var conditionInfo = TransitionConditionInfo(label, whenTrueDescr.info);
      _conditions.add(
        TransitionConditionDescriptor.withData<D, C>(
          conditionInfo,
          condition,
          whenTrueDescr,
        ),
      );
    }
    return this;
  }

  void otherwise(
    void Function(TransitionHandlerBuilder<D, C> builder) buildOtherwise, {
    String? label,
  }) {
    var otherwiseBuilder = _makeBuilder();
    buildOtherwise(otherwiseBuilder);

    var otherwiseDescr = otherwiseBuilder.descriptor;
    if (otherwiseDescr != null) {
      var conditionInfo = TransitionConditionInfo(label, otherwiseDescr.info);
      _conditions.add(
        TransitionConditionDescriptor<C>(
          conditionInfo,
          (_) => (_) => true,
          otherwiseDescr,
        ),
      );
    }
  }
}
