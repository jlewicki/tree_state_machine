part of tree_builders;

/// Defines methods for writing a textual description of the state tree represented by a
/// [StateTreeBuilder].
abstract class StateTreeFormatter {
  /// Writes a textual description of the state tree represented by [treeBuilder] to the [sink].
  ///
  /// The specific output format depends on the particular [StateTreeFormatter] implementation.
  void formatTo(
    StateTreeBuilder treeBuilder,
    StringSink sink,
  );
}

/// Generates a description of a [StateTreeBuilder] in Graphviz DOT graph format.
class DotFormatter implements StateTreeFormatter {
  /// Optional name used to label the graph
  final String? graphName;

  /// Optional function that will be called when labeling each state in the tree, and can be used
  /// to customize the state names.
  final String Function(StateKey key)? getStateName;

  /// Constructs a [DotFormatter] instance.
  DotFormatter({this.graphName, this.getStateName});

  @override
  void formatTo(StateTreeBuilder treeBuilder, StringSink sink) {
    var formatter = _DotFormatter(treeBuilder, sink, graphName, getStateName);
    formatter.format();
  }
}

class _DotFormatter {
  final StateTreeBuilder treeBuilder;
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
    _StateBuilderBase state,
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
    var childStates =
        state._children.map((childKey) => treeBuilder._stateBuilders[childKey]!).toList();
    var childLeaves = childStates.where((child) => child._stateType == _StateType.leaf);
    for (var leaf in childLeaves) {
      _writeLeafState(leaf, sink);
    }

    // Declare interior child states
    var interiors = childStates.where((child) => child._stateType != _StateType.leaf);
    for (var interior in interiors) {
      _writeCompositeState(interior, sink, transitions);
    }

    // If any of the handlers for this state post/schedule, declare a node that represents the post
    // operation. This node is used as a 'sink' destination node for edges that represrnt the post
    // action.
    var postNodeName = '${clusterName}_${_getStateName(state)}_post';
    tryWritePostNode(childStates, postNodeName, sink);

    // Declare initial transition
    var initialChild =
        childStates.firstWhereOrNull((cs) => cs.key == state._initialChild?._initialChildKey);
    if (initialChild != null) {
      transitions.add('${_getStateName(state)} -> ${_getStateName(initialChild)} [style=dashed];');
    }

    // Declare state transitions
    // TODO: do we need to do this a loop? can we do it node by node during recursive calls?
    for (var child in childStates) {
      for (var handlerEntry in child._messageHandlerMap.entries) {
        var messageValueOrType = handlerEntry.key;
        if (isEnumValue(messageValueOrType)) {
          messageValueOrType = describeEnum(messageValueOrType);
        }
        var childStateName = _getStateName(child);
        // Note that handlers of type unhandled are exluded, since they don't result in a transition
        // from this state
        var handler = handlerEntry.value;
        var handlerType = handlerEntry.value.handlerType;
        if (handlerType != _MessageHandlerType.unhandled) {
          var conditions = handler.tryGetConditions();
          if (conditions == null) {
            transitions.add(_labelMessageHandler(child, handler, childStateName, postNodeName));
          } else {
            // Conditions are displayed in the graph as an edge leading to a decision node, and then
            // edges from the decision node representing the transition targets.
            //
            // Render the decision node
            var decisionNodeName =
                '${clusterName}_${childStateName}_decision_${messageValueOrType.toString().replaceAll('.', '_')}';
            sink.writeln('$tabs$decisionNodeName [shape=circle, label="", width=0.25]');

            // Render edge from state to decision node
            transitions.add('$childStateName -> $decisionNodeName [label=$messageValueOrType]');

            // Render edges for the targets
            for (var condition in conditions) {
              transitions.add(_labelMessageHandler(
                child,
                condition.whenTrueDescriptor,
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

  void tryWritePostNode(List<_StateBuilderBase> childStates, String postNodeName, StringSink sink) {
    var firstPostOrSchedule = childStates
        .expand((child) => child._messageHandlerMap.values)
        .firstWhereOrNull((descr) => descr.actions.any(
            (act) => act.actionType == _ActionType.post || act.actionType == _ActionType.schedule));
    var hasPostHandler = firstPostOrSchedule != null;
    if (hasPostHandler) {
      sink.writeln('${_indent()}$postNodeName [shape=circle, style=dotted, label=""]');
    }
  }

  String _writeLeafState(_StateBuilderBase leaf, StringSink sb) {
    var stateName = _getStateName(leaf);
    sb.write('${_indent()}$stateName [shape=Mrecord, ');
    _labelState(leaf, sink);
    sb.writeln(']');
    return stateName;
  }

  void _labelState(_StateBuilderBase stateBuilder, StringSink sink) {
    // Note that label fields are wrapped in braces. In DOT format this means to
    // flip the layout of the records (flipping from left-right to top-bottom)
    sink.write('label="{${_getStateName(stateBuilder)}');

    if (stateBuilder is _DataStateBuilder) {
      sink.write('|dataType: ${stateBuilder.dataType}');
    }

    if (stateBuilder._onEnter != null) {
      sink.write('|entry: ${_labelTransitionHandler(stateBuilder._onEnter!)}');
    }

    if (stateBuilder._onExit != null) {
      sink.write('|exit: ${_labelTransitionHandler(stateBuilder._onExit!)}');
    }

    for (var handlerEntry in stateBuilder._messageHandlerMap.entries) {
      var handler = handlerEntry.value;
      if (handler.handlerType == _MessageHandlerType.unhandled) {
        var handlerOp = _labelMessageHandlerOp(handler, labelMessageType: false);
        sink.write('|on ${handler.messageType}: $handlerOp');
      }
    }

    sink.write('}"');
  }

  String _labelTransitionHandler(_TransitionHandlerDescriptor entryInfo) {
    var opName = entryInfo.label ?? _labelTransitionOp(entryInfo);
    return opName;
  }

  String _labelTransitionOp(_TransitionHandlerDescriptor info) {
    switch (info.handlerType) {
      case _TransitionHandlerType.post:
        return 'POST ${(info as _PostOrScheduleTransitionHandlerDescriptor)._messageType}';
      case _TransitionHandlerType.schedule:
        return 'SCHEDULE ${(info as _PostOrScheduleTransitionHandlerDescriptor)._messageType}';
      case _TransitionHandlerType.updateData:
        return 'UPDATE ${(info as _UpdateDataTransitionHandlerDescriptor)._dataType}';
      case _TransitionHandlerType.channelEntry:
        return 'Channel Entry';
      case _TransitionHandlerType.run:
        return info.label ?? 'Function';
      default:
        return 'Function';
    }
  }

  String _labelMessageHandler(
    _StateBuilderBase state,
    _MessageHandlerInfo handlerInfo,
    String sourceNodeName,
    String postNodeName, {
    bool isTransitionFromDecisionNode = false,
    _MessageConditionInfo? condition,
  }) {
    var targetState = handlerInfo.handlerType == _MessageHandlerType.goto
        ? treeBuilder._stateBuilders[(handlerInfo as _GoToInfo).targetState]!
        : state;
    var targetStateName = _getStateName(targetState);
    var conditionLabel = condition != null ? _labelCondition(condition) : '';
    var opName = handlerInfo.label ??
        _labelMessageHandlerOp(handlerInfo, labelMessageType: !isTransitionFromDecisionNode);
    var conditionAndOp =
        '$conditionLabel${conditionLabel.isNotEmpty && opName.isNotEmpty ? ' / ' : ''}$opName';
    var postOrScheduleAction = handlerInfo.actions.firstWhereOrNull((action) =>
        action.actionType == _ActionType.post || action.actionType == _ActionType.schedule);
    var isUnhandled = handlerInfo.handlerType == _MessageHandlerType.unhandled;

    if (postOrScheduleAction != null) {
      return '$sourceNodeName -> $postNodeName [label="$conditionAndOp"]';
    } else if (isUnhandled) {
      return '';
    }
    var isNotStay = handlerInfo.handlerType == _MessageHandlerType.goto ||
        handlerInfo.handlerType == _MessageHandlerType.gotoSelf;
    var style = isNotStay ? '' : ',style=dotted';

    return '$sourceNodeName -> $targetStateName [label="$conditionAndOp"$style]';
  }

  String _labelMessageHandlerOp(_MessageHandlerInfo info, {bool labelMessageType = true}) {
    var msgType = labelMessageType ? (info.messageName ?? info.messageType.toString()) : '';
    var msgTypeWithSlash = msgType + (msgType.isNotEmpty ? ' / ' : '');
    switch (info.handlerType) {
      case _MessageHandlerType.goto:
      case _MessageHandlerType.gotoSelf:
        return msgType;
      default:
        if (info.actions.length == 1) {
          return '$msgTypeWithSlash${_labelActionOp(info.actions.first)}';
        } else if (info.actions.length > 1) {
          throw StateError('Unexpected multiple actions');
        } else {
          return msgTypeWithSlash;
        }
    }
  }

  String _labelActionOp(_MessageActionInfo action) {
    switch (action.actionType) {
      case _ActionType.run:
        return 'Function';
      case _ActionType.post:
        return 'POST ${action.postMessageType}';
      case _ActionType.schedule:
        return 'SCHEDULE ${action.postMessageType}';
      case _ActionType.updateData:
        return 'UPDATE';
    }
  }

  String _labelCondition(_MessageConditionInfo condition) {
    var label = '';
    if (condition.label != null) {
      label = condition.label!;
    } else {
      label = 'Function';
    }
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

  String _getStateName(_StateBuilderBase state) {
    var name = getStateName != null ? getStateName!(state.key) : '${state.key}';
    return name == StateTreeBuilder.defaultRootKey.toString() ? 'Root' : name;
  }

  _StateBuilderBase _findRootState() {
    return treeBuilder._stateBuilders.values.firstWhere((sb) => sb._stateType == _StateType.root);
  }
}
