import 'dart:collection';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_node.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import './handlers/messages/message_handler_descriptor.dart';
import './handlers/transitions/transition_handler_descriptor.dart';
import './message_handler_builder.dart';
import './transition_handler_builder.dart';
import './tree_builder.dart';
import './tree_build_context.dart';

class Channel<P> {
  /// The state to enter for this channel.
  final StateKey to;

  /// A descriptive label for this channel.
  final String? label;

  /// Constructs a channel for the [to] state.
  Channel(this.to, {this.label});
}

enum _StateType { root, interior, leaf }

abstract class StateBuilderBase {
  final StateKey key;
  final bool isFinal;
  final List<StateKey> children = [];
  final Logger _log;
  final InitialChild? initialChild;
  final Type? dataType;
  final StateDataCodec? codec;
  StateKey? parent;

  // Key is either a Type object representing message type or a message value
  final Map<Object, MessageHandlerDescriptor<void>> messageHandlerMap = {};
  // 'Open-coded' message handler. This is mutually exclusive with _messageHandlerMap
  MessageHandler? _messageHandler;
  // Builder for onExit handler. This is mutually exclusive with _onExitHandler
  TransitionHandlerDescriptor<void>? _onExit;
  // 'Open-coded' onExit handler. This is mutually exclusive with _onExit
  TransitionHandler? _onExitHandler;
  // Builder for onEnter handler. This is mutually exclusive with _onEnterHandler
  TransitionHandlerDescriptor<void>? _onEnter;
  // 'Open-coded' onEnter handler. This is mutually exclusive with _onEnter
  TransitionHandler? _onEnterHandler;

  StateBuilderBase._(
    this.key,
    this.isFinal,
    this.dataType,
    this.codec,
    this._log,
    this.parent,
    this.initialChild,
  );

  _StateType get _stateType {
    if (parent == null) return _StateType.root;
    if (children.isEmpty) return _StateType.leaf;
    return _StateType.interior;
  }

  void addChild(StateBuilderBase child) {
    child.parent = key;
    children.add(child.key);
  }

  TreeNode _toNode(TreeBuildContext context, Map<StateKey, StateBuilderBase> builderMap) {
    switch (_nodeType()) {
      case NodeType.rootNode:
        var childAndLeafBuilders = children.map((e) => builderMap[e]!);
        return context.buildRoot(
          key,
          (_) => _createState(),
          childAndLeafBuilders.map((cb) {
            return (childCtx) => cb._toNode(childCtx, builderMap);
          }),
          initialChild!.eval,
          codec,
        );
      case NodeType.interiorNode:
        return context.buildInterior(
          key,
          (_) => _createState(),
          children.map((e) {
            return (childCtx) => builderMap[e]!._toNode(childCtx, builderMap);
          }),
          initialChild!.eval,
          codec,
        );
      case NodeType.leafNode:
        return context.buildLeaf(key, (_) => _createState(), codec);
      case NodeType.finalLeafNode:
        return context.buildLeaf(key, (_) => _createState(), codec, isFinal: true);
      default:
        throw StateError('Unrecognized node type');
    }
  }

  NodeType _nodeType() {
    if (parent == null) {
      return NodeType.rootNode;
    } else if (children.isEmpty) {
      return isFinal ? NodeType.finalLeafNode : NodeType.leafNode;
    }
    return NodeType.interiorNode;
  }

  TreeState _createState() {
    return DelegatingTreeState(
      _createMessageHandler(),
      _createOnEnter(),
      _createOnExit(),
      null,
    );
  }

  MessageHandler _createMessageHandler() {
    if (_messageHandler != null) {
      return _messageHandler!;
    }

    final handlerMap = HashMap.fromEntries(
      messageHandlerMap.entries.map((e) => MapEntry(e.key, e.value.makeHandler())),
    );

    return (MessageContext msgCtx) {
      var msg = msgCtx.message;
      // Note that if message handlers were registered by message type, then the runtime type of
      // a message must exactly match the registered type. That is, a message cannot be a subclass
      // of the registered type. Can we do better?
      var handler = handlerMap[msg] ?? handlerMap[msg.runtimeType];
      return handler != null ? handler(msgCtx) : msgCtx.unhandled();
    };
  }

  TransitionHandler _createOnEnter() {
    final onEnterHandler = _onEnterHandler;
    final onEnterDescriptor = _onEnter;
    if (onEnterHandler != null) {
      return onEnterHandler;
    } else if (onEnterDescriptor != null) {
      return onEnterDescriptor.makeHandler();
    }
    throw StateError('Unable to create onEnter');
  }

  TransitionHandler _createOnExit() {
    final onExitHandler = _onEnterHandler;
    final onExitDescriptor = _onEnter;
    if (onExitHandler != null) {
      return onExitHandler;
    } else if (onExitDescriptor != null) {
      return onExitDescriptor.makeHandler();
    }
    throw StateError('Unable to create onExit');
  }

  void _makeVoidTransitionContext(TransitionContext ctx) {}
  void _makeVoidMessageContext(MessageContext ctx) {}
}

abstract class EnterStateBuilder<D> {
  /// Describes how transitions to this state should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used to describe
  /// the behavior of the entry transition.
  void onEnter(void Function(TransitionHandlerBuilder<D, void>) build);

  /// Describes how transition to this state through [channel] should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used
  /// to describe the behavior of the entry transition.
  void onEnterFromChannel<P>(
    Channel<P> channel,
    void Function(TransitionHandlerBuilder<D, P>) build,
  );
}

class StateBuilder<D> extends StateBuilderBase implements EnterStateBuilder<D> {
  final InitialData<D> _initialValue;

  StateBuilder(
    StateKey key,
    this._initialValue,
    Logger log,
    StateKey? parent,
    InitialChild? initialChild, {
    required bool isFinal,
    StateDataCodec? codec,
  }) : super._(key, isFinal, D, codec, log, parent, initialChild);

  @override
  void onEnter(
    void Function(TransitionHandlerBuilder<D, void>) build,
  ) {
    var builder = TransitionHandlerBuilder<D, void>(key, _log, _makeVoidTransitionContext);
    build(builder);
    _onEnter = builder.descriptor;
  }

  @override
  void onEnterFromChannel<P>(
    Channel<P> channel,
    void Function(TransitionHandlerBuilder<D, P>) build,
  ) {
    var builder = TransitionHandlerBuilder<D, P>(
      key,
      _log,
      (transCtx) => transCtx.payloadOrThrow<P>(),
    );
    build(builder);
    _onEnter = builder.descriptor;
  }

  ///
  void onMessage<M>(void Function(MessageHandlerBuilder<M, D, void> b) buildHandler) {
    var builder = MessageHandlerBuilder<M, D, void>(
      key,
      _makeVoidMessageContext,
      _log,
      null,
    );
    buildHandler(builder);
    var descr = builder.descriptor;
  }

  ///
  void onMessageValue<M>(
    M message,
    void Function(MessageHandlerBuilder<M, D, void> b) buildHandler, {
    String? messageName,
  }) {}
}

class MachineData {}

class MachineStateBuilder extends StateBuilderBase {
  final InitialMachine _initialMachine;
  final bool Function(Transition transition)? _isDone;
  final _currentStateRef = Ref<CurrentState?>(null);
  MessageHandlerDescriptor<CurrentState>? _doneDescriptor;
  MessageHandlerDescriptor<void>? _disposedDescriptor;

  MachineStateBuilder(
    StateKey key,
    this._initialMachine,
    this._isDone,
    Logger log,
    StateKey? parent, {
    required bool isFinal,
    StateDataCodec? codec,
  }) : super._(key, isFinal, MachineData, codec, log, parent, null);

  void onMachineDone(
      void Function(MachineDoneHandlerBuilder<void, CurrentState> builder) buildHandler) {
    var builder = MachineDoneHandlerBuilder<void, CurrentState>(
      key,
      (_) => _currentStateRef.value!,
      _log,
      null,
    );
    buildHandler(builder);
    var descr = builder.descriptor;
  }

  @override
  TreeState _createState() {
    var doneDescriptor = _doneDescriptor;
    if (doneDescriptor == null) {
      throw StateError(
          "Nested machine state '$key' does not have a done handler. Make sure to call onMachineDone.");
    }

    return NestedMachineState(
      _initialMachine,
      (currentState) {
        _currentStateRef.value = currentState;
        return doneDescriptor.makeHandler();
      },
      _log,
      _isDone,
      _disposedDescriptor?.makeHandler(),
    );
  }
}

// void example() {
//   var sb = StateBuilder<void>(StateKey('name'), InitialData.empty, Logger('name'), null, null,
//       isFinal: false);
//   var channel = Channel<int>(StateKey(''));
//   sb.onEnterFromChannel<void>(channel, (b) {
//     b.updateOwnData((transCtx, data, ctx) {});
//     b.updateData<int>((transCtx, data, ctx) => data);
//     b.whenResult((transCtx, _, ctx) => Result.value(3), (b) {}).otherwise((b) {});
//     b
//         .when(
//           (transCtx, data, ctx) => true,
//           (b) => b.updateOwnData((transCtx, data, ctx) {}),
//         )
//         .when(
//           (transCtx, data, ctx) => false,
//           (b) => b.updateData<int>((transCtx, data, ctx) => data),
//         );
//     b
//         .whenWith<String>(
//           (transCtx, data, ctx) => 'null',
//           (transCtx, data, ctx) => true,
//           (b) => b.updateOwnData((transCtx, data, ctx) {}),
//         )
//         .otherwise((b) => b.updateOwnData((transCtx, data, ctx) {}));
//   });

//   sb.onMessage<AMessage>((b) {
//     b.goTo(StateKey('name'), action: b.act.run((ctx) => print('')));
//   });

//   sb.onMessage<AMessage>((b) {
//     b.when((ctx) => true, (b) => b.goTo(StateKey(''))).otherwise((b) => b.goTo(StateKey('')));
//   });

//   MachineStateBuilder? msb;

//   msb!.onMachineDone((b) {
//     b.when((ctx) => true, (b) {
//       b.goTo(StateKey(''));
//     });
//   });
// }

// class AMessage {}
