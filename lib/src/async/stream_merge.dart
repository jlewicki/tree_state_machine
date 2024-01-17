import 'dart:async';

/// A stream that combines multiple streams into one by merging their events.
///
/// Each time one of the input streams emits a value, this stream will the same
/// value, potentially interleaving values from the different streams.
///
/// The combined stream will emit an error when any of the input streams emits
/// an error.
///
/// The combined stream will complete when all of the input streams have
/// completed.
class StreamMerge<T> extends Stream<T> {
  StreamMerge(Iterable<Stream<T>> streams) : _streams = streams;

  final Iterable<Stream<T>> _streams;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    var subscriptions = <StreamSubscription<T>>[];
    late List<bool> completedStreams;
    late StreamController<T> controller;

    void onData_(T data) {
      controller.add(data);
    }

    void onError_(Object error, StackTrace stackTrace) {
      if (cancelOnError ?? false) {
        for (var i = 0; i < subscriptions.length; i++) {
          subscriptions[i].cancel();
        }
        controller.close();
      } else {
        controller.addError(error, stackTrace);
      }
    }

    void onDone_(int index) {
      completedStreams[index] = true;
      if (completedStreams.every((completed) => completed)) {
        controller.close();
      }
    }

    try {
      for (var stream in _streams) {
        var index = subscriptions.length;
        subscriptions.add(stream.listen(
          onData_,
          onError: onError_,
          onDone: () => onDone_(index),
        ));
      }
    } catch (e) {
      for (var i = subscriptions.length - 1; i >= 0; i--) {
        subscriptions[i].cancel();
      }
      rethrow;
    }

    completedStreams = List<bool>.filled(subscriptions.length, false);
    controller = StreamController<T>(
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
