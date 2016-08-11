//
//  ViewController.swift
//  PJMusicPlayer
//
//  Created by 彭晋 on 16/7/2.
//  Copyright © 2016年 彭晋. All rights reserved.
//

import UIKit
import AVFoundation


enum Event {
    case asTimer
    case asValue
}

public class Song: NSObject {
    var songTitle = ""
    var singer = "网络歌手"
    
    var songSourceName = ""
    var songSourceType = "mp3"
    
    var lrcSourceName = ""
    var lrcSourceType = "lrc"
}

var isReadyToPlay = true
var isTimeToChangeScrollView = false
var isCircleType = true

var songList = Array<Song>()
var currentSong = Song()
var audioPlayer = AVAudioPlayer()
var tempLRCTime:NSTimeInterval = 0
var timer:NSTimer!
var timer2:NSTimer!
var updateProgressSlider = Event.asTimer

let heightOfLCRLabel:CGFloat = 24
let emptyView = UIView()
let playListTableView = UITableView()

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, AVAudioPlayerDelegate, UIGestureRecognizerDelegate {
    private var lrcLabelViewArray = Array<UILabel>()
    private var lrcTimeArray = Array<NSTimeInterval>()
    private var time2LRC = [NSTimeInterval: String]()
    private let number = "0123456789"
    private var tempTimeLine = 0
    
    @IBOutlet weak var lrcScrollView: UIScrollView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var singerLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var progressTimeLabel: UILabel!
    @IBOutlet weak var emptyLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    // MARK: Slider
    
    @IBAction func progressSliderTap(sender: UISlider) {
        let sliderValue = Double(sender.value)
        updateProgressSlider = .asValue
        
        progressTimeLabel.text = calculatTime2String(audioPlayer.duration * sliderValue)
        progressTimeLabel.alpha = 1
    }
    
    @IBAction func progressSliderTouchUpInside(sender: UISlider) {
        let sliderValue = Double(sender.value)
        
        audioPlayer.currentTime = audioPlayer.duration * sliderValue
        
        updateProgressSlider = .asTimer
        
        progressTimeLabel.text = ""
        progressTimeLabel.alpha = 0
    }
    
    // 更新TimeLabel和进度条
    func updateTimeLabelAndProgressSlider() {
        timeLabel.text = calculatTime2String(audioPlayer.currentTime)
            + "/"
            + calculatTime2String(audioPlayer.duration)
        
        // 进度条的更新视情况而定
        switch updateProgressSlider {
        case .asTimer:
            // 根据歌曲播放的时间更新进度条
            progressSlider.value = Float(audioPlayer.currentTime) / Float(audioPlayer.duration)
            break
        case .asValue:
            // 根据进度条自生的值直接更新
            return
        }
    }
    
    // MARK: Button Taps
    
    @IBAction func nextTap(sender: UIButton) {
        playNextSong()
    }
    
    @IBAction func previousTap(sender: UIButton) {
        playPreviousSong()
    }
    
    @IBAction func cycleTap(sender: UIButton) {
        if sender.currentImage == UIImage(named: "circleClose.png") {
            sender.setImage(UIImage(named: "circleOpen.png"), forState: UIControlState.Normal)
            isCircleType = true
        } else {
            sender.setImage(UIImage(named: "circleClose.png"), forState: UIControlState.Normal)
            isCircleType = false
        }
    }
    
    @IBAction func playTap(sender: UIButton) {
        if !audioPlayer.playing {
            audioPlayer.play()
            sender.setImage(UIImage(named: "pause.png"), forState: UIControlState.Normal)
            isReadyToPlay = false
        } else {
            audioPlayer.pause()
            sender.setImage(UIImage(named: "play.png"), forState: UIControlState.Normal)
            isReadyToPlay = true
        }
    }
    
    // MARK: Button Tap Actions
    
    func playNextSong() {
        let temp = songList.indexOf(currentSong)!
        
        if temp < songList.count - 1 {
            setCurrentSong(temp + 1)
        }
        
        if temp == songList.count - 1 {
            if isCircleType {
                setCurrentSong(0)
            } else {
                stopAll()
                return
            }
        }
        
        audioPlayer.play()
        
        self.playButton.setImage(UIImage(named: "pause.png"), forState: UIControlState.Normal)
    }
    
    func playPreviousSong() {
        let temp = songList.indexOf(currentSong)!
        
        if temp == 0 {
            if isCircleType {
                setCurrentSong(songList.count - 1)
            } else {
                stopAll()
                return
            }
        }
        
        if temp > 0 {
            setCurrentSong(temp - 1)
        }
        
        audioPlayer.play()
        
        self.playButton.setImage(UIImage(named: "pause.png"), forState: UIControlState.Normal)
    }
    
    func setCurrentSong(number: Int) {
        currentSong = songList[number]
        loadMusic()
        loadLRC()
    }
    
    // MARK: Play List Table View
    
    @IBAction func menuTap(sender: UIButton) {
        showPlayListTableView()
    }
    
    func showPlayListTableView() {
        let originPlayList = CGPoint(x: 0.3 * self.view.frame.width, y: 0.2 * self.view.frame.height)
        let sizePlayList = CGSize(width: 0.66 * self.view.frame.width, height: 0.66 * self.view.frame.height)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.dismissPlayListTableView(_:)))
        
        tapGestureRecognizer.delegate = self
        
        emptyView.frame = self.view.frame
        emptyView.userInteractionEnabled = true
        emptyView.addGestureRecognizer(tapGestureRecognizer)
        
        
        playListTableView.backgroundView = UIImageView(image: UIImage(named: "playListBackground.jpg"))
        playListTableView.frame = CGRect(origin: originPlayList, size: sizePlayList)
        playListTableView.alpha = 0.8
        
        playListTableView.delegate = self
        playListTableView.dataSource = self
        
        // 正在播放的歌曲显示为选中状态，必须写在 delegate 和 dataSource 之后才有效果
        playListTableView.selectRowAtIndexPath(NSIndexPath.init(forRow: getCurrentSongIndex(), inSection: 0), animated: false, scrollPosition: UITableViewScrollPosition.None)
        
        emptyView.addSubview(playListTableView)
        self.view.addSubview(emptyView)
    }
    
    func dismissPlayListTableView(sender: UITapGestureRecognizer) {
        playListTableView.removeFromSuperview()
        emptyView.removeFromSuperview()
    }
    
    // 限制dismissPlayListTableView的响应区域
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        let touchPoint = touch.locationInView(emptyView)
        
        if CGRectContainsPoint(playListTableView.frame, touchPoint) {
            return false
        } else {
            return true
        }
    }
    
    // tableView delegate and dataSource
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songList.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "cellId")
        
        cell.textLabel?.text = songList[indexPath.row].songTitle
        cell.detailTextLabel?.text = songList[indexPath.row].singer
        cell.backgroundColor = UIColor.clearColor()
        cell.textLabel?.textColor = UIColor.lightGrayColor()
        cell.detailTextLabel?.textColor = UIColor.lightGrayColor()
        
        cell.selectedBackgroundView = UIView(frame: cell.frame)
        cell.selectedBackgroundView?.backgroundColor = UIColor.darkGrayColor()
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        setCurrentSong(indexPath.row)
        audioPlayer.play()
        self.playButton.setImage(UIImage(named: "pause.png"), forState: UIControlState.Normal)
    }
    
    // MARK: View Did Load
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        loadList()
        }
    
    func loadList() {
        let song1 = Song()
        let song2 = Song()
        let song3 = Song()
        
        song1.songTitle = "情非得已";
        song1.songSourceName = "情非得已"
        song1.lrcSourceName = "情非得已"
        
        song2.songTitle = "背对背拥抱"
        song2.singer = "林俊杰"
        song2.songSourceName = "林俊杰-背对背拥抱"
        song2.lrcSourceName = "林俊杰-背对背拥抱"
        
        song3.songTitle = "偶阵雨"
        song3.singer = "梁静茹"
        song3.songSourceName = "梁静茹-偶阵雨"
        song3.lrcSourceName = "梁静茹-偶阵雨"
        
        songList.append(song1)
        songList.append(song2)
        songList.append(song3)
        
        setCurrentSong(0)
    }
    
    func loadMusic() {
        titleLabel.text = currentSong.songTitle
        singerLabel.text = currentSong.singer
        
        let path = NSBundle.mainBundle().URLForResource(currentSong.songSourceName, withExtension: currentSong.songSourceType)
        
        do {
            try audioPlayer = AVAudioPlayer(contentsOfURL: path!)
            
            audioPlayer.delegate = self
            
            startTimer()
        } catch {
            print(error)
        }
    }
    
    func loadLRC() {
        cleanOldLRCSource()
        
        let pathURLOfLRC = NSBundle.mainBundle().URLForResource(currentSong.lrcSourceName, withExtension: currentSong.lrcSourceType)
        let allContentOfLRC = try! NSString(contentsOfURL: pathURLOfLRC!, encoding: NSUTF8StringEncoding)
        
        // 歌词文件的每行“[时间]歌词内容”存为数组
        var tempArrayOfLRC = allContentOfLRC.componentsSeparatedByString("\n")
        
        tempArrayOfLRC = tempArrayOfLRC.filter { $0 != "" }
        
        // 处理歌词，将歌词以时间为key放入字典
        for j in 0 ..< tempArrayOfLRC.count {
            // 用“]”分割字符串，可能含有多个时间对应个一句歌词的现象,并且歌词可能为空,例如：“[00:12.34][01:56.78]”
            // 分割后的数组为：["[00:12.34", "[01:56.78", ""]
            var arrContentLRC = tempArrayOfLRC[j].componentsSeparatedByString("]")
            //            print(j, arrContentLRC)
            
            // 判断数组中每个元素的第二个字符是不是数字,如果是数字，进入循环
            if(number.componentsSeparatedByString((arrContentLRC[0] as NSString).substringWithRange(NSMakeRange(1, 1))).count > 1) {
                // 不用处理最后一个元素
                for k in 0..<(arrContentLRC.count - 1) {
                    // 将元素内容中的“[”去掉
                    if arrContentLRC[k].containsString("[") {
                        arrContentLRC[k] = (arrContentLRC[k] as NSString).substringFromIndex(1)
                    }
                    
                    // 将时间和歌词对应地放入字典
                    time2LRC[calculatString2Time(arrContentLRC[k] as NSString)] = arrContentLRC[arrContentLRC.count - 1]
                }
            }
        }
        
        // 根据歌词行数设置ScrollView的内容范围
        self.lrcScrollView.showsVerticalScrollIndicator = false
        self.lrcScrollView.contentSize.width = self.view.frame.width * 0.98
        self.lrcScrollView.contentSize.height = self.view.frame.height * 0.65 + (heightOfLCRLabel * CGFloat(time2LRC.count))
        
        showLRCToScrollView()
        
        // 初始化LRCScrollView的位置
        self.lrcScrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
    }
    
    // MARK: LRC functions
    
    // 显示歌词
    func showLRCToScrollView() {
        var i:CGFloat = 0
        
        for key in time2LRC.keys.sort() {
            // 创建显示一行歌词的label，并设置位置、大小、内容
            let label = UILabel(frame: CGRect(
                x: 0,
                y: (self.view.frame.height * 0.65 / 2 + (heightOfLCRLabel * i)),
                width: self.view.frame.width * 0.98,
                height: heightOfLCRLabel))
            
            label.text = time2LRC[key]!
            label.backgroundColor = UIColor.clearColor()
            label.textColor = UIColor.lightTextColor()
            label.textAlignment = NSTextAlignment.Center
            label.font = UIFont.systemFontOfSize(16)
            
            // 添加到scrollview
            self.lrcScrollView.addSubview(label)
            
            // 添加到lrcLabelViewArray
            lrcLabelViewArray.append(label)
            
            // 将时间添加到数组
            lrcTimeArray.append(key)
            
            i += 1
        }
    }
    
    // 根据时间调整ScrollView的位置
    func updateLRCScrollView() {
        if lrcTimeArray.isEmpty {
            return
        }
        
        switch audioPlayer.currentTime {
        case 0..<lrcTimeArray[0]:
            // 不更新位置
            isTimeToChangeScrollView = true
            return
        case lrcTimeArray[0]..<audioPlayer.duration:
            // 判断是否是第一次 到达歌词的时间（小于 当前时间 的歌词时间）
            if tempLRCTime != maxElementOfLRCTime()! {
                tempLRCTime = maxElementOfLRCTime()!
                
                isTimeToChangeScrollView = true
            } else {
                isTimeToChangeScrollView = false
            }
            
            // 更新到当前歌词的位置
            if isTimeToChangeScrollView {
                //                print(time2LRC[tempLRCTime]!)
                
                // ScrollView滚动到歌词Label的中心位置
                let lrcRowNumber = lrcTimeArray.indexOf(tempLRCTime)!
                var newOffset = self.lrcScrollView.contentOffset
                
                newOffset.y = lrcLabelViewArray[lrcRowNumber].center.y - self.view.frame.height * 0.65 / 2
                
                self.lrcScrollView.setContentOffset(newOffset, animated: true)
                
                // 取消非当前Label歌词的高亮、字体加大
                for itemLabel in lrcLabelViewArray {
                    //                    print(itemLabel)
                    itemLabel.textColor = UIColor.lightTextColor()
                    itemLabel.font = UIFont.systemFontOfSize(16)
                }
                
                // 高亮当前Label中的歌词
                lrcLabelViewArray[lrcRowNumber].textColor = UIColor.whiteColor()
                lrcLabelViewArray[lrcRowNumber].font = UIFont.systemFontOfSize(20)
            }
        default:
            // 不更新位置
            return
        }
    }
    
    func cleanOldLRCSource() {
        if !lrcTimeArray.isEmpty {
            for subView in self.lrcScrollView.subviews {
                subView.removeFromSuperview()
            }
            
            lrcLabelViewArray.removeAll()
            lrcTimeArray.removeAll()
            time2LRC.removeAll()
            tempTimeLine = 0
        }
    }
    
    // 判断歌曲时间所属于的歌词时间段(寻找时间数组中小于当前时间的最大值)
    func maxElementOfLRCTime() -> NSTimeInterval! {
        return lrcTimeArray.filter { $0 <= audioPlayer.currentTime }.maxElement()
    }
    
    // 将时间转换为String
    // 输出时间字符串格式为:"00:12.34"
    func calculatTime2String(timeTime: NSTimeInterval) -> String {
        var strTime: String!
        
        if (timeTime % 60 < 10) {
            strTime = String(Int(timeTime) / 60)
                    + ":0"
                    + String(Int(timeTime) % 60)
        } else {
            strTime = String(Int(timeTime) / 60)
                    + ":"
                    + String(Int(timeTime) % 60)
        }
        
        return strTime
    }
    
    // 将字符串转换为Float
    // 输入时间格式为:“00:12.34”
    func calculatString2Time(strTime: NSString) -> NSTimeInterval {
        var arrTime:[NSString] = strTime.componentsSeparatedByString(":")
        
        let numberTime = arrTime[0].doubleValue * 60 + arrTime[1].doubleValue
        
        return numberTime
    }
    
    // MARK: Timer
    
    func startTimer() {
        timer = NSTimer.scheduledTimerWithTimeInterval(0.1,
                                               target: self,
                                             selector: #selector(ViewController.updateTimeLabelAndProgressSlider),
                                             userInfo: nil,
                                              repeats: true)
        
        timer2 = NSTimer.scheduledTimerWithTimeInterval(0.2,
                                                target: self,
                                              selector: #selector(ViewController.updateLRCScrollView),
                                              userInfo: nil,
                                               repeats: true)
    }
    
    func stopAll() {
        audioPlayer.currentTime = 0
        timer.invalidate()
        timer2.invalidate()
        audioPlayer.stop()
        self.playButton.setImage(UIImage(named: "play.png"), forState: UIControlState.Normal)
    }
    
    // MARK: Others
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        self.playButton.setImage(UIImage(named: "play.png"), forState: UIControlState.Normal)
        cleanOldLRCSource()
        playNextSong()
    }
    
    func getCurrentSongIndex() -> Int {
        let title = self.titleLabel.text
        var index = 0
        
        for tempSong in songList {
            if (tempSong.songTitle == title) {
                index = songList.indexOf(tempSong)!
            }
        }
//        print(index)
        return index
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

