//
//  CYOutput.m
//  RecordReversedSound
//
//  Created by Scott Jones on 1/1/16.
//  Copyright © 2016 Barf. All rights reserved.
//


#import "CYOutput.h"
#import "CYUtilities.h"
#import <AVFoundation/AVFoundation.h>

static OSStatus OutputRenderCallback (void *inRefCon,
                                      AudioUnitRenderActionFlags	* ioActionFlags,
                                      const AudioTimeStamp * inTimeStamp,
                                      UInt32 inOutputBusNumber,
                                      UInt32 inNumberFrames,
                                      AudioBufferList * ioData) {
    CYOutput *output = (__bridge CYOutput*)inRefCon;
    
    if (output.outputDataSource) {
        @autoreleasepool {
            UInt32 bufferSize;
            [output.outputDataSource readFrames:inNumberFrames audioBufferList:ioData bufferSize:&bufferSize];
        }
    }
    
    return noErr;
}

@interface CYOutput()
@property (nonatomic) AudioUnit audioUnit;
@end

@implementation CYOutput

- (id)init {
    if (self = [super init]) {
        [self createAudioUnit];
    }
    return self;
}

- (void)createAudioUnit {
    // create component desc
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    // use description to find the component we are looking for
    AudioComponent defaultOutput = AudioComponentFindNext(NULL, &desc);
    
    // create an instance of the component and have our audio property point to it
    CheckError(AudioComponentInstanceNew(defaultOutput, &_audioUnit), "AudioComponentInstanceNew Failed");
 
    // describe the output audio format..
    AudioStreamBasicDescription outputFormat;
    UInt32 floatByteSize = sizeof(float);
    outputFormat.mChannelsPerFrame = 2;
    outputFormat.mBitsPerChannel = 8 * floatByteSize;
    outputFormat.mBytesPerFrame = floatByteSize;
    outputFormat.mFramesPerPacket = 1;
    outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket;
    outputFormat.mFormatFlags = kAudioFormatFlagIsFloat|kAudioFormatFlagIsNonInterleaved;
    outputFormat.mFormatID = kAudioFormatLinearPCM;
    outputFormat.mSampleRate = 44100;
    
    // set the audio format on the input scope (kAudioUnitScope) of the output bus (0) of the output unit
    CheckError(AudioUnitSetProperty(_audioUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    0,
                                    &outputFormat,
                                    sizeof(outputFormat)), "AudioUnitSetProperty StreamFormat Failed");
   
    
    // set up the render callback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = OutputRenderCallback;
    callbackStruct.inputProcRefCon = (__bridge void*)self;
    
    // add the callback struc to the output unit (thats to the input scope of the output bus)
    CheckError(AudioUnitSetProperty(_audioUnit,
                                    kAudioUnitProperty_SetRenderCallback,
                                    kAudioUnitScope_Input,
                                    0, &callbackStruct,
                                    sizeof(callbackStruct)), "AudioUnitSetProperty SetRenderCallback Failed");
    // initialize the unit
    CheckError(AudioUnitInitialize(_audioUnit), "AudioUnitInitialize Failed");
    

}

- (void)startOutputUnit {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *setCategoryError = nil;
    if (![session setCategory:AVAudioSessionCategoryPlayback
                  withOptions:kAudioSessionCategory_MediaPlayback
                        error:&setCategoryError]) {
        // handle error
    }
    CheckError(AudioOutputUnitStart(_audioUnit), "AudioOutputUnitStart Failed");
}

- (void)stopOutputUnit {
    CheckError(AudioOutputUnitStop(_audioUnit), "AudioOutputUnitStop Failed");
}

@end


































