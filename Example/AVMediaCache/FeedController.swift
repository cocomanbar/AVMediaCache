//
//  FeedController.swift
//  AVMediaCache_Example
//
//  Created by tanxl on 2023/4/23.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import UIKit

class FeedController: UIViewController {
    
    var tableView: UITableView!
    var dataSource = [FeedModel]()
    
    var lastFeedCell: FeedCell?
    var currentIndex = 0 {
        didSet {
            let indexPath = IndexPath(item: currentIndex, section: 0)
            if let cell = tableView.cellForRow(at: indexPath) as? FeedCell {
                if cell == lastFeedCell {
                    return
                }
                lastFeedCell?.freePlay()
                lastFeedCell = cell
                cell.play()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        
        let background = UIImageView()
        background.frame = view.bounds
        background.contentMode = .scaleAspectFill
        background.image = UIImage(named: "img_video_loading")
        view.addSubview(background)
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorColor = .clear
        tableView.separatorStyle = .none
        tableView.isPagingEnabled = true
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .never
        }
        view.addSubview(tableView)
        
        initData()
    }
    
    deinit {
        if let lastFeedCell = lastFeedCell {
            lastFeedCell.freePlay()
        }
        lastFeedCell = nil
    }
    
    func initData() {
        
        // error
        // "http://vfx.mtime.cn/Video/2021/07/09/mp4/210709172715355157.mp4"
        
        let urls = [
            "http://aliuwmp3.changba.com/userdata/video/45F6BD5E445E4C029C33DC5901307461.mp4",
            "https://media.w3.org/2010/05/sintel/trailer.mp4",
            "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4",
            "http://www.w3school.com.cn/example/html5/mov_bbb.mp4",
            "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4",
            "http://vfx.mtime.cn/Video/2021/07/10/mp4/210710171112971120.mp4",
            "http://vfx.mtime.cn/Video/2021/07/10/mp4/210710122716702150.mp4",
            "http://vfx.mtime.cn/Video/2021/07/10/mp4/210710095541348171.mp4",
            "http://vfx.mtime.cn/Video/2021/07/10/mp4/210710094507540173.mp4",
            "http://vfx.mtime.cn/Video/2021/07/09/mp4/210709224656837141.mp4"
        ]
        
        for url in urls {
            let model = FeedModel(url: URL(string: url)!)
            dataSource.append(model)
        }
        
        tableView.reloadData()
        currentIndex = 0
    }
    
}

extension FeedController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dataSource.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        tableView.frame.height
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "c") as? FeedCell
        if cell == nil {
            cell = FeedCell(style: .default, reuseIdentifier: "c")
        }
        let index = indexPath.row
        let model = dataSource[index]
        cell?.initData(model, index: index)
        return cell!
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        DispatchQueue.main.async {
            let translatedPoint = scrollView.panGestureRecognizer.translation(in: scrollView)
            
            scrollView.panGestureRecognizer.isEnabled = false
            
            if translatedPoint.y < -50 && self.currentIndex < self.dataSource.count - 1 {
                self.currentIndex += 1
            }
            if translatedPoint.y > 50 && self.currentIndex > 0 {
                self.currentIndex -= 1
            }
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut]) {
                let index = IndexPath(item: self.currentIndex, section: 0)
                self.tableView.scrollToRow(at: index, at: .top, animated: false)
            } completion: { finished in
                scrollView.panGestureRecognizer.isEnabled = true
            }
        }
    }
}
