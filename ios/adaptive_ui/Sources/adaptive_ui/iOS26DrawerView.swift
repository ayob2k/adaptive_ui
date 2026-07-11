import Flutter
import UIKit

// MARK: - DrawerGlassView

/// The native UIView that provides the iOS 26 Liquid Glass appearance for the drawer.
/// Layers (bottom → top):
///   1. UIVisualEffectView  — live blur (UIKit reads from whatever is behind the window)
///   2. Optional tint layer — colour overlay at low opacity
///   3. Specular gradient   — top highlight for the "glossy" sheen
///   4. Right-edge hairline — glass panel separator
private class DrawerGlassView: UIView {

    private let blurView: UIVisualEffectView
    private let specularLayer: CAGradientLayer
    private var tintView: UIView?
    private let separatorView: UIView

    // MARK: Dynamic properties

    var isDark: Bool = false {
        didSet { guard isDark != oldValue else { return }; applyTheme() }
    }

    var blurStyleName: String = "systemUltraThinMaterial" {
        didSet {
            guard blurStyleName != oldValue else { return }
            blurView.effect = UIBlurEffect(style: DrawerGlassView.parseBlurStyle(blurStyleName))
        }
    }

    var glassTintColor: UIColor? {
        didSet { applyTint() }
    }

    // MARK: Init

    init(frame: CGRect, isDark: Bool, blurStyleName: String, tintColor: UIColor?) {
        self.isDark = isDark
        self.blurStyleName = blurStyleName
        self.glassTintColor = tintColor

        blurView = UIVisualEffectView(effect: UIBlurEffect(style: DrawerGlassView.parseBlurStyle(blurStyleName)))
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if #available(iOS 13.0, *) {
            blurView.overrideUserInterfaceStyle = isDark ? .dark : .light
        }

        specularLayer = CAGradientLayer()
        specularLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        specularLayer.endPoint   = CGPoint(x: 0.5, y: 0.6)
        specularLayer.locations  = [0.0, 0.25, 0.7, 1.0]

        separatorView = UIView()
        separatorView.autoresizingMask = [.flexibleHeight, .flexibleLeftMargin]

        super.init(frame: frame)
        backgroundColor = .clear

        addSubview(blurView)
        layer.addSublayer(specularLayer)
        addSubview(separatorView)

        applyTint()
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        blurView.frame = bounds
        tintView?.frame = bounds
        specularLayer.frame = bounds
        separatorView.frame = CGRect(x: bounds.maxX - 0.5, y: 0, width: 0.5, height: bounds.height)
    }

    // MARK: Appearance

    private func applyTheme() {
        if #available(iOS 13.0, *) {
            blurView.overrideUserInterfaceStyle = isDark ? .dark : .light
        }

        // In light mode the specular is very bright (iOS 26 glossy glass).
        // In dark mode it is subtler so it doesn't look washed out.
        specularLayer.colors = isDark
            ? [
                UIColor.white.withAlphaComponent(0.12).cgColor,
                UIColor.white.withAlphaComponent(0.05).cgColor,
                UIColor.white.withAlphaComponent(0.01).cgColor,
                UIColor.clear.cgColor,
              ]
            : [
                UIColor.white.withAlphaComponent(0.45).cgColor,
                UIColor.white.withAlphaComponent(0.18).cgColor,
                UIColor.white.withAlphaComponent(0.04).cgColor,
                UIColor.clear.cgColor,
              ]

        separatorView.backgroundColor = isDark
            ? UIColor.white.withAlphaComponent(0.20)
            : UIColor.white.withAlphaComponent(0.65)
    }

    private func applyTint() {
        tintView?.removeFromSuperview()
        tintView = nil

        guard let tc = glassTintColor else { return }
        let tv = UIView(frame: bounds)
        tv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tv.backgroundColor = tc.withAlphaComponent(0.18)
        insertSubview(tv, aboveSubview: blurView)
        tintView = tv
    }

    // MARK: Blur style parsing

    static func parseBlurStyle(_ name: String) -> UIBlurEffect.Style {
        if #available(iOS 13.0, *) {
            switch name {
            case "systemUltraThinMaterial":  return .systemUltraThinMaterial
            case "systemThinMaterial":        return .systemThinMaterial
            case "systemMaterial":            return .systemMaterial
            case "systemThickMaterial":       return .systemThickMaterial
            case "systemChromeMaterial":      return .systemChromeMaterial
            default:                          return .systemUltraThinMaterial
            }
        }
        return .light
    }
}

// MARK: - iOS26DrawerPlatformView

/// Flutter platform view that wraps DrawerGlassView and owns the method channel.
class iOS26DrawerPlatformView: NSObject, FlutterPlatformView {

    private let glassView: DrawerGlassView
    private let channel: FlutterMethodChannel

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "adaptive_ui/ios26_drawer_\(viewId)",
            binaryMessenger: messenger
        )

        var isDark = false
        var blurStyleName = "systemUltraThinMaterial"
        var tintColor: UIColor? = nil

        if let dict = args as? [String: Any] {
            isDark = dict["isDark"] as? Bool ?? false
            if let styleName = dict["blurStyle"] as? String { blurStyleName = styleName }
            if let tint = dict["tintColor"] as? NSNumber { tintColor = UIColor(argb: tint.intValue) }
        }

        glassView = DrawerGlassView(
            frame: frame,
            isDark: isDark,
            blurStyleName: blurStyleName,
            tintColor: tintColor
        )

        super.init()

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    func view() -> UIView { glassView }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(nil); return
        }
        switch call.method {
        case "setBrightness":
            if let dark = args["isDark"] as? Bool { glassView.isDark = dark }
            result(nil)
        case "setBlurStyle":
            if let name = args["blurStyle"] as? String { glassView.blurStyleName = name }
            result(nil)
        case "setTintColor":
            if let tint = args["tintColor"] as? NSNumber {
                glassView.glassTintColor = UIColor(argb: tint.intValue)
            } else {
                glassView.glassTintColor = nil
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - iOS26DrawerViewFactory

/// Factory that vends iOS26DrawerPlatformView instances.
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
