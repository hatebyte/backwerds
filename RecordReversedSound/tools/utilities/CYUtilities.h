//
//  CYUtilities.h
//  RecordReversedSound
//
//  Created by Scott Jones on 1/1/16.
//  Copyright © 2016 Barf. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AudioToolbox;

@interface CYUtilities : NSObject

extern void CheckError(OSStatus error, const char *operation);

+ (void)printErrorMessage: (NSString *) errorString withStatus: (OSStatus) result;

+ (void) printASBD: (AudioStreamBasicDescription) asbd;

+ (NSString*)descriptionForAudioFormat:(AudioStreamBasicDescription) audioFormat;

+ (NSString*)descriptionForStandardFlags:(UInt32) mFormatFlags;

@end
