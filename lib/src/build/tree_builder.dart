import 'dart:async';

import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'tree_build_context.dart';
import 'tree_node.dart';
import 'tree_node_info.dart';

/// Defines a method for constructing a [RootNodeInfo] the describes how to
/// build a state tree.
///
/// Libraries that provide high-level APIs for defining a state tree must
/// implement this interface in order to translate the state tree as represented
/// by the API into a [RootNodeInfo] that can be used by [StateTreeBuilder] to
/// construct a state tree.
abstract interface class StateTreeBuildProvider {
  /// Creates a [RootNodeInfo] that can be used by [StateTreeBuilder] to build a
  /// state tree.
  RootNodeInfo createRootNodeInfo();
}

/// An error that can be thrown if a [StateTreeBuildProvider] produces an
/// invalid state tree definition.
class StateTreeDefinitionError extends Error {
  final String message;
  StateTreeDefinitionError(this.message);
  @override
  String toString() => "Invalid definition: $message";
}

/// Provides a [build] method that constructs a state tree.
///
/// [StateTreeBuilder] is primary means to supply a state tree to a
/// [TreeStateMachine]. The typical usage is to use a high-level builder API to
/// define a state tree. This API provides a [StateTreeBuildProvider]
/// implementation that can construct a [RootNodeInfo] that reifies the
/// definition of the tree. A [StateTreeBuilder] can then be constructed with
/// this implementation, which in turn can be used to construct a
/// [TreeStateMachine].
///
/// ```dart
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
/// ```
/// If [_createBuildContext] is provided, it will be called each time [build] is
/// called, and the resulting build context will be used during tree
/// construction. This is typically not needed, but may be useful in advanced
/// scenarios requiring access to the state tree as it is built.
class StateTreeBuilder {
  /// Constructs a [StateTreeBuilder].
  StateTreeBuilder(
    this.treeBuildInfoProvider, {
    this.logName,
    TreeBuildContext Function()? createBuildContext,
  }) : _createBuildContext = createBuildContext;

  /// Describes how the root node of the state tree should be constructed when
  /// [build] is called.
  ///
  /// Because this [RootNodeInfo] also describes how its descendants should be
  /// built, it provides a complete description of a state tree.
  final StateTreeBuildProvider treeBuildInfoProvider;

  /// An optional name for the state tree that to be used as the suffix of the
  /// logger name used when logging messages.
  ///
  /// This can be used to correlate log messages with specific state trees when
  /// examining the log output.
  final String? logName;

  final TreeBuildContext Function()? _createBuildContext;

  /// Builds a state tree, and returns the root node of the tree.
  ///
  /// A [buildContext] may optionally provided. This is typically not needed,
  /// but may be useful in advanced scenarios requiring access to the state tree
  /// as it is built.
  TreeNode build([TreeBuildContext? buildContext]) {
    var buildContext_ =
        buildContext ?? _createBuildContext?.call() ?? TreeBuildContext();
    var rootNodeInfo = treeBuildInfoProvider.createRootNodeInfo();
    return buildContext_.buildTree(rootNodeInfo);
  }
}

/// A callable class that can select the initial child state of a parent state,
/// when the parent state is entered.
sealed class InitialChild {
  InitialChild._();

  /// Constructs an [InitialChild] indicating that the state identified by
  /// [initialChild] should be entered.
  factory InitialChild(StateKey initialChild) =>
      InitialChildByKey._(initialChild);

  /// Constructs an [InitialChild] that will run the [getInitialChild] function
  /// when the state is entered in order to determine the initial child,
  factory InitialChild.run(GetInitialChild getInitialChild) =>
      InitialChildByDelegate._(getInitialChild);

  /// Returns the key of the child state that should be entered.
  StateKey call(TransitionContext transCtx);
}

/// An [InitialChild] that selects the child state to enter based on a [StateKey].
final class InitialChildByKey extends InitialChild {
  /// Constructs an [InitialChildByKey] that will select [initialChild] as the
  /// intial child state to enter.
  InitialChildByKey._(this.initialChild) : super._();

  /// Identifies the state that should intitially be entered when a parent state
  /// is entered.
  final StateKey initialChild;

  @override
  StateKey call(TransitionContext transCtx) => initialChild;
}

final class InitialChildByDelegate extends InitialChild {
  InitialChildByDelegate._(this.initialChild) : super._();
  final GetInitialChild initialChild;

  @override
  StateKey call(TransitionContext transCtx) => initialChild(transCtx);
}

/// A callable class that can produce the initial data value for a data state,
/// when the state is entered.
sealed class InitialData<D> {
  InitialData._();

  /// Creates an [InitialData] that will call the [create] function to obtain
  /// the initial data value. The function is called each time the data state is
  /// entered.
  factory InitialData(D Function() create) {
    return InitialDataByFactory(create);
  }

  /// Creates an [InitialData] uses the specified [value] as the initial data
  /// value.
  factory InitialData.value(D value) {
    return InitialDataByValue(value);
  }

  /// Creates an [InitialData] that will call the [getInitialData] function,
  /// passing the [TransitionContext] for the transition in progress, to obtain
  /// the initial data value. The function is called each time the data state is
  /// entered.
  ///
  /// If a precondition cannot be met in order to create the initial data,
  /// [TransitionContext.redirectTo] may be called, and `null` returned.
  ///
  /// ```dart
  /// DataState<AuthenticatedUser>(
  ///   States.authenticated,
  ///   InitialData.run((TransitionContext transCtx) {
  ///      var token = getAccessToken();
  ///      if (token == null) {
  ///         ctx.redirectTo(States.unauthenticated);
  ///         // It is permissible to return null, but only when redirectTo is
  ///         // also called
  ///         return null;
  ///      }
  ///      return AuthenticatedUser.fromToken(token);
  ///   },
  /// );
  /// ```
  factory InitialData.run(GetInitialData<D?> getInitialData) {
    return InitialDataByDelegate._(getInitialData);
  }

  static InitialData<D> fromAncestor<D, DAnc>(
    DataStateKey<DAnc> ancestorState,
    D Function(DAnc ancData) initialValue,
  ) {
    return InitialData.run((ctx) {
      var data = ctx.data(ancestorState);
      return initialValue(data.value);
    });
  }

  /// Creates the initial data value.
  D? call(TransitionContext transCtx);
}

final class InitialDataByValue<D> extends InitialData<D> {
  InitialDataByValue(this.value) : super._();
  final D value;

  @override
  D call(TransitionContext transCtx) => value;
}

final class InitialDataByFactory<D> extends InitialData<D> {
  InitialDataByFactory(this.create) : super._();
  final D Function() create;

  @override
  D call(TransitionContext transCtx) => create();
}

final class InitialDataByDelegate<D> extends InitialData<D> {
  InitialDataByDelegate._(this.initialData) : super._();
  final GetInitialData<D?> initialData;

  @override
  D? call(TransitionContext transCtx) => initialData(transCtx);
}

/// A callable class that can produce the initial nested nested state machine for
/// a machine state, when the machine state is entered.
class InitialMachine implements MachineTreeStateMachine {
  InitialMachine._(
    this._create,
    this.disposeMachineOnExit,
    this.forwardMessages,
    this.label,
  );

  @override
  final bool forwardMessages;
  @override
  final bool disposeMachineOnExit;
  final String? label;
  final FutureOr<TreeStateMachine> Function(TransitionContext) _create;

  @override
  FutureOr<TreeStateMachine> call(TransitionContext transCtx) =>
      _create(transCtx);

  /// Constructs an [InitialMachine] that will use the state machine produced by
  /// the [create] function as the nested state machine.
  ///
  /// If [disposeOnExit] is true (the default), then the nested state machine
  /// will be disposed when the machine state is exited.
  ///
  /// If [forwardMessages] is true (the default), then the machine state will
  /// forward any messages that are dispatched to it to the nested state machine.
  factory InitialMachine.fromMachine(
    FutureOr<TreeStateMachine> Function(TransitionContext) create, {
    bool disposeOnExit = true,
    bool forwardMessages = true,
    String? label,
  }) {
    return InitialMachine._(create, disposeOnExit, forwardMessages, label);
  }

  /// Constructs an [InitialMachine] that will create and start a nested state
  /// machine using the [StateTreeBuildProvider] produced by the [create]
  /// function.
  factory InitialMachine.fromStateTree(
    FutureOr<StateTreeBuildProvider> Function(TransitionContext transCtx)
        create, {
    String? label,
    String? logSuffix,
  }) {
    return InitialMachine._(
      (ctx) {
        return create(ctx).bind((treeBuilder) {
          return TreeStateMachine(
            treeBuilder,
            logName: logSuffix,
          );
        });
      },
      true,
      true,
      label,
    );
  }
}
