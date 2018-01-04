//
//  MTTSingletonManager.swift
//  MyTwitter
//
//  Created by LiuChuanan on 2017/9/18.
//  Copyright © 2017年 waitWalker. All rights reserved.
//

import UIKit
import Foundation
import Photos
import AssetsLibrary
import AVFoundation
import MBProgressHUD

class MTTSingletonManager: NSObject 
{
    var user_name:String     = ""
    var email:String         = ""
    var phone_num:String     = ""
    var password:String      = ""
    var tappedImageIndex:Int = 0
    
    // 录音相关 
    var recorder:AVAudioRecorder!
    var currentRecorderPath:String!
    var recorderTimer:Timer!
    var recorderContainerView:UIView!
    var recordingAnimationImageView:UIImageView!
    var recordingMicroImageView:UIImageView!
    var recordCancelImageView:UIImageView!
    var recordShotTimeImageView:UIImageView!
    var recordHintTextLabel:UILabel!
    
    var count:Int! = 0
    
    
    
    
    
    

    static let sharedInstance = MTTSingletonManager()
    
    private override init
    () {
        super.init()
    }
    
    // MARK: - AppDelegate 相关
    func getAppDelegate() -> AppDelegate
    {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    func getKeyWindow() -> UIWindow
    {
        return getAppDelegate().window!
    }
    
    func getRootViewController() -> UIViewController
    {
        return getKeyWindow().rootViewController!
    }
    
    // MARK: - 隐藏 显示 tabBar
    func hideTabbar() -> Void
    {
        let rootVC = getRootViewController()
        
        if (rootVC.isKind(of: UITabBarController.self))
        {
            let tabBarVC = rootVC as! UITabBarController
            tabBarVC.tabBar.isHidden = true
        } else
        {
            rootVC.tabBarController?.tabBar.isHidden = true
        }
        
    }
    
    func showTabbar() -> Void
    {
        let rootVC = getRootViewController()
        
        if (rootVC.isKind(of: UITabBarController.self))
        {
            let tabBarVC = rootVC as! UITabBarController
            tabBarVC.tabBar.isHidden = false
        } else
        {
            rootVC.tabBarController?.tabBar.isHidden = false
        }
    }
    
    // MARK: - 获取相机相册权限状态
    func getCameraAuthorizationStatus() -> Bool
    {
        let authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        
        if authStatus != AVAuthorizationStatus.denied
        {
            return true
        }
        return false
    }
    
    func getPhotoLibraryAuthorizationStatus() -> Bool
    {
        if PHPhotoLibrary.authorizationStatus() != PHAuthorizationStatus.denied
        {
            return true
        }
        return false
    }
    
    // MARK: - 授权失败弹框
    func showAlter(with message: String) -> Void
    {
        let alertController = UIAlertController(title: "提示", message: message, preferredStyle: UIAlertControllerStyle.alert)
        let confirmAction = UIAlertAction(title: "确定", style: UIAlertActionStyle.default) { action in
            UIApplication.shared.open(URL(string: "App-Prefs:root=Privacy")!, options: ["" : ""], completionHandler: { completed in
                
            })
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertActionStyle.cancel) { action in
            
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(confirmAction)
        
        getRootViewController().present(alertController, animated: true) {
            
        }
    }
    
    
    
    
    
    /***************************************/
    // MARK: - recorder 相关 
    func startRecorder() -> Void 
    {
        setupSubview()
        setupRecorder()
    }
    
    func cancelRecorder() -> Void 
    {
        recorder.stop()
        recorderTimer.invalidate()
        recorderTimer = nil
        recorderContainerView.removeFromSuperview()
    }
    
    func finishRecorder() -> Void 
    {
        if recorder.currentTime < 1.0
        {
            showShotTimeView()
            return
        }
        stopRecorder()
    }
    
    func readyToCancelRecorder() -> Void 
    {
        recordingAnimationImageView.isHidden = true
        recordingMicroImageView.isHidden     = true
        recordCancelImageView.isHidden       = false
        recordShotTimeImageView.isHidden     = true
        recordHintTextLabel.text = "手指松开，取消发送"
    }
    
    func readyToResumeRecorder() -> Void 
    {
        recordingAnimationImageView.isHidden = false
        recordingMicroImageView.isHidden     = false
        recordCancelImageView.isHidden       = true
        recordShotTimeImageView.isHidden     = true
        recordHintTextLabel.text = "手指松开，取消发送"
    }
    
    func stopRecorder() -> Void 
    {
        recorderTimer.invalidate()
        recorderTimer = nil
        recorder.stop()
        recorderContainerView.removeFromSuperview()
    }
    
    private func setupRecorder() -> Void 
    {
        //初始化录音器
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        
        //设置录音类型
        try! session.setCategory(AVAudioSessionCategoryPlayAndRecord)
        
        //设置支持后台
        try! session.setActive(true)
        
        //组合录音文件路径
        self.currentRecorderPath = getDocumentPath() + String(format: "/voice-%.0f.aac", Date().timeIntervalSince1970)
        
        //初始化字典并添加设置参数
        let recorderSeetingsDic = setupSettings()
        
        //初始化录音器
        recorder = try! AVAudioRecorder(url: URL(string: self.currentRecorderPath)!, settings: recorderSeetingsDic)
        
        if recorder != nil 
        {
            //开启仪表计数功能
            recorder!.isMeteringEnabled = true
            //准备录音
            recorder!.prepareToRecord()
            //开始录音
            recorder!.record()
            
            recorder.delegate = self
            
            //启动定时器，定时更新录音音量
            recorderTimer = Timer.scheduledTimer(timeInterval: 0.001, 
                                                 target: self,
                                                 selector: #selector(recorderTimerAction),
                                                 userInfo: nil, 
                                                 repeats: true)
        }
    }
    
    @objc func recorderTimerAction() -> Void 
    {
        recorder!.updateMeters() // 刷新音量数据
        var averageV:Float = recorder!.averagePower(forChannel: 0) //获取音量的平均值
        print("声波:\(averageV)")
        averageV = averageV + 75.0
        
        if averageV > 0.0 && averageV <= 10.0 
        {
            recordingAnimationImageView.image = UIImage.imageNamed(name: "twitter_record_vol_1")
        } else if averageV > 10.0 && averageV <= 20.0
        {
            recordingAnimationImageView.image = UIImage.imageNamed(name: "twitter_record_vol_2")
        } else if averageV > 20.0 && averageV <= 30.0
        {
            recordingAnimationImageView.image = UIImage.imageNamed(name: "twitter_record_vol_3")
        } else if averageV > 30.0 && averageV <= 40.0
        {
            recordingAnimationImageView.image = UIImage.imageNamed(name: "twitter_record_vol_4")
        } else if averageV > 40.0 && averageV <= 50.0
        {
            recordingAnimationImageView.image = UIImage.imageNamed(name: "twitter_record_vol_5")
        } else if averageV > 50.0 && averageV <= 60.0
        {
            recordingAnimationImageView.image = UIImage.imageNamed(name: "twitter_record_vol_6")
        } else if averageV > 60.0 && averageV <= 70.0
        {
            recordingAnimationImageView.image = UIImage.imageNamed(name: "twitter_record_vol_7")
        }  else
        {
            recordingAnimationImageView.image = UIImage.imageNamed(name: "twitter_record_vol_7")
        }
        
    }
    
    private func setupSettings() -> [String:Any] 
    {
        let setting = 
            [
                AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC),
                AVNumberOfChannelsKey: 2, //录音的声道数，立体声为双声道
                AVEncoderAudioQualityKey : AVAudioQuality.max.rawValue,
                AVEncoderBitRateKey : 320000,
                AVSampleRateKey : 44100.0 //录音器每秒采集的录音样本数
            ] as [String : Any]
        
        return setting
        
    }
    
    // 录音缓存路径 
    private func getRecorderFilePath() -> String 
    {
        let filePath = getDocumentPath().appendingFormat("&@", "/recorderFile")
        return filePath
    }
    
    
    func setupSubview() -> Void 
    {
        if recorderContainerView == nil 
        {
            recorderContainerView = UIView(frame: CGRect(x: (kScreenWidth - 160) / 2, y: (kScreenHeight - 140) / 2, width: 160, height: 140))
            recorderContainerView.layer.cornerRadius = 15
            recorderContainerView.clipsToBounds = true
            recorderContainerView.backgroundColor = UIColor.orange.withAlphaComponent(0.4)
            self.getKeyWindow().addSubview(recorderContainerView)
            
            recordingMicroImageView = UIImageView(frame: CGRect(x: 40, y: 25, width: 37, height: 70))
            recordingMicroImageView.image = UIImage.imageNamed(name: "twitter_record_micro")
            recorderContainerView.addSubview(recordingMicroImageView)
            
            recordingAnimationImageView = UIImageView(frame: CGRect(x: recordingMicroImageView.frame.maxX + 16, y: 30, width: 29, height: 64))
            recordingAnimationImageView.image = UIImage.imageNamed(name: "twitter_record_vol_5")
            recorderContainerView.addSubview(recordingAnimationImageView)
            
            recordHintTextLabel = UILabel()
            recordHintTextLabel.frame = CGRect(x: 0, y: recordingAnimationImageView.frame.maxY + 10, width: recorderContainerView.frame.size.width, height: 20)
            recordHintTextLabel.backgroundColor = UIColor.clear
            recordHintTextLabel.textColor = UIColor.white
            recordHintTextLabel.textAlignment = NSTextAlignment.center
            recordHintTextLabel.font = UIFont.systemFont(ofSize: 14.0)
            recordHintTextLabel.text = "手指上滑,取消发送"
            recorderContainerView.addSubview(recordHintTextLabel)
            
            recordCancelImageView = UIImageView(frame: CGRect(x: 45, y: 20, width: 60, height: 75))
            recordCancelImageView.image = UIImage.imageNamed(name: "twitter_record_cancel")
            recorderContainerView.addSubview(recordCancelImageView)
            
            recordShotTimeImageView = UIImageView(frame: CGRect(x: 70, y: 20, width: 20, height: 75))
            recordShotTimeImageView.image = UIImage.imageNamed(name: "twitter_record_shot_time")
            recorderContainerView.addSubview(recordShotTimeImageView)
        }
        
        recordingAnimationImageView.isHidden = false
        recordingMicroImageView.isHidden     = false
        recordCancelImageView.isHidden       = true
        recordShotTimeImageView.isHidden     = true
    }
    
    private func showShotTimeView() -> Void 
    {
        recordingAnimationImageView.isHidden = true
        recordingMicroImageView.isHidden     = true
        recordCancelImageView.isHidden       = true
        recordShotTimeImageView.isHidden     = false
        recordHintTextLabel.text             = "说话时间太短"
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5) { 
            self.stopRecorder()
        }
    }
    
    
    
    /***********************************************************/
    
    
    
    /**工具相关**/
    func getDocumentPath() -> String 
    {
        let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first
        return path!
    }
}

// MARK: - recorderDelegate
extension MTTSingletonManager:
AVAudioRecorderDelegate
{
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) 
    {
        
    }
    
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) 
    {
        
    }
}
