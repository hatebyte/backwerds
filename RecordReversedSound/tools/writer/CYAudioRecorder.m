//
//  CYAudioRecorder.m
//  Capture-Live-Camera
//
//  Created by hatebyte on 4/17/15.
//  Copyright (c) 2015 CaptureMedia. All rights reserved.
//

#import "CYAudioRecorder.h"
#import <UIKit/UIKit.h>
#import <mach/mach_time.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>
#import "CYUtilities.h"
// return max value for given values
#define max(a, b) (((a) > (b)) ? (a) : (b))
// return min value for given values
#define min(a, b) (((a) < (b)) ? (a) : (b))

static AudioUnitElement kOutputBusU                 = 0;
static AudioUnitElement kInputBusU                  = 1;
static Float64 kDeviceTimeScale                     = 1000000000.0f;
static double kAudioSampleRate                      = 44100.0f;
static UInt32 kNumChannels                          = 2;
static mach_timebase_info_data_t info;

@interface CYAudioRecorder ()

@property(nonatomic, strong) dispatch_queue_t conversionQueue;
@property(nonatomic, assign) AudioUnit rioUnit;
@property(nonatomic, assign) AudioConverterRef audioConverter;
@property(nonatomic, assign) AudioStreamBasicDescription pcmASBD;
@property(nonatomic, assign) CMFormatDescriptionRef cmformat;
@property(nonatomic, assign) AudioBuffer audioBuffer;
@property(nonatomic, assign) AudioComponentInstance audioUnit;
@property(nonatomic, assign) Float64 sampleRate;
@property(nonatomic, assign) CMTime duration;
@property(nonatomic, assign) ExtAudioFileRef recordedFileRef;
@property(nonatomic, strong) NSURL *outputURL;

- (void)cmSampleBuffer:(AudioBufferList *)audioBufferList
        numberOfFrames:(UInt32)inNumberFrames
                  time:(uint64_t)time;

@end

@implementation CYAudioRecorder

+ (void)shouldTryToAccessMicrophone:(void (^)(BOOL granted))handler {
    AVAuthorizationStatus authStatus                = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if(authStatus == AVAuthorizationStatusAuthorized) {
        handler(true);
    } else if(authStatus == AVAuthorizationStatusDenied) {
        handler(false);
    } else if(authStatus == AVAuthorizationStatusRestricted) {
        handler(false);
    } else if(authStatus == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:handler];
    } else {
        handler(false);
    }
}

#pragma mark helpers
OSStatus RecordingCallback(void *inRefCon,
                           AudioUnitRenderActionFlags *ioActionFlags,
                           const AudioTimeStamp *inTimeStamp,
                           UInt32 inBusNumber,
                           UInt32 inNumberFrames,
                           AudioBufferList *ioData) {
    
    CYAudioRecorder *recorder = (__bridge CYAudioRecorder *)inRefCon;
    
    
    // the place where the data gets rendered
    AudioBuffer buffer;
    
    // number of frame is usually 512 or 1024
    buffer.mDataByteSize                        = inNumberFrames * (kNumChannels * 2);
    buffer.mNumberChannels                      = kNumChannels;
    buffer.mData                                = malloc(inNumberFrames * (kNumChannels * 2));   // 4 for for 2 *  channe
    
    // we the buffer into a bufferlist in order to pass to renderer
    AudioBufferList bufferList;
    bufferList.mNumberBuffers                   = 1;
    bufferList.mBuffers[0]                      = buffer;

    // render input
    CheckError(AudioUnitRender(recorder.rioUnit,
                               ioActionFlags,
                               inTimeStamp,
                               inBusNumber,
                               inNumberFrames,
                               &bufferList),
               "Couldn't render from RemoteIO unit");
    
    /* Convert to nanoseconds */
    uint64_t time                               = inTimeStamp->mHostTime;
    time                                        *= info.numer;
    time                                        /= info.denom;

//    [recorder cmSampleBuffer:&bufferList numberOfFrames:inNumberFrames time:time];
    CheckError(ExtAudioFileWriteAsync(recorder.recordedFileRef,
                           inNumberFrames,
                           &bufferList), "Couldn't write to audio file ext");

    // release the memory
//    free(bufferList.mBuffers[0].mData);
    
    return noErr;
}

- (void)cmSampleBuffer:(AudioBufferList *)audioBufferList numberOfFrames:(UInt32)inNumberFrames time:(uint64_t)time {
    dispatch_sync(self.conversionQueue, ^{
        CMSampleBufferRef buff                      = NULL;
        CMTime presentationTime                     = CMTimeMake(time,  (UInt32)kDeviceTimeScale);
        CMSampleTimingInfo timing                   = {0};
        timing.presentationTimeStamp                = presentationTime;
        timing.duration                             = self.duration;
        timing.decodeTimeStamp                      = kCMTimeInvalid;
        
        CheckError(CMSampleBufferCreate(kCFAllocatorDefault,
                                        NULL,
                                        false,
                                        NULL,
                                        NULL,
                                        _cmformat,
                                        (CMItemCount)inNumberFrames,
                                        1,
                                        &timing,
                                        0,
                                        NULL,
                                        &buff),
                   "Could not create CMSampleBufferRef");
        
        CheckError(CMSampleBufferSetDataBufferFromAudioBufferList(buff,
                                                                  kCFAllocatorDefault,
                                                                  kCFAllocatorDefault,
                                                                  0,
                                                                  audioBufferList),
                   "Could not set data in CMSampleBufferRef");
        
        [self.sampleBufferDelegate didRenderAudioSampleBuffer:buff];
        CFRelease(buff);
    });
}

- (void)configure {
    @synchronized(self) {
        // USE THIS SESSION STUFF TO HANDLE INTERRUPTIONS FROM THE OS and ROUTE THROUGH BLUETOOTH, HEADPHONES, SPEAKERS
        AVAudioSession *session                     = [AVAudioSession sharedInstance];
        [session setActive:NO error:nil];
    
        self.sampleRate                             = kAudioSampleRate;
        self.duration                               = CMTimeMake(1, self.sampleRate);
        [session setActive:YES error:nil];

        if (!session.inputAvailable) {
            UIAlertView *noInputAlert               = [[UIAlertView alloc] initWithTitle:@"No audio input"
                                                                                 message:@"No audio input device is currently attached"
                                                                                delegate:nil
                                                                       cancelButtonTitle:@"OK"
                                                                       otherButtonTitles:nil];
            [noInputAlert show];
            return;
        }
        
        self.conversionQueue                        = dispatch_queue_create("com.capturemedia.ios.microphone.audioqueue", DISPATCH_QUEUE_SERIAL);
        mach_timebase_info(&info);
        
        [self setUpRecorder];
        CheckError(AudioUnitInitialize(self.rioUnit), "Couldn't initialize RIO unit");
    }
}

- (void)setUpRecorder {
    AudioComponentDescription audioCompDesc;
    audioCompDesc.componentType                 = kAudioUnitType_Output;
    audioCompDesc.componentSubType              = kAudioUnitSubType_RemoteIO;
    audioCompDesc.componentManufacturer         = kAudioUnitManufacturer_Apple;
    audioCompDesc.componentFlags                = 0;
    audioCompDesc.componentFlagsMask            = 0;
    
    // get rio unit from audio component manager
    AudioComponent rioComponent = AudioComponentFindNext(NULL, &audioCompDesc);
    CheckError(AudioComponentInstanceNew(rioComponent,
                                         &_rioUnit),
               "Couldn't get RIO unit instance");
    
    //    // reset since openTOk
//        CheckError(AudioUnitReset(self.rioUnit,
//                                  kAudioUnitScope_Global,
//                                  kOutputBusU),
//                   "Could not reset Output bus of rioUnit");
//        CheckError(AudioUnitReset(self.rioUnit,
//                                  kAudioUnitScope_Global,
//                                  kInputBusU),
//                   "Could not reset Input bus of rioUnit");
    
    UInt32 oneFlag = 1;
    // enable rio input
    CheckError(AudioUnitSetProperty(self.rioUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input,
                                    kInputBusU,
                                    &oneFlag,
                                    sizeof(oneFlag)),
               "Couldn't enable RIO input");
    
    // set up the rio unit for playback
    CheckError(AudioUnitSetProperty (self.rioUnit,
                                     kAudioOutputUnitProperty_EnableIO,
                                     kAudioUnitScope_Output,
                                     kOutputBusU,
                                     &oneFlag,
                                     sizeof(oneFlag)),
               "Couldn't enable RIO output");
    
    // setup an _pcmASBD in the iphone canonical format
    size_t bytesPerSample                       = sizeof(SInt16);
    _pcmASBD.mSampleRate                        = self.sampleRate;
    _pcmASBD.mFormatID                          = kAudioFormatMPEG4AAC;
    _pcmASBD.mFormatFlags                       = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    _pcmASBD.mBytesPerPacket                    = (unsigned int)(bytesPerSample) * kNumChannels;
    _pcmASBD.mBytesPerFrame                     = (unsigned int)(bytesPerSample) * kNumChannels;
    _pcmASBD.mChannelsPerFrame                  = kNumChannels;
    _pcmASBD.mFramesPerPacket                   = 1;
    _pcmASBD.mBitsPerChannel                    = (unsigned int)(8 * bytesPerSample);
    
    // set asbd for mic input
    CheckError(AudioUnitSetProperty(self.rioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     kInputBusU,
                                     &_pcmASBD,
                                     sizeof (_pcmASBD)),
               "Couldn't set ASBD for RIO on output scope / bus 1");
    
    // set format for output (bus 0) on rio's input scope
    CheckError(AudioUnitSetProperty(self.rioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input,
                                     kOutputBusU,
                                     &_pcmASBD,
                                     sizeof(_pcmASBD)),
               "Couldn't set ASBD for RIO on input scope / bus 0");
    
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc                    = RecordingCallback; // callback function
    callbackStruct.inputProcRefCon              = (__bridge void *)(self);
    
    CheckError(AudioUnitSetProperty(self.rioUnit,
                                    kAudioOutputUnitProperty_SetInputCallback,
                                    kAudioUnitScope_Global,
                                    kInputBusU,
                                    &callbackStruct,
                                    sizeof (callbackStruct)),
               "Couldn't set RIO input callback on bus 1");
    
    UInt32 flag = 0;
    CheckError(AudioUnitSetProperty(self.rioUnit,
                                    kAudioUnitProperty_ShouldAllocateBuffer,
                                    kAudioUnitScope_Output,
                                    kInputBusU,
                                    &flag,
                                    sizeof(flag)),
               "Couldn't set shouldAlloceBuffer to no");
    
    AudioStreamBasicDescription audioFormat     = self.pcmASBD;
    CheckError(CMAudioFormatDescriptionCreate(kCFAllocatorDefault,
                                              &audioFormat,
                                              0,
                                              NULL,
                                              0,
                                              NULL,
                                              NULL,
                                              &_cmformat),
               "Could not create format from AudioStreamBasicDescription");

    
    CFURLRef cfurl = (__bridge CFURLRef)self.outputURL;
    CheckError(ExtAudioFileCreateWithURL(cfurl,
                                         kAudioFileM4AType,
                                         &_pcmASBD,
                                         NULL,
                                         kAudioFileFlags_EraseFile,
                                         &_recordedFileRef),
               "Could not create audio file ext");
    
    
//    UInt32 codec = kAppleHardwareAudioCodecManufacturer;
//    UInt32 size = sizeof(codec);
//    CheckError(ExtAudioFileSetProperty(_recordedFileRef,
//                                     kExtAudioFileProperty_CodecManufacturer,
//                                     size,
//                                     &codec), "ExtAudioFileProperty CodecManufacturer Failed");
//    
//
//    
//    CheckError(ExtAudioFileSetProperty(_recordedFileRef,
//                                       kExtAudioFileProperty_ClientDataFormat,
//                                       sizeof(_cmformat),
//                                       &_cmformat), "Could not set client data format");
    

//    CFURLRef myFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
//                                                       CFSTR("output.caf"),
//                                                       kCFURLPOSIXPathStyle,
//                                                       false);
//    CheckError(AudioFileCreateWithURL(cfurl,
//                                      kAudioFileCAFType,
//                                      &_pcmASBD,
//                                      kAudioFileFlags_EraseFile,
//                                      &_recordedFileId), "AudioFileCreateURL failed");
    CFRelease(cfurl);
}

- (void)myInterruptionListener:(NSNotification *)notification {
    AVAudioSessionInterruptionType inInterruptionState = [[[notification userInfo]
                                                           objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    printf("Interrupted! inInterruptionState=%u\n" , (unsigned int)inInterruptionState);
    switch (inInterruptionState) {
        case kAudioSessionBeginInterruption:
            //            [self stopRecordering];
            break;
        case kAudioSessionEndInterruption:
            //            [self startRecordering];
            break;
        default:
            break;
    }
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        self.outputURL = [NSURL fileURLWithPath:path];
//        self.outputURL = path;
        [self configure];
    }
    return self;
}

- (void)dealloc {
    CheckError(AudioUnitUninitialize(self.rioUnit), "Couldn't uninitialize RIO unit");
    CheckError(AudioComponentInstanceDispose(self.rioUnit), "Couldn't dispose of component RIO unit");
    CheckError(ExtAudioFileDispose(self.recordedFileRef), "Couldn't dispose of audio file ext");
    
    free(_audioBuffer.mData);
    CFRelease(_cmformat);
}

- (void)startRecordering {
    NSError *e                                  = nil;
    AVAudioSession *session                     = [AVAudioSession sharedInstance];
    BOOL success                                = [session setActive:YES error:&e];
    if (!success) {
        NSLog(@"Couldn't set audio active : YES");
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(myInterruptionListener:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:session];

    CheckError(AudioOutputUnitStart(self.rioUnit), "Couldn't start audio unit");
}

- (void)stopRecordering {
    CheckError(AudioOutputUnitStop(self.rioUnit), "Couldn't stop audio unit");
    
    AVAudioSession *session                     = [AVAudioSession sharedInstance];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:session];
    
    NSError *e                                  = nil;
    BOOL success                                = [session setActive:NO error:&e];
    if (!success) {
        NSLog(@"Couldn't set audio active : NO");
    }
}

@end


