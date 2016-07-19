//
//  CYFileReader.m
//  RecordReversedSound
//
//  Created by Scott Jones on 1/1/16.
//  Copyright © 2016 Barf. All rights reserved.
//

#import "CYFileReader.h"
#import "CYUtilities.h"


@interface CYFileReader () {
    float **_floatBuffers;
    AudioBufferList *_fileReadingBufferList;
    uint64_t timeOfLastSeek;
}

@property(nonatomic, assign) SInt64 totalFramesInFile;
@property(nonatomic, assign) AudioStreamBasicDescription fileFormat;
@property(nonatomic, assign) AudioStreamBasicDescription clientFormat;
@property (assign, nonatomic) SInt64 startOfFile;
@property (assign, nonatomic) SInt64 endOfFile;


@property(nonatomic, assign) BOOL isReading;
@property(nonatomic, assign) ExtAudioFileRef audioFile;
@property (assign, nonatomic) SInt64 frameIndex;

@end

@implementation CYFileReader

- (instancetype)initWithFileUrl:(NSURL *)url {
    if (self = [super init]) {
        _isReading  = NO;
        
        [self openFileAtUrl:url];
    }
    return self;
}


- (void)readFrames:(UInt32)frames
   audioBufferList:(AudioBufferList *)audioBufferList
        bufferSize:(UInt32*)bufferSize {

    if (self.audioFile) {
        self.isReading = YES;
        
        // get our current location in file
        SInt64 currentFrame;
        CheckError(ExtAudioFileTell(_audioFile, &currentFrame), "ExtAudioFileTell Failed");
        
        // Check our current location against end of file
        [self checkCurrentFrameAgainstLoopMarkers:currentFrame];
        
        // File reading
        CheckError(ExtAudioFileSeek(_audioFile, _frameIndex), "ExtAudioFileSeek Failed");
        CheckError(ExtAudioFileRead(_audioFile, &frames, audioBufferList), "Failed to read audio data from audio file");
        
        _frameIndex += frames;
        
        self.isReading = NO;
        
        // infrom delegates of current frame
        
    }
    
}


- (void)openFileAtUrl:(NSURL*)url {
    self.audioFile = NULL;
    CFURLRef cfurl = (__bridge CFURLRef)url;
    CheckError(ExtAudioFileOpenURL(cfurl, &_audioFile), "ExtAudioFileOpenURL Failed");
    
    // get the total number of frames
    [self getTotalNumberFramesInFile];
    
    // get the files format
    [self getFileDataFormat];
    
    // set the client and waveform formats
    [self setClientFormatForAudioFile];
    
    // set the loop markers for out file start and end points
    [self setFileRegionMarkers];
    
    // create the audiobuffers for the file reading
    [self createFileReadingBufferList];
    
    // reset the frame index
    self.frameIndex = 0;

}

#pragma File Setup
- (void)getTotalNumberFramesInFile {
    SInt64 totalFrames;
    UInt32 dataSize = sizeof(totalFrames);
    CheckError(ExtAudioFileGetProperty(_audioFile,
                                       kExtAudioFileProperty_FileLengthFrames,
                                       &dataSize,
                                       &totalFrames), "ExtAudioFileProperty FileLengthFrames Failed");
    _totalFramesInFile = totalFrames;
}

- (void)getFileDataFormat {
    UInt32 dataSize = sizeof(_fileFormat);
    CheckError(ExtAudioFileGetProperty(_audioFile,
                                       kExtAudioFileProperty_FileDataFormat,
                                       &dataSize,
                                       &_fileFormat), "ExtAudioFileProperty FileDataFormat Failed");
}

- (void)setClientFormatForAudioFile {
    UInt32 floatByteSize = sizeof(float);
    
    _clientFormat.mChannelsPerFrame = 2;
    _clientFormat.mBitsPerChannel = 8 * floatByteSize;
    _clientFormat.mBytesPerFrame = floatByteSize;
    _clientFormat.mFramesPerPacket = 1;
    _clientFormat.mBytesPerPacket = _clientFormat.mBytesPerFrame * _clientFormat.mFramesPerPacket;
    _clientFormat.mFormatFlags = kAudioFormatFlagIsFloat|kAudioFormatFlagIsNonInterleaved;
    _clientFormat.mFormatID = kAudioFormatLinearPCM;
    _clientFormat.mSampleRate = 44100;

    CheckError(ExtAudioFileSetProperty(_audioFile,
                                       kExtAudioFileProperty_ClientDataFormat,
                                       sizeof(_clientFormat),
                                       &_clientFormat), "ExtAudioFileProperty ClientDataFormat Failed");
}

- (void)setFileRegionMarkers {
    self.startOfFile = 0;
    self.endOfFile = self.totalFramesInFile;
}

- (void)createFileReadingBufferList {
    _fileReadingBufferList = (AudioBufferList*)malloc(sizeof(AudioBufferList) + (sizeof(AudioBuffer) * _clientFormat.mChannelsPerFrame));
    _fileReadingBufferList->mNumberBuffers = _clientFormat.mChannelsPerFrame;
    
    for (int i=0; i < _fileReadingBufferList->mNumberBuffers; i++) {
        _fileReadingBufferList->mBuffers[i].mNumberChannels = 1;
        UInt32 bufferSize = 1024;
        _fileReadingBufferList->mBuffers[i].mDataByteSize = bufferSize * sizeof(float);
        _fileReadingBufferList->mBuffers[i].mData = malloc(bufferSize * sizeof(float));
    }
}

- (void)checkCurrentFrameAgainstLoopMarkers:(SInt64)currentFrame {
    if (currentFrame >= self.endOfFile) {
        self.frameIndex = self.startOfFile;
    }
}

- (Float32*)reverseContentsOfBuffer:(Float32 *)audioBuffer numberOfFrames:(UInt32)frames {
    Float32* reversedBuffer = audioBuffer;
    Float32 tmp;
    
    int i = 0;
    int j = frames - 1;
    
    while (j > i) {
        tmp = reversedBuffer[j];
        reversedBuffer[j] = reversedBuffer[i];
        reversedBuffer[i] = tmp;
        j--;
        i++;
    }
    return reversedBuffer;
}

@end





































