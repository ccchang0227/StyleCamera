//
//  tensor_style_utils.m
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/26.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import "tensor_style_utils.h"

#include "ios_image_load.h"
#include "tensorflow_utils.h"

#define STYLE_MODEL_NAME    @"stylize_quantized"
#define STYLE_MODEL_TYPE    @"pb"

#define INPUT_NODE          "input"
#define STYLE_NODE          "style_num"
#define OUTPUT_NODE         "transformer/expand/conv3/conv/Sigmoid"

ImageData EmptyImageData = {NULL, 0, 0};

UIImage *createImageFromImageData(ImageData imageData) {
    if (NULL == imageData.pixelData) {
        return nil;
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate (imageData.pixelData,
                                                  imageData.width,
                                                  imageData.height,
                                                  8,      // bits per component
                                                  (imageData.width*4),
                                                  colorSpace,
                                                  kCGImageAlphaPremultipliedFirst);
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage *outputImage = [UIImage imageWithCGImage:cgImage];
    
    CGColorSpaceRelease( colorSpace );
    CGContextRelease( context );
    CGImageRelease( cgImage );
    
    return outputImage;
}

@interface tensor_style_utils ()
@end

@implementation tensor_style_utils

- (instancetype)init {
    self = [super init];
    if (self) {
        tensorflow::Status load_status = LoadModel(STYLE_MODEL_NAME, STYLE_MODEL_TYPE, &tf_session);
        if (!load_status.ok()) {
            LOG(FATAL) << "Couldn't load model: " << load_status;
        }
        
        for (int i = 0; i < NUM_OF_STYLES; i ++) {
            styleRatio[i] = 0;
        }
        
    }
    
    return self;
}

- (void)dealloc {
    [super dealloc];
}

- (void)setRatio:(float)ratio forStyleAtIndex:(int)index {
    if (index < 0 || index >= NUM_OF_STYLES) {
        return;
    }
    
    styleRatio[index] = MAX(0, MIN(1, ratio));
}

- (void)selectStyle:(int)index {
    [self clearStyle];
    [self setRatio:1 forStyleAtIndex:index];
}

- (void)clearStyle {
    for (int i = 0; i < NUM_OF_STYLES; i ++) {
        styleRatio[i] = 0;
    }
}

- (ImageData)performStyleTransferWithResourceName:(NSString *)resourceName type:(NSString *)extension {
    if (!resourceName || resourceName.length == 0) {
        return EmptyImageData;
    }
    if (!extension || extension.length == 0) {
        return EmptyImageData;
    }
    
    NSString* image_path = FilePathForResourceName(resourceName, extension);
    return [self performStyleTransferWithImagePath:image_path];
}

- (ImageData)performStyleTransferWithImagePath:(NSString *)imagePath {
    if (!imagePath || imagePath.length == 0) {
        return EmptyImageData;
    }
    
    int image_width;
    int image_height;
    int image_channels;
    std::vector<tensorflow::uint8> image_data = LoadImageFromFile([imagePath UTF8String],
                                                                  &image_width,
                                                                  &image_height,
                                                                  &image_channels);
    const int wanted_width = image_width;//256;
    const int wanted_height = image_height;//256;
//    const int wanted_width = 256;
//    const int wanted_height = 256;
    const int wanted_channels = 3;
    const float input_mean = 0.0f;//117.0f;
    const float input_std = 255.0f;//1.0f;
    assert(image_channels >= wanted_channels);
    tensorflow::Tensor image_tensor(tensorflow::DT_FLOAT,
                                    tensorflow::TensorShape({1, wanted_height, wanted_width, wanted_channels}));
    auto image_tensor_mapped = image_tensor.tensor<float, 4>();
    tensorflow::uint8* in_temp = image_data.data();
//    tensorflow::uint8* in_end = (in_temp + (image_height * image_width * image_channels));
    float* out_temp = image_tensor_mapped.data();
    for (int y = 0; y < wanted_height; ++y) {
        const int in_y = (y * image_height) / wanted_height;
        tensorflow::uint8* in_row = in_temp + (in_y * image_width * image_channels);
        float* out_row = out_temp + (y * wanted_width * wanted_channels);
        for (int x = 0; x < wanted_width; ++x) {
            const int in_x = (x * image_width) / wanted_width;
            tensorflow::uint8* in_pixel = in_row + (in_x * image_channels);
            float* out_pixel = out_row + (x * wanted_channels);
            for (int c = 0; c < wanted_channels; ++c) {
                out_pixel[c] = (in_pixel[c] - input_mean) / input_std;
            }
        }
    }
    
    std::vector<tensorflow::Tensor> outputs = [self _performStyleTransfer:image_tensor];
    if (outputs.empty()) {
        return EmptyImageData;
    }
    
    tensorflow::Tensor* output = &outputs[0];
    auto floatValues = output->flat<float>();
    
    ARGBPixel bitmapData[(wanted_width*wanted_height)];
//    ARGBPixel *bitmapData = (ARGBPixel *)calloc((wanted_width*wanted_height), sizeof(ARGBPixel));
    for (int i = 0; i < (wanted_width*wanted_height); i ++) {
        bitmapData[i].alpha = 255;
        bitmapData[i].red = ((int) (floatValues((i * 3)) * 255));
        bitmapData[i].green = ((int) (floatValues((i * 3 + 1)) * 255));
        bitmapData[i].blue = ((int) (floatValues((i * 3 + 2)) * 255));
    }
    
    return {wanted_width, wanted_height, bitmapData};
}

- (std::vector<tensorflow::Tensor>)_performStyleTransfer:(tensorflow::Tensor)image_tensor {
    std::vector<tensorflow::Tensor> outputs;
    if (!tf_session.get()) {
        return outputs;
    }
    
    tensorflow::Tensor style_tensor(tensorflow::DT_FLOAT, tensorflow::TensorShape({NUM_OF_STYLES}));
    auto style_tensor_mapped = style_tensor.tensor<float, 1>();
    float* out_temp = style_tensor_mapped.data();
    for (int i = 0; i < NUM_OF_STYLES; i ++) {
        out_temp[i] = styleRatio[i];
    }
    
    tensorflow::Status run_status = tf_session->Run({{INPUT_NODE, image_tensor}, {STYLE_NODE, style_tensor}},
                                                    {OUTPUT_NODE},
                                                    {},
                                                    &outputs);
    if (!run_status.ok()) {
        LOG(ERROR) << "Running model failed: " << run_status;
        tensorflow::LogAllRegisteredKernels();
    }
    
    return outputs;
}

@end
