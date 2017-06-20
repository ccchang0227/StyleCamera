//
//  CCCStyleCameraView.m
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/20.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import "CCCStyleCameraView.h"
#import "UIImage+CCCProcessor.h"

#import <CoreMotion/CoreMotion.h>
#import <GLKit/GLKit.h>


#pragma mark ****** CCCCameraGLKPreviewView ******

@interface CCCCameraGLKPreviewView : UIView {
@private
    EAGLContext *_eaglContext;
    CIContext *_ciContext;
    CGRect _videoPreviewViewBounds;
}

@property (retain, nonatomic) GLKView *videoPreviewView;

@end

@implementation CCCCameraGLKPreviewView

- (instancetype)init {
    self = [super init];
    if (self) {
        [self _setup];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _setup];
    }
    return self;
}

- (void)dealloc {
    [_videoPreviewView deleteDrawable];
    if (_eaglContext == [EAGLContext currentContext]) {
        [EAGLContext setCurrentContext:nil];
    }
    
#if !__has_feature(objc_arc)
    [_eaglContext release];
    [_videoPreviewView release];
    [super dealloc];
#endif
    
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    [_videoPreviewView bindDrawable];
    _videoPreviewViewBounds = CGRectZero;
    _videoPreviewViewBounds.size.width = _videoPreviewView.drawableWidth;
    _videoPreviewViewBounds.size.height = _videoPreviewView.drawableHeight;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    [_videoPreviewView bindDrawable];
    _videoPreviewViewBounds = CGRectZero;
    _videoPreviewViewBounds.size.width = _videoPreviewView.drawableWidth;
    _videoPreviewViewBounds.size.height = _videoPreviewView.drawableHeight;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [_videoPreviewView bindDrawable];
    _videoPreviewViewBounds = CGRectZero;
    _videoPreviewViewBounds.size.width = _videoPreviewView.drawableWidth;
    _videoPreviewViewBounds.size.height = _videoPreviewView.drawableHeight;
}

#pragma mark -

- (void)_setup {
    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = YES;
    
    _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    _videoPreviewView = [[GLKView alloc] initWithFrame:self.bounds context:_eaglContext];
    _videoPreviewView.enableSetNeedsDisplay = NO;
    _videoPreviewView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_videoPreviewView];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_videoPreviewView]|" options:NSLayoutFormatDirectionLeadingToTrailing metrics:nil views:NSDictionaryOfVariableBindings(_videoPreviewView)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_videoPreviewView]|" options:NSLayoutFormatDirectionLeadingToTrailing metrics:nil views:NSDictionaryOfVariableBindings(_videoPreviewView)]];
    
    // create the CIContext instance, note that this must be done after _videoPreviewView is properly set up
    _ciContext = [[CIContext contextWithEAGLContext:_eaglContext options:@{kCIContextWorkingColorSpace:[NSNull null]}] retain];
    
}

- (void)_renderImage:(CIImage*)image {
    CGRect sourceExtent = image.extent;
    
    CGFloat sourceAspect = sourceExtent.size.width/sourceExtent.size.height;
    CGFloat previewAspect = _videoPreviewViewBounds.size.width/_videoPreviewViewBounds.size.height;
    
    // we want to maintain the aspect radio of the screen size, so we clip the video image
    CGRect drawRect = sourceExtent;
    if (sourceAspect > previewAspect) {
        // use full height of the video image, and center crop the width
        drawRect.origin.x += (drawRect.size.width-drawRect.size.height*previewAspect)/2.0;
        drawRect.size.width = drawRect.size.height*previewAspect;
    }
    else {
        // use full width of the video image, and center crop the height
        drawRect.origin.y += (drawRect.size.height-drawRect.size.width/previewAspect)/2.0;
        drawRect.size.height = drawRect.size.width/previewAspect;
    }
    
    [_videoPreviewView bindDrawable];
    
    if (_eaglContext != [EAGLContext currentContext]) {
        [EAGLContext setCurrentContext:_eaglContext];
    }
    
    // clear eagl view to grey
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // set the blend mode to "source over" so that CI will use that
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    if (image) {
        [_ciContext drawImage:image inRect:_videoPreviewViewBounds fromRect:drawRect];
    }
    
    [_videoPreviewView display];
}

@end


#pragma mark ****** CCCStyleCameraView ******

@interface CCCStyleCameraView () {
    UIInterfaceOrientation _oldOrientation;
    
    BOOL _lockPictureOrientation;
    UIInterfaceOrientation _pictureOrientation;
}

@property (retain, nonatomic) CCCCameraGLKPreviewView *preview;

@property (retain, nonatomic) CMMotionManager *motionManager;
@property (retain, nonatomic) NSOperationQueue *motionQueue;

@end

@implementation CCCStyleCameraView

- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        [self _setup];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        [self _setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _setup];
    }
    return self;
}

- (void)dealloc {
    if (_cameraSession.isCameraRunning) {
        [self stopCameraRunning];
    }
    
    [_motionManager stopAccelerometerUpdates];
    [_motionQueue cancelAllOperations];
    [_motionQueue setSuspended:YES];
    
#if !__has_feature(objc_arc)
    [_cameraSession release];
    [_preview release];
    [_motionManager release];
    [_motionQueue release];
    [super dealloc];
#endif
    
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

- (CCCCameraGLKPreviewView*)preview {
    if (_preview == nil) {
        _preview = [[CCCCameraGLKPreviewView alloc] init];
        _preview.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_preview];
        
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_preview]|" options:NSLayoutFormatDirectionLeadingToTrailing metrics:nil views:NSDictionaryOfVariableBindings(_preview)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_preview]|" options:NSLayoutFormatDirectionLeadingToTrailing metrics:nil views:NSDictionaryOfVariableBindings(_preview)]];
    }
    
    return _preview;
}

- (CMMotionManager*)motionManager {
    if (_motionManager == nil) {
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.accelerometerUpdateInterval = 0.2;
    }
    
    return _motionManager;
}

- (NSOperationQueue*)motionQueue {
    if (_motionQueue == nil) {
        _motionQueue = [[NSOperationQueue alloc] init];
        _motionQueue.maxConcurrentOperationCount = 1;
    }
    
    return _motionQueue;
}

- (void)setScaleType:(CCCCameraPreviewScaleType)scaleType {
    _scaleType = scaleType;
}

- (void)setVideoQuality:(CCCCameraVideoQuality)videoQuality {
    _cameraSession.videoQuality = videoQuality;
}

- (CCCCameraVideoQuality)videoQuality {
    return _cameraSession.videoQuality;
}

- (void)setCameraCaptureMode:(CCCCameraCaptureMode)cameraCaptureMode {
    _cameraSession.cameraCaptureMode = cameraCaptureMode;
}

- (CCCCameraCaptureMode)cameraCaptureMode {
    return _cameraSession.cameraCaptureMode;
}

- (void)setCameraDevice:(CCCCameraDevice)cameraDevice {
    _cameraSession.cameraDevice = cameraDevice;
    
}

- (CCCCameraDevice)cameraDevice {
    return _cameraSession.cameraDevice;
}

- (void)setCameraFlashMode:(CCCCameraFlashMode)cameraFlashMode {
    _cameraSession.cameraFlashMode = cameraFlashMode;
}

- (CCCCameraFlashMode)cameraFlashMode {
    return _cameraSession.cameraFlashMode;
}

- (void)setCameraMirrorType:(CCCCameraVideoMirrorType)cameraMirrorType {
    _cameraSession.cameraMirrorType = cameraMirrorType;
}

- (CCCCameraVideoMirrorType)cameraMirrorType {
    return _cameraSession.cameraMirrorType;
}

- (void)setFaceDetectEnabled:(BOOL)faceDetectEnabled {
    _cameraSession.faceDetectEnabled = faceDetectEnabled;
}

- (BOOL)isFaceDetectEnabled {
    return _cameraSession.isFaceDetectEnabled;
}

- (void)setBarcodeScanEnabled:(BOOL)barcodeScanEnabled {
    _cameraSession.barcodeScanEnabled = NO;
}

- (BOOL)isBarcodeScanEnabled {
    return NO;
}

- (NSTimeInterval)recordedVideoDuration {
    return _cameraSession.recordedVideoDuration;
}

- (void)setMaxVideoDuration:(NSTimeInterval)maxVideoDuration {
    _cameraSession.maxVideoDuration = maxVideoDuration;
}

- (NSTimeInterval)maxVideoDuration {
    return _cameraSession.maxVideoDuration;
}

- (void)setMuteVideo:(BOOL)muteVideo {
    _cameraSession.muteVideo = muteVideo;
}

- (BOOL)muteVideo {
    return _cameraSession.muteVideo;
}

#pragma mark -

- (void)_setup {
    self.clipsToBounds = YES;
    
    _cameraSession = [[CCCCameraSession alloc] init];
    _cameraSession.delegate = self;
    _cameraSession.barcodeScanEnabled = NO;
    
    self.preview.userInteractionEnabled = NO;
    
    self.scaleType = CCCCameraPreviewScaleTypeScaleAspectFit;
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tapGesture:)];
    [self addGestureRecognizer:tapGestureRecognizer];
    [tapGestureRecognizer release];
    
    UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(_pinchGesture:)];
    [self addGestureRecognizer:pinchGestureRecognizer];
    [pinchGestureRecognizer release];
    
    _oldOrientation = UIInterfaceOrientationUnknown;
    
}

- (NSDictionary*)_editedMetadataDictionary:(NSDictionary*)sourceMetadata ofImage:(UIImage*)image {
    CFMutableDictionaryRef mutableMetadata = CFDictionaryCreateMutableCopy(NULL, 0, (CFDictionaryRef)sourceMetadata);
    
    if (CFDictionaryContainsKey(mutableMetadata, kCGImagePropertyExifDictionary)) {
        CFDictionaryRef exif = CFDictionaryGetValue(mutableMetadata, kCGImagePropertyExifDictionary);
        CFMutableDictionaryRef mutableExif = CFDictionaryCreateMutableCopy(NULL, 0, exif);
        CFDictionarySetValue(mutableExif, kCGImagePropertyExifPixelXDimension, (CFNumberRef)@(CGImageGetWidth(image.CGImage)));
        CFDictionarySetValue(mutableExif, kCGImagePropertyExifPixelYDimension, (CFNumberRef)@(CGImageGetHeight(image.CGImage)));
        CFDictionarySetValue(mutableMetadata, kCGImagePropertyExifDictionary, mutableExif);
        CFRelease(mutableExif);
    }
    
    CFDictionarySetValue(mutableMetadata, kCGImagePropertyPixelWidth, (CFNumberRef)@(CGImageGetWidth(image.CGImage)));
    CFDictionarySetValue(mutableMetadata, kCGImagePropertyPixelHeight, (CFNumberRef)@(CGImageGetHeight(image.CGImage)));
    
    CGImagePropertyOrientation realOrientation = [self _imagePropertyOrientationFromUIImageOrientation:image.imageOrientation];
    CFDictionarySetValue(mutableMetadata, kCGImagePropertyOrientation, (CFNumberRef)@(realOrientation));
    
    if (CFDictionaryContainsKey(mutableMetadata, kCGImagePropertyTIFFDictionary)) {
        CFDictionaryRef tiff = CFDictionaryGetValue(mutableMetadata, kCGImagePropertyTIFFDictionary);
        CFMutableDictionaryRef mutableTiff = CFDictionaryCreateMutableCopy(NULL, 0, tiff);
        CFDictionarySetValue(mutableTiff, kCGImagePropertyTIFFOrientation, (CFNumberRef)@(realOrientation));
        CFDictionarySetValue(mutableMetadata, kCGImagePropertyTIFFDictionary, mutableTiff);
        CFRelease(mutableTiff);
    }
    
    if (CFDictionaryContainsKey(mutableMetadata, kCGImagePropertyIPTCDictionary)) {
        CFDictionaryRef iptc = CFDictionaryGetValue(mutableMetadata, kCGImagePropertyIPTCDictionary);
        CFMutableDictionaryRef mutableIptc = CFDictionaryCreateMutableCopy(NULL, 0, iptc);
        size_t imageWidth = CGImageGetWidth(image.CGImage);
        size_t imageHeight = CGImageGetHeight(image.CGImage);
        if (imageWidth > imageHeight) {
            CFDictionarySetValue(mutableIptc, kCGImagePropertyIPTCImageOrientation, (CFStringRef)@"L");
        }
        else if (imageWidth < imageHeight) {
            CFDictionarySetValue(mutableIptc, kCGImagePropertyIPTCImageOrientation, (CFStringRef)@"P");
        }
        else {
            CFDictionarySetValue(mutableIptc, kCGImagePropertyIPTCImageOrientation, (CFStringRef)@"S");
        }
        CFDictionarySetValue(mutableMetadata, kCGImagePropertyIPTCDictionary, mutableIptc);
        CFRelease(mutableIptc);
    }
    
    NSDictionary *destMetadata = [NSDictionary dictionaryWithDictionary:(NSDictionary*)mutableMetadata];
    
    CFRelease(mutableMetadata);
    
    return destMetadata;
}

- (CGImagePropertyOrientation)_imagePropertyOrientationFromUIImageOrientation:(UIImageOrientation)imageOrientation {
    switch (imageOrientation) {
        case UIImageOrientationUp:
            return kCGImagePropertyOrientationUp;
            break;
        case UIImageOrientationUpMirrored:
            return kCGImagePropertyOrientationUpMirrored;
            break;
        case UIImageOrientationDown:
            return kCGImagePropertyOrientationDown;
            break;
        case UIImageOrientationDownMirrored:
            return kCGImagePropertyOrientationDownMirrored;
            break;
        case UIImageOrientationLeftMirrored:
            return kCGImagePropertyOrientationLeftMirrored;
            break;
        case UIImageOrientationRight:
            return kCGImagePropertyOrientationRight;
            break;
        case UIImageOrientationRightMirrored:
            return kCGImagePropertyOrientationRightMirrored;
            break;
        case UIImageOrientationLeft:
            return kCGImagePropertyOrientationLeft;
            break;
        default:
            return kCGImagePropertyOrientationUp;
            break;
    }
}

- (UIImage*)_writeExifToPostProcessedImage:(UIImage*)image metadata:(NSDictionary*)metadata {
    if (!image) {
        return image;
    }
    if (!metadata || metadata.count == 0) {
        return image;
    }
    
    metadata = [self _editedMetadataDictionary:metadata ofImage:image];
    
    CFDictionaryRef exif = CFDictionaryGetValue((CFDictionaryRef)metadata, kCGImagePropertyExifDictionary);
    
    CFMutableDictionaryRef mutableExif = CFDictionaryCreateMutableCopy(NULL, 0, exif);
    CFDictionarySetValue(mutableExif, kCGImagePropertyExifPixelXDimension, (CFNumberRef)@(CGImageGetWidth(image.CGImage)));
    CFDictionarySetValue(mutableExif, kCGImagePropertyExifPixelYDimension, (CFNumberRef)@(CGImageGetHeight(image.CGImage)));
    
    NSData *data = UIImageJPEGRepresentation(image, 1.0);
    NSLog(@"1:%lu", (unsigned long)data.length);
    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)data, NULL);
    CFDictionaryRef cfMetadata =  CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    
    CFMutableDictionaryRef mutableMetadata = CFDictionaryCreateMutableCopy(NULL, 0, cfMetadata);
    CFRelease(cfMetadata);
    
    CFDictionarySetValue(mutableMetadata, kCGImagePropertyExifDictionary, mutableExif);
    
    CFStringRef UTI = CGImageSourceGetType(source);
    NSMutableData *dataDest = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((CFMutableDataRef)dataDest, UTI, 1, NULL);
    
    CGImageDestinationAddImageFromSource(destination, source, 0, mutableMetadata);
    
    BOOL success = CGImageDestinationFinalize(destination);
    
    UIImage *imageDest = nil;
    if (success) {
        imageDest = [UIImage imageWithData:dataDest];
        NSLog(@"2:%lu", (unsigned long)dataDest.length);
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* docDir = [paths objectAtIndex:0];
        [dataDest writeToFile:[NSString stringWithFormat:@"%@/ccccamera1.jpg", docDir] atomically:YES];
    }
    else {
        imageDest = image;
    }
    
    CFRelease(mutableExif);
    CFRelease(mutableMetadata);
    CFRelease(source);
    CFRelease(destination);
    
    return imageDest;
}

- (UIImageOrientation)_imageOrientationFromInterfaceOrientation:(UIInterfaceOrientation)orientation {
    switch (orientation) {
        case UIInterfaceOrientationPortrait:
            if (_cameraSession.cameraMirrorType == CCCCameraVideoMirrorTypeYes) {
                return UIImageOrientationLeftMirrored;
            }
            else {
                return UIImageOrientationRight;
            }
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            if (_cameraSession.cameraMirrorType == CCCCameraVideoMirrorTypeYes) {
                return UIImageOrientationRightMirrored;
            }
            else {
                return UIImageOrientationLeft;
            }
            break;
        case UIInterfaceOrientationLandscapeLeft:
            if (_cameraSession.cameraMirrorType == CCCCameraVideoMirrorTypeYes) {
                if (_cameraSession.cameraDevice == CCCCameraDeviceFront) {
                    return UIImageOrientationUpMirrored;
                }
                else {
                    return UIImageOrientationDownMirrored;
                }
            }
            else {
                if (_cameraSession.cameraDevice == CCCCameraDeviceFront) {
                    return UIImageOrientationUp;
                }
                else {
                    return UIImageOrientationDown;
                }
            }
            break;
        case UIInterfaceOrientationLandscapeRight:
            if (_cameraSession.cameraMirrorType == CCCCameraVideoMirrorTypeYes) {
                if (_cameraSession.cameraDevice == CCCCameraDeviceFront) {
                    return UIImageOrientationDownMirrored;
                }
                else {
                    return UIImageOrientationUpMirrored;
                }
            }
            else {
                if (_cameraSession.cameraDevice == CCCCameraDeviceFront) {
                    return UIImageOrientationDown;
                }
                else {
                    return UIImageOrientationUp;
                }
            }
            break;
        default:
            return -1;
            break;
    }
}

- (CIImage*)_processedImageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    /*
    size_t w, h;
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    w = CVPixelBufferGetWidth(imageBuffer);
    h = CVPixelBufferGetHeight(imageBuffer);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    */
    if (_delegate && [_delegate respondsToSelector:@selector(cccStyleCameraView:processPreview:)]) {
        imageBuffer = [_delegate cccStyleCameraView:self processPreview:imageBuffer];
    }
    
    CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:(CVPixelBufferRef)imageBuffer options:nil];
    CGSize imageSize = CGSizeMake(CGRectGetHeight(sourceImage.extent), CGRectGetWidth(sourceImage.extent));
    
    CGAffineTransform transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(-M_PI_2), -CGRectGetWidth(sourceImage.extent), 0);
    if (_cameraSession.cameraDevice == CCCCameraDeviceFront) {
        transform = CGAffineTransformScale(transform, 1, -1);
        transform = CGAffineTransformTranslate(transform, 0, -CGRectGetHeight(sourceImage.extent));
    }
    CIFilter *filter = [CIFilter filterWithName:@"CIAffineTransform"];
    [filter setValue:sourceImage forKey:kCIInputImageKey];
    [filter setValue:[NSValue value:&transform withObjCType:@encode(CGAffineTransform)] forKey:@"inputTransform"];
    sourceImage = [filter.outputImage imageByCroppingToRect:CGRectMake(0, 0, imageSize.width, imageSize.height)];
    
    return sourceImage;
}

#pragma mark -

+ (BOOL)isCameraAccess {
    return [CCCCameraSession isCameraAccess];
}

- (BOOL)isCameraRunning {
    return _cameraSession.isCameraRunning;
}

- (void)startCameraRunning {
    [self.cameraSession startCameraRunning];
}

- (void)stopCameraRunning {
    [self.cameraSession stopCameraRunning];
}

#pragma mark -

- (void)lockPictureOrientationWithOrientation:(UIInterfaceOrientation)orientation {
    _lockPictureOrientation = YES;
    _pictureOrientation = orientation;
}

- (void)unlockPictureOrientation {
    _lockPictureOrientation = NO;
    _pictureOrientation = UIInterfaceOrientationUnknown;
}

- (void)takePictureWithCompletionHandler:(void(^)(UIImage *picture, NSDictionary *pictureMetadata))handler {
    if (!self.isCameraRunning) {
        return;
    }
    
    UIInterfaceOrientation currentDeviceOrientation = _oldOrientation;
    
    [_cameraSession takePictureWithCompletionHandler:^(UIImage *picture, NSDictionary *pictureMetadata) {
        
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
            
            UIImage *image = picture;
            
            if (_lockPictureOrientation) {
                UIImageOrientation imageOrientation = [self _imageOrientationFromInterfaceOrientation:_pictureOrientation];
                if (imageOrientation >= 0) {
                    image = [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:imageOrientation];
                }
            }
            
            switch (picture.imageOrientation) {
                case UIImageOrientationUp:
                    NSLog(@"%@", CCC2String(UIImageOrientationUp));
                    break;
                case UIImageOrientationDown:
                    NSLog(@"%@", CCC2String(UIImageOrientationDown));
                    break;
                case UIImageOrientationLeft:
                    NSLog(@"%@", CCC2String(UIImageOrientationLeft));
                    break;
                case UIImageOrientationRight:
                    NSLog(@"%@", CCC2String(UIImageOrientationRight));
                    break;
                case UIImageOrientationUpMirrored:
                    NSLog(@"%@", CCC2String(UIImageOrientationUpMirrored));
                    break;
                case UIImageOrientationDownMirrored:
                    NSLog(@"%@", CCC2String(UIImageOrientationDownMirrored));
                    break;
                case UIImageOrientationLeftMirrored:
                    NSLog(@"%@", CCC2String(UIImageOrientationLeftMirrored));
                    break;
                case UIImageOrientationRightMirrored:
                    NSLog(@"%@", CCC2String(UIImageOrientationRightMirrored));
                    break;
                default:
                    break;
            }
            
            image = [image cg_rotatedImageWithCorrectOrientation];
            
            if (_scaleType == CCCCameraPreviewScaleTypeScaleAspectFill) {
                CGRect cropLocation = CGRectMake(0, 0, image.size.width, image.size.height);
                CGSize sizeImage = image.size;
                CGSize sizeView = self.bounds.size;
                if (UIInterfaceOrientationIsLandscape(currentDeviceOrientation) && !_lockPictureOrientation) {
                    sizeView = CGSizeMake(sizeView.height, sizeView.width);
                }
                else if (UIInterfaceOrientationIsLandscape(_pictureOrientation) && _lockPictureOrientation) {
                    sizeView = CGSizeMake(sizeView.height, sizeView.width);
                }
                if (!CGSizeEqualToSize(sizeImage, CGSizeZero) && !CGSizeEqualToSize(sizeView, CGSizeZero)) {
                    CGFloat scale = sizeImage.width/sizeView.width;
                    if (scale*sizeView.height > sizeImage.height) {
                        scale = sizeImage.height/sizeView.height;
                    }
                    cropLocation.size.width = sizeView.width*scale;
                    cropLocation.size.height = sizeView.height*scale;
                    cropLocation.origin.x = (sizeImage.width-cropLocation.size.width)/2.0;
                    cropLocation.origin.y = (sizeImage.height-cropLocation.size.height)/2.0;
                }
                
                if (!CGSizeEqualToSize(cropLocation.size, sizeImage)) {
                    image = [image cg_croppedImageInRect:cropLocation];
                }
            }
            
            NSDictionary *dicMetadata = [self _editedMetadataDictionary:pictureMetadata ofImage:image];
            
            dispatch_async(dispatch_get_main_queue(), ^ {
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                
                if (handler) {
                    handler(image, dicMetadata);
                }
            });
        });
        
    }];
}

- (BOOL)isVideoRecording {
    return _cameraSession.isVideoRecording;
}

- (void)startVideoRecording {
    switch (_scaleType) {
        case CCCCameraPreviewScaleTypeScaleAspectFill:
            _cameraSession.videoSizeRatio = CGRectGetWidth(self.bounds)/CGRectGetHeight(self.bounds);
            break;
        case CCCCameraPreviewScaleTypeScaleAspectFit:
            _cameraSession.videoSizeRatio = 0.0f;
            break;
        default:
            break;
    }
    
    [_cameraSession startVideoRecording];
}

- (void)stopVideoRecording {
    [_cameraSession stopVideoRecording];
}

#pragma mark - Orientation

- (void)startOrientationObserver {
    [self orientationChanged:nil];
    
    _oldOrientation = UIInterfaceOrientationUnknown;
    if (self.motionManager.isAccelerometerAvailable) {
        [self.motionManager startAccelerometerUpdatesToQueue:self.motionQueue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
            
            if (accelerometerData) {
                UIInterfaceOrientation newOrientation;
                if (accelerometerData.acceleration.x >= 0.5) {
                    newOrientation = UIInterfaceOrientationLandscapeLeft;
                }
                else if (accelerometerData.acceleration.x <= -0.5) {
                    newOrientation = UIInterfaceOrientationLandscapeRight;
                }
                else if (accelerometerData.acceleration.y <= -0.5) {
                    newOrientation = UIInterfaceOrientationPortrait;
                }
                else if (accelerometerData.acceleration.y >= 0.5) {
                    newOrientation = UIInterfaceOrientationPortraitUpsideDown;
                }
                else {
                    return;
                }
                
                if (newOrientation == _oldOrientation) {
                    return;
                }
                
                _oldOrientation = newOrientation;
                
                if (_cameraSession.session.isRunning) {
                    AVCaptureVideoOrientation videoOrientation = [self videoOrientationFromDeviceOrientation:(UIDeviceOrientation)newOrientation];
                    [self _changeVideoOrientationWithOrientation:videoOrientation];
                }
            }
            
        }];
        if (self.motionManager.isAccelerometerActive && self.motionManager.accelerometerData) {
        }
    }
}

- (void)stopOrientationObserver {
    if (self.motionManager.isAccelerometerAvailable && self.motionManager.isAccelerometerActive) {
        [self.motionManager stopAccelerometerUpdates];
        [self.motionQueue cancelAllOperations];
        self.motionQueue = nil;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _oldOrientation = UIInterfaceOrientationUnknown;
    });
}

- (void)orientationChanged:(NSNotification *)notification {
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    AVCaptureVideoOrientation videoOrientation = [self videoOrientationFromDeviceOrientation:orientation];
    
    [self _changeVideoOrientationWithOrientation:videoOrientation];
}

- (AVCaptureVideoOrientation)videoOrientationFromDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
    AVCaptureVideoOrientation orientation;
    switch (deviceOrientation) {
        case UIDeviceOrientationLandscapeLeft:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIDeviceOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        default:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
    }
    
    return orientation;
}

- (void)_changeVideoOrientationWithOrientation:(AVCaptureVideoOrientation)videoOrientation {
    if (![CCCCameraSession isCameraAccess]) {
        return;
    }
    
    [_cameraSession setCameraVideoOrientation:videoOrientation];
}

#pragma mark - Tap Gesture

- (void)_tapGesture:(UITapGestureRecognizer*)gestureRecognizer {
    if (![CCCCameraSession isCameraAccess]) {
        return;
    }
    
    [_cameraSession setCameraFocusPoint:CGPointMake(0.5, 0.5)];
}

#pragma mark - Pinch Gesture

- (void)_pinchGesture:(UIPinchGestureRecognizer*)gestureRecognizer {
    if (![CCCCameraSession isCameraAccess]) {
        return;
    }
    
    CGFloat scale = [_cameraSession zoomWithPinchGesture:gestureRecognizer];
    
    self.preview.layer.affineTransform = CGAffineTransformMakeScale(scale, scale);
}

#pragma mark - CCCCameraSessionDelegate

- (void)cccCameraSessionDidStart:(CCCCameraSession*)cameraSession {
    [self startOrientationObserver];
    if (_oldOrientation != UIInterfaceOrientationUnknown) {
        AVCaptureVideoOrientation videoOrientation = [self videoOrientationFromDeviceOrientation:(UIDeviceOrientation)_oldOrientation];
        [self _changeVideoOrientationWithOrientation:videoOrientation];
    }
    
    if (_delegate && [_delegate respondsToSelector:@selector(cccStyleCameraViewDidStart:)]) {
        [_delegate cccStyleCameraViewDidStart:self];
    }
    
}

- (void)cccCameraSessionDidStop:(CCCCameraSession *)cameraSession {
    [self stopOrientationObserver];
    
    if (_delegate && [_delegate respondsToSelector:@selector(cccStyleCameraViewDidStop:)]) {
        [_delegate cccStyleCameraViewDidStop:self];
    }
    
}

- (void)cccCameraSession:(CCCCameraSession*)cameraSession didReceiveRuntimeError:(NSError*)error {
    
}

- (void)cccCameraSessionDidStartVideoRecording:(CCCCameraSession*)cameraSession {
}

- (void)cccCameraSession:(CCCCameraSession *)cameraSession didFinishVideoRecordingToFile:(NSURL*)fileURL error:(NSError*)error {
}

- (void)cccCameraSession:(CCCCameraSession*)cameraSession shouldUpdateCorners:(NSArray*)cornersArray {
}

- (void)cccCameraSession:(CCCCameraSession*)cameraSession didReceiveSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection {
    
    CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDesc);
    if (mediaType == kCMMediaType_Audio) {
        return;
    }
    
    CIImage *image = [self _processedImageFromSampleBuffer:sampleBuffer];
    [self.preview _renderImage:image];
    
}

#pragma mark - Static

+ (NSUInteger)numberOfCameraDevice {
    return [CCCCameraSession numberOfCameraDevice];
}

+ (BOOL)isCameraDeviceAvailable:(CCCCameraDevice)cameraDevice {
    return [CCCCameraSession isCameraDeviceAvailable:cameraDevice];
}

+ (BOOL)isFlashAvailableForCameraDevice:(CCCCameraDevice)cameraDevice {
    return [CCCCameraSession isFlashAvailableForCameraDevice:cameraDevice];
}

+ (UIImage*)previewImageForVideo:(NSURL*)videoURL atTime:(NSTimeInterval)time {
    return [CCCCameraSession previewImageForVideo:videoURL atTime:time];
}

+ (void)convertVideoToMPEG4Format:(NSURL*)srcUrl destinationPath:(NSString*)path completionHandler:(void(^)(BOOL successful, NSError *error))handler {
    [CCCCameraSession convertVideoToMPEG4Format:srcUrl destinationPath:path completionHandler:handler];
}

@end
