import 'dart:collection';

import '../data_provider.dart';
import '../tree_node.dart';
import '../tree_state.dart';

/// Base interface for types that identity the types of node in a state tree.
class TaggedNode {}

/// Tags a node as a root node.
class RootNode implements TaggedNode {}

/// Tags a node as a child node.
///
/// A child node is an a node that can be a child of another node.
class ChildNode implements TaggedNode {}

/// Tags a node as an interior node node.
class InteriorNode implements ChildNode {}

class LeafNode implements ChildNode {}

class FinalNode implements LeafNode {}

abstract class NodeBuilder<N extends TaggedNode> {
  TreeNode build(TreeBuildContext context);
}

class TreeBuildContext {
  final TreeNode parentNode;
  final HashMap<StateKey, TreeNode> nodes;
  final ObservableData<Object> currentLeafData;

  TreeBuildContext._(this.parentNode, this.nodes, this.currentLeafData);

  factory TreeBuildContext(ObservableData<Object> currentLeafData, [TreeNode parentNode]) =>
      TreeBuildContext._(parentNode, HashMap(), currentLeafData);

  TreeBuildContext childContext(TreeNode newParentNode) =>
      TreeBuildContext._(newParentNode, nodes, currentLeafData);

  TreeNode buildRoot<T extends TreeState>(
    StateKey key,
    TreeNode Function(StateKey) createNode,
    Iterable<NodeBuilder<ChildNode>> children,
    InitialChild initialChild,
    Iterable<NodeBuilder<FinalNode>> finalStates,
  ) {
    if (parentNode != null) {
      throw StateError('Unexpected parent node in context when building root node');
    }
    final nodeKey = key ?? StateKey.forState<T>();
    final root = createNode(nodeKey);
    final childCtx = childContext(root);
    root.children.addAll(children.map((childBuilder) => childBuilder.build(childCtx)));
    if (finalStates != null) {
      root.children.addAll(finalStates.map((childBuilder) => childBuilder.build(childCtx)));
    }
    _addNode(root);
    return root;
  }

  TreeNode buildLeaf<T extends TreeState>(
    StateKey key,
    TreeNode Function(StateKey) createNode,
  ) {
    final nodeKey = key ?? StateKey.forState<T>();
    final leaf = createNode(nodeKey);
    _addNode(leaf);
    return leaf;
  }

  TreeNode buildInterior<T extends TreeState>(
    StateKey key,
    TreeNode Function(StateKey) createNode,
    Iterable<NodeBuilder<ChildNode>> children,
  ) {
    final nodeKey = key ?? StateKey.forState<T>();
    final interior = createNode(nodeKey);
    final childCtx = childContext(interior);
    interior.children.addAll(children.map((childBuilder) => childBuilder.build(childCtx)));
    _addNode(interior);
    return interior;
  }

  StateCreator stateCreatorWithDataInitialization<T extends DataTreeState<D>, D>(
    DataStateCreator<T, D> createState,
    DataProvider<D> provider,
    ObservableData<Object> leafData,
  ) =>
      (key) {
        final state = createState(key);
        if (provider is CurrentLeafDataProvider) {
          (provider as CurrentLeafDataProvider).initializeLeafData(leafData);
        }
        state.initializeDataValue(provider);
        return state;
      };

  void _addNode(TreeNode node) {
    if (nodes.containsKey(node.key)) {
      final msg = 'A state with key ${node.key} has already been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    nodes[node.key] = node;
  }
}
