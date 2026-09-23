import SwiftUI

struct StudioTabView: View {
    @EnvironmentObject private var studio: StudioModel

    var body: some View {
        TabView {
            NavigationStack { SongView() }
                .tabItem { Label("Song", systemImage: "music.note.list") }
            NavigationStack { TracksView() }
                .tabItem { Label("Tracks", systemImage: "square.stack.3d.up") }
            NavigationStack { NotesView() }
                .tabItem { Label("Notes", systemImage: "list.number") }
            NavigationStack { PlayerView() }
                .tabItem { Label("Player", systemImage: "play.circle") }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)) { _ in }
        .accessibilityAction(.magicTap) { studio.togglePlayback() }
    }
}

struct SongView: View {
    @EnvironmentObject private var studio: StudioModel

    var body: some View {
        Form {
            Section("Song") {
                TextField("Title", text: $studio.song.title)
                Stepper("Tempo, \(studio.song.tempo) beats per minute", value: $studio.song.tempo, in: 30...250)
                Picker("Time signature", selection: $studio.song.beatsPerBar) {
                    Text("3/4").tag(3)
                    Text("4/4").tag(4)
                    Text("6/4").tag(6)
                }
            }
            Section("Summary") {
                LabeledContent("Tracks", value: studio.song.tracks.count.formatted())
                LabeledContent("Notes", value: studio.song.tracks.reduce(0) { $0 + $1.notes.count }.formatted())
            }
            Section {
                Text("This experimental build includes legacy VocalWriter resources for personal sideloading only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Song")
    }
}

struct TracksView: View {
    @EnvironmentObject private var studio: StudioModel

    var body: some View {
        List(studio.song.tracks) { track in
            Button {
                studio.selectTrack(track)
            } label: {
                VStack(alignment: .leading) {
                    Text(track.name).font(.headline)
                    Text("Voice \(track.voice + 1), \(track.notes.count) notes")
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("\(track.name), voice \(track.voice + 1), \(track.notes.count) notes")
            .accessibilityValue(track.id == studio.selectedTrackID ? "Selected" : "")
            .accessibilityAction(named: "Select") { studio.selectTrack(track) }
            .accessibilityAction(named: track.isMuted ? "Unmute" : "Mute") { toggleMute(track.id) }
            .accessibilityAction(named: track.isSolo ? "Unsolo" : "Solo") { toggleSolo(track.id) }
        }
        .navigationTitle("Tracks")
    }

    private func toggleMute(_ id: UUID) {
        guard let index = studio.song.tracks.firstIndex(where: { $0.id == id }) else { return }
        studio.song.tracks[index].isMuted.toggle()
    }

    private func toggleSolo(_ id: UUID) {
        guard let index = studio.song.tracks.firstIndex(where: { $0.id == id }) else { return }
        studio.song.tracks[index].isSolo.toggle()
    }
}

struct NotesView: View {
    @EnvironmentObject private var studio: StudioModel
    @State private var editingNote: SongNote?

    var body: some View {
        List {
            if let track = studio.selectedTrack {
                Section {
                    ForEach(Array(track.notes.enumerated()), id: \.element.id) { index, note in
                        NoteRow(note: note, index: index, beatsPerBar: studio.song.beatsPerBar) {
                            editingNote = note
                            studio.selectedNoteID = note.id
                        }
                    }
                } header: {
                    Text("\(track.name), \(track.notes.count) notes")
                }
            } else {
                ContentUnavailableView("No Track Selected", systemImage: "music.note")
            }
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Note", systemImage: "plus") { studio.addNote() }
            }
            ToolbarItem(placement: .bottomBar) {
                Button(studio.isPlaying ? "Stop" : "Play", systemImage: studio.isPlaying ? "stop.fill" : "play.fill") {
                    studio.togglePlayback()
                }
                .disabled(studio.isRendering)
            }
        }
        .sheet(item: $editingNote) { note in
            NoteEditorView(note: note)
        }
    }
}

private struct NoteRow: View {
    @EnvironmentObject private var studio: StudioModel
    let note: SongNote
    let index: Int
    let beatsPerBar: Int
    let edit: () -> Void

    var body: some View {
        Button(action: edit) {
            HStack {
                VStack(alignment: .leading) {
                    Text(note.lyric.isEmpty ? "Ah" : note.lyric).font(.headline)
                    Text("\(position), \(note.pitchName), \(note.durationName)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if note.id == studio.selectedNoteID {
                    Image(systemName: "cursorarrow")
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityLabel("\(position), \(note.lyric.isEmpty ? "Ah" : note.lyric), \(note.pitchName), \(note.durationName)")
        .accessibilityHint("Double tap to edit")
        .accessibilityAddTraits(note.id == studio.selectedNoteID ? .isSelected : [])
        .accessibilityAction(named: "Preview from here") { studio.selectedNoteID = note.id; studio.renderAndPlay() }
        .accessibilityAction(named: "Transpose up") { studio.transpose(note.id, semitones: 1) }
        .accessibilityAction(named: "Transpose down") { studio.transpose(note.id, semitones: -1) }
        .accessibilityAction(named: "Lengthen") { studio.resize(note.id, direction: 1) }
        .accessibilityAction(named: "Shorten") { studio.resize(note.id, direction: -1) }
        .accessibilityAction(named: "Move earlier") { studio.move(note.id, direction: -1) }
        .accessibilityAction(named: "Move later") { studio.move(note.id, direction: 1) }
        .accessibilityAction(named: "Delete") { studio.removeNote(note.id) }
        .accessibilityAdjustableAction { direction in
            studio.transpose(note.id, semitones: direction == .increment ? 1 : -1)
        }
    }

    private var position: String {
        let preceding = studio.selectedTrack?.notes.prefix(index).reduce(0.0) { $0 + $1.beats } ?? 0
        let bar = Int(preceding) / beatsPerBar + 1
        let beat = preceding.truncatingRemainder(dividingBy: Double(beatsPerBar)) + 1
        return "Bar \(bar), beat \(beat.formatted())"
    }
}

struct NoteEditorView: View {
    @EnvironmentObject private var studio: StudioModel
    @Environment(\.dismiss) private var dismiss
    @State var note: SongNote

    var body: some View {
        NavigationStack {
            Form {
                Section("Syllable") {
                    TextField("Word or syllable", text: $note.lyric)
                        .textInputAutocapitalization(.never)
                    Button("Preview Note", systemImage: "speaker.wave.2") {
                        studio.updateNote(note)
                        studio.renderAndPlay()
                    }
                }
                Section("Pitch") {
                    Stepper("\(note.pitchName), MIDI \(note.pitch)", value: $note.pitch, in: 0...127)
                    Button("Down One Octave") { note.pitch = max(0, note.pitch - 12) }
                    Button("Up One Octave") { note.pitch = min(127, note.pitch + 12) }
                }
                Section("Timing") {
                    Picker("Duration", selection: $note.beats) {
                        ForEach(NoteStep.durations, id: \.self) { beats in
                            Text(SongNote(lyric: "", pitch: 60, beats: beats).durationName).tag(beats)
                        }
                    }
                    Stepper("Velocity, \(note.velocity)", value: $note.velocity, in: 1...127)
                }
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { studio.updateNote(note); dismiss() }
                }
            }
        }
    }
}

struct PlayerView: View {
    @EnvironmentObject private var studio: StudioModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: studio.isPlaying ? "waveform.circle.fill" : "waveform.circle")
                .font(.system(size: 80))
                .accessibilityHidden(true)
            Text(studio.status)
                .font(.title2)
                .accessibilityLabel("Playback status, \(studio.status)")
            Button("Play Selected Track", systemImage: "play.fill") { studio.renderAndPlay() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(studio.isRendering || studio.isPlaying)
            Button("Stop", systemImage: "stop.fill") { studio.stop() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!studio.isPlaying)
            Text("Two-finger double-tap anywhere to play or stop.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Player")
    }
}

