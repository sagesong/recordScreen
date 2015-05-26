//
//  RecordScreenManager.m
//  recordInner
//
//  Created by Lightning on 15/5/26.
//  Copyright (c) 2015年 Lightning. All rights reserved.
//

#import "RecordScreenManager.h"
#import <AVFoundation/AVFoundation.h>
#import "RecordScreenTool.h"
#import "IOMobileFrameBuffer.h"
#import "IOSurfaceAccelerator.h"

@interface RecordScreenManager ()

@property (nonatomic, strong) NSLock *pixelBufferLock;
@property (nonatomic, strong) AVAssetWriter *videoWriter;
@property (nonatomic, strong) AVAssetWriterInput *videoWriterInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor;
@property (nonatomic, retain) dispatch_queue_t video_queue;
@property (nonatomic, assign) NSInteger kbps;
@property (nonatomic, assign) NSInteger fps;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) BOOL isRecording;

@end


@implementation RecordScreenManager

+ (instancetype)shareInstance
{
    static RecordScreenManager *single;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        single = [[self alloc] init];
    });
    
    return single;
}

#pragma mark - record control
- (BOOL)atRecording
{
    return self.isRecording;
}

- (void)startRecord
{
    
}

- (void)stopRecord
{
    
}

#pragma mark - initiation before record
- (void)setupRecordParam
{
    //设置文件保存路径
    NSString *filePath = nil;
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    
    // 初始化 成员变量
    _pixelBufferLock = [[NSLock alloc] init];
    _video_queue = dispatch_queue_create("video_queue", DISPATCH_QUEUE_SERIAL);
    VideoSolution videoSetting = [RecordScreenTool getVideoSetting];
    [self settingFpsAndRate:videoSetting];
    [self settingVideoWidthAndHeight];
    [self settingAssetWriterWithUrl:fileUrl];
    
}

- (void)settingVideoWidthAndHeight
{
    CGRect screenRect = [UIScreen mainScreen].bounds;
    float scale = [UIScreen mainScreen].scale;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        // iPhone frame buffer is Portrait
        self.width = screenRect.size.width * scale;
        self.height = screenRect.size.height * scale;
    } else
    {
        // iPad frame buffer is Landscape
        self.width = screenRect.size.height * scale;
        self.height = screenRect.size.width * scale;
    }
    
//    CGSize size = [self getScreenSize];
//    self.width = size.width;
//    self.height = size.height;
    
    float videoWidth = self.width;
    float videoHeight = self.height;
    
    videoHeight = Video_Height_480; //默认值
    
    VideoSolution videoSolution = [RecordScreenTool getVideoSetting];
    switch (videoSolution) {
        case VIDEO_480_500_12:
        {
            videoHeight = Video_Height_480;
        }
            break;
        case VIDEO_640_600_12:
        {
            videoHeight = Video_Height_640;
        }
            break;
        case VIDEO_960_800_15:
        {
            videoHeight = Video_Height_960;
        }
            break;
        case VIDEO_1280_1000_15:
        {
            videoHeight = Video_Height_1280;
        }
            break;
        default:
            break;
    }
    
    videoWidth = videoHeight * self.width / self.height;
    
    //绿边处理
    NSInteger maxLength = self.height > self.width ? self.height : self.width;
    switch (maxLength) {
        case 1334:              //iphone6
        {
            videoWidth = 728;   //原值719
            break;
        }
        case 1024:              //ipad2
        {
            videoWidth = 860;   //原值853
            break;
        }
            
        default:
            break;
    }
}

//-(CGSize)getScreenSize
//{
//    CGSize size = CGSizeMake(0, 0);
//    
//    IOMobileFramebufferConnection connect;
//    kern_return_t result;
//    IOSurfaceRef screenSurface = NULL;
//    
//    io_service_t framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleH1CLCD"));
//    if(!framebufferService)
//        framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleM2CLCD"));
//    if(!framebufferService)
//        framebufferService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleCLCD"));
//    
//    result = IOMobileFramebufferOpen(framebufferService, mach_task_self(), 0, &connect);
//    result = IOMobileFramebufferGetLayerDefaultSurface(connect, 0, (CoreSurfaceBufferRef *)&screenSurface);
//    
//    uint32_t aseed;
//    IOSurfaceLock(screenSurface, kIOSurfaceLockReadOnly, &aseed);
//    size.width = IOSurfaceGetWidth(screenSurface);
//    size.height = IOSurfaceGetHeight(screenSurface);
//    
//    IOSurfaceUnlock(screenSurface, kIOSurfaceLockReadOnly, &aseed);
//    
//    CFRelease(screenSurface);
//    screenSurface = NULL;
//    
//    return size;
//}

- (void)settingAssetWriterWithUrl:(NSURL *)url
{
    if (_videoWriter) {
        return;
    }
    NSError *error;
    _videoWriter = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:&error];
    
    
}

- (void)settingFpsAndRate:(VideoSolution)videoSetting
{
    switch (videoSetting) {
        case VIDEO_480_500_12:
        {
            self.fps = VideoFps_12;
            self.kbps = VideoKbps_500;
        }
            break;
        case VIDEO_640_600_12:
        {
            self.fps = VideoFps_12;
            self.kbps = VideoKbps_600;
        }
            break;
        case VIDEO_960_800_15:
        {
            self.fps = VideoFps_15;
            self.kbps = VideoKbps_800;
        }
            break;
        case VIDEO_1280_1000_15:
        {
            self.fps = VideoFps_15;
            self.kbps = VideoKbps_1000;
        }
            break;
        default:
            break;
    }
}



@end
