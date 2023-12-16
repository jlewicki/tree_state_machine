part of '../../declarative_builders.dart';

class StateBuilderExtensionInfo {
  StateBuilderExtensionInfo(this.key, this.metadata, this.filters);
  final StateKey key;
  final Map<String, Object> metadata;
  final List<TreeStateFilter> filters;
}

class StateExtensionBuilder {
  StateExtensionBuilder._(_StateBuilder stateBuilder)
      : extensionInfo = stateBuilder._getExtensionInfo();

  final StateBuilderExtensionInfo extensionInfo;

  StateExtensionBuilder metadata(Map<String, Object> metadata) {
    for (var pair in metadata.entries) {
      if (extensionInfo.metadata.containsKey(pair.key)) {
        throw StateError(
            'State "${extensionInfo.key}" already has metadata with key "${pair.key}"');
      }
      extensionInfo.metadata[pair.key] = pair.value;
    }

    return this;
  }

  StateExtensionBuilder filter(TreeStateFilter filters) {
    extensionInfo.filters.add(filters);
    return this;
  }

  StateExtensionBuilder filters(Iterable<TreeStateFilter> filters) {
    extensionInfo.filters.addAll(filters);
    return this;
  }
}
