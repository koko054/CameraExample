//
//  Camera.m
//  CameraExample
//
//  Created by 김도범 on 2018. 5. 19..
//  Copyright © 2018년 DobumKim. All rights reserved.
//

#import "Camera.h"

static void *SessionRunningContext = &SessionRunningContext;

@interface Camera ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property(nonatomic, strong) AVCaptureDeviceDiscoverySession *cameraDiscoverySession;
@property(nonatomic, strong) AVCaptureSession *captureSession;
@property(nonatomic, strong) AVCaptureDevice *cameraDevice;
@property(nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property(nonatomic, strong) AVCapturePhotoOutput *photoOutput;
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
    complete(camera,error);
  });
}

+ (void)congifureCameraWithMode:(CameraMode)mode
                       position:(AVCaptureDevicePosition)position
                       complete:(void (^)(Camera *camera, NSError *error))complete {
  if (!complete) return;
  dispatch_async([Camera sessionQueue], ^{
    NSError *error;
    Camera *camera = [[Camera alloc] initWithMode:mode position:position error:&error];
    complete(camera,error);
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

    [self.captureSession commitConfiguration];
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

- (void)capturePhoto:(void (^)(UIImage *photo))complete {
  dispatch_async([Camera sessionQueue], ^{
    
  });
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
    [self.captureSession beginConfiguration];
    self.captureSession.sessionPreset =
        mode == CameraModePhoto ? AVCaptureSessionPresetPhoto : AVCaptureSessionPresetHigh;
    [self.captureSession commitConfiguration];
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
  if (_livePhotoEnable != livePhotoEnable) {
    // livePhoto 지원이 안되는데 livePhoto를 활성화할 경우 예외처리
    if (!self.livePhotoSupported && livePhotoEnable) return;
    
    _livePhotoEnable = livePhotoEnable;
  }
}

- (void)setDepthDataDeliveryEnable:(BOOL)depthDataDeliveryEnable {
  if (_depthDataDeliveryEnable != depthDataDeliveryEnable) {
    // depthDataDelivery 지원이 안되는데 deptheDataDelivery를 활성화할 경우 예외처리
    if (!self.depthDataDeliverySupported && depthDataDeliveryEnable) return;

    _depthDataDeliveryEnable = depthDataDeliveryEnable;
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
    _livePhotoSupported = _photoOutput.livePhotoCaptureSupported;
    _photoOutput.livePhotoCaptureEnabled = _photoOutput.livePhotoCaptureSupported;
    if (@available(iOS 11.0, *)) {
      _depthDataDeliverySupported = _photoOutput.depthDataDeliverySupported;
      _photoOutput.depthDataDeliveryEnabled = _photoOutput.depthDataDeliverySupported;
    } else {
      _depthDataDeliverySupported = NO;
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
      setting = [AVCapturePhotoSettings photoSettingsWithFormat:@{ AVVideoCodecKey : AVVideoCodecTypeHEVC }];
    } else {
      setting = [AVCapturePhotoSettings photoSettings];
    }
  } else {
    setting = [AVCapturePhotoSettings photoSettings];
  }
  
  // flash 모드적용
  if (self.cameraDevice.isFlashAvailable) {
    [[self.photoOutput supportedFlashModes] enumerateObjectsUsingBlock:^(NSNumber *mode, NSUInteger idx, BOOL *stop){
      if (mode.integerValue == self.flash) {
        setting.flashMode = self.flash;
        *stop = YES;
      }
    }];
  }
  
  setting.highResolutionPhotoEnabled = YES; // 해상도 최대로 사용?
  
  if (setting.availablePreviewPhotoPixelFormatTypes.count > 0) { // 이건 뭐하는 건지 모르겠다. 예제에 있길래 넣은 코드
    setting.previewPhotoFormat = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : setting.availablePreviewPhotoPixelFormatTypes.firstObject };
  }
  
  // 라이브포토설정, 라이브포토를 임시저장해놓을 경로설정
  if (self.livePhotoEnable && self.livePhotoSupported) {
    NSString *livePhotoMovieFileName = [NSUUID UUID].UUIDString;
    NSString *livePhotoMovieFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[livePhotoMovieFileName stringByAppendingPathExtension:@"mov"]];
    setting.livePhotoMovieFileURL = [NSURL fileURLWithPath:livePhotoMovieFilePath];
  }
  
  // depth data 설정
  if (@available(iOS 11.0, *)) {
    if (self.depthDataDeliveryEnable && self.depthDataDeliverySupported) {
      setting.depthDataDeliveryEnabled = YES;
    } else {
      setting.depthDataDeliveryEnabled = NO;
    }
  }
  
  return setting;
}


@end
