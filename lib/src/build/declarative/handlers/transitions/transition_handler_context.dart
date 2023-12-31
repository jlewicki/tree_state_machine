part of '../../../../../declarative_builders.dart';

/// Provides access to the context for a transition handler, including the [transitionContext], the
/// state [data], and a [context] value.
class TransitionHandlerContext<D, C> {
  /// The [TransitionContext] that describes the state transition that is taking place.
  final TransitionContext transitionContext;

  /// The state data of the state that is handling the transition.  This may be of `void` type if
  /// the state has no state data.
  final D data;

  /// An extra data value for the transition, whose value may depend on the context in which is
  /// used.
  ///
  /// The context type is determined by the builder method that is used to define the transition
  /// handler. For example, when [StateBuilder.onEnterFromChannel] is used to define an entry
  /// transition, the context value will match the payload of the channel.
  final C context;
  TransitionHandlerContext(this.transitionContext, this.data, this.context);
}
