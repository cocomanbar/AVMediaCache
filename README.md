# AVMediaCache

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

AVMediaCache is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby

pod 'AVMediaCache'


AVMediaCache:
    - mediaCacheLimit   设置最大缓存值
    - reportClosure     播放异常上报
    
    - mediaForAsset:        MP4链接通过此获取的AVURLAsset具备缓存能力
    - mediaForPlayerItem:   MP4链接通过此获取的AVPlayerItem具备缓存能力
    
借鉴HTTPKVTCache作者的片段缓存设计

source data total length

  0                           100     
| ------------------------------- |


local data section
 5  26        56   89 
| --- |      | ---- |       


total section sort

  0~4    5~26    27~55    56~88  89~100
| ----   -----  -------  ------  ------ |    
   net   local    net     local    net
    a              b                c


net-sections will be download when playing at the same time.

seek to 0 
    -> a ->b ->c 

seek to 20 
    -> b -> c   

```

## Author

tanxl, 125322078@qq.com

## License

AVMediaCache is available under the MIT license. See the LICENSE file for more info.
