//
//  ViewController.m
//  recordInner
//
//  Created by Lightning on 15/5/26.
//  Copyright (c) 2015年 Lightning. All rights reserved.
//

#import "ViewController.h"
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>



@interface ViewController ()
- (IBAction)beginRecord:(UIButton *)sender;
@property (weak, nonatomic) IBOutlet UILabel *timeLable;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self openAssistiveTouch];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)beginRecord:(UIButton *)sender {
    if (![self openAssistiveTouch]) {
        return;
    }
    
    
}









#pragma mark - check for assistant touch

- (BOOL)openAssistiveTouch
{
    BOOL findAssisTiveProcess = NO;
    NSArray *processesArray = [self runningProcesses];
    for (NSDictionary *processDict in processesArray) {
        if ([[processDict objectForKey:@"ProcessName"] isEqualToString:@"assistivetouchd"]) {
            findAssisTiveProcess = YES;
            NSLog(@"please already assitive touch");
            return YES;
        }
    }
    
    NSLog(@"please open assitive touch");
    return NO;
}

//返回所有正在运行的进程的 id，name，占用cpu，运行时间
//使用函数int	sysctl(int *, u_int, void *, size_t *, void *, size_t)
- (NSArray *)runningProcesses
{
    //指定名字参数，按照顺序第一个元素指定本请求定向到内核的哪个子系统，第二个及其后元素依次细化指定该系统的某个部分。
    //CTL_KERN，KERN_PROC,KERN_PROC_ALL 正在运行的所有进程
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL ,0};
    
    size_t miblen = 4;
    //值-结果参数：函数被调用时，size指向的值指定该缓冲区的大小；函数返回时，该值给出内核存放在该缓冲区中的数据量
    //如果这个缓冲不够大，函数就返回ENOMEM错误
    size_t size;
    //返回0，成功；返回-1，失败
    int st = sysctl(mib, miblen, NULL, &size, NULL, 0);
    if(st != 0)
    {
        return nil;
    }
    
    struct kinfo_proc * process = NULL;
    struct kinfo_proc * newprocess = NULL;
    do
    {
        size += size / 10;
        newprocess = realloc(process, size);
        if (!newprocess)
        {
            if (process)
            {
                free(process);
                process = NULL;
            }
            return nil;
        }
        
        process = newprocess;
        st = sysctl(mib, miblen, process, &size, NULL, 0);
    } while (st == -1 && errno == ENOMEM);
    
    if (st == 0)
    {
        if (size % sizeof(struct kinfo_proc) == 0)
        {
            int nprocess = size / sizeof(struct kinfo_proc);
            if (nprocess)
            {
                NSMutableArray * array = [[NSMutableArray alloc] init];
                for (int i = nprocess - 1; i >= 0; i--)
                {
                    NSString * processID = [[NSString alloc] initWithFormat:@"%d", process[i].kp_proc.p_pid];
                    NSString * processName = [[NSString alloc] initWithFormat:@"%s", process[i].kp_proc.p_comm];
                    NSString * proc_CPU = [[NSString alloc] initWithFormat:@"%d", process[i].kp_proc.p_estcpu];
                    double t = [[NSDate date] timeIntervalSince1970] - process[i].kp_proc.p_un.__p_starttime.tv_sec;
                    NSString * proc_useTiem = [[NSString alloc] initWithFormat:@"%f",t];
                    
                    //NSLog(@"process.kp_proc.p_stat = %c",process.kp_proc.p_stat);
                    
                    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
                    [dic setValue:processID forKey:@"ProcessID"];
                    [dic setValue:processName forKey:@"ProcessName"];
                    [dic setValue:proc_CPU forKey:@"ProcessCPU"];
                    [dic setValue:proc_useTiem forKey:@"ProcessUseTime"];
                    
                    [array addObject:dic];
                }
                
                free(process);
                process = NULL;
                //NSLog(@"array = %@",array);
                
                return array;
            }
        }
    }
    
    return nil;
}

@end
