import 'dart:collection';
import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/lazy.dart';
import 'package:tree_state_machine/src/tree_state.dart';

typedef InitialChild = StateKey Function(TransitionContext ctx);
typedef Creator<T> = T Function();

class TreeNode {
  final Lazy<TreeState> _lazyState;
  final Lazy<StateHandler> _lazyHandler;
  final StateKey key;
  final TreeNode parent;
  final List<TreeNode> children = [];
  final InitialChild initialChild;

  TreeNode._(
    this.key,
    this.parent,
    this._lazyState,
    this._lazyHandler,
    this.initialChild,
  );

  factory TreeNode(StateKey key, TreeState createState(), TreeNode parent,
      [InitialChild entryTransition]) {
    final lazyState = Lazy(createState);
    final lazyHandler = Lazy(() => lazyState.value.createHandler());
    return TreeNode._(key, parent, lazyState, lazyHandler, entryTransition);
  }

  bool get isRoot => parent == null;
  bool get isLeaf => children.isEmpty;
  bool get isInterior => !isRoot && !isLeaf;
  TreeState state() => _lazyState.value;
  StateHandler handler() => _lazyHandler.value;

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
}

class BuildContext {
  final TreeNode parentNode;
  final HashMap<StateKey, TreeNode> nodes;

  BuildContext._(this.parentNode, this.nodes);
  factory BuildContext(TreeNode parentNode) => BuildContext._(parentNode, HashMap());

  BuildContext childContext(TreeNode newParentNode) => BuildContext._(newParentNode, nodes);

  void addNode(TreeNode node) {
    if (nodes.containsKey(node.key)) {
      final msg = 'A state with key ${node.key} has alreasdy been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    nodes[node.key] = node;
  }
}

abstract class BuildNode {
  TreeNode call(BuildContext ctx);
}

///
/// Builder for non-root nodes.
///
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
// A better solution is needed
//

class BuildRoot<T extends TreeState> implements BuildChildNode {
  final StateKey key;
  final TreeState Function() state;
  final Iterable<BuildChildNode> children;
  final InitialChild entryTransition;

  BuildRoot._(this.key, this.state, this.children, this.entryTransition) {
    if (state == null) throw ArgumentError.notNull('state');
    if (children == null) throw ArgumentError.notNull('children');
    if (children.isEmpty == 0) {
      throw ArgumentError.value(children, 'children', 'Must have at least one item');
    }
    if (entryTransition == null) throw ArgumentError.notNull('entryTransition');
  }

  factory BuildRoot({
    @required T state(),
    @required Iterable<BuildChildNode> children,
    @required InitialChild entryTransition,
  }) =>
      BuildRoot._(StateKey.forState<T>(), state, children, entryTransition);

  factory BuildRoot.keyed({
    @required StateKey key,
    @required T Function() state,
    @required Iterable<BuildChildNode> children,
    @required InitialChild entryTransition,
  }) =>
      BuildRoot._(key, state, children, entryTransition);

  @override
  TreeNode call(BuildContext ctx) {
    if (ctx.parentNode != null) {
      throw ArgumentError.value(ctx, 'ctx', 'Unexpected parent node for root node');
    }
    final root = TreeNode(key, state, null, entryTransition);
    final childContext = ctx.childContext(root);
    root.children.addAll(children.map((childBuilder) => childBuilder(childContext)));
    ctx.addNode(root);
    return root;
  }
}

class BuildInterior<T extends TreeState> implements BuildChildNode {
  final StateKey key;
  final Creator<T> state;
  final Iterable<BuildChildNode> children;
  final InitialChild entryTransition;

  BuildInterior._(this.key, this.state, this.children, this.entryTransition) {
    if (state == null) throw ArgumentError.notNull('state');
    if (children == null) throw ArgumentError.notNull('children');
    if (children.isEmpty)
      throw ArgumentError.value(children, 'children', 'Must have at least one item');
    if (entryTransition == null) throw ArgumentError.notNull('entryTransition');
  }

  factory BuildInterior({
    @required Creator<T> state,
    @required Iterable<BuildChildNode> children,
    @required InitialChild entryTransition,
  }) =>
      BuildInterior._(StateKey.forState<T>(), state, children, entryTransition);

  factory BuildInterior.keyed({
    @required StateKey key,
    @required T state(),
    @required Iterable<BuildChildNode> children,
    @required InitialChild entryTransition,
  }) =>
      BuildInterior._(key, state, children, entryTransition);

  @override
  TreeNode call(BuildContext ctx) {
    final interior = TreeNode(key, state, ctx.parentNode, entryTransition);
    final childContext = ctx.childContext(interior);
    interior.children.addAll(children.map((childBuilder) => childBuilder(childContext)));
    ctx.addNode(interior);
    return interior;
  }
}

class BuildLeaf<T extends TreeState> implements BuildChildNode {
  final StateKey key;
  final T Function() createState;

  BuildLeaf._(this.key, this.createState);

  factory BuildLeaf(T Function() createState) => BuildLeaf._(StateKey.forState<T>(), createState);

  factory BuildLeaf.keyed(StateKey key, T Function() createState) => BuildLeaf._(key, createState);

  @override
  TreeNode call(BuildContext ctx) {
    final leaf = TreeNode(key, createState, ctx.parentNode);
    ctx.addNode(leaf);
    return leaf;
  }
}
