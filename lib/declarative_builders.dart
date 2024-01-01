/// Provides support for defining state trees in a declarative fashion.
///
/// When defining state and their behavior with this library, [DeclarativeStateTreeBuilder] captures
/// a description of the resulting state tree that can be used to generate a diagram of the tree,
/// which may be useful for documentation purposes.
///
/// ```dart
/// class States {
///   static final locked = StateKey('locked');
///   static final unlocked = StateKey('unlocked');
/// }
///
/// var builder = DeclarativeStateTreeBuilder(initialChild: States.locked)
///   ..state(States.locked, (b) {
///     b.onMessageValue(Messages.insertCoin, (b) => b.goTo(States.unlocked));
///   })
///   ..state(States.unlocked, (b) {
///     b.onMessageValue(Messages.push, (b) => b.goTo(States.locked),
///         messageName: 'push');
///   });
///
///  var sb = StringBuffer();
///  declBuilder.format(sb, DotFormatter());
///  print(sb.toString());
/// ```
library declarative_builders;

import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/src/build/tree_node.dart';
import 'package:tree_state_machine/src/build/tree_builder.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

import 'src/build/declarative/handlers/messages/message_handler_descriptor.dart';
import 'src/build/declarative/handlers/messages/go_to_descriptor.dart';
import 'src/build/declarative/handlers/messages/go_to_self_descriptor.dart';
import 'src/build/declarative/handlers/messages/stay_or_unhandled_descriptor.dart';
import 'src/build/declarative/handlers/messages/when_descriptor.dart';
import 'src/build/declarative/handlers/messages/when_result_descriptor.dart';

import 'src/build/declarative/handlers/transitions/transition_handler_descriptor.dart';
import 'src/build/declarative/handlers/transitions/update_data_descriptor.dart';
import 'src/build/declarative/handlers/transitions/when_result_descriptor.dart';
import 'src/build/declarative/handlers/transitions/when_descriptor.dart';
import 'src/build/declarative/handlers/transitions/run_descriptor.dart';
import 'src/build/declarative/handlers/transitions/post_descriptor.dart';
import 'src/build/declarative/handlers/transitions/schedule_descriptor.dart';

part 'src/build/declarative/tree_builder.dart';
part 'src/build/declarative/tree_formatters.dart';
part 'src/build/declarative/state_builder.dart';
part 'src/build/declarative/state_builder_extensions.dart';
part 'src/build/declarative/message_action_builder.dart';
part 'src/build/declarative/message_handler_builder.dart';
part 'src/build/declarative/transition_handler_builder.dart';
part 'src/build/declarative/handlers/messages/message_handler_context.dart';
part 'src/build/declarative/handlers/transitions/transition_handler_context.dart';
