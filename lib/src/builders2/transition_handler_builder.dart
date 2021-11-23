import 'dart:async';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/builders2/handlers/transitions/post_descriptor.dart';
import 'package:tree_state_machine/src/builders2/handlers/transitions/run_descriptor.dart';
import 'package:tree_state_machine/src/builders2/handlers/transitions/schedule_descriptor.dart';
import 'package:tree_state_machine/src/builders2/handlers/transitions/transition_handler_descriptor.dart';
import 'package:tree_state_machine/src/builders2/handlers/transitions/update_data_descriptor.dart';
import 'package:tree_state_machine/src/builders2/handlers/transitions/when_descriptor.dart';
import 'package:tree_state_machine/src/builders2/handlers/transitions/when_result_descriptor.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

// TODO: remove this class when we standarsize on data builders
abstract class _TransitionHandlerBuilder<C> {
  final StateKey _forState;
  final Logger _log;
  TransitionHandlerDescriptor<C>? _handler;

  _TransitionHandlerBuilder(this._forState, this._log);
}

class TransitionHandlerBuilder<C, D> extends _TransitionHandlerBuilder<C> {
  TransitionHandlerBuilder(StateKey forState, Logger log) : super(forState, log);

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
  void run(FutureOr<void> Function(TransitionContext transCtx, D data, C ctx) handler,
      {String? label}) {
    _handler = makeRunDescriptor<C, D>(handler, _log, label);
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
    FutureOr<M> Function(TransitionContext ctx, D data)? getMessage,
    M? message,
    String? label,
  }) {
    if (getMessage == null && message == null) {
      throw ArgumentError('getMessage or message must be provided');
    } else if (getMessage != null && message != null) {
      throw ArgumentError('One of getMessage or message must be provided');
    }
    var _getMessage = getMessage ?? (_, __) => message!;
    _handler = makePostDescriptor<C, M, D>(
      (transCtx, _, data) => _getMessage(transCtx, data),
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
    M Function(TransitionContext transCtx, C ctx, D data)? getMessage,
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
    var _getMessage = getMessage ?? (_, __, ___) => message!;
    _handler = makeScheduleDescriptor<C, M, D>(
      (transCtx, ctx, data) => _getMessage(transCtx, ctx, data),
      duration,
      periodic,
      _log,
      label,
    );
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
    D2 Function(TransitionContext transCtx, D2 data, C ctx) update, {
    String? label,
  }) {
    _handler = makeUpdateDataDescriptor<C, D2>(
      update,
      _forState,
      _log,
      label,
    );
  }

  void updateOwnData(
    D Function(TransitionContext transCtx, D data, C ctx) update, {
    String? label,
  }) {
    _handler = makeUpdateDataDescriptor<C, D>(
      update,
      _forState,
      _log,
      label,
    );
  }

  /// Indicates that a transition action should conditionally occur.
  ///
  /// When the transition occurs, [condition] will be evaluated. If `true` is returned, the
  /// transition actions defined by the [buildTrueHandler] callback will be invoked.
  ///
  /// This method returns a builder that can be used to define additional conditions, including an
  /// `otherwise` callback that can be used to define the transition behavior when none of the
  /// conditions evaluate to `true`.
  ///
  /// ```dart
  /// var state1 = StateKey('s1');
  /// var builder = StateTreeBuilder(initialState: state1);
  ///
  /// builder.state(state1, (b) {
  ///   b.onEnter((b) {
  ///     // Conditionally run an action when the state is entered.
  ///     b.when(
  ///       (transCtx, _) => false,
  ///       (b) => b.run((transCtx) => print('Condition 1 is true'))
  ///     ).when(
  ///       (transCtx, _) => true,
  ///       (b) => b.run((transCtx) => print('Condition 2 is true'))
  ///     ).otherwise(
  ///       (b) => b.run((transCtx) => print('No conditions are true'))
  ///     );
  ///   });
  /// });
  /// ```
  ///
  /// The condition can be labeled when formatting a state tree by providing a [label].
  TransitionHandlerWhenBuilder<C, D> when(
    TransitionCondition<C, D> condition,
    void Function(TransitionHandlerBuilder<C, D> builder) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = TransitionHandlerBuilder<C, D>(_forState, _log);
    buildTrueHandler(trueBuilder);
    var whenTrueDescr = trueBuilder._handler!;

    var conditionInfo = TransitionConditionInfo(label, whenTrueDescr.info);
    var conditions = [
      TransitionConditionDescriptor.withData<C, D>(conditionInfo, condition, whenTrueDescr),
    ];

    _handler = makeWhenDescriptor(conditions, _log, label);
    return TransitionHandlerWhenBuilder<C, D>._(
      conditions,
      () => TransitionHandlerBuilder<C, D>(_forState, _log),
    );
  }

  TransitionHandlerWhenResultBuilder<D> whenResult<T>(
    FutureOr<Result<T>> Function(TransitionContext transCtx, D data, C ctx) result,
    void Function(TransitionHandlerBuilder<T, D> builder) buildTrueHandler, {
    String? label,
  }) {
    var continuationBuilder = TransitionHandlerBuilder<T, D>(_forState, _log);
    buildTrueHandler(continuationBuilder);
    var successContinuation = continuationBuilder._handler!;

    var refFailure = Ref<TransitionHandlerDescriptor<AsyncError>?>(null);
    _handler = makeWhenResultDescriptor<C, D, T>(
      _forState,
      result,
      successContinuation,
      refFailure,
      _log,
      label,
    );
    return TransitionHandlerWhenResultBuilder<D>(
      () => TransitionHandlerBuilder<AsyncError, D>(_forState, _log),
      refFailure,
    );
  }
}

class TransitionHandlerWhenBuilder<C, D> {
  final List<TransitionConditionDescriptor<C>> _conditions;
  final TransitionHandlerBuilder<C, D> Function() _makeBuilder;
  TransitionHandlerWhenBuilder._(this._conditions, this._makeBuilder);

  TransitionHandlerWhenBuilder<C, D> when(
    TransitionCondition<C, D> condition,
    void Function(TransitionHandlerBuilder<C, D> builder) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = _makeBuilder();
    buildTrueHandler(trueBuilder);
    var whenTrueDescr = trueBuilder._handler!;
    var conditionInfo = TransitionConditionInfo(label, whenTrueDescr.info);
    _conditions.add(
      TransitionConditionDescriptor.withData<C, D>(conditionInfo, condition, whenTrueDescr),
    );
    return this;
  }

  void otherwise(
    void Function(TransitionHandlerBuilder<C, D> builder) buildOtherwise, {
    String? label,
  }) {
    var otherwiseBuilder = _makeBuilder();
    buildOtherwise(otherwiseBuilder);
    var otherwiseDescr = otherwiseBuilder._handler!;
    var conditionInfo = TransitionConditionInfo(label, otherwiseDescr.info);
    _conditions.add(
      TransitionConditionDescriptor<C>(conditionInfo, (_) => (_) => true, otherwiseDescr),
    );
  }
}

class TransitionHandlerWhenResultBuilder<D> {
  final Ref<TransitionHandlerDescriptor<AsyncError>?> _failureContinuationRef;
  final TransitionHandlerBuilder<AsyncError, D> Function() _makeErrorBuilder;

  TransitionHandlerWhenResultBuilder(this._makeErrorBuilder, this._failureContinuationRef);

  void otherwise(
    void Function(TransitionHandlerBuilder<AsyncError, D> builder) buildErrorHandler, {
    String? label,
  }) {
    var errorBuilder = _makeErrorBuilder();
    buildErrorHandler(errorBuilder);
    _failureContinuationRef.value = errorBuilder._handler;
  }
}

class EmptyData {}

void example() {
  var tb = TransitionHandlerBuilder<TransitionContext, EmptyData>(StateKey(''), Logger(''));
  tb.updateData<String>((transCtx, data, __) => data);
  tb.run((transCtx, _, __) {});
  tb.whenResult<int>((transCtx, _, __) => Result.value(1), (b) {
    b.updateData<String>((transCtx, data, result) => data);
  }).otherwise((b) {
    b.updateData<String>((transCtx, data, error) => data);
  });

  var dtb = TransitionHandlerBuilder<TransitionContext, int>(StateKey(''), Logger(''));
  dtb.updateOwnData((transCtx, data, _) => data);
  dtb.updateData<String>((transCtx, data, _) => data);
  dtb.run((transCtx, data, _) {});
  dtb.whenResult<int>((transCtx, data, _) => Result.value(1), (b) {
    b.updateData<int>((transCtx, data, result) => data);
  }).otherwise((b) {
    b.run((transCtx, data, error) {});
  });
  dtb.when((transCtx, ctx, data) => true, (b) {
    b.updateData<int>((transCtx, data, result) => data);
  }).when((transCtx, ctx, data) => false, (b) {
    b.updateData<int>((transCtx, data, _) => data);
  }).otherwise((b) {
    b.updateOwnData((transCtx, data, _) => data);
  });

  var emptyFoo = Foo<void>();
}

class Foo<T> {}
