//
//  IPCStructs.h
//  FruitXR
//
//  Created by user on 2025/11/12.
//

typedef struct {
    // mach_port_t はプロセス間で違う値になるため、別にIDを用意している
    uint32_t swapchain_id;
} EndFrameInfoPerEye;

_Static_assert(sizeof(EndFrameInfoPerEye) == (sizeof(int32_t) * 1), "EndFrameInfoPerEye size SHOULD matched with FruitXR_IPC.defs");

typedef struct {
    EndFrameInfoPerEye eyes[2];
} EndFrameInfo;

typedef struct {
    float x;
    float y;
    float z;
} Position;

typedef struct {
    float x;
    float y;
    float z;
    float w;
} Orientation;

typedef struct {
    Position position;
    Orientation orientation;
} Transform;

typedef struct {
    Transform hmd;
    Transform leftEye;
    Transform rightEye;
} CurrentHeadsetInfo;

_Static_assert(sizeof(CurrentHeadsetInfo) == (sizeof(float) * 21), "CurrentHeadsetInfo size SHOULD matched with FruitXR_IPC.defs");
