import 'package:tree_state_machine/tree_state_machine.dart';

/// A function that is called to intercept the message handler of a state in a
/// state tree.
///
/// If a state has an associated message filter, that filter will be called in
/// lieu of the message handler for the state. In addition to the message
/// context, the filter is passed a [next] function, that when called will call
/// any remaining message filters for the state, followed by calling the message
/// handler for the state itself.
///
/// ```dart
/// var log = Logger();
/// MessageFilter loggingFilter = (msgCtx, next) async {
///   log.info('Calling the message handler for state ${msgCtx.handlingState}');
///   var result = await next();
///   log.info('Called the message handler for state ${msgCtx.handlingState}');
/// }
/// ```
typedef MessageFilter = Future<MessageResult> Function(
  MessageContext msgCtx,
  Future<MessageResult> Function() next,
);

/// A function that is called to intercept a transition handler of a state in a
/// state tree.
///
/// If a state has an associated onEntry or onExit transition filter, that
/// filter will be called in lieu of the transition handler for the state. In
/// addition to the transition context, the filter is passed a [next] function,
/// that when called will call any remaining transition filters for the state,
/// followed by calling the transition handler for the state itself.
///
///  ```dart
/// var log = Logger();
/// TransitionFilter loggingOnEntryFilter = (transCtx, next) async {
///   log.info('Calling the onEnter handler for state ${transCtx.handlingState}');
///   var result = await next();
///   log.info('Called the onEnter handler for state ${transCtx.handlingState}');
/// }
/// ```
typedef TransitionFilter = Future<void> Function(
  TransitionContext ctx,
  Future<void> Function() next,
);

/// /// A set of filter methods that can be associated with a state in a state tree,
/// to intercept and potentially extend the message and transition handlers of
/// the state.
///
/// ```dart
/// var log = Logger('filterLogger');
/// var loggingFilter = TreeStateFilter(
///   onMessage: (msgCtx, next) async {
///     log.info('Calling the message handler for state ${msgCtx.handlingState}');
///     var result = await next();
///     log.info('Called the message handler for state ${msgCtx.handlingState}');
///   },
/// );
/// ```
class TreeStateFilter {
  /// Constructs a [TreeStateFilter].
  ///
  /// [onMessage], [onEnter], and [onExit] handlers can optionally be provided
  /// to provide filtering logic for the corresponding event on the filtered
  /// state.
  TreeStateFilter({
    this.name,
    MessageFilter? onMessage,
    TransitionFilter? onEnter,
    TransitionFilter? onExit,
  })  : _onMessage = onMessage,
        _onEnter = onEnter,
        _onExit = onExit;

  /// Optional user-friendly name of this filter
  final String? name;

  final MessageFilter? _onMessage;
  final TransitionFilter? _onEnter;
  final TransitionFilter? _onExit;

  /// Called to intercept the [TreeState.onMessage] handler of the state being
  /// filtered.
  ///
  /// If this filter was constructed with a `onMessage` handler, that handler
  /// will be called, otherwise [next] is called.
  Future<MessageResult> onMessage(
    MessageContext msgCtx,
    Future<MessageResult> Function() next,
  ) =>
      _onMessage != null ? _onMessage.call(msgCtx, next) : next();

  /// Called to intercept the [TreeState.onEnter] handler of the state being
  /// filtered.
  ///
  /// If this filter was constructed with a `onEnter` handler, that handler
  /// will be called, otherwise [next] is called.
  Future<void> onEnter(
    TransitionContext ctx,
    Future<void> Function() next,
  ) =>
      _onEnter != null ? _onEnter.call(ctx, next) : next();

  /// Called to intercept the [TreeState.onExit] handler of the state being
  /// filtered.
  ///
  /// If this filter was constructed with a `onExit` handler, that handler
  /// will be called, otherwise [next] is called.
  Future<void> onExit(
    TransitionContext ctx,
    Future<void> Function() next,
  ) =>
      _onExit != null ? _onExit.call(ctx, next) : next();
}
