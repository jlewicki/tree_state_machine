import 'package:test/test.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

void main() {
  group('StateKey', () {
    test('should use value equality', () {
      var key1 = StateKey('key');
      var key2 = StateKey('key');
      var key3 = StateKey('key3');
      expect(key1 == key1, isTrue);
      expect(key1 == key2, isTrue);
      expect(key1 == key3, isFalse);
    });

    test('can be used as map keys', () {
      var key1 = StateKey('key');
      var map = {key1: 1};
      var key2 = StateKey('key');
      var val = map[key2];
      expect(val, equals(1));
    });
  });

  group('DataStateKey', () {
    test('should use value equality including type of D', () {
      var key1 = DataStateKey<int>('key');
      var key2 = DataStateKey<int>('key');
      var key3 = DataStateKey<String>('key');
      expect(key1 == key2, isTrue);
      // ignore: unnecessary_cast
      expect((key1 as StateKey) == (key3 as StateKey), isFalse);
    });

    test('can be used as map keys', () {
      var key1 = DataStateKey<int>('key');
      var map = {key1: 1};
      var key2 = DataStateKey<int>('key');
      var val = map[key2];
      expect(val, equals(1));
    });
  });
}
