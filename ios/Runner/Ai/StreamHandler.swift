import Flutter
import Foundation

/// Forwards decoded tokens to Dart. Events are posted to the main thread, as the sink requires.
final class StreamHandler: NSObject, FlutterStreamHandler, @unchecked Sendable {

  private var sink: FlutterEventSink?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func token(_ text: String) {
    send(["type": "token", "text": text])
  }

  func done() {
    send(["type": "done"])
  }

  func error(_ message: String) {
    send(["type": "error", "message": message])
  }

  private func send(_ event: [String: Any]) {
    DispatchQueue.main.async { self.sink?(event) }
  }
}
