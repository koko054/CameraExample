//
//  ViewController.m
//  CameraExample
//
//  Created by 김도범 on 2018. 5. 19..
//  Copyright © 2018년 DobumKim. All rights reserved.
//

#import "ViewController.h"
#import "Camera.h"
#import "AVCamPreviewView.h"

// 촬영버튼 (모드참고)
// 모드변경 (사진/비디오)
// 전/후면 전환
// 라이브포토 on/off
// 플래쉬 자동/켬/끔
// 줌
// 포커스모드 (자동/수동)
// 포커스
// 밝기 모드 (자동/수동)
// 밝기

@interface ViewController ()<CameraCaptureUIDelegate>

@property(nonatomic, strong) Camera *camera;
@property(nonatomic, strong) AVCamPreviewView *previewView;

@property(nonatomic, strong) UIView *buttonPanel;
@property(nonatomic, strong) UIButton *captureButton;
@property(nonatomic, strong) UIButton *cameraModeButton;
@property(nonatomic, strong) UIButton *snapShotButton;
@property(nonatomic, strong) UIButton *livePhotoButton;
@property(nonatomic, strong) UIButton *flashButton;
@property(nonatomic, strong) UIButton *formatButton;
@property(nonatomic, strong) UIButton *exposureModeButton;
@property(nonatomic, strong) UIButton *rotateButton;

@property(nonatomic, assign) CGFloat videoRecordingTime;

@property(nonatomic, strong) UISlider *slider;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.blackColor;
  [self.view addSubview:self.previewView];
  [self.view addSubview:self.buttonPanel];
  [self.buttonPanel addSubview:self.captureButton];
  [self.buttonPanel addSubview:self.cameraModeButton];
  [self.buttonPanel addSubview:self.snapShotButton];
  [self.buttonPanel addSubview:self.livePhotoButton];
  [self.buttonPanel addSubview:self.flashButton];
  [self.buttonPanel addSubview:self.formatButton];
  [self.buttonPanel addSubview:self.exposureModeButton];
  [self.buttonPanel addSubview:self.rotateButton];

  [self.view addSubview:self.slider];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationWillEnterForeground)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationDidEnterBackground)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];

  [Camera configureCamera:^(Camera *camera, NSError *error) {
    if (camera) {
      dispatch_async(dispatch_get_main_queue(), ^{
        CGSize cameraResolution = camera.resolution;
        CGFloat width = self.view.frame.size.width;
        CGFloat height = ceil(cameraResolution.width * width / cameraResolution.height);
        self.previewView.frame = CGRectMake(0.0, 0.0, width, height);
        self.previewView.session = camera.captureSession;
        self.camera = camera;
        [self.camera startCapture];
        [self.camera addObserver:self];
        self.camera.depthDataDeliveryEnable = YES;
        self.camera.portraitEffectsMatteEnable = YES;
//        NSLog(@"dbtest init v:%lld t:%d",self.camera.commitedExposureDuration.value, self.camera.commitedExposureDuration.timescale);
//        NSLog(@"dbtest max v:%lld t:%d",self.camera.maxExposureDuration.value, self.camera.maxExposureDuration.timescale);
//        NSLog(@"dbtest min v:%lld t:%d",self.camera.minExposureDuration.value, self.camera.minExposureDuration.timescale);
//        NSLog(@"dbtest init time: %f",CMTimeGetSeconds(self.camera.commitedExposureDuration));
//        NSLog(@"dbtest max time : %f",CMTimeGetSeconds(self.camera.maxExposureDuration));
//        NSLog(@"dbtest min time : %f",CMTimeGetSeconds(self.camera.minExposureDuration));
//        self.slider.minimumValue = CMTimeGetSeconds(self.camera.minExposureDuration);
//        self.slider.maximumValue = CMTimeGetSeconds(self.camera.maxExposureDuration);
//        self.slider.value = CMTimeGetSeconds(self.camera.commitedExposureDuration);
        
        self.slider.minimumValue = 1.0;
        self.slider.maximumValue = self.camera.maxWhiteBalanceGain;
        self.slider.value = self.camera.whiteBalanceGains.redGain;
        
        [UIView animateWithDuration:0.3
                         animations:^{
                           self.previewView.alpha = 1.0;
                         }];
      });
    } else {
      NSLog(@"Failed configureCamera : %@", error.localizedDescription);
    }
  }];
}

- (void)dealloc {
  [self.camera removeObserver:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  NSLog(@"dbtest keyPath:%@ change:%@", keyPath, change);
  id value = [object valueForKeyPath:keyPath];
  NSLog(@"dbtest %@ : %@", keyPath, value);
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self.camera startCapture];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  [self.camera stopCapture];
}

- (void)applicationWillEnterForeground {
  [self.camera startCapture];
}

- (void)applicationDidEnterBackground {
  [self.camera stopCapture];
}

- (AVCamPreviewView *)previewView {
  if (!_previewView) {
    _previewView = [[AVCamPreviewView alloc] init];
    _previewView.backgroundColor = UIColor.blackColor;
    _previewView.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _previewView.alpha = 0.0;
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapCameraPreviewView:)];
    [_previewView addGestureRecognizer:tap];
  }
  return _previewView;
}

- (void)handleTapCameraPreviewView:(UITapGestureRecognizer *)gesture {
  CGPoint devicePoint =
      [self.previewView.videoPreviewLayer captureDevicePointOfInterestForPoint:[gesture locationInView:gesture.view]];
  [self.camera setFocusExposurePoint:devicePoint];
}

- (UIView *)buttonPanel {
  if (!_buttonPanel) {
    CGFloat top = self.view.frame.size.width * 4 / 3;
    CGFloat height = self.view.frame.size.height - top;
    _buttonPanel = [[UIView alloc] initWithFrame:CGRectMake(0.0, top, self.view.frame.size.width, height)];
    _buttonPanel.backgroundColor = UIColor.clearColor;
  }
  return _buttonPanel;
}

- (UIButton *)testButtonRow:(NSInteger)row column:(NSInteger)column {
  CGFloat size = self.buttonPanel.frame.size.width * 0.25;
  CGFloat left = size * column;
  CGFloat top = size * row;
  UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(left, top, size, size)];
  button.backgroundColor = UIColor.whiteColor;
  button.layer.borderColor = UIColor.blackColor.CGColor;
  button.layer.borderWidth = 1.0;
  button.titleLabel.numberOfLines = 2;
  [button setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
  [button setTitleColor:UIColor.blackColor forState:UIControlStateSelected];
  [button setTitleColor:UIColor.blackColor forState:UIControlStateHighlighted];
  [button addTarget:self action:@selector(touchedUpButtons:) forControlEvents:UIControlEventTouchUpInside];
  return button;
}

- (UIButton *)captureButton {
  if (!_captureButton) {
    _captureButton = [self testButtonRow:0 column:0];
    [_captureButton setTitle:@"촬영" forState:UIControlStateNormal];
  }
  return _captureButton;
}

- (UIButton *)cameraModeButton {
  if (!_cameraModeButton) {
    _cameraModeButton = [self testButtonRow:0 column:1];
    [_cameraModeButton setTitle:@"사진" forState:UIControlStateNormal];
    [_cameraModeButton setTitle:@"비디오" forState:UIControlStateSelected];
  }
  return _cameraModeButton;
}

- (UIButton *)snapShotButton {
  if (!_snapShotButton) {
    _snapShotButton = [self testButtonRow:0 column:2];
    [_snapShotButton setTitle:@"snap\nshot" forState:UIControlStateNormal];
  }
  return _snapShotButton;
}

- (UIButton *)livePhotoButton {
  if (!_livePhotoButton) {
    _livePhotoButton = [self testButtonRow:0 column:3];
    [_livePhotoButton setTitle:@"live\nOff" forState:UIControlStateNormal];
    [_livePhotoButton setTitle:@"live\nOn" forState:UIControlStateSelected];
  }
  return _livePhotoButton;
}

- (UIButton *)flashButton {
  if (!_flashButton) {
    _flashButton = [self testButtonRow:1 column:0];
    [_flashButton setTitle:@"flash\nAuto" forState:UIControlStateNormal];
  }
  return _flashButton;
}

- (UIButton *)formatButton {
  if (!_formatButton) {
    _formatButton = [self testButtonRow:1 column:1];
    [_formatButton setTitle:@"HEIF" forState:UIControlStateNormal];
  }
  return _formatButton;
}

- (UIButton *)exposureModeButton {
  if (!_exposureModeButton) {
    _exposureModeButton = [self testButtonRow:1 column:2];
    [_exposureModeButton setTitle:@"자동밝기" forState:UIControlStateNormal];
  }
  return _exposureModeButton;
}

- (UIButton *)rotateButton {
  if (!_rotateButton) {
    _rotateButton = [self testButtonRow:1 column:3];
    [_rotateButton setTitle:@"후면" forState:UIControlStateNormal];
    [_rotateButton setTitle:@"전면" forState:UIControlStateSelected];
  }
  return _rotateButton;
}

- (void)touchedUpButtons:(UIButton *)sender {
  if (sender == self.captureButton) {
    if (self.camera.mode == CameraModePhoto) {
      [self.camera takePhotoWithDelegate:self
                                complete:^(UIImage *previewImage) {
                                  NSLog(@"dbtest take photo complete");
                                }];
    } else if (self.camera.mode == CameraModeVideo) {
      if (![self.camera isRecording]) {
        NSLog(@"dbtest start video recording");
        self.videoRecordingTime = 0.0;
        __block NSTimer *timer =
            [NSTimer scheduledTimerWithTimeInterval:0.1
                                            repeats:YES
                                              block:^(NSTimer *timer) {
                                                self.videoRecordingTime += 0.1;
                                                NSLog(@"dbtest recording : %.2f", self.videoRecordingTime);
                                              }];
        [self.camera startVideoRecording:self
                                complete:^(BOOL success) {
                                  [timer invalidate];
                                  timer = nil;
                                  NSLog(@"dbtest stop video recording : %f", self.videoRecordingTime);
                                }];
      } else {
        [self.camera stopVideoRecording];
      }
    }
  } else if (sender == self.cameraModeButton) {
    [self showCameraPreview:NO];
    CameraMode newMode = self.camera.mode == CameraModePhoto ? CameraModeVideo : CameraModePhoto;
    __block typeof(self) blockSelf = self;
    [self.camera setMode:newMode
                complete:^{
                  dispatch_async(dispatch_get_main_queue(), ^{
                    blockSelf.cameraModeButton.selected = blockSelf.camera.mode == CameraModeVideo;
                    [blockSelf showCameraPreview:YES];
                  });
                }];
  } else if (sender == self.rotateButton) {
    [self showCameraPreview:NO];
    AVCaptureDevicePosition newPosition = self.camera.position == AVCaptureDevicePositionFront
                                              ? AVCaptureDevicePositionBack
                                              : AVCaptureDevicePositionFront;
    __block typeof(self) blockSelf = self;
    [self.camera setPosition:newPosition
                    complete:^{
                      dispatch_async(dispatch_get_main_queue(), ^{
                        blockSelf.rotateButton.selected = blockSelf.camera.position == AVCaptureDevicePositionFront;
                        [blockSelf showCameraPreview:YES];
                      });
                    }];
  } else if (sender == self.livePhotoButton) {
    [self.camera setLivePhotoEnable:!self.camera.livePhotoEnable];
    self.livePhotoButton.selected = self.camera.livePhotoEnable;
  } else if (sender == self.flashButton) {
    AVCaptureFlashMode nextFlash;
    switch (self.camera.flashMode) {
      case AVCaptureFlashModeOff:
        nextFlash = AVCaptureFlashModeOn;
        [self.flashButton setTitle:@"flash\nOn" forState:UIControlStateNormal];
        break;
      case AVCaptureFlashModeOn:
        nextFlash = AVCaptureFlashModeAuto;
        [self.flashButton setTitle:@"flash\nAuto" forState:UIControlStateNormal];
        break;
      case AVCaptureFlashModeAuto:
        nextFlash = AVCaptureFlashModeOff;
        [self.flashButton setTitle:@"flash\nOff" forState:UIControlStateNormal];
        break;
      default:
        break;
    }
    [self.camera setFlashMode:nextFlash];
  } else if (sender == self.formatButton) {
    switch (self.camera.photoFormat) {
      case PhotoFormatHEIF:
        self.camera.photoFormat = PhotoFormatJPEG;
        [self.formatButton setTitle:@"JPEG" forState:UIControlStateNormal];
        break;
      case PhotoFormatJPEG:
        self.camera.photoFormat = PhotoFormatRAW;
        [self.formatButton setTitle:@"RAW" forState:UIControlStateNormal];
        break;
      case PhotoFormatRAW:
        self.camera.photoFormat = PhotoFormatRAWHEIF;
        [self.formatButton setTitle:@"RAW\nHEIF" forState:UIControlStateNormal];
        break;
      case PhotoFormatRAWHEIF:
        self.camera.photoFormat = PhotoFormatRAWJPEG;
        [self.formatButton setTitle:@"RAW\nJPEG" forState:UIControlStateNormal];
        break;
      case PhotoFormatRAWJPEG:
        self.camera.photoFormat = PhotoFormatHEIF;
        [self.formatButton setTitle:@"HEIF" forState:UIControlStateNormal];
        break;
      default:
        self.camera.photoFormat = PhotoFormatHEIF;
        [self.formatButton setTitle:@"HEIF" forState:UIControlStateNormal];
        break;
    }
  } else if (sender == self.exposureModeButton) {
  } else if (sender == self.snapShotButton) {
    if (self.camera.isRecording && self.camera.availableSnapShot) {
      [self.camera takePhotoWithDelegate:self
                                complete:^(UIImage *previewImage) {
                                  NSLog(@"dbtest take snap shot");
                                }];
    }
  }
}

- (UISlider *)slider {
  if (!_slider) {
    CGFloat width = self.view.frame.size.width * 0.8;
    CGFloat height = self.view.frame.size.width * 0.1;
    CGFloat left = (self.view.frame.size.width - width) * 0.5;
    CGFloat top = self.buttonPanel.frame.origin.y - height;
    _slider = [[UISlider alloc] initWithFrame:CGRectMake(left, top, width, height)];
    [_slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    _slider.minimumValue = 0.0;
    _slider.maximumValue = 1.0;
  }
  return _slider;
}

- (void)sliderChanged:(UISlider *)slider {
  AVCaptureWhiteBalanceGains gain;
  gain.redGain = slider.value;
  gain.greenGain = self.camera.whiteBalanceGains.greenGain;
  gain.blueGain = self.camera.whiteBalanceGains.blueGain;
  self.camera.whiteBalanceGains = gain;
}

- (void)showCameraPreview:(BOOL)show {
  CGFloat alpha = show ? 1.0 : 0.0;
  [self.previewView.layer removeAllAnimations];
  [UIView animateWithDuration:0.3
                   animations:^{
                     self.previewView.alpha = alpha;
                   }];
}

#pragma mark - CameraCaptureUIDelegate
- (AVCaptureVideoOrientation)captureOrientation {
  return self.previewView.videoPreviewLayer.connection.videoOrientation;
}

- (void (^)(void))captureAnimation {
  return ^{
    NSLog(@"dbtest say cheeeeeeeese!");
  };
}

- (void)capturingLivePhoto:(BOOL)capturing {
  NSLog(@"dbtest livePhoto capturing : %@", capturing ? @"YES" : @"NO");
}

- (NSString *)stringOfCameraMode:(CameraMode)cameraMode {
  NSString *string;
  switch (cameraMode) {
    case CameraModePhoto:
      string = @"Photo";
      break;
    case CameraModeVideo:
      string = @"Video";
      break;
    default:
      string = @"Unknown";
      break;
  }
  return string;
}

@end
