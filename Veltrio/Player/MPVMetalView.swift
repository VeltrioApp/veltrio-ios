import SwiftUI
import UIKit
import AVFoundation
import Libmpv

/// SwiftUI view backed by libmpv, as on macOS (same API): the engine from
/// VeltrioKit, drawn into a Metal layer mpv renders to itself
/// (vo=gpu-next through MoltenVK, VideoToolbox decoding).
struct MPVPlayer: UIViewRepresentable {
    let url: URL
    let controller: PlayerController

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MPVMetalView {
        let view = MPVMetalView()
        view.engine.controller = controller
        controller.view = view.engine
        view.engine.load(url: url.absoluteString)
        context.coordinator.lastURL = url.absoluteString
        return view
    }

    func updateUIView(_ view: MPVMetalView, context: Context) {
        if context.coordinator.lastURL != url.absoluteString {
            view.engine.load(url: url.absoluteString)
            context.coordinator.lastURL = url.absoluteString
        }
    }

    static func dismantleUIView(_ view: MPVMetalView, coordinator: Coordinator) {
        view.engine.shutdown()
    }

    final class Coordinator {
        var lastURL: String?
    }
}

/// The video surface on iOS.
final class MPVMetalView: UIView {
    let engine = MPVEngine()
    private let metalLayer = MetalLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        metalLayer.contentsScale = UIScreen.main.nativeScale
        metalLayer.framebufferOnly = true
        metalLayer.backgroundColor = UIColor.black.cgColor
        layer.addSublayer(metalLayer)

        // Sound even with the silent switch on, as any video player.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        var surface = metalLayer
        engine.start { mpv in
            mpv_set_option(mpv, "wid", MPV_FORMAT_INT64, &surface)
            _ = mpv_set_option_string(mpv, "vo", "gpu-next")
            _ = mpv_set_option_string(mpv, "gpu-api", "vulkan")
            _ = mpv_set_option_string(mpv, "gpu-context", "moltenvk")
            _ = mpv_set_option_string(mpv, "hwdec", "videotoolbox")
        }
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foreground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        metalLayer.frame = bounds
        CATransaction.commit()
    }

    // In the background there is nothing to draw on: paused, video off,
    // then back on return (else the picture stays black).
    @objc private func background() {
        engine.controller?.setPaused(true)
        engine.setVideoEnabled(false)
    }

    @objc private func foreground() {
        engine.setVideoEnabled(true)
    }
}

/// MoltenVK sometimes sets a 1×1 drawable to force a presentation, which
/// flickers and can stick; such sizes are ignored (as in MPVKit's demo).
final class MetalLayer: CAMetalLayer {
    override var drawableSize: CGSize {
        get { super.drawableSize }
        set { if Int(newValue.width) > 1 && Int(newValue.height) > 1 { super.drawableSize = newValue } }
    }
}
