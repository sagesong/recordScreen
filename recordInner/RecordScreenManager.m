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
#import <sys/time.h>

@interface RecordScreenManager ()



@property (nonatomic, strong) NSLock *pixelBufferLock;
@property (nonatomic, strong) AVAssetWriter *videoWriter;
@property (nonatomic, strong) AVAssetWriterInput *videoWriterInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor;
@property (nonatomic, retain) dispatch_queue_t video_queue;
@property (nonatomic, retain) dispatch_queue_t screen_queue;

@property (nonatomic, assign) int kbps;
@property (nonatomic, assign) int fps;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) BOOL isRecording;


@property (nonatomic, strong) AVCaptureSession *audioSession;

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

#pragma mark - init audio recorder
- (void)prepareForAudioRecord
{
    // 判断授权状态
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (authStatus == AVAuthorizationStatusDenied) {
        // 提示需要授权
        return;
    }
    
    _audioSession = [[AVCaptureSession alloc] init];
    NSArray *audioDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if (audioDevices.count > 0) {
        AVCaptureDevice *anDevice = [audioDevices objectAtIndex:0];
        NSError *error;
        AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:anDevice error:&error];
        if (error) {
            NSLog(@"the given device cannot be used for capture");
        }
        
        if ([_audioSession canAddInput:deviceInput]) {
            [_audioSession addInput:deviceInput];
        }
        
        // device output
        AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
        
    }
    
    
    
}


#pragma mark - record control
- (BOOL)atRecording
{
    return self.isRecording;
}

- (void)startRecord
{
    self.isRecording = YES;
    
    NSError *sessionError = nil;
    if ([[AVAudioSession sharedInstance] respondsToSelector:@selector(setCategory:withOptions:error:)]) [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDuckOthers error:&sessionError];
    else
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError]; [[AVAudioSession sharedInstance] setActive:YES error:&sessionError];
    
    //此处修正录屏时候声音变小的Bug
    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(audioRouteOverride), &audioRouteOverride);
    
    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    
    self.isRecording = YES;
    // Capture loop
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int targetFPS = self.fps;
        int msBeforeNextCapture = 1000 / targetFPS;
        
        struct timeval lastCapture, currentTime, startTime;
        lastCapture.tv_sec = 0;
        lastCapture.tv_usec = 0;
        
        // Recording start time
        gettimeofday(&startTime, NULL);
        startTime.tv_usec /= 1000;
        
        int lastFrame = -1;
        
        while (self.isRecording) {
            // Time passed since last capture
            gettimeofday(&currentTime, NULL);
            
            // Convert to milliseconds to avoid overflows
            currentTime.tv_usec /= 1000;
            
            unsigned long long diff = (currentTime.tv_usec + (1000 * currentTime.tv_sec)) - (lastCapture.tv_usec + (1000 * lastCapture.tv_sec));
            
            if (diff >= msBeforeNextCapture)
            {
                // Time since start
                unsigned long long msSinceStart = (currentTime.tv_usec + (1000 * currentTime.tv_sec)) - (startTime.tv_usec + (1000 * startTime.tv_sec));
                
                int frameNumber = (int)(msSinceStart / msBeforeNextCapture);
                CMTime presentTime;
                presentTime = CMTimeMake(frameNumber, targetFPS);
                NSParameterAssert(frameNumber != lastFrame);
                lastFrame = frameNumber;
                
                [self captureScreenImage:presentTime];
                lastCapture = currentTime;
            }
            [NSThread sleepForTimeInterval:msBeforeNextCapture*0.001];
            
            }
        
        dispatch_async(self.video_queue, ^{
            [self finishRecord];
        });
        
    });
    
    
}

- (void)stopRecord
{
    self.isRecording = NO;
                   
}

- (void)finishRecord
{
    [self.videoWriterInput markAsFinished];
    //[self.videoWriter finishWriting];
    [self.videoWriter finishWritingWithCompletionHandler:^{
        if (self.videoWriter.status == AVAssetWriterStatusCompleted) {
            NSLog(@"AVAssetWriterStatusCompleted");
        } else {
            NSLog(@"%@",[self.videoWriter.error localizedDescription]);
        }
    }];
    
    self.videoWriter = nil;
    self.videoWriterInput = nil;
    self.pixelBufferAdaptor = nil;
}

- (void)captureScreenImage:(CMTime)frameTime
{
    dispatch_async(self.screen_queue, ^{
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
        
        //录制普通程序没问题，游戏有问题
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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            CVPixelBufferRef pixelBuffer = NULL;
            if (!self.pixelBufferAdaptor.pixelBufferPool)
            {
                NSLog(@"skipping frame: %lld", frameTime.value);
                return;
            }
            
            NSParameterAssert(self.pixelBufferAdaptor.pixelBufferPool != NULL);
            [self.pixelBufferLock lock];
            CVPixelBufferPoolCreatePixelBuffer (kCFAllocatorDefault, self.pixelBufferAdaptor.pixelBufferPool, &pixelBuffer);
            [self.pixelBufferLock unlock];
            NSParameterAssert(pixelBuffer != NULL);
            
            //pixelBuffer set
            
            // Unlock pixel buffer data
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            void *pixelData = CVPixelBufferGetBaseAddress(pixelBuffer);
            NSParameterAssert(pixelData != NULL);
            
            
            //            memcpy(pixelData, baseAddr, totalBytes);
            size_t pixelBufferPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
            for (int idx = 0; idx < height; idx++)
            {
                memcpy(pixelData + idx * pixelBufferPerRow, baseAddr + idx * destSurfPerRow, destSurfPerRow);
            }
            
            CFRelease(destSurf);
            destSurf = NULL;
            
            // Unlock pixel buffer data
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            /*
             //test code
             CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, pixelBuffer, kCMAttachmentMode_ShouldPropagate);
             NSDictionary *currentListing = CFBridgingRelease(attachments);
             
             CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:currentListing];
             //END test code
             */
            
            dispatch_async(self.video_queue, ^{
                while (!self.videoWriterInput.readyForMoreMediaData) usleep(1000);
                
                [self.pixelBufferLock lock];
                [self.pixelBufferAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:frameTime];
                CVPixelBufferRelease(pixelBuffer);
                [self.pixelBufferLock unlock];
            });
            
        });
        
    });
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
    _screen_queue = dispatch_queue_create("screen_queue", DISPATCH_QUEUE_SERIAL);
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
    
    CGSize size = [self getScreenSize];
    self.width = size.width;
    self.height = size.height;
    
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
    
    self.width = videoWidth;
    self.height = videoHeight;
}

-(CGSize)getScreenSize
{
    CGSize size = CGSizeMake(0, 0);
    
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
    
    uint32_t aseed;
    IOSurfaceLock(screenSurface, kIOSurfaceLockReadOnly, &aseed);
    size.width = IOSurfaceGetWidth(screenSurface);
    size.height = IOSurfaceGetHeight(screenSurface);
    
    IOSurfaceUnlock(screenSurface, kIOSurfaceLockReadOnly, &aseed);
    
    CFRelease(screenSurface);
    screenSurface = NULL;
    
    return size;
}

- (void)settingAssetWriterWithUrl:(NSURL *)url
{
    if (_videoWriter) {
        return;
    }
    NSError *error;
    _videoWriter = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:&error];
    
    NSDictionary *compressionProperties = @{AVVideoAverageBitRateKey : @(self.kbps * 1000), AVVideoMaxKeyFrameIntervalKey : @(self.fps), AVVideoProfileLevelKey : AVVideoProfileLevelH264Main32};
    
    NSDictionary *outputSettings = @{AVVideoCodecKey : AVVideoCodecH264, AVVideoWidthKey : @(self.width), AVVideoHeightKey : @(self.height), AVVideoCompressionPropertiesKey : compressionProperties};
    NSParameterAssert([self.videoWriter canApplyOutputSettings:outputSettings forMediaType:AVMediaTypeVideo]);
    self.videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
    NSParameterAssert(self.videoWriterInput);
    NSParameterAssert([self.videoWriter canAddInput:self.videoWriterInput]);
    [self.videoWriter addInput:self.videoWriterInput];
    
    NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @(kCVPixelFormatType_32BGRA), kCVPixelBufferPixelFormatTypeKey,
                                      @(self.width), kCVPixelBufferWidthKey,
                                      @(self.height), kCVPixelBufferHeightKey,
                                      kCFAllocatorDefault, kCVPixelBufferMemoryAllocatorKey,
                                      nil];
    
    self.pixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoWriterInput sourcePixelBufferAttributes:bufferAttributes];
    
    // FPS
    [self.videoWriterInput setMediaTimeScale:self.fps];
    [self.videoWriter setMovieTimeScale:self.fps];
    
    // Start a session
    [self.videoWriterInput setExpectsMediaDataInRealTime:YES];
    [self.videoWriter startWriting];
    [self.videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    // TODO: Hhmmm, seems to be crashing right here on the iPad.
    NSParameterAssert(self.pixelBufferAdaptor.pixelBufferPool != NULL);
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
