/// Provides support for defining state trees.
///
///
library tree_builders;

import 'dart:async';
import 'dart:collection';
import 'package:collection/collection.dart';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/tree_node.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

part 'src/builders/tree_builder.dart';
part 'src/builders/tree_build_context.dart';
part 'src/builders/state_builders.dart';
part 'src/builders/transition_handler_builders.dart';
part 'src/builders/message_handler_builders.dart';
part 'src/builders/message_action_builders.dart';
part 'src/builders/channel.dart';
part 'src/builders/tree_formatters.dart';
part 'src/builders/handlers/transitions/transition_handler_descriptor.dart';
part 'src/builders/handlers/transitions/transition_when_descriptor.dart';
part 'src/builders/handlers/messages/message_handler_descriptor.dart';
part 'src/builders/handlers/messages/goto_descriptor.dart';
part 'src/builders/handlers/messages/goto_self_descriptor.dart';
part 'src/builders/handlers/messages/stay_or_unhandled_descriptor.dart';
part 'src/builders/handlers/messages/when_descriptor.dart';
