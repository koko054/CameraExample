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

typedef NS_ENUM(NSInteger, CameraMode) { CameraModeUnknown, CameraModePhoto, CameraModeVideo, CameraModeCount };

typedef NS_ENUM(NSInteger, PhotoFormat) {
  PhotoFormatHEIF,
  PhotoFormatJPEG,
  PhotoFormatRAW,
  PhotoFormatRAWHEIF,
  PhotoFormatRAWJPEG
};

@protocol CameraCaptureUIDelegate<NSObject>
@required
- (AVCaptureVideoOrientation)captureOrientation;
@optional
- (void (^)(void))captureAnimation;
- (void)capturingLivePhoto:(BOOL)capturing;
@end

@interface Camera : NSObject

@property(nonatomic, strong, readonly) AVCaptureSession *captureSession;

@property(nonatomic, assign, readonly) CameraMode mode;                     // 사진,비디오
@property(nonatomic, assign, readonly) AVCaptureDevicePosition position;    // 전면,후면
@property(nonatomic, assign, readonly) AVCaptureFlashMode flashMode;        // 자동,켬,끔
@property(nonatomic, assign, readonly) AVCaptureTorchMode torchMode;        // 자동,켬,끔
@property(nonatomic, assign, readonly) AVCaptureFocusMode focusMode;        // 자동,고정,연속자동
@property(nonatomic, assign, readonly) AVCaptureExposureMode exposureMode;  // 자동,고정,연속자동,커스텀
@property(nonatomic, assign, readonly) AVCaptureWhiteBalanceMode whiteBalanceMode;  // 고정, 자동, 연속자동
@property(nonatomic, assign, readonly) AVCaptureVideoStabilizationMode videoStabilizationMode;  // 비디오 손떨림방지모드
@property(nonatomic, assign, readonly) BOOL livePhotoEnable;                                    // 라이브포토
@property(nonatomic, assign, readonly) BOOL depthDataDeliveryEnable;                            // depth 데이터
@property(nonatomic, assign, readonly) BOOL portraitEffectsMatteEnable;  // 전면 인물 depth 데이터
@property(nonatomic, assign, readonly) BOOL photoStabilizationEnable;    // 사진촬영시 손떨림방지기능
@property(nonatomic, assign, readonly) PhotoFormat photoFormat;          // 사진포맷 (HEIF,JPEG,RAW,RAW/JPEG)
@property(nonatomic, assign, readonly) CGSize previewPhotoSize;          // 썸네일크기

/**
 Camera 싱글톤객체를 async하게 생성한다.
 기본적으로 mode는 CameraModePhoto, posotion은 AVCaptureDevicePositionBack으로
 설정된다.

 @param complete Camera * 생성된 객체 생성실패 시 null , NSError * 생성필패 시
 에러
 */
+ (void)configureCamera:(void (^)(Camera *camera, NSError *error))complete;

/**
 Camera 싱글톤객체를 async하게 생성한다.

 @param mode 초기 카메라모드
 @param position 초기 카메라 위치 (전/후면카메라)
 @param complete Camera * : 생성된 객체 생성실패 시 null , NSError * : 생성필패
 시 에러
 */
+ (void)congifureCameraWithMode:(CameraMode)mode
                       position:(AVCaptureDevicePosition)position
                       complete:(void (^)(Camera *camera, NSError *error))complete;

/**
 사용할 수 없는 메소드.
 configureCamera:메소드나 congifureCameraWithMode:position:complete:메소드를 사용해야한다.
 */
- (instancetype)init
    __attribute__((unavailable("Must use configureCamera: or congifureCameraWithMode:position:complete:  instead.")));

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
- (void)takePhotoWithDelegate:(id<CameraCaptureUIDelegate>)uiDelegate
                     complete:(void (^)(UIImage *previewImage))complete;

/**
 비디오촬영중인지 확인하는 기능

 @return 비디오촬영중 YES, 아니면 NO
 */
- (BOOL)isRecording;

/**
 비디오촬영 중 사진 스냅샷이 가능한지 확인

 @return 스냅샷 가능:YES, 불가능:NO
 */
- (BOOL)availableSnapShot;

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
 사진/비디오 촬영시 플래쉬모드 설정
 default : AVCaptureFlashModeAuto

 @param flashMode AVCaptureFlashModeOff, AVCaptureFlashModeOn, AVCaptureFlashModeAuto
 */
- (void)setFlashMode:(AVCaptureFlashMode)flashMode;

/**
 토치 모드 설정
 default : AVCaptureTorchModeOff
 @param torchMode AVCaptureTorchModeOff, AVCaptureTorchModeOn, AVCaptureTorchModeAuto
 */
- (void)setTorchMode:(AVCaptureTorchMode)torchMode;

/**
 focus 모드 설정
 default : AVCaptureFocusModeContinuousAutoFocus

 @param focusMode AVCaptureFocusModeLocked, AVCaptureFocusModeAutoFocus, AVCaptureFocusModeContinuousAutoFocus
 */
- (void)setFocusMode:(AVCaptureFocusMode)focusMode;

/**
 exposure 모드 설정
 default : AVCaptureExposureModeContinuousAutoExposure
 수동으로 exposureISO와 exposureDuration을 설정하기 위해서는 AVCaptureExposureModeCustom을 사용해야한다.

 @param exposureMode AVCaptureExposureModeLocked, AVCaptureExposureModeAutoExpose,
                 AVCaptureExposureModeContinuousAutoExposure, AVCaptureExposureModeCustom
 */
- (void)setExposureMode:(AVCaptureExposureMode)exposureMode;

/**
 whiteBalance 모드 설정
 default : AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance

 @param whiteBalanceMode AVCaptureWhiteBalanceModeLocked, AVCaptureWhiteBalanceModeAutoWhiteBalance, AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance
 */
- (void)setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode;

/**
 입력된 포인터로 포커스와 밝기를 자동으로 맞춘다.

 @param point x:0.0~1.0 / y:0.0~1.0
 */
- (void)setFocusExposurePoint:(CGPoint)point;

/**
 비디오 손떨림방지모드 설정
 default : AVCaptureVideoStabilizationModeAuto

 @param videoStabilizationMode AVCaptureVideoStabilizationModeOff, AVCaptureVideoStabilizationModeStandard,
 AVCaptureVideoStabilizationModeCinematic, AVCaptureVideoStabilizationModeAuto
 */
- (void)setVideoStabilizationMode:(AVCaptureVideoStabilizationMode)videoStabilizationMode;

/**
 라이브포토 활성화/비활성화
 defualt : NO

 @param livePhotoEnable 활성화:YES, 비활성화:NO
 */
- (void)setLivePhotoEnable:(BOOL)livePhotoEnable;

/**
 depth data 지원여부

 @return YES : 지원, NO : 지원안함
 */
- (BOOL)depthDataDeliverySupports;

/**
 depthDataDelivery 활성화/비활성화 (iOS11 이상만 활성화 가능)
 default : NO

 @param depthDataDeliveryEnable 활성화:YES, 비활성화:NO
 */
- (void)setDepthDataDeliveryEnable:(BOOL)depthDataDeliveryEnable;

/**
 portraitEffectsMatte 기능 지원여부확인

 @return YES : 지원, NO : 지원안함
 */
- (BOOL)portraitEffectsMatteSupports;

/**
 portraitEffectsMatteEnable 활성화/비활성화
 (iOS12 이상만 활성화가능, depthDataDelivery가 활성화되어야 사용가능)
 default : NO

 @param portraitEffectsMatteEnable 활성화:YES, 비활성화:NO
 */
- (void)setPortraitEffectsMatteEnable:(BOOL)portraitEffectsMatteEnable;

/**
 손떨림방지기능 활성화/비활성화
 default : YES
 
 @param photoStabilizationEnable 활성화:YES, 비활성화:NO
 */
- (void)setPhotoStabilizationEnable:(BOOL)photoStabilizationEnable;

/**
 사진 포맷
 default : PhotoFormatHEIF
 
 @param photoFormat PhotoFormatHEIF, PhotoFormatJPEG, PhotoFormatRAW, PhotoFormatRAWHEIF, PhotoFormatRAWJPEG
 */
- (void)setPhotoFormat:(PhotoFormat)photoFormat;

/**
 썸네일크기 설정
 default : CGSizeZero
 
 @param previewPhotoSize 썸네일크기
 */
- (void)setPreviewPhotoSize:(CGSize)previewPhotoSize;

#pragma mark - manual camera

/**
 @return 카메라 조리개값 고정값
 */
- (CGFloat)aperture;

/**
 현재 카메라초점값(0.0 ~ 1.0)
 @return 0.0 ~ 1.0
 */
- (CGFloat)focus;

/**
 수동초점조절을 위한 focus설정(0.0 ~ 1.0)
 @param focus 0.0 ~ 1.0
 */
- (void)setFocus:(CGFloat)focus;

// 카메라 밝기조절 (밝기조절은 DSLR과는 다르게 ISO와 셔터스피드로만 조절가능하다)
/**
 @return 최소 ISO값
 */
- (CGFloat)minExposureISO;

/**
 @return 최대 ISO값
 */
- (CGFloat)maxExposureISO;

/**
 @return 현재 ISO값
 */
- (CGFloat)exposureISO;

/**
 수동밝기조절을 위한 ISO값 설정
 exposureMode가 AVCaptureExposureModeCustom 인 경우에만 적용된다.

 @param exposureISO minExposureISO와 maxExporsureISO 사이의 값
 */
- (void)setExposureISO:(CGFloat)exposureISO;

/**
 @return 최소 셔터스피드값
 */
- (CGFloat)minExposureDuration;

/**
 @return 최대 셔터스피드값
 */
- (CGFloat)maxExposureDuration;

/**
 @return 현재 셔터스피드값
 */
- (CGFloat)exposureDuration;

/**
 수동밝기조절을 위한 셔터스피드값(초)이며 높은 값을 설정할수록 카메라캡쳐속도가 느려진다.
 exposureMode가 AVCaptureExposureModeCustom 인 경우에만 적용된다.

 @param exposureDuration minExposureDuration와 maxExposureDuration 사이의 값
 */
- (void)setExposureDuration:(CGFloat)exposureDuration;

/**
 exposureISO와 exposureDuration를 동시에 적용하기 위한 메소드
 */
- (void)commitExposureISO:(CGFloat)exposureISO exposureDuration:(CGFloat)exposureDuration;

/**
 @return 최소 화이트밸런스 Gain값 1.0
 */
- (CGFloat)minWhiteBalanceGain;

/**
 @return 최대 화이트밸런스 Gain값
 */
- (CGFloat)maxWhiteBalanceGain;

/**
 @return 현재 화이트밸런스 Gain값
 */
- (AVCaptureWhiteBalanceGains)whiteBalanceGains;

/**
 화이트밸런스 Gain 설정
 @param whiteBalanceGains AVCaptureWhiteBalanceGains
 */
- (void)setWhiteBalanceGains:(AVCaptureWhiteBalanceGains)whiteBalanceGains;

#pragma mark - KVO supports

- (void)addObserver:(NSObject *)observer;

- (void)removeObserver:(NSObject *)observer;

@end
