package com.lumin.ai.lumin_app_v2.ai

import android.content.Context
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.SamplerConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/** Runs Gemma on device through LiteRT-LM and streams the decoded text back token by token. */
class LiteRtLmEngine(private val context: Context) {

    private val modelStore = ModelStore(context)
    private val lock = Mutex()

    @Volatile
    private var engine: Engine? = null

    @Volatile
    private var conversation: Conversation? = null

    /**
     * Downloads the weights if needed and initializes the engine. Both steps are slow enough that
     * this must stay off the main thread.
     */
    suspend fun load() = withContext(Dispatchers.IO) {
        lock.withLock {
            if (conversation != null) return@withLock
            releaseLocked()

            val modelFile = modelStore.resolveModelFile()
            val created = Engine(HardwareAccelerator.engineConfig(context, modelFile))
            try {
                created.initialize()
                conversation = created.createConversation(conversationConfig(emptyList()))
                engine = created
            } catch (error: Throwable) {
                runCatching { created.close() }
                throw error
            }
        }
    }

    /**
     * Streams a reply to [prompt].
     *
     * The native conversation holds its own KV cache, so the usual turn only sends the new prompt.
     * When [resetContext] is set, the conversation is rebuilt from [history] instead, which is how
     * the caller enforces its context window.
     */
    suspend fun generate(
        prompt: String,
        history: List<Message>,
        resetContext: Boolean,
        onToken: (String) -> Unit,
    ) = withContext(Dispatchers.IO) {
        val active = lock.withLock {
            val loaded = engine ?: throw IllegalStateException("The model is not loaded.")
            if (resetContext) {
                conversation?.let { previous -> runCatching { previous.close() } }
                conversation = loaded.createConversation(conversationConfig(history))
            }
            conversation ?: throw IllegalStateException("The model is not loaded.")
        }

        active.sendMessageAsync(Message.user(prompt)).collect { chunk ->
            val text = chunk.toString()
            if (text.isNotEmpty()) {
                onToken(text)
            }
        }
    }

    /** Stops the current decode. Harmless when nothing is running. */
    fun cancel() {
        val active = conversation ?: return
        runCatching { active.cancelProcess() }
    }

    suspend fun release() = withContext(Dispatchers.IO) {
        lock.withLock { releaseLocked() }
    }

    private fun releaseLocked() {
        conversation?.let { active -> runCatching { active.close() } }
        conversation = null
        engine?.let { active -> runCatching { active.close() } }
        engine = null
    }

    private fun conversationConfig(history: List<Message>) = ConversationConfig(
        systemInstruction = Contents.of(SYSTEM_INSTRUCTION),
        initialMessages = history,
        samplerConfig = SamplerConfig(topK = 40, topP = 0.95, temperature = 0.8),
    )

    private companion object {
        const val SYSTEM_INSTRUCTION =
            "You are Lumin, a concise and friendly assistant. Reply with plain text only."
    }
}
