import Flutter
import UIKit

/// Factory for creating iOS 26 native loader platform views
class iOS26LoaderViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return iOS26LoaderPlatformView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Native iOS 26 loader with Liquid Glass card and activity indicator
class iOS26LoaderPlatformView: NSObject, FlutterPlatformView {
    private let _containerView: UIView
    private let _channel: FlutterMethodChannel
    private var isDark: Bool = false

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        _containerView = UIView(frame: frame)
        _containerView.backgroundColor = .clear

        _channel = FlutterMethodChannel(
            name: "adaptive_ui/ios26_loader_\(viewId)",
            binaryMessenger: messenger
        )

        var message: String?
        var indicatorColor: UIColor?

        if let params = args as? [String: Any] {
            isDark = params["isDark"] as? Bool ?? false
            message = params["message"] as? String
            if let argb = params["color"] as? Int {
                indicatorColor = UIColor(argb: argb)
            }
        }

        super.init()

        buildCard(message: message, indicatorColor: indicatorColor)

        if #available(iOS 13.0, *) {
            _containerView.overrideUserInterfaceStyle = isDark ? .dark : .light
        }

        _channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    func view() -> UIView {
        return _containerView
    }

    // MARK: - Private

    private func buildCard(message: String?, indicatorColor: UIColor?) {
        // Glass card — fills the platform view frame exactly so the Dart side
        // controls the card's outer size via the SizedBox that wraps UiKitView.
        let glassView: UIVisualEffectView
        if #available(iOS 26.0, *) {
            glassView = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            glassView = UIVisualEffectView(
                effect: UIBlurEffect(style: .systemUltraThinMaterial)
            )
        }
        glassView.layer.cornerRadius = 20
        glassView.clipsToBounds = true
        glassView.translatesAutoresizingMaskIntoConstraints = false
        _containerView.addSubview(glassView)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: _containerView.leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: _containerView.trailingAnchor),
            glassView.topAnchor.constraint(equalTo: _containerView.topAnchor),
            glassView.bottomAnchor.constraint(equalTo: _containerView.bottomAnchor),
        ])

        let contentView = glassView.contentView

        // Spinner
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        if let color = indicatorColor {
            indicator.color = color
        }
        indicator.startAnimating()
        contentView.addSubview(indicator)

        if let msg = message, !msg.isEmpty {
            // Spinner + label, stacked vertically, centered
            let label = UILabel()
            label.text = msg
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textAlignment = .center
            label.numberOfLines = 2
            label.translatesAutoresizingMaskIntoConstraints = false
            if #available(iOS 13.0, *) {
                label.textColor = .label
            } else {
                label.textColor = .black
            }
            contentView.addSubview(label)

            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                indicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),

                label.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 12),
                label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            ])
        } else {
            // Spinner only — centered
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ])
        }
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setBrightness":
            if let args = call.arguments as? [String: Any],
               let dark = args["isDark"] as? Bool {
                isDark = dark
                if #available(iOS 13.0, *) {
                    _containerView.overrideUserInterfaceStyle = dark ? .dark : .light
                }
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
