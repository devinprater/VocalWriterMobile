import XCTest
@testable import VocalWriterMobile

final class VocalWriterMobileTests: XCTestCase {
    func testPitchNames() {
        XCTAssertEqual(SongNote(lyric: "ah", pitch: 60, beats: 1).pitchName, "C 4")
        XCTAssertEqual(SongNote(lyric: "ah", pitch: 70, beats: 1).pitchName, "B flat 4")
    }

    func testDurationStepping() {
        XCTAssertEqual(NoteStep.adjacentDuration(to: 1, direction: 1), 1.5)
        XCTAssertEqual(NoteStep.adjacentDuration(to: 1, direction: -1), 0.75)
        XCTAssertEqual(NoteStep.adjacentDuration(to: 4, direction: 1), 4)
    }

    @MainActor
    func testEngineRendersWaveFile() throws {
        let studio = StudioModel()
        let url = try studio.renderPreviewForTesting()
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? NSNumber
        XCTAssertGreaterThan(size?.intValue ?? 0, 44)
    }
}
