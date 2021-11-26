import 'dart:async';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import './state_builder.dart';
import './message_action_builder.dart';
import './handlers/messages/message_handler_descriptor.dart';
import './handlers/messages/go_to_self_descriptor.dart';
import './handlers/messages/go_to_descriptor.dart';
import './handlers/messages/stay_or_unhandled_descriptor.dart';
import './handlers/messages/when_descriptor.dart';
import './handlers/messages/when_result_descriptor.dart';

abstract class _MessageHandlerDescriptorProvider<C> {
  MessageHandlerDescriptor<C>? get descriptor;
}

class _MessageHandlerBuilder<M, D, C> implements _MessageHandlerDescriptorProvider<C> {
  final StateKey _forState;
  final FutureOr<C> Function(MessageContext) _makeContext;
  final Logger _log;
  final String? _messageName;
  @override
  MessageHandlerDescriptor<C>? descriptor;

  _MessageHandlerBuilder(this._forState, this._makeContext, this._log, this._messageName);
}

mixin _GoToHandlerBuilderMixin<M, D, C> on _MessageHandlerBuilder<M, D, C> {
  /// Indicates that a transition to [targetState] should occur.
  ///
  /// If [action] is provided, this action will be invoked before the transition occurs. The
  /// [MessageHandlerBuilder.act] builder can be used to specify this action.
  ///
  /// If [payload] is provided, this function will be called to generate a value for
  /// [TransitionContext.payload] before the transition occurs.
  ///
  /// If [transitionAction] is specified, this function will be called during the transition
  /// between states, after all states are exited, but before entering any new states.
  ///
  /// If [reenterTarget] is true, then the target state will be re-enterd (that is, its exit and
  /// entry handlers will be called), even if the state is already active.
  ///
  /// The state transition can be labeled when formatting a state tree by providing a [label].
  void goTo(
    StateKey targetState, {
    TransitionHandler? transitionAction,
    FutureOr<Object?> Function(MessageHandlerContext<M, D, C> ctx)? payload,
    MessageActionDescriptor<M, D, C>? action,
    bool reenterTarget = false,
    String? label,
  }) {
    descriptor = makeGoToDescriptor<M, D, C>(
      _makeContext,
      _log,
      _forState,
      targetState,
      transitionAction,
      reenterTarget,
      payload,
      action,
      label,
      _messageName,
    );
  }

  /// Indicates that [channel] should be entered and a transition to the channels state should
  /// occur.
  ///
  /// The [payload] function wull be called to obtain the payload for the channel when the
  /// transition occurs.
  void enterChannel<P>(
    Channel<P> channel,
    FutureOr<P> Function(MessageHandlerContext<M, D, C>) payload, {
    bool reenterTarget = false,
  }) {
    goTo(channel.to, payload: payload, reenterTarget: reenterTarget);
  }
}

/// Provides methods for describing how a state behaves in response to a message of type [M].
///
/// A [MessageHandlerBuilder] is provided to the build callback provided to [StateBuilder.onMessage],
/// and is used to describe how messages of a particular type are handled by a state.
///
/// ```dart
/// class MyMessage {}
/// var state1 = StateKey('s1');
/// var state2 = StateKey('s2');
/// var builder = StateTreeBuilder(initialState: state1);
/// builder.state(state1, (b) {
///   // Describe how state responds to MyMessage messages
///   b.onMessage<MyMessage>((b) => b.goTo(state2));
/// });
/// ```
class MessageHandlerBuilder<M, D, C> extends _MessageHandlerBuilder<M, D, C>
    with _GoToHandlerBuilderMixin<M, D, C> {
  MessageHandlerBuilder(
    StateKey forState,
    FutureOr<C> Function(MessageContext) makeContext,
    Logger log,
    String? messageName,
  ) : super(forState, makeContext, log, messageName);

  /// A [MessageActionBuilder] that can be used to specify actions that should take place when
  /// handling messages.
  ///
  /// ```dart
  /// class MyMessage {}
  /// var state1 = StateKey('s1');
  /// var state2 = StateKey('s2');
  /// var builder = StateTreeBuilder(initialState: state1);
  /// builder.state(state1, (b) {
  ///   b.onMessage<MyMessage>((b) => b.goTo(
  ///     state2,
  ///     // Perform an action before state transition occurs.
  ///     action: b.act.run((ctx) =>
  ///       print('Going to $state2 in response to message ${ctx.message}')));
  /// });
  late final act = MessageActionBuilder<M, D, C>(_forState, _log);

  /// Indicates that the message has been handled, and that a self transition should occur.
  ///
  /// During a self-transition this state will be exited and re-entered.
  ///
  /// If [action] is provided, this action will be invoked before the transition occurs. The [act]
  /// builder can be used to specify this action.
  ///
  /// If [transitionAction] is specified, this function will be called during the transition
  /// between states, after all states are exited, but before entering any new states.
  void goToSelf({
    TransitionHandler? transitionAction,
    MessageActionDescriptor<M, D, C>? action,
    String? label,
  }) {
    descriptor = makeGoToSelfDescriptor<M, D, C>(
      _makeContext,
      _log,
      transitionAction,
      action,
      label,
      _messageName,
    );
  }

  /// Indicates that the message has been handled, and no state transition should occur.
  ///
  /// If [action] is provided, this action will be invoked as the message is being handled. The
  /// [act] builder can be used to specify this action.
  void stay({MessageActionDescriptor<M, D, C>? action}) {
    descriptor = makeStayOrUnhandledDescriptor<M, D, C>(
      _makeContext,
      _log,
      _forState,
      action,
      action?.info.label,
      _messageName,
      handled: true,
    );
  }

  /// Indicates that the message has not been handled, and the message should be dispatched to
  /// ancestor states for processing.
  ///
  /// If [action] is provided, this action will be invoked before any ancestor states handle the
  /// message. The [act] builder can be used to specify this action.
  void unhandled({MessageActionDescriptor<M, D, C>? action}) {
    descriptor = makeStayOrUnhandledDescriptor<M, D, C>(
      _makeContext,
      _log,
      _forState,
      action,
      action?.info.label,
      _messageName,
      handled: false,
    );
  }

  MessageHandlerWhenBuilder<M, D, C> when(
    FutureOr<bool> Function(MessageHandlerContext<M, D, C>) condition,
    void Function(MessageHandlerBuilder<M, D, C> builder) buildTrueHandler, {
    String? label,
  }) {
    var conditions = <MessageConditionDescriptor<M, D, C>>[];
    var whenBuilder = MessageHandlerWhenBuilder<M, D, C>(
      () => MessageHandlerBuilder<M, D, C>(_forState, _makeContext, _log, _messageName),
      conditions,
    );

    whenBuilder.when(condition, buildTrueHandler, label: label);
    descriptor = makeWhenDescriptor<M, D, C>(conditions, _makeContext, _log, label, _messageName);
    return whenBuilder;
  }

  MessageHandlerWhenResultBuilder<M, D, C, T> whenResult<T>(
    FutureOr<Result<T>> Function(MessageHandlerContext<M, D, C>) result,
    void Function(MessageHandlerBuilder<M, D, T> builder) buildSuccessHandler, {
    String? label,
  }) {
    var whenResultBuilder = MessageHandlerWhenResultBuilder<M, D, C, T>(
      this,
      result,
      buildSuccessHandler,
      label,
    );

    descriptor = whenResultBuilder.descriptor;

    return whenResultBuilder;
  }
}

class MachineDoneHandlerBuilder<D, C> extends _MessageHandlerBuilder<Object, D, C>
    with _GoToHandlerBuilderMixin<Object, D, C> {
  MachineDoneHandlerBuilder(
    StateKey forState,
    FutureOr<C> Function(MessageContext) makeContext,
    Logger log,
    String? messageName,
  ) : super(forState, makeContext, log, messageName);

  MachineDoneWhenBuilder<D, C> when(
    FutureOr<bool> Function(MessageHandlerContext<Object, D, C>) condition,
    void Function(MachineDoneHandlerBuilder<D, C> builder) buildTrueHandler, {
    String? label,
  }) {
    var conditions = <MessageConditionDescriptor<Object, D, C>>[];
    var whenBuilder = MachineDoneWhenBuilder<D, C>(
      () => MachineDoneHandlerBuilder<D, C>(_forState, _makeContext, _log, _messageName),
      conditions,
    );

    whenBuilder.when(condition, buildTrueHandler, label: label);
    descriptor = makeWhenDescriptor<Object, D, C>(
      conditions,
      _makeContext,
      _log,
      label,
      _messageName,
    );
    return whenBuilder;
  }

  MachineDoneWhenResultBuilder<D, C, T> whenResult<T>(
    FutureOr<Result<T>> Function(MessageHandlerContext<Object, D, C>) result,
    void Function(MachineDoneHandlerBuilder<D, T> builder) buildSuccessHandler, {
    String? label,
  }) {
    var whenResultBuilder = MachineDoneWhenResultBuilder<D, C, T>(
      this,
      result,
      buildSuccessHandler,
      label,
    );

    descriptor = whenResultBuilder.descriptor;

    return whenResultBuilder;
  }
}

class _MessageHandlerWhenBuilder<M, D, C, B extends _MessageHandlerDescriptorProvider<C>> {
  final B Function() _makeBuilder;
  final List<MessageConditionDescriptor<M, D, C>> _conditions;

  _MessageHandlerWhenBuilder(
    this._makeBuilder,
    this._conditions,
  );

  void when(
    FutureOr<bool> Function(MessageHandlerContext<M, D, C>) condition,
    void Function(B builder) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = _makeBuilder();
    buildTrueHandler(trueBuilder);
    var descriptor = trueBuilder.descriptor;

    if (descriptor != null) {
      _conditions.add(MessageConditionDescriptor<M, D, C>(
        MessageConditionInfo(label, descriptor.info),
        (ctx) => true,
        descriptor,
      ));
    }
  }

  void otherwise(
    void Function(B builder) buildOtherwise, {
    String? label,
  }) {
    var builder = _makeBuilder();
    buildOtherwise(builder);
    var descriptor = builder.descriptor;

    if (descriptor != null) {
      _conditions.add(MessageConditionDescriptor<M, D, C>(
        MessageConditionInfo(label, descriptor.info),
        (ctx) => true,
        descriptor,
      ));
    }
  }
}

class MessageHandlerWhenBuilder<M, D, C>
    extends _MessageHandlerWhenBuilder<M, D, C, MessageHandlerBuilder<M, D, C>> {
  MessageHandlerWhenBuilder(
    MessageHandlerBuilder<M, D, C> Function() makeBuilder,
    List<MessageConditionDescriptor<M, D, C>> conditions,
  ) : super(makeBuilder, conditions);
}

class MachineDoneWhenBuilder<D, C>
    extends _MessageHandlerWhenBuilder<Object, D, C, MachineDoneHandlerBuilder<D, C>> {
  MachineDoneWhenBuilder(
    MachineDoneHandlerBuilder<D, C> Function() makeBuilder,
    List<MessageConditionDescriptor<Object, D, C>> conditions,
  ) : super(makeBuilder, conditions);
}

class _MessageHandlerWhenResultBuilder<
    M,
    D,
    C,
    T,
    BSuccess extends _MessageHandlerDescriptorProvider<T>,
    BError extends _MessageHandlerDescriptorProvider<AsyncError>> {
  final _resultRef = Ref<Result<T>?>(null);
  final _failureDescrRef = Ref<MessageHandlerDescriptor<AsyncError>?>(null);
  final BError Function(Ref<Result<T>?> resultRef) _makeErrorBuilder;
  MessageHandlerDescriptor<C>? descriptor;

  _MessageHandlerWhenResultBuilder(
    _MessageHandlerBuilder<M, D, C> parentBuilder,
    BSuccess Function(Ref<Result<T>?> resultRef) makeSuccessBuilder,
    this._makeErrorBuilder,
    FutureOr<Result<T>> Function(MessageHandlerContext<M, D, C>) result,
    void Function(BSuccess builder) buildSuccessHandler,
    String? label,
  ) {
    var successBuilder = makeSuccessBuilder(_resultRef);
    buildSuccessHandler(successBuilder);
    var successDesr = successBuilder.descriptor;

    if (successDesr != null) {
      descriptor = makeWhenResultDescriptor<M, D, C, T>(
        parentBuilder._forState,
        result,
        parentBuilder._makeContext,
        _resultRef,
        successDesr,
        _failureDescrRef,
        parentBuilder._log,
        label,
        parentBuilder._messageName,
      );
    }
  }

  void otherwise(
    void Function(BError builder) buildErrorHandler, {
    String? label,
  }) {
    var errorBuilder = _makeErrorBuilder(_resultRef);
    buildErrorHandler(errorBuilder);
    _failureDescrRef.value = errorBuilder.descriptor;
  }
}

class MessageHandlerWhenResultBuilder<M, D, C, T> extends _MessageHandlerWhenResultBuilder<M, D, C,
    T, MessageHandlerBuilder<M, D, T>, MessageHandlerBuilder<M, D, AsyncError>> {
  MessageHandlerWhenResultBuilder(
    MessageHandlerBuilder<M, D, C> parentBuilder,
    FutureOr<Result<T>> Function(MessageHandlerContext<M, D, C>) result,
    void Function(MessageHandlerBuilder<M, D, T> builder) buildSuccessHandler,
    String? label,
  ) : super(
            parentBuilder,
            (resultRef) => MessageHandlerBuilder<M, D, T>(
                parentBuilder._forState,
                (_) => resultRef.value!.asValue!.value,
                parentBuilder._log,
                parentBuilder._messageName),
            (resultRef) => MessageHandlerBuilder<M, D, AsyncError>(parentBuilder._forState, (_) {
                  var err = resultRef.value!.asError!;
                  return AsyncError(err.error, err.stackTrace);
                }, parentBuilder._log, parentBuilder._messageName),
            result,
            buildSuccessHandler,
            label);
}

class MachineDoneWhenResultBuilder<D, C, T> extends _MessageHandlerWhenResultBuilder<Object, D, C,
    T, MachineDoneHandlerBuilder<D, T>, MachineDoneHandlerBuilder<D, AsyncError>> {
  MachineDoneWhenResultBuilder(
    MachineDoneHandlerBuilder<D, C> parentBuilder,
    FutureOr<Result<T>> Function(MessageHandlerContext<Object, D, C>) result,
    void Function(MachineDoneHandlerBuilder<D, T> builder) buildSuccessHandler,
    String? label,
  ) : super(
            parentBuilder,
            (resultRef) => MachineDoneHandlerBuilder<D, T>(
                parentBuilder._forState,
                (_) => resultRef.value!.asValue!.value,
                parentBuilder._log,
                parentBuilder._messageName),
            (resultRef) => MachineDoneHandlerBuilder<D, AsyncError>(parentBuilder._forState, (_) {
                  var err = resultRef.value!.asError!;
                  return AsyncError(err.error, err.stackTrace);
                }, parentBuilder._log, parentBuilder._messageName),
            result,
            buildSuccessHandler,
            label);
}
