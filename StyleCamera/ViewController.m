//
//  ViewController.m
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/20.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import "ViewController.h"
#import "CCCStyleCameraView.h"
#import <ActionSheetPicker-3.0/ActionSheetPicker.h>


@interface ViewController () <CCCStyleCameraViewDelegate> {
    NSTimeInterval _previousFrameTime;
    CGFloat _fps;
    
    CGSize _previewSize;
}

@property (retain, nonatomic) IBOutlet UIBarButtonItem *switchButton;

@property (retain, nonatomic) IBOutlet CCCStyleCameraView *styleCameraView;
@property (retain, nonatomic) IBOutlet UILabel *previewSizeLabel;
@property (retain, nonatomic) IBOutlet UIButton *qualityButton;
@property (retain, nonatomic) IBOutlet UIButton *scaleTypeButton;

@property (retain, nonatomic) NSTimer *fpsTimer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _previousFrameTime = 0;
    _fps = 0;
    _previewSize = CGSizeZero;
    
    self.styleCameraView.delegate = self;
    self.styleCameraView.videoQuality = CCCCameraVideoQualityPhoto;
    
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
    [_qualityButton release];
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

@end
