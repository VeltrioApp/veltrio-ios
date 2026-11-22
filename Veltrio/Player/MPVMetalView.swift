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
    private var started = false
    private var lastResetSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        // Cap Metal backing scale at 2x on 3x phones: cuts MoltenVK fragment
        // shading work by >50% with no visible loss on a phone screen.
        metalLayer.contentsScale = min(UIScreen.main.nativeScale, 2.0)
        metalLayer.framebufferOnly = true
        metalLayer.maximumDrawableCount = 3
        metalLayer.presentsWithTransaction = false
        metalLayer.backgroundColor = UIColor.black.cgColor
        layer.addSublayer(metalLayer)

        // Sound even with the silent switch on, as any video player.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foreground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func startEngineIfNeeded() {
        guard !started else { return }
        started = true
        var surface = metalLayer
        engine.start { mpv in
            mpv_set_option(mpv, "wid", MPV_FORMAT_INT64, &surface)
            _ = mpv_set_option_string(mpv, "vo", "gpu-next")
            _ = mpv_set_option_string(mpv, "gpu-api", "vulkan")
            _ = mpv_set_option_string(mpv, "gpu-context", "moltenvk")
            _ = mpv_set_option_string(mpv, "hwdec", "videotoolbox")
            _ = mpv_set_option_string(mpv, "hwdec-codecs", "all")
            _ = mpv_set_option_string(mpv, "vulkan-async-transfer", "yes")
            _ = mpv_set_option_string(mpv, "vulkan-async-compute", "yes")
            _ = mpv_set_option_string(mpv, "profile", "fast")
            _ = mpv_set_option_string(mpv, "scale", "bilinear")
            _ = mpv_set_option_string(mpv, "dscale", "bilinear")
            _ = mpv_set_option_string(mpv, "cscale", "bilinear")
            _ = mpv_set_option_string(mpv, "dither", "no")
            _ = mpv_set_option_string(mpv, "deband", "no")
            _ = mpv_set_option_string(mpv, "hdr-compute-peak", "no")
            _ = mpv_set_option_string(mpv, "deinterlace", "no")
            _ = mpv_set_option_string(mpv, "framedrop", "vo")
            _ = mpv_set_option_string(mpv, "video-sync", "audio")
            _ = mpv_set_option_string(mpv, "interpolation", "no")
            _ = mpv_set_option_string(mpv, "vd-lavc-threads", "0")
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1, bounds.height > 1 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        metalLayer.frame = bounds
        let scale = metalLayer.contentsScale
        let size = CGSize(width: floor(bounds.width * scale), height: floor(bounds.height * scale))
        if abs(metalLayer.drawableSize.width - size.width) > 0.5 || abs(metalLayer.drawableSize.height - size.height) > 0.5 {
            metalLayer.drawableSize = size
        }
        CATransaction.commit()

        if !started {
            lastResetSize = size
            startEngineIfNeeded()
        } else if abs(lastResetSize.width - size.width) > 4 || abs(lastResetSize.height - size.height) > 4 {
            lastResetSize = size
            scheduleVideoReset()
        }
    }

    /// mpv's MoltenVK context only sizes its swapchain when the video
    /// output starts, so a rotation restarts the video output once the
    /// layout settles.
    private var resetTask: Task<Void, Never>?
    private func scheduleVideoReset() {
        resetTask?.cancel()
        resetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, !Task.isCancelled,
                  UIApplication.shared.applicationState != .background else { return }
            engine.setVideoEnabled(false)
            engine.setVideoEnabled(true)
        }
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
