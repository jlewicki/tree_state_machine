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

/// Provides initial data values for data states when a state machine is first started by calling
/// [TreeStateMachine.startWith].
class InitialStateData {
  /// Constructs an [InitialStateData] with a [build] function. The function is called as part of
  /// the constructor, and it can be used to specify the initial data values for one or more
  /// data states.
  InitialStateData(void Function(InitialStateDataBuilder b) build) {
    build(InitialStateDataBuilder(_initialData));
  }

  final Map<DataStateKey<dynamic>, Object Function()> _initialData = {};

  /// Returns the initial data value for the specified state, or null if none was defined.
  Object? call(StateKey key) {
    var createInitialData = _initialData[key];
    return createInitialData?.call();
  }
}
