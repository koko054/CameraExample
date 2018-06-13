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

@protocol CameraCaptureUIDelegate<NSObject>
@required
- (AVCaptureVideoOrientation)captureOrientation;
@optional
- (void (^)(void))captureAnimation;
- (void)capturingLivePhoto:(BOOL)capturing;
@end

@interface Camera : NSObject

@property(nonatomic, assign, readonly) CameraMode mode;
@property(nonatomic, assign, readonly) AVCaptureDevicePosition position;
@property(nonatomic, assign, readonly) AVCaptureFlashMode flash;
@property(nonatomic, assign, readonly) BOOL livePhotoEnable;
@property(nonatomic, assign, readonly) BOOL depthDataDeliveryEnable;

/**
 Camera 객체를 async하게 생성한다.
 기본적으로 mode는 CameraModePhoto, posotion은 AVCaptureDevicePositionBack으로
 설정된다.

 @param complete Camera * 생성된 객체 생성실패 시 null , NSError * 생성필패 시
 에러
 */
+ (void)configureCamera:(void (^)(Camera *camera, NSError *error))complete;

/**
 Camera 객체를 async하게 생성한다.

 @param mode 초기 카메라모드
 @param position 초기 카메라 위치 (전/후면카메라)
 @param complete Camera * : 생성된 객체 생성실패 시 null , NSError * : 생성필패
 시 에러
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
 현재 캡쳐세션 AVCaptureVideoPreviewLayer의 session으로 설정하면 해당 Layer에
 캡쳐한 영상이 나온다.
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
 사진촬영 또는 라이브포토촬영(livePhotoEnable을 YES설정시)
 */
- (void)takePhotoWithDelegate:(id<CameraCaptureUIDelegate>)uiDelegate complete:(void (^)(void))complete;

/**
 비디오촬영중인지 확인하는 기능

 @return 비디오촬영중 YES, 아니면 NO
 */
- (BOOL)isRecording;

/**
 비디오촬영

 @param uiDelegate <CameraCaptureUIDelegate> 딜리게이트
 @param complete 촬영종료되면 실행되는 Block
 @see stopVideoRecording
 */
- (void)startVideoRecording:(id<CameraCaptureUIDelegate>)uiDelegate complete:(void (^)(BOOL success))complete;

/**
 촬영종료
 @see startVideoRecording:complete
 */
- (void)stopVideoRecording;

#pragma mark - camera options

/**
 sync하게 사진/비디오 모드 설정 (UI가 잠깐 멈추거나 카메라화면이 깜빡이는 현상이 일어날수있다.)

 @param mode 사진:CameraModePhoto, 비디오:CameraModeVideo
 */
- (void)setMode:(CameraMode)mode;

/**
 async하게 사진/비디오 모드 설정 (카메라화면이 깜빡이는 현상이 일어날수있다.)

 @param mode 사진:CameraModePhoto, 비디오:CameraModeVideo
 @param complete 설정이 완료되면 실행되는 Block
 */
- (void)setMode:(CameraMode)mode complete:(void (^)(void))complete;

/**
 sync하게 카메라 전/후면 설정 (UI가 잠깐 멈추거나 카메라화면이 깜빡이는 현상이 일어날수있다.)

 @param position 전면:AVCaptureDevicePositionFront, 후면:AVCaptureDevicePositionBack
 */
- (void)setPosition:(AVCaptureDevicePosition)position;

/**
 async하게 카메라 전/후면 설정 (카메라화면이 깜빡이는 현상이 일어날수있다.)

 @param position 전면:AVCaptureDevicePositionFront, 후면:AVCaptureDevicePositionBack
 @param complete 설정이 완료되면 실행되는 Block
 */
- (void)setPosition:(AVCaptureDevicePosition)position complete:(void (^)(void))complete;

/**
 flash 모드 설정

 @param flash AVCaptureFlashModeOff, AVCaptureFlashModeOn, AVCaptureFlashModeAuto
 */
- (void)setFlash:(AVCaptureFlashMode)flash;

/**
 라이브포토 활성화/비활성화

 @param livePhotoEnable 활성화:YES, 비활성화:NO
 */
- (void)setLivePhotoEnable:(BOOL)livePhotoEnable;

/**
 depthDataDelivery 활성화/비활성화 (iOS11 이상만 활성화 가능)

 @param depthDataDeliveryEnable 활성화:YES, 비활성화:NO
 */
- (void)setDepthDataDeliveryEnable:(BOOL)depthDataDeliveryEnable;

@end
