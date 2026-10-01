package com.lumin.ai.lumin_app_v2

import com.google.ai.edge.litertlm.Message
import com.lumin.ai.lumin_app_v2.ai.LiteRtLmEngine
import com.lumin.ai.lumin_app_v2.ai.StreamHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val tokens = StreamHandler()

    private lateinit var aiEngine: LiteRtLmEngine
    private var generation: Job? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        aiEngine = LiteRtLmEngine(applicationContext)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger, TOKEN_CHANNEL).setStreamHandler(tokens)
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> loadModel(result)
            "sendMessage" -> sendMessage(call, result)
            "cancel" -> {
                aiEngine.cancel()
                generation?.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun loadModel(result: MethodChannel.Result) {
        scope.launch {
            try {
                aiEngine.load()
                result.success(null)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                result.error("load_failed", error.message, null)
            }
        }
    }

    private fun sendMessage(call: MethodCall, result: MethodChannel.Result) {
        val prompt = call.argument<String>("text")
        if (prompt.isNullOrBlank()) {
            result.error("invalid_argument", "A non-empty message is required.", null)
            return
        }
        val resetContext = call.argument<Boolean>("resetContext") ?: false
        val history = call.argument<List<Map<String, Any?>>>("history")
            .orEmpty()
            .mapNotNull(::toMessage)

        // Stops the native decode too, not just the coroutine waiting on it.
        aiEngine.cancel()
        generation?.cancel()
        generation = scope.launch {
            try {
                aiEngine.generate(prompt, history, resetContext, tokens::token)
                tokens.done()
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                tokens.error(error.message ?: "Generation failed.")
            }
        }
        result.success(null)
    }

    private fun toMessage(entry: Map<String, Any?>): Message? {
        val text = entry["text"] as? String ?: return null
        return when (entry["role"] as? String) {
            "user" -> Message.user(text)
            "model" -> Message.model(text)
            else -> null
        }
    }

    override fun onDestroy() {
        generation?.cancel()
        if (::aiEngine.isInitialized) {
            val engine = aiEngine
            engine.cancel()
            // Runs off the activity scope so the handles are still released after cancellation.
            CoroutineScope(Dispatchers.IO).launch { engine.release() }
        }
        scope.cancel()
        super.onDestroy()
    }

    private companion object {
        const val METHOD_CHANNEL = "com.lumin.ai/litert_lm"
        const val TOKEN_CHANNEL = "com.lumin.ai/litert_lm/tokens"
    }
}
