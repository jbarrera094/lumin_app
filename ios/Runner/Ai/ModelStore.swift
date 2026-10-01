import Foundation

/// Keeps the Gemma weights in app storage so only the first launch pays for the download.
///
/// The body lands in a temporary file first and is only moved under its final name once it has been
/// written in full, so the presence of that name is what marks a download as complete.
struct ModelStore {

  func resolveModelFile() async throws -> URL {
    let modelFile = try modelsDirectory().appendingPathComponent(Self.modelFileName)
    if isComplete(modelFile) {
      return modelFile
    }

    let (downloaded, response) = try await URLSession.shared.download(from: Self.modelURL)
    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
    guard status == 200 else {
      try? FileManager.default.removeItem(at: downloaded)
      throw ModelStoreError.downloadFailed(status: status)
    }

    do {
      // Clears the leftovers of an earlier attempt, which `moveItem` would otherwise refuse.
      try? FileManager.default.removeItem(at: modelFile)
      // Both paths live in the app container, so this is a rename rather than a copy.
      try FileManager.default.moveItem(at: downloaded, to: modelFile)
    } catch {
      try? FileManager.default.removeItem(at: downloaded)
      throw error
    }

    return modelFile
  }

  private func modelsDirectory() throws -> URL {
    let fileManager = FileManager.default
    let support = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )

    var directory = support.appendingPathComponent(Self.modelsDirectoryName, isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

    // The weights are several gigabytes and can always be fetched again, so they stay out of
    // backups.
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    try? directory.setResourceValues(resourceValues)

    return directory
  }

  private func isComplete(_ modelFile: URL) -> Bool {
    let size = try? modelFile.resourceValues(forKeys: [.fileSizeKey]).fileSize
    return (size ?? 0) > 0
  }

  private static let modelsDirectoryName = "models"
  private static let modelFileName = "gemma-4-E4B-it.litertlm"
  private static let modelURL = URL(
    string: "https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/"
      + "gemma-4-E4B-it.litertlm"
  )!
}

enum ModelStoreError: LocalizedError {
  case downloadFailed(status: Int)

  var errorDescription: String? {
    switch self {
    case .downloadFailed(let status):
      return "Model download failed with HTTP \(status)."
    }
  }
}
