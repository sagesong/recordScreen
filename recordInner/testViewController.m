//
//  testViewController.m
//  recordInner
//
//  Created by Lightning on 15/5/29.
//  Copyright (c) 2015年 Lightning. All rights reserved.
//

#import "testViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "IOMobileFrameBuffer.h"
#import "IOSurfaceAccelerator.h"
#import <sys/time.h>


@interface testViewController ()

@end

@implementation testViewController

#pragma mark - life cycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    IOMobileFramebufferConnection connect;
    kern_return_t result;
    
    IOSurfaceRef screenSurface = NULL;
    
    io_service_t framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleH1CLCD"));
    if(!framebufferService)
        framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleM2CLCD"));
    if(!framebufferService)
        framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleCLCD"));
    
    result = IOMobileFramebufferOpen(framebufferService, mach_task_self(), 0, &connect);
    result = IOMobileFramebufferGetLayerDefaultSurface(connect, 0, (CoreSurfaceBufferRef *)&screenSurface);
    
    uint32_t lockSeed,unlockSeed;
    IOSurfaceLock(screenSurface, kIOSurfaceLockReadOnly, &lockSeed);
    
    uint32_t width = (int)IOSurfaceGetWidth(screenSurface);
    uint32_t height = (int)IOSurfaceGetHeight(screenSurface);
    
    
    int pitch = width*4, size = width*height*4;
    int bPE=4;
    char pixelFormat[4] = {'A','R','G','B'};
    CFMutableDictionaryRef dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(dict, kIOSurfaceIsGlobal, kCFBooleanTrue);
    CFDictionarySetValue(dict, kIOSurfaceBytesPerRow, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pitch));
    CFDictionarySetValue(dict, kIOSurfaceBytesPerElement, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bPE));
    CFDictionarySetValue(dict, kIOSurfaceWidth, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &width));
    CFDictionarySetValue(dict, kIOSurfaceHeight, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &height));
    CFDictionarySetValue(dict, kIOSurfacePixelFormat, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, pixelFormat));
    CFDictionarySetValue(dict, kIOSurfaceAllocSize, CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &size));
    
    __block IOSurfaceRef destSurf = IOSurfaceCreate(dict);
    
    void* outAcc;
    IOSurfaceAcceleratorCreate(NULL, 0, (IOSurfaceAcceleratorRef *)&outAcc);
    IOSurfaceAcceleratorTransferSurface(outAcc, screenSurface, destSurf, dict, NULL);
    
    IOSurfaceUnlock(screenSurface, kIOSurfaceLockReadOnly, &unlockSeed);
    
    CFRelease(screenSurface);
    //screenSurface = NULL;
    CFRelease(outAcc);
    CFRelease(dict);
    
    void *baseAddr = IOSurfaceGetBaseAddress(destSurf);
    
    size_t destSurfPerRow = IOSurfaceGetBytesPerRow(destSurf);
    
    
    
    NSLog(@"%d----%d",width,height);
}




@end
