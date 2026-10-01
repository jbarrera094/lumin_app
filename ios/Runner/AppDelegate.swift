import Flutter
import LiteRTLM
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private let aiEngine = LiteRtLmEngine()
  private let tokens = StreamHandler()

  // The channels stop delivering once they are released, so they outlive `didInitialize`.
  private var methodChannel: FlutterMethodChannel?
  private var tokenChannel: FlutterEventChannel?
  private var generation: Task<Void, Never>?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let tokenChannel = FlutterEventChannel(name: Self.tokenChannelName, binaryMessenger: messenger)
    tokenChannel.setStreamHandler(tokens)
    self.tokenChannel = tokenChannel

    let methodChannel = FlutterMethodChannel(
      name: Self.methodChannelName,
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.onMethodCall(call, result: result)
    }
    self.methodChannel = methodChannel
  }

  private func onMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "loadModel":
      loadModel(result: result)
    case "sendMessage":
      sendMessage(call, result: result)
    case "cancel":
      aiEngine.cancel()
      generation?.cancel()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func loadModel(result: @escaping FlutterResult) {
    Task { @MainActor [aiEngine] in
      do {
        try await aiEngine.load()
        result(nil)
      } catch {
        result(
          FlutterError(code: "load_failed", message: error.localizedDescription, details: nil)
        )
      }
    }
  }

  private func sendMessage(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    let prompt = arguments?["text"] as? String ?? ""
    if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      result(
        FlutterError(
          code: "invalid_argument",
          message: "A non-empty message is required.",
          details: nil
        )
      )
      return
    }

    let resetContext = arguments?["resetContext"] as? Bool ?? false
    let history = (arguments?["history"] as? [[String: Any]] ?? []).compactMap(Self.message(from:))

    // Stops the native decode too, not just the task waiting on it.
    aiEngine.cancel()
    generation?.cancel()
    generation = Task { [aiEngine, tokens] in
      do {
        try await aiEngine.generate(
          prompt: prompt,
          history: history,
          resetContext: resetContext,
          onToken: { text in tokens.token(text) }
        )
        tokens.done()
      } catch is CancellationError {
        // A newer prompt took over, and it owns the reply Dart is showing now.
      } catch {
        tokens.error(error.localizedDescription)
      }
    }
    result(nil)
  }

  private static func message(from entry: [String: Any]) -> Message? {
    guard let text = entry["text"] as? String else { return nil }
    switch entry["role"] as? String {
    case "user":
      return Message(text, role: .user)
    case "model":
      return Message(text, role: .model)
    default:
      return nil
    }
  }

  private static let methodChannelName = "com.lumin.ai/litert_lm"
  private static let tokenChannelName = "com.lumin.ai/litert_lm/tokens"
}
