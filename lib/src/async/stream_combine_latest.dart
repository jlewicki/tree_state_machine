import 'dart:async';

/// A stream that combines the latest values of other streams.
///
/// Each time one of the input streams emits a value, this stream will emit a
/// list containing the most recently emitted value values from each input
/// stream. The emitted lists have the same ordering as the iterable passed to
/// [StreamCombineLatest.new].
///
/// Note that the combined stream will not emit a value until all of the input
/// streams have emitted at least one value.
///
/// The combined stream will complete as soon as any of the input streams is
/// completed.
class StreamCombineLatest<T> extends Stream<List<T>> {
  StreamCombineLatest(Iterable<Stream<T>> streams) : _streams = streams;

  final Iterable<Stream<T>> _streams;

  @override
  StreamSubscription<List<T>> listen(
    void Function(List<T> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    var cancelOnError_ = identical(true, cancelOnError);
    var subscriptions = <StreamSubscription<T>>[];
    var allEmitted = false;
    late StreamController<List<T>> controller;
    late List<T?> currentValues;
    late List<bool> hasEmitted;

    void onDone_() {
      for (var i = 0; i < subscriptions.length; i++) {
        subscriptions[i].cancel();
      }
      controller.close();
    }

    void onError_(Object error, StackTrace stackTrace) {
      if (cancelOnError_) {
        for (var i = 0; i < subscriptions.length; i++) {
          subscriptions[i].cancel();
        }
      }
      controller.addError(error, stackTrace);
    }

    void onData_(int index, T data) {
      currentValues[index] = data;
      hasEmitted[index] = true;
      if (!allEmitted) {
        allEmitted = true;
        for (var i = 0; i < hasEmitted.length; ++i) {
          if (!hasEmitted[i]) allEmitted = false;
        }
      }
      if (allEmitted) {
        controller.add(List<T>.from(currentValues));
      }
    }

    try {
      for (var stream in _streams) {
        var index = subscriptions.length;
        subscriptions.add(stream.listen(
          (data) => onData_(index, data),
          onError: onError_,
          onDone: onDone_,
          cancelOnError: cancelOnError,
        ));
      }
    } catch (e) {
      for (var i = subscriptions.length - 1; i >= 0; i--) {
        subscriptions[i].cancel();
      }
      rethrow;
    }

    currentValues = List<T?>.filled(subscriptions.length, null);
    hasEmitted = List<bool>.filled(subscriptions.length, false);

    controller = StreamController<List<T>>(
      onPause: () {
        for (var i = 0; i < subscriptions.length; i++) {
          subscriptions[i].pause();
        }
      },
      onResume: () {
        for (var i = 0; i < subscriptions.length; i++) {
          subscriptions[i].resume();
        }
      },
      onCancel: () {
        for (var i = 0; i < subscriptions.length; i++) {
          // Canceling more than once is safe.
          subscriptions[i].cancel();
        }
      },
    );

    if (subscriptions.isEmpty) {
      controller.close();
    }

    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
