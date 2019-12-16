import 'package:tree_state_machine/src/tree_node.dart';

import 'data_provider.dart';
import 'helpers.dart';
import 'tree_state.dart';
import 'utility.dart';

enum NodeType { rootNode, interiorNode, leafNode, finalNode }
typedef InitialChild = StateKey Function(TransitionContext ctx);
typedef StateCreator<T extends TreeState> = T Function(StateKey key);
typedef DataStateCreator<T extends DataTreeState<D>, D> = T Function(StateKey key);

// abstract class NodeType {}
// abstract class RootNode extends NodeType {}
// abstract class InteriorNode extends NodeType {}
// abstract class LeafNode extends NodeType {}
// abstract class FinalNode extends NodeType {}

/// A node within a state tree.
class TreeNode {
  final NodeType nodeType;
  final Lazy<TreeState> _lazyState;
  final StateKey key;
  final TreeNode parent;
  // Consider making this list of keys
  final List<TreeNode> children = [];
  final InitialChild initialChild;
  final DataProvider dataProvider;

  TreeNode._(
    this.nodeType,
    this.key,
    this.parent,
    this._lazyState,
    this.initialChild,
    this.dataProvider,
  );

  factory TreeNode.root(
    StateKey key,
    StateCreator createState,
    InitialChild initialChild, [
    DataProvider provider,
  ]) =>
      TreeNode._(NodeType.rootNode, key, null, Lazy<TreeState>(() => createState(key)),
          initialChild, provider);

  bool get isRoot => nodeType == NodeType.rootNode;
  bool get isLeaf => nodeType == NodeType.leafNode;
  bool get isInterior => nodeType == NodeType.interiorNode;
  bool get isFinal => nodeType == NodeType.finalNode;

  TreeState state() => _lazyState.value;

  bool isSelfOrAncestor(StateKey stateKey) => selfOrAncestorWithKey(stateKey) != null;

  Iterable<TreeNode> selfAndAncestors() sync* {
    yield this;
    yield* ancestors();
  }

  Iterable<TreeNode> ancestors() sync* {
    var nextAncestor = parent;
    while (nextAncestor != null) {
      yield nextAncestor;
      nextAncestor = nextAncestor.parent;
    }
  }

  TreeNode selfOrAncestorWithKey(StateKey stateKey) {
    return selfAndAncestors().firstWhere((n) => n.key == stateKey, orElse: () => null);
  }

  TreeNode selfOrAncestorWithData<D>() {
    return selfAndAncestors().firstWhere(
      (n) => n.dataProvider != null && n.dataProvider is DataProvider<D>,
      orElse: () => null,
    );
  }

  TreeNode lcaWith(TreeNode other) {
    final i1 = selfAndAncestors().toList().reversed.iterator;
    final i2 = other.selfAndAncestors().toList().reversed.iterator;
    TreeNode lca;
    while (i1.moveNext() && i2.moveNext()) {
      lca = i1.current.key == i2.current.key ? i1.current : lca;
    }
    assert(lca != null, 'LCA must not be null');
    return lca;
  }

  D data<D>() => dataStream<D>(key)?.value;

  DataStream<D> dataStream<D>([StateKey key]) {
    final node = key != null ? selfOrAncestorWithKey(key) : selfOrAncestorWithData<D>();
    if (node?.dataProvider != null) {
      if (node.dataProvider is ObservableData<D>) {
        return (node.dataProvider as ObservableData<D>).dataStream;
      } else {
        Object data = node.dataProvider.data;
        if (data is D) {
          return DelegateObservableData<D>(
              getData: () => data, createStream: () => Stream.value(data)).dataStream;
        }
      }
      throw StateError(
          'Data for state ${node.key} of type ${data.runtimeType} does not match requested type '
          '${TypeLiteral<D>().type}.');
    } else if (isTypeOf<Object, D>()) {
      // Handle case where state has no data, and requested type is a generic object. We don't want
      // to return the raw state this case, so just return null
      return null;
    } else if (node?.state() is D) {
      return !isTypeOf<D, TreeState>() && !isTypeOf<TreeState, D>()
          // In cases where state variables are just instance fields in the TreeState, and the
          // state implements the requested type, just return the state directly. This allows apps
          // to read the state data without having to use DataTreeState.
          // Note that we check if D is a tree state, and throw if it is. The idea here is that it
          // is risky to directy return a state to outside of the statemachine, since then external
          // code could call onenter/onexit and potentially violate invariants. (although external
          // code can simply do the cast themselves and work around this)
          ? DelegateObservableData.single(node.state() as D).dataStream
          : throw StateError('Requested data type ${TypeLiteral<D>().type} cannot be a '
              '${TypeLiteral<TreeState>().type} or Object or dynamic.');
    }
    return null;
  }
}
