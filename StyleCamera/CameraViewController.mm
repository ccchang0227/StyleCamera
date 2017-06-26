//
//  CameraViewController.mm
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/20.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import "CameraViewController.h"
#import "CCCStyleCameraView.h"


@interface CameraViewController () <CCCStyleCameraViewDelegate> {
    NSTimeInterval _previousFrameTime;
    CGFloat _fps;
}

@property (retain, nonatomic) IBOutlet UIBarButtonItem *switchButton;

@property (retain, nonatomic) IBOutlet CCCStyleCameraView *styleCameraView;
@property (retain, nonatomic) IBOutlet UILabel *previewSizeLabel;

@property (retain, nonatomic) NSTimer *fpsTimer;

@end

@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _previousFrameTime = 0;
    
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
    [self.styleCameraView startCameraRunning];
    
    self.fpsTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(displayFps:) userInfo:nil repeats:YES];
    
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
}

// 顯示FPS
- (void)displayFps:(NSTimer *)theTimer {
    if (_fps == 0) {
        return;
    }
    
    self.previewSizeLabel.text = [NSString stringWithFormat:@"%ldx%ld, %.1f fps", (long)self.styleCameraView.cameraSession.currentPreviewSize.width, (long)self.styleCameraView.cameraSession.currentPreviewSize.height, _fps];
}

#pragma mark - Button Actions

- (IBAction)switchCamera:(id)sender {
    if ([CCCCameraView numberOfCameraDevice] <= 1) {
        return;
    }
    
    _previousFrameTime = 0;
    _fps = 0;
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
    
}

- (IBAction)closeAction:(id)sender {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - CCCStyleCameraViewDelegate

- (void)cccStyleCameraViewDidStart:(CCCStyleCameraView *)cameraView {
    
}

- (CVImageBufferRef)cccStyleCameraView:(CCCStyleCameraView *)cameraView
                        processPreviewWithBuffer:(CVImageBufferRef)imageBuffer {
    
    //TODO: 合上tensorflow?
    
    // 計算FPS
    if (_previousFrameTime == 0) {
        _previousFrameTime = [NSDate date].timeIntervalSince1970;
    }
    else {
        NSTimeInterval currentFrameTime = [NSDate date].timeIntervalSince1970;
        _fps = 1/(currentFrameTime-_previousFrameTime);
        _previousFrameTime = currentFrameTime;
    }
    
    return imageBuffer;
}

@end
