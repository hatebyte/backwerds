//
//  HDFileEncoder.swift
//  Capture-Live
//
//  Created by hatebyte on 4/8/15.
//  Copyright (c) 2015 CaptureMedia. All rights reserved.
//

import UIKit
import AVFoundation

typealias CloseFile = (String)->()
typealias UpdateAssetWriter = ()->()

protocol CYAudioFileWriterErrorDelegate {
    func hdFileEncoderError(error:NSError)
//    func didStartNewFile()
}

enum CYAudioFileWriterErrorCode : Int {
    case CantApplyOutputSettings
    case CantAddInput                   
    case AVAssetWriterStatusFailed
    case CantWriteFile
}

class CYAudioFileWriter: NSObject {
    
    static let Domain                                                       = "com.capturemedia.ios.cmhdfilencoder"
    
    var updateAssetWriter:UpdateAssetWriter?
    private var mainAssetWriter:AVAssetWriter!
    var defaultFileName:String!
    var defaultDirectory:String!
    let highResEncoderQueue                                                 = dispatch_queue_create("HighResEncoderQueue", DISPATCH_QUEUE_CONCURRENT);
    var errorDelegate:CYAudioFileWriterErrorDelegate?

    init(fileName:String, directory:String) {
        self.defaultFileName                                                = fileName
        self.defaultDirectory                                               = directory
        
        super.init()
        
        self.updateAssetWriter = {
            self.mainAssetWriter                                            = try! AVAssetWriter(URL:self.fileURL, fileType:AVFileTypeMPEG4)
            self.mainAssetWriter.addInput(self.audioInputWriter)
        }
    }
    
    func shutDown() {
        self.mainAssetWriter                                                = nil
    }
    
    var fileURL:NSURL {
        get {
            let docPath                                                     = CYFileManager.defaultManager().createAudioFilePathInDirectory(self.defaultDirectory, fileName: self.defaultFileName)
            return NSURL.fileURLWithPath(docPath)
        }
    }
    
    lazy private var audioInputWriter: AVAssetWriterInput = {
        var temporaryAWriter = self.createAudioInputWriter()!
        return temporaryAWriter
    }()

    func finishWritingWithComplete(complete:()->()) {
        if let _ = self.mainAssetWriter {
            if self.mainAssetWriter.status == .Writing  {
                self.audioInputWriter.markAsFinished()
                self.mainAssetWriter.finishWritingWithCompletionHandler({ () -> Void in
                    complete()
                })
            }
        }
    }
    
    func cutRecording(complete:CloseFile) {
        weak var weakSelf:CYAudioFileWriter? = self
        dispatch_barrier_async(self.highResEncoderQueue, {
            let path                            = self.mainAssetWriter.outputURL.path!;
            weakSelf?.finishWritingWithComplete { () -> () in
//                self.updateAssetWriter?()
                dispatch_async(dispatch_get_main_queue(), {
                    complete(path)
                })
            }
        })
    }
    
    func finishRecording(complete:CloseFile) {
        self.updateAssetWriter = nil
        weak var weakSelf:CYAudioFileWriter?                                = self
        let path                                                            = self.mainAssetWriter.outputURL.path!;
        dispatch_barrier_async(self.highResEncoderQueue, {
            weakSelf?.finishWritingWithComplete { () -> () in
                dispatch_async(dispatch_get_main_queue(), {
                    complete(path)
                })
            }
        })
    }
    
    func encodeSampleBuffer(sampleBuffer:CMSampleBuffer, isVideo:Bool) {
        dispatch_barrier_async(self.highResEncoderQueue, {
            if self.mainAssetWriter == nil {
                self.updateAssetWriter?()
            }
        })

        dispatch_sync(self.highResEncoderQueue, {
            let testBool:Bool                                               = CMSampleBufferDataIsReady(sampleBuffer) != false
            if testBool == true {
                let currentTime                                             = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
                if let aw = self.mainAssetWriter {
                    if aw.status == AVAssetWriterStatus.Unknown {
                        aw.startWriting()
                        aw.startSessionAtSourceTime(currentTime)
                    }
                    if aw.status == AVAssetWriterStatus.Failed {
                        print("AVAssetWriterStatus.Failed \(aw.status.rawValue) \(aw.error!.localizedDescription)");
                        // call high res error
                        // should inform the user some how
                        let error                                           = NSError(domain:CYAudioFileWriter.Domain, code:CYAudioFileWriterErrorCode.AVAssetWriterStatusFailed.rawValue, userInfo:nil)
                        self.errorDelegate?.hdFileEncoderError(error)
                    } else {
                        if self.audioInputWriter.readyForMoreMediaData == true {
                            let worked = self.audioInputWriter.appendSampleBuffer(sampleBuffer);
                            if worked == false {
                                print("_mainAssetWriter.status \(aw.status.rawValue)");
                            }
                        }
                    }
                }
                
            }
        })
    }
    
    func createAudioInputWriter()->AVAssetWriterInput? {
        let settings:[String : AnyObject]         = [
            AVFormatIDKey                           : NSNumber(unsignedInt: kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey                   : 2,
            AVSampleRateKey                         : 44100,
            AVEncoderBitRateKey                     : 64000
        ]
        
        var assetWriter:AVAssetWriterInput!
        if self.mainAssetWriter.canApplyOutputSettings(settings, forMediaType:AVMediaTypeAudio) {
            assetWriter                             = AVAssetWriterInput(mediaType:AVMediaTypeAudio, outputSettings:settings)
            assetWriter.expectsMediaDataInRealTime  = true
            if self.mainAssetWriter.canAddInput(assetWriter) {
                self.mainAssetWriter.addInput(assetWriter)
            } else {
                let error = NSError(domain:CYAudioFileWriter.Domain, code:CYAudioFileWriterErrorCode.CantAddInput.rawValue, userInfo:nil)
                self.errorDelegate?.hdFileEncoderError(error)
            }
        } else {
            let error = NSError(domain:CYAudioFileWriter.Domain, code:CYAudioFileWriterErrorCode.CantApplyOutputSettings.rawValue, userInfo:nil)
            self.errorDelegate?.hdFileEncoderError(error)
        }
        return assetWriter
    }
    
}

