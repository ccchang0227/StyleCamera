//
//  CameraViewController.mm
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/20.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import "CameraViewController.h"
#import "CCCStyleCameraView.h"
#import "StyleCollectionViewCell.h"
#import <ActionSheetPicker-3.0/ActionSheetPicker.h>

#import "tensor_style_utils.h"


@interface CameraViewController () <CCCStyleCameraViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout> {
    NSTimeInterval _previousFrameTime;
    CGFloat _fps;
    
    CGSize _previewSize;
}

@property (retain, nonatomic) IBOutlet UIBarButtonItem *switchButton;

@property (retain, nonatomic) IBOutlet CCCStyleCameraView *styleCameraView;
@property (retain, nonatomic) IBOutlet UILabel *previewSizeLabel;
@property (retain, nonatomic) IBOutlet UIButton *qualityButton;
@property (retain, nonatomic) IBOutlet UIButton *scaleTypeButton;

@property (retain, nonatomic) IBOutlet UIView *stylesView;
@property (retain, nonatomic) IBOutlet UICollectionView *stylesCollectionView;

@property (retain, nonatomic) NSTimer *fpsTimer;

@property (retain, nonatomic) tensor_style_utils *tensorStyleUtils;

@property (nonatomic) NSInteger selectedStyle;

@end

@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _previousFrameTime = 0;
    _fps = 0;
    _previewSize = CGSizeZero;
    _selectedStyle = 0;
    
    _tensorStyleUtils = [[tensor_style_utils alloc] init];
    
    self.styleCameraView.delegate = self;
    self.styleCameraView.videoQuality = CCCCameraVideoQualityMedium;
    
    self.stylesView.hidden = YES;
    [self.stylesCollectionView registerNib:[UINib nibWithNibName:@"StyleCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"StyleCollectionViewCell"];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_fpsTimer invalidate];
    
    [_styleCameraView release];
    [_switchButton release];
    [_previewSizeLabel release];
    [_fpsTimer release];
    [_tensorStyleUtils release];
    [_qualityButton release];
    [_stylesCollectionView release];
    [_stylesView release];
    [_scaleTypeButton release];
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self initView];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    _previousFrameTime = 0;
    _fps = 0;
    _previewSize = CGSizeZero;
    [self.styleCameraView startCameraRunning];
    
    self.fpsTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(displayFps:) userInfo:nil repeats:YES];
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.styleCameraView stopCameraRunning];
    
    if (self.fpsTimer) {
        [self.fpsTimer invalidate];
    }
    self.fpsTimer = nil;
    
}

#pragma mark -

- (void)initView {
    if ([CCCCameraView numberOfCameraDevice] <= 1) {
        self.switchButton.enabled = NO;
    }
    else {
        self.switchButton.enabled = YES;
    }
    
    self.previewSizeLabel.text = nil;
    
    [self configureQuality];
    [self configureScaleType];
    
}

- (void)configureQuality {
    switch (self.styleCameraView.videoQuality) {
        case CCCCameraVideoQualityLow: {
            [self.qualityButton setTitle:@"Low" forState:UIControlStateNormal];
            break;
        }
        case CCCCameraVideoQualityMedium: {
            [self.qualityButton setTitle:@"Medium" forState:UIControlStateNormal];
            break;
        }
        case CCCCameraVideoQualityHigh: {
            [self.qualityButton setTitle:@"High" forState:UIControlStateNormal];
            break;
        }
        case CCCCameraVideoQuality352x288: {
            [self.qualityButton setTitle:@"352x288" forState:UIControlStateNormal];
            break;
        }
        case CCCCameraVideoQuality640x480: {
            [self.qualityButton setTitle:@"640x480" forState:UIControlStateNormal];
            break;
        }
        case CCCCameraVideoQuality960x540: {
            [self.qualityButton setTitle:@"960x540" forState:UIControlStateNormal];
            break;
        }
        case CCCCameraVideoQuality1280x720: {
            [self.qualityButton setTitle:@"1280x720" forState:UIControlStateNormal];
            break;
        }
        case CCCCameraVideoQuality1920x1080: {
            [self.qualityButton setTitle:@"1920x1080" forState:UIControlStateNormal];
            break;
        }
        default: {
            [self.qualityButton setTitle:@"Photo" forState:UIControlStateNormal];
            break;
        }
    }
    
}

- (void)configureScaleType {
    switch (self.styleCameraView.scaleType) {
        case CCCCameraPreviewScaleTypeScaleAspectFit: {
            [self.scaleTypeButton setImage:[UIImage imageNamed:@"aspect_fit"] forState:UIControlStateNormal];
            break;
        }
        default: {
            [self.scaleTypeButton setImage:[UIImage imageNamed:@"aspect_fill"] forState:UIControlStateNormal];
            break;
        }
    }
    
}

// 顯示FPS
- (void)displayFps:(NSTimer *)theTimer {
    if (_fps == 0) {
        return;
    }
    
    self.previewSizeLabel.text = [NSString stringWithFormat:@"%ldx%ld, %.1f fps", (long)_previewSize.width, (long)_previewSize.height, _fps];
}

#pragma mark - Button Actions

- (IBAction)switchCamera:(id)sender {
    if ([CCCCameraView numberOfCameraDevice] <= 1) {
        return;
    }
    
    _previousFrameTime = 0;
    _fps = 0;
    _previewSize = CGSizeZero;
    self.previewSizeLabel.text = nil;
    
    switch (self.styleCameraView.cameraDevice) {
        case CCCCameraDeviceRear: {
            self.styleCameraView.cameraDevice = CCCCameraDeviceFront;
            break;
        }
        default: {
            self.styleCameraView.cameraDevice = CCCCameraDeviceRear;
            break;
        }
    }
    [self configureQuality];
    
}

- (IBAction)closeAction:(id)sender {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)selectQualityAction:(id)sender {
    NSArray *qualityKeys = @[@(CCCCameraVideoQualityLow),
                             @(CCCCameraVideoQualityMedium),
                             @(CCCCameraVideoQualityHigh),
                             @(CCCCameraVideoQuality352x288),
                             @(CCCCameraVideoQuality640x480),
                             @(CCCCameraVideoQuality960x540),
                             @(CCCCameraVideoQuality1280x720),
                             @(CCCCameraVideoQuality1920x1080),
                             @(CCCCameraVideoQualityPhoto)];
    NSArray *qualityStrings = @[@"Low",
                                @"Medium",
                                @"High",
                                @"352x288",
                                @"640x480",
                                @"960x540",
                                @"1280x720",
                                @"1920x1080",
                                @"Photo"];
    NSInteger index = [qualityKeys indexOfObject:@(self.styleCameraView.videoQuality)];
    
    [ActionSheetStringPicker showPickerWithTitle:@"Select video quality" rows:qualityStrings initialSelection:index doneBlock:^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
        
        self.styleCameraView.videoQuality = (CCCCameraVideoQuality)[qualityKeys[selectedIndex] integerValue];
        [self configureQuality];
        
    }cancelBlock:^(ActionSheetStringPicker *picker) {
        
    }origin:sender];
}

- (IBAction)selectStyleAction:(id)sender {
    self.stylesView.hidden = !self.stylesView.hidden;
}

- (IBAction)changeScaleTypeAction:(id)sender {
    switch (self.styleCameraView.scaleType) {
        case CCCCameraPreviewScaleTypeScaleAspectFit: {
            self.styleCameraView.scaleType = CCCCameraPreviewScaleTypeScaleAspectFill;
            break;
        }
        default: {
            self.styleCameraView.scaleType = CCCCameraPreviewScaleTypeScaleAspectFit;
            break;
        }
    }
    [self configureScaleType];
    
}

#pragma mark - CCCStyleCameraViewDelegate

- (void)cccStyleCameraViewDidStart:(CCCStyleCameraView *)cameraView {
    
    [self configureQuality];
    
}

- (CVImageBufferRef)cccStyleCameraView:(CCCStyleCameraView *)cameraView
                        processPreviewWithBuffer:(CVImageBufferRef)imageBuffer {
    
    if (_selectedStyle == 0) {
        return imageBuffer;
    }
    
    imageBuffer = (CVImageBufferRef)[self.tensorStyleUtils performStyleTransferWithPixelBuffer:(CVPixelBufferRef)imageBuffer preferredOutputWidth:160 preferredOutputHeight:0];
    
    return imageBuffer;
}

- (CIImage *)cccStyleCameraView:(CCCStyleCameraView *)cameraView processPreviewWithCIImage:(CIImage *)previewImage {
    
    // 計算FPS
    if (_previousFrameTime == 0) {
        _previousFrameTime = [NSDate date].timeIntervalSince1970;
    }
    else {
        NSTimeInterval currentFrameTime = [NSDate date].timeIntervalSince1970;
        _fps = 1/(currentFrameTime-_previousFrameTime);
        _previousFrameTime = currentFrameTime;
    }
    
    _previewSize = previewImage.extent.size;
    
    return previewImage;
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
    
    _selectedStyle = indexPath.item;
    if (indexPath.item == 0) {
        [self.tensorStyleUtils clearStyle];
    }
    else {
        [self.tensorStyleUtils selectStyle:(int)(indexPath.item-1)];
    }
    [self selectStyleAction:nil];
    
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

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    cell.highlighted = YES;
    
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    cell.highlighted = NO;
    
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
