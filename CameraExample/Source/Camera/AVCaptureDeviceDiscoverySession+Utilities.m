//
//  AVCaptureDeviceDiscoverySession+Utilities.m
//  CameraExample
//
//  Created by 김도범 on 2018. 5. 19..
//  Copyright © 2018년 DobumKim. All rights reserved.
//

#import "AVCaptureDeviceDiscoverySession+Utilities.h"

@implementation AVCaptureDeviceDiscoverySession (Utilities)

- (NSInteger)uniqueDevicePositionsCount {
  NSMutableArray<NSNumber *> *uniqueDevicePositions = [NSMutableArray array];

  for (AVCaptureDevice *device in self.devices) {
    if (![uniqueDevicePositions containsObject:@(device.position)]) {
      [uniqueDevicePositions addObject:@(device.position)];
    }
  }

  return uniqueDevicePositions.count;
}

@end
