import 'dart:collection';
import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/tree_node.dart';
import 'tree_state.dart';

typedef ChildNodeBuilder = TaggedTreeNode<ChildNode> Function(BuildContext ctx);
typedef LeafNodeBuilder = TaggedTreeNode<Leaf> Function(BuildContext ctx);
typedef InteriorNodeBuilder = TaggedTreeNode<Interior> Function(BuildContext ctx);
typedef FinalNodeBuilder = TaggedTreeNode<Final> Function(BuildContext ctx);
typedef RootNodeBuilder = TaggedTreeNode<Root> Function(BuildContext ctx);

RootNodeBuilder buildRoot<T extends TreeState>({
  StateKey key,
  @required StateCreator<T> state,
  @required Iterable<ChildNodeBuilder> children,
  @required InitialChild initialChild,
  Iterable<FinalNodeBuilder> finalStates,
}) {
  return (ctx) {
    if (ctx.parentNode != null) {
      throw ArgumentError.value(ctx, 'ctx', 'Unexpected parent node for root node');
    }
    final nodeKey = key ?? StateKey.forState<T>();
    final root = rootNode(nodeKey, state, initialChild);
    final childContext = ctx.childContext(root);
    root.children.addAll(children.map((childBuilder) => childBuilder(childContext)));
    if (finalStates != null) {
      root.children.addAll(finalStates.map((childBuilder) => childBuilder(childContext)));
    }
    ctx.addNode(root);
    return root;
  };
}

InteriorNodeBuilder buildInterior<T extends TreeState>({
  StateKey key,
  @required StateCreator<T> state,
  @required Iterable<ChildNodeBuilder> children,
  @required InitialChild initialChild,
}) {
  return (ctx) {
    final nodeKey = key ?? StateKey.forState<T>();
    final interior = interiorNode(nodeKey, state, ctx.parentNode, initialChild);
    final childContext = ctx.childContext(interior);
    interior.children.addAll(children.map((childBuilder) => childBuilder(childContext)));
    ctx.addNode(interior);
    return interior;
  };
}

LeafNodeBuilder buildLeaf<T extends TreeState>({
  StateKey key,
  @required StateCreator<T> createState,
}) {
  return (ctx) {
    final nodeKey = key ?? StateKey.forState<T>();
    final leaf = leafNode(nodeKey, createState, ctx.parentNode);
    ctx.addNode(leaf);
    return leaf;
  };
}

LeafNodeBuilder dataLeaf<T extends DataTreeState<D>, D>({
  StateKey key,
  @required DataStateCreator<T, D> createState,
  @required DataProvider<D> provider,
}) {
  return (ctx) {
    final nodeKey = key ?? StateKey.forState<T>();
    final leaf = leafNode(nodeKey, (k) => createState(k, provider), ctx.parentNode);
    ctx.addNode(leaf);
    return leaf;
  };
}

FinalNodeBuilder buildFinal<T extends TreeState>({
  StateKey key,
  @required StateCreator<T> createState,
}) {
  return (ctx) {
    final nodeKey = key ?? StateKey.forState<T>();
    final leaf = finalNode(nodeKey, createState, ctx.parentNode);
    ctx.addNode(leaf);
    return leaf;
  };
}

// class Build {
//   static RootNodeBuilder root<T extends TreeState>({
//     StateKey key,
//     @required StateCreator<T> state,
//     @required Iterable<ChildNodeBuilder> children,
//     @required InitialChild initialChild,
//     Iterable<FinalNodeBuilder> finalStates,
//   }) {
//     return (ctx) {
//       if (ctx.parentNode != null) {
//         throw ArgumentError.value(ctx, 'ctx', 'Unexpected parent node for root node');
//       }
//       final nodeKey = key ?? StateKey.forState<T>();
//       final root = TreeNode.rootNode(nodeKey, state, initialChild);
//       final childContext = ctx.childContext(root);
//       root.children.addAll(children.map((childBuilder) => childBuilder(childContext)));
//       if (finalStates != null) {
//         root.children.addAll(finalStates.map((childBuilder) => childBuilder(childContext)));
//       }
//       ctx.addNode(root);
//       return root;
//     };
//   }

//   static InteriorNodeBuilder interior<T extends TreeState>({
//     StateKey key,
//     @required StateCreator<T> state,
//     @required Iterable<ChildNodeBuilder> children,
//     @required InitialChild initialChild,
//   }) {
//     return (ctx) {
//       final nodeKey = key ?? StateKey.forState<T>();
//       final interior = TreeNode.interiorNode(nodeKey, state, ctx.parentNode, initialChild);
//       final childContext = ctx.childContext(interior);
//       interior.children.addAll(children.map((childBuilder) => childBuilder(childContext)));
//       ctx.addNode(interior);
//       return interior;
//     };
//   }

//   static LeafNodeBuilder leaf<T extends TreeState>({
//     StateKey key,
//     @required StateCreator<T> createState,
//   }) {
//     return (ctx) {
//       final nodeKey = key ?? StateKey.forState<T>();
//       final leaf = TreeNode.leafNode(nodeKey, createState, ctx.parentNode);
//       ctx.addNode(leaf);
//       return leaf;
//     };
//   }

//   static ChildNodeBuilder dataLeaf<T extends DataTreeState<D>, D>({
//     StateKey key,
//     @required DataStateCreator<T, D> createState,
//     @required DataProvider<D> provider,
//   }) {
//     return (ctx) {
//       final nodeKey = key ?? StateKey.forState<T>();
//       final leaf = TreeNode.leafNode(nodeKey, (k) => createState(k, provider), ctx.parentNode);
//       ctx.addNode(leaf);
//       return leaf;
//     };
//   }

//   static FinalNodeBuilder finalNode<T extends TreeState>({
//     StateKey key,
//     @required StateCreator<T> createState,
//   }) {
//     return (ctx) {
//       final nodeKey = key ?? StateKey.forState<T>();
//       final leaf = TreeNode.finalNode(nodeKey, createState, ctx.parentNode);
//       ctx.addNode(leaf);
//       return leaf;
//     };
//   }
// }

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
