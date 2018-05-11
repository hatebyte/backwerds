//
//  CYOutput.h
//  RecordReversedSound
//
//  Created by Scott Jones on 1/1/16.
//  Copyright © 2016 Barf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class CYOutput;

@protocol CYOutputDataSource <NSObject>

- (void)readFrames:(UInt32)frames
   audioBufferList:(AudioBufferList *)audioBufferList
        bufferSize:(UInt32*)bufferSize;

@end


@interface CYOutput : NSObject

@property(strong, nonatomic) id <CYOutputDataSource> outputDataSource;

- (void)startOutputUnit;
- (void)stopOutputUnit;

@end
