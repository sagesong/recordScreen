//
//  IOSurfaceAccelerator.h
//  RecordMyScreen
//
//  Created by xiewei on 14/12/9.
//  Copyright (c) 2014年 CoolStar Organization. All rights reserved.
//

#ifndef _IOSURFACE_ACCELERATOR_H
#define _IOSURFACE_ACCELERATOR_H 1

#include "IOSurfaceAPI.h"
#include "IOKit/IOReturn.h"

typedef IOReturn IOSurfaceAcceleratorReturn;

enum {
    kIOSurfaceAcceleratorSuccess = 0,
};

typedef struct __IOSurfaceAccelerator *IOSurfaceAcceleratorRef;

IOSurfaceAcceleratorReturn IOSurfaceAcceleratorCreate(CFAllocatorRef allocator, uint32_t type, IOSurfaceAcceleratorRef *outAccelerator);
IOSurfaceAcceleratorReturn IOSurfaceAcceleratorTransferSurface(IOSurfaceAcceleratorRef accelerator, IOSurfaceRef sourceSurface, IOSurfaceRef destSurface, CFDictionaryRef dict, void *unknown);

#endif



