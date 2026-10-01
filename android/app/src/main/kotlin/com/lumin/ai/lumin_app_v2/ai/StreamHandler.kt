package com.lumin.ai.lumin_app_v2.ai

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/** Forwards decoded tokens to Dart. Events are posted to the main thread, as the sink requires. */
class StreamHandler : EventChannel.StreamHandler {

    private val mainThread = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun token(text: String) = send(mapOf("type" to "token", "text" to text))

    fun done() = send(mapOf("type" to "done"))

    fun error(message: String) = send(mapOf("type" to "error", "message" to message))

    private fun send(event: Map<String, Any?>) {
        mainThread.post { sink?.success(event) }
    }
}
