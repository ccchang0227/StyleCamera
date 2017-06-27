//
//  tensor_style_utils.h
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/26.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ios_image_load.h"
#import "tensorflow_utils.h"

#include <fstream>
#include <pthread.h>
#include <unistd.h>
#include <queue>
#include <sstream>
#include <string>

#include "google/protobuf/io/coded_stream.h"
#include "google/protobuf/io/zero_copy_stream_impl.h"
#include "google/protobuf/io/zero_copy_stream_impl_lite.h"
#include "google/protobuf/message_lite.h"
#include "tensorflow/core/framework/op_kernel.h"
#include "tensorflow/core/framework/tensor.h"
#include "tensorflow/core/framework/types.pb.h"
#include "tensorflow/core/platform/env.h"
#include "tensorflow/core/platform/logging.h"
#include "tensorflow/core/platform/mutex.h"
#include "tensorflow/core/platform/types.h"
#include "tensorflow/core/public/session.h"

#define NUM_OF_STYLES 26

typedef struct {
    /// Alpha component
    UInt8 alpha;
    /// Red component
    UInt8 red;
    /// Green component
    UInt8 green;
    /// Blue component
    UInt8 blue;
} ARGBPixel;

@interface ImageData : NSObject

@property (nonatomic) int width;
@property (nonatomic) int height;
@property (nonatomic) ARGBPixel *pixelData;

@end

UIKIT_EXTERN UIImage *createImageFromImageData(ImageData *imageData,
                                               CGFloat scale,
                                               UIImageOrientation orientation);

@interface tensor_style_utils : NSObject {
@protected
    std::unique_ptr<tensorflow::Session> tf_session;
    float styleRatio[NUM_OF_STYLES];
}

- (void)setRatio:(float)ratio forStyleAtIndex:(int)index;
- (void)selectStyle:(int)index;
- (void)clearStyle;

- (ImageData *)performStyleTransferWithCGImage:(CGImageRef)image;
- (ImageData *)performStyleTransferWithResourceName:(NSString *)resourceName
                                             type:(NSString *)extension;
- (ImageData *)performStyleTransferWithImagePath:(NSString *)imagePath;

@end
