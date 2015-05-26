//
//  RecordScreenTool.m
//  recordInner
//
//  Created by Lightning on 15/5/26.
//  Copyright (c) 2015年 Lightning. All rights reserved.
//

#import "RecordScreenTool.h"
#import "UIDevice+Hardware.h"
@implementation RecordScreenTool

+ (instancetype)shareInstance
{
    static RecordScreenTool *single;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        single = [[self alloc] init];
    });
    
    return single;
}

+ (VideoSolution)getVideoSetting
{
    Hardware device = [[UIDevice currentDevice] hardware];
    
    switch (device) {
            //≤iPhone4,  帧率12，最长边480，码率500
        case IPHONE_2G:
        case IPHONE_3G:
        case IPHONE_3GS:
        case IPHONE_4:
        case IPHONE_4_CDMA:
            //≤iTouch4，帧率12，最长边480，码率500
        case IPOD_TOUCH_1G:
        case IPOD_TOUCH_2G:
        case IPOD_TOUCH_3G:
        case IPOD_TOUCH_4G:
        {
            return VIDEO_480_500_12;
        }
            //iPad2，iPad mini，iPad1，帧率12，最长边640，码率600
        case IPAD:
        case IPAD_2:
        case IPAD_2_WIFI:
        case IPAD_2_CDMA:
        case IPAD_MINI:
        case IPAD_MINI_WIFI:
        case IPAD_MINI_WIFI_CDMA:
        {
            return VIDEO_640_600_12;
        }
            //iPhone4s，iPhone5，iPhone5S，帧率15，最长边960，码率800
        case IPHONE_4S:
        case IPHONE_5:
        case IPHONE_5_CDMA_GSM:
        case IPHONE_5C:
        case IPHONE_5C_CDMA_GSM:
        case IPHONE_5S:
        case IPHONE_5S_CDMA_GSM:
            //iPad3、4、air、air2，mini2、mini3或以上，帧率15，最长边960，码率800
        case IPAD_3:
        case IPAD_3G:
        case IPAD_3_WIFI:
        case IPAD_3_WIFI_CDMA:
        case IPAD_4:
        case IPAD_4_WIFI:
        case IPAD_4_GSM_CDMA:
            
        case IPAD_MINI_RETINA_WIFI:
        case IPAD_MINI_RETINA_WIFI_CDMA:
        case IPAD_MINI_3_WIFI:
        case IPAD_MINI_3_WIFI_CELLULAR:
        case IPAD_MINI_RETINA_WIFI_CELLULAR_CN:
            
        case IPAD_AIR_WIFI:
        case IPAD_AIR_WIFI_GSM:
        case IPAD_AIR_WIFI_CDMA:
        case IPAD_AIR_2_WIFI:
        case IPAD_AIR_2_WIFI_CELLULAR:
            //≥iTouch5，帧率15，最长边960，码率800
        case IPOD_TOUCH_5G:
        {
            return VIDEO_960_800_15;
            
        }
            //iPhone6，iPhone6+，帧率15，最长边1280，码率1000
        case IPHONE_6_PLUS:
        case IPHONE_6:
        {
            return VIDEO_1280_1000_15;
        }
        default:
            break;
    }
    
    return VIDEO_480_500_12;
}

@end
