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

@interface ViewController ()

@property(nonatomic, strong) Camera *camera;
@property(nonatomic, strong) AVCamPreviewView *previewView;

@property(nonatomic, strong) UIView *buttonPanel;
@property(nonatomic, strong) UIButton *captureButton;
@property(nonatomic, strong) UIButton *cameraModeButton;
@property(nonatomic, strong) UIButton *rotateButton;
@property(nonatomic, strong) UIButton *livePhotoButton;
@property(nonatomic, strong) UIButton *flashButton;
@property(nonatomic, strong) UIButton *focusModeButton;
@property(nonatomic, strong) UIButton *exposureModeButton;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.blackColor;
  [self.view addSubview:self.previewView];
  [self.view addSubview:self.buttonPanel];
  [self.buttonPanel addSubview:self.captureButton];
  [self.buttonPanel addSubview:self.cameraModeButton];
  [self.buttonPanel addSubview:self.rotateButton];
  [self.buttonPanel addSubview:self.livePhotoButton];
  [self.buttonPanel addSubview:self.flashButton];
  [self.buttonPanel addSubview:self.focusModeButton];
  [self.buttonPanel addSubview:self.exposureModeButton];
  

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationWillEnterForeground)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationDidEnterBackground)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
  
  [Camera configureCamera:^(Camera *camera, NSError *error){
    if (camera) {
      dispatch_async(dispatch_get_main_queue(), ^{
        CGSize cameraResolution = camera.resolution;
        CGFloat width = self.view.frame.size.width;
        CGFloat height = ceil(cameraResolution.width * width / cameraResolution.height);
        self.previewView.frame = CGRectMake(0.0, 0.0, self.view.frame.size.width, height);
        self.previewView.session = camera.session;
        self.camera = camera;
        [self.camera startCapture];
        [UIView animateWithDuration:0.3 animations:^{
          self.previewView.alpha = 1.0;
        }];
      });
    } else {
      NSLog(@"Failed configureCamera : %@",error.localizedDescription);
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
    _previewView.backgroundColor = UIColor.blueColor;
    _previewView.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _previewView.alpha = 0.0;
  }
  return _previewView;
}

- (UIView *)buttonPanel {
  if (!_buttonPanel) {
    CGFloat top = self.view.frame.size.width * 4/3;
    CGFloat height = self.view.frame.size.height - top;
    _buttonPanel = [[UIView alloc] initWithFrame:CGRectMake(0.0, top, self.view.frame.size.width, height)];
    _buttonPanel.backgroundColor = UIColor.clearColor;
  }
  return _buttonPanel;
}

- (UIButton *)captureButton {
  if (!_captureButton) {
    CGFloat size = self.view.frame.size.width * 0.25;
    CGFloat left = (self.buttonPanel.frame.size.width - size) * 0.5;
    CGFloat top =  (self.buttonPanel.frame.size.height - size) * 0.5;
    _captureButton = [[UIButton alloc] initWithFrame:CGRectMake(left, top, size, size)];
    _captureButton.backgroundColor = UIColor.whiteColor;
    _captureButton.layer.cornerRadius = size * 0.5;
    [_captureButton setTitle:@"촬영" forState:UIControlStateNormal];
    [_captureButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [_captureButton addTarget:self action:@selector(touchedUpButtons:) forControlEvents:UIControlEventTouchUpInside];
  }
  return _captureButton;
}

- (UIButton *)cameraModeButton {
  if (!_cameraModeButton) {
    CGFloat padding = 10;
    CGFloat size = (self.buttonPanel.frame.size.height - (padding * 3.0)) * 0.45;
    CGFloat top = padding;
    CGFloat left = self.captureButton.frame.origin.x - size - padding;
    _cameraModeButton = [[UIButton alloc] initWithFrame:CGRectMake(left, top, size, size)];
    _cameraModeButton.backgroundColor = UIColor.whiteColor;
    _cameraModeButton.layer.cornerRadius = size * 0.5;
    _cameraModeButton.titleLabel.font = [UIFont systemFontOfSize:size * 0.15];
    [_cameraModeButton setTitle:@"사진" forState:UIControlStateNormal];
    [_cameraModeButton setTitle:@"비디오" forState:UIControlStateSelected];
    [_cameraModeButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [_cameraModeButton setTitleColor:UIColor.blackColor forState:UIControlStateSelected];
    [_cameraModeButton addTarget:self action:@selector(touchedUpButtons:) forControlEvents:UIControlEventTouchUpInside];
  }
  return _cameraModeButton;
}

- (UIButton *)rotateButton {
  if (!_rotateButton) {
    CGFloat padding = 10;
    CGFloat size = (self.buttonPanel.frame.size.height - (padding * 3.0)) * 0.45;
    CGFloat top = (self.buttonPanel.frame.size.height - size) * 0.5;
    CGFloat left = padding;
    _rotateButton = [[UIButton alloc] initWithFrame:CGRectMake(left, top, size, size)];
    _rotateButton.backgroundColor = UIColor.whiteColor;
    _rotateButton.layer.cornerRadius = size * 0.5;
    _rotateButton.titleLabel.font = [UIFont systemFontOfSize:size * 0.15];
    [_rotateButton setTitle:@"후면" forState:UIControlStateNormal];
    [_rotateButton setTitle:@"전면" forState:UIControlStateSelected];
    [_rotateButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [_rotateButton setTitleColor:UIColor.blackColor forState:UIControlStateSelected];
    [_rotateButton addTarget:self action:@selector(touchedUpButtons:) forControlEvents:UIControlEventTouchUpInside];
  }
  return _rotateButton;
}

- (UIButton *)livePhotoButton {
  if (!_livePhotoButton) {
    CGFloat padding = 10;
    CGFloat size = (self.buttonPanel.frame.size.height - (padding * 3.0)) * 0.45;
    CGFloat top = self.buttonPanel.frame.size.height - size - padding;
    CGFloat left = self.captureButton.frame.origin.x - size - padding;
    _livePhotoButton = [[UIButton alloc] initWithFrame:CGRectMake(left, top, size, size)];
    _livePhotoButton.backgroundColor = UIColor.whiteColor;
    _livePhotoButton.layer.cornerRadius = size * 0.5;
    _livePhotoButton.titleLabel.font = [UIFont systemFontOfSize:size * 0.15];
    [_livePhotoButton setTitle:@"라이브포토 Off" forState:UIControlStateNormal];
    [_livePhotoButton setTitle:@"라이브포토 On" forState:UIControlStateSelected];
    [_livePhotoButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [_livePhotoButton setTitleColor:UIColor.blackColor forState:UIControlStateSelected];
    [_livePhotoButton addTarget:self action:@selector(touchedUpButtons:) forControlEvents:UIControlEventTouchUpInside];
  }
  return _livePhotoButton;
}

- (UIButton *)flashButton {
  if (!_flashButton) {
    CGFloat padding = 10;
    CGFloat top = self.cameraModeButton.frame.origin.y;
    CGFloat size = (self.buttonPanel.frame.size.height - (padding * 3.0)) * 0.45;
    CGFloat left = self.captureButton.frame.origin.x + self.captureButton.frame.size.width + padding;
    _flashButton = [[UIButton alloc] initWithFrame:CGRectMake(left, top, size, size)];
    _flashButton.backgroundColor = UIColor.whiteColor;
    _flashButton.layer.cornerRadius = size * 0.5;
    _flashButton.titleLabel.font = [UIFont systemFontOfSize:size * 0.15];
    [_flashButton setTitle:@"flash" forState:UIControlStateNormal];
    [_flashButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [_flashButton setTitleColor:UIColor.blackColor forState:UIControlStateSelected];
    [_flashButton addTarget:self action:@selector(touchedUpButtons:) forControlEvents:UIControlEventTouchUpInside];
  }
  return _flashButton;
}

- (UIButton *)focusModeButton {
  if (!_focusModeButton) {
    CGFloat padding = 10;
    CGFloat size = (self.buttonPanel.frame.size.height - (padding * 3.0)) * 0.45;
    CGFloat top = (self.buttonPanel.frame.size.height - size) * 0.5;
    CGFloat left = self.buttonPanel.frame.size.width - size - padding;
    _focusModeButton = [[UIButton alloc] initWithFrame:CGRectMake(left, top, size, size)];
    _focusModeButton.backgroundColor = UIColor.whiteColor;
    _focusModeButton.layer.cornerRadius = size * 0.5;
    _focusModeButton.titleLabel.font = [UIFont systemFontOfSize:size * 0.15];
    [_focusModeButton setTitle:@"자동포커스" forState:UIControlStateNormal];
    [_focusModeButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [_focusModeButton setTitleColor:UIColor.blackColor forState:UIControlStateSelected];
    [_focusModeButton addTarget:self action:@selector(touchedUpButtons:) forControlEvents:UIControlEventTouchUpInside];
  }
  return _focusModeButton;
}

- (UIButton *)exposureModeButton {
  if (!_exposureModeButton) {
    CGFloat padding = 10;
    CGFloat size = (self.buttonPanel.frame.size.height - (padding * 3.0)) * 0.45;
    CGFloat top = self.buttonPanel.frame.size.height - size - padding;
    CGFloat left = self.captureButton.frame.origin.x + self.captureButton.frame.size.width + padding;
    _exposureModeButton = [[UIButton alloc] initWithFrame:CGRectMake(left, top, size, size)];
    _exposureModeButton.backgroundColor = UIColor.whiteColor;
    _exposureModeButton.layer.cornerRadius = size * 0.5;
    _exposureModeButton.titleLabel.font = [UIFont systemFontOfSize:size * 0.15];
    [_exposureModeButton setTitle:@"자동밝기" forState:UIControlStateNormal];
    [_exposureModeButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [_exposureModeButton setTitleColor:UIColor.blackColor forState:UIControlStateSelected];
    [_exposureModeButton addTarget:self
                            action:@selector(touchedUpButtons:)
                  forControlEvents:UIControlEventTouchUpInside];
  }
  return _exposureModeButton;
}

- (void)touchedUpButtons:(UIButton *)sender {
  if (sender == self.captureButton) {
  } else if (sender == self.cameraModeButton) {
    if (NO) { // no animation
      [self.camera switchMode];
      self.cameraModeButton.selected = self.camera.mode == CameraModeVideo;
    } else { // use camera option change animation;
      [UIView animateWithDuration:0.3
                       animations:^{
                         self.previewView.alpha = 0.0;
                       }];
      CameraMode newMode = self.camera.mode == CameraModePhoto ? CameraModeVideo : CameraModePhoto;
      
      __block typeof(self) blockSelf = self;
      [self.camera setMode:newMode
                  complete:^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                      blockSelf.cameraModeButton.selected = blockSelf.camera.mode == CameraModeVideo;
                      [blockSelf.previewView.layer removeAllAnimations];
                      [UIView animateWithDuration:0.3
                                       animations:^{
                                         blockSelf.previewView.alpha = 1.0;
                                       }];
                    });
                  }];
    }
  } else if (sender == self.rotateButton) {
    [self.camera switchCamera];
    self.rotateButton.selected = self.camera.position == AVCaptureDevicePositionFront;
  } else if (sender == self.livePhotoButton) {
    [self.camera switchLivePhoto];
    self.livePhotoButton.selected = self.camera.livePhotoEnable;
  } else if (sender == self.flashButton) {
    
  } else if (sender == self.focusModeButton) {
    
  } else if (sender == self.exposureModeButton) {
    
  }
}

@end
