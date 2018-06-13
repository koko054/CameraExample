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
@property(nonatomic, strong) UIButton *focusModeButton;
@property(nonatomic, strong) UIButton *exposureModeButton;
@property(nonatomic, strong) UIButton *rotateButton;

@property(nonatomic, assign) CGFloat videoRecordingTime;

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
  [self.buttonPanel addSubview:self.focusModeButton];
  [self.buttonPanel addSubview:self.exposureModeButton];
  [self.buttonPanel addSubview:self.rotateButton];

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
        self.previewView.frame = CGRectMake(0.0, 0.0, self.view.frame.size.width, height);
        self.previewView.session = camera.session;
        self.camera = camera;
        [self.camera startCapture];
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
  }
  return _previewView;
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

- (UIButton *)focusModeButton {
  if (!_focusModeButton) {
    _focusModeButton = [self testButtonRow:1 column:1];
    [_focusModeButton setTitle:@"auto\nfocus" forState:UIControlStateNormal];
  }
  return _focusModeButton;
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
                                complete:^{
                                  NSLog(@"dbtest takePhoto complete");
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
    switch (self.camera.flash) {
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
    [self.camera setFlash:nextFlash];
  } else if (sender == self.focusModeButton) {
  } else if (sender == self.exposureModeButton) {
  } else if (sender == self.snapShotButton) {
    if (self.camera.isRecording && self.camera.availableSnapShot) {
      [self.camera takePhotoWithDelegate:self complete:^{
        NSLog(@"dbtest take snap shot");
      }];
    }
  }
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
  NSLog(@"dbtest livePhoto capturing : %@",capturing ? @"YES" : @"NO");
}

@end
