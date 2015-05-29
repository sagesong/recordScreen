//
//  MyScreenRe.m
//  recordInner
//
//  Created by Lightning on 15/5/29.
//  Copyright (c) 2015年 Lightning. All rights reserved.
//

#import "MyScreenRe.h"
#import <AVFoundation/AVFoundation.h>
#import "IOMobileFrameBuffer.h"
#import "IOSurfaceAccelerator.h"
#import <sys/time.h>

@interface MyScreenRe ()<AVCaptureAudioDataOutputSampleBufferDelegate>
{
    AVAssetWriter * _assetWriter;
    AVAssetWriterInput * _assetWriterAudioIn;
    AVAssetWriterInput * _videoWriterInput;
    
    AVCaptureSession * _captureSession;
    AVCaptureOutput * _audioCaptureOutput;
    AVCaptureConnection * _audioConnection;
    dispatch_queue_t _sessionQueue;
    dispatch_queue_t _audioDataQueue;
    dispatch_queue_t _captureScreenQueue;
    
    CADisplayLink *_displayeLink;
    NSInteger _timeCount;
    NSDate *_startingCaptureTime;
}


@end


@implementation MyScreenRe

- (instancetype)init
{
    if (self = [super init]) {
        _displayeLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallBack:)];
        [_displayeLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [_displayeLink setPaused:YES];
        _displayeLink.frameInterval = 4;
        _timeCount = 0;
        
        _audioDataQueue = dispatch_queue_create("audioDataQueue", 0);
        _sessionQueue = dispatch_queue_create("sessionQueue", 0);
        _captureScreenQueue = dispatch_queue_create("captureScreenQueue", 0);
    }
    
    return self;
}

- (void)displayLinkCallBack:(CADisplayLink *)diplayLink
{
    _timeCount ++;
    if (_assetWriter.status == AVAssetWriterStatusUnknown)
    {
        [_assetWriter startWriting];
        [_assetWriter startSessionAtSourceTime:kCMTimeZero];
    }
    dispatch_async(_captureScreenQueue, ^{
        [self captureScreen];
    });
}

- (void)captureScreen
{
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
}


- (void)startRecord
{
    if ([_captureSession isRunning]) {
        return;
    }
    NSError *error;
    _assetWriter = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:_filePath] fileType:AVMediaTypeVideo error:&error];
    if (error) {
        NSLog(@"AVAssetWriter cann't be allocted");
    }
    
    _startingCaptureTime = [NSDate date];
    dispatch_async(_sessionQueue, ^{
        [_captureSession startRunning];
    });
    
    [_displayeLink setPaused:NO];
    
}
- (void)stopRecord
{
    [_displayeLink setPaused:YES];
    dispatch_async(_sessionQueue, ^{
        [_captureSession startRunning];
    });
    
}

- (BOOL)setupAssetWriter
{
    AVAssetWriterInput *audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:nil];
    
    
    return YES;
}

- (void)test
{
    AudioChannelLayout channelLayout;
    memset(&channelLayout, 0, sizeof(AudioChannelLayout));
    channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    
    NSDictionary *audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
                                   [NSNumber numberWithFloat:44100.0] ,AVSampleRateKey,
                                   [NSNumber numberWithInt: 1] ,AVNumberOfChannelsKey,
                                   [NSNumber numberWithInt:192000],AVEncoderBitRateKey,
                                   [NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)],AVChannelLayoutKey,
                                   nil];
}

- (BOOL)setupCaptureSession
{
    _captureSession = [[AVCaptureSession alloc] init];
    
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    assert(audioDevice);
    NSError *error;
    AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (error) {
        NSLog(@"audioDeviceInput error");
        return NO;
    }
    
    if (![_captureSession canAddInput:audioDeviceInput]) {
        NSLog(@"CaptureSession cann't add audio device input");
        return NO;
    }
    [_captureSession addInput:audioDeviceInput];
    
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    _audioConnection = [audioOutput connectionWithMediaType:AVMediaTypeAudio];
    
    _audioDataQueue = dispatch_queue_create("audioDataQueue", NULL);
    [audioOutput setSampleBufferDelegate:self queue:_audioDataQueue];
    
    
    return YES;
}


#pragma mark - AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (connection == _audioConnection) {
        [self setupAssetWriterAudioInput:CMSampleBufferGetFormatDescription(sampleBuffer)];
        [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeAudio];
    }
}

- (BOOL)setupAssetWriterAudioInput:(CMFormatDescriptionRef) FormatDescription
{
    const AudioStreamBasicDescription *currentASBD = CMAudioFormatDescriptionGetStreamBasicDescription(FormatDescription);
    size_t aclSize = 0;
    const AudioChannelLayout * currentAudioChannelLayout= CMAudioFormatDescriptionGetChannelLayout(FormatDescription, &aclSize);
    NSData *audioChannelData = nil;
    
    if (currentAudioChannelLayout && aclSize > 0) {
        audioChannelData = [NSData dataWithBytes:currentAudioChannelLayout length:aclSize];
    } else {
        audioChannelData = [NSData data];
    }
    // AVFormatIDKey, AVSampleRateKey, and AVNumberOfChannelsKey keys. If no other channel layout information is available, a value of 1 for the AVNumberOfChannelsKey key results in mono output and a value of 2 results in stereo output
    NSMutableDictionary *audioSettings = [NSMutableDictionary dictionary];
    [audioSettings setObject:@(kAudioFormatMPEG4AAC) forKey:AVFormatIDKey];
    [audioSettings setObject:@(currentASBD->mSampleRate) forKey:AVSampleRateKey];
    [audioSettings setObject:@(currentASBD->mChannelsPerFrame) forKey:AVNumberOfChannelsKey];
    [audioSettings setObject:audioChannelData forKey:AVChannelLayoutKey];
    [audioSettings setObject:@(64000) forKey:AVEncoderBitRatePerChannelKey];
    if (![_assetWriter canApplyOutputSettings:audioSettings forMediaType:AVMediaTypeAudio]) {
        NSLog(@"AVAssetWriter couldn't apply audioOutputSettings");
        return NO;
    }
    _assetWriterAudioIn = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    _assetWriterAudioIn.expectsMediaDataInRealTime = NO;
    if (![_assetWriter canAddInput:_assetWriterAudioIn]) {
        NSLog(@"AVAssetWriter couldn't add video input");
        return NO;
    }
    [_assetWriter addInput:_assetWriterAudioIn];
    
    return YES;
}

- (void)writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
    if (_assetWriter.status == AVAssetWriterStatusUnknown) {
        if ([_assetWriter startWriting]) {
            [_assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
        } else {
            NSLog(@"%@",_assetWriter.error);
        }
    }
    
    if (_assetWriter.status == AVAssetWriterStatusWriting) {
            if (mediaType == AVMediaTypeAudio) {
            if (_assetWriterAudioIn.readyForMoreMediaData) {
                [_assetWriterAudioIn appendSampleBuffer:sampleBuffer];
            }
            }
    }
}

@end
