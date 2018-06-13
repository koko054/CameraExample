//
//  Camera.m
//  CameraExample
//
//  Created by 김도범 on 2018. 5. 19..
//  Copyright © 2018년 DobumKim. All rights reserved.
//

#import "Camera.h"
#import "CaptureDelegate.h"
#import <UIKit/UIKit.h>

@import Photos;

static void *SessionRunningContext = &SessionRunningContext;

@interface Camera ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate>

@property(nonatomic, strong) AVCaptureDeviceDiscoverySession *cameraDiscoverySession;
@property(nonatomic, strong) AVCaptureSession *captureSession;
@property(nonatomic, strong) AVCaptureDevice *cameraDevice;
@property(nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property(nonatomic, strong) AVCapturePhotoOutput *photoOutput;

@property(nonatomic) NSMutableDictionary<NSNumber *, CaptureDelegate *> *inProgressPhotoCaptureDelegates;
@property(nonatomic) NSInteger inProgressLivePhotoCapturesCount;

@property(nonatomic, copy) void (^videoRecordingComplete)(BOOL success);
@property(nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;
@property(nonatomic, assign) UIBackgroundTaskIdentifier backgroundRecordingID;

@end

@implementation Camera

#pragma mark - initialize

+ (dispatch_queue_t)sessionQueue {
  static dispatch_queue_t sessionQueue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (!sessionQueue) sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
  });
  return sessionQueue;
}

+ (void)configureCamera:(void (^)(Camera *camera, NSError *error))complete {
  if (!complete) return;
  dispatch_async([Camera sessionQueue], ^{
    NSError *error;
    Camera *camera = [[Camera alloc] initWithMode:CameraModePhoto position:AVCaptureDevicePositionBack error:&error];
    complete(camera, error);
  });
}

+ (void)congifureCameraWithMode:(CameraMode)mode
                       position:(AVCaptureDevicePosition)position
                       complete:(void (^)(Camera *camera, NSError *error))complete {
  if (!complete) return;
  dispatch_async([Camera sessionQueue], ^{
    NSError *error;
    Camera *camera = [[Camera alloc] initWithMode:mode position:position error:&error];
    complete(camera, error);
  });
}

- (instancetype)init {
  return [self initWithMode:CameraModePhoto position:AVCaptureDevicePositionBack error:nil];
}

- (instancetype)initWithMode:(CameraMode)mode position:(AVCaptureDevicePosition)position error:(NSError **)error {
  if (self = [super init]) {
    _mode = mode;
    _position = position;
    _flash = AVCaptureFlashModeAuto;
    _livePhotoEnable = NO;
    _depthDataDeliveryEnable = NO;


    AVCaptureSessionPreset preset = mode == CameraModePhoto ? AVCaptureSessionPresetPhoto : AVCaptureSessionPresetHigh;

    [self.captureSession beginConfiguration];
    self.captureSession.sessionPreset = preset;

    if (![self configureCamera:error]) {
      [self.captureSession commitConfiguration];
      return nil;
    }

    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:error];

    if ([self.captureSession canAddInput:audioInput]) {
      [self.captureSession addInput:audioInput];
    }

    if ([self.captureSession canAddOutput:self.photoOutput]) {
      [self.captureSession addOutput:self.photoOutput];
    } else {
      [self.captureSession commitConfiguration];
      return nil;
    }

    self.backgroundRecordingID = UIBackgroundTaskInvalid;
    
    [self.captureSession commitConfiguration];

    self.inProgressPhotoCaptureDelegates = [NSMutableDictionary dictionary];
    self.inProgressLivePhotoCapturesCount = 0;
  }
  return self;
}

#pragma mark - public functions
- (AVCaptureSession *)session {
  return self.captureSession;
}

- (CGSize)resolution {
  return CGSizeMake(self.currentFormat.highResolutionStillImageDimensions.width,
                    self.currentFormat.highResolutionStillImageDimensions.height);
}

- (void)startCapture {
  [self.captureSession startRunning];
}

- (void)stopCapture {
  [self.captureSession stopRunning];
}

- (void)takePhotoWithDelegate:(id<CameraCaptureUIDelegate>)uiDelegate complete:(void (^)(void))complete {
  NSAssert(uiDelegate, @"uiDelegate can't be nil");
  dispatch_async([Camera sessionQueue], ^{
    AVCaptureConnection *photoOutputConnection = [self.photoOutput connectionWithMediaType:AVMediaTypeVideo];
    photoOutputConnection.videoOrientation = [uiDelegate captureOrientation];

    AVCapturePhotoSettings *settings = [self configurePhotoSetting];

    CaptureDelegate *captureDelegate = [[CaptureDelegate alloc] initWithSettings:settings
        captureAnimation:[uiDelegate captureAnimation]
        livePhotoHandler:^(BOOL capturing) {
          if (capturing) {
            self.inProgressLivePhotoCapturesCount++;
          } else {
            self.inProgressLivePhotoCapturesCount--;
          }

          NSInteger inProgressLivePhotoCapturesCount = self.inProgressLivePhotoCapturesCount;
          dispatch_async(dispatch_get_main_queue(), ^{
            if (inProgressLivePhotoCapturesCount > 0) {
              [uiDelegate capturingLivePhoto:YES];
            } else if (inProgressLivePhotoCapturesCount == 0) {
              [uiDelegate capturingLivePhoto:NO];
            } else {
              NSLog(@"Error: In progress live photo capture count is less than "
                    @"0");
            }
          });
        }
        complete:^(CaptureDelegate *delegate) {
          dispatch_async([Camera sessionQueue], ^{
            self.inProgressPhotoCaptureDelegates[@(delegate.requestedPhotoSettings.uniqueID)] = nil;
          });
        }];
    self.inProgressPhotoCaptureDelegates[@(captureDelegate.requestedPhotoSettings.uniqueID)] = captureDelegate;
    [self.photoOutput capturePhotoWithSettings:settings delegate:captureDelegate];
  });
}

- (BOOL)isRecording {
  return self.movieFileOutput.isRecording;
}

- (void)startVideoRecording:(id<CameraCaptureUIDelegate>)uiDelegate complete:(void (^)(BOOL success))complete {
  NSAssert(uiDelegate, @"uiDelegate can't be nil");
  
  _videoRecordingComplete = complete;
  
  AVCaptureVideoOrientation videoPreviewLayerVideoOrientation = [uiDelegate captureOrientation];

  dispatch_async([Camera sessionQueue], ^{
    if (!self.movieFileOutput.isRecording) {  // 촬영중이 아니라면 촬영시작
      if ([UIDevice currentDevice]
              .isMultitaskingSupported) {  // 멀티태스킹지원시 백그라운드에서 동작할수있도록 백그라운드ID를 받는다.
        self.backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
      }

      // 현재 비디오화면의 오리엔테이션으로 아웃푹오리엔테이션을 업데이트한다.
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
      [self.movieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath]
                                        recordingDelegate:self];
    }
  });
}

- (void)stopVideoRecording {
  if (self.movieFileOutput.isRecording) { // 촬영중이면 촬영종료
    [self.movieFileOutput stopRecording];
  }
}

#pragma mark - AVCaptureFileOutputRecordingDelegate
- (void)captureOutput:(AVCaptureFileOutput *)output
    didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                       fromConnections:(NSArray<AVCaptureConnection *> *)connections {
}

- (void)captureOutput:(AVCaptureFileOutput *)output
    didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                        fromConnections:(NSArray<AVCaptureConnection *> *)connections
                                  error:(nullable NSError *)error {
  UIBackgroundTaskIdentifier currentBackgroundRecordingID = self.backgroundRecordingID;
  self.backgroundRecordingID = UIBackgroundTaskInvalid;
  
  // 촬영종료 후 초기화과정 (임시저장파일 삭제 및 백그라운드태스크 종료 블록)
  dispatch_block_t cleanUp = ^{
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputFileURL.path]) {
      [[NSFileManager defaultManager] removeItemAtPath:outputFileURL.path error:NULL];
    }
    
    if (currentBackgroundRecordingID != UIBackgroundTaskInvalid) {
      [[UIApplication sharedApplication] endBackgroundTask:currentBackgroundRecordingID];
    }
  };
  
  BOOL success = YES;
  if (error) { // 에러로 촬영종료 성공여부 확인
    NSLog(@"Movie file finishing error: %@", error);
    success = [error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] boolValue];
  }
  
  if (_videoRecordingComplete) {
    _videoRecordingComplete(success);
    _videoRecordingComplete = nil;
  }
  if (success) { // 성공적으로 촬영이 종료되었다면 영상저장
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
- (void)switchCamera {
  AVCaptureDevicePosition currentPosition = self.position;
  if (currentPosition == AVCaptureDevicePositionBack) {
    self.position = AVCaptureDevicePositionFront;
  } else {
    self.position = AVCaptureDevicePositionBack;
  }
}

- (void)switchMode {
  CameraMode currentMode = self.mode;
  if (currentMode == CameraModePhoto) {
    self.mode = CameraModeVideo;
  } else {
    self.mode = CameraModePhoto;
  }
}

- (void)switchLivePhoto {
  self.livePhotoEnable = !self.livePhotoEnable;
}

- (void)switchDepthDataDelivery {
  self.depthDataDeliveryEnable = !self.depthDataDeliveryEnable;
}

- (void)setMode:(CameraMode)mode {
  if (_mode != mode) {
    _mode = mode;
    if (_mode == CameraModePhoto) {
      [self.captureSession beginConfiguration];
      [self.captureSession removeOutput:self.movieFileOutput];
      self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
      self.movieFileOutput = nil;
      if (self.photoOutput.livePhotoCaptureSupported) {
        self.photoOutput.livePhotoCaptureEnabled = YES;
      }

      if (@available(iOS 11.0, *)) {
        if (self.photoOutput.depthDataDeliverySupported) {
          self.photoOutput.depthDataDeliveryEnabled = YES;
        }
      }
      [self.captureSession commitConfiguration];
    } else if (_mode == CameraModeVideo) {
      AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
      if ([self.captureSession canAddOutput:movieFileOutput]) {
        [self.captureSession beginConfiguration];
        [self.captureSession addOutput:movieFileOutput];
        AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if (connection.isVideoStabilizationSupported) {
          connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
        [self.captureSession commitConfiguration];
        self.movieFileOutput = movieFileOutput;
      }
    }
  }
}

- (void)setMode:(CameraMode)mode complete:(void (^)(void))complete {
  dispatch_async([Camera sessionQueue], ^{
    self.mode = mode;
    if (complete) complete();
  });
}

- (void)setPosition:(AVCaptureDevicePosition)position {
  if (_position != position) {
    _position = position;
    [self configureCamera:nil];
  }
}

- (void)setPosition:(AVCaptureDevicePosition)position complete:(void (^)(void))complete {
  dispatch_async([Camera sessionQueue], ^{
    self.position = position;
    if (complete) complete();
  });
}

- (void)setFlash:(AVCaptureFlashMode)flash {
  if (_flash != flash) {
    _flash = flash;
  }
}

- (void)setLivePhotoEnable:(BOOL)livePhotoEnable {
  [self setLivePhotoEnable:livePhotoEnable complete:nil];
}

- (void)setLivePhotoEnable:(BOOL)livePhotoEnable complete:(void (^)(void))complete {
  if (_livePhotoEnable != livePhotoEnable) {
    // livePhoto 지원이 안되는데 livePhoto를 활성화할 경우 예외처리
    if (!self.photoOutput.livePhotoCaptureSupported && livePhotoEnable) return;

    _livePhotoEnable = livePhotoEnable;
    dispatch_async([Camera sessionQueue], ^{
      if (complete) complete();
    });
  }
}

- (void)setDepthDataDeliveryEnable:(BOOL)depthDataDeliveryEnable {
  [self setDepthDataDeliveryEnable:depthDataDeliveryEnable complete:nil];
}

- (void)setDepthDataDeliveryEnable:(BOOL)depthDataDeliveryEnable complete:(void (^)(void))complete {
  if (@available(iOS 11.0, *)) {
    if (_depthDataDeliveryEnable != depthDataDeliveryEnable) {
      // depthDataDelivery 지원이 안되는데 deptheDataDelivery를 활성화할 경우
      // 예외처리

      if (!self.photoOutput.depthDataDeliverySupported && depthDataDeliveryEnable) return;

      _depthDataDeliveryEnable = depthDataDeliveryEnable;
      dispatch_async([Camera sessionQueue], ^{
        self.photoOutput.depthDataDeliveryEnabled = depthDataDeliveryEnable;
        if (complete) complete();
      });
    }
  }
}

#pragma mark - private functions
- (AVCaptureDeviceFormat *)currentFormat {
  return self.cameraDevice.activeFormat;
}

- (AVCaptureDeviceDiscoverySession *)cameraDiscoverySession {
  if (!_cameraDiscoverySession) {
    NSArray<AVCaptureDeviceType> *deviceTypes =
        @[ AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInDualCamera ];
    _cameraDiscoverySession =
        [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes
                                                               mediaType:AVMediaTypeVideo
                                                                position:AVCaptureDevicePositionUnspecified];
  }
  return _cameraDiscoverySession;
}

- (AVCaptureSession *)captureSession {
  if (!_captureSession) {
    _captureSession = [[AVCaptureSession alloc] init];
  }
  return _captureSession;
}

- (AVCapturePhotoOutput *)photoOutput {
  if (!_photoOutput) {
    _photoOutput = [[AVCapturePhotoOutput alloc] init];
    _photoOutput.highResolutionCaptureEnabled = YES;
    _photoOutput.livePhotoCaptureEnabled = _photoOutput.livePhotoCaptureSupported;
    if (@available(iOS 11.0, *)) {
      _photoOutput.depthDataDeliveryEnabled = _photoOutput.depthDataDeliverySupported;
    } else {
      _depthDataDeliveryEnable = NO;
    }
  }
  return _photoOutput;
}

- (BOOL)configureCamera:(NSError **)error {
  AVCaptureDeviceType deviceType;
  if (_position == AVCaptureDevicePositionFront) {
    deviceType = AVCaptureDeviceTypeBuiltInWideAngleCamera;
  } else {
    deviceType = AVCaptureDeviceTypeBuiltInDualCamera;
  }

  AVCaptureDevice *newCameraDevice = nil;
  NSArray<AVCaptureDevice *> *devices = self.cameraDiscoverySession.devices;

  for (AVCaptureDevice *device in devices) {
    if (device.position == _position && [device.deviceType isEqualToString:deviceType]) {
      newCameraDevice = device;
      break;
    }
  }

  if (!newCameraDevice) {
    for (AVCaptureDevice *device in devices) {
      if (device.position == _position) {
        newCameraDevice = device;
        break;
      }
    }
  }

  if (newCameraDevice) {
    AVCaptureDeviceInput *newVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:newCameraDevice error:error];
    if (newVideoInput) {
      [self.captureSession beginConfiguration];

      if (self.videoInput) {
        [self.captureSession removeInput:self.videoInput];
      }

      if ([self.captureSession canAddInput:newVideoInput]) {
        [self.captureSession addInput:newVideoInput];
        self.videoInput = newVideoInput;
        self.cameraDevice = newCameraDevice;
      } else if (self.videoInput) {
        [self.captureSession addInput:self.videoInput];
      } else {
        [self.captureSession commitConfiguration];
        return NO;
      }

      [self.captureSession commitConfiguration];
    } else {
      return NO;
    }
  } else {
    return NO;
  }
  return YES;
}

- (AVCapturePhotoSettings *)configurePhotoSetting {
  // AVCapturePhotoSettings 생성
  AVCapturePhotoSettings *setting;
  if (@available(iOS 11.0, *)) {
    if ([self.photoOutput.availablePhotoCodecTypes containsObject:AVVideoCodecTypeHEVC]) {
      setting = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey : AVVideoCodecTypeHEVC}];
    } else {
      setting = [AVCapturePhotoSettings photoSettings];
    }
  } else {
    setting = [AVCapturePhotoSettings photoSettings];
  }

  // flash 모드적용
  if (self.cameraDevice.isFlashAvailable) {
    [[self.photoOutput supportedFlashModes] enumerateObjectsUsingBlock:^(NSNumber *mode, NSUInteger idx, BOOL *stop) {
      if (mode.integerValue == self.flash) {
        setting.flashMode = self.flash;
        *stop = YES;
      }
    }];
  }

  setting.highResolutionPhotoEnabled = YES;  // 해상도 최대로 사용?

  if (setting.availablePreviewPhotoPixelFormatTypes.count > 0) {  // 이건 뭐하는 건지 모르겠다. 예제에 있길래 넣은 코드
    setting.previewPhotoFormat =
        @{(NSString *)kCVPixelBufferPixelFormatTypeKey : setting.availablePreviewPhotoPixelFormatTypes.firstObject};
  }

  // 라이브포토설정, 라이브포토를 임시저장해놓을 경로설정
  if (self.livePhotoEnable && self.photoOutput.livePhotoCaptureSupported) {
    NSString *livePhotoMovieFileName = [NSUUID UUID].UUIDString;
    NSString *livePhotoMovieFilePath = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[livePhotoMovieFileName stringByAppendingPathExtension:@"mov"]];
    setting.livePhotoMovieFileURL = [NSURL fileURLWithPath:livePhotoMovieFilePath];
  }

  // depth data 설정
  if (@available(iOS 11.0, *)) {
    if (self.depthDataDeliveryEnable && self.photoOutput.depthDataDeliverySupported) {
      setting.depthDataDeliveryEnabled = YES;
    } else {
      setting.depthDataDeliveryEnabled = NO;
    }
  }
  
  return setting;
}


@end
