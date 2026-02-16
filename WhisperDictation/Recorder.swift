import AVFoundation
import Foundation

/// Records 16 kHz mono audio to a WAV file and detects silence (level-based).
final class Recorder {
    private let engine = AVAudioEngine()
    private let silenceDurationSec: Int
    private var outputURL: URL?
    private var fileHandle: FileHandle?
    private var totalSamples: Int = 0
    private var silentSamples: Int = 0
    private let sampleRate: Double = 16000
    private let silenceThreshold: Float = 0.01  // level below this = silent

    var onSilenceDetected: (() -> Void)?

    init(silenceDurationSec: Int = 8) {
        self.silenceDurationSec = silenceDurationSec
    }

    func startRecording(to path: String) throws {
        try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: path)
        outputURL = url
        totalSamples = 0
        silentSamples = 0

        let input = engine.inputNode
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let inputFormat = input.inputFormat(forBus: 0)
        // Install tap before start() so initial buffers are not missed (Apple docs).
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer, inputFormat: inputFormat, outputFormat: format)
        }
        try engine.start()

        // Write WAV header (placeholder; we'll rewrite on stop)
        let header = Self.wavHeader(sampleCount: 0, sampleRate: UInt32(sampleRate))
        try header.write(to: url)
        fileHandle = try FileHandle(forWritingTo: url)
        try fileHandle?.seek(toOffset: UInt64(header.count))
    }

    func stopRecording() throws -> String? {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        guard let url = outputURL, let handle = fileHandle else { return nil }
        try handle.close()
        fileHandle = nil
        outputURL = nil

        // Rewrite WAV header with correct size
        let data = try Data(contentsOf: url)
        let header = Self.wavHeader(sampleCount: totalSamples, sampleRate: UInt32(sampleRate))
        let body = data.dropFirst(44)
        try (header + body).write(to: url)
        return url.path
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0, let handle = fileHandle else { return }
        let inputRate = inputFormat.sampleRate
        let ratio = inputRate / sampleRate
        var level: Float = 0
        var outData = [Int16]()

        if let channelData = buffer.floatChannelData?[0] {
            var sum: Float = 0
            for i in 0..<frameLength { sum += abs(channelData[i]) }
            level = sum / Float(frameLength)
            for i in stride(from: 0, to: frameLength, by: max(1, Int(ratio))) {
                let s = channelData[i]
                outData.append(Int16(max(-32768, min(32767, s * 32767))))
            }
        } else if let channelData = buffer.int16ChannelData?[0] {
            var sum: Float = 0
            for i in 0..<frameLength { sum += Float(abs(channelData[i])) / 32768 }
            level = sum / Float(frameLength)
            for i in stride(from: 0, to: frameLength, by: max(1, Int(ratio))) {
                outData.append(channelData[i])
            }
        }

        if !outData.isEmpty {
            outData.withUnsafeBytes { try? handle.write(contentsOf: $0) }
        }
        totalSamples += outData.count

        if level < silenceThreshold {
            silentSamples += outData.count
            let silentSec = Double(silentSamples) / sampleRate
            if Double(silenceDurationSec) <= silentSec {
                onSilenceDetected?()
                onSilenceDetected = nil
            }
        } else {
            silentSamples = 0
        }
    }

    private static func wavHeader(sampleCount: Int, sampleRate: UInt32) -> Data {
        let byteRate = sampleRate * 2
        let dataSize = sampleCount * 2
        var header = Data()
        header.append(contentsOf: [0x52, 0x49, 0x46, 0x46])  // RIFF
        header.append(contentsOf: withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { [UInt8]($0) })
        header.append(contentsOf: [0x57, 0x41, 0x56, 0x45])  // WAVE
        header.append(contentsOf: [0x66, 0x6d, 0x74, 0x20])  // fmt
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { [UInt8]($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { [UInt8]($0) })   // PCM
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { [UInt8]($0) })   // mono
        header.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { [UInt8]($0) })
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { [UInt8]($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { [UInt8]($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { [UInt8]($0) })
        header.append(contentsOf: [0x64, 0x61, 0x74, 0x61])  // data
        header.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { [UInt8]($0) })
        return header
    }
}
