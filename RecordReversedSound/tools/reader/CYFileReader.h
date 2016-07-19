//
//  CYFilerReader.h
//  RecordReversedSound
//
//  Created by Scott Jones on 1/1/16.
//  Copyright © 2016 Barf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface CYFileReader : NSObject

- (instancetype)initWithFileUrl:(NSURL *)url;

- (void)readFrames:(UInt32)frames
   audioBufferList:(AudioBufferList *)audioBufferList
        bufferSize:(UInt32*)bufferSize;

//- (void)seekToFrame:(SInt32)frame;

@end
