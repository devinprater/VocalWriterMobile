import AVFAudio
import Foundation
import UIKit

@MainActor
final class StudioModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var song = StudioSong()
    @Published var selectedTrackID: UUID?
    @Published var selectedNoteID: UUID?
    @Published var isRendering = false
    @Published var isPlaying = false
    @Published var status = "Ready"

    private var engine: EngineHandle?
    private var player: AVAudioPlayer?

    override init() {
        super.init()
        selectedTrackID = song.tracks.first?.id
        selectedNoteID = song.tracks.first?.notes.first?.id
        openEngine()
    }

    var selectedTrackIndex: Int? {
        guard let selectedTrackID else { return nil }
        return song.tracks.firstIndex { $0.id == selectedTrackID }
    }

    var selectedTrack: VocalTrack? {
        guard let index = selectedTrackIndex else { return nil }
        return song.tracks[index]
    }

    func selectTrack(_ track: VocalTrack) {
        selectedTrackID = track.id
        selectedNoteID = track.notes.first?.id
        announce("Selected \(track.name), \(track.notes.count) notes")
    }

    func addNote() {
        guard let trackIndex = selectedTrackIndex else { return }
        let note = SongNote(lyric: "ah", pitch: 60, beats: 1)
        song.tracks[trackIndex].notes.append(note)
        selectedNoteID = note.id
        announce("Note added, C 4, quarter note")
    }

    func updateNote(_ note: SongNote) {
        guard let trackIndex = selectedTrackIndex,
              let noteIndex = song.tracks[trackIndex].notes.firstIndex(where: { $0.id == note.id }) else { return }
        song.tracks[trackIndex].notes[noteIndex] = note
    }

    func removeNote(_ id: UUID) {
        guard let trackIndex = selectedTrackIndex,
              let noteIndex = song.tracks[trackIndex].notes.firstIndex(where: { $0.id == id }) else { return }
        song.tracks[trackIndex].notes.remove(at: noteIndex)
        let notes = song.tracks[trackIndex].notes
        selectedNoteID = notes.indices.contains(noteIndex) ? notes[noteIndex].id : notes.last?.id
        announce("Note deleted")
    }

    func transpose(_ id: UUID, semitones: Int) {
        mutateNote(id) { $0.pitch = min(max($0.pitch + semitones, 0), 127) }
        if let note = note(id) { announce("Transposed to \(note.pitchName)") }
    }

    func resize(_ id: UUID, direction: Int) {
        mutateNote(id) { $0.beats = NoteStep.adjacentDuration(to: $0.beats, direction: direction) }
        if let note = note(id) { announce("Length \(note.durationName)") }
    }

    func move(_ id: UUID, direction: Int) {
        guard let trackIndex = selectedTrackIndex,
              let index = song.tracks[trackIndex].notes.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + direction
        guard song.tracks[trackIndex].notes.indices.contains(destination) else { return }
        song.tracks[trackIndex].notes.swapAt(index, destination)
        selectedNoteID = id
        announce("Moved to position \(destination + 1)")
    }

    func note(_ id: UUID) -> SongNote? {
        selectedTrack?.notes.first { $0.id == id }
    }

    func renderAndPlay() {
        guard !isRendering else { return }
        guard let engine, let track = selectedTrack, !track.notes.isEmpty else {
            announce("Nothing to play")
            return
        }
        stop()
        isRendering = true
        status = "Rendering"

        let song = song
        Task.detached(priority: .userInitiated) {
            let result = Self.render(song: song, track: track, engine: engine)
            await MainActor.run {
                self.isRendering = false
                switch result {
                case .success(let url): self.play(url)
                case .failure(let error):
                    self.status = error.localizedDescription
                    self.announce("Render failed. \(error.localizedDescription)")
                }
            }
        }
    }

    func stop() {
        player?.stop()
        isPlaying = false
        status = "Stopped"
    }

    func togglePlayback() {
        if isPlaying { stop() } else { renderAndPlay() }
    }

    func renderPreviewForTesting() throws -> URL {
        guard let engine, let track = selectedTrack else {
            throw RenderError.engineUnavailable
        }
        switch Self.render(song: song, track: track, engine: engine) {
        case .success(let url): return url
        case .failure(let error): throw error
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        status = flag ? "Playback finished" : "Playback stopped"
        announce(status)
    }

    private func mutateNote(_ id: UUID, change: (inout SongNote) -> Void) {
        guard let trackIndex = selectedTrackIndex,
              let noteIndex = song.tracks[trackIndex].notes.firstIndex(where: { $0.id == id }) else { return }
        change(&song.tracks[trackIndex].notes[noteIndex])
        selectedNoteID = id
    }

    private func openEngine() {
        let names = ["VocalWriter", "GMSpeech", "GMBank", "EnglishLex"]
        let extensions = ["dat", "dat", "dat", "dat"]
        let urls = zip(names, extensions).map { Bundle.main.url(forResource: $0.0, withExtension: $0.1) }
        guard urls.allSatisfy({ $0 != nil }) else {
            status = "Engine resources are missing"
            return
        }
        let pointer = urls[0]!.path.withCString { resource in
            urls[1]!.path.withCString { voices in
                urls[2]!.path.withCString { bank in
                    urls[3]!.path.withCString { lexicon in
                        vw_mobile_open(resource, voices, bank, lexicon)
                    }
                }
            }
        }
        guard let pointer else {
            status = "The VocalWriter engine could not be created"
            return
        }
        engine = EngineHandle(pointer)
        if let error = vw_mobile_error(pointer), error.pointee != 0 {
            status = String(cString: error)
        }
    }

    nonisolated private static func render(song: StudioSong, track: VocalTrack, engine: EngineHandle) -> Result<URL, Error> {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vocalwriter-preview.wav")
        let lyrics = track.notes.map { strdup($0.lyric) }
        defer { lyrics.forEach { free($0) } }
        var starts = 0.0
        var notes: [VWMobileNote] = zip(track.notes, lyrics).map { note, lyric in
            defer { starts += note.beats }
            return VWMobileNote(
                start_beats: starts,
                duration_beats: note.beats,
                midi_pitch: Int32(note.pitch),
                velocity: Int32(note.velocity),
                lyric: UnsafePointer(lyric)
            )
        }
        let code = url.path.withCString { output in
            vw_mobile_render(engine.pointer, &notes, Int32(notes.count), Int32(song.tempo), Int32(track.voice), output)
        }
        guard code == 0 else {
            let message = vw_mobile_error(engine.pointer).map { String(cString: $0) } ?? "Unknown engine error"
            return .failure(RenderError.failed(message))
        }
        return .success(url)
    }

    private func play(_ url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
            status = "Playing \(selectedTrack?.name ?? "track")"
            announce(status)
        } catch {
            status = error.localizedDescription
            announce("Playback failed. \(error.localizedDescription)")
        }
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

private final class EngineHandle: @unchecked Sendable {
    let pointer: OpaquePointer

    init(_ pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        vw_mobile_close(pointer)
    }
}

private enum RenderError: LocalizedError {
    case engineUnavailable
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .engineUnavailable: "The VocalWriter engine is unavailable."
        case .failed(let message): message
        }
    }
}
