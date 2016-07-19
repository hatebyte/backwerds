//
//  CMAudioRecorder.h
//  Capture-Live-Camera
//
//  Created by hatebyte on 4/17/15.
//  Copyright (c) 2015 CaptureMedia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVAudioSession.h>
#import <CoreMedia/CoreMedia.h>




@protocol CYAudioRecoredSampleBufferDelegate <NSObject>

- (void)didRenderAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

//@protocol CYAudioRecorderAACAudioDelegate <NSObject>
//
//- (void)didConvertAACData:(NSData *)data time:(double)time;
//
//@end


@interface CYAudioRecorder : NSObject

@property(nonatomic, weak) id <CYAudioRecoredSampleBufferDelegate> sampleBufferDelegate;
//@property(nonatomic, weak) id <CMAudioRecorderAACAudioDelegate> aacDelegate;

- (instancetype)initWithPath:(NSString *)path;

//+ (int)Channel;
//+ (int)Profile;
//+ (int)FrequencyIndex;
+ (void)shouldTryToAccessMicrophone:(void (^)(BOOL granted))handler;

- (void)startRecordering;
- (void)stopRecordering;

@end
