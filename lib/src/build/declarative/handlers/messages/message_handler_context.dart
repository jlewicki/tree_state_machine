part of '../../../../../declarative_builders.dart';

/// Provides access to the context for a message handler, including the [MessageContext], the
/// [message] of type [M] being processed, the state [data] of type [D], and a context value of type
/// [C].
class MessageHandlerContext<M, D, C> {
  /// Constructs a [MessageHandlerContext].
  MessageHandlerContext(
      this.messageContext, this.message, this.data, this.context);

  /// The [MessageContext] that describes the message being processed.
  final MessageContext messageContext;

  /// The message that is being processed.
  final M message;

  /// The state data for the state that is handling the message. This may be of `void` type if
  /// the state has no state data.
  final D data;

  /// An extra contextual value for the handler, whose value depends on the builder method used to
  /// define the message handler.
  final C context;
}
