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
    let highResEncoderQueue                                                 = DispatchQueue(label: "HighResEncoderQueue", attributes: .concurrent)
    var errorDelegate:CYAudioFileWriterErrorDelegate?

    init(fileName:String, directory:String) {
        self.defaultFileName                                                = fileName
        self.defaultDirectory                                               = directory
        
        super.init()
        
        self.updateAssetWriter = {
            self.mainAssetWriter                                            = try! AVAssetWriter(outputURL:self.fileURL as URL, fileType:AVFileType.mp4)
            self.mainAssetWriter.add(self.audioInputWriter)
        }
    }
    
    func shutDown() {
        self.mainAssetWriter                                                = nil
    }
    
    var fileURL:NSURL {
        get {
            let docPath                                                     = CYFileManager.default().createAudioFilePath(inDirectory: self.defaultDirectory, fileName: self.defaultFileName)
            return NSURL.fileURL(withPath: docPath!) as NSURL
        }
    }
    
    lazy private var audioInputWriter: AVAssetWriterInput = {
        var temporaryAWriter = self.createAudioInputWriter()!
        return temporaryAWriter
    }()

    func finishWritingWithComplete(complete:@escaping ()->()) {
        if let _ = self.mainAssetWriter {
            if self.mainAssetWriter.status == .writing  {
                self.audioInputWriter.markAsFinished()
                self.mainAssetWriter.finishWriting(completionHandler: { () -> Void in
                    complete()
                })
            }
        }
    }
    
    func cutRecording(complete:@escaping CloseFile) {
        weak var weakSelf:CYAudioFileWriter? = self
        self.highResEncoderQueue.async(flags: .barrier) {
            let path                            = self.mainAssetWriter.outputURL.path;
            weakSelf?.finishWritingWithComplete { () -> () in
//                self.updateAssetWriter?()
                
                DispatchQueue.main.async {
                    complete(path)
                }
            }
        }
    }
    
    func finishRecording(complete:@escaping CloseFile) {
        self.updateAssetWriter = nil
        weak var weakSelf:CYAudioFileWriter?                                = self
        let path                                                            = self.mainAssetWriter.outputURL.path;
        
        self.highResEncoderQueue.async(flags: .barrier) {
            weakSelf?.finishWritingWithComplete { () -> () in
                DispatchQueue.main.async {
                    complete(path)
                }
            }
        }
    }
    
    func encodeSampleBuffer(sampleBuffer:CMSampleBuffer, isVideo:Bool) {
        self.highResEncoderQueue.async(flags: .barrier) {
            if self.mainAssetWriter == nil {
                self.updateAssetWriter?()
            }
        }

        self.highResEncoderQueue.sync {
            let testBool:Bool                                               = CMSampleBufferDataIsReady(sampleBuffer) != false
            if testBool == true {
                let currentTime                                             = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
                if let aw = self.mainAssetWriter {
                    if aw.status == AVAssetWriterStatus.unknown {
                        aw.startWriting()
                        aw.startSession(atSourceTime: currentTime)
                    }
                    if aw.status == AVAssetWriterStatus.failed {
                        print("AVAssetWriterStatus.Failed \(aw.status.rawValue) \(aw.error!.localizedDescription)");
                        // call high res error
                        // should inform the user some how
                        let error                                           = NSError(domain:CYAudioFileWriter.Domain, code:CYAudioFileWriterErrorCode.AVAssetWriterStatusFailed.rawValue, userInfo:nil)
                        self.errorDelegate?.hdFileEncoderError(error: error)
                    } else {
                        if self.audioInputWriter.isReadyForMoreMediaData == true {
                            let worked = self.audioInputWriter.append(sampleBuffer);
                            if worked == false {
                                print("_mainAssetWriter.status \(aw.status.rawValue)");
                            }
                        }
                    }
                }
                
            }
        }
    }
    
    func createAudioInputWriter()->AVAssetWriterInput? {
        let settings:[String : Any]         = [
            AVFormatIDKey                           : NSNumber(value: kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey                   : 2,
            AVSampleRateKey                         : 44100,
            AVEncoderBitRateKey                     : 64000
        ]
        
        var assetWriter:AVAssetWriterInput!
        if self.mainAssetWriter.canApply(outputSettings: settings, forMediaType:AVMediaType.audio) {
            assetWriter                             = AVAssetWriterInput(mediaType:AVMediaType.audio, outputSettings:settings)
            assetWriter.expectsMediaDataInRealTime  = true
            if self.mainAssetWriter.canAdd(assetWriter) {
                self.mainAssetWriter.add(assetWriter)
            } else {
                let error = NSError(domain:CYAudioFileWriter.Domain, code:CYAudioFileWriterErrorCode.CantAddInput.rawValue, userInfo:nil)
                self.errorDelegate?.hdFileEncoderError(error: error)
            }
        } else {
            let error = NSError(domain:CYAudioFileWriter.Domain, code:CYAudioFileWriterErrorCode.CantApplyOutputSettings.rawValue, userInfo:nil)
            self.errorDelegate?.hdFileEncoderError(error: error)
        }
        return assetWriter
    }
    
}

