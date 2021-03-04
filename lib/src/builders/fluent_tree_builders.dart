library fluent_tree_builders;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/tree_node.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/utility.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_helpers.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

part './fluent/tree_builder.dart';
part './fluent/state_builder.dart';
part './fluent/transition_handler_builder.dart';
part './fluent/message_handler_builder.dart';
part './fluent/dot_formatter.dart';

enum _StateType { root, interior, leaf }

/// Describes the payload type [P] that must be provided when entering a state.
class EntryChannel<P> {
  /// The key of the state to which this channel applies.
  final StateKey stateKey;

  /// Creates a new entry channel for the state identified by [stateKey].
  EntryChannel(this.stateKey);
}

class _ChannelEntry<P> {
  final EntryChannel<P> channel;
  final P payload;
  _ChannelEntry(this.channel, this.payload);
}
