//
//  FeedCell.swift
//  AVMediaCache_Example
//
//  Created by tanxl on 2023/4/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import UIKit
import AVKit
import SnapKit
import AVMediaCache

class FeedCell: UITableViewCell {

    var background: UIImageView!
    var indexLabel: UILabel!
    var durationLabel: UILabel!
    
    var bgView: UIView!
    var loadedRangeView: UIView!
    var progressView: UIView!
    
    var playItem: AVPlayerItem?
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    
    var currentIndex: Int!
    var model: FeedModel?
    
    weak var timeObserverToken: AnyObject?
    
    var duration: Double!
    var timeRangeLength: Double!
    
    var indicatorView: UIActivityIndicatorView!
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        duration = 0
        currentIndex = 0
        timeRangeLength = 0
        
        background = UIImageView()
        background.clipsToBounds = true
        background.contentMode = .scaleAspectFill
        background.image = UIImage(named: "img_video_loading")
        contentView.addSubview(background)
        
        indexLabel = UILabel()
        indexLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        indexLabel.textColor = .purple
        indexLabel.numberOfLines = 0
        contentView.addSubview(indexLabel)
        indexLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(88)
            make.right.equalToSuperview().offset(-20)
        }
        
        durationLabel = UILabel()
        durationLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        durationLabel.textColor = .purple
        contentView.addSubview(durationLabel)
        durationLabel.snp.makeConstraints { make in
            make.left.equalTo(indexLabel.snp.left)
            make.top.equalTo(indexLabel.snp.bottom).offset(10)
            make.right.equalTo(indexLabel.snp.right)
        }
        
        bgView = UIView()
        bgView.backgroundColor = .lightGray
        bgView.layer.cornerRadius = 3
        bgView.layer.masksToBounds = true
        contentView.addSubview(bgView)
        bgView.snp.makeConstraints { make in
            make.left.equalTo(indexLabel.snp.left)
            make.top.equalTo(durationLabel.snp.bottom).offset(10)
            make.right.equalTo(indexLabel.snp.right)
            make.height.equalTo(6)
        }
        
        loadedRangeView = UIView()
        loadedRangeView.backgroundColor = .darkGray
        bgView.addSubview(loadedRangeView)
        loadedRangeView.snp.makeConstraints { make in
            make.left.top.bottom.equalToSuperview()
            make.width.equalTo(0)
        }
        
        progressView = UIView()
        progressView.backgroundColor = .orange
        bgView.addSubview(progressView)
        progressView.snp.makeConstraints { make in
            make.left.top.bottom.equalToSuperview()
            make.width.equalTo(0)
        }
        
        indicatorView = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        contentView.addSubview(indicatorView)
        indicatorView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        background.frame = contentView.bounds
        playerLayer?.frame = contentView.bounds
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        indicatorView.startAnimating()
        indicatorView.isHidden = true
        
        timeRangeLength = 0
        indexLabel.text = nil
        duration = 0
        durationLabel.text = nil
        progressView.snp.updateConstraints { make in
            make.width.equalTo(0)
        }
        loadedRangeView.snp.updateConstraints { make in
            make.width.equalTo(0)
        }
    }
    
    func initData(_ feedModel: FeedModel?, index: Int) {
        
        model = feedModel
        indexLabel.text = (feedModel?.url.absoluteString)!
    }
    
    func pause() {
        player?.pause()
    }
    
    func play() {
        
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        
        playItem = AVMediaCache.shared.mediaForPlayerItem(url: (model?.url)!)
        player = AVPlayer(playerItem: playItem)
        addObservers()
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = background.bounds
        background.layer.addSublayer(playerLayer!)
        playerLayer?.videoGravity = .resizeAspect
        player?.volume = 1.0
        player?.automaticallyWaitsToMinimizeStalling = false // important
        player?.play()
    }
    
    func freePlay() {
                
        destoryObservers()
        
        player?.currentItem?.cancelPendingSeeks()
        player?.currentItem?.asset.cancelLoading()
        
        playerLayer?.removeFromSuperlayer()
        playerLayer?.player = nil
        playerLayer = nil
        player = nil
        playItem = nil
    }
    
    func addObservers() {
        
        let interval: CMTime = CMTime(seconds: 0.5, preferredTimescale: .max)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main, using: { [weak self] time in
            guard let self = self else { return }
            
            if self.duration <= 0 {
                return
            }
            let current = CMTimeGetSeconds(time)
            let scale = current / self.duration
            let width = self.bgView.frame.width * scale
            self.progressView.snp.updateConstraints { make in
                make.width.equalTo(width)
            }
            
        }) as AnyObject?
        
        playItem?.addObserver(self, forKeyPath: "status", context: nil)
        playItem?.addObserver(self, forKeyPath: "loadedTimeRanges", context: nil)
        playItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", context: nil)
        playItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlayEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    func destoryObservers() {
        
        NotificationCenter.default.removeObserver(self)
        
        playItem?.removeObserver(self, forKeyPath: "status")
        playItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
        playItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
        playItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
        
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
        }
    }
    
    @objc func handlePlayEnd(_ notif: Notification) {
        if let item = notif.object as? NSObject, item == playItem {
            player?.seek(to: CMTime(seconds: 0, preferredTimescale: .max), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
            player?.play()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "status" {
            
            guard let playItem = playItem else { return }
            
            if playItem.status == .readyToPlay {
                
                duration = CMTimeGetSeconds(playItem.duration)
                durationLabel.text = timeStringFromSecondsValue(Int(duration))
                
            } else if playItem.status == .unknown {
                
                durationLabel.text = "unknown"
                
            } else if playItem.status == .failed {
                
                durationLabel.text = playItem.error?.localizedDescription ?? ""
                
            }
            
        } else if keyPath == "playbackBufferEmpty" {
            
            guard let _ = playItem else { return }
            
            contentView.bringSubview(toFront: indicatorView)
            indicatorView.isHidden = false
            indicatorView.startAnimating()
            
        } else if keyPath == "playbackLikelyToKeepUp" {
            
            guard let _ = playItem else { return }
            
            indicatorView.isHidden = true
            indicatorView.stopAnimating()
            
        } else if keyPath == "loadedTimeRanges" {
            
            guard let _ = playItem else { return }
            
            let array = change?[NSKeyValueChangeKey.newKey] as? [CMTimeRange]
            
            if let rangeValue: CMTimeRange = array?.first {
                if rangeValue.isValid || duration <= 0 {
                    return
                }
                
                let curr = CMTimeGetSeconds(CMTimeRangeGetEnd(rangeValue))
                if curr > timeRangeLength {
                    timeRangeLength = curr
                    let scale = curr / duration
                    let width = bgView.frame.width * scale
                    loadedRangeView.snp.updateConstraints { make in
                        make.width.equalTo(width)
                    }
                }
            }
        } else {
            
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func timeStringFromSecondsValue(_ time: Int) -> String {
        
        var retval: String
        let hours = time / 3600
        let minutes = time / 60 % 60
        let seconds = time % 60
        if hours > 0 {
            retval = NSString.init(format: "%01d:%02d:%02d", hours, minutes, seconds) as String
        } else if minutes > 0 {
            retval = NSString.init(format: "%02d:%02d", minutes, seconds) as String
        } else {
            retval = NSString.init(format: "00:%02d", seconds) as String
        }
        return retval
    }
}
