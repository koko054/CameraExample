//
//  Camera.h
//  CameraExample
//
//  Created by 김도범 on 2018. 5. 19..
//  Copyright © 2018년 DobumKim. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

// 모드변경 (사진/비디오)
// 촬영버튼 (모드)
// 전/후면 전환
// 라이브포토 on/off
// 플래쉬 자동/켬/끔
// 줌
// 포커스,밝기 모드 (자동/수동)
// 포커스
// 밝기

typedef NS_ENUM(NSInteger, CameraMode) {
  CameraModeUnknown,
  CameraModePhoto,
  CameraModeVideo,
  CameraModeCount
};

@interface Camera : NSObject

@property(nonatomic, assign, readonly) CameraMode mode;
@property(nonatomic, assign, readonly) AVCaptureDevicePosition position;
@property(nonatomic, assign, readonly) BOOL livePhotoSupported;
@property(nonatomic, assign, readonly) BOOL livePhotoEnable;
@property(nonatomic, assign, readonly) BOOL depthDataDeliverySupported;
@property(nonatomic, assign, readonly) BOOL depthDataDeliveryEnable;


/**
 Camera 객체를 async하게 생성한다.
 기본적으로 mode는 CameraModePhoto, posotion은 AVCaptureDevicePositionBack으로 설정된다.

 @param complete Camera * 생성된 객체 생성실패 시 null , NSError * 생성필패 시 에러
 */
+ (void)configureCamera:(void (^)(Camera *camera, NSError *error))complete;

/**
 Camera 객체를 async하게 생성한다.

 @param mode 초기 카메라모드
 @param position 초기 카메라 위치 (전/후면카메라)
 @param complete Camera * : 생성된 객체 생성실패 시 null , NSError * : 생성필패 시 에러
 */
+ (void)congifureCameraWithMode:(CameraMode)mode
                       position:(AVCaptureDevicePosition)position
                       complete:(void (^)(Camera *camera, NSError *error))complete;

/**
 Camera 객체를 sync하게 생성한다.

 @return Camera객체
 */
- (instancetype)init;

/**
 Camera 객체를 sync하게 생성한다.

 @param mode 초기 카메라모드
 @param position 초기 카메라 위치 (전/후면카메라)
 @param error 생성필패 시 에러
 @return Camera객체
 */
- (instancetype)initWithMode:(CameraMode)mode position:(AVCaptureDevicePosition)position error:(NSError **)error;

/**
 현재 캡쳐세션 AVCaptureVideoPreviewLayer의 session으로 설정하면 해당 Layer에 캡쳐한 영상이 나온다.
 */
- (AVCaptureSession *)session;

/**
 현재 활성화되어 있는 카메라의 해상도
 */
- (CGSize)resolution;

/**
 카메라 캡쳐 시작
 */
- (void)startCapture;

/**
 카메라 캡쳐 중지
 */
- (void)stopCapture;

/**
 사진모드 : 사진촬영 / 비디오모드 : 캡쳐
 */
- (void)capturePhoto:(void (^)(UIImage *photo))complete;

#pragma mark - camera options

/**
 전/후면 camera position toggle
 */
- (void)switchCamera;

/**
 사진/비디오 modo toggle
 */
- (void)switchMode;

/**
 livePhoto on/off toggle
 */
- (void)switchLivePhoto;

/**
 depthDataDelivery on/off toggle
 */
- (void)switchDepthDataDelivery;

- (void)setMode:(CameraMode)mode;
- (void)setMode:(CameraMode)mode complete:(void (^)(void))complete;
- (void)setPosition:(AVCaptureDevicePosition)position;
- (void)setPosition:(AVCaptureDevicePosition)position complete:(void (^)(void))complete;
- (void)setLivePhotoEnable:(BOOL)livePhotoEnable;
- (void)setDepthDataDeliveryEnable:(BOOL)depthDataDeliveryEnable;

@end
