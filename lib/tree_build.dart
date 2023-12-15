/// Provides basic infrastructure for creating state trees.
///
/// This library does not provide an application API for defining state trees. Instead it provides
/// the basic protocol for constructing `TreeNode`s, organizing them into a tree, and providing that
/// tree to a `TreeStateMachine`.
///
/// It is intended that applications will use libraries providing various higher-level APIs for
/// defining state tree, and those libraries will work using the core types in this library.
///
/// ///
/// ```dart
/// class MyTreeBuilder implements StateTreeBuilder {
///   // APIs for definining states
///
///   RootTreeNode build(TreeBuildContext buildContext) {
///
///   }
///
/// }
///
/// var treeBuilder =
/// ```
library tree_build;

export 'src/build/tree_build_info.dart';
export 'src/build/tree_build_context.dart';
export 'src/build/tree_builder.dart';
