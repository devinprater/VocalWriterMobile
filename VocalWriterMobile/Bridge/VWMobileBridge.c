#include "VWMobileBridge.h"
#include "vocalwriter.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct VWMobileEngine {
    vw_engine engine;
    char error[192];
};

static void set_error(VWMobileEngine *engine, const char *message, int code)
{
    if (engine == NULL)
        return;
    if (code == 0)
        snprintf(engine->error, sizeof engine->error, "%s", message);
    else
        snprintf(engine->error, sizeof engine->error, "%s (%d)", message, code);
}

VWMobileEngine *vw_mobile_open(const char *resource_path,
                               const char *voices_path,
                               const char *bank_path,
                               const char *lexicon_path)
{
    VWMobileEngine *mobile = calloc(1, sizeof *mobile);
    int result;
    if (mobile == NULL)
        return NULL;
    result = vw_engine_open(&mobile->engine, resource_path, voices_path,
                            bank_path, lexicon_path);
    if (result != VW_OK) {
        set_error(mobile, "The VocalWriter engine could not open its resources", result);
        return mobile;
    }
    return mobile;
}

void vw_mobile_close(VWMobileEngine *engine)
{
    if (engine == NULL)
        return;
    vw_engine_close(&engine->engine);
    free(engine);
}

int32_t vw_mobile_render(VWMobileEngine *mobile,
                         const VWMobileNote *notes,
                         int32_t note_count,
                         int32_t bpm,
                         int32_t voice,
                         const char *output_path)
{
    vw_note *engine_notes;
    vw_song song;
    vw_render_options options;
    int result;
    int32_t i;

    if (mobile == NULL || notes == NULL || note_count <= 0 || output_path == NULL)
        return VW_ERR_ARGUMENT;
    if (mobile->engine.svv == NULL) {
        set_error(mobile, "The VocalWriter engine is not ready", 0);
        return VW_ERR_ENGINE;
    }

    engine_notes = calloc((size_t)note_count, sizeof *engine_notes);
    if (engine_notes == NULL)
        return VW_ERR_MEMORY;

    for (i = 0; i < note_count; i++) {
        engine_notes[i].start = (int32_t)(notes[i].start_beats * 240.0 + 0.5);
        engine_notes[i].duration = (int32_t)(notes[i].duration_beats * 240.0 + 0.5);
        engine_notes[i].key = (int16_t)notes[i].midi_pitch;
        engine_notes[i].velocity = (int16_t)notes[i].velocity;
        engine_notes[i].lyric = notes[i].lyric;
        engine_notes[i].phonemes[0] = 0;
    }

    memset(&song, 0, sizeof song);
    result = vw_song_build(&song, &mobile->engine, engine_notes, note_count, bpm, voice);
    free(engine_notes);
    if (result != VW_OK) {
        set_error(mobile, "The song could not be prepared", result);
        return result;
    }

    memset(&options, 0, sizeof options);
    options.reverb = 1;
    options.reverbRoom = -1;
    options.reverbWet = -1;
    result = vw_render_wav(&mobile->engine, &song, &options, output_path);
    vw_song_free(&song);
    if (result != VW_OK)
        set_error(mobile, "The song could not be rendered", result);
    else
        mobile->error[0] = '\0';
    return result;
}

const char *vw_mobile_error(VWMobileEngine *engine)
{
    if (engine == NULL)
        return "The VocalWriter engine could not be created";
    return engine->error;
}

