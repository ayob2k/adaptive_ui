import Flutter
import UIKit

// MARK: - Manager

/// Singleton that presents and dismisses native iOS 26 loader pop-ups.
///
/// Registered as a method-channel handler (not a platform view) so it can
/// present a real `UIViewController` over the Flutter root, giving the
/// `UIGlassEffect` full access to the native view hierarchy — the only way
/// to get the authentic Liquid Glass look.
///
/// Dart usage pattern:
///   initState  → channel.invokeMethod("show",    {id, message?, color?, isDark})
///   dispose    → channel.invokeMethod("dismiss", {id})
///   (if tapped through) native calls back: channel.invokeMethod("dismissed")
class iOS26LoaderManager: NSObject {

    static let shared = iOS26LoaderManager()
    private var activeLoaders: [Int: iOS26LoaderViewController] = [:]
    private var channel: FlutterMethodChannel?

    private override init() { super.init() }

    func setup(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "adaptive_ui/ios26_loader_manager",
            binaryMessenger: messenger
        )
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
    }

    // MARK: Method call dispatch

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let id   = args["id"] as? Int ?? 0

        switch call.method {
        case "show":
            show(id: id, params: args)
            result(nil)
        case "dismiss":
            dismiss(id: id, animated: true)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: Show

    private func show(id: Int, params: [String: Any]) {
        let message  = params["message"]  as? String
        let isDark   = params["isDark"]   as? Bool ?? false
        let color: UIColor? = {
            guard let argb = params["color"] as? Int else { return nil }
            return UIColor(argb: argb)
        }()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let topVC = self.topViewController() else { return }

            // Dismiss any existing loader with the same id first.
            if let existing = self.activeLoaders[id] {
                existing.dismiss(animated: false)
            }

            let loaderVC = iOS26LoaderViewController(
                message: message,
                isDark: isDark,
                indicatorColor: color
            )

            // Present transparently so Flutter's barrier shows through.
            loaderVC.modalPresentationStyle = .overCurrentContext
            loaderVC.modalTransitionStyle   = .crossDissolve
            topVC.present(loaderVC, animated: true)
            self.activeLoaders[id] = loaderVC
        }
    }

    // MARK: Dismiss

    func dismiss(id: Int, animated: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let vc = self.activeLoaders[id] else { return }
            vc.dismiss(animated: animated)
            self.activeLoaders.removeValue(forKey: id)
        }
    }

    // MARK: Helpers

    private func topViewController() -> UIViewController? {
        guard let scene  = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

// MARK: - View Controller

/// A transparent UIViewController that hosts the Liquid Glass loader card.
///
/// It is presented with `.overCurrentContext` so the Flutter content (including
/// any barrier rendered by Flutter's dialog system) remains visible through the
/// clear background. The glass card itself uses `UIGlassEffect` on iOS 26+ for
/// the authentic Liquid Glass look, falling back to a material blur on earlier
/// versions.
class iOS26LoaderViewController: UIViewController {

    private let message: String?
    private let isDark: Bool
    private let indicatorColor: UIColor?

    init(message: String?, isDark: Bool, indicatorColor: UIColor?) {
        self.message        = message
        self.isDark         = isDark
        self.indicatorColor = indicatorColor
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildCard()
    }

    // MARK: Card construction

    private func buildCard() {
        // ── Glass container ─────────────────────────────────────────────────
        let glassView: UIVisualEffectView
        if #available(iOS 26.0, *) {
            glassView = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            glassView = UIVisualEffectView(
                effect: UIBlurEffect(style: isDark
                    ? .systemThinMaterialDark
                    : .systemThinMaterialLight)
            )
        }
        glassView.layer.cornerRadius = 24
        glassView.clipsToBounds = true
        glassView.translatesAutoresizingMaskIntoConstraints = false

        // Subtle specular border that enhances the glass look
        glassView.layer.borderWidth = 0.5
        glassView.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor

        view.addSubview(glassView)

        // ── Activity indicator ───────────────────────────────────────────────
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        if let color = indicatorColor { indicator.color = color }
        indicator.startAnimating()

        let contentView = glassView.contentView
        contentView.addSubview(indicator)

        if let msg = message, !msg.isEmpty {
            // Spinner + label ------------------------------------------------
            let label = UILabel()
            label.text = msg
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textAlignment = .center
            label.numberOfLines = 2
            label.translatesAutoresizingMaskIntoConstraints = false
            if #available(iOS 13.0, *) {
                label.textColor = .label
            } else {
                label.textColor = isDark ? .white : .black
            }
            contentView.addSubview(label)

            NSLayoutConstraint.activate([
                // Glass card — fixed width, content-driven height
                glassView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                glassView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                glassView.widthAnchor.constraint(equalToConstant: 128),

                indicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
                indicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

                label.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 14),
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28),
            ])
        } else {
            // Spinner only ----------------------------------------------------
            NSLayoutConstraint.activate([
                // Square glass card sized around the large spinner (40 pt) + padding
                glassView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                glassView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                glassView.widthAnchor.constraint(equalToConstant: 88),
                glassView.heightAnchor.constraint(equalToConstant: 88),

                indicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ])
        }

        // Respect brightness override
        if #available(iOS 13.0, *) {
            view.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
    }
}
