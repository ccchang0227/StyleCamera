//
//  tensor_style_utils.m
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/26.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import "tensor_style_utils.h"

#define STYLE_MODEL_NAME    @"stylize_quantized"
#define STYLE_MODEL_TYPE    @"pb"

#define INPUT_NODE          "input"
#define STYLE_NODE          "style_num"
#define OUTPUT_NODE         "transformer/expand/conv3/conv/Sigmoid"

ImageData *EmptyImageData = nil;

@implementation ImageData
- (void)dealloc {
    if (NULL != _pixelData) {
        free( _pixelData );
    }
    [super dealloc];
}
@end

UIImage *createImageFromImageData(ImageData *imageData, CGFloat scale, UIImageOrientation orientation) {
    if (!imageData) {
        return nil;
    }
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
    UIImage *outputImage = [UIImage imageWithCGImage:cgImage scale:scale orientation:orientation];
    
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

void stillImageDataReleaseCallback(void *releaseRefCon, const void *baseAddress) {
    free((void *)baseAddress);
}

- (CVPixelBufferRef)performStyleTransferWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                   preferredOutputWidth:(int)outputWidth
                                  preferredOutputHeight:(int)outputHeight {
    if (NULL == pixelBuffer) {
        return NULL;
    }
    CFRetain(pixelBuffer);
    
    OSType sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    int doReverseChannels;
    if (kCVPixelFormatType_32ARGB == sourcePixelFormat) {
        doReverseChannels = 1;
    }
    else if (kCVPixelFormatType_32BGRA == sourcePixelFormat) {
        doReverseChannels = 0;
    }
    else {
        CFRelease(pixelBuffer);
        return pixelBuffer;  // Unknown source format
    }
    
//    const int sourceRowBytes = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
    const int image_width = (int)CVPixelBufferGetWidth(pixelBuffer);
    const int image_height = (int)CVPixelBufferGetHeight(pixelBuffer);
    const int image_channels = 4;
    
    CVPixelBufferLockFlags unlockFlags = kNilOptions;
    CVPixelBufferLockBaseAddress(pixelBuffer, unlockFlags);
    
    unsigned char *sourceBaseAddr = (unsigned char *)(CVPixelBufferGetBaseAddress(pixelBuffer));
    
    // width 和 height 必須要是4的倍數.
    int wanted_width = image_width;//256;
    if (outputWidth > 0) {
        wanted_width = outputWidth;
    }
    else {
        // default value
        wanted_width = 256;
    }
    while (wanted_width%4 != 0) {
        wanted_width --;
    }
    int wanted_height = image_height*wanted_width/(float)image_width;//256;
    if (outputHeight > 0) {
        wanted_height = outputHeight;
        wanted_width = image_width*wanted_height/(float)image_height;
    }
    while (wanted_height%4 != 0) {
        wanted_height --;
    }
    const int wanted_channels = 3;
    const float input_mean = 0.0f;//117.0f;
    const float input_std = 255.0f;//1.0f;
    
    tensorflow::Tensor image_tensor(tensorflow::DT_FLOAT,
                                    tensorflow::TensorShape({1, wanted_height, wanted_width, wanted_channels}));
    auto image_tensor_mapped = image_tensor.tensor<float, 4>();
    tensorflow::uint8 *in_temp = sourceBaseAddr;
    float *out_temp = image_tensor_mapped.data();
    
    for (int y = 0; y < wanted_height; ++y) {
        const int in_y = (y * image_height) / wanted_height;
        tensorflow::uint8* in_row = in_temp + (in_y * image_width * image_channels);
        float* out_row = out_temp + (y * wanted_width * wanted_channels);
        for (int x = 0; x < wanted_width; ++x) {
            const int in_x = (x * image_width) / wanted_width;
            tensorflow::uint8* in_pixel = in_row + (in_x * image_channels);
            float* out_pixel = out_row + (x * wanted_channels);
            for (int c = (doReverseChannels?1:0); c < wanted_channels; ++c) {
                out_pixel[c] = (in_pixel[c] - input_mean) / input_std;
            }
        }
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, unlockFlags);
    
    std::vector<tensorflow::Tensor> outputs = [self _performStyleTransferWithTensor:image_tensor];
    if (outputs.empty()) {
        CFRelease(pixelBuffer);
        return pixelBuffer;
    }
    
    tensorflow::Tensor* output = &outputs[0];
//    tensorflow::Tensor* output = &image_tensor;
    
    auto floatValues = output->flat<float>();
    
    ARGBPixel *bitmapData = (ARGBPixel *)calloc((wanted_width*wanted_height), sizeof(ARGBPixel));
    for (int i = 0; i < (wanted_width*wanted_height); i ++) {
        bitmapData[i].alpha = 255;
        if (!doReverseChannels) {
            bitmapData[i].blue = ((UInt8) (floatValues((i * 3)) * 255));
            bitmapData[i].green = ((UInt8) (floatValues((i * 3 + 1)) * 255));
            bitmapData[i].red = ((UInt8) (floatValues((i * 3 + 2)) * 255));
        }
        else {
            bitmapData[i].red = ((UInt8) (floatValues((i * 3)) * 255));
            bitmapData[i].green = ((UInt8) (floatValues((i * 3 + 1)) * 255));
            bitmapData[i].blue = ((UInt8) (floatValues((i * 3 + 2)) * 255));
        }
    }
    
    CVPixelBufferRef newBuffer = NULL;
    CVReturn status = CVPixelBufferCreateWithBytes(NULL,
                                                   wanted_width,
                                                   wanted_height,
                                                   kCVPixelFormatType_32ARGB,
                                                   bitmapData,
                                                   (wanted_width*4),
                                                   stillImageDataReleaseCallback,
                                                   NULL,
                                                   NULL,
                                                   &newBuffer);
    if (status != kCVReturnSuccess) {
        CFRelease(pixelBuffer);
        return pixelBuffer;
    }
    /*
    auto floatValues_mapped = output->tensor<float, 4>();
    
    CVPixelBufferLockBaseAddress(pixelBuffer, unlockFlags);
    sourceBaseAddr = (unsigned char *)(CVPixelBufferGetBaseAddress(pixelBuffer));
    
    tensorflow::uint8 *out_temp2 = sourceBaseAddr;
    float *in_temp2 = floatValues_mapped.data();
    for (int y = 0; y < wanted_height; ++y) {
        float *in_row = in_temp2 + (y * wanted_width * wanted_channels);
        for (int x = 0; x < wanted_width; ++x) {
            const int out_x = (y * image_width) / wanted_width;
            const int out_y = (x * image_height) / wanted_height;
            tensorflow::uint8 *out_pixel = out_temp2 + (out_y * image_width * image_channels) + (out_x * image_channels);
            float *in_pixel = in_row + (x * wanted_channels);
            for (int c = 0; c < wanted_channels; ++c) {
                out_pixel[c] = (tensorflow::uint8)(in_pixel[c]*input_std);
            }
        }
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, unlockFlags);
    */
    CFRelease(pixelBuffer);
    
    return newBuffer;
}

- (ImageData *)performStyleTransferWithCGImage:(CGImageRef)image {
    if (NULL == image) {
        return EmptyImageData;
    }
    
    int image_width;
    int image_height;
    int image_channels;
    std::vector<tensorflow::uint8> image_data = LoadImageFromCGImage(image,
                                                                     &image_width,
                                                                     &image_height,
                                                                     &image_channels);
    
    return [self _performStyleTransferWithImageData:image_data
                                         imageWidth:image_width
                                        imageHeight:image_height
                                      imageChannels:image_channels];    
}

- (ImageData *)performStyleTransferWithResourceName:(NSString *)resourceName type:(NSString *)extension {
    if (!resourceName || resourceName.length == 0) {
        return EmptyImageData;
    }
    if (!extension || extension.length == 0) {
        return EmptyImageData;
    }
    
    NSString* image_path = FilePathForResourceName(resourceName, extension);
    return [self performStyleTransferWithImagePath:image_path];
}

- (ImageData *)performStyleTransferWithImagePath:(NSString *)imagePath {
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
    
    return [self _performStyleTransferWithImageData:image_data
                                         imageWidth:image_width
                                        imageHeight:image_height
                                      imageChannels:image_channels];
}

- (ImageData *)_performStyleTransferWithImageData:(std::vector<tensorflow::uint8>)image_data
                                     imageWidth:(int)imageWidth
                                    imageHeight:(int)imageHeight
                                  imageChannels:(int)imageChannels {
    if (image_data.empty()) {
        return EmptyImageData;
    }
    
    // width 和 height 必須要是4的倍數.
    int wanted_width = imageWidth;//256;
    while (wanted_width%4 != 0) {
        wanted_width --;
    }
    int wanted_height = imageHeight;//256;
    while (wanted_height%4 != 0) {
        wanted_height --;
    }
    const int wanted_channels = 3;
    const float input_mean = 0.0f;//117.0f;
    const float input_std = 255.0f;//1.0f;
    if (imageChannels < wanted_channels) {
        return EmptyImageData;
    }
    
    tensorflow::Tensor image_tensor(tensorflow::DT_FLOAT,
                                    tensorflow::TensorShape({1, wanted_height, wanted_width, wanted_channels}));
    auto image_tensor_mapped = image_tensor.tensor<float, 4>();
    tensorflow::uint8* in_temp = image_data.data();
//    tensorflow::uint8* in_end = (in_temp + (image_height * image_width * image_channels));
    float* out_temp = image_tensor_mapped.data();
    
    for (int y = 0; y < wanted_height; ++y) {
        const int in_y = (y * imageHeight) / wanted_height;
        tensorflow::uint8* in_row = in_temp + (in_y * imageWidth * imageChannels);
        float* out_row = out_temp + (y * wanted_width * wanted_channels);
        for (int x = 0; x < wanted_width; ++x) {
            const int in_x = (x * imageWidth) / wanted_width;
            tensorflow::uint8* in_pixel = in_row + (in_x * imageChannels);
            float* out_pixel = out_row + (x * wanted_channels);
            for (int c = 0; c < wanted_channels; ++c) {
                out_pixel[c] = (in_pixel[c] - input_mean) / input_std;
            }
        }
    }
    
    std::vector<tensorflow::Tensor> outputs = [self _performStyleTransferWithTensor:image_tensor];
    if (outputs.empty()) {
        return EmptyImageData;
    }
    
    tensorflow::Tensor* output = &outputs[0];
    auto floatValues = output->flat<float>();
    
//    ARGBPixel bitmapData[(wanted_width*wanted_height)];
    ARGBPixel *bitmapData = (ARGBPixel *)calloc((wanted_width*wanted_height), sizeof(ARGBPixel));
    for (int i = 0; i < (wanted_width*wanted_height); i ++) {
        bitmapData[i].alpha = 255;
        bitmapData[i].red = ((UInt8) (floatValues((i * 3)) * 255));
        bitmapData[i].green = ((UInt8) (floatValues((i * 3 + 1)) * 255));
        bitmapData[i].blue = ((UInt8) (floatValues((i * 3 + 2)) * 255));
    }
    
    ImageData *imageData = [[ImageData alloc] init];
    imageData.width = wanted_width;
    imageData.height = wanted_height;
    imageData.pixelData = bitmapData;
    
    return [imageData autorelease];
}

- (std::vector<tensorflow::Tensor>)_performStyleTransferWithTensor:(tensorflow::Tensor)image_tensor {
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
