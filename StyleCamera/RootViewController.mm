//
//  RootViewController.mm
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/26.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import "RootViewController.h"
#import "StyleCollectionViewCell.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import <CCCUIKit/UIImage+CCCProcessor.h>

#import "tensor_style_utils.h"
#import "CCLPickerView.h"

#define DEFAULT_SAMPLE_IMAGE_NAME       @"me"
#define DEFAULT_SAMPLE_IMAGE_EXTENSION  @"png"


typedef NS_ENUM(NSInteger, ImageSource) {
    ImageSourceAlbum = 0,
    ImageSourceResource
};

@interface RootViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, CCLPickerViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIPopoverControllerDelegate, UIPopoverPresentationControllerDelegate>

@property (retain, nonatomic) UIPopoverController *popoverCtrl;

@property (retain, nonatomic) IBOutlet UIImageView *sampleImageView;
@property (retain, nonatomic) IBOutlet UILabel *debugLabel;
@property (retain, nonatomic) IBOutlet UICollectionView *stylesCollectionView;

@property (retain, nonatomic) tensor_style_utils *tensorStyleUtils;

@property (retain, nonatomic) CCLPickerView *cclPickerView;
@property (retain, nonatomic) UIImagePickerController *imagePickerController;

@property (nonatomic) ImageSource imageSource;
@property (retain, nonatomic) NSString *resourceName;
@property (retain, nonatomic) NSString *resourceType;
@property (retain, nonatomic) UIImage *albumImage;

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
    [_imagePickerController release];
    [_popoverCtrl release];
    [_albumImage release];
    [super dealloc];
}

#pragma mark -

- (void)setDefault {
    switch (self.imageSource) {
        case ImageSourceAlbum: {
            self.sampleImageView.image = self.albumImage;
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
    
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        UIImage *outputImage = nil;
        switch (self.imageSource) {
            case ImageSourceAlbum: {
                ImageData *imageData = [self.tensorStyleUtils performStyleTransferWithCGImage:self.albumImage.CGImage];
                outputImage = createImageFromImageData(imageData, self.albumImage.scale, self.albumImage.imageOrientation);
                break;
            }
            default: {
                ImageData *imageData = [self.tensorStyleUtils performStyleTransferWithResourceName:self.resourceName type:self.resourceType];
                outputImage = createImageFromImageData(imageData, 1, UIImageOrientationUp);
                break;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^ {
            self.sampleImageView.image = outputImage;
            
            NSTimeInterval costTime = [NSDate date].timeIntervalSince1970 - startTime;
            self.debugLabel.text = [NSString stringWithFormat:@"%ldx%ld\nTime cost: %.3f sec.", (long)outputImage.size.width, (long)outputImage.size.height, costTime];
            
//            [self showAlertWithTitle:[NSString stringWithFormat:@"cost: %.3f sec.", costTime] message:nil actions:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil], nil];
//            NSLog(@"cost: %.3f sec.", costTime);
//            LOG(INFO) << "Done";
            
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            
        });
    });
    
}

#pragma mark - Button Actions

- (IBAction)openAlbumAction:(UIButton *)sender {
    UIImagePickerController *imgPicker = [[UIImagePickerController alloc] init];
    imgPicker.delegate = self;
    imgPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    self.imagePickerController = imgPicker;
    [imgPicker release];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        CGSize preferredSize = [self.imagePickerController.view systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        self.imagePickerController.preferredContentSize = preferredSize;
        
        if([self.imagePickerController respondsToSelector:@selector(popoverPresentationController)]) {
            //iOS 8以上使用UIPopoverPresentationController
            self.imagePickerController.modalPresentationStyle = UIModalPresentationPopover;
            //不建議寫死長寬，建議由上方的code根據內容計算大小
            //self.pickerViewCtrl.preferredContentSize = CGSizeMake(320, 216);
            UIPopoverPresentationController *popoverPresentation = self.imagePickerController.popoverPresentationController;
            popoverPresentation.delegate = self;
            popoverPresentation.sourceView = sender;
            popoverPresentation.sourceRect = sender.bounds;
            popoverPresentation.permittedArrowDirections = UIPopoverArrowDirectionAny;
            [self presentViewController:self.imagePickerController animated:YES completion:nil];
        }
        else {
            UIPopoverController *popoverCtrl = [[UIPopoverController alloc] initWithContentViewController:self.imagePickerController];
            popoverCtrl.delegate = self;
            popoverCtrl.backgroundColor = [UIColor colorWithWhite:1.000 alpha:0.800];
            //不建議寫死長寬，建議由上方的code根據內容計算大小
            //popoverCtrl.popoverContentSize = CGSizeMake(320, 216);
            [popoverCtrl presentPopoverFromRect:sender.bounds inView:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
            self.popoverCtrl = popoverCtrl;
            [popoverCtrl release];
        }
    }
    else {
        [self presentViewController:self.imagePickerController animated:YES completion:nil];
    }
    
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

- (IBAction)saveImageAction:(id)sender {
    if (!self.sampleImageView.image) {
        return;
    }
    
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    UIImageWriteToSavedPhotosAlbum(self.sampleImageView.image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    
}

#pragma mark - UIImageWriteToSavedPhotosAlbum

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    if (error) {
        [self showAlertWithTitle:[error localizedDescription] message:nil actions:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil], nil];
    }
    else {
        [self showAlertWithTitle:@"Saved！" message:nil actions:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil], nil];
    }
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
    self.albumImage = nil;
    
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

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    
    UIImage *originalImage = info[UIImagePickerControllerOriginalImage];
    if (!originalImage) {
        return;
    }
    
    self.imageSource = ImageSourceAlbum;
    self.resourceName = nil;
    self.resourceType = nil;
    if (originalImage.size.width > 1000 || originalImage.size.height > 1000) {
        self.albumImage = [originalImage cg_scaledImageToFitBoundingSize:CGSizeMake(1000, 1000)];
    }
    else {
        self.albumImage = originalImage;
    }
    
    [self setDefault];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self dismissViewControllerAnimated:YES completion:^ {
            self.imagePickerController = nil;
        }];
    }
    else {
        if([self.imagePickerController respondsToSelector:@selector(popoverPresentationController)]) {
            //iOS 8以上使用UIPopoverPresentationController
            [self dismissViewControllerAnimated:YES completion:^ {
                self.imagePickerController = nil;
            }];
        }
        else {
            [self.popoverCtrl dismissPopoverAnimated:YES];
            self.popoverCtrl = nil;
            self.imagePickerController = nil;
        }
    }
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self dismissViewControllerAnimated:YES completion:^ {
            self.imagePickerController = nil;
        }];
    }
}

#pragma mark - UIPopoverControllerDelegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController {
    return YES;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    if([self.imagePickerController respondsToSelector:@selector(popoverPresentationController)]) {
        //iOS 8以上使用UIPopoverPresentationController
        [self dismissViewControllerAnimated:YES completion:^ {
            self.imagePickerController = nil;
        }];
    }
    else {
        [self.popoverCtrl dismissPopoverAnimated:YES];
        self.popoverCtrl = nil;
        self.imagePickerController = nil;
    }
}

#pragma mark - UIPopoverPresentationControllerDelegate (iOS 8以上)

- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    return YES;
}

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    
}

@end
