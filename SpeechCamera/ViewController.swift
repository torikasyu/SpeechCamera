//
//  ViewController.swift
//  SpeechCamera
//
//  Created by TANAKAHiroki on 2017/01/13.
//  Copyright © 2017年 torikasyu. All rights reserved.
//

import UIKit
import AVFoundation
import Speech

class ViewController: UIViewController,AVCapturePhotoCaptureDelegate,SFSpeechRecognizerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var btnShootOutlet: UIButton!
    @IBOutlet weak var viewCamera: UIView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var textView: UITextView!

    private var imageOutput:AVCapturePhotoOutput?
    // for speech
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @IBAction func btnShoot(_ sender: Any) {
        self.shoot()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Inputを作成
        var audioInput: AVCaptureInput?
        //let device = AVCaptureDevice.devices().filter { ($0 as AnyObject).position == .back }.first as! AVCaptureDevice?
        let device = AVCaptureDeviceDiscoverySession(deviceTypes: [AVCaptureDeviceType.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: AVCaptureDevicePosition.back)
        
        do {
            audioInput = try AVCaptureDeviceInput(device: device?.devices[0])
        } catch {}
        
        // Outputを作成
        imageOutput = AVCapturePhotoOutput()
        imageOutput?.isHighResolutionCaptureEnabled = true
        
        // セッションを作成と起動
        let session = AVCaptureSession()
        session.addInput(audioInput!)
        session.addOutput(imageOutput)
        session.startRunning()
        
        // カメラの映像を画面に表示する為のレイヤー作成
        let myVideoLayer = AVCaptureVideoPreviewLayer(session: session)
        
        //let rect = CGRect(x:0,y:0,width:self.view.bounds.width/2,height:self.view.bounds.height/2)
        //myVideoLayer?.frame = rect
        myVideoLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        //myVideoLayer?.position = CGPoint(x: self.cameraView.frame.width / 2, y: self.cameraView.frame.height / 2)

        myVideoLayer?.bounds = viewCamera.frame
        self.viewCamera.layer.addSublayer(myVideoLayer!)
        
        // for speech
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            /*
             The callback may not be called on the main thread. Add an
             operation to the main queue to update the record button's state.
             */
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }
    }
    
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                //let rec = result.bestTranscription.formattedString
                
                if let t = result.bestTranscription.segments.last?.substring {
                    self.textView.text = t
                }
                isFinal = result.isFinal

                if (result.bestTranscription.segments.last?.substring.lowercased() == "チーズ")
                //if(rec == "チーズ")
                {
                    self.shoot()
                }
                
            }
            
            if error != nil || isFinal {
                
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        try audioEngine.start()
        
        textView.text = "(Go ahead, I'm listening)"
    }

    // MARK: SFSpeechRecognizerDelegate
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition not available", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            try! startRecording()
            recordButton.setTitle("Stop recording", for: [])
        }
    }
    
    func shoot()
    {
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        settings.flashMode = .off
        imageOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        // do something
        if let photoSampleBuffer = photoSampleBuffer {
            // JPEG形式で画像データを取得
            let photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
            let image = UIImage(data: photoData!)
            
            //let image = UIImageFromCMSamleBuffer(buffer: photoSampleBuffer!)
            self.imageView.image = image
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

