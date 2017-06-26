//
//  RootViewController.mm
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/26.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import "RootViewController.h"
#import "StyleCollectionViewCell.h"

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

#include "ios_image_load.h"
#include "tensorflow_utils.h"

#define INPUT_NODE      "input"
#define STYLE_NODE      "style_num"
#define OUTPUT_NODE     "transformer/expand/conv3/conv/Sigmoid"
#define NUM_OF_STYLES   26

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

@interface RootViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout> {
    
    std::unique_ptr<tensorflow::Session> tf_session;
    float styleRatio[NUM_OF_STYLES];
}

@property (retain, nonatomic) IBOutlet UIImageView *sampleImageView;
@property (retain, nonatomic) IBOutlet UICollectionView *stylesCollectionView;

@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    tensorflow::Status load_status = LoadModel(@"stylize_quantized", @"pb", &tf_session);
    if (!load_status.ok()) {
        LOG(FATAL) << "Couldn't load model: " << load_status;
    }
    
    for (int i = 0; i < NUM_OF_STYLES; i ++) {
        styleRatio[i] = 0;
    }
    
    [self.stylesCollectionView registerNib:[UINib nibWithNibName:@"StyleCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"StyleCollectionViewCell"];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_sampleImageView release];
    [_stylesCollectionView release];
    [super dealloc];
}

- (void)runStyle {
    if (!tf_session.get()) {
        return;
    }
    
    NSString* image_path = FilePathForResourceName(@"sample", @"jpeg");
    int image_width;
    int image_height;
    int image_channels;
    std::vector<tensorflow::uint8> image_data = LoadImageFromFile([image_path UTF8String],
                                                                  &image_width,
                                                                  &image_height,
                                                                  &image_channels);
    const int wanted_width = image_width;//256;
    const int wanted_height = image_height;//256;
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
    
    tensorflow::Tensor style_tensor(tensorflow::DT_FLOAT, tensorflow::TensorShape({NUM_OF_STYLES}));
    auto style_tensor_mapped = style_tensor.tensor<float, 1>();
    out_temp = style_tensor_mapped.data();
    for (int i = 0; i < NUM_OF_STYLES; i ++) {
        out_temp[0] = styleRatio[i];
        out_temp ++;
    }
    
    std::vector<tensorflow::Tensor> outputs;
    tensorflow::Status run_status = tf_session->Run({{INPUT_NODE, image_tensor}, {STYLE_NODE, style_tensor}},
                                                    {OUTPUT_NODE}, {}, &outputs);
    if (!run_status.ok()) {
        LOG(ERROR) << "Running model failed: " << run_status;
        tensorflow::LogAllRegisteredKernels();
        return;
    }
    
    tensorflow::Tensor* output = &outputs[0];
    auto floatValues = output->flat<float>();
    
    ARGBPixel *bitmapData = (ARGBPixel *)calloc((wanted_width*wanted_height), sizeof(ARGBPixel));
    for (int i = 0; i < (wanted_width*wanted_height); i ++) {
        bitmapData[i].alpha = 255;
        bitmapData[i].red = ((int) (floatValues((i * 3)) * 255));
        bitmapData[i].green = ((int) (floatValues((i * 3 + 1)) * 255));
        bitmapData[i].blue = ((int) (floatValues((i * 3 + 2)) * 255));
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate (bitmapData,
                                                  wanted_width,
                                                  wanted_height,
                                                  8,      // bits per component
                                                  (wanted_width*4),
                                                  colorSpace,
                                                  kCGImageAlphaPremultipliedFirst);
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIImage *outputImage = [UIImage imageWithCGImage:cgImage];
    
    CGColorSpaceRelease( colorSpace );
    CGContextRelease( context );
    CGImageRelease( cgImage );
    free( bitmapData );
    
    self.sampleImageView.image = outputImage;
    
    LOG(INFO) << "Done";
    
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return NUM_OF_STYLES+1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [collectionView dequeueReusableCellWithReuseIdentifier:@"StyleCollectionViewCell" forIndexPath:indexPath];
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    
    
    for (int i = 0; i < NUM_OF_STYLES; i ++) {
        styleRatio[i] = 0;
    }
    
    if (indexPath.item == 0) {
        self.sampleImageView.image = [UIImage imageNamed:@"sample.jpeg"];
    }
    else {
        styleRatio[indexPath.item-1] = 1;
        [self runStyle];
    }
    
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(StyleCollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.item == 0) {
        cell.styleImageView.image = [UIImage imageNamed:@"no_style"];
    }
    else {
        cell.styleImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"style%ld", (long)(indexPath.item-1)]];
    }
    
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(StyleCollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    cell.styleImageView.image = nil;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(70, 70);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(5, 10, 5, 10);
}

@end
