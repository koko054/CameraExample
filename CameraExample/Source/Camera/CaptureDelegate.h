//
//  CaptureDelegate.h
//  CameraExample
//
//  Created by 김도범 on 2018. 5. 19..
//  Copyright © 2018년 DobumKim. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface CaptureDelegate : NSObject<AVCapturePhotoCaptureDelegate>

- (instancetype)initWithSettings:(AVCapturePhotoSettings *)settings
                captureAnimation:(void (^)(void))captureAnimation
                livePhotoHandler:(void (^)(BOOL capturing))livePhotoHandler
                        complete:(void (^)(CaptureDelegate *delegate))complete;

@property(nonatomic, readonly) AVCapturePhotoSettings *requestedPhotoSettings;

@end
