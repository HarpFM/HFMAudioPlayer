//
//  HFMAudioManager.swift
//  HarpFM
//
//  Created by Brian Drelling on 10/24/16.
//  Copyright © 2016 Brian Drelling. All rights reserved.
//

import AVFoundation
import Foundation
import MediaPlayer

class AudioManager {
    // MARK: - Shared Instance
    
    private static var _shared: AudioManager!
    
    static var shared: AudioManager {
        if (self._shared == nil) {
            self._shared = AudioManager()
        }
        
        return self._shared
    }
    
    // MARK: - Enums
    
    enum SkipDirection {
        case backward
        case forward
    }
    
    // MARK: - Properties
    
    public var delegate: HFMAudioManagerDelegate?
    public var player: HFMAudioPlayer?
    
    public var isDebugEnabled = false
    public var supportedPlaybackRates: [NSNumber] = [1, 1.5, 2]
    public var preferredSkipBackwardIntervals: [NSNumber] = [-15, -30]
    public var preferredSkipForwardIntervals: [NSNumber] = [15, 30]
    public var syncInterval: TimeInterval = 15
    public var updateInterval: TimeInterval = 1
    
    public var shouldPauseWhenExternalDeviceChanges = true {
        didSet {
            if (self.shouldPauseWhenExternalDeviceChanges) {
                NotificationCenter.default.addObserver(self, selector: #selector(self.onAudioSessionRouteChanged), name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
            } else {
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
            }
        }
    }
    
    private var updateTimer: Timer?
    
    // MARK: - Methods
    
    // MARK: Initializers
    
    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print(error.localizedDescription)
        }
        
        self.addRemoteCommandHandlers()
    }
    
    // MARK: Events
    
    @objc func onAudioSessionRouteChanged(notification: Notification) {
        guard let routeChangeReasonInt = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let routeChangeReason = AVAudioSessionRouteChangeReason(rawValue: routeChangeReasonInt) else {
                return
        }
        
        if (routeChangeReason == .oldDeviceUnavailable) {
            self.pause()
        }
    }
    
    // MARK: Player Commands
    
    func pause() {
        self.player?.pause()
        
        if (self.isDebugEnabled) {
            print("Playback paused.")
        }
        
        self.stopTimers()
        
        self.requestAudioPlayerUpdate()
    }
    
    func play() {
        self.player?.play()
        
        if (self.isDebugEnabled) {
            print("Playback started.")
        }
        
        self.startTimers()
        
        self.requestAudioPlayerUpdate()
    }
    
    func seek(to time: TimeInterval) {
        self.player?.seek(to: time)
        
        if (self.isDebugEnabled) {
            print("Playback seeked to \(time).")
        }
        
        self.requestAudioPlayerUpdate()
    }
    
    func setPlaybackRate(to rate: Float) {
        self.player?.setPlaybackRate(to: rate)
        
        if (self.isDebugEnabled) {
            print("Playback rate set to \(rate).")
        }
        
        self.requestAudioPlayerUpdate()
    }
    
    func skip(by seconds: TimeInterval) {
        self.player?.skip(by: seconds)
        
        if (self.isDebugEnabled) {
            print("Playback skipped backward by \(seconds) seconds.")
        }
        
        self.requestAudioPlayerUpdate()
    }
    
    func skip(_ direction: SkipDirection) {
        switch (direction) {
        case .backward:
            self.skip(by: -15)
        case .forward:
            self.skip(by: 15)
        }
    }
    
    func stop() {
        self.player?.stop()
        
        if (self.isDebugEnabled) {
            print("Playback stopped.")
        }
        
        self.stopTimers()
        
        self.requestAudioPlayerUpdate()
        
        try? self.setActive(false)
    }
    
    @discardableResult
    func togglePlayPause() -> Bool {
        guard let player = self.player else {
            return false
        }
        
        if (player.isPlaying) {
            self.pause()
        } else {
            self.play()
        }
        
        return player.isPlaying
    }
    
    // MARK: Utilities
    
    private func addRemoteCommandHandlers() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = self.supportedPlaybackRates
        
        commandCenter.skipBackwardCommand.preferredIntervals = self.preferredSkipBackwardIntervals
        commandCenter.skipForwardCommand.preferredIntervals = self.preferredSkipForwardIntervals
        
        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
                guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                    return MPRemoteCommandHandlerStatus.commandFailed
                }
                
                self.seek(to: event.positionTime)
                return MPRemoteCommandHandlerStatus.success
            }
        }
        
        commandCenter.changePlaybackRateCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            guard let event = event as? MPChangePlaybackRateCommandEvent else {
                return MPRemoteCommandHandlerStatus.commandFailed
            }
            
            self.setPlaybackRate(to: event.playbackRate)
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.nextTrackCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            return MPRemoteCommandHandlerStatus.commandFailed
        }
        
        commandCenter.pauseCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            self.pause()
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.playCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            self.play()
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.previousTrackCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            return MPRemoteCommandHandlerStatus.commandFailed
        }
        
        commandCenter.skipBackwardCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            guard let event = event as? MPSkipIntervalCommandEvent else {
                return MPRemoteCommandHandlerStatus.commandFailed
            }
            
            self.skip(by: event.interval)
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.skipForwardCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            guard let event = event as? MPSkipIntervalCommandEvent else {
                return MPRemoteCommandHandlerStatus.commandFailed
            }
            
            self.skip(by: event.interval)
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.stopCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            self.stop()
            return MPRemoteCommandHandlerStatus.success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget() { (event) -> MPRemoteCommandHandlerStatus in
            self.togglePlayPause()
            return MPRemoteCommandHandlerStatus.success
        }
    }
    
    func clearDownloads() throws {
        guard let downloads = try self.getDownloads() else {
            return
        }
        
        for download in downloads {
            try FileManager.default.removeItem(at: download)
        }
    }
    
    private func getDownloads() throws -> [URL]? {
        guard let documentsURL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: [])
    }
    
    @discardableResult
    private func prepareToPlay(filePath: String?, time: TimeInterval? = nil, persist: Bool = false) throws -> Bool {
        guard let filePath = filePath else {
            return false
        }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        
        guard let fileURL = documentsURL?.appendingPathComponent(filePath) else {
            return false
        }
        
        return try self.prepareToPlay(fileURL: fileURL, time: time, persist: persist)
    }
    
    @discardableResult
    private func prepareToPlay(fileURL: URL?, time: TimeInterval? = nil, persist: Bool = false) throws -> Bool {
        guard let fileURL = fileURL else {
            return false
        }
        
        if (!FileManager.default.fileExists(atPath: fileURL.path)) {
            return false
        }
        
        return try self.prepareToPlay(url: fileURL, time: time, persist: persist)
    }
    
    @discardableResult
    private func prepareToPlay(url: URL?, time: TimeInterval? = nil, persist: Bool = false) throws -> Bool {
        guard let url = url else {
            return false
        }
        
        // Ignore prepare request if it's the actively playing file
        if (self.player?.url == url) {
            return false
        }
        
        if (persist) {
            self.player?.load(url: url, time: time)
        } else {
            if (self.player?.isPlaying == true) {
                self.stop()
            }
            
            self.player = HFMAudioPlayer(url: url, time: time)
        }
        
        try self.setActive(true)
        
        return self.player != nil
    }
    
    private var timeSinceLastSync: TimeInterval = 0
    
    @objc func requestAudioPlayerUpdate() {
        self.updateNowPlayingInfo()
        
        if let player = self.player {
            self.delegate?.onAudioPlayerUpdateRequested(player)
        }
        
        timeSinceLastSync += self.updateInterval
        
        if (timeSinceLastSync >= self.syncInterval) {
            self.delegate?.onSyncRequested()
            self.timeSinceLastSync = 0
        }
    }
    
    private func setActive(_ isActive: Bool) throws {
        try AVAudioSession.sharedInstance().setActive(isActive)
        self.setNowPlaying()
    }
    
    private func setNowPlaying() {
        guard let info = self.delegate?.getNowPlayingInfo() else {
            return
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        self.requestAudioPlayerUpdate()
    }
    
    func startTimers() {
        self.updateTimer?.invalidate()
        
        guard let player = self.player else {
            return
        }
        
        let updateInterval = TimeInterval(player.playbackRate) / self.updateInterval
        
        if #available(iOS 10.0, *) {
            self.updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] (timer) in
                self?.requestAudioPlayerUpdate()
            }
        } else {
            self.updateTimer = Timer.scheduledTimer(timeInterval: updateInterval, target: self, selector: #selector(self.requestAudioPlayerUpdate), userInfo: nil, repeats: true)
        }
    }
    
    func stopTimers() {
        self.updateTimer?.invalidate()
        self.updateTimer = nil
        
        if (self.isDebugEnabled) {
            print("Update timer stopped.")
        }
    }
    
    func updateNowPlayingAlbumArt(image: UIImage?) {
        guard let image = image, var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            return
        }
        
        if #available(iOS 10.0, *) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { (size) -> UIImage in
                return image
            })
        } else {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: image)
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    func updateNowPlayingInfo() {
        guard let player = self.player, var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
                return
        }
        
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.playbackRate
        
        if #available(iOS 10.0, *) {
            info[MPNowPlayingInfoPropertyPlaybackProgress] = Float(player.currentTime / player.duration)
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        self.delegate?.onNowPlayingInfoUpdated()
        self.delegate?.onNowPlayingAlbumArtRequested()
    }
}
