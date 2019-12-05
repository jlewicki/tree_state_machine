import 'tree_state.dart';
import 'utility.dart';

typedef InitialChild = StateKey Function(TransitionContext ctx);
typedef StateCreator<T extends TreeState> = T Function(StateKey key);
typedef DataStateCreator<T extends DataTreeState<D>, D> = T Function(StateKey key);

class TreeNode {
  final Lazy<TreeState> _lazyState;
  final StateKey key;
  final TreeNode parent;
  // Consider making this list of keys
  final List<TreeNode> children = [];
  final InitialChild initialChild;
  final DataProvider dataProvider;

  TreeNode._(
    this.key,
    this.parent,
    this._lazyState,
    this.initialChild,
    this.dataProvider,
  );

  bool get isRoot => this is RootNode;
  bool get isLeaf => this is LeafNode;
  bool get isInterior => this is InteriorNode;
  bool get isFinal => this is FinalNode;
  TreeState state() => _lazyState.value;

  bool isActive(StateKey stateKey) {
    return selfOrAncestor(stateKey) != null;
  }

  TreeNode selfOrAncestor(StateKey stateKey) {
    TreeNode nextNode = this;
    while (nextNode != null) {
      if (nextNode.key == stateKey) {
        return nextNode;
      }
      nextNode = nextNode.parent;
    }
    return null;
  }

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
}

abstract class ChildNode extends TreeNode {
  ChildNode._(
    StateKey key,
    TreeNode parent,
    Lazy<TreeState> lazyState,
    InitialChild initialChild, [
    DataProvider provider,
  ]) : super._(key, parent, lazyState, initialChild, provider);
}

class RootNode extends TreeNode {
  RootNode(
    StateKey key,
    StateCreator createState,
    InitialChild initialChild, [
    DataProvider provider,
  ]) : super._(key, null, Lazy<TreeState>(() => createState(key)), initialChild, provider);
}

class InteriorNode extends ChildNode {
  InteriorNode(
    StateKey key,
    TreeNode parent,
    StateCreator<TreeState> createState,
    InitialChild initialChild, [
    DataProvider provider,
  ]) : super._(key, parent, Lazy<TreeState>(() => createState(key)), initialChild, provider);
}

class LeafNode extends ChildNode {
  LeafNode(
    StateKey key,
    TreeNode parent,
    StateCreator createState, [
    DataProvider provider,
  ]) : super._(key, parent, Lazy<TreeState>(() => createState(key)), null, provider);
}

class FinalNode extends LeafNode {
  FinalNode(
    StateKey key,
    TreeNode parent,
    StateCreator createState, [
    DataProvider provider,
  ]) : super(key, parent, createState, provider);
}

class NodePath {
  final TreeNode from;
  final TreeNode to;
  final TreeNode lca;
  final Iterable<TreeNode> path;
  final Iterable<TreeNode> exiting;
  final Iterable<TreeNode> entering;

  NodePath._(this.from, this.to, this.lca, this.path, this.exiting, this.entering);

  factory NodePath(TreeNode from, TreeNode to) {
    final lca = from.lcaWith(to);
    final exiting = from.selfAndAncestors().takeWhile((n) => n != lca).toList();
    final entering = to.selfAndAncestors().takeWhile((n) => n != lca).toList().reversed.toList();
    final path = exiting.followedBy(entering);
    return NodePath._(from, to, lca, path, exiting, entering);
  }

  factory NodePath.reenter(TreeNode node, TreeNode from) {
    final lca = node.lcaWith(from);
    assert(lca.key == from.key);
    final exiting = node.selfAndAncestors().takeWhile((n) => n != lca).toList();
    final entering = exiting.reversed.toList();
    final path = exiting.followedBy(entering);
    return NodePath._(node, node, lca, path, exiting, entering);
  }

  factory NodePath.enterFromRoot(TreeNode root, TreeNode to) {
    assert(root.isRoot);
    final exiting = <TreeNode>[];
    final entering = to.selfAndAncestors().toList().reversed.toList();
    final path = exiting.followedBy(entering);
    return NodePath._(root, to, null, path, exiting, entering);
  }
}

abstract class DataProvider<D> implements DataValue<D> {
  D get data;
  Object encode();
  void decodeInto(Object input);
  void initializeLeafDataAccessor(Object Function() getCurrentLeafData);

  static LeafDataProvider<D> currentLeaf<D>() => LeafDataProvider();
}

class OwnedDataProvider<D> implements DataProvider<D> {
  final Map<String, dynamic> Function(D data) encoder;
  final D Function(Map<String, dynamic> json) decoder;
  final D Function() _eval;
  D _data;
  OwnedDataProvider(this._eval, this.encoder, this.decoder);

  D get data => _data ??= _eval();

  /// Encodes the [data] value using the [Codec] provided in the constructor.
  Object encode() => encoder(data);

  void decodeInto(Object input) {
    ArgumentError.checkNotNull('input');
    if (!(input is Map<String, dynamic>)) {
      throw ArgumentError.value(input, 'value',
          'expected value of type Map<String, dynamic>, but received ${input.runtimeType}');
    }
    _data = decoder(input as Map<String, dynamic>);
  }

  @override
  void initializeLeafDataAccessor(Object Function() getCurrentLeafData) {}
}

class LeafDataProvider<D> implements DataProvider<D> {
  D Function() _getCurrentLeafData;
  D get data => _getCurrentLeafData();
  Object encode() => null;
  void decodeInto(Object input) {}
  @override
  void initializeLeafDataAccessor(Object Function() getCurrentLeafData) =>
      _getCurrentLeafData = () {
        final leafData = getCurrentLeafData;
        if (!(leafData is D)) {
          throw StateError(
              'Expected leaf data of type ${TypeLiteral<D>().type}, but received ${leafData?.runtimeType}');
        }
        return leafData as D;
      };
}
