// ignore_for_file: non_constant_identifier_names

import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'fixture/tree.dart';

void main() {
  group('TreeNodeInfoNavigationExtensions', () {
    var nodeMap = <StateKey, TreeNodeInfo>{};
    setUp(() {
      var stateTreeBuilder = StateTreeBuilder(treeBuilder());
      var buildContext = TreeBuildContext();
      stateTreeBuilder.build(buildContext);
      nodeMap = buildContext.nodes;
    });

    group('parent', () {
      test('should return parent', () {
        var parent = nodeMap[r_a_a_1_key]!.parent();
        expect(parent, isNotNull);
        expect(parent!.key, equals(r_a_a_key));
      });

      test('should return null for root', () {
        var parent = nodeMap[r_key]!.parent();
        expect(parent, isNull);
      });
    });

    group('root', () {
      test('should return root', () {
        var root = nodeMap[r_a_a_1_key]!.root();
        expect(root.key, equals(r_key));
      });

      test('should return root for root', () {
        var root = nodeMap[r_key]!.root();
        expect(root, same(root));
      });
    });

    group('ancestors', () {
      test('should return ancestors', () {
        var ancs = nodeMap[r_a_a_1_key]!.ancestors().map((a) => a.key);
        expect(
          ListEquality<StateKey>()
              .equals([r_a_a_key, r_a_key, r_key], ancs.toList()),
          isTrue,
        );
      });
    });

    group('selfAndAncestors', () {
      test('should return self and ancestors', () {
        var ancs = nodeMap[r_a_a_1_key]!.selfAndAncestors().map((a) => a.key);
        expect(
          ListEquality<StateKey>()
              .equals([r_a_a_1_key, r_a_a_key, r_a_key, r_key], ancs.toList()),
          isTrue,
        );
      });
    });

    group('children', () {
      test('should return children', () {
        var ancs = nodeMap[r_a_a_key]!.children().map((a) => a.key);
        expect(
          SetEquality<StateKey>()
              .equals({r_a_a_1_key, r_a_a_2_key}, ancs.toSet()),
          isTrue,
        );
      });

      test('should return empty for leaf node', () {
        var ancs = nodeMap[r_a_a_1_key]!.children();
        expect(ancs.isEmpty, isTrue);
      });
    });

    group('descendants', () {
      test('should return descendants', () {
        var ancs = nodeMap[r_a_key]!.descendants().map((a) => a.key);
        expect(
          SetEquality<StateKey>()
              .equals({r_a_a_key, r_a_a_1_key, r_a_a_2_key}, ancs.toSet()),
          isTrue,
        );
      });

      test('should return empty for leaf node', () {
        var ancs = nodeMap[r_a_a_1_key]!.descendants();
        expect(ancs.isEmpty, isTrue);
      });
    });

    group('selfAndDescendants', () {
      test('should return self and descendants', () {
        var ancs = nodeMap[r_a_key]!.selfAndDescendants().map((a) => a.key);
        expect(
          SetEquality<StateKey>().equals(
              {r_a_key, r_a_a_key, r_a_a_1_key, r_a_a_2_key}, ancs.toSet()),
          isTrue,
        );
      });
    });

    group('leaves', () {
      test('should return leaves', () {
        var ancs = nodeMap[r_key]!.leaves().map((a) => a.key).toList();
        expect(
          SetEquality<StateKey>().equals({
            r_a_a_1_key,
            r_a_a_2_key,
            r_b_1_key,
            r_b_2_key,
            r_X_key,
          }, ancs.toSet()),
          isTrue,
        );
      });
    });
  });
}
