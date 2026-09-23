#ifndef VW_MOBILE_BRIDGE_H
#define VW_MOBILE_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct VWMobileEngine VWMobileEngine;

typedef struct VWMobileNote {
    double start_beats;
    double duration_beats;
    int32_t midi_pitch;
    int32_t velocity;
    const char *lyric;
} VWMobileNote;

VWMobileEngine *vw_mobile_open(const char *resource_path,
                               const char *voices_path,
                               const char *bank_path,
                               const char *lexicon_path);
void vw_mobile_close(VWMobileEngine *engine);

int32_t vw_mobile_render(VWMobileEngine *engine,
                         const VWMobileNote *notes,
                         int32_t note_count,
                         int32_t bpm,
                         int32_t voice,
                         const char *output_path);

const char *vw_mobile_error(VWMobileEngine *engine);

#ifdef __cplusplus
}
#endif

#endif

