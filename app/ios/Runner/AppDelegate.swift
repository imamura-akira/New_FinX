import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// 界面提示音（P-01 欢迎页，design/theme.md 第 7 节）。保持强引用直到播放结束。
  private var uiSoundPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FinxUiSound") else { return }
    let channel = FlutterMethodChannel(name: "finx/ui_sound", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "play",
            let args = call.arguments as? [String: Any],
            let asset = args["asset"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.playUiSound(asset: asset) ?? false)
    }
  }

  /// .ambient：跟随系统静音开关（静音时不出声），并与其他 App 的音频混合、不打断用户正在播放的音乐。
  private func playUiSound(asset: String) -> Bool {
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    guard let path = Bundle.main.path(forResource: key, ofType: nil) else { return false }
    do {
      try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
      let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
      player.volume = 0.8
      player.prepareToPlay()
      player.play()
      uiSoundPlayer = player
      return true
    } catch {
      return false
    }
  }
}
