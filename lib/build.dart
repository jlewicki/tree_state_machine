/// Provides basic infrastructure for creating state trees.
///
/// This library does not provide an application API for defining state trees. Instead it provides
/// the basic protocol for constructing `TreeNode`s, organizing them into a tree, and providing that
/// tree to a `TreeStateMachine`.
///
/// It is intended that applications will use libraries providing various higher-level APIs for
/// defining state tree, and those libraries will work using the core types in this library.
///
// ```dart
/// // Hypothetical class providing high-level API for defining a state tree
/// class MyTreeBuilder implements StateTreeBuildProvider {
///   // APIs for definining states...
///
///   RootNodeBuildInfo createRootNodeBuildInfo() {
///     // Create a RootNodeBuildInfo based on API calls
///     // to this builder....
///   }
/// }
///
/// var myBuilder = MyTreeBuilder();
/// // Call myBuilder methods to define a state tree....
///
/// // The state tree builder will call myBuilder.createRootNodeBuildInfo()
/// var treeBuilder = StateTreeBuilder(myBuilder);
///
/// // The state machine will call treeBuilder.build()
/// var stateMachine = TreeStateMachine(treeBuilder);
library build;

export 'src/build/tree_build_info.dart';
export 'src/build/tree_build_context.dart';
export 'src/build/tree_builder.dart';
