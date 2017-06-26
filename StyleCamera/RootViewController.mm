//
//  RootViewController.mm
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/26.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import "RootViewController.h"
#import "StyleCollectionViewCell.h"

#import "tensor_style_utils.h"

#define SAMPLE_IMAGE_NAME       @"shinting"
#define SAMPLE_IMAGE_EXTENSION  @"jpg"

// FIXME: 只有shinting和sample兩張圖正常...

@interface RootViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (retain, nonatomic) IBOutlet UIImageView *sampleImageView;
@property (retain, nonatomic) IBOutlet UILabel *debugLabel;
@property (retain, nonatomic) IBOutlet UICollectionView *stylesCollectionView;

@property (retain, nonatomic) tensor_style_utils *tensorStyleUtils;

@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _tensorStyleUtils = [[tensor_style_utils alloc] init];
    
    self.sampleImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@.%@", SAMPLE_IMAGE_NAME, SAMPLE_IMAGE_EXTENSION]];
    self.debugLabel.text = nil;
    [self.stylesCollectionView registerNib:[UINib nibWithNibName:@"StyleCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"StyleCollectionViewCell"];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_tensorStyleUtils release];
    [_sampleImageView release];
    [_stylesCollectionView release];
    [_debugLabel release];
    [super dealloc];
}

- (void)runStyle {
    NSTimeInterval startTime = [NSDate date].timeIntervalSince1970;
    
    ImageData imageData = [self.tensorStyleUtils performStyleTransferWithResourceName:SAMPLE_IMAGE_NAME
                                                                                 type:SAMPLE_IMAGE_EXTENSION];
    UIImage *outputImage = createImageFromImageData(imageData);
    self.sampleImageView.image = outputImage;
    
    NSTimeInterval costTime = [NSDate date].timeIntervalSince1970 - startTime;
    self.debugLabel.text = [NSString stringWithFormat:@"Time cost: %.3f sec.", costTime];
//    [self showAlertWithTitle:[NSString stringWithFormat:@"cost: %.3f sec.", costTime] message:nil actions:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil], nil];
//    NSLog(@"cost: %.3f sec.", costTime);
//    LOG(INFO) << "Done";
    
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
    
    if (indexPath.item == 0) {
        [self.tensorStyleUtils clearStyle];
        self.sampleImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@.%@", SAMPLE_IMAGE_NAME, SAMPLE_IMAGE_EXTENSION]];
        self.debugLabel.text = nil;
    }
    else {
        [self.tensorStyleUtils selectStyle:(int)(indexPath.item-1)];
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
