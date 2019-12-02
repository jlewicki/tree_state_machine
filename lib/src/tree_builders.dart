import 'dart:collection';
import 'package:meta/meta.dart';
import 'tree_node.dart';
import 'tree_state.dart';

typedef ChildNodeBuilder = ChildNode Function(BuildContext ctx);
typedef LeafNodeBuilder = LeafNode Function(BuildContext ctx);
typedef InteriorNodeBuilder = InteriorNode Function(BuildContext ctx);
typedef FinalNodeBuilder = FinalNode Function(BuildContext ctx);
typedef RootNodeBuilder = RootNode Function(BuildContext ctx);

RootNodeBuilder rootBuilder<T extends TreeState>({
  StateKey key,
  @required StateCreator<T> state,
  @required Iterable<ChildNodeBuilder> children,
  @required InitialChild initialChild,
  Iterable<FinalNodeBuilder> finalStates,
}) =>
    _rootBuilder<T>(
        key, (k) => RootNode(k, state, initialChild), children, initialChild, finalStates);

RootNodeBuilder dataRootBuilder<T extends DataTreeState<D>, D>({
  StateKey key,
  @required DataStateCreator<T, D> createState,
  @required Iterable<ChildNodeBuilder> children,
  @required InitialChild initialChild,
  @required DataProvider<D> provider,
  Iterable<FinalNodeBuilder> finalStates,
}) =>
    _rootBuilder<T>(
      key,
      (k) => RootNode(k, (k) => createState(k, provider), initialChild, provider),
      children,
      initialChild,
      finalStates,
    );

InteriorNodeBuilder interiorBuilder<T extends TreeState>({
  StateKey key,
  @required StateCreator<T> state,
  @required Iterable<ChildNodeBuilder> children,
  @required InitialChild initialChild,
}) =>
    _interiorBuilder<T>(key, (k, p) => InteriorNode(k, p, state, initialChild), children);

InteriorNodeBuilder dataInteriorBuilder<T extends DataTreeState<D>, D>({
  StateKey key,
  @required DataStateCreator<T, D> createState,
  @required Iterable<ChildNodeBuilder> children,
  @required InitialChild initialChild,
  @required DataProvider<D> provider,
}) =>
    _interiorBuilder<T>(
        key,
        (k, p) => InteriorNode(k, p, (k) => createState(k, provider), initialChild, provider),
        children);

LeafNodeBuilder leafBuilder<T extends TreeState>({
  StateKey key,
  @required StateCreator<T> createState,
}) {
  return _leafBuilder<T>(key, (k, p) => LeafNode(k, p, createState));
}

LeafNodeBuilder dataLeafBuilder<T extends DataTreeState<D>, D>({
  StateKey key,
  @required DataStateCreator<T, D> createState,
  @required DataProvider<D> provider,
}) {
  return _leafBuilder<T>(key, (k, p) => LeafNode(k, p, (k) => createState(k, provider), provider));
}

FinalNodeBuilder finalBuilder<T extends TreeState>({
  StateKey key,
  @required StateCreator<T> createState,
}) {
  return (ctx) {
    final nodeKey = key ?? StateKey.forState<T>();
    final leaf = FinalNode(nodeKey, ctx.parentNode, createState);
    ctx.addNode(leaf);
    return leaf;
  };
}

RootNodeBuilder _rootBuilder<T extends TreeState>(
  StateKey key,
  RootNode Function(StateKey key) createNode,
  Iterable<ChildNodeBuilder> children,
  InitialChild initialChild,
  Iterable<FinalNodeBuilder> finalStates,
) {
  return (ctx) {
    if (ctx.parentNode != null) {
      throw ArgumentError.value(ctx, 'ctx', 'Unexpected parent node for root node');
    }
    final nodeKey = key ?? StateKey.forState<T>();
    final root = createNode(nodeKey);
    final childContext = ctx.childContext(root);
    root.children.addAll(children.map((childBuilder) => childBuilder(childContext)));
    if (finalStates != null) {
      root.children.addAll(finalStates.map((childBuilder) => childBuilder(childContext)));
    }
    ctx.addNode(root);
    return root;
  };
}

InteriorNodeBuilder _interiorBuilder<T extends TreeState>(
  StateKey key,
  InteriorNode Function(StateKey key, TreeNode parent) createNode,
  Iterable<ChildNodeBuilder> children,
) {
  return (ctx) {
    final nodeKey = key ?? StateKey.forState<T>();
    final interior = createNode(nodeKey, ctx.parentNode);
    final childContext = ctx.childContext(interior);
    interior.children.addAll(children.map((childBuilder) => childBuilder(childContext)));
    ctx.addNode(interior);
    return interior;
  };
}

LeafNodeBuilder _leafBuilder<T extends TreeState>(
  StateKey key,
  LeafNode Function(StateKey key, TreeNode parent) createNode,
) {
  return (ctx) {
    final nodeKey = key ?? StateKey.forState<T>();
    final leaf = createNode(nodeKey, ctx.parentNode);
    ctx.addNode(leaf);
    return leaf;
  };
}

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
