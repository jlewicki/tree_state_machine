import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/utility.dart';

import 'data_provider.dart';
import 'tree_node.dart';
import 'tree_state.dart';

typedef ChildNodeBuilder = ChildNode Function(TreeBuildContext ctx);
typedef LeafNodeBuilder = LeafNode Function(TreeBuildContext ctx);
typedef InteriorNodeBuilder = InteriorNode Function(TreeBuildContext ctx);
typedef FinalNodeBuilder = FinalNode Function(TreeBuildContext ctx);
typedef RootNodeBuilder = RootNode Function(TreeBuildContext ctx);
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
  @required DataProvider<D> Function() createProvider,
  StateKey key,
  Iterable<FinalNodeBuilder> finalStates,
}) {
  ArgumentError.checkNotNull(createProvider, 'provider');
  return _rootBuilder<T>(
    key,
    (key, ctx) {
      final lazyProvider = Lazy(createProvider);
      return RootNode(
        key,
        _dataStateCreator(createState, lazyProvider.value, ctx),
        initialChild,
        lazyProvider.value,
      );
    },
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
  @required DataProvider<D> Function() createProvider,
  StateKey key,
}) {
  ArgumentError.checkNotNull(createProvider, 'provider');

  return _interiorBuilder<T>(
    key,
    (key, ctx) {
      final lazyProvider = Lazy(createProvider);
      return InteriorNode(
        key,
        ctx.parentNode,
        _dataStateCreator(createState, lazyProvider.value, ctx),
        initialChild,
        lazyProvider.value,
      );
    },
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
  @required OwnedDataProvider<D> Function() createProvider,
  StateKey key,
}) {
  ArgumentError.checkNotNull(createProvider, 'provider');

  return _leafBuilder<T>(
    key,
    (k, ctx) {
      final lazyProvider = Lazy(createProvider);
      return LeafNode(
        k,
        ctx.parentNode,
        _dataStateCreator(createState, lazyProvider.value, ctx),
        lazyProvider.value,
      );
    },
  );
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
  RootNode Function(StateKey, TreeBuildContext) createNode,
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
  InteriorNode Function(StateKey, TreeBuildContext) createNode,
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
  LeafNode Function(StateKey, TreeBuildContext) createNode,
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
  TreeBuildContext ctx,
) =>
    (key) {
      final state = createState(key);
      if (provider is CurrentLeafDataProvider) {
        (provider as CurrentLeafDataProvider).initializeLeafData(ctx.currentLeafData);
      }
      state.initializeDataValue(provider);
      return state;
    };

class TreeBuildContext {
  final TreeNode parentNode;
  final HashMap<StateKey, TreeNode> nodes;
  final ObservableData<Object> currentLeafData;

  TreeBuildContext._(this.parentNode, this.nodes, this.currentLeafData);

  factory TreeBuildContext(ObservableData<Object> currentLeafData, [TreeNode parentNode]) =>
      TreeBuildContext._(parentNode, HashMap(), currentLeafData);

  TreeBuildContext childContext(TreeNode newParentNode) =>
      TreeBuildContext._(newParentNode, nodes, currentLeafData);

  void addNode(TreeNode node) {
    if (nodes.containsKey(node.key)) {
      final msg = 'A state with key ${node.key} has already been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    nodes[node.key] = node;
  }
}
