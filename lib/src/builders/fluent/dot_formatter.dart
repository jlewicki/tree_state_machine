part of fluent_tree_builders;

/// Generates a description of a [StateTreeBuilder] in DOT graph format.
class _DotFormatter {
  final String graphName;
  final String Function(StateKey key) getStateName;
  final Map<StateKey, StateBuilder> _stateBuilders;

  _DotFormatter(this._stateBuilders, {this.graphName, this.getStateName});

  String toDot() {
    var rootState = _stateBuilders.values.firstWhere((sb) => sb._stateType == _StateType.root);
    assert(rootState != null);

    var b = new StringBuffer();
    var transitions = <String>[];
    b.writeln('digraph ${graphName ?? ""} {');
    b.writeln('\tcompound=true;');
    b.writeln('\trankdir=TB');
    _renderCompositeState(rootState, b, transitions);

    // Output transition after all nodes are declared, otherwise Graphviz can infer
    // the wrong node hierarchy if it finds a transition to an undeclared node.
    for (var transition in transitions) {
      b.writeln('\t$transition');
    }

    b.writeln('}');

    return b.toString();
  }

  String _renderLeafState(
    StateBuilder leaf,
    StringBuffer sb,
  ) {
    var stateName = _getStateName(leaf);
    sb.writeln('${stateName} [shape=Mrecord, ${_labelState(leaf)}]');
    return stateName;
  }

  void _renderPostNode(
    String postNodeName,
    StringBuffer sb,
  ) {
    sb.writeln('${postNodeName} [shape=circle, style=dotted, label=""]');
  }

  void _renderCompositeState(
    StateBuilder state,
    StringBuffer sb,
    List<String> transitions,
  ) {
    // 'cluster' prefix is a common convention among DOT rendering enginees to render
    // a box that contains the nodes in the subgraph.
    var clusterName = "cluster_${_getStateName(state)}";
    sb.writeln('subgraph ${clusterName} {');
    sb.writeln('label=""');

    // Declare a state representing composite state (rectangular states as indicated by
    // shape=record represent the composite state)
    sb.writeln('${_getStateName(state)} [shape=record, ${_labelState(state)}]');

    // Declare leaf child states
    var childStates = state._children.map((childKey) => _stateBuilders[childKey]).toList();
    var leaves = childStates.where((child) => child._stateType == _StateType.leaf);
    for (var leaf in leaves) {
      _renderLeafState(leaf, sb);
    }

    // Declare interior child states
    var interiors = childStates.where((child) => child._stateType != _StateType.leaf);
    for (var interior in interiors) {
      _renderCompositeState(interior, sb, transitions);
    }

    // If any of the handlers for this state post/schedule, declare a node that
    // represents the post operation
    var firstPostOrSchedule = childStates
        .expand((child) => child._messageHandlerMap.values.expand((handlers) => handlers))
        .firstWhere(
            (handler) =>
                handler.handlerType == _MessageHandlerType.post ||
                handler.handlerType == _MessageHandlerType.schedule,
            orElse: () => null);
    var hasPostHandler = firstPostOrSchedule != null;
    var postNodeName = '${clusterName}_${_getStateName(state)}_post';
    if (hasPostHandler) {
      _renderPostNode(postNodeName, sb);
    }

    // Declare initial transition
    var initialChild =
        childStates.firstWhere((cs) => cs.key == state._initialChild, orElse: () => null);
    transitions.add('${_getStateName(state)} -> ${_getStateName(initialChild)} [style=dashed];');

    // Declare state transitions
    for (var child in childStates) {
      for (var handlerEntry in child._messageHandlerMap.entries) {
        var messageType = handlerEntry.key;
        var childStateName = _getStateName(child);
        // Note that handlers of type unhandled are exluded, since they don't result in a transition.
        var handlers = handlerEntry.value.where((h) => !h.isUnhandled).toList();

        if (handlers.length == 1) {
          transitions.add(_labelMessageHandler(child, handlers[0], childStateName, postNodeName));
        } else if (handlers.length > 1) {
          // There are several handlers with guards for this message type. This is displayed in the
          // graph as an edge leading to a decision node, and then edges from the decision node
          // representing the transition targets

          // Render the decision node
          var decisionNodeName = '${clusterName}_${childStateName}_decision_${messageType}';
          sb.writeln('${decisionNodeName} [shape=circle, label="", width=0.25]');

          // Render edge from state to decision node
          transitions.add('${childStateName} -> ${decisionNodeName} [label=${messageType}]');

          // Render edges for the targets
          for (var handler in handlers) {
            transitions.add(_labelMessageHandler(child, handler, decisionNodeName, postNodeName,
                isTransitionFromDecisionNode: true));
          }
        }
      }
    }

    sb.writeln('}');
  }

  String _getStateName(StateBuilder state) {
    return getStateName != null ? getStateName(state.key) : '${state.key}';
  }

  String _labelState(StateBuilder stateBuilder) {
    // Note that label fields are wrapped in braces. In DOT format this means to
    // flip the layout of the records (flipping from left-right to top-bottom)
    var b = StringBuffer('label="{${_getStateName(stateBuilder)}');

    if (stateBuilder is DataStateBuilder<Object>) {
      b.write('|dataType: ${stateBuilder.dataType}');
    }

    for (var onEnterInfo in stateBuilder._onEnters) {
      b.write('|entry: ${_labelTransitionHandler(onEnterInfo)}');
    }

    for (var onExitInfo in stateBuilder._onExits) {
      b.write('|exit: ${_labelTransitionHandler(onExitInfo)}');
    }

    for (var handlerEntry in stateBuilder._messageHandlerMap.entries) {
      for (var unhandled in handlerEntry.value.where((handler) =>
          handler.handlerType == _MessageHandlerType.unhandled || (handler.isUnhandled ?? false))) {
        var guardLabel = _labelGuard(unhandled.guard, unhandled.guardLabel);
        var handlerOp = _labelMessageHandlerOp(unhandled, labelMessageType: false);
        b.write('|on ${unhandled.messageType}: ${guardLabel}${handlerOp}');
      }
    }

    b.write('}"');
    return b.toString();
  }

  String _labelMessageHandler(
    StateBuilder state,
    _MessageHandlerInfo handlerInfo,
    String sourceNodeName,
    String postNodeName, {
    bool isTransitionFromDecisionNode = false,
  }) {
    // If handlerInfo.targetState is null that means a self transition
    var targetState =
        handlerInfo.targetState != null ? _stateBuilders[handlerInfo.targetState] : state;
    var guardLabel = _labelGuard(handlerInfo.guard, handlerInfo.guardLabel);
    var opName = handlerInfo.handlerLabel ?? _labelMessageHandlerOp(handlerInfo);
    opName = isTransitionFromDecisionNode ? '' : opName;
    var isPostOrSchedule = handlerInfo.handlerType == _MessageHandlerType.post ||
        handlerInfo.handlerType == _MessageHandlerType.schedule;
    var isUnhandled = handlerInfo.isUnhandled;

    if (isPostOrSchedule) {
      return '${sourceNodeName} -> ${postNodeName} [label="${guardLabel} / ${opName} ${handlerInfo.postMessageType}"]';
    } else if (isUnhandled) {
      return '';
    }
    var isNotStay = handlerInfo.handlerType == _MessageHandlerType.goto ||
        handlerInfo.handlerType == _MessageHandlerType.gotoSelf;
    var style = isNotStay ? '' : ',style=dotted';
    return '${sourceNodeName} -> ${_getStateName(targetState)} [label="${guardLabel}${opName}"$style]';
  }

  String _labelMessageHandlerOp(_MessageHandlerInfo info, {bool labelMessageType = true}) {
    var msgType = labelMessageType ? '${info.messageType}' : '';
    var msgTypeWithSlash = msgType + (msgType.length > 0 ? ' / ' : '');
    switch (info.handlerType) {
      case _MessageHandlerType.goto:
      case _MessageHandlerType.gotoSelf:
        return msgType;
      case _MessageHandlerType.post:
        return '${msgTypeWithSlash}POST ${info.postMessageType}';
      case _MessageHandlerType.schedule:
        return '${msgTypeWithSlash}SCHEDULE ${info.postMessageType}';
      case _MessageHandlerType.updateData:
        return '${msgTypeWithSlash}UPDATE ${info.dataType}';
      case _MessageHandlerType.replaceData:
        return '${msgTypeWithSlash}REPLACE ${info.dataType}';
      default:
        return '${msgTypeWithSlash}Function';
    }
  }

  String _labelTransitionHandler(_TransitionHandlerInfo entryInfo) {
    var guardLabel = _labelGuard(entryInfo.guard, entryInfo.guardLabel);
    var opName = entryInfo.handlerLabel ?? _labelTransitionOp(entryInfo);
    return '${guardLabel}${guardLabel.isNotEmpty ? " " : ""}${opName}';
  }

  String _labelTransitionOp(_TransitionHandlerInfo info) {
    switch (info.handlerType) {
      case _TransitionHandlerType.post:
        return 'POST ${info.postMessageType}';
      case _TransitionHandlerType.schedule:
        return 'SCHEDULE ${info.postMessageType}';
      case _TransitionHandlerType.updateData:
        return 'UPDATE ${info.dataType}';
      case _TransitionHandlerType.replaceData:
        return 'REPLACE ${info.dataType}';
      case _TransitionHandlerType.channelEntry:
        return 'Channel Entry';
      case _TransitionHandlerType.opaqueHandler:
        return info.handlerLabel ?? 'Function';
      default:
        return 'Function';
    }
  }

  String _labelGuard(Object guard, String guardLabel) {
    var label = '';
    if (guardLabel != null) {
      label = guardLabel;
    } else if (guard != null) {
      label = 'Function';
    }
    return label.length > 0 ? '[${label}]' : '';
  }
}
