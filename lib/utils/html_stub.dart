// lib/src/html_stub.dart

import 'dart:async';

dynamic document;

class IFrameElement {
  IFrameElement();
  String? id;
  String? src;
  final Style style = Style();

  Stream<Event> get onLoad => _DummyStream<Event>();

  final ContentWindow contentWindow = ContentWindow();
}

class Event {}

class _DummyStream<T> extends Stream<T> {
  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _DummyStreamSubscription<T>();
  }
}

class _DummyStreamSubscription<T> implements StreamSubscription<T> {
  @override
  Future<void> cancel() => Future.value();

  @override
  void onData(void Function(T data)? handleData) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void onError(Function? handleError) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  bool get isPaused => false;

  @override
  Future<E> asFuture<E>([E? futureValue]) => Future.value(futureValue);
}

class Style {
  String? border;
  String? width;
  String? height;
}

class ContentWindow {
  void postMessage(Object? message, String targetOrigin) {}
}

class MessageEvent {
  final dynamic data;
  MessageEvent(this.data);
}

class Window {
  Stream<MessageEvent> get onMessage => _DummyStream<MessageEvent>();

  dynamic open(String url, String name, [String? options]) {
    return null;
  }
}

final Window window = Window();
