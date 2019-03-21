//
//  Camera.m
//  CameraExample
//
//  Created by 김도범 on 2018. 5. 19..
//  Copyright © 2018년 DobumKim. All rights reserved.
//

#import "Camera.h"
#import "CaptureDelegate.h"
#import "AVCaptureDeviceDiscoverySession+Utilities.h"
#import <UIKit/UIKit.h>

@import Photos;

#define USE_INTERRUPTION_NOTIFICATION 0

#define EPSILON 1.0e-5f

int const kTimeScale = 1000000;

BOOL floatsAreEquivalentEpsilon(float left, float right, float epsilon) { return (ABS(left - right) < epsilon); }

BOOL floatsAreEquivalent(float left, float right) { return floatsAreEquivalentEpsilon(left, right, EPSILON); }

@interface Camera ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate>

@property(nonatomic, assign) BOOL sessionRunning;  // 캡쳐세션이 에러로 멈췄을때 다시 시작할지 판단하기위한 플래그
@property(nonatomic, strong)
    AVCaptureDeviceDiscoverySession *cameraDiscoverySession;     // 현재 카메라디바이스를 찾기위한 세션
@property(nonatomic, strong) AVCaptureSession *captureSession;   // 카메라 캡쳐세션
@property(nonatomic, strong) AVCaptureDevice *cameraDevice;      //
@property(nonatomic, strong) AVCaptureDeviceInput *videoInput;   // 비디오 영상 입력
@property(nonatomic, strong) AVCaptureDeviceInput *audioInput;   // 오디오 입력
@property(nonatomic, strong) AVCapturePhotoOutput *photoOutput;  // 사진,라이브포토 출력

// 사진,포토라이브러리 캡쳐 관리
@property(nonatomic) NSMutableDictionary<NSNumber *, CaptureDelegate *> *inProgressPhotoCaptureDelegates;
@property(nonatomic) NSInteger inProgressLivePhotoCapturesCount;

@property(nonatomic, copy) void (^videoRecordingComplete)(BOOL success);  // 비디오 촬영 완료 블럭
@property(nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;   // 비디오 출력

@property(nonatomic, assign) UIBackgroundTaskIdentifier backgroundRecordingID;  // 백그라운드 태스크 관리

@property(nonatomic, assign) CGFloat iso;
@property(nonatomic, assign) CGFloat duration;

@end

@implementation Camera

#pragma mark - initialize

// 카메라 세션 작업 큐를 싱글톤객체로 생성
+ (dispatch_queue_t)sessionQueue {
  static dispatch_queue_t sessionQueue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (!sessionQueue) sessionQueue = dispatch_queue_create("camera session queue", DISPATCH_QUEUE_SERIAL);
  });
  return sessionQueue;
}

// async하게 싱글톤객체생성
+ (void)configureCamera:(void (^)(Camera *camera, NSError *error))complete {
  [Camera congifureCameraWithMode:CameraModePhoto position:AVCaptureDevicePositionBack complete:complete];
}

// async하게 싱글톤객체생성
+ (void)congifureCameraWithMode:(CameraMode)mode
                       position:(AVCaptureDevicePosition)position
                       complete:(void (^)(Camera *camera, NSError *error))complete {
  if (!complete) return;
  static Camera *camera = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    dispatch_async([Camera sessionQueue], ^{
      NSError *error;
      if (!camera) camera = [[Camera alloc] initWithMode:mode position:position error:&error];
      complete(camera, error);
    });
  });
}

// 객체생성
- (instancetype)initWithMode:(CameraMode)mode position:(AVCaptureDevicePosition)position error:(NSError **)error {
  if (self = [super init]) {
    // 프로퍼티초기화
    _mode = mode;
    _position = position;
    _flashMode = AVCaptureFlashModeAuto;
    _torchMode = AVCaptureTorchModeOff;
    _focusMode = AVCaptureFocusModeContinuousAutoFocus;
    _exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    _whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
    _videoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
    _livePhotoEnable = NO;
    _depthDataDeliveryEnable = NO;
    _portraitEffectsMatteEnable = NO;
    _photoStabilizationEnable = YES;
    _photoFormat = PhotoFormatHEIF;
    _previewPhotoSize = CGSizeZero;
    _iso = -1.0;
    _duration = -1.0;

    // 카메라모드와 포지션에 맞춰 캡쳐세션 구성(카메라디바이스생성, 세션프리셋, 비디오입력연결, 사진출력설정)
    // 카메라설정하여 실패시 캡쳐 세션 설정종료 및 nil포인트반환
    if (![self configureCaptureSessionForMode:_mode andPosition:_position error:error]) {
      return nil;
    }

    // 백그라운드ID 초기화
    self.backgroundRecordingID = UIBackgroundTaskInvalid;

    // 사진챕쳐딜리게이트를 저장하는 dictionary 설정 및 초기화
    self.inProgressPhotoCaptureDelegates = [NSMutableDictionary dictionary];
    self.inProgressLivePhotoCapturesCount = 0;
  }
  return self;
}

- (void)dealloc {
}

#pragma mark - public functions

// 현재 카메라 포맷의 해상도를 전달하기위한 함수
- (CGSize)resolution {
  return CGSizeMake(self.currentFormat.highResolutionStillImageDimensions.width,
                    self.currentFormat.highResolutionStillImageDimensions.height);
}

// 캡쳐세션 시작
- (void)startCapture {
  [self.captureSession startRunning];
  self.sessionRunning = self.captureSession.isRunning;
}

// 캡쳐세션 중지
- (void)stopCapture {
  [self.captureSession stopRunning];
  self.sessionRunning = self.captureSession.isRunning;
}

// 사진/라이브포토 촬영
- (void)takePhotoWithDelegate:(id<CameraCaptureUIDelegate>)uiDelegate
                     complete:(void (^)(UIImage *previewImage))complete {
  NSAssert(uiDelegate, @"uiDelegate can't be nil");
  // 현재 카메라화면의 오리엔테이션을 적용
  AVCaptureConnection *photoOutputConnection = [self.photoOutput connectionWithMediaType:AVMediaTypeVideo];
  photoOutputConnection.videoOrientation = [uiDelegate captureOrientation];

  // 사진촬영 설정객체 생성 (여기서 라이브포토로 찍을지, 그냥 사진촬영할지 결정된다. also depthDataDelivery)
  AVCapturePhotoSettings *settings = [self configurePhotoSetting];

  // 라이브포토촬영시 촬영하는 데 시간이 걸리는데 연속해서 촬영할 경우 촬영프로세스를 여러개 동시에 돌리기 위해
  // 실질적인 촬영기능을 CaptureDelegate 클래스로 분리하여 여러개의 객체를 생성하여 촬영한다.
  CaptureDelegate *captureDelegate = [[CaptureDelegate alloc] initWithSettings:settings
      captureAnimation:[uiDelegate captureAnimation]
      livePhotoHandler:^(BOOL capturing) {
        // 라이브포토 카운드 관리
        if (capturing) {
          self.inProgressLivePhotoCapturesCount++;
        } else {
          self.inProgressLivePhotoCapturesCount--;
        }

        NSInteger inProgressLivePhotoCapturesCount = self.inProgressLivePhotoCapturesCount;
        dispatch_async(dispatch_get_main_queue(), ^{
          if (inProgressLivePhotoCapturesCount > 0) {  // 라이브포토촬영이 진행중
            [uiDelegate capturingLivePhoto:YES];
          } else if (inProgressLivePhotoCapturesCount == 0) {  // 라이브포토촬영 완료
            [uiDelegate capturingLivePhoto:NO];
          } else {
            NSLog(@"Error: In progress live photo capture count is less than "
                  @"0");
          }
        });
      }
      complete:^(CaptureDelegate *delegate) {  // 촬영완료
        dispatch_async([Camera sessionQueue], ^{
          // 촬영을 완료한 CaptureDelegate는 더 이상 필요없기 때문에 inProgressPhotoCaptureDelegates dictionary에서
          // 제거한다.
          self.inProgressPhotoCaptureDelegates[@(delegate.requestedPhotoSettings.uniqueID)] = nil;
        });
        dispatch_async(dispatch_get_main_queue(), ^{
          if (complete) {
            complete(delegate.previewImage);
          }
        });
      }];

  // 생성된 CaptureDelegate를 strong하게 가지고 있기위해 inProgressPhotoCaptureDelegates dictionary에 저장한다.
  self.inProgressPhotoCaptureDelegates[@(captureDelegate.requestedPhotoSettings.uniqueID)] = captureDelegate;

  // 캡쳐시작
  [self.photoOutput capturePhotoWithSettings:settings delegate:captureDelegate];
}

// 비디오촬영 중 인지 확인
- (BOOL)isRecording {
  return self.movieFileOutput.isRecording;
}

// 비디오촬영 중 스냅샷이 가능한지 확인
- (BOOL)availableSnapShot {
  return (self.cameraDiscoverySession.uniqueDevicePositionsCount > 1);
}

// 비디오촬영 시작
- (void)startVideoRecording:(id<CameraCaptureUIDelegate>)uiDelegate complete:(void (^)(BOOL success))complete {
  NSAssert(uiDelegate, @"uiDelegate can't be nil");
  _videoRecordingComplete = complete;
  // 현재 카메라화면의 오리엔테이션을 가져온다.
  AVCaptureVideoOrientation videoPreviewLayerVideoOrientation = [uiDelegate captureOrientation];
  dispatch_async([Camera sessionQueue], ^{
    if (!self.movieFileOutput.isRecording) {                   // 촬영중이 아니라면 촬영시작
      if ([UIDevice currentDevice].isMultitaskingSupported) {  // 멀티태스킹지원시 백그라운드 설정
        self.backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
      }

      // 현재 비디오화면의 오리엔테이션 적용
      AVCaptureConnection *movieFileOutputConnection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
      movieFileOutputConnection.videoOrientation = videoPreviewLayerVideoOrientation;

      // HEVC 코덱이 지원된다면 사용
      if (@available(iOS 11.0, *)) {
        if ([self.movieFileOutput.availableVideoCodecTypes containsObject:AVVideoCodecTypeHEVC]) {
          [self.movieFileOutput setOutputSettings:@{
            AVVideoCodecKey : AVVideoCodecTypeHEVC
          }
                                    forConnection:movieFileOutputConnection];
        }
      }

      // 촬영하는 영상은 임의의 스트링으로 임시저장폴더에 저장한다.
      NSString *outputFileName = [NSUUID UUID].UUIDString;
      NSString *outputFilePath = [NSTemporaryDirectory()
          stringByAppendingPathComponent:[outputFileName stringByAppendingPathExtension:@"mov"]];

      // 비디오촬영 시작
      [self.movieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath]
                                        recordingDelegate:self];
    }
  });
}

// 비디오촬영 종료
- (void)stopVideoRecording {
  if (self.movieFileOutput.isRecording) {
    [self.movieFileOutput stopRecording];
  }
}

#pragma mark - AVCaptureFileOutputRecordingDelegate

// 비디오촬영이 시작되면 호출되는 함수
- (void)captureOutput:(AVCaptureFileOutput *)output
    didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                       fromConnections:(NSArray<AVCaptureConnection *> *)connections {
}

// 비디오촬영이 종료되면 호출되는 함수
- (void)captureOutput:(AVCaptureFileOutput *)output
    didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                        fromConnections:(NSArray<AVCaptureConnection *> *)connections
                                  error:(nullable NSError *)error {
  // 백그라운드 태스크 종료
  UIBackgroundTaskIdentifier currentBackgroundRecordingID = self.backgroundRecordingID;
  self.backgroundRecordingID = UIBackgroundTaskInvalid;

  // 촬영종료 후 초기화과정 코드블록 (임시저장파일 삭제 및 백그라운드가 종료되지 않은 경우 백그라운드태스크 종료)
  dispatch_block_t cleanUp = ^{
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputFileURL.path]) {
      [[NSFileManager defaultManager] removeItemAtPath:outputFileURL.path error:NULL];
    }

    if (currentBackgroundRecordingID != UIBackgroundTaskInvalid) {
      [[UIApplication sharedApplication] endBackgroundTask:currentBackgroundRecordingID];
    }
  };

  BOOL success = YES;
  if (error) {  // 에러로 비디오촬영종료 성공여부 확인
    NSLog(@"Movie file finishing error: %@", error);
    success = [error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] boolValue];
  }

  // 비디오촬영 성공여부 알림
  if (_videoRecordingComplete) {
    _videoRecordingComplete(success);
    _videoRecordingComplete = nil;
  }

  if (success) {  // 성공적으로 촬영이 종료되었다면 영상저장
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
      if (status == PHAuthorizationStatusAuthorized) {
        // Save the movie file to the photo library and cleanup.
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
          PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
          options.shouldMoveFile = YES;
          PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAsset];
          [creationRequest addResourceWithType:PHAssetResourceTypeVideo fileURL:outputFileURL options:options];
        }
            completionHandler:^(BOOL success, NSError *error) {
              if (!success) {
                NSLog(@"Could not save movie to photo library: %@", error);
              }
              cleanUp();
            }];
      } else {
        cleanUp();
      }
    }];
  } else {
    cleanUp();
  }
}

#pragma mark - camera options

// sync하게 카메라/비디오 모드 설정
- (void)setMode:(CameraMode)mode {
  if (_mode != mode) {
    _mode = mode;
    [self configureCaptureSessionForMode:_mode andPosition:AVCaptureDevicePositionUnspecified error:nil];
  }
}

// async하게 카메라/비디오 모드 설정
- (void)setMode:(CameraMode)mode complete:(void (^)(void))complete {
  dispatch_async([Camera sessionQueue], ^{
    self.mode = mode;
    if (complete) complete();
  });
}

// sync하게 카메라 전/후면 설정
- (void)setPosition:(AVCaptureDevicePosition)position {
  if (_position != position) {
    _position = position;
    [self configureCaptureSessionForMode:CameraModeUnknown andPosition:_position error:nil];
  }
}

// async하게 카메라 전/후면 설정
- (void)setPosition:(AVCaptureDevicePosition)position complete:(void (^)(void))complete {
  dispatch_async([Camera sessionQueue], ^{
    self.position = position;
    if (complete) complete();
  });
}

// flashMode 설정
- (void)setFlashMode:(AVCaptureFlashMode)flashMode {
  if (_flashMode != flashMode) {
    _flashMode = flashMode;
  }
}

// torchMode 설정
- (void)setTorchMode:(AVCaptureTorchMode)torchMode {
  if (_torchMode != torchMode) {
    AVCaptureDevice *device = self.cameraDevice;
    if ([device isTorchModeSupported:torchMode]) {
      _torchMode = torchMode;
      dispatch_async([Camera sessionQueue], ^{
        NSError *error;
        if ([device lockForConfiguration:&error]) {
          device.torchMode = torchMode;
          [device unlockForConfiguration];
        } else {
          NSLog(@"Could not lock device for configuration: %@", error);
        }
      });
    }
  }
}

// focus 설정
- (void)setFocusMode:(AVCaptureFocusMode)focusMode {
  if (_focusMode != focusMode) {
    AVCaptureDevice *device = self.cameraDevice;
    if ([device isFocusModeSupported:focusMode]) {
      _focusMode = focusMode;
      dispatch_async([Camera sessionQueue], ^{
        NSError *error;
        if ([device lockForConfiguration:&error]) {
          device.focusMode = focusMode;
          [device unlockForConfiguration];
        } else {
          NSLog(@"Could not lock device for configuration: %@", error);
        }
      });
    }
  }
}

- (void)setExposureMode:(AVCaptureExposureMode)exposureMode {
  if (_exposureMode != exposureMode) {
    AVCaptureDevice *device = self.cameraDevice;
    if ([device isExposureModeSupported:exposureMode]) {
      _exposureMode = exposureMode;
      dispatch_async([Camera sessionQueue], ^{
        NSError *error;
        if ([device lockForConfiguration:&error]) {
          device.exposureMode = exposureMode;
          [device unlockForConfiguration];
        } else {
          NSLog(@"Could not lock device for configuration: %@", error);
        }
      });
    }
  }
}

- (void)setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode {
  if (_whiteBalanceMode != whiteBalanceMode) {
    AVCaptureDevice *device = self.cameraDevice;
    if ([device isWhiteBalanceModeSupported:whiteBalanceMode]) {
      _whiteBalanceMode = whiteBalanceMode;
      dispatch_async([Camera sessionQueue], ^{
        NSError *error;
        if ([device lockForConfiguration:&error]) {
          device.whiteBalanceMode = whiteBalanceMode;
          [device unlockForConfiguration];
        } else {
          NSLog(@"Could not lock device for configuration: %@", error);
        }
      });
    }
  }
}

- (void)setFocusExposurePoint:(CGPoint)point {
  [self adjustFocusAndExposureAtDevicePoint:point monitorSubjectAreaChange:YES];
}

- (void)adjustFocusAndExposureAtDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange {
  dispatch_async([Camera sessionQueue], ^{
    AVCaptureDevice *device = self.cameraDevice;
    NSError *error = nil;
    if ([device lockForConfiguration:&error]) {
      /*
       Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
       Call set(Focus/Exposure)Mode() to apply the new point of interest.
       */
      if (device.isFocusPointOfInterestSupported) {
        device.focusPointOfInterest = point;
      }

      if (device.isExposurePointOfInterestSupported) {
        device.exposurePointOfInterest = point;
      }
      device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
      [device unlockForConfiguration];
    } else {
      NSLog(@"Could not lock device for configuration: %@", error);
    }
  });
}

- (void)setVideoStabilizationMode:(AVCaptureVideoStabilizationMode)videoStabilizationMode {
  if (_videoStabilizationMode != videoStabilizationMode) {
    _videoStabilizationMode = videoStabilizationMode;
  }
}

- (void)setLivePhotoEnable:(BOOL)livePhotoEnable {
  if (_livePhotoEnable != livePhotoEnable) {
    _livePhotoEnable = livePhotoEnable;
  }
}

- (BOOL)depthDataDeliverySupports {
  if (@available(iOS 11.0, *)) {
    return self.photoOutput.depthDataDeliverySupported;
  } else {
    return NO;
  }
}

- (void)setDepthDataDeliveryEnable:(BOOL)depthDataDeliveryEnable {
  if (@available(iOS 11.0, *)) {
    if (_depthDataDeliveryEnable != depthDataDeliveryEnable) {
      _depthDataDeliveryEnable = depthDataDeliveryEnable;
    }
  } else {
    _depthDataDeliveryEnable = NO;
  }
}

- (BOOL)portraitEffectsMatteSupports {
  if (@available(iOS 12.0, *)) {
    return self.photoOutput.portraitEffectsMatteDeliverySupported;
  } else {
    return NO;
  }
}

- (void)setPortraitEffectsMatteEnable:(BOOL)portraitEffectsMatteEnable {
  if (@available(iOS 12.0, *)) {
    if (_portraitEffectsMatteEnable != portraitEffectsMatteEnable) {
      _portraitEffectsMatteEnable = portraitEffectsMatteEnable;
    }
    if (_portraitEffectsMatteEnable && !_depthDataDeliveryEnable) {
      self.depthDataDeliveryEnable = YES;
    }
  } else {
    _portraitEffectsMatteEnable = NO;
  }
}

- (void)setPhotoStabilizationEnable:(BOOL)photoStabilizationEnable {
  if (_photoStabilizationEnable != photoStabilizationEnable) {
    _photoStabilizationEnable = photoStabilizationEnable;
  }
}

- (void)setPhotoFormat:(PhotoFormat)photoFormat {
  if (_photoFormat != photoFormat) {
    _photoFormat = photoFormat;
  }
}

- (void)setPreviewPhotoSize:(CGSize)previewPhotoSize {
  if (!CGSizeEqualToSize(_previewPhotoSize, previewPhotoSize)) {
    _previewPhotoSize = previewPhotoSize;
  }
}

#pragma mark - manual camera

- (CGFloat)aperture {
  return self.cameraDevice.lensAperture;
}

- (CGFloat)focus {
  return self.cameraDevice.lensPosition;
}

- (void)setFocus:(CGFloat)focus {
  if (!floatsAreEquivalentEpsilon(focus, self.cameraDevice.lensPosition, 4.0e-3)) {
    dispatch_async([Camera sessionQueue], ^{
      NSError *error;
      if ([self.cameraDevice lockForConfiguration:&error]) {
        if ([self.cameraDevice isLockingFocusWithCustomLensPositionSupported]) {
          [self.cameraDevice setFocusModeLockedWithLensPosition:focus
                                              completionHandler:^(CMTime syncTime){
                                              }];
        }
        [self.cameraDevice unlockForConfiguration];
      } else {
        NSLog(@"Could not lock device for configuration: %@", error);
      }
    });
  }
}

- (CGFloat)minExposureISO {
  return self.cameraDevice.activeFormat.minISO;
}

- (CGFloat)maxExposureISO {
  return self.cameraDevice.activeFormat.maxISO;
}

- (CGFloat)exposureISO {
  return self.cameraDevice.ISO;
}

- (void)setExposureISO:(CGFloat)exposureISO {
  if (self.cameraDevice.exposureMode != AVCaptureExposureModeCustom) return;
  if (_iso != exposureISO) {
    _iso = exposureISO;
    [self commitExposureCompletion:nil];
  }
}

- (CGFloat)minExposureDuration {
  return CMTimeGetSeconds(self.cameraDevice.activeFormat.minExposureDuration);
}

- (CGFloat)maxExposureDuration {
  return CMTimeGetSeconds(self.cameraDevice.activeFormat.maxExposureDuration);
}

- (CGFloat)exposureDuration {
  return CMTimeGetSeconds(self.cameraDevice.exposureDuration);
}

- (void)setExposureDuration:(CGFloat)exposureDuration {
  if (self.cameraDevice.exposureMode != AVCaptureExposureModeCustom) return;
  if (_duration != exposureDuration) {
    _duration = exposureDuration;
    [self commitExposureCompletion:nil];
  }
}

- (void)commitExposureISO:(CGFloat)exposureISO exposureDuration:(CGFloat)exposureDuration {
  if (self.cameraDevice.exposureMode != AVCaptureExposureModeCustom) return;
  if (_iso != exposureISO || _duration != exposureDuration) {
    _iso = exposureISO;
    _duration = exposureDuration;
    [self commitExposureCompletion:nil];
  }
}

- (void)commitExposureCompletion:(void (^)(void))completion {
  if (self.cameraDevice.exposureMode != AVCaptureExposureModeCustom) return;
  dispatch_async([Camera sessionQueue], ^{
    NSError *error;
    if ([self.cameraDevice lockForConfiguration:&error]) {
      CGFloat iso = MIN(MAX(self.iso, self.minExposureISO), self.maxExposureISO);
      NSInteger value =
          (NSInteger)(MIN(MAX(self.duration, self.minExposureDuration), self.maxExposureDuration) * kTimeScale);
      CMTime duration = CMTimeMake(value, kTimeScale);
      [self.cameraDevice setExposureModeCustomWithDuration:duration
                                                       ISO:iso
                                         completionHandler:^(CMTime syncTime) {
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                             if (completion) {
                                               completion();
                                             }
                                           });
                                         }];
      [self.cameraDevice unlockForConfiguration];
    }
  });
}

- (CGFloat)minWhiteBalanceGain {
  return 1.0;
}

- (CGFloat)maxWhiteBalanceGain {
  return self.cameraDevice.maxWhiteBalanceGain;
}

- (AVCaptureWhiteBalanceGains)whiteBalanceGains {
  return self.cameraDevice.deviceWhiteBalanceGains;
}

- (void)setWhiteBalanceGains:(AVCaptureWhiteBalanceGains)whiteBalanceGains {
  AVCaptureDevice *device = self.cameraDevice;
  if ([device isLockingWhiteBalanceWithCustomDeviceGainsSupported]) {
    dispatch_async([Camera sessionQueue], ^{
      NSError *error;
      AVCaptureWhiteBalanceGains newGain;
      newGain.redGain = MIN(whiteBalanceGains.redGain, device.maxWhiteBalanceGain);
      newGain.greenGain = MIN(whiteBalanceGains.greenGain, device.maxWhiteBalanceGain);
      newGain.blueGain = MIN(whiteBalanceGains.blueGain, device.maxWhiteBalanceGain);
      if ([device lockForConfiguration:&error]) {
        [device setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:newGain completionHandler:nil];
        [device unlockForConfiguration];
      } else {
        NSLog(@"Could not lock device for configuration: %@", error);
      }
    });
  }
}

#pragma mark - private functions
- (AVCaptureDeviceFormat *)currentFormat {
  return self.cameraDevice.activeFormat;
}

- (AVCaptureDeviceDiscoverySession *)cameraDiscoverySession {
  if (!_cameraDiscoverySession) {
    NSArray<AVCaptureDeviceType> *deviceTypes;
    if (@available(iOS 11.1, *)) {
      deviceTypes = @[
        AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInDualCamera,
        AVCaptureDeviceTypeBuiltInTrueDepthCamera
      ];
    } else {
      deviceTypes = @[ AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInDualCamera ];
    }
    _cameraDiscoverySession =
        [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes
                                                               mediaType:AVMediaTypeVideo
                                                                position:AVCaptureDevicePositionUnspecified];
  }
  return _cameraDiscoverySession;
}

- (BOOL)configureCaptureSessionForMode:(CameraMode)mode
                           andPosition:(AVCaptureDevicePosition)position
                                 error:(NSError **)error {
  if (!self.captureSession) {  // 캡쳐세션이 없는 경우 생성
    self.captureSession = [[AVCaptureSession alloc] init];
  }

  [self.captureSession beginConfiguration];  // 캡셔설정 시작

  if (mode == CameraModePhoto) {  // 사진모드인 경우
    if (self.movieFileOutput) {  // 기존 비디오파일출력이 있으면 제거(사진모드에서는 필요없음)
      [self.captureSession removeOutput:self.movieFileOutput];
      self.movieFileOutput = nil;
    }
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;  // 사진모드 프리셋 설정
  } else if (mode == CameraModeVideo) {                               // 비디오모드인 경우
    // 비디오파일출력을 생성하여 캡쳐세션에 연결한다.
    AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ([self.captureSession canAddOutput:movieFileOutput]) {
      [self.captureSession addOutput:movieFileOutput];

      // 비디오안정화기능이 지원되면 적용
      AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
      if (connection.isVideoStabilizationSupported) {
        connection.preferredVideoStabilizationMode = self.videoStabilizationMode;
      }
      self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;  // 비디오 프리셋 설정
      self.movieFileOutput = movieFileOutput;
    }
  }

  // 전/후면 카메라설정에만
  if (position != AVCaptureDevicePositionUnspecified) {
    // 해당 포지션의 카메라디바이스를 가져온다.
    AVCaptureDevice *newDevice = [self cameraDeviceWithPosition:position error:error];
    if (!newDevice) return NO;

    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:newDevice error:error];
    if (!videoInput) return NO;

    // 기존 영상입력이 있는 경우 먼저 제거 후 생성한 영상입력을 캡쳐세션에 연결한다.
    if (self.videoInput) {
      [self.captureSession removeInput:self.videoInput];
    }
    if ([self.captureSession canAddInput:videoInput]) {
      [self.captureSession addInput:videoInput];
    } else {
      *error = [Camera errorWithInfoString:@"Failed to connect video input"];
      return NO;
    }
    self.cameraDevice = newDevice;
    self.videoInput = videoInput;
  }

  // 오디오입력이 없는 경우 생성
  if (!self.audioInput) {
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    self.audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:error];
    // 오디오입력을 캡쳐세션에 연결
    if ([self.captureSession canAddInput:self.audioInput]) {
      [self.captureSession addInput:self.audioInput];
    }
  }

  // 사진출력이 없는 경우 생성
  if (!self.photoOutput) {
    self.photoOutput = [[AVCapturePhotoOutput alloc] init];
    self.photoOutput.highResolutionCaptureEnabled = YES;
    // 사진출력을 캡쳐세션에 연결
    if ([self.captureSession canAddOutput:self.photoOutput]) {
      [self.captureSession addOutput:self.photoOutput];
    } else {
      *error = [Camera errorWithInfoString:@"Failed to connect photo output"];
      return NO;
    }
  }

  // 사진출력 옵션설정
  self.photoOutput.livePhotoCaptureEnabled = self.photoOutput.livePhotoCaptureSupported;
  if (@available(iOS 11.0, *)) {
    self.photoOutput.depthDataDeliveryEnabled = self.photoOutput.depthDataDeliverySupported;
  }
  if (@available(iOS 12.0, *)) {
    self.photoOutput.portraitEffectsMatteDeliveryEnabled = self.photoOutput.portraitEffectsMatteDeliverySupported;
  }

  [self.captureSession commitConfiguration];
  return YES;
}

- (AVCaptureDevice *)cameraDeviceWithPosition:(AVCaptureDevicePosition)devicePosition error:(NSError **)error {
  AVCaptureDeviceType deviceType;
  if (devicePosition == AVCaptureDevicePositionFront) {
    if (@available(iOS 11.1, *)) {
      deviceType = AVCaptureDeviceTypeBuiltInTrueDepthCamera;
    } else {
      deviceType = AVCaptureDeviceTypeBuiltInWideAngleCamera;
    }
  } else {
    deviceType = AVCaptureDeviceTypeBuiltInWideAngleCamera;  // AVCaptureDeviceTypeBuiltInDualCamera;
  }

  AVCaptureDevice *newCameraDevice = nil;
  NSArray<AVCaptureDevice *> *devices = self.cameraDiscoverySession.devices;

  for (AVCaptureDevice *device in devices) {
    if (device.position == devicePosition && [device.deviceType isEqualToString:deviceType]) {
      newCameraDevice = device;
      break;
    }
  }

  if (!newCameraDevice) {
    for (AVCaptureDevice *device in devices) {
      if (device.position == devicePosition) {
        newCameraDevice = device;
        break;
      }
    }
  }
  if (!newCameraDevice) {
    NSString *reason = [NSString stringWithFormat:@"Failed to get camera device for position:%@",
                                                  devicePosition == AVCaptureDevicePositionBack ? @"Back" : @"Front"];
    *error = [Camera errorWithInfoString:reason];
  }
  return newCameraDevice;
}

- (void)setCameraDevice:(AVCaptureDevice *)cameraDevice {
  if (_cameraDevice != cameraDevice) {
    _cameraDevice = cameraDevice;
    if (_cameraDevice) {
      _iso = _cameraDevice.ISO;
      _duration = CMTimeGetSeconds(_cameraDevice.exposureDuration);
    } else {
      _iso = -1.0;
      _duration = -1.0;
    }
  }
}

- (AVCapturePhotoSettings *)configurePhotoSetting {
  // 설정된 PhotoFormat에 따라 AVCapturePhotoSettings 생성
  AVCapturePhotoSettings *setting;
  if (@available(iOS 11.0, *)) {
    // HEIF
    if (self.photoFormat == PhotoFormatHEIF &&
        [self.photoOutput.availablePhotoCodecTypes containsObject:AVVideoCodecTypeHEVC]) {
      setting = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey : AVVideoCodecTypeHEVC}];
      setting.autoStillImageStabilizationEnabled = self.photoStabilizationEnable;
    }
    // JPEG
    else if (self.photoFormat == PhotoFormatJPEG &&
             [self.photoOutput.availablePhotoCodecTypes containsObject:AVVideoCodecTypeJPEG]) {
      setting = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey : AVVideoCodecTypeJPEG}];
      setting.autoStillImageStabilizationEnabled = self.photoStabilizationEnable;
    }
    // RAW
    else if (self.photoFormat == PhotoFormatRAW && self.photoOutput.availableRawPhotoPixelFormatTypes.count > 0) {
      NSNumber *rawFileType = self.photoOutput.availableRawPhotoPixelFormatTypes.firstObject;
      setting = [AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:(OSType)rawFileType.integerValue];
      setting.autoStillImageStabilizationEnabled = NO;
    }
    // RAW + HEIF
    else if (self.photoFormat == PhotoFormatRAWHEIF &&
             [self.photoOutput.availablePhotoCodecTypes containsObject:AVVideoCodecTypeHEVC] &&
             self.photoOutput.availableRawPhotoPixelFormatTypes.count > 0) {
      NSNumber *rawFileType = self.photoOutput.availableRawPhotoPixelFormatTypes.firstObject;
      setting = [AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:(OSType)rawFileType.integerValue
                                                            processedFormat:@{AVVideoCodecKey : AVVideoCodecTypeHEVC}];
      setting.autoStillImageStabilizationEnabled = NO;
    }
    // RAW + JPEG
    else if (self.photoFormat == PhotoFormatRAWJPEG &&
             [self.photoOutput.availablePhotoCodecTypes containsObject:AVVideoCodecTypeJPEG] &&
             self.photoOutput.availableRawPhotoPixelFormatTypes.count > 0) {
      NSNumber *rawFileType = self.photoOutput.availableRawPhotoPixelFormatTypes.firstObject;
      setting = [AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:(OSType)rawFileType.integerValue
                                                            processedFormat:@{AVVideoCodecKey : AVVideoCodecTypeJPEG}];
      setting.autoStillImageStabilizationEnabled = NO;
    }
  }

  // 위 포맷에 따른 설정생성이 모두 불가능한 경우
  if (!setting) {
    setting = [AVCapturePhotoSettings photoSettings];
  }

  // flash 모드적용
  if (self.cameraDevice.isFlashAvailable) {
    [[self.photoOutput supportedFlashModes] enumerateObjectsUsingBlock:^(NSNumber *mode, NSUInteger idx, BOOL *stop) {
      if (mode.integerValue == self.flashMode) {
        setting.flashMode = self.flashMode;
        *stop = YES;
      }
    }];
  }

  setting.highResolutionPhotoEnabled = YES;  // 해상도 최대로 사용?

  // previewPhoto(thumbnail) 관련 설정
  if (setting.availablePreviewPhotoPixelFormatTypes.count > 0) {
    NSMutableDictionary *previewPhotoInfo = [NSMutableDictionary dictionary];
    [previewPhotoInfo setObject:setting.availablePreviewPhotoPixelFormatTypes.firstObject
                         forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    [previewPhotoInfo setObject:@(self.previewPhotoSize.width) forKey:(NSString *)kCVPixelBufferWidthKey];
    [previewPhotoInfo setObject:@(self.previewPhotoSize.height) forKey:(NSString *)kCVPixelBufferHeightKey];
    [setting setPreviewPhotoFormat:previewPhotoInfo];
  }

  // 라이브포토설정, 라이브포토를 임시저장해놓을 경로설정
  if (self.livePhotoEnable && self.photoOutput.livePhotoCaptureSupported) {
    NSString *livePhotoMovieFileName = [NSUUID UUID].UUIDString;
    NSString *livePhotoMovieFilePath = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[livePhotoMovieFileName stringByAppendingPathExtension:@"mov"]];
    setting.livePhotoMovieFileURL = [NSURL fileURLWithPath:livePhotoMovieFilePath];
  } else {
    setting.livePhotoMovieFileURL = nil;
  }

  // depth data 설정
  if (@available(iOS 11.0, *)) {
    if (self.depthDataDeliveryEnable && self.photoOutput.depthDataDeliverySupported) {
      setting.depthDataDeliveryEnabled = YES;
    } else {
      setting.depthDataDeliveryEnabled = NO;
    }
  }

  // portraitEffectsMatte 설정
  if (@available(iOS 12.0, *)) {
    if (self.portraitEffectsMatteEnable && self.photoOutput.portraitEffectsMatteDeliverySupported) {
      setting.portraitEffectsMatteDeliveryEnabled = YES;
    } else {
      setting.portraitEffectsMatteDeliveryEnabled = NO;
    }
  }

  return setting;
}

#pragma mark KVO and Notifications
- (void)addObservers {
  // 카메라화면에 많은 변화가 생기면 호출되는 노티피케이션 등록
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(subjectAreaDidChange:)
                                               name:AVCaptureDeviceSubjectAreaDidChangeNotification
                                             object:self.cameraDevice];

  // 캡쳐세션에 에러발생 시 호출되는 노티피케이션 등록
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(sessionRuntimeError:)
                                               name:AVCaptureSessionRuntimeErrorNotification
                                             object:self.captureSession];

#if USE_INTERRUPTION_NOTIFICATION
  // 캡쳐세션에 인터럽트가 걸리면 호출되는 노티피케이션 등록
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(captureSessionWasInterrupted:)
                                               name:AVCaptureSessionWasInterruptedNotification
                                             object:self.captureSession];

  // 캡쳐세션 인터럽트가 끝나면 호출되는 노티피케이션 등록
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(captureSessionInterruptionEnded:)
                                               name:AVCaptureSessionInterruptionEndedNotification
                                             object:self.captureSession];
#endif
}

- (void)removeObservers {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)sessionRuntimeError:(NSNotification *)notification { // 캡쳐세션 에러발생 시
  NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
  NSLog(@"Capture session runtime error: %@", error);
  
  if (error.code == AVErrorMediaServicesWereReset) { // 미디어서비스가 리셋된경우
    dispatch_async([Camera sessionQueue], ^{
      if (self.sessionRunning) { // 기존 캡쳐세션이 작동하고 있었으면 다시 시작
        [self startCapture];
      }
    });
  }
}

- (void)subjectAreaDidChange:(NSNotification *)notification { // 카메라화면에 많은 변화가 있으면 다시 포커스와 밝기를 맞춘다.
  [self adjustFocusAndExposureAtDevicePoint:CGPointMake(0.5, 0.5) monitorSubjectAreaChange:NO];
}

#if USE_INTERRUPTION_NOTIFICATION
- (void)captureSessionWasInterrupted:(NSNotification *)notification {
  
}

- (void)captureSessionInterruptionEnded:(NSNotification *)notification {
  
}
#endif

- (NSArray<NSString *> *)observingPropertyList {
  return @[
           @"mode",
           @"position",
           @"flash",
           @"focus",
           @"exposureISO",
           @"exposureDuration",
           @"whiteBalanceGains",
           @"videoStabilizationMode",
           @"livePhotoEnable",
           @"depthDataDeliveryEnable",
           @"portraitEffectsMatteEnable",
           @"lensStabilizationEnable",
           @"photoFormat"
           ];
}

- (void)addObserver:(NSObject *)observer {
  if ([observer respondsToSelector:@selector(observeValueForKeyPath:ofObject:change:context:)]) {
    [[self observingPropertyList] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      [self addObserver:observer forKeyPath:obj options:NSKeyValueObservingOptionNew context:nil];
    }];
  } else {
    NSAssert(nil, @"Please, implement observeValueForKeyPath:ofObject:change:context: function.");
  }
}

- (void)removeObserver:(NSObject *)observer {
  if (observer && [self observationInfo]) {
    @try {
      [[self observingPropertyList] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self removeObserver:observer forKeyPath:obj context:nil];
      }];
    }
    @catch (NSException *exception) {}
  }
}

#pragma mark - error handling

+ (NSError *)errorWithInfoString:(NSString *)infoString {
  NSDictionary *errorInfo;
  if (infoString) {
    errorInfo = @{NSLocalizedDescriptionKey : infoString};
  }
  return [NSError errorWithDomain:@"Camera" code:-1 userInfo:errorInfo];
}

@end
