import 'package:test/test.dart';
import 'package:tree_state_machine/src/machine/data_value.dart';

void main() {
  group('DataValue', () {
    group('DataValue.new', () {
      test('should set initial value', () {
        var dv = DataValue<int>(1);
        expect(dv.value, 1);
        expect(dv.hasValue, true);
        expect(dv.hasError, false);
      });
    });

    group('update', () {
      test('should update value', () {
        var dv = DataValue<int>(1);
        var updated = dv.update((current) => current + 1);
        expect(dv.value, 2);
        expect(updated, 2);
      });
    });
  });
}
