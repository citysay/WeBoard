//
//  SSFRecordViewController.swift
//  WeBoard
//
//  Created by 赛峰 施 on 2016/12/20.
//  Copyright © 2016年 赛峰 施. All rights reserved.
//

import UIKit

let DefaultUpdateWeBoardList = "DefaultUpdateWeBoardList"

class SSFRecordViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        canvasView.delegate = self
    }

    //MARK: Action
    
    @IBAction func backButtonPressed(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func colorButtonPressed(_ sender: UIButton) {
        switch sender.tag {
        case 100:
            canvasView.brushColor = UIColor.red
        case 101:
            canvasView.brushColor = UIColor.black
        case 102:
            canvasView.brushColor = UIColor.blue
        case 103:
            canvasView.brushWidth = 15.0
        case 104:
            canvasView.brushWidth = 10.0
        case 105:
            canvasView.brushWidth = 5.0
        default: break
        }
    }
    
    @IBAction func cameraButtonPressed(_ sender: UIButton) {
        presentImagePickerViewController(withSourceType: UIImagePickerControllerSourceType.camera)
    }
    
    @IBAction func photoButtonPressed(_ sender: UIButton) {
        presentImagePickerViewController(withSourceType: UIImagePickerControllerSourceType.photoLibrary)
    }
    
    @IBAction func backgroundImageButtonPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "showBackgroundCollectionViewController", sender: self)
    }
    
    @IBAction func revokeAStrokeButtonPressed(_ sender: UIButton) {
        
    }
    
    @IBAction func revokeAllButtonPressed(_ sender: UIButton) {
        clearAll()
    }
    
    @IBAction func startButtonPressed(_ sender: RoundButton) {
        sender.isSelected = !sender.isSelected
        
        if sender.isSelected,!SSFRecorder.sharedInstance.isRecording, SSFRecorder.sharedInstance.audioRecoder == nil {
            startRecord()
        } else if !sender.isSelected, SSFRecorder.sharedInstance.isRecording {
            pauseRecord()
            showActionSheet()
        }
    }
    
    //MARK: Methods
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier?.isEqual("showBackgroundCollectionViewController"))! {
            let vc = segue.destination as! SSFBackgroundCollectionViewController
            vc.delegate = self
        }
    }
    
    //MARK: Property
    
    @IBOutlet var canvasView: SSFCanvasView!
    
    @IBOutlet var timeLabel: UILabel!
    
    @IBOutlet var startButton: RoundButton!
    
    var timer: Timer?
    
    ///The drawing lines in recording
    var allRecordingDrawingLines: [SSFLine] = []
    
    ///The drawing lines before recording,it's used to background
    var allBackgroundDrawingLines: [SSFLine] = []
    
    ///The background image of start time
    var backgroundImage: UIImage?
    
    ///The small cover image of end time,then this image is used to display when listting all weboards
    var coverImage: UIImage?
    
    ///All points of a line which is drawing
    var pointsOfCurrentLine: [SSFPoint] = []
    
    ///All elements view which used to configure background
    var allElements: [SSFElementView] = []
    
    //MARK: Set to landscape
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.landscapeRight
    }
}

extension SSFRecordViewController {
    
    fileprivate func presentImagePickerViewController(withSourceType sourcetype: UIImagePickerControllerSourceType) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = sourcetype
        imagePickerController.allowsEditing = true
        imagePickerController.delegate = self
        imagePickerController.modalPresentationStyle = .popover
        
        if UIImagePickerController.isSourceTypeAvailable(sourcetype) {
            present(imagePickerController, animated: true, completion: nil)
        }
    }
    
    fileprivate func showActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        let resumeAction = UIAlertAction(title: "继续", style: UIAlertActionStyle.default) {  _ in
            self.startButton.isSelected = !self.startButton.isSelected
            self.resumeRecord()
        }
        let clearAction = UIAlertAction(title: "废弃", style: UIAlertActionStyle.default) { _ in
            self.clearAll()
        }
        let saveAction = UIAlertAction(title: "保存", style: UIAlertActionStyle.default) { _ in
            self.endAndSaveRecord()
        }
        alert.addAction(resumeAction)
        alert.addAction(clearAction)
        alert.addAction(saveAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: Recorder control
    
    fileprivate func startRecord() {
        //1.Crop the canvas view and use to draw backgroundimage
        backgroundImage = SSFScreenShot.screenShot(withView: canvasView)
        canvasView.drawBackground(withImage: (backgroundImage !! "crop backgroundImage fail"))
        allElements.forEach { $0.removeFromSuperview() }
        
        //2.start to record sound
        SSFRecorder.sharedInstance.startAudioRecord()
        
        //3.timelabel start to work
        startTimer()
    }
    
    fileprivate func pauseRecord() {
        SSFRecorder.sharedInstance.pauseAudioRecord()
        endTimer()
    }
    
    fileprivate func resumeRecord() {
        SSFRecorder.sharedInstance.resumeAudioRecorder()
        startTimer()
    }
    
    fileprivate func endAndSaveRecord() {
        coverImage = SSFScreenShot.screenShot(withView: canvasView)
        SSFRecorder.sharedInstance.endAndSave(penLines: allRecordingDrawingLines, backgroundImage: backgroundImage!, coverImage: coverImage!) { (isSaved, describition) in
            SwiftNotice.showNoticeWithText(.success, text: "保存成功", autoClear: true, autoClearTime: 2)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: DefaultUpdateWeBoardList), object: nil)
            self.perform(#selector(self.backButtonPressed), with: nil, afterDelay: 2.0)
        }
    }
    
    fileprivate func clearAll() {
        //1.clear canvas
        canvasView.drawBackground(withColor: UIColor.white)
        allRecordingDrawingLines = []
        allBackgroundDrawingLines = []
        pointsOfCurrentLine = []
        backgroundImage = nil
        coverImage = nil
        allElements.forEach { $0.removeFromSuperview() }
        allElements = []
        
        //2.clear audiorecorder
        SSFRecorder.sharedInstance.endAudioRecord()
        endTimer()
        
        //3.clear view
        timeLabel.text = "00:00"
        startButton.isSelected = false
    }
    
    // MARK: timer
    
    fileprivate func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timerFinished(timer:)), userInfo: nil, repeats: true)
    }
    
    fileprivate func endTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc fileprivate func timerFinished(timer: Timer) {
        self.timeLabel.text = SSFRecorder.sharedInstance.currentTime.timeFormatString()
    }
}

extension SSFRecordViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let image = info[UIImagePickerControllerEditedImage] else { picker.dismiss(animated: true, completion: nil); return}
        picker.dismiss(animated: true) { 
           self.addElement(image: image as! UIImage)
        }
    }
    
    private func addElement(image: UIImage) {
        let elementView = SSFElementView(image: image)
        allElements.append(elementView)
        self.canvasView.addSubview(elementView)
    }
}

extension SSFRecordViewController: SSFBackgroundCollectionViewControllerDelegate {
    func backgroundCollectionViewController(_ controller: SSFBackgroundCollectionViewController, didSelectColor color: UIColor) {
        self.canvasView.drawBackground(withColor: color)
    }
}

extension SSFRecordViewController: SSFCanvasViewDelegate {
    func canvasView(touchBeganAt point: CGPoint, withLineColor color: UIColor, withLineWidth width: Double, isStartOfLine isStart: Bool) {
        pointsOfCurrentLine = []
        let ssfPoint = SSFPoint(point: point, time: SSFRecorder.sharedInstance.currentTime, color: color, width: width, isStartOfLine: isStart)
        pointsOfCurrentLine.append(ssfPoint)
    }
    
    func canvasView(touchMoveAt point: CGPoint, withLineColor color: UIColor, withLineWidth width: Double, isStartOfLine isStart: Bool) {
        let ssfPoint = SSFPoint(point: point, time: SSFRecorder.sharedInstance.currentTime, color: color, width: width, isStartOfLine: isStart)
        pointsOfCurrentLine.append(ssfPoint)
    }
    
    func canvasView(touchEndAt point: CGPoint, withLineColor color: UIColor, withLineWidth width: Double, isStartOfLine isStart: Bool) {
        let ssfPoint = SSFPoint(point: point, time: SSFRecorder.sharedInstance.currentTime, color: color, width: width, isStartOfLine: isStart)
        pointsOfCurrentLine.append(ssfPoint)
        let currentLine = SSFLine(pointsOfLine: pointsOfCurrentLine, color: color, width: width)
        
        if SSFRecorder.sharedInstance.isRecording {
            allRecordingDrawingLines.append(currentLine)
        } else {
            allBackgroundDrawingLines.append(currentLine)
        }
    }
}