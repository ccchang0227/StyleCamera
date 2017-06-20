//
//  CCCStyleCameraView.h
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/20.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CCCCamera.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CCCStyleCameraViewDelegate;

@interface CCCStyleCameraView : UIView <CCCCameraController, CCCCameraSessionDelegate>

@property (assign, nonatomic, nullable) id<CCCStyleCameraViewDelegate> delegate;

// must not override its delegate.
@property (readonly, retain, nonatomic) CCCCameraSession *cameraSession;

// default is CCCCameraPreviewScaleTypeScaleToFill.
@property (assign, nonatomic) CCCCameraPreviewScaleType scaleType;

@property (assign, nonatomic, getter=isBarcodeScanEnabled) BOOL barcodeScanEnabled NS_UNAVAILABLE;

@end

@protocol CCCStyleCameraViewDelegate <NSObject>
@optional

- (void)cccStyleCameraViewDidStart:(CCCStyleCameraView *)cameraView;
- (void)cccStyleCameraViewDidStop:(CCCStyleCameraView *)cameraView;

- (CVImageBufferRef)cccStyleCameraView:(CCCStyleCameraView *)cameraView
                        processPreview:(CVImageBufferRef)imageBuffer;

@end

NS_ASSUME_NONNULL_END
