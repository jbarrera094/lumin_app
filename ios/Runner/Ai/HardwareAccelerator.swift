import Foundation
import LiteRTLM

/// Builds the engine configuration for the GPU (ML Drift / Metal) backend.
enum HardwareAccelerator {

  static func engineConfig(modelFile: URL) throws -> EngineConfig {
    try EngineConfig(
      modelPath: modelFile.path,
      backend: backend,
      // Compiled GPU artifacts are kept here, which shortens every load after the first.
      cacheDir: NSTemporaryDirectory()
    )
  }

  private static var backend: Backend {
    #if targetEnvironment(simulator)
      // Metal on the simulator cannot run the model, so the simulator falls back to the CPU.
      return .cpu()
    #else
      return .gpu
    #endif
  }
}
