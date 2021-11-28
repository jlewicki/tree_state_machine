import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

/// Utility extensions on [TransitionContext].
extension TransitionContextExtensions on TransitionContext {
  DataValue<D> dataOrThrow<D>([StateKey? key]) {
    var data = this.data<D>(key);
    if (data == null) {
      throw StateError('Unable to find data of type ${TypeLiteral<D>().type}');
    }
    return data;
  }

  D dataValueOrThrow<D>([StateKey? key]) {
    var data = this.data<D>(key);
    if (data == null) {
      return isTypeOf<Object, void>()
          ? data as D
          : throw StateError('Unable to find data value of type ${TypeLiteral<D>().type}');
    }
    return data.value;
  }

  P payloadOrThrow<P>() {
    var payload = this.payload;
    if (payload != null) {
      return payload is P ? payload as P : throw StateError('Unexpected payload type.');
    }
    throw StateError('The transition context does not have a payload.');
  }

  D updateOrThrow<D>(D Function(D current) update, {StateKey? key}) {
    var data = dataOrThrow<D>();
    data.update(update);
    return data.value;
  }
}

/// Utility extensions on [MessageContext].
extension MessageContextExtensions on MessageContext {
  DataValue<D> dataOrThrow<D>([StateKey? key]) {
    var dataVal = data<D>(key);
    if (dataVal == null) {
      throw StateError(
          'Unable to find data value of type ${TypeLiteral<D>().type} in active data states');
    }
    return dataVal;
  }

  D dataValueOrThrow<D>([StateKey? key]) {
    if (isTypeOf<void, D>()) return null as D;
    var dataVal = data<D>(key);
    if (dataVal == null) {
      return isTypeOf<Object, void>()
          ? data as D
          : throw StateError('Unable to find data value of type ${TypeLiteral<D>().type}');
    }
    return dataVal.value;
  }

  M messageAsOrThrow<M>() {
    if (message is M) {
      return message as M;
    }
    throw StateError(
        'Message of type ${message.runtimeType} is not of expected type ${TypeLiteral<M>().type}');
  }

  D updateOrThrow<D>(D Function(D current) update, {StateKey? key}) {
    var data = dataOrThrow<D>(key);
    data.update(update);
    return data.value;
  }
}
