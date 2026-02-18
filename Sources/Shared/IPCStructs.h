//
//  IPCStructs.h
//  FruitXR
//
//  Created by user on 2025/11/12.
//

typedef struct {
    // mach_port_t はプロセス間で違う値になるため、別にIDを用意している
    uint32_t swapchain_id;
} IPCEndFrameInfoPerEye;

_Static_assert(sizeof(IPCEndFrameInfoPerEye) == (sizeof(int32_t) * 1), "IPCEndFrameInfoPerEye size SHOULD matched with FruitXR_IPC.defs");

typedef struct {
    IPCEndFrameInfoPerEye eyes[2];
} IPCEndFrameInfo;

typedef struct {
    float x;
    float y;
    float z;
} IPCPosition;

typedef struct {
    float x;
    float y;
    float z;
    float w;
} IPCOrientation;

typedef struct {
    IPCPosition position;
    IPCOrientation orientation;
} IPCTransform;

#define HC_BUTTON_PRIMARY_CLICK (1 << 0)
#define HC_BUTTON_PRIMARY_TOUCH (1 << 1)
#define HC_BUTTON_SECONDARY_CLICK (1 << 2)
#define HC_BUTTON_SECONDARY_TOUCH (1 << 3)
#define HC_BUTTON_STICK_CLICK (1 << 4)
#define HC_BUTTON_STICK_TOUCH (1 << 5)
#define HC_BUTTON_SYSTEM_CLICK (1 << 6)
#define HC_BUTTON_THUMBREST_TOUCH (1 << 7)

typedef struct {
    IPCTransform transform;
    float thumbstick_x;
    float thumbstick_y;
    float trigger;
    float squeeze;
    uint32_t buttons;
} IPCHandController;

typedef struct {
    IPCTransform hmd;
    IPCTransform leftEye;
    IPCTransform rightEye;
    IPCHandController leftController;
    IPCHandController rightController;
} IPCCurrentHeadsetInfo;

// Transform = 7
// Controller = Transform + 5 = 12
// 7*3 + 12*2 = 45
_Static_assert(sizeof(IPCCurrentHeadsetInfo) == (sizeof(float) * 45), "IPCCurrentHeadsetInfo size SHOULD matched with FruitXR_IPC.defs");
