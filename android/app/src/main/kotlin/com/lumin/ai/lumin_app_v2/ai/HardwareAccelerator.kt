package com.lumin.ai.lumin_app_v2.ai

import android.content.Context
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.EngineConfig
import java.io.File

/** Builds the engine configuration for the GPU (ML Drift / OpenCL) backend. */
object HardwareAccelerator {

    fun engineConfig(context: Context, modelFile: File) = EngineConfig(
        modelPath = modelFile.absolutePath,
        backend = Backend.GPU(),
        // Compiled GPU artifacts are kept here, which shortens every load after the first.
        cacheDir = context.cacheDir.absolutePath,
    )
}
