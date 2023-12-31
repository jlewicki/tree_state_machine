part of '../../declarative_builders.dart';

/// Defines methods for writing a textual description of the state tree represented by a
/// [DeclarativeStateTreeBuilder].
abstract class StateTreeFormatter {
  /// Writes a textual description of the state tree represented by [treeBuilder] to the [sink].
  ///
  /// The specific output format depends on the particular [StateTreeFormatter] implementation.
  void formatTo(
    DeclarativeStateTreeBuilder treeBuilder,
    StringSink sink,
  );
}

/// Generates a description of a [DeclarativeStateTreeBuilder] in Graphviz DOT graph format.
class DotFormatter implements StateTreeFormatter {
  /// Optional name used to label the graph
  final String? graphName;

  /// Optional function that will be called when labeling each state in the tree, and can be used
  /// to customize the state names.
  final String Function(StateKey key)? getStateName;

  /// Constructs a [DotFormatter] instance.
  DotFormatter({this.graphName, this.getStateName});

  @override
  void formatTo(DeclarativeStateTreeBuilder treeBuilder, StringSink sink) {
    var formatter = _DotFormatter(treeBuilder, sink, graphName, getStateName);
    formatter.format();
  }
}

class _DotFormatter {
  final DeclarativeStateTreeBuilder treeBuilder;
  final StringSink sink;
  final String? graphName;
  final String Function(StateKey key)? getStateName;
  int _depth = 0;
  _DotFormatter(this.treeBuilder, this.sink, this.graphName, this.getStateName);

  void format() {
    sink.writeln('digraph ${graphName ?? ''} {');

    var tabs = _incrementIndent();
    sink.writeln('${tabs}compound=true;');
    sink.writeln('${tabs}rankdir=TB');
    var transitions = <String>[];

    var rootState = _findRootState();
    _writeCompositeState(rootState, sink, transitions);

    // Output transition after all nodes are declared, otherwise Graphviz can infer
    // the wrong node hierarchy if it finds a transition to an undeclared node.
    for (var transition in transitions) {
      sink.writeln('$tabs$transition');
    }

    sink.writeln('}');
  }

  void _writeCompositeState(
    _StateBuilder state,
    StringSink sink,
    List<String> transitions,
  ) {
    var tabs = _indent();
    // 'cluster' prefix is a common convention among DOT rendering engines to render a box that
    // contains the nodes in the subgraph.
    var stateName = _getStateName(state);
    var clusterName = "cluster_$stateName";
    sink.writeln('${tabs}subgraph $clusterName {');
    tabs = _incrementIndent();
    sink.writeln('${tabs}label=""');

    // Declare a state representing composite state (rectangular states as indicated by
    // shape=record represent the composite state)
    sink.write('$tabs$stateName [shape=record, ');
    _labelState(state, sink);
    sink.writeln(']');

    // Declare leaf child states
    var childStates = state._children
        .map((childKey) => treeBuilder._stateBuilders[childKey]!)
        .toList();
    var childLeaves =
        childStates.where((child) => child.nodeType == NodeType.leaf);
    for (var leaf in childLeaves) {
      _writeLeafState(leaf, sink);
    }

    // Declare interior child states
    var interiors =
        childStates.where((child) => child.nodeType != NodeType.leaf);
    for (var interior in interiors) {
      _writeCompositeState(interior, sink, transitions);
    }

    // If any of the handlers for this state post/schedule, declare a node that represents the post
    // operation. This node is used as a 'sink' destination node for edges that represent the post
    // action.
    var postNodeName = '${clusterName}_${_getStateName(state)}_post';
    tryWritePostNode(childStates, state.key, postNodeName, sink);

    // Declare initial transition
    var initialChildKey = state._initialChild is InitialChildByKey
        ? state._initialChild.initialChild
        : null;
    var initialChild =
        childStates.firstWhereOrNull((cs) => cs.key == initialChildKey);
    if (initialChild != null) {
      transitions.add(
          '${_getStateName(state)} -> ${_getStateName(initialChild)} [style=dashed];');
    }

    // Declare state transitions
    // FUTURE: do we need to do this a loop? can we do it node by node during recursive calls?
    for (var child in childStates) {
      for (var handlerInfo in child._getHandlerInfos()) {
        var childStateName = _getStateName(child);
        // Note that handlers of type unhandled are exluded, since they don't result in a transition
        // from this state
        //var handler = handlerEntry.value;
        var handlerType = handlerInfo.handlerType;
        if (handlerType != MessageHandlerType.unhandled) {
          var conditions = handlerInfo.conditions;
          if (conditions.isEmpty) {
            transitions.add(
              _labelMessageHandler(
                  child, handlerInfo, childStateName, postNodeName),
            );
          } else {
            // Conditions are displayed in the graph as an edge leading to a decision node, and then
            // edges from the decision node representing the transition targets.
            //
            // Render the decision node
            var decisionNodeName =
                '${clusterName}_${childStateName}_decision_${handlerInfo.messageName.toString().replaceAll('.', '_')}';
            sink.writeln(
                '$tabs$decisionNodeName [shape=circle, label="", width=0.25]');

            // Render edge from state to decision node
            transitions.add(
                '$childStateName -> $decisionNodeName [label=${handlerInfo.messageName}]');

            // Render edges for the targets
            for (var condition in conditions) {
              transitions.add(_labelMessageHandler(
                child,
                condition.whenTrueInfo,
                decisionNodeName,
                postNodeName,
                isTransitionFromDecisionNode: true,
                condition: condition,
              ));
            }
          }
        }
      }
    }

    tabs = _decrementIndent();
    sink.writeln('$tabs}');
  }

  void tryWritePostNode(
    List<_StateBuilder> childStates,
    StateKey postingState,
    String postNodeName,
    StringSink sink,
  ) {
    var firstPostOrSchedule = childStates
        .expand((child) => child._getHandlerInfos())
        .expand((info) => _expandConditionHandlers([info]))
        .firstWhereOrNull((info) => info.actions.any((act) =>
            act.actionType == ActionType.post ||
            act.actionType == ActionType.schedule));
    var hasPostHandler = firstPostOrSchedule != null;
    if (hasPostHandler) {
      sink.writeln(
          '${_indent()}$postNodeName [shape=circle, style=dotted, label=""]');
    }
  }

  Iterable<MessageHandlerInfo> _expandConditionHandlers(
      Iterable<MessageHandlerInfo> infos) sync* {
    for (var info in infos) {
      if (info.conditions.isNotEmpty) {
        yield* _expandConditionHandlers(
            info.conditions.map((c) => c.whenTrueInfo));
      } else {
        yield info;
      }
    }
  }

  String _writeLeafState(_StateBuilder leaf, StringSink sb) {
    var stateName = _getStateName(leaf);
    sb.write('${_indent()}$stateName [shape=Mrecord, ');
    if (leaf is MachineStateBuilder) {
      sb.write('style=diagonals, ');
    }
    _labelState(leaf, sink);
    sb.writeln(']');
    return stateName;
  }

  void _labelState(_StateBuilder stateBuilder, StringSink sink) {
    // Note that label fields are wrapped in braces. In DOT format this means to
    // flip the layout of the records (flipping from left-right to top-bottom)
    sink.write('label="{${_getStateName(stateBuilder)}');

    if (stateBuilder._hasStateData) {
      sink.write('|dataType: ${stateBuilder._dataType}');
    }

    if (stateBuilder is MachineStateBuilder) {
      sink.write(
          '|stateMachine: ${stateBuilder._initialMachine.label ?? '<Nested State Machine>'}');
    }

    if (stateBuilder._onEnter != null) {
      sink.write('|entry: ${_labelTransitionHandler(stateBuilder._onEnter!)}');
    }

    if (stateBuilder._onExit != null) {
      sink.write('|exit: ${_labelTransitionHandler(stateBuilder._onExit!)}');
    }

    for (var handlerInfo in stateBuilder._getHandlerInfos()) {
      if (handlerInfo.handlerType == MessageHandlerType.unhandled) {
        var handlerOp =
            _labelMessageHandlerOp(handlerInfo, labelMessageType: false);
        sink.write('|on ${handlerInfo.messageType}: $handlerOp');
      }
    }

    sink.write('}"');
  }

  String _labelTransitionHandler(TransitionHandlerDescriptor<void> entryInfo) {
    var opName = entryInfo.info.label ?? _labelTransitionOp(entryInfo);
    return opName;
  }

  String _labelTransitionOp(TransitionHandlerDescriptor<void> descr) {
    switch (descr.info.handlerType) {
      case TransitionHandlerType.post:
        return 'POST ${descr.info.postOrScheduleMessageType}';
      case TransitionHandlerType.schedule:
        return 'SCHEDULE ${descr.info.postOrScheduleMessageType}';
      case TransitionHandlerType.updateData:
        return 'UPDATE ${descr.info.updateDataType}';
      case TransitionHandlerType.channelEntry:
        return 'Channel Entry';
      case TransitionHandlerType.run:
        return descr.info.label ?? 'Function';
      default:
        return 'Function';
    }
  }

  String _labelMessageHandler(
    _StateBuilder state,
    MessageHandlerInfo handlerInfo,
    String sourceNodeName,
    String postNodeName, {
    bool isTransitionFromDecisionNode = false,
    MessageConditionInfo? condition,
  }) {
    var targetState = handlerInfo.handlerType == MessageHandlerType.goto
        ? treeBuilder._stateBuilders[handlerInfo.goToTarget]!
        : state;
    var targetStateName = _getStateName(targetState);
    var conditionLabel = condition != null ? _labelCondition(condition) : '';
    var opName = handlerInfo.label ??
        _labelMessageHandlerOp(handlerInfo,
            labelMessageType: !isTransitionFromDecisionNode);
    var conditionAndOp =
        '$conditionLabel${conditionLabel.isNotEmpty && opName.isNotEmpty ? ' / ' : ''}$opName';
    var postOrScheduleAction = handlerInfo.actions.firstWhereOrNull((action) =>
        action.actionType == ActionType.post ||
        action.actionType == ActionType.schedule);
    var isUnhandled = handlerInfo.handlerType == MessageHandlerType.unhandled;

    if (postOrScheduleAction != null) {
      return '$sourceNodeName -> $postNodeName [label="$conditionAndOp"]';
    } else if (isUnhandled) {
      return '';
    }
    var isNotStay = handlerInfo.handlerType == MessageHandlerType.goto ||
        handlerInfo.handlerType == MessageHandlerType.gotoSelf;
    var style = isNotStay ? '' : ',style=dotted';

    return '$sourceNodeName -> $targetStateName [label="$conditionAndOp"$style]';
  }

  String _labelMessageHandlerOp(MessageHandlerInfo info,
      {bool labelMessageType = true}) {
    var msgName = labelMessageType ? info.messageName : '';
    var msgTypeWithSlash = msgName + (msgName.isNotEmpty ? ' / ' : '');
    switch (info.handlerType) {
      case MessageHandlerType.goto:
      case MessageHandlerType.gotoSelf:
        return msgName;
      default:
        if (info.actions.length == 1) {
          return '$msgTypeWithSlash${_labelActionOp(info.actions.first)}';
        } else if (info.actions.length > 1) {
          throw StateError('Unexpected multiple actions');
        } else {
          return msgName;
        }
    }
  }

  String _labelActionOp(MessageActionInfo action) {
    switch (action.actionType) {
      case ActionType.run:
        return action.label ?? 'Function';
      case ActionType.post:
        return 'POST ${action.postMessageType}';
      case ActionType.schedule:
        return 'SCHEDULE ${action.postMessageType}';
      case ActionType.updateData:
        return 'UPDATE ${action.updateDataType}';
    }
  }

  String _labelCondition(MessageConditionInfo condition) {
    var label = condition.label ?? 'Function';
    return label.isNotEmpty ? '[$label]' : '';
  }

  String _incrementIndent() {
    _depth += 1;
    return List.filled(_depth, '\t').join();
  }

  String _decrementIndent() {
    _depth -= 1;
    return List.filled(_depth, '\t').join();
  }

  String _indent() {
    return List.filled(_depth, '\t').join();
  }

  String _getStateName(_StateBuilder state) {
    var name = '';
    if (getStateName != null) {
      name = getStateName!(state.key);
    } else {
      name = '${state.key}';
      if (state.key is DataStateKey) {
        // Strip out the datatype from the name, since it is displayed elsewhere in the graph
        name = name.substring(0, name.lastIndexOf('<'));
      }
    }

    return name == DeclarativeStateTreeBuilder.defaultRootKey.toString()
        ? 'Root'
        // Graphviz does not like <, > in names
        : name.replaceAll('<', '_').replaceAll(">", '');
  }

  _StateBuilder _findRootState() {
    return treeBuilder._stateBuilders.values
        .firstWhere((sb) => sb.nodeType == NodeType.root);
  }
}
