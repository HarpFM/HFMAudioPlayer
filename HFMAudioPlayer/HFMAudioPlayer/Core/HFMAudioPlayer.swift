//
//  HFMAudioPlayer.swift
//  HarpFM
//
//  Created by Brian Drelling on 10/28/16.
//  Copyright © 2016 Brian Drelling. All rights reserved.
//

import AVFoundation
import Foundation

open class HFMAudioPlayer: NSObject {
    // MARK: - Properties
    
    private var localPlayer: AVAudioPlayer?
    @objc private var streamPlayer: AVPlayer?
    
    public var currentTime: TimeInterval {
        if let player = self.localPlayer {
            return player.currentTime
        } else if let player = self.streamPlayer {
            return player.currentTime().seconds
        } else {
            return 0
        }
    }
    
    public var currentTimeText: String? {
        return self.getFormattedString(from: self.currentTime)
    }
    
    public var duration: TimeInterval {
        if let player = self.localPlayer {
            return player.duration
        } else if let player = self.streamPlayer {
            let seconds = player.currentItem?.duration.seconds
            
            if (seconds?.isNaN != false) { return 0 }
            
            return seconds ?? 0
        } else {
            return 0
        }
    }
    
    public var isPlaying: Bool  {
        if let player = self.localPlayer {
            return player.isPlaying
        } else if let player = self.streamPlayer {
            return player.rate != 0 && player.error == nil
        }
        
        return false
    }
    
    public var isStreaming: Bool {
        return self.streamPlayer != nil
    }
    
    public var playbackRate: Float {
        return self.localPlayer?.rate ?? self.streamPlayer?.rate ?? 0
    }
    
    public var remainingTime: TimeInterval {
        return self.duration - self.currentTime
    }
    
    public var remainingTimeText: String? {
        return self.getFormattedString(from: self.remainingTime)
    }
    
    private var timeToSeek: TimeInterval?
    
    public var url: URL? {
        if let player = self.localPlayer {
            return player.url
        } else if let player = self.streamPlayer,
            let asset = player.currentItem?.asset as? AVURLAsset {
            return asset.url
        } else {
            return nil
        }
    }
    
    // MARK: - Methods
    
    // MARK: Public
    
    public init(url: URL?, time: TimeInterval? = nil) {
        super.init()
        
        self.load(url: url, time: time)
    }
    
    public func load(url: URL?, time: TimeInterval? = nil) {
        guard let url = url else {
            return
        }
        
        let time = time ?? self.currentTime
        
        if (url.isFileURL) {
            self.streamPlayer?.pause()
            self.streamPlayer = nil
            self.localPlayer = try? AVAudioPlayer(contentsOf: url)
            
            self.seek(to: time)
        } else {
            self.localPlayer?.stop()
            self.localPlayer = nil
            self.streamPlayer = AVPlayer(url: url)
            
            self.timeToSeek = time
            self.addObserver(self, forKeyPath: #keyPath(streamPlayer.currentItem.status), options: [.old, .new], context: nil)
        }
        
        if (self.isPlaying) {
            self.play()
        } else {
            self.prepareToPlay()
        }
    }
    
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == #keyPath(streamPlayer.currentItem.status)) {
            if (self.streamPlayer?.status == .readyToPlay) {
                self.seek(to: self.timeToSeek)

                // Find way to abstract this
//                AudioManager.shared.requestAudioPlayerUpdate()
//                
//                if (self.isPlaying) {
//                    AudioManager.shared.play()
//                }
                
                self.timeToSeek = nil
                self.removeObserver(self, forKeyPath: #keyPath(streamPlayer.currentItem.status))
            }
        }
    }
    
    public func pause() {
        if let player = self.localPlayer {
            player.pause()
        } else if let player = self.streamPlayer {
            player.pause()
        }
    }
    
    public func play() {
        if let player = self.localPlayer {
            player.play()
        } else if let player = self.streamPlayer {
            player.play()
            
            if #available(iOS 10.0, *) {
                player.playImmediately(atRate: self.playbackRate)
            }
        }
    }
    
    public func prepareToPlay() {
        if let player = self.localPlayer {
            player.prepareToPlay()
        }
    }
    
    public func seek(to time: TimeInterval?) {
        guard var time = time else {
            return
        }
        
        if (time >= self.duration) {
            time = 0
            self.stop()
        } else if (time <= 0) {
            time = 0
        }
        
        if let player = self.localPlayer {
            player.currentTime = time
        } else if let player = self.streamPlayer {
            let newTime = CMTime(seconds: time, preferredTimescale: player.currentTime().timescale)
            player.currentItem?.seek(to: newTime)
            player.seek(to: newTime)
        }
    }
    
    public func setPlaybackRate(to rate: Float?) {
        guard let rate = rate else {
            return
        }
        
        if let player = self.localPlayer {
            player.rate = rate
        } else if let player = self.streamPlayer {
            player.rate = rate
        }
    }
    
    public func skip(by seconds: TimeInterval?) {
        guard let seconds = seconds else {
            return
        }
        
        let newTime = self.currentTime + seconds
        
        self.seek(to: newTime)
    }
    
    public func stop() {
        if let player = self.localPlayer {
            player.stop()
        } else if let player = self.streamPlayer {
            // TODO: No stop method for AVPlayer?
            player.pause()
        }
    }
    
    @discardableResult
    public func togglePlayPause() -> Bool {
        if (self.isPlaying) {
            self.pause()
        } else {
            self.play()
        }
        
        return self.isPlaying
    }
    
    // MARK: Private
    
    private func getFormattedString(from timeInterval: TimeInterval?) -> String? {
        guard let timeInterval = timeInterval else {
            return nil
        }
        
        let duration = Int(timeInterval)
        
        let seconds = duration % 60
        let minutes = (duration / 60) % 60
        let hours = duration / 3600
        
        if (hours <= 0) {
            return String(format: "%01d:%02d", minutes, seconds)
        } else {
            return String(format: "%01d:%02d:%02d", hours, minutes, seconds)
        }
    }
}
