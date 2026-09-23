import Foundation

struct SongNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var lyric: String
    var pitch: Int
    var beats: Double
    var velocity: Int = 100

    var pitchName: String {
        let names = ["C", "C sharp", "D", "E flat", "E", "F", "F sharp", "G", "A flat", "A", "B flat", "B"]
        return "\(names[(pitch % 12 + 12) % 12]) \(pitch / 12 - 1)"
    }

    var durationName: String {
        switch beats {
        case 0.25: "sixteenth note"
        case 0.5: "eighth note"
        case 0.75: "dotted eighth note"
        case 1: "quarter note"
        case 1.5: "dotted quarter note"
        case 2: "half note"
        case 3: "dotted half note"
        case 4: "whole note"
        default: "\(beats.formatted()) beats"
        }
    }
}

struct VocalTrack: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var voice: Int
    var volume: Int = 100
    var pan: Int = 0
    var isMuted = false
    var isSolo = false
    var notes: [SongNote]
}

struct StudioSong: Codable, Equatable {
    var title = "Daisy Bell Experiment"
    var tempo = 80
    var beatsPerBar = 4
    var tracks: [VocalTrack] = [
        VocalTrack(
            name: "Lead Vocal",
            voice: 0,
            notes: [
                SongNote(lyric: "Dai-", pitch: 69, beats: 1.5),
                SongNote(lyric: "sy", pitch: 65, beats: 1.5),
                SongNote(lyric: "dai-", pitch: 62, beats: 1.5),
                SongNote(lyric: "sy", pitch: 57, beats: 1.5),
                SongNote(lyric: "give", pitch: 64, beats: 0.75),
                SongNote(lyric: "me", pitch: 65, beats: 0.75),
                SongNote(lyric: "your", pitch: 67, beats: 0.75),
                SongNote(lyric: "an-", pitch: 64, beats: 0.75),
                SongNote(lyric: "swer", pitch: 62, beats: 1)
            ]
        )
    ]
}

enum NoteStep {
    static let durations = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4]

    static func adjacentDuration(to duration: Double, direction: Int) -> Double {
        let closest = durations.enumerated().min { abs($0.element - duration) < abs($1.element - duration) }?.offset ?? 3
        return durations[min(max(closest + direction, 0), durations.count - 1)]
    }
}

