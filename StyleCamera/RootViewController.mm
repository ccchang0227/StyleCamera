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
#import "CCLPickerView.h"

#define DEFAULT_SAMPLE_IMAGE_NAME       @"monster"
#define DEFAULT_SAMPLE_IMAGE_EXTENSION  @"jpg"


typedef NS_ENUM(NSInteger, ImageSource) {
    ImageSourceAlbum = 0,
    ImageSourceResource
};

@interface RootViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, CCLPickerViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource>

@property (retain, nonatomic) IBOutlet UIImageView *sampleImageView;
@property (retain, nonatomic) IBOutlet UILabel *debugLabel;
@property (retain, nonatomic) IBOutlet UICollectionView *stylesCollectionView;

@property (retain, nonatomic) tensor_style_utils *tensorStyleUtils;

@property (retain, nonatomic) CCLPickerView *cclPickerView;

@property (nonatomic) ImageSource imageSource;
@property (retain, nonatomic) NSString *resourceName;
@property (retain, nonatomic) NSString *resourceType;

@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _tensorStyleUtils = [[tensor_style_utils alloc] init];
    
    self.imageSource = ImageSourceResource;
    self.resourceName = DEFAULT_SAMPLE_IMAGE_NAME;
    self.resourceType = DEFAULT_SAMPLE_IMAGE_EXTENSION;
    [self setDefault];
    
    [self.stylesCollectionView registerNib:[UINib nibWithNibName:@"StyleCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"StyleCollectionViewCell"];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_sampleImageView release];
    [_stylesCollectionView release];
    [_debugLabel release];
    [_tensorStyleUtils release];
    [_cclPickerView release];
    [_resourceName release];
    [_resourceType release];
    [super dealloc];
}

#pragma mark -

- (void)setDefault {
    switch (self.imageSource) {
        case ImageSourceAlbum: {
            
            break;
        }
        default: {
            self.sampleImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@.%@", self.resourceName, self.resourceType]];
            break;
        }
    }
    self.debugLabel.text = [NSString stringWithFormat:@"%ldx%ld\n", (long)self.sampleImageView.image.size.width, (long)self.sampleImageView.image.size.height];
}

- (void)runStyle {
    NSTimeInterval startTime = [NSDate date].timeIntervalSince1970;
    
    ImageData imageData;
    switch (self.imageSource) {
        case ImageSourceAlbum: {
            
            break;
        }
        default: {
            imageData = [self.tensorStyleUtils performStyleTransferWithResourceName:self.resourceName
                                                                               type:self.resourceType];
            break;
        }
    }
    UIImage *outputImage = createImageFromImageData(imageData);
    self.sampleImageView.image = outputImage;
    
    NSTimeInterval costTime = [NSDate date].timeIntervalSince1970 - startTime;
    self.debugLabel.text = [NSString stringWithFormat:@"%ldx%ld\nTime cost: %.3f sec.", (long)outputImage.size.width, (long)outputImage.size.height, costTime];
//    [self showAlertWithTitle:[NSString stringWithFormat:@"cost: %.3f sec.", costTime] message:nil actions:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil], nil];
//    NSLog(@"cost: %.3f sec.", costTime);
//    LOG(INFO) << "Done";
    
}

#pragma mark -

- (IBAction)openAlbumAction:(id)sender {
    
}

- (IBAction)selectResourceAction:(UIButton *)sender {
    CCLPickerView *pickerView = [[CCLPickerView alloc] initWithTitle:@"Select Resource"
                                                            delegate:self
                                                   cancelButtonTitle:@"Cancel"
                                                     saveButtonTitle:@"OK"];
    self.cclPickerView = pickerView;
    [pickerView release];
    
    [self.cclPickerView showPickerViewFromView:sender];
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
        [self setDefault];
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

#pragma mark - CCLPickerViewDelegate

- (void)pickerViewDidSaveWithResult:(NSArray *)selectRowArray {
    if (!selectRowArray || selectRowArray.count == 0) {
        self.cclPickerView = nil;
        return;
    }
    
    self.imageSource = ImageSourceResource;
    NSInteger row = [selectRowArray[0] integerValue];
    NSArray<NSString *> *names = @[@"sample",
                                   @"fang",
                                   @"shinting",
                                   @"me",
                                   @"monster"];
    NSArray<NSString *> *types = @[@"jpeg",
                                   @"png",
                                   @"jpg",
                                   @"png",
                                   @"jpg"];
    self.resourceName = names[row];
    self.resourceType = types[row];
    
    [self setDefault];
    
    self.cclPickerView = nil;
}

- (void)pickerViewDidCancel {
    self.cclPickerView = nil;
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 5;
}

#pragma mark - UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    
    NSArray<NSString *> *titles = @[@"狗",
                                    @"吉芳",
                                    @"信廷",
                                    @"智傑",
                                    @"誘人的背影"];
    return titles[row];
}

@end
