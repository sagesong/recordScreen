//
//  RecordScreenTool.h
//  recordInner
//
//  Created by Lightning on 15/5/26.
//  Copyright (c) 2015年 Lightning. All rights reserved.
//

#import <Foundation/Foundation.h>



typedef enum
{
    VIDEO_480_500_12,
    VIDEO_640_600_12,
    VIDEO_960_800_15,
    VIDEO_1280_1000_15
} VideoSolution;

@interface RecordScreenTool : NSObject

+ (instancetype)shareInstance;
+ (VideoSolution)getVideoSetting;

@end






#ifndef DaShi_RecordPara_h
#define DaShi_RecordPara_h

//默认参数
//#define VideoFps 15
//#define VideoKbps 500
//#define VideoHeight 480




//480,12帧
#define VideoFps_12 12
#define VideoFps_15 15

#define Video_Height_480 480
#define Video_Height_640 640
#define Video_Height_960 960
#define Video_Height_1280 1280

#define VideoKbps_500 500
#define VideoKbps_600 600
#define VideoKbps_800 800
#define VideoKbps_1000 1000


/*
 #define VideoFps 15
 #define Video_Height_For_Record 640
 #define Video_Height_For_Upload 640
 #define VideoKbps 10240
 */

/*
 //800
 #define VideoFps 8
 #define Video_Height_For_Record 800
 #define Video_Height_For_Upload 800
 #define VideoKbps 750
 */

/*
 //960
 #define VideoFps 15
 #define Video_Height_For_Record 960
 #define Video_Height_For_Upload 960
 #define VideoKbps 800
 */

/*
 //1280,8帧
 #define VideoFps 15
 #define Video_Height_For_Record 1280
 #define Video_Height_For_Upload 1280
 #define VideoKbps 1000
 */
#endif