import 'dart:collection';
import 'package:meta/meta.dart';
import 'data_provider.dart';
import 'tree_node.dart';
import 'tree_state.dart';

typedef ChildNodeBuilder = ChildNode Function(BuildContext ctx);
typedef LeafNodeBuilder = LeafNode Function(BuildContext ctx);
typedef InteriorNodeBuilder = InteriorNode Function(BuildContext ctx);
typedef FinalNodeBuilder = FinalNode Function(BuildContext ctx);
typedef RootNodeBuilder = RootNode Function(BuildContext ctx);
typedef CreateProvider<D> = DataProvider<D> Function(Object Function() currentLeafData);

RootNodeBuilder rootBuilder<T extends TreeState>({
  @required StateCreator<T> createState,
  @required Iterable<ChildNodeBuilder> children,
  @required InitialChild initialChild,
  StateKey key,
  Iterable<FinalNodeBuilder> finalStates,
}) =>
    _rootBuilder<T>(
      key,
      (key, ctx) => RootNode(key, createState, initialChild),
      children,
      initialChild,
      finalStates,
    );

RootNodeBuilder dataRootBuilder<T extends DataTreeState<D>, D>({
  @required DataStateCreator<T, D> createState,
  @required Iterable<ChildNodeBuilder> children,
  @required InitialChild initialChild,
  @required DataProvider<D> provider,
  StateKey key,
  Iterable<FinalNodeBuilder> finalStates,
}) {
  ArgumentError.checkNotNull(provider, 'provider');
  return _rootBuilder<T>(
    key,
    (key, ctx) =>
        RootNode(key, _dataStateCreator(createState, provider, ctx), initialChild, provider),
    children,
    initialChild,
    finalStates,
  );
}

InteriorNodeBuilder interiorBuilder<T extends TreeState>({
  @required StateCreator<T> createState,
  @required Iterable<ChildNodeBuilder> children,
  @required InitialChild initialChild,
  StateKey key,
}) =>
    _interiorBuilder<T>(
      key,
      (key, ctx) => InteriorNode(key, ctx.parentNode, createState, initialChild),
      children,
    );

InteriorNodeBuilder dataInteriorBuilder<T extends DataTreeState<D>, D>({
  @required DataStateCreator<T, D> createState,
  @required Iterable<ChildNodeBuilder> children,
  @required InitialChild initialChild,
  @required DataProvider<D> provider,
  StateKey key,
}) {
  ArgumentError.checkNotNull(provider, 'provider');
  return _interiorBuilder<T>(
    key,
    (key, ctx) => InteriorNode(
        key, ctx.parentNode, _dataStateCreator(createState, provider, ctx), initialChild, provider),
    children,
  );
}

LeafNodeBuilder leafBuilder<T extends TreeState>({
  @required StateCreator<T> createState,
  StateKey key,
}) =>
    _leafBuilder<T>(
      key,
      (k, ctx) => LeafNode(k, ctx.parentNode, createState),
    );

LeafNodeBuilder dataLeafBuilder<T extends DataTreeState<D>, D>({
  @required DataStateCreator<T, D> createState,
  @required OwnedDataProvider<D> provider,
  StateKey key,
}) {
  ArgumentError.checkNotNull(provider, 'provider');
  return _leafBuilder<T>(
      key,
      (k, ctx) =>
          LeafNode(k, ctx.parentNode, _dataStateCreator(createState, provider, ctx), provider));
}

FinalNodeBuilder finalBuilder<T extends TreeState>({
  @required StateCreator<T> createState,
  StateKey key,
}) =>
    (ctx) {
      final nodeKey = key ?? StateKey.forState<T>();
      final leaf = FinalNode(nodeKey, ctx.parentNode, createState);
      ctx.addNode(leaf);
      return leaf;
    };

RootNodeBuilder _rootBuilder<T extends TreeState>(
  StateKey key,
  RootNode Function(StateKey, BuildContext) createNode,
  Iterable<ChildNodeBuilder> children,
  InitialChild initialChild,
  Iterable<FinalNodeBuilder> finalStates,
) =>
    (ctx) {
      if (ctx.parentNode != null) {
        throw ArgumentError.value(ctx, 'ctx', 'Unexpected parent node for root node');
      }
      final nodeKey = key ?? StateKey.forState<T>();
      final root = createNode(nodeKey, ctx);
      final childContext = ctx.childContext(root);
      root.children.addAll(children.map((childBuilder) => childBuilder(childContext)));
      if (finalStates != null) {
        root.children.addAll(finalStates.map((childBuilder) => childBuilder(childContext)));
      }
      ctx.addNode(root);
      return root;
    };

InteriorNodeBuilder _interiorBuilder<T extends TreeState>(
  StateKey key,
  InteriorNode Function(StateKey, BuildContext) createNode,
  Iterable<ChildNodeBuilder> children,
) =>
    (ctx) {
      final nodeKey = key ?? StateKey.forState<T>();
      final interior = createNode(nodeKey, ctx);
      final childContext = ctx.childContext(interior);
      interior.children.addAll(children.map((childBuilder) => childBuilder(childContext)));
      ctx.addNode(interior);
      return interior;
    };

LeafNodeBuilder _leafBuilder<T extends TreeState>(
  StateKey key,
  LeafNode Function(StateKey, BuildContext) createNode,
) =>
    (ctx) {
      final nodeKey = key ?? StateKey.forState<T>();
      final leaf = createNode(nodeKey, ctx);
      ctx.addNode(leaf);
      return leaf;
    };

StateCreator _dataStateCreator<T extends DataTreeState<D>, D>(
  DataStateCreator<T, D> createState,
  DataProvider<D> provider,
  BuildContext ctx,
) =>
    (key) {
      final state = createState(key);
      if (provider is CurrentLeafDataProvider) {
        (provider as CurrentLeafDataProvider).initializeLeafDataAccessor(ctx.currentLeafData);
      }
      state.initializeDataValue(provider);
      return state;
    };

class BuildContext {
  final TreeNode parentNode;
  final HashMap<StateKey, TreeNode> nodes;
  final Object Function() currentLeafData;

  BuildContext._(this.parentNode, this.nodes, this.currentLeafData);

  factory BuildContext(Object Function() currentLeafData, [TreeNode parentNode]) =>
      BuildContext._(parentNode, HashMap(), currentLeafData);

  BuildContext childContext(TreeNode newParentNode) =>
      BuildContext._(newParentNode, nodes, currentLeafData);

  void addNode(TreeNode node) {
    if (nodes.containsKey(node.key)) {
      final msg = 'A state with key ${node.key} has already been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    nodes[node.key] = node;
  }
}

// abstract class DataState<T extends DataTreeState<D>, D> {
//   final DataStateCreator<T, D> stateCreator;
//   final DataProvider<D> dataProvider;
//   DataState._(this.stateCreator, this.dataProvider);
// }

// abstract class OwnedDataState<T extends DataTreeState<D>, D> {
//   final DataStateCreator<T, D> stateCreator;
//   final DataProvider<D> dataProvider;
//   DataState._(this.stateCreator, this.dataProvider);
// }
