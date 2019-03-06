//
//  ViewController.m
//  metalDemoyuv03-06
//
//  Created by 王洪飞 on 2019/3/6.
//  Copyright © 2019 王洪飞. All rights reserved.
//

#import "ViewController.h"
#import "WFType.h"
#import <AVFoundation/AVFoundation.h>
#import <MetalKit/MetalKit.h>
#import <simd/simd.h>

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate,MTKViewDelegate>
{
    AVCaptureSession *mCaptureSession;
    AVCaptureDeviceInput *mCaptureInput;
    AVCaptureVideoDataOutput *mCaptureOutput;
    
    vector_uint2 viewportSize;
    MTKView *mMtkview;
    id <MTLDevice> mDevice;
    id <MTLCommandQueue> mCmdQueue;
    id <MTLRenderPipelineState> mPipeline;
    id <MTLBuffer> mBuffer;
    id <MTLTexture> mTexture;
    CVMetalTextureCacheRef mTextureCache;
    NSUInteger vertexCount;
    
    id<MTLTexture> mTextureY;
    id<MTLTexture> mTextureUV;
    
    id <MTLBuffer> mConvertMatrix;
    
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupSession];
    [self setMetal];
    [self setPipeline];
    [self setVertex];
    [self setupMatrix];
    // Do any additional setup after loading the view, typically from a nib.
}
-(void)setMetal{
    mMtkview = [[MTKView alloc] initWithFrame:UIScreen.mainScreen.bounds device:MTLCreateSystemDefaultDevice()];
    mDevice = mMtkview.device;
    self.view = mMtkview;
    mMtkview.delegate = self;
    mCmdQueue = [mDevice newCommandQueue];
    
    CVMetalTextureCacheCreate(NULL, NULL, mDevice, NULL, &mTextureCache);
}

-(void)setVertex {
    WFVertex v1 = {{-1.0,1.0},{0.0,0.0}};
    WFVertex v2 = {{1.0,1.0},{1.0,0.0}};
    WFVertex v3 = {{-1.0,-1.0},{0.0,1.0}};
    WFVertex v4 = {{1.0,-1.0},{1.0,1.0}};
    WFVertex vertexs[] = {v1,v2,v3,v2,v3,v4};
    vertexCount = sizeof(vertexs) / sizeof(WFVertex);
    mBuffer = [mDevice newBufferWithBytes:vertexs length:sizeof(vertexs) options:MTLResourceStorageModeShared];
}

-(void)setPipeline {
    id <MTLLibrary> library = [mDevice newDefaultLibrary];
    id <MTLFunction> vertexfunc = [library newFunctionWithName:@"verfunc"];
    id <MTLFunction> fragfunc = [library newFunctionWithName:@"fragfunc"];
    MTLRenderPipelineDescriptor *renderdes = [MTLRenderPipelineDescriptor new];
    renderdes.vertexFunction = vertexfunc;
    renderdes.fragmentFunction = fragfunc;
    renderdes.colorAttachments[0].pixelFormat = mMtkview.colorPixelFormat;
    mPipeline = [mDevice newRenderPipelineStateWithDescriptor:renderdes error:nil];
}

-(void)setTexture:(CMSampleBufferRef)samplebuffer {
    CVPixelBufferRef pixelbuffer = CMSampleBufferGetImageBuffer(samplebuffer);
    // textureY
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelbuffer, 0);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelbuffer, 0);
        CVMetalTextureRef texture = NULL;
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, mTextureCache, pixelbuffer, NULL, MTLPixelFormatR8Unorm, width, height, 0, &texture);
        if (status == kCVReturnSuccess) {
            mTextureY = CVMetalTextureGetTexture(texture);
            CFRelease(texture);
        }
    }
    // textureUV
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelbuffer, 1);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelbuffer, 1);
        CVMetalTextureRef texture = NULL;
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, mTextureCache, pixelbuffer, NULL, MTLPixelFormatRG8Unorm, width, height, 1, &texture);
        if (status == kCVReturnSuccess) {
            mTextureUV = CVMetalTextureGetTexture(texture);
            CFRelease(texture);
        }
    }
    
//    CFRelease(samplebuffer);
    /**
     rgb 数据
     
    size_t width = CVPixelBufferGetWidth(pixelbuffer);
    size_t heigth = CVPixelBufferGetHeight(pixelbuffer);
    CVMetalTextureRef temTexture = nil;
    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, mTextureCache, pixelbuffer, NULL, MTLPixelFormatBGRA8Unorm, width, heigth, 0, &temTexture);
    if (status == kCVReturnSuccess) {
        mMtkview.drawableSize = CGSizeMake(width, heigth);
        mTexture = CVMetalTextureGetTexture(temTexture);
        CFRelease(temTexture);
    }
     */
}

- (void)setupMatrix{
    matrix_float3x3 kColorConversion601FullRangeMatrix = (matrix_float3x3){
        (simd_float3){1.0,    1.0,    1.0},
        (simd_float3){0.0,    -0.343, 1.765},
        (simd_float3){1.4,    -0.711, 0.0},
    };
    vector_float3 kColorConversion601FullRangeOffset = (vector_float3){ -(16.0/255.0), -0.5, -0.5}; // 这个是偏移
    
    WFConvertMatrix converMatrix;
    converMatrix.matrix = kColorConversion601FullRangeMatrix;
    converMatrix.offset = kColorConversion601FullRangeOffset;
    mConvertMatrix = [mDevice newBufferWithBytes:&converMatrix length:sizeof(WFConvertMatrix) options:MTLResourceStorageModeShared];
}

-(void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    viewportSize = (vector_uint2){size.width, size.height};
}

-(void)drawInMTKView:(MTKView *)view {
    if (mTextureY && mTextureUV) {
        id <MTLCommandBuffer> cmdBuffer = [mCmdQueue commandBuffer];
        MTLRenderPassDescriptor *passdes = view.currentRenderPassDescriptor;
        if (passdes != nil) {
            id <MTLRenderCommandEncoder> cmdEncoder = [cmdBuffer renderCommandEncoderWithDescriptor:passdes];
            [cmdEncoder setViewport:(MTLViewport){0.0,0.0,viewportSize.x,viewportSize.y, -1.0,1.0}];
            [cmdEncoder setRenderPipelineState:mPipeline];
            [cmdEncoder setVertexBuffer:mBuffer offset:0 atIndex:0];

            [cmdEncoder setFragmentTexture:mTextureY atIndex:0];
            [cmdEncoder setFragmentTexture:mTextureUV atIndex:1];
            [cmdEncoder setFragmentBuffer:mConvertMatrix offset:0 atIndex:WFFragmentInputindexMatrix];
            [cmdEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:vertexCount];
            
            
            /**
             rgb 数据
             
            [cmdEncoder setFragmentTexture:mTexture atIndex:0];
            [cmdEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:vertexCount];
            */
            [cmdEncoder endEncoding];
            [cmdBuffer presentDrawable:view.currentDrawable];
            [cmdBuffer commit];
        }
    }
}



-(void)setupSession {
    mCaptureSession = [[AVCaptureSession alloc] init];
    mCaptureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
    AVCaptureDevice *cameraDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    
    mCaptureInput = [[AVCaptureDeviceInput alloc] initWithDevice:cameraDevice error:nil];
    if ([mCaptureSession canAddInput:mCaptureInput]) {
        [mCaptureSession addInput:mCaptureInput];
    }

    mCaptureOutput = [[AVCaptureVideoDataOutput alloc] init];
    [mCaptureOutput setAlwaysDiscardsLateVideoFrames:NO];
    [mCaptureOutput setSampleBufferDelegate:self queue:dispatch_queue_create("bd", DISPATCH_QUEUE_SERIAL)];
    
    if ([mCaptureSession canAddOutput:mCaptureOutput]) {
        [mCaptureSession addOutput:mCaptureOutput];
    }
    NSLog(@"out = %@ ary = %@",mCaptureOutput,[mCaptureOutput availableVideoCodecTypes]);
    [mCaptureOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    AVCaptureConnection *connection = [mCaptureOutput connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    [mCaptureSession startRunning];
    
}

-(void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    NSLog(@"data");
    [self setTexture:sampleBuffer];
}

@end
