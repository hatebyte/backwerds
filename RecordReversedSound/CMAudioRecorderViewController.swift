//
//  CMAudioRecorderViewController.swift
//  RecordReversedSound
//
//  Created by Scott Jones on 12/30/15.
//  Copyright © 2015 Barf. All rights reserved.
//

import UIKit
import AVFoundation
import AssetsLibrary

class CMAudioRecorderViewController: UIViewController, CYOutputDataSource, CMAudioRecoredSampleBufferDelegate, CYAudioFileWriterErrorDelegate {
    
    var fileWriter:CYAudioFileWriter?
    var audioRecorder:CMAudioRecorder?
    
    var fileReader : CYFileReader!
    var output : CYOutput!

    
    var fileLocalDirectory:String?
    var filePath:String?
    var player:AVAudioPlayer!
    var dirPath:String = "recording"
    var backgroundTask:UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    var startTime = CMTime()
    var sampleBuffers = [CMSampleBufferRef]()
    
    var masterPath:String?
    var challengePath:String?
    
    var theView:CMAudioRecorderView {
        return self.view as! CMAudioRecorderView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        output = CYOutput()
        output.outputDataSource = self
        
        self.automaticallyAdjustsScrollViewInsets           = false
        self.theView.didLoad()
   
        self.fileLocalDirectory                             = CYFileManager.defaultManager().documentDirectoryPathForName(self.dirPath)
        _                                                   = NSURL.fileURLWithPath(self.fileLocalDirectory!, isDirectory: true).URLByDeletingLastPathComponent
        CYFileManager.defaultManager().clearFilesFromDirectory(self.fileLocalDirectory)
        
        CMAudioRecorder.shouldTryToAccessMicrophone { (granted:Bool) -> Void in
            if granted == true {
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let nc                                              = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(willEnterBackground), name: UIApplicationWillResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(willEnterForeground), name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        let nc                                              = NSNotificationCenter.defaultCenter()
        nc.removeObserver(self, name: UIApplicationWillResignActiveNotification, object:nil)
        nc.removeObserver(self, name: UIApplicationDidBecomeActiveNotification, object:nil)
        
        self.removeButtonHandlers()
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.layoutIfNeeded();
        self.addButtonHandlers()
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.Portrait
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return false
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    private func addButtonHandlers() {
        self.theView.recordMasterButton!.addTarget(self,    action: #selector(recordMaster),   forControlEvents: UIControlEvents.TouchUpInside)
        self.theView.playMasterButton!.addTarget(self,      action: #selector(playMaster),    forControlEvents: UIControlEvents.TouchUpInside)
        self.theView.recordChallengeButton!.addTarget(self,       action: #selector(recordChallenge), forControlEvents: UIControlEvents.TouchUpInside)
        self.theView.playChallengeButton!.addTarget(self,         action: #selector(playChallenge),  forControlEvents: UIControlEvents.TouchUpInside)
    }
    
    private func removeButtonHandlers() {
        self.theView.recordMasterButton!.removeTarget(self,     action: #selector(recordMaster),   forControlEvents: UIControlEvents.TouchUpInside)
        self.theView.playMasterButton!.removeTarget(self,       action: #selector(playMaster),    forControlEvents: UIControlEvents.TouchUpInside)
        self.theView.recordChallengeButton!.removeTarget(self,  action: #selector(recordChallenge), forControlEvents: UIControlEvents.TouchUpInside)
        self.theView.playChallengeButton!.removeTarget(self,    action: #selector(playChallenge),  forControlEvents: UIControlEvents.TouchUpInside)
    }
    
    // MARK: buttonhandler
    func recordMaster() {
        self.theView.recordMasterButton!.removeTarget(self,     action: #selector(recordMaster),   forControlEvents: UIControlEvents.TouchUpInside)
        self.theView.recordMasterButton!.addTarget(self,     action: #selector(stopRecordingMaster),   forControlEvents: UIControlEvents.TouchUpInside)
        self.theView.showForMasterRecording()
        self.startRecording()
    }
    
    func stopRecordingMaster() {
        self.theView.recordMasterButton!.removeTarget(self,     action: #selector(stopRecordingMaster),   forControlEvents: UIControlEvents.TouchUpInside)
        self.stopRecording { [unowned self] (path:String) in
            self.masterPath = path;
            self.theView.showDefault()
            self.theView.recordMasterButton!.addTarget(self,     action: #selector(self.recordMaster),   forControlEvents: UIControlEvents.TouchUpInside)
        }
    }
  
    func playMaster() {
        if let masterP = self.masterPath {
            self.theView.playMasterButton!.removeTarget(self,     action: #selector(playMaster),   forControlEvents: UIControlEvents.TouchUpInside)
            self.theView.playMasterButton!.addTarget(self,     action: #selector(stopPlayingMaster),   forControlEvents: UIControlEvents.TouchUpInside)
            self.theView.showForMasterPlaying()
            self.fileReader = CYFileReader(fileUrl: NSURL(fileURLWithPath:masterP))
            self.startPlayingFile()
        }
    }
   
    func stopPlayingMaster() {
        self.stopPlayingFile()
        self.theView.showDefault()
        self.theView.playMasterButton!.removeTarget(self,     action: #selector(stopPlayingMaster),   forControlEvents: UIControlEvents.TouchUpInside)
        self.theView.playMasterButton!.addTarget(self,     action: #selector(playMaster),   forControlEvents: UIControlEvents.TouchUpInside)
    }
   
    func recordChallenge() {
        self.theView.recordChallengeButton!.removeTarget(self,  action: #selector(recordChallenge), forControlEvents: UIControlEvents.TouchUpInside)
        self.theView.recordChallengeButton!.addTarget(self,     action: #selector(stopRecordingChallenge),   forControlEvents: UIControlEvents.TouchUpInside)
        self.theView.showForChallengeRecording()
        self.startRecording()
    }
    
    func stopRecordingChallenge() {
        self.theView.recordChallengeButton!.removeTarget(self,     action: #selector(stopRecordingChallenge),   forControlEvents: UIControlEvents.TouchUpInside)
        self.stopRecording { [unowned self] (path:String) in
            self.challengePath = path;
            self.theView.showDefault()
            self.theView.recordChallengeButton!.addTarget(self,     action: #selector(self.recordChallenge),   forControlEvents: UIControlEvents.TouchUpInside)
        }
    }

    func playChallenge() {
        if let challengeP = self.challengePath {
            self.theView.playChallengeButton!.removeTarget(self,     action: #selector(playChallenge),   forControlEvents: UIControlEvents.TouchUpInside)
            self.theView.playChallengeButton!.addTarget(self,     action: #selector(stopPlayingChallenge),   forControlEvents: UIControlEvents.TouchUpInside)
            self.theView.showForChallengePlaying()
            self.fileReader = CYFileReader(fileUrl: NSURL(fileURLWithPath:challengeP))
            self.startPlayingFile()
        }
    }
    
    func stopPlayingChallenge() {
        self.stopPlayingFile()
        self.theView.showDefault()
        self.theView.playChallengeButton!.removeTarget(self,     action: #selector(playChallenge),   forControlEvents: UIControlEvents.TouchUpInside)
        self.theView.playChallengeButton!.addTarget(self,     action: #selector(playChallenge),   forControlEvents: UIControlEvents.TouchUpInside)
    } 

    func startRecording() {
        self.fileReader = nil
        self.stopPlayingFile()
        self.fileWriter = nil
        CMAudioRecorder.shouldTryToAccessMicrophone { [unowned self] (granted:Bool) -> Void in
            if granted {
                self.fileWriter                             = nil
                self.fileWriter                             = CYAudioFileWriter(fileName:self.dirPath, directory:self.fileLocalDirectory!)
                self.fileWriter?.errorDelegate              = self
                self.audioRecorder                          = CMAudioRecorder()
                self.audioRecorder?.sampleBufferDelegate    = self
                self.audioRecorder?.startRecordering()
            }
        }
    }
    
    func stopRecording(complete:CloseFile) {
        self.audioRecorder?.stopRecordering()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) { [weak self] in
            while let sb = self?.sampleBuffers.popLast() {
                self?.fileWriter?.encodeSampleBuffer(sb, isVideo: false);
            }

            self?.fileWriter?.cutRecording({ (path:String) in
                dispatch_async(dispatch_get_main_queue()) {
                    complete(path)
                }
            })
        }
    }
    
    func startPlayingFile() {
        output.startOutputUnit()
    }
    
    func stopPlayingFile() {
        output.stopOutputUnit()
    }
    
    // MARK: CYOutputDataSource
    func readFrames(frames: UInt32, audioBufferList: UnsafeMutablePointer<AudioBufferList>, bufferSize: UnsafeMutablePointer<UInt32>) {
        if let reader = self.fileReader {
            reader.readFrames(frames, audioBufferList: audioBufferList, bufferSize: bufferSize)
        }
    }
    
    //MARK: CMSampleBufferDelegate
    func didRenderAudioSampleBuffer(sampleBuffer: CMSampleBuffer!) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            self.sampleBuffers.append(sampleBuffer)
        }
    }
   
    //MARK: CYFileWriterErrorDelegate 
    func hdFileEncoderError(error:NSError) {
        print(error.localizedDescription)
    }
    
//    // MARK: InteruptionHandlers
    func willEnterBackground() {
        backgroundTask                                      = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
            
        });
    }
    
    func willEnterForeground() {
        if self.backgroundTask != UIBackgroundTaskInvalid {
            UIApplication.sharedApplication().endBackgroundTask(self.backgroundTask)
            self.backgroundTask                             = UIBackgroundTaskInvalid;
        }
    }
    
}




































