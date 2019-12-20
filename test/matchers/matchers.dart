
import 'package:test/test.dart';
import 'package:tree_state_machine/src/errors.dart';

final isDisposedError = TypeMatcher<DisposedError>();

final Matcher throwsDisposedError = throwsA(isDisposedError);