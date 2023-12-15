/// Provides support for defining state trees.
///
///
library declarative_tree_builders;

import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/tree_build.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/tree_node.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

import 'src/declarative_builders/handlers/messages/message_handler_descriptor.dart';
import 'src/declarative_builders/handlers/messages/go_to_descriptor.dart';
import 'src/declarative_builders/handlers/messages/go_to_self_descriptor.dart';
import 'src/declarative_builders/handlers/messages/stay_or_unhandled_descriptor.dart';
import 'src/declarative_builders/handlers/messages/when_descriptor.dart';
import 'src/declarative_builders/handlers/messages/when_result_descriptor.dart';

import 'src/declarative_builders/handlers/transitions/transition_handler_descriptor.dart';
import 'src/declarative_builders/handlers/transitions/update_data_descriptor.dart';
import 'src/declarative_builders/handlers/transitions/when_result_descriptor.dart';
import 'src/declarative_builders/handlers/transitions/when_descriptor.dart';
import 'src/declarative_builders/handlers/transitions/run_descriptor.dart';
import 'src/declarative_builders/handlers/transitions/post_descriptor.dart';
import 'src/declarative_builders/handlers/transitions/schedule_descriptor.dart';

part 'src/declarative_builders/tree_builder.dart';
part 'src/declarative_builders/tree_formatters.dart';
part 'src/declarative_builders/state_builder.dart';
part 'src/declarative_builders/state_builder_extensions.dart';
part 'src/declarative_builders/message_action_builder.dart';
part 'src/declarative_builders/message_handler_builder.dart';
part 'src/declarative_builders/transition_handler_builder.dart';
part 'src/declarative_builders/handlers/messages/message_handler_context.dart';
part 'src/declarative_builders/handlers/transitions/transition_handler_context.dart';
