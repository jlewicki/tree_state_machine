import 'package:tree_state_machine/tree_state_machine.dart';

/// Provides methods to specify the initial data values of data states that are entered when
/// a state machine is started.
interface class InitialStateDataBuilder {
  InitialStateDataBuilder(this._initialData);
  final Map<DataStateKey<dynamic>, Object Function()> _initialData;

  /// Adds [value] as the initial data value for the [forState] data state.
  InitialStateDataBuilder initialData<D>(DataStateKey<D> forState, D value) {
    _initialData[forState] = () => value as Object;
    return this;
  }
}

/// A function that uses the [builder] argument to specify the initial data values of data states
/// that are entered when a state machine is started.
///
/// Zero or more initial data values may be specified using the builder. It is not necessary to
/// provide initial values for all data states.
typedef BuildInitialData = void Function(InitialStateDataBuilder builder);

/// Provides initial data values for data states when a state machine is first started by calling
/// [TreeStateMachine.start].
class InitialStateData {
  /// Constructs an [InitialStateData] with a [build] function. The function is called as part of
  /// this constructor, and it can be used to specify the initial data values for one or more
  /// data states.
  InitialStateData(BuildInitialData build) {
    build(InitialStateDataBuilder(_initialData));
  }

  final Map<DataStateKey<dynamic>, Object Function()> _initialData = {};

  /// Returns the initial data value for the specified state, or null if none was defined.
  Object? call(StateKey key) {
    var createInitialData = _initialData[key];
    return createInitialData?.call();
  }
}
