package com.lumin.ai.lumin_app_v2.ai

import android.content.Context
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * Keeps the Gemma weights in app storage so only the first launch pays for the download.
 *
 * The file is only renamed into its final name once the whole body has been written, so the
 * presence of that name is what marks a download as complete.
 */
class ModelStore(private val context: Context) {

    fun resolveModelFile(): File {
        val modelsDir = File(context.filesDir, MODELS_DIR)
        if (!modelsDir.isDirectory && !modelsDir.mkdirs()) {
            throw IllegalStateException("Could not create the model directory.")
        }

        val modelFile = File(modelsDir, MODEL_FILE_NAME)
        if (modelFile.isFile && modelFile.length() > 0L) {
            return modelFile
        }

        val partial = File(modelsDir, "$MODEL_FILE_NAME.tmp")
        if (partial.exists() && !partial.delete()) {
            throw IllegalStateException("Could not clear the partial model download.")
        }

        try {
            download(URL(MODEL_URL), partial)
            if (!partial.renameTo(modelFile)) {
                throw IllegalStateException("Could not move the downloaded model into place.")
            }
        } catch (error: Throwable) {
            partial.delete()
            throw error
        }

        return modelFile
    }

    private fun download(source: URL, target: File) {
        var url = source
        var redirects = 0

        while (true) {
            val connection = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                // Handled manually so the https redirect to the Hugging Face CDN is followed.
                instanceFollowRedirects = false
            }

            try {
                val status = connection.responseCode
                if (status == HttpURLConnection.HTTP_OK) {
                    connection.inputStream.use { input ->
                        target.outputStream().use(input::copyTo)
                    }
                    return
                }

                if (status !in REDIRECT_RANGE) {
                    throw IllegalStateException("Model download failed with HTTP $status.")
                }

                val location = connection.getHeaderField("Location")
                    ?: throw IllegalStateException("Model download redirect is missing a target.")
                if (++redirects > MAX_REDIRECTS) {
                    throw IllegalStateException("Too many redirects while downloading the model.")
                }
                url = URL(url, location)
            } finally {
                connection.disconnect()
            }
        }
    }

    private companion object {
        const val MODELS_DIR = "models"
        const val MODEL_FILE_NAME = "gemma-4-E4B-it-gpu.litertlm"
        const val MODEL_URL =
            "https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/" +
                "gemma-4-E4B-it-gpu.litertlm"
        const val CONNECT_TIMEOUT_MS = 30_000
        const val READ_TIMEOUT_MS = 60_000
        const val MAX_REDIRECTS = 5
        val REDIRECT_RANGE = 300..399
    }
}
