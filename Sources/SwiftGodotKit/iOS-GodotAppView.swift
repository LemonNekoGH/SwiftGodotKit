import OSLog
import SwiftUI
import SwiftGodot
import UIKit
import apple_embedded_runtime_bridge

#if os(iOS)
public struct GodotAppView: UIViewRepresentable {
    @SwiftUI.Environment(\.godotApp) var app: GodotApp?
    var view = UIGodotAppView(frame: .zero)
    let source: String?
    let scene: String?
    let onReady: ((GodotAppViewHandle) -> Void)?
    let onMessage: ((VariantDictionary) -> Void)?

    public init(
        source: String? = nil,
        scene: String? = nil,
        onReady: ((GodotAppViewHandle) -> Void)? = nil,
        onMessage: ((VariantDictionary) -> Void)? = nil
    ) {
        self.source = source
        self.scene = scene
        self.onReady = onReady
        self.onMessage = onMessage
    }

    public func makeUIView(context: Context) -> UIGodotAppView {
        guard let app else {
            Logger.App.error("No GodotApp instance, you must pass it on the environment using \\.godotApp")
            return view
        }

        view.app = app
        view.source = source
        view.scene = scene
        view.onReady = onReady
        view.onMessage = onMessage
        view.syncCallbackRegistration()

        app.configureLaunch(source: source, scene: scene)
        _ = app.start()
        return view
    }

    public func updateUIView(_ uiView: UIGodotAppView, context: Context) {
        guard let app else { return }
        app.configureLaunch(source: source, scene: scene)
        uiView.app = app
        uiView.source = source
        uiView.scene = scene
        uiView.onReady = onReady
        uiView.onMessage = onMessage
        uiView.syncCallbackRegistration()
        uiView.startGodotInstance()
    }
}

typealias TTGodotAppView = UIGodotAppView
typealias TTGodotWindow = UIGodotWindow

public final class GodotHostApplicationDelegate: NSObject, UIApplicationDelegate {
    @objc public var window: UIWindow? {
        get {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.flatMap(\.windows).first
        }
        set {}
    }
}

public final class UIGodotAppView: UIView {
    private var hostedController: UIViewController?
    private var readinessDisplayLink: CADisplayLink?
    private var callbackToken: UUID?
    private weak var callbackApp: GodotApp?
    private var isRendering = false

    public var app: GodotApp?
    public var source: String?
    public var scene: String?
    public var onReady: ((GodotAppViewHandle) -> Void)?
    public var onMessage: ((VariantDictionary) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        clipsToBounds = true
    }

    deinit {
        teardownHostedController()
        unregisterCallbacks()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        hostedController?.view.frame = bounds
    }

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview == nil {
            teardownHostedController()
            return
        }
        startGodotInstance()
    }

    func startGodotInstance() {
        syncCallbackRegistration()
        guard let app else { return }
        guard ensureHostedController() != nil else {
            Logger.App.error("startGodotInstance: failed to create hosted iOS Godot view controller")
            return
        }
        guard app.instance != nil || app.start() else {
            app.queueStart(self)
            return
        }

        app.setHostedRenderLoopActive(true)
        syncRenderingState()
        ensureReadinessPolling()
        app.pollBridgeAndReadiness()
    }

    @objc
    private func pollRuntimeState() {
        guard let app else { return }
        app.setHostedRenderLoopActive(true)
        syncRenderingState()
        app.pollBridgeAndReadiness()
    }
}

private extension UIGodotAppView {
    @discardableResult
    func ensureHostedController() -> UIViewController? {
        if let hostedController {
            if hostedController.view.superview !== self {
                attachHostedView(hostedController)
            }
            return hostedController
        }

        guard let controller = SGKCreateAndRegisterGodotViewController() else {
            return nil
        }
        hostedController = controller
        attachHostedView(controller)
        return controller
    }

    func attachHostedView(_ controller: UIViewController) {
        let hostedView = controller.view
        hostedView?.frame = bounds
        hostedView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if hostedView?.superview !== self, let hostedView {
            addSubview(hostedView)
        }
    }

    func teardownHostedController() {
        readinessDisplayLink?.invalidate()
        readinessDisplayLink = nil

        if let hostedController {
            SGKStopGodotViewRendering(hostedController)
            hostedController.view.removeFromSuperview()
        }
        hostedController = nil
        isRendering = false
        app?.setHostedRenderLoopActive(false)
    }

    func ensureReadinessPolling() {
        guard readinessDisplayLink == nil else { return }
        let displayLink = CADisplayLink(target: self, selector: #selector(pollRuntimeState))
        displayLink.add(to: .main, forMode: .common)
        readinessDisplayLink = displayLink
    }

    func syncRenderingState() {
        guard let hostedController, let app else { return }
        let shouldRender = !app.isPaused && app.isDrawing
        guard shouldRender != isRendering else { return }
        if shouldRender {
            SGKStartGodotViewRendering(hostedController)
        } else {
            SGKStopGodotViewRendering(hostedController)
        }
        isRendering = shouldRender
    }

    func syncCallbackRegistration() {
        guard let app else { return }

        if callbackApp !== app {
            unregisterCallbacks()
            callbackApp = app
        }

        if callbackToken == nil {
            let token = app.registerViewCallbacks(
                handle: GodotAppViewHandle(app: app),
                onReady: { [weak self] handle in
                    self?.onReady?(handle)
                },
                onMessage: { [weak self] message in
                    self?.onMessage?(message)
                }
            )
            callbackToken = token
        }
    }

    func unregisterCallbacks() {
        callbackApp?.unregisterViewCallbacks(id: callbackToken)
        callbackToken = nil
        callbackApp = nil
    }
}
#endif
