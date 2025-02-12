# Refactor VideoService – Video Processing Issue Fix Plan

This document outlines the precise code changes needed to resolve the following issues in the video processing module:
- Invalid frame dimensions (negative or non-finite values)
- Export session failures due to format/orientation/transform mismatches
- Orientation/transform handling errors
- Format compatibility problems

---

## 1. Define a Robust VideoFormat Helper

Create a new struct named `VideoFormat` that loads format properties from an AVAssetTrack and computes the correct output dimensions by applying the track’s preferred transform. This avoids negative or non-finite values. For example:

```swift
private struct VideoFormat {
    let codec: String
    let dimensions: CGSize
    let frameRate: Float

    init?(track: AVAssetTrack) {
        // Load format descriptions synchronously.
        let formatDescriptions = try? track.load(.formatDescriptions)
        guard let formatDescription = formatDescriptions?.first else { return nil }
        
        let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
        self.codec = String(format: "%c%c%c%c",
                            (mediaSubType >> 24) & 0xff,
                            (mediaSubType >> 16) & 0xff,
                            (mediaSubType >> 8) & 0xff,
                            mediaSubType & 0xff)
        
        // Get the natural size and validate it.
        guard let naturalSize = try? track.load(.naturalSize),
              naturalSize.width > 0, naturalSize.width.isFinite,
              naturalSize.height > 0, naturalSize.height.isFinite else {
            return nil
        }
        
        // Apply preferred transform if available; otherwise use identity.
        let transform = (try? track.load(.preferredTransform)) ?? .identity
        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        self.dimensions = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))
        
        // Load nominal frame rate with a fallback.
        self.frameRate = (try? track.load(.nominalFrameRate)) ?? 30.0
    }
    
    var description: String {
        return "\(codec) \(Int(dimensions.width))x\(Int(dimensions.height))@\(Int(frameRate))fps"
    }
}
```

---

## 2. Refactor createExportSession

Replace dynamic preset selection and asynchronous calls with a synchronous approach. Remove use of unsupported properties (like `supportedOutputPresetNames` or modifying read-only `presetName`) and log the export session configuration:

```swift
private func createExportSession(for composition: AVComposition, videoComposition: AVVideoComposition? = nil) throws -> AVAssetExportSession {
    print("🎥 Creating export session...")
    
    // Log the source video format.
    let videoTracks = composition.tracks(withMediaType: .video)
    if let track = videoTracks.first,
       let format = VideoFormat(track: track) {
        print("🎬 Source format: \(format.description)")
    }
    
    guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
        throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
    }
    
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
    print("📍 Output URL: \(outputURL.path)")
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true
    
    if let videoComposition = videoComposition {
        let size = videoComposition.renderSize
        print("🎬 Output size: \(Int(size.width))x\(Int(size.height))")
        exportSession.videoComposition = videoComposition
    }
    
    let supportedTypes = exportSession.supportedFileTypes.map { $0.rawValue }.joined(separator: ", ")
    print("📼 Supported types: \(supportedTypes)")
    
    return exportSession
}
```

---

## 3. Update Stitching and Preview Methods

In the stitching function (e.g. `stitchClips`), perform these steps:

- **Validation:** Iterate through all clips (using synchronous calls like `try track.load(...)`) and use `VideoFormat(track:)` to determine a proper naturalSize.
  
- **Composition:** For each clip, insert its video and audio tracks into an AVMutableComposition at the correct timeline (using a timeCursor). For each clip, create an `AVMutableVideoCompositionInstruction` with a layer instruction that applies the appropriate transform. For example:

  ```pseudo
  for clip in clips {
      let asset = AVAsset(url: clip.sourceURL)
      let videoTrack = asset.loadTracks(withMediaType: .video).first!
      let naturalSize = computed from first clip's VideoFormat
      
      let timeRange = CMTimeRange(start: clip.startTime, duration: clip.duration)
      try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: timeCursor)
      
      // Calculate scaling factor:
      let trackSize = try track.load(.naturalSize)
      let transform = try track.load(.preferredTransform)
      let scale = min(naturalSize.width / trackSize.width, naturalSize.height / trackSize.height)
      let scaledTransform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
      
      let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
      layerInstruction.setTransform(scaledTransform, at: timeCursor)
      
      // Create and append instruction:
      let instruction = AVMutableVideoCompositionInstruction()
      instruction.timeRange = CMTimeRange(start: timeCursor, duration: clip.duration)
      instruction.layerInstructions = [layerInstruction]
      instructions.append(instruction)
      
      timeCursor = timeCursor + clip.duration
  }
  ```
  
- **Export and Preview:** After building the composition and video composition, create the export session with the new helper and call the export function. Log each step. Remove special-casing for single-clip processing so all clips follow the uniform pipeline.

Also in preview update (e.g., in `updateStitchedPreview`), ensure that any errors with invalid frame dimensions are caught and logged.

---

## 4. Restore renderClip Function

Bring back the `renderClip` function as follows (pseudocode):

```swift
public func renderClip(_ clip: VideoClip) async throws -> URL {
    print("🎥 Starting to render clip from URL: \(clip.sourceURL)")
    // Log file type info:
    print("🎬 Source video type: \(getVideoFileType(clip.sourceURL))")
    
    let asset = AVAsset(url: clip.sourceURL)
    let composition = AVMutableComposition()
    guard let videoTrack = asset.loadTracks(withMediaType: .video).first,
          let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
    }
    let timeRange = CMTimeRange(start: clip.startTime, duration: clip.duration)
    try compVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
    
    // Optionally insert audio
    if let audioTrack = asset.loadTracks(withMediaType: .audio).first,
       let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
        try compAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
    }
    
    // Configure a video composition if a filter is applied (similar to earlier)
    // ...
    
    let exportSession = try createExportSession(for: composition, videoComposition: videoComposition)
    return try await export(using: exportSession)
}
```

---

## 5. Replace Deprecated API Calls

Ensure that all uses of `tracks(withMediaType:)` are replaced with the asynchronous `loadTracks(withMediaType:)` only where safe, or use synchronous loading if already loaded. Remove async calls from synchronous contexts by using the synchronous `try!` (or graceful error handling). For example:

- Replace usages of `track.preferredTransform` with `(try? track.load(.preferredTransform)) ?? .identity`
- Replace usages of `track.formatDescriptions` with `try? track.load(.formatDescriptions)`

---

## 6. Add Debug Logging

Insert logging statements at the following key points:
- When computing video dimensions and applying preferredTransform.
- When creating an export session (log output URL, supported file types).
- When inserting each clip into the composition (log time ranges and transforms).
- When completing the export (log export session status and any errors).

---

## Summary of Implementation Plan

- **Create a robust VideoFormat struct** using synchronous loading (avoid async calls in synchronous functions).
- **Refactor createExportSession** to set fixed export settings, logging codec information.
- **Update stitching and renderClip functions** to use proper synchronous APIs and compute transforms correctly.
- **Replace deprecated API calls** by using `try? track.load(...)` for properties.
- **Embed detailed debug logging** to trace computed dimensions, transforms, and export session details.

This plan instructs the editor engineer to modify only the affected portions of VideoService.swift and VideoStoryboardEditor.swift. Follow the pseudocode snippets to update the real code and validate that the output video has valid frame dimensions and proper orientation.
