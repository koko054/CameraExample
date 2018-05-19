//
//  CaptureDelegate.m
//  CameraExample
//
//  Created by 김도범 on 2018. 5. 19..
//  Copyright © 2018년 DobumKim. All rights reserved.
//

#import "CaptureDelegate.h"

@interface CaptureDelegate ()<AVCapturePhotoCaptureDelegate>

@property(nonatomic, readwrite) AVCapturePhotoSettings *requestedPhotoSettings;
@property(nonatomic) void (^captureAnimation)(void);
@property(nonatomic) void (^livePhotoHandler)(BOOL capturing);
@property(nonatomic) void (^completionHandler)(CaptureDelegate *delegate);

@property(nonatomic) NSData *photoData;
@property(nonatomic) NSURL *livePhotoCompanionMovieURL;

@end

@implementation CaptureDelegate

- (instancetype)initWithSettings:(AVCapturePhotoSettings *)settings
                captureAnimation:(void (^)(void))captureAnimation
                livePhotoHandler:(void (^)(BOOL capturing))livePhotoHandler
                        complete:(void (^)(CaptureDelegate *delegate))complete {
  if (self = [super init]) {
    self.requestedPhotoSettings = settings;
    self.captureAnimation = captureAnimation;
    self.livePhotoHandler = livePhotoHandler;
    self.completionHandler = complete;
  }
  return self;
}

#pragma mark - AVCapturePhotoCaptureDelegate
// AVCapturePhotoOutput의 capturePhotoWithSettings:delegate:함수를 호출하면 가장
// 먼저 불리는 콜백
- (void)captureOutput:(AVCapturePhotoOutput *)output
    willBeginCaptureForResolvedSettings:
        (AVCaptureResolvedPhotoSettings *)resolvedSettings {
  if ((resolvedSettings.livePhotoMovieDimensions.width > 0) &&
      (resolvedSettings.livePhotoMovieDimensions.height > 0)) {
    self.livePhotoHandler(YES);  // livePhoto 캡쳐가 진행중이라고 알려준다.
  }
}

// 캡쳐직전(셔터사운드가 들린후 바로) 호출되는 콜백(livePhoto는 셔터사운드가
// 없음)
- (void)captureOutput:(AVCapturePhotoOutput *)output
    willCapturePhotoForResolvedSettings:
        (AVCaptureResolvedPhotoSettings *)resolvedSettings {
  self.captureAnimation();  // 촬영관련 애니매이션을 실행한다. ex) white flash
                            // animation
}

// 캡쳐직후 호출되는 콜백
- (void)captureOutput:(AVCapturePhotoOutput *)output
    didCapturePhotoForResolvedSettings:
        (AVCaptureResolvedPhotoSettings *)resolvedSettings {
}

// 캡쳐한 이미지가 준비된 경우 호출 (RAW or processed)
- (void)captureOutput:(AVCapturePhotoOutput *)output
    didFinishProcessingPhoto:(AVCapturePhoto *)photo
                       error:(nullable NSError *)error
    API_AVAILABLE(ios(11.0)) {
  if (error != nil) {
    NSLog(@"Error capturing photo: %@", error);
    return;
  }
  self.photoData = [photo fileDataRepresentation];
}

// 라이브포토가 촬영된 경우 호출, 새로운 미디어가 파일로 기록되지 않는다. 만약
// UI에 라이브포토 관련 표시가 있는 경우 이 함수에서 표시를 없애도록 하면 된다.
- (void)captureOutput:(AVCapturePhotoOutput *)output
    didFinishRecordingLivePhotoMovieForEventualFileAtURL:(NSURL *)outputFileURL
                                        resolvedSettings:
                                            (AVCaptureResolvedPhotoSettings *)
                                                resolvedSettings {
  self.livePhotoHandler(NO);  // livePhoto 캡쳐가 진행중이라고 알려준다.
}

// 라이브포토가 저장된 경우 호출
- (void)captureOutput:(AVCapturePhotoOutput *)output
    didFinishProcessingLivePhotoToMovieFileAtURL:(NSURL *)outputFileURL
                                        duration:(CMTime)duration
                                photoDisplayTime:(CMTime)photoDisplayTime
                                resolvedSettings:
                                    (AVCaptureResolvedPhotoSettings *)
                                        resolvedSettings
                                           error:(nullable NSError *)error {
  if (error != nil) {
    NSLog(@"Error processing live photo companion movie: %@", error);
    return;
  }
  self.livePhotoCompanionMovieURL =
      outputFileURL;  // livePhoto가 저장된 URL을 설정
}

// 캡쳐가 완전히 끝난 후 호출되는 함수. 항상 마지막에 호출된다. 캡쳐관련
// 속성들을 초기화하면 된다.
- (void)captureOutput:(AVCapturePhotoOutput *)output
    didFinishCaptureForResolvedSettings:
        (AVCaptureResolvedPhotoSettings *)resolvedSettings
                                  error:(nullable NSError *)error {
}

- (void)didFinish {
  if ([[NSFileManager defaultManager]
       fileExistsAtPath:self.livePhotoCompanionMovieURL.path]) {
    NSError *error = nil;
    [[NSFileManager defaultManager]
     removeItemAtPath:self.livePhotoCompanionMovieURL.path
     error:&error];
    
    if (error) {
      NSLog(@"Could not remove file at url: %@",
            self.livePhotoCompanionMovieURL.path);
    }
  }
  
  self.completionHandler(self);
}

@end
