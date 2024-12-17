import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let alarmChannel = FlutterMethodChannel(name: "com.telalarm.wakeupcall", binaryMessenger: controller.binaryMessenger)

        alarmChannel.setMethodCallHandler { (call, result) in
            if call.method == "playAlarmSound" {
                self.playAlarmSound()
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func playAlarmSound() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)

            if let soundUrl = Bundle.main.url(forResource: "alarm_sound", withExtension: "mp3") {
                var audioPlayer: AVAudioPlayer?
                audioPlayer = try AVAudioPlayer(contentsOf: soundUrl)
                audioPlayer?.play()
            }
        } catch {
            print("Failed to play alarm sound: \(error)")
        }
    }
}
