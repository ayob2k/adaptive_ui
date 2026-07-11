import Flutter
import UIKit

/// A UIView subclass that renders the iOS 26 Liquid Glass background for
/// the adaptive drawer: native UIVisualEffectView blur, a specular highlight
/// gradient, and a right-edge separator line.
private class DrawerGlassView: UIView {

    private let blurView: UIVisualEffectView
    private let specularLayer: CAGradientLayer
    private let separatorView: UIView

    var isDark: Bool = false {
        didSet { updateAppearance() }
    }

    init(frame: CGRect, isDark: Bool) {
        self.isDark = isDark

        // Blur background (UIVisualEffectView — the core of Liquid Glass)
        blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if #available(iOS 13.0, *) {
            blurView.overrideUserInterfaceStyle = isDark ? .dark : .light
        }

        // Specular highlight gradient layer (top-heavy, glossy feel)
        specularLayer = CAGradientLayer()
        specularLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        specularLayer.endPoint   = CGPoint(x: 0.5, y: 0.65)
        specularLayer.locations  = [0.0, 0.35, 1.0]

        // Right-edge separator — mimics the glass panel edge
        separatorView = UIView()
        separatorView.autoresizingMask = [.flexibleHeight, .flexibleLeftMargin]

        super.init(frame: frame)
        backgroundColor = .clear

        addSubview(blurView)
        layer.addSublayer(specularLayer)
        addSubview(separatorView)

        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        blurView.frame = bounds
        specularLayer.frame = bounds
        separatorView.frame = CGRect(
            x: bounds.maxX - 0.5,
            y: 0,
            width: 0.5,
            height: bounds.height
        )
    }

    private func updateAppearance() {
        // Update blur darkness
        if #available(iOS 13.0, *) {
            blurView.overrideUserInterfaceStyle = isDark ? .dark : .light
        }

        // Specular colours: stronger in light mode, subtle in dark mode
        specularLayer.colors = isDark
            ? [
                UIColor.white.withAlphaComponent(0.07).cgColor,
                UIColor.white.withAlphaComponent(0.025).cgColor,
                UIColor.clear.cgColor,
              ]
            : [
                UIColor.white.withAlphaComponent(0.26).cgColor,
                UIColor.white.withAlphaComponent(0.09).cgColor,
                UIColor.clear.cgColor,
              ]

        // Separator line — bright in light mode, softly visible in dark mode
        separatorView.backgroundColor = isDark
            ? UIColor.white.withAlphaComponent(0.18)
            : UIColor.white.withAlphaComponent(0.62)
    }
}

// MARK: - FlutterPlatformView

/// Platform view that wraps DrawerGlassView and handles the Flutter method channel.
class iOS26DrawerPlatformView: NSObject, FlutterPlatformView {

    private let glassView: DrawerGlassView
    private let channel: FlutterMethodChannel

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "adaptive_ui/ios26_drawer_\(viewId)",
            binaryMessenger: messenger
        )

        var isDark = false
        if let dict = args as? [String: Any] {
            isDark = dict["isDark"] as? Bool ?? false
        }

        glassView = DrawerGlassView(frame: frame, isDark: isDark)

        super.init()

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    func view() -> UIView { glassView }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setBrightness":
            if let args = call.arguments as? [String: Any],
               let dark = args["isDark"] as? Bool {
                glassView.isDark = dark
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - FlutterPlatformViewFactory

/// Factory that creates iOS26DrawerPlatformView instances.
class iOS26DrawerViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return iOS26DrawerPlatformView(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
