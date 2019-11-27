import 'dart:collection';
import 'package:meta/meta.dart';
import 'tree_node.dart';
import 'tree_state.dart';

class BuildContext {
  final TreeNode parentNode;
  final HashMap<StateKey, TreeNode> nodes;

  BuildContext._(this.parentNode, this.nodes);
  factory BuildContext([TreeNode parentNode]) => BuildContext._(parentNode, HashMap());

  BuildContext childContext(TreeNode newParentNode) => BuildContext._(newParentNode, nodes);

  void addNode(TreeNode node) {
    if (nodes.containsKey(node.key)) {
      final msg = 'A state with key ${node.key} has already been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    nodes[node.key] = node;
  }
}

abstract class BuildNode {
  TreeNode call(BuildContext ctx);
}

/// A builder for nodes that can be children of other nodes.
abstract class BuildChildNode extends BuildNode {}

//
// General note about node builders:
// For convenience in generating state keys when calling the unnamed ctor, the builders are generic types. And for
// readability when declaring state trees with the builders, keyed optional args are used.
//
// Unfortunately, the dart analyzer does not check for @required in generic types (I think this issue reflects that:
// https://github.com/dart-lang/sdk/issues/38596). Which means currently it possible for consumers to leave off required
// arguments. Maybe we should just go back to positional parameters
//
// UPDATE: beta version of Dart 1.11.0 SDK fixes this!
//
// A better solution is needed
//

class BuildRoot<T extends TreeState> implements BuildNode {
  final StateKey key;
  final StateCreator<T> state;
  final Iterable<BuildChildNode> children;
  final InitialChild initialChild;
  final Iterable<BuildTerminal> terminalStates;

  BuildRoot._(this.key, this.state, this.children, this.initialChild, this.terminalStates) {
    ArgumentError.checkNotNull(key, 'key');
    ArgumentError.checkNotNull(state, 'state');
    ArgumentError.checkNotNull(children, 'children');
    ArgumentError.checkNotNull(initialChild, 'initialChild');
    if (children.isEmpty) {
      throw ArgumentError.value(children, 'children', 'Must have at least one item');
    }
  }

  factory BuildRoot({
    @required StateCreator<T> state,
    @required Iterable<BuildChildNode> children,
    @required InitialChild initialChild,
    Iterable<BuildTerminal> terminalStates,
  }) =>
      BuildRoot._(StateKey.forState<T>(), state, children, initialChild, terminalStates ?? []);

  factory BuildRoot.keyed({
    @required StateKey key,
    @required StateCreator<T> state,
    @required Iterable<BuildChildNode> children,
    @required InitialChild initialChild,
    Iterable<BuildTerminal> terminalStates,
  }) =>
      BuildRoot._(key, state, children, initialChild, terminalStates ?? []);

  @override
  TreeNode call(BuildContext ctx) {
    if (ctx.parentNode != null) {
      throw ArgumentError.value(ctx, 'ctx', 'Unexpected parent node for root node');
    }
    final root = TreeNode(key, state, null, initialChild);
    final childContext = ctx.childContext(root);
    root.children.addAll(children.map((childBuilder) => childBuilder(childContext)));
    root.children.addAll(terminalStates.map((childBuilder) => childBuilder(childContext)));
    ctx.addNode(root);
    return root;
  }
}

class BuildInterior<T extends TreeState> implements BuildChildNode {
  final StateKey key;
  final StateCreator<T> state;
  final Iterable<BuildChildNode> children;
  final InitialChild initialChild;

  BuildInterior._(this.key, this.state, this.children, this.initialChild) {
    ArgumentError.checkNotNull(key, 'key');
    ArgumentError.checkNotNull(state, 'state');
    ArgumentError.checkNotNull(children, 'children');
    ArgumentError.checkNotNull(initialChild, 'initialChild');
    if (children.isEmpty) {
      throw ArgumentError.value(children, 'children', 'Must have at least one item');
    }
  }

  factory BuildInterior({
    @required StateCreator<T> state,
    @required Iterable<BuildChildNode> children,
    @required InitialChild initialChild,
  }) =>
      BuildInterior._(StateKey.forState<T>(), state, children, initialChild);

  factory BuildInterior.keyed({
    @required StateKey key,
    @required StateCreator<T> state,
    @required Iterable<BuildChildNode> children,
    @required InitialChild initialChild,
  }) =>
      BuildInterior._(key, state, children, initialChild);

  @override
  TreeNode call(BuildContext ctx) {
    final interior = TreeNode(key, state, ctx.parentNode, initialChild);
    final childContext = ctx.childContext(interior);
    interior.children.addAll(children.map((childBuilder) => childBuilder(childContext)));
    ctx.addNode(interior);
    return interior;
  }
}

class BuildLeaf<T extends TreeState> implements BuildChildNode {
  final StateKey key;
  final StateCreator<T> createState;

  BuildLeaf._(this.key, this.createState) {
    ArgumentError.checkNotNull(key, 'key');
    ArgumentError.checkNotNull(createState, 'createState');
  }

  factory BuildLeaf(StateCreator<T> createState) =>
      BuildLeaf._(StateKey.forState<T>(), createState);

  factory BuildLeaf.keyed(StateKey key, StateCreator<T> createState) =>
      BuildLeaf._(key, createState);

  @override
  TreeNode call(BuildContext ctx) {
    final leaf = TreeNode(key, createState, ctx.parentNode);
    ctx.addNode(leaf);
    return leaf;
  }
}

class BuildTerminal<T extends TerminalTreeState> extends BuildNode {
  final StateKey key;
  final StateCreator<T> createState;

  BuildTerminal._(this.key, this.createState) {
    ArgumentError.checkNotNull(key, 'key');
    ArgumentError.checkNotNull(createState, 'createState');
  }

  factory BuildTerminal(StateCreator<T> createState) =>
      BuildTerminal._(StateKey.forState<T>(), createState);

  factory BuildTerminal.keyed(StateKey key, StateCreator<T> createState) =>
      BuildTerminal._(key, createState);

  @override
  TreeNode call(BuildContext ctx) {
    final terminal = TreeNode.terminal(key, createState, ctx.parentNode);
    ctx.addNode(terminal);
    return terminal;
  }
}
