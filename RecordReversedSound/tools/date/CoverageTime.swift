//
//  CoverageTime.swift
//  RecordReversedSound
//
//  Created by Scott Jones on 1/1/16.
//  Copyright © 2016 Barf. All rights reserved.
//

typealias CoverageTime = (hours:String, minutes:String, seconds:String, milliseconds:String)

class TimeParser: NSObject {
    
    var startFileTime                               = CMTime()
    var seconds:Int                                 = 0
    var clockFormatter                              = CoverTimeFormatter(adjustment:3)
    
    func time(sampleBuffer:CMSampleBuffer)->Box<CoverageTime> {
        if self.startFileTime.isValid == false {
            self.startFileTime                      = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        }
        
        let currentTime                             = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let recordedTime                            = CMTimeSubtract(currentTime, self.startFileTime);
        self.clockFormatter.time                    = CMTimeGetSeconds(recordedTime)
        return self.clockFormatter.coverageTime()
    }
    
}
