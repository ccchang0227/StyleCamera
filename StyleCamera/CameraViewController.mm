//
//  CameraViewController.mm
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/20.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import "CameraViewController.h"
#import "CCCStyleCameraView.h"


@interface CameraViewController () <CCCStyleCameraViewDelegate>

@property (retain, nonatomic) IBOutlet UIBarButtonItem *switchButton;

@property (retain, nonatomic) IBOutlet CCCStyleCameraView *styleCameraView;
@property (retain, nonatomic) IBOutlet UILabel *previewSizeLabel;

@end

@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.styleCameraView.delegate = self;
    self.styleCameraView.videoQuality = CCCCameraVideoQualityPhoto;
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_styleCameraView release];
    [_switchButton release];
    [_previewSizeLabel release];
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self initView];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.styleCameraView startCameraRunning];
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.styleCameraView stopCameraRunning];
    
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
}

#pragma mark - Button Actions

- (IBAction)switchCamera:(id)sender {
    if ([CCCCameraView numberOfCameraDevice] <= 1) {
        return;
    }
    
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
    
    self.previewSizeLabel.text = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.previewSizeLabel.text = [NSString stringWithFormat:@"%ld x %ld", (long)self.styleCameraView.cameraSession.currentPreviewSize.width, (long)self.styleCameraView.cameraSession.currentPreviewSize.height];
    });
    
}

#pragma mark - CCCStyleCameraViewDelegate

- (void)cccStyleCameraViewDidStart:(CCCStyleCameraView *)cameraView {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.previewSizeLabel.text = [NSString stringWithFormat:@"%ld x %ld", (long)cameraView.cameraSession.currentPreviewSize.width, (long)cameraView.cameraSession.currentPreviewSize.height];
    });
}

- (CVImageBufferRef)cccStyleCameraView:(CCCStyleCameraView *)cameraView
                        processPreview:(CVImageBufferRef)imageBuffer {
    
    //TODO: 合上tensorflow?
    
    return imageBuffer;
}

@end
