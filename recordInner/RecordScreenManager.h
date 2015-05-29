//
//  RecordScreenManager.h
//  recordInner
//
//  Created by Lightning on 15/5/26.
//  Copyright (c) 2015年 Lightning. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface RecordScreenManager : NSObject

+ (instancetype)shareInstance;

- (BOOL)startRecord;
- (BOOL)stopRecord;
- (BOOL)recording;


@end
