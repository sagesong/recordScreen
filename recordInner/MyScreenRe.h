//
//  MyScreenRe.h
//  recordInner
//
//  Created by Lightning on 15/5/29.
//  Copyright (c) 2015年 Lightning. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MyScreenRe : NSObject

- (void)startRecord;
- (void)stopRecord;

@property (nonatomic, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, copy) NSString *filePath;

@end
