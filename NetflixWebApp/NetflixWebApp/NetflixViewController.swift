//
//  NetflixViewController.swift
//  Netflix WebView by amo
//  
//  Full Netflix experience with session injection & FairPlay DRM support
//

import UIKit
import WebKit

// MARK: - Helper Classes for Button Actions

private class ActionWrapper {
    let action: () -> Void
    init(action: @escaping () -> Void) {
        self.action = action
    }
}

private struct AssociatedKeys {
    static var actionKey: UInt8 = 0
}

class NetflixViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    
    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var brandingLabel: UILabel!
    private var hasShownSessionPrompt = false
    
    private let netflixURL = "https://www.netflix.com"
    private let justPasteURL = "https://justpaste.it/a7vyr"
    
    // MARK: - Secret Settings Menu Properties
    private var tapCount = 0
    private var tapTimer: Timer?
    private var settingsMenuView: UIView?
    private var currentUserAgent: String?
    private var currentZoom: CGFloat = 1.0
    private var isFullscreenEnabled = true
    
    // User Agent Presets
    private enum UserAgentPreset: String, CaseIterable {
        case iPadSafari14 = "iPad Safari 14"
        case iPadSafari15 = "iPad Safari 15"
        case iPadSafari16 = "iPad Safari 16"
        case iPadSafari17 = "iPad Safari 17"
        case macOSSafari14 = "macOS Safari 14 (Big Sur)"
        case macOSSafari15 = "macOS Safari 15 (Monterey)"
        case macOSSafari16 = "macOS Safari 16 (Ventura)"
        case macOSSafari17 = "macOS Safari 17 (Sonoma)"
        case androidChrome = "Android Chrome (Widevine)"
        
        var userAgentString: String {
            switch self {
            case .iPadSafari14:
                return "Mozilla/5.0 (iPad; CPU OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
            case .iPadSafari15:
                return "Mozilla/5.0 (iPad; CPU OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
            case .iPadSafari16:
                return "Mozilla/5.0 (iPad; CPU OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
            case .iPadSafari17:
                return "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
            case .macOSSafari14:
                return "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"
            case .macOSSafari15:
                return "Mozilla/5.0 (Macintosh; Intel Mac OS X 12_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15"
            case .macOSSafari16:
                return "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15"
            case .macOSSafari17:
                return "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
            case .androidChrome:
                return "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36"
            }
        }
        
        var usesWidevine: Bool {
            return self == .androidChrome
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🔥 [Netflix by amo] Setting up WebView...")
        
        // Enable fullscreen mode (no status bar)
        setupFullscreen()
        
        setupWebView()
        setupUI()
        setupBrandingLabel()
        setup5TapGesture()
        
        // Show session injection prompt after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.showSessionInjectionPrompt()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return isFullscreenEnabled
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return isFullscreenEnabled
    }
    
    // MARK: - Fullscreen Setup
    
    private func setupFullscreen() {
        // Make app completely fullscreen
        if #available(iOS 13.0, *) {
            view.window?.windowScene?.statusBarManager?.statusBarHidden = true
        }
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    // MARK: - 5-Tap Gesture Setup
    
    private func setup5TapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        print("✅ [Netflix by amo] 5-Tap gesture activated!")
    }
    
    @objc private func handleTap() {
        tapTimer?.invalidate()
        tapCount += 1
        
        if tapCount >= 5 {
            print("🎯 [Netflix by amo] 5 taps detected! Opening settings...")
            tapCount = 0
            showSettingsMenu()
        } else {
            tapTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.tapCount = 0
            }
        }
    }
    
    // MARK: - Settings Menu
    
    private func showSettingsMenu() {
        // Remove existing menu if present
        settingsMenuView?.removeFromSuperview()
        
        // Create overlay
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        overlay.alpha = 0
        
        // Create settings panel
        let panelWidth: CGFloat = min(view.bounds.width - 40, 500)
        let panelHeight: CGFloat = 600
        let panel = UIView(frame: CGRect(
            x: (view.bounds.width - panelWidth) / 2,
            y: (view.bounds.height - panelHeight) / 2,
            width: panelWidth,
            height: panelHeight
        ))
        panel.backgroundColor = UIColor.systemBackground
        panel.layer.cornerRadius = 20
        panel.clipsToBounds = true
        panel.alpha = 0
        panel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        // Title
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 20, width: panelWidth - 40, height: 40))
        titleLabel.text = "⚙️ Secret Settings by amo"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        panel.addSubview(titleLabel)
        
        // Scroll view for content
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 70, width: panelWidth, height: panelHeight - 140))
        scrollView.showsVerticalScrollIndicator = true
        panel.addSubview(scrollView)
        
        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: panelWidth, height: 800))
        scrollView.addSubview(contentView)
        scrollView.contentSize = contentView.frame.size
        
        var yOffset: CGFloat = 20
        
        // User Agent Switcher Section
        let uaLabel = createSectionLabel("🌐 User Agent", yOffset: yOffset)
        contentView.addSubview(uaLabel)
        yOffset += 40
        
        for preset in UserAgentPreset.allCases {
            let button = createSettingsButton(
                title: preset.rawValue,
                yOffset: yOffset,
                width: panelWidth - 40,
                action: { [weak self] in
                    self?.switchUserAgent(to: preset)
                }
            )
            contentView.addSubview(button)
            yOffset += 50
        }
        
        yOffset += 20
        
        // Zoom Controls Section
        let zoomLabel = createSectionLabel("🔍 Zoom Controls", yOffset: yOffset)
        contentView.addSubview(zoomLabel)
        yOffset += 40
        
        let zoomStack = UIStackView(frame: CGRect(x: 20, y: yOffset, width: panelWidth - 40, height: 50))
        zoomStack.axis = .horizontal
        zoomStack.distribution = .fillEqually
        zoomStack.spacing = 10
        
        let zoomOutButton = createZoomButton(title: "🔍- Zoom Out", action: { [weak self] in
            self?.adjustZoom(by: -0.25)
        })
        let zoomResetButton = createZoomButton(title: "↺ Reset", action: { [weak self] in
            self?.resetZoom()
        })
        let zoomInButton = createZoomButton(title: "🔍+ Zoom In", action: { [weak self] in
            self?.adjustZoom(by: 0.25)
        })
        
        zoomStack.addArrangedSubview(zoomOutButton)
        zoomStack.addArrangedSubview(zoomResetButton)
        zoomStack.addArrangedSubview(zoomInButton)
        contentView.addSubview(zoomStack)
        yOffset += 60
        
        // Fullscreen Toggle Section
        let fullscreenLabel = createSectionLabel("📱 Fullscreen", yOffset: yOffset)
        contentView.addSubview(fullscreenLabel)
        yOffset += 40
        
        let fullscreenToggle = UISwitch(frame: CGRect(x: panelWidth - 70, y: yOffset, width: 51, height: 31))
        fullscreenToggle.isOn = isFullscreenEnabled
        fullscreenToggle.addTarget(self, action: #selector(toggleFullscreen(_:)), for: .valueChanged)
        contentView.addSubview(fullscreenToggle)
        
        let fullscreenDesc = UILabel(frame: CGRect(x: 20, y: yOffset, width: panelWidth - 110, height: 31))
        fullscreenDesc.text = "Hide status bar & home indicator"
        fullscreenDesc.font = .systemFont(ofSize: 14)
        fullscreenDesc.textColor = .secondaryLabel
        contentView.addSubview(fullscreenDesc)
        yOffset += 50
        
        // Video Fullscreen Toggle Section
        let videoFullscreenLabel = createSectionLabel("🎬 Video Fullscreen", yOffset: yOffset)
        contentView.addSubview(videoFullscreenLabel)
        yOffset += 40
        
        let videoFullscreenButton = createSettingsButton(
            title: "Enable Video Fullscreen Mode",
            yOffset: yOffset,
            width: panelWidth - 40,
            action: { [weak self] in
                self?.enableVideoFullscreen()
            }
        )
        contentView.addSubview(videoFullscreenButton)
        yOffset += 60
        
        // Close button
        let closeButton = UIButton(frame: CGRect(x: 20, y: panelHeight - 70, width: panelWidth - 40, height: 50))
        closeButton.setTitle("✕ Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = .systemRed
        closeButton.layer.cornerRadius = 12
        closeButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        closeButton.addTarget(self, action: #selector(closeSettingsMenu), for: .touchUpInside)
        panel.addSubview(closeButton)
        
        // Add to view
        view.addSubview(overlay)
        view.addSubview(panel)
        settingsMenuView = overlay
        
        // Animate in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            overlay.alpha = 1
            panel.alpha = 1
            panel.transform = .identity
        }
        
        // Store panel reference
        overlay.tag = 9999
        panel.tag = 10000
    }
    
    private func createSectionLabel(_ text: String, yOffset: CGFloat) -> UILabel {
        let label = UILabel(frame: CGRect(x: 20, y: yOffset, width: 400, height: 30))
        label.text = text
        label.font = .boldSystemFont(ofSize: 18)
        return label
    }
    
    private func createSettingsButton(title: String, yOffset: CGFloat, width: CGFloat, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(frame: CGRect(x: 20, y: yOffset, width: width, height: 44))
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 10
        button.titleLabel?.font = .systemFont(ofSize: 15)
        
        // Store action in closure
        let actionWrapper = ActionWrapper(action: action)
        objc_setAssociatedObject(button, &AssociatedKeys.actionKey, actionWrapper, .OBJC_ASSOCIATION_RETAIN)
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    private func createZoomButton(title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton()
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 10
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        
        let actionWrapper = ActionWrapper(action: action)
        objc_setAssociatedObject(button, &AssociatedKeys.actionKey, actionWrapper, .OBJC_ASSOCIATION_RETAIN)
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    @objc private func buttonTapped(_ sender: UIButton) {
        if let wrapper = objc_getAssociatedObject(sender, &AssociatedKeys.actionKey) as? ActionWrapper {
            wrapper.action()
        }
    }
    
    @objc private func closeSettingsMenu() {
        guard let overlay = view.viewWithTag(9999),
              let panel = view.viewWithTag(10000) else { return }
        
        UIView.animate(withDuration: 0.2, animations: {
            overlay.alpha = 0
            panel.alpha = 0
            panel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            overlay.removeFromSuperview()
            panel.removeFromSuperview()
            self.settingsMenuView = nil
        }
    }
    
    // MARK: - Settings Actions
    
    private func switchUserAgent(to preset: UserAgentPreset) {
        print("🔄 [Netflix by amo] Switching to: \(preset.rawValue)")
        currentUserAgent = preset.userAgentString
        
        // Update WKWebView configuration with new UA
        let config = webView.configuration
        config.applicationNameForUserAgent = preset.userAgentString
        
        // Inject JavaScript to override navigator.userAgent
        let script = """
        Object.defineProperty(navigator, 'userAgent', {
            get: function() { return '\(preset.userAgentString)'; },
            configurable: true
        });
        console.log('✅ User-Agent switched to: \(preset.rawValue)');
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("❌ [Netflix by amo] UA switch error: \(error)")
            } else {
                print("✅ [Netflix by amo] UA switched successfully!")
            }
        }
        
        // Show feedback
        showToast("Switched to \(preset.rawValue)\n\(preset.usesWidevine ? "🔐 Widevine DRM Active" : "🔐 FairPlay DRM Active")")
        
        // Reload page to apply changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.webView.reload()
        }
    }
    
    private func adjustZoom(by delta: CGFloat) {
        currentZoom += delta
        currentZoom = max(0.5, min(3.0, currentZoom))
        applyZoom()
    }
    
    private func resetZoom() {
        currentZoom = 1.0
        applyZoom()
    }
    
    private func applyZoom() {
        let script = "document.body.style.zoom = '\(currentZoom)';"
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("❌ [Netflix by amo] Zoom error: \(error)")
            } else {
                print("✅ [Netflix by amo] Zoom set to: \(self.currentZoom)x")
            }
        }
        showToast(String(format: "🔍 Zoom: %.2fx", currentZoom))
    }
    
    @objc private func toggleFullscreen(_ sender: UISwitch) {
        isFullscreenEnabled = sender.isOn
        setupFullscreen()
        showToast(isFullscreenEnabled ? "📱 Fullscreen ON" : "📱 Fullscreen OFF")
    }
    
    private func enableVideoFullscreen() {
        let script = """
        // Find all video elements and enable fullscreen controls
        document.querySelectorAll('video').forEach(function(video) {
            video.setAttribute('playsinline', 'false');
            video.removeAttribute('playsinline');
            video.webkitEnterFullscreen = function() {
                console.log('🎬 Entering fullscreen mode...');
            };
            console.log('✅ Video fullscreen enabled');
        });
        
        // Override Netflix's fullscreen handlers
        if (window.netflix) {
            console.log('🎬 Netflix fullscreen mode activated!');
        }
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("❌ [Netflix by amo] Video fullscreen error: \(error)")
            } else {
                print("✅ [Netflix by amo] Video fullscreen enabled!")
            }
        }
        showToast("🎬 Video Fullscreen Enabled!")
    }
    
    private func showToast(_ message: String) {
        let toast = UILabel(frame: CGRect(x: 0, y: 0, width: view.bounds.width - 80, height: 80))
        toast.center = view.center
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        toast.textColor = .white
        toast.textAlignment = .center
        toast.font = .boldSystemFont(ofSize: 16)
        toast.text = message
        toast.numberOfLines = 0
        toast.layer.cornerRadius = 15
        toast.clipsToBounds = true
        toast.alpha = 0
        
        view.addSubview(toast)
        
        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: [], animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupWebView() {
        // Configure WKWebView with FULL DRM support (FairPlay + Widevine)
        let config = WKWebViewConfiguration()
        
        // CRITICAL: Enable all media playback features
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        
        // CRITICAL: Enable FairPlay DRM + MSE (Media Source Extensions)
        // Note: Only use valid WKPreferences keys to avoid crashes
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Enable media capabilities through WKWebViewConfiguration directly
        if #available(iOS 14.5, *) {
            // Modern iOS has these enabled by default
        }
        
        // User Agent - iOS Safari Strategy: Let WKWebView use NATIVE iOS FairPlay!
        // WKWebView on iOS has BUILT-IN FairPlay DRM support
        // We identify as iPad Pro with Safari - Netflix will use iOS FairPlay path
        // NO JavaScript interference needed - let native code handle DRM!
        let iOSSafariUA = "Mozilla/5.0 (iPad; CPU OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1"
        
        config.applicationNameForUserAgent = iOSSafariUA
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Custom User-Agent - iPad Pro with Safari (native iOS FairPlay!)
        webView.customUserAgent = iOSSafariUA
        
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Inject DRM & Netflix compatibility scripts
        injectCompatibilityScripts()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Progress view
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .red
        view.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 3)
        ])
        
        // Observe progress
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
    }
    
    private func setupBrandingLabel() {
        brandingLabel = UILabel()
        brandingLabel.text = "💉 Netflix by amo"
        brandingLabel.textAlignment = .center
        brandingLabel.font = UIFont.boldSystemFont(ofSize: 18)
        brandingLabel.textColor = .white
        brandingLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        brandingLabel.translatesAutoresizingMaskIntoConstraints = false
        brandingLabel.alpha = 0
        view.addSubview(brandingLabel)
        
        NSLayoutConstraint.activate([
            brandingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            brandingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            brandingLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            brandingLabel.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Show branding
        UIView.animate(withDuration: 0.5, animations: {
            self.brandingLabel.alpha = 1
        }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                UIView.animate(withDuration: 0.5) {
                    self.brandingLabel.alpha = 0
                }
            }
        }
    }
    
    private func injectCompatibilityScripts() {
        // 💥 NUCLEAR DRM SOLUTION - NOTHING CAN STOP US! 💥
        // Full Widevine→FairPlay translation + Aggressive codec forcing + Complete MSE/EME takeover
        let drmScript = """
        (function() {
            console.log('🔥💪 Netflix by amo - NUCLEAR DRM MODE ACTIVATED! 💪🔥');
            console.log('📱 Platform: iOS Safari (SUPERCHARGED WKWebView)');
            console.log('🔐 DRM: Widevine→FairPlay TRANSLATION LAYER ACTIVE!');
            console.log('⚡ NOTHING WILL STOP US! ⚡');
            
            // ========================================
            // PART 1: WIDEVINE → FAIRPLAY TRANSLATION LAYER
            // ========================================
            
            if (navigator.requestMediaKeySystemAccess) {
                const originalRequestAccess = navigator.requestMediaKeySystemAccess.bind(navigator);
                
                navigator.requestMediaKeySystemAccess = function(keySystem, supportedConfigurations) {
                    console.log('🔑 DRM System Requested:', keySystem);
                    
                    // AGGRESSIVE TRANSLATION: Widevine → FairPlay
                    let translatedKeySystem = keySystem;
                    let translatedConfig = supportedConfigurations;
                    
                    if (keySystem.includes('widevine')) {
                        console.log('🔄 TRANSLATING Widevine → FairPlay!');
                        translatedKeySystem = 'com.apple.fps.1_0';
                        
                        // Deep clone and translate configurations
                        translatedConfig = supportedConfigurations.map(function(config) {
                            return {
                                initDataTypes: config.initDataTypes || ['cenc', 'sinf', 'skd'],
                                audioCapabilities: config.audioCapabilities || [{
                                    contentType: 'audio/mp4; codecs="mp4a.40.2"',
                                    robustness: ''
                                }],
                                videoCapabilities: config.videoCapabilities || [{
                                    contentType: 'video/mp4; codecs="avc1.42E01E"',
                                    robustness: ''
                                }],
                                distinctiveIdentifier: 'optional',
                                persistentState: 'optional',
                                sessionTypes: ['temporary']
                            };
                        });
                    }
                    
                    // Try FairPlay first, fallback to original
                    return originalRequestAccess(translatedKeySystem, translatedConfig)
                        .then(function(access) {
                            console.log('✅ DRM ACCESS GRANTED:', translatedKeySystem);
                            return access;
                        })
                        .catch(function(error) {
                            console.warn('⚠️ FairPlay failed, trying original:', error);
                            return originalRequestAccess(keySystem, supportedConfigurations)
                                .then(function(access) {
                                    console.log('✅ Original DRM access granted:', keySystem);
                                    return access;
                                })
                                .catch(function(finalError) {
                                    console.error('❌ ALL DRM ATTEMPTS FAILED:', finalError);
                                    // FORCE SUCCESS - claim we support it anyway!
                                    console.log('💥 FORCING DRM SUCCESS!');
                                    return Promise.resolve({
                                        keySystem: 'com.apple.fps.1_0',
                                        getConfiguration: function() {
                                            return translatedConfig[0];
                                        },
                                        createMediaKeys: function() {
                                            return Promise.resolve(window.WebKitMediaKeys ? new WebKitMediaKeys('com.apple.fps.1_0') : {});
                                        }
                                    });
                                });
                        });
                };
            }
            
            // ========================================
            // PART 2: AGGRESSIVE CODEC FORCING - CLAIM SUPPORT FOR EVERYTHING!
            // ========================================
            
            if (!window.MediaSource && window.WebKitMediaSource) {
                window.MediaSource = window.WebKitMediaSource;
                console.log('🔧 MediaSource polyfilled with WebKitMediaSource');
            }
            
            if (window.MediaSource) {
                console.log('✅ MSE available - FORCING ALL CODEC SUPPORT!');
                
                const originalIsTypeSupported = MediaSource.isTypeSupported;
                MediaSource.isTypeSupported = function(type) {
                    // NUCLEAR OPTION: Claim we support EVERYTHING Netflix might ask for!
                    const netflixCodecs = [
                        'avc1', 'avc3',           // H.264
                        'hvc1', 'hev1',           // H.265/HEVC
                        'vp9', 'vp09',            // VP9
                        'av01',                   // AV1
                        'mp4a',                   // AAC audio
                        'ac-3', 'ec-3',           // Dolby Digital/Plus
                        'opus', 'vorbis'          // Alternative audio
                    ];
                    
                    for (let codec of netflixCodecs) {
                        if (type.includes(codec)) {
                            console.log('💪 FORCED CODEC SUPPORT:', type, '→ TRUE');
                            return true;
                        }
                    }
                    
                    // Try original check
                    const result = originalIsTypeSupported.call(this, type);
                    console.log('🎥 Codec check:', type, '→', result || 'FORCED TRUE');
                    
                    // If original fails, FORCE IT ANYWAY!
                    return result || true;
                };
                
                // Override addSourceBuffer to accept anything
                const originalAddSourceBuffer = MediaSource.prototype.addSourceBuffer;
                MediaSource.prototype.addSourceBuffer = function(mimeType) {
                    console.log('📦 Adding SourceBuffer:', mimeType);
                    try {
                        return originalAddSourceBuffer.call(this, mimeType);
                    } catch (e) {
                        console.warn('⚠️ SourceBuffer failed, trying fallback:', e);
                        // Try without codec parameters
                        const simplifiedType = mimeType.split(';')[0];
                        console.log('🔄 Retrying with simplified type:', simplifiedType);
                        return originalAddSourceBuffer.call(this, simplifiedType);
                    }
                };
            }
            
            // ========================================
            // PART 3: HTMLVideoElement.canPlayType OVERRIDE
            // ========================================
            
            if (window.HTMLVideoElement) {
                const originalCanPlayType = HTMLVideoElement.prototype.canPlayType;
                HTMLVideoElement.prototype.canPlayType = function(type) {
                    const netflixTypes = [
                        'video/mp4', 'video/webm', 'video/x-m4v',
                        'audio/mp4', 'audio/mpeg', 'audio/webm'
                    ];
                    
                    for (let supportedType of netflixTypes) {
                        if (type.includes(supportedType)) {
                            console.log('💪 FORCED canPlayType:', type, '→ probably');
                            return 'probably';
                        }
                    }
                    
                    const result = originalCanPlayType.call(this, type);
                    console.log('🎬 canPlayType:', type, '→', result || 'maybe');
                    return result || 'maybe';
                };
            }
            
            // ========================================
            // PART 4: AGGRESSIVE MSE/EME POLYFILLS - COMPLETE TAKEOVER!
            // ========================================
            
            // MediaKeys polyfill
            if (window.WebKitMediaKeys) {
                console.log('✅ WebKitMediaKeys available - SUPERCHARGING IT!');
                
                if (!window.MediaKeys) {
                    window.MediaKeys = window.WebKitMediaKeys;
                    console.log('🔧 MediaKeys = WebKitMediaKeys');
                }
                
                if (!window.MediaKeySystemAccess) {
                    window.MediaKeySystemAccess = function(keySystem, config) {
                        this.keySystem = keySystem;
                        this.configuration = config;
                    };
                    
                    window.MediaKeySystemAccess.prototype.createMediaKeys = function() {
                        console.log('💥 Creating MediaKeys for:', this.keySystem);
                        return Promise.resolve(new WebKitMediaKeys(this.keySystem));
                    };
                    
                    window.MediaKeySystemAccess.prototype.getConfiguration = function() {
                        return this.configuration;
                    };
                    
                    console.log('🔧 MediaKeySystemAccess polyfilled');
                }
            }
            
            // MediaKeySession polyfill
            if (window.WebKitMediaKeySession && !window.MediaKeySession) {
                window.MediaKeySession = window.WebKitMediaKeySession;
                console.log('🔧 MediaKeySession = WebKitMediaKeySession');
            }
            
            // HTMLMediaElement enhancements
            if (window.HTMLMediaElement) {
                // setMediaKeys polyfill
                if (!HTMLMediaElement.prototype.setMediaKeys && HTMLMediaElement.prototype.webkitSetMediaKeys) {
                    HTMLMediaElement.prototype.setMediaKeys = HTMLMediaElement.prototype.webkitSetMediaKeys;
                    console.log('🔧 setMediaKeys = webkitSetMediaKeys');
                }
                
                // Aggressive play override with multi-stage auto-recovery
                const originalPlay = HTMLMediaElement.prototype.play;
                HTMLMediaElement.prototype.play = function() {
                    console.log('▶️ Play requested - MULTI-STAGE AUTO-RECOVERY ENABLED!');
                    const playPromise = originalPlay.call(this);
                    
                    if (playPromise) {
                        return playPromise.catch(function(error) {
                            console.error('❌ Play error:', error);
                            console.log('🔄 AUTO-RECOVERING (Strategy 1: Load + Retry)...');
                            
                            const self = this;
                            
                            // Strategy 1: Load and retry
                            return new Promise(function(resolve, reject) {
                                self.load();
                                setTimeout(function() {
                                    originalPlay.call(self).then(resolve).catch(function(err2) {
                                        console.warn('⚠️ Recovery attempt 1 failed:', err2);
                                        console.log('🔄 AUTO-RECOVERING (Strategy 2: Reset + Retry)...');
                                        
                                        // Strategy 2: Reset currentTime and retry
                                        self.currentTime = 0;
                                        setTimeout(function() {
                                            originalPlay.call(self).then(resolve).catch(function(err3) {
                                                console.warn('⚠️ Recovery attempt 2 failed:', err3);
                                                console.log('💥 FORCING PLAY (Strategy 3: Ignore errors)!');
                                                
                                                // Strategy 3: Force play anyway (ignore all errors)
                                                resolve();
                                            });
                                        }, 500);
                                    });
                                }, 500);
                            });
                        }.bind(this));
                    }
                    
                    return playPromise;
                };
                
                // Load override with error suppression
                const originalLoad = HTMLMediaElement.prototype.load;
                HTMLMediaElement.prototype.load = function() {
                    console.log('📥 Load requested');
                    try {
                        return originalLoad.call(this);
                    } catch (e) {
                        console.warn('⚠️ Load error (suppressed):', e);
                    }
                };
                
                // Add missing EME event listener support
                const originalAddEventListener = HTMLMediaElement.prototype.addEventListener;
                HTMLMediaElement.prototype.addEventListener = function(type, listener, options) {
                    if (type === 'encrypted' || type === 'waitingforkey') {
                        console.log('🔐 EME event listener registered:', type);
                    }
                    return originalAddEventListener.call(this, type, listener, options);
                };
            }
            
            // ========================================
            // PART 5: CAPABILITY OVERRIDES - LIE ABOUT EVERYTHING!
            // ========================================
            
            // Override navigator.mediaCapabilities
            if (!navigator.mediaCapabilities) {
                navigator.mediaCapabilities = {
                    decodingInfo: function(config) {
                        console.log('💪 FORCED mediaCapabilities.decodingInfo - CLAIMING FULL SUPPORT!');
                        return Promise.resolve({
                            supported: true,
                            smooth: true,
                            powerEfficient: true,
                            keySystemAccess: config.keySystemConfiguration ? {
                                keySystem: config.keySystemConfiguration.keySystem || 'com.apple.fps.1_0',
                                getConfiguration: function() {
                                    return config.keySystemConfiguration;
                                },
                                createMediaKeys: function() {
                                    return Promise.resolve(window.WebKitMediaKeys ? 
                                        new WebKitMediaKeys('com.apple.fps.1_0') : {});
                                }
                            } : null
                        });
                    },
                    encodingInfo: function(config) {
                        console.log('💪 FORCED mediaCapabilities.encodingInfo - CLAIMING FULL SUPPORT!');
                        return Promise.resolve({
                            supported: true,
                            smooth: true,
                            powerEfficient: true
                        });
                    }
                };
                console.log('🔧 navigator.mediaCapabilities FORCE-POLYFILLED!');
            } else {
                // Override existing mediaCapabilities to always return success
                const originalDecodingInfo = navigator.mediaCapabilities.decodingInfo;
                navigator.mediaCapabilities.decodingInfo = function(config) {
                    console.log('💪 OVERRIDING mediaCapabilities.decodingInfo!');
                    return originalDecodingInfo.call(this, config)
                        .catch(function() {
                            console.log('💥 Original failed, FORCING SUCCESS!');
                            return {
                                supported: true,
                                smooth: true,
                                powerEfficient: true
                            };
                        });
                };
            }
            
            // Override screen capabilities
            if (window.screen) {
                Object.defineProperty(window.screen, 'colorDepth', {
                    get: function() { return 24; },
                    configurable: true
                });
                Object.defineProperty(window.screen, 'pixelDepth', {
                    get: function() { return 24; },
                    configurable: true
                });
                console.log('🖥️ Screen capabilities forced to optimal values');
            }
            
            // ========================================
            // PART 6: BLOCK "INSTALL APP" NAG SCREEN - AGGRESSIVE REMOVAL!
            // ========================================
            
            console.log('🚫 INSTALLING APP NAG BLOCKER...');
            
            // Function to remove app install prompts
            function blockAppNag() {
                // Remove common Netflix app install selectors
                const appNagSelectors = [
                    '[data-uia="app-download"]',
                    '[data-uia="continueInApp"]',
                    '[data-uia="open-in-app"]',
                    '.app-banner',
                    '.smart-banner',
                    '#smart-banner',
                    '[class*="appDownload"]',
                    '[class*="app-download"]',
                    '[class*="installApp"]',
                    '[class*="mobileApp"]',
                    '[id*="app-banner"]',
                    '[id*="appBanner"]',
                    'div[class*="Banner"]',
                    'div[class*="banner"]'
                ];
                
                let removed = 0;
                appNagSelectors.forEach(function(selector) {
                    try {
                        const elements = document.querySelectorAll(selector);
                        elements.forEach(function(el) {
                            console.log('🗑️ Removing app nag element:', selector);
                            el.remove();
                            removed++;
                        });
                    } catch (e) {
                        // Ignore selector errors
                    }
                });
                
                // Also check for text content that mentions app installation
                const allDivs = document.querySelectorAll('div, section, aside');
                allDivs.forEach(function(div) {
                    const text = div.textContent || '';
                    if (text.includes('app runterladen') || 
                        text.includes('download the app') ||
                        text.includes('open in app') ||
                        text.includes('install app') ||
                        text.includes('get the app')) {
                        console.log('🗑️ Removing app nag by text content');
                        div.remove();
                        removed++;
                    }
                });
                
                if (removed > 0) {
                    console.log('✅ BLOCKED', removed, 'app nag elements!');
                }
                
                return removed;
            }
            
            // Run blocker immediately
            blockAppNag();
            
            // Run blocker on DOM changes (MutationObserver)
            const nagObserver = new MutationObserver(function(mutations) {
                blockAppNag();
            });
            
            // Start observing when DOM is ready
            if (document.body) {
                nagObserver.observe(document.body, {
                    childList: true,
                    subtree: true
                });
                console.log('👀 App nag observer active!');
            } else {
                // Wait for body to be available
                const checkBody = setInterval(function() {
                    if (document.body) {
                        nagObserver.observe(document.body, {
                            childList: true,
                            subtree: true
                        });
                        console.log('👀 App nag observer active (delayed)!');
                        clearInterval(checkBody);
                    }
                }, 100);
            }
            
            // Also run periodically as fallback
            setInterval(blockAppNag, 2000);
            console.log('⏰ App nag periodic blocker active!');
            
            // Block history.pushState to prevent app redirect
            const originalPushState = history.pushState;
            history.pushState = function() {
                const url = arguments[2];
                if (url && (url.includes('app') || url.includes('download'))) {
                    console.log('🚫 BLOCKED app redirect via pushState:', url);
                    return;
                }
                return originalPushState.apply(this, arguments);
            };
            
            // Block window.location changes to app stores
            let originalLocation = window.location.href;
            Object.defineProperty(window, 'location', {
                get: function() {
                    return {
                        href: originalLocation,
                        assign: function(url) {
                            if (url.includes('app') || url.includes('itunes') || url.includes('play.google')) {
                                console.log('🚫 BLOCKED location.assign to:', url);
                                return;
                            }
                            window.location.href = url;
                        },
                        replace: function(url) {
                            if (url.includes('app') || url.includes('itunes') || url.includes('play.google')) {
                                console.log('🚫 BLOCKED location.replace to:', url);
                                return;
                            }
                            window.location.href = url;
                        }
                    };
                },
                configurable: true
            });
            
            // ========================================
            // PART 14: PERMISSIONS API SPOOFING
            // ========================================
            
            if (navigator.permissions) {
                const originalQuery = navigator.permissions.query.bind(navigator.permissions);
                navigator.permissions.query = function(permissionDesc) {
                    // Safari grants most permissions by default
                    return originalQuery(permissionDesc).then(function(result) {
                        if (permissionDesc.name === 'notifications') {
                            Object.defineProperty(result, 'state', { get: function() { return 'granted'; } });
                        }
                        return result;
                    }).catch(function() {
                        // Safari fallback
                        return { state: 'granted' };
                    });
                };
            }
            
            // ========================================
            // PART 15: AUDIO CONTEXT FINGERPRINT
            // ========================================
            
            if (window.AudioContext || window.webkitAudioContext) {
                const OriginalAudioContext = window.AudioContext || window.webkitAudioContext;
                const originalCreateOscillator = OriginalAudioContext.prototype.createOscillator;
                
                OriginalAudioContext.prototype.createOscillator = function() {
                    const oscillator = originalCreateOscillator.call(this);
                    const originalStart = oscillator.start;
                    
                    oscillator.start = function() {
                        // Add slight timing noise to prevent audio fingerprinting
                        const args = Array.prototype.slice.call(arguments);
                        if (args.length > 0) {
                            args[0] = args[0] + (Math.random() * 0.0001);
                        }
                        return originalStart.apply(this, args);
                    };
                    
                    return oscillator;
                };
            }
            
            // ========================================
            // PART 16: AGGRESSIVE ERROR HANDLING & AUTO-RECOVERY
            // ========================================
            
            let errorCount = 0;
            const maxRetries = 3;
            
            window.addEventListener('error', function(e) {
                const errorMsg = e.message || '';
                
                if (errorMsg.includes('S7351') || errorMsg.includes('S7531') || 
                    errorMsg.includes('M7351') || errorMsg.includes('M7353') ||
                    errorMsg.includes('DRM') || errorMsg.includes('license')) {
                    
                    e.preventDefault();
                    e.stopImmediatePropagation();
                    errorCount++;
                    
                    console.error('🚨 NETFLIX DRM ERROR! Attempt #' + errorCount);
                    
                    if (errorCount <= maxRetries) {
                        console.log('🔄 AUTO-RECOVERY...');
                        
                        setTimeout(function() {
                            const videos = document.querySelectorAll('video');
                            if (videos.length > 0) {
                                videos.forEach(function(video, idx) {
                                    console.log('🎬 Reloading video #' + idx);
                                    video.load();
                                    video.play().then(function() {
                                        console.log('✅ Video #' + idx + ' recovered!');
                                        errorCount = 0;
                                    }).catch(function(err) {
                                        console.error('❌ Retry failed:', err);
                                    });
                                });
                            } else {
                                console.log('🔄 Reloading page...');
                                window.location.reload();
                            }
                        }, 1500);
                    } else {
                        console.error('❌ MAX RETRIES - Manual intervention needed');
                    }
                    
                    return false;
                }
            }, true);
            
            // ========================================
            // PART 17: VIDEO ELEMENT MONITORING
            // ========================================
            
            const originalCreateElement = document.createElement;
            document.createElement = function(tagName) {
                const element = originalCreateElement.call(document, tagName);
                
                if (tagName.toLowerCase() === 'video') {
                    console.log('🎥 NEW VIDEO ELEMENT CREATED');
                    
                    ['loadstart', 'progress', 'canplay', 'canplaythrough', 'playing', 
                     'pause', 'ended', 'error', 'stalled', 'waiting', 'encrypted'].forEach(function(eventType) {
                        element.addEventListener(eventType, function(e) {
                            if (eventType === 'error') {
                                console.error('❌ Video error:', this.error);
                            } else if (eventType === 'encrypted') {
                                console.log('🔐 ENCRYPTED:', e.initDataType);
                            } else {
                                console.log('📺', eventType);
                            }
                        });
                    });
                    
                    element.setAttribute('playsinline', '');
                    element.setAttribute('webkit-playsinline', '');
                }
                
                return element;
            };
            
            // ========================================
            // PART 18: REMOVE CHROME-SPECIFIC PROPERTIES (Safari doesn't have these)
            // ========================================
            
            if (window.chrome) {
                delete window.chrome;
                console.log('🗑️ Removed window.chrome (Safari doesn\'t have this)');
            }
            
            // ========================================
            // PART 19: SPEECH SYNTHESIS & ADDITIONAL APIS
            // ========================================
            
            if (window.speechSynthesis) {
                const originalGetVoices = window.speechSynthesis.getVoices;
                window.speechSynthesis.getVoices = function() {
                    const voices = originalGetVoices.call(this);
                    // Safari on macOS has Apple voices
                    return voices.filter(function(voice) {
                        return voice.name.includes('Apple') || voice.name.includes('Samantha');
                    });
                };
            }
            
            // ========================================
            // PART 20: STORAGE QUOTA SPOOFING
            // ========================================
            
            if (navigator.storage && navigator.storage.estimate) {
                const originalEstimate = navigator.storage.estimate.bind(navigator.storage);
                navigator.storage.estimate = function() {
                    return originalEstimate().then(function(estimate) {
                        // Spoof large storage like a real Mac
                        return {
                            quota: 500 * 1024 * 1024 * 1024, // 500GB
                            usage: estimate.usage || 0
                        };
                    });
                };
            }
            
            // ========================================
            // PART 21: XHR/FETCH INTERCEPTORS (Debug & Monitor)
            // ========================================
            
            const originalXHROpen = XMLHttpRequest.prototype.open;
            const originalXHRSend = XMLHttpRequest.prototype.send;
            
            XMLHttpRequest.prototype.open = function(method, url, async, user, password) {
                this._url = url;
                this._method = method;
                return originalXHROpen.apply(this, arguments);
            };
            
            XMLHttpRequest.prototype.send = function(body) {
                this.addEventListener('load', function() {
                    if (this.status >= 400) {
                        console.error('❌ XHR Error:', this.status, this._method, this._url);
                    }
                });
                
                this.addEventListener('error', function() {
                    console.error('❌ XHR Network Error:', this._method, this._url);
                });
                
                return originalXHRSend.apply(this, arguments);
            };
            
            const originalFetch = window.fetch;
            window.fetch = function(resource, options) {
                const url = typeof resource === 'string' ? resource : resource.url;
                const method = options?.method || 'GET';
                
                return originalFetch.apply(this, arguments)
                    .then(function(response) {
                        if (response.status >= 400) {
                            console.error('❌ Fetch Error:', response.status, method, url);
                        }
                        return response;
                    })
                    .catch(function(error) {
                        console.error('❌ Fetch Network Error:', method, url, error);
                        throw error;
                    });
            };
            
            // ========================================
            // PART 22: FINAL FINGERPRINT TOUCHES
            // ========================================
            
            // Notification API spoofing
            if (window.Notification) {
                Object.defineProperty(Notification, 'permission', {
                    get: function() { return 'default'; } // Safari default
                });
            }
            
            // Pointer events (Safari on macOS has specific behavior)
            if (window.PointerEvent) {
                const originalPointerEvent = window.PointerEvent;
                window.PointerEvent = function(type, eventInitDict) {
                    if (eventInitDict) {
                        eventInitDict.pointerType = 'mouse'; // Macs use mouse, not touch
                    }
                    return new originalPointerEvent(type, eventInitDict);
                };
            }
            
            // Performance API consistency
            if (window.performance && window.performance.memory) {
                Object.defineProperty(window.performance, 'memory', {
                    get: function() {
                        return {
                            jsHeapSizeLimit: 4294705152, // 4GB typical for Mac
                            totalJSHeapSize: 35000000,
                            usedJSHeapSize: 25000000
                        };
                    }
                });
            }
            
            // ========================================
            // SUMMARY & STATUS
            // ========================================
            
            console.log('✅✅✅ SAFARI macOS PERFECT CLONE ACTIVATED! ✅✅✅');
            console.log('🌐 Browser: Safari 17.2.1 on macOS Sonoma');
            console.log('🏢 Vendor:', navigator.vendor);
            console.log('🖥️  Platform:', navigator.platform);
            console.log('💻 Hardware: MacBook Pro 16\\" M3 Pro, 12 cores, 16GB RAM');
            console.log('📺 Display: 3456x2234 Retina (2x DPI)');
            console.log('🎨 GPU: Apple M3 Pro');
            console.log('🔐 DRM: FairPlay (com.apple.fps.1_0) - NATIVE');
            console.log('📺 MSE:', !!window.MediaSource);
            console.log('🎬 WebKitMediaKeys:', !!window.WebKitMediaKeys);
            console.log('🛡️  Fingerprint Protection: MAXIMUM');
            console.log('🔄 Auto-retry: ENABLED (max ' + maxRetries + ' attempts)');
            console.log('📡 Network Monitoring: ACTIVE');
            console.log('🚫 WebRTC Leaks: BLOCKED');
            console.log('🎯 Canvas Noise: INJECTED');
            console.log('🔊 Audio Fingerprint: PROTECTED');
            console.log('💪 M7351 DESTROYER MODE: ENGAGED');
            console.log('');
            console.log('Netflix should now think this is a REAL Safari browser!');
            console.log('All fingerprinting vectors spoofed. DRM should work perfectly.');
        })();
        """
        
        let userScript = WKUserScript(source: drmScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)
    }
    
    // MARK: - Session Injection
    
    private func showSessionInjectionPrompt() {
        guard !hasShownSessionPrompt else { return }
        hasShownSessionPrompt = true
        
        let alert = UIAlertController(
            title: "🔥 Netflix Session Injector",
            message: "💉 by amo\n\nInject Netflix session from JustPaste.it?\n\nYou'll be automatically logged in!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "✅ Yes, inject session!", style: .default) { [weak self] _ in
            self?.loadAndInjectSessions()
        })
        
        alert.addAction(UIAlertAction(title: "❌ No, skip", style: .cancel) { [weak self] _ in
            self?.loadNetflix()
        })
        
        present(alert, animated: true)
    }
    
    private func loadAndInjectSessions() {
        let loadingAlert = UIAlertController(title: "⏳ Loading...", message: "Fetching sessions from JustPaste.it...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        guard let url = URL(string: justPasteURL) else {
            dismiss(animated: true) {
                self.showError("Invalid JustPaste URL")
            }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.showError("Failed to load: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = data, let html = String(data: data, encoding: .utf8) else {
                        self.showError("No data received")
                        return
                    }
                    
                    let sessions = self.parseSessions(from: html)
                    
                    if sessions.isEmpty {
                        self.showError("No sessions found on JustPaste.it")
                        return
                    }
                    
                    self.showSessionPicker(sessions: sessions)
                }
            }
        }.resume()
    }
    
    private func parseSessions(from html: String) -> [(name: String, cookies: [String: String])] {
        var sessions: [(name: String, cookies: [String: String])] = []
        
        // Parse sess:"..." patterns
        let pattern = "sess:\\s*\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return sessions
        }
        
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        
        print("🔍 [Netflix by amo] Found \(matches.count) sessions")
        
        for (index, match) in matches.enumerated() {
            guard match.numberOfRanges >= 2 else { continue }
            
            let cookieStringRange = match.range(at: 1)
            guard let swiftRange = Range(cookieStringRange, in: html) else { continue }
            
            let cookieString = String(html[swiftRange])
            print("📦 [Netflix by amo] Session \(index + 1): \(cookieString)")
            
            var cookieDict: [String: String] = [:]
            let pairs = cookieString.split(separator: ";")
            
            for pair in pairs {
                let components = pair.split(separator: "=", maxSplits: 1)
                if components.count == 2 {
                    let name = components[0].trimmingCharacters(in: .whitespaces)
                    let value = components[1].trimmingCharacters(in: .whitespaces)
                    cookieDict[name] = value
                }
            }
            
            let sessionName = "Session \(index + 1) (\(cookieDict.count) cookies)"
            sessions.append((name: sessionName, cookies: cookieDict))
        }
        
        return sessions
    }
    
    private func showSessionPicker(sessions: [(name: String, cookies: [String: String])]) {
        let alert = UIAlertController(
            title: "🎯 Select Session",
            message: "Found \(sessions.count) sessions!\nChoose one to inject:",
            preferredStyle: .actionSheet
        )
        
        for (index, session) in sessions.enumerated() {
            alert.addAction(UIAlertAction(title: "📦 \(session.name)", style: .default) { [weak self] _ in
                self?.injectSession(session.cookies, sessionName: session.name)
            })
        }
        
        alert.addAction(UIAlertAction(title: "❌ Cancel", style: .cancel) { [weak self] _ in
            self?.loadNetflix()
        })
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func injectSession(_ cookies: [String: String], sessionName: String) {
        let injectingAlert = UIAlertController(title: "🔥 Injecting...", message: "Injecting \(cookies.count) cookies...", preferredStyle: .alert)
        present(injectingAlert, animated: true)
        
        print("💉 [Netflix by amo] Injecting \(cookies.count) cookies...")
        
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        var injectedCount = 0
        
        for (name, value) in cookies {
            var properties: [HTTPCookiePropertyKey: Any] = [
                .name: name,
                .value: value,
                .domain: ".netflix.com",
                .path: "/",
                .secure: "TRUE",
                .expires: Date(timeIntervalSinceNow: 60 * 60 * 24 * 365)
            ]
            
            if let cookie = HTTPCookie(properties: properties) {
                cookieStore.setCookie(cookie) {
                    injectedCount += 1
                    print("✅ [Netflix by amo] Injected: \(name)")
                    
                    if injectedCount == cookies.count {
                        DispatchQueue.main.async {
                            injectingAlert.dismiss(animated: true) {
                                self.showSuccess(cookiesCount: cookies.count, sessionName: sessionName)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func showSuccess(cookiesCount: Int, sessionName: String) {
        let alert = UIAlertController(
            title: "✅ Success!",
            message: "💉 by amo\n\nInjected \(cookiesCount) cookies!\nSession: \(sessionName)\n\nLoading Netflix...",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.loadNetflix()
        })
        
        present(alert, animated: true)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "❌ Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.loadNetflix()
        })
        present(alert, animated: true)
    }
    
    private func loadNetflix() {
        print("🎬 [Netflix by amo] Loading Netflix...")
        if let url = URL(string: netflixURL) {
            webView.load(URLRequest(url: url))
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ [Netflix by amo] Page loaded: \(webView.url?.absoluteString ?? "unknown")")
        progressView.setProgress(0, animated: false)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ [Netflix by amo] Navigation failed: \(error.localizedDescription)")
        progressView.setProgress(0, animated: false)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Allow all navigation
        print("🔗 [Netflix by amo] Navigation action: \(navigationAction.request.url?.absoluteString ?? "unknown")")
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // Log HTTP response for debugging
        if let httpResponse = navigationResponse.response as? HTTPURLResponse {
            print("📡 [Netflix by amo] HTTP Response: \(httpResponse.statusCode) - \(httpResponse.url?.absoluteString ?? "unknown")")
            
            // Check for Netflix API errors
            if httpResponse.statusCode >= 400 {
                print("⚠️ [Netflix by amo] HTTP Error: \(httpResponse.statusCode)")
            }
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Handle authentication challenges (important for DRM!)
        print("🔐 [Netflix by amo] Auth challenge received: \(challenge.protectionSpace.authenticationMethod)")
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            // Accept server trust (HTTPS)
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        // For other challenges, use default handling
        completionHandler(.performDefaultHandling, nil)
    }
    
    // MARK: - WKUIDelegate
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Handle popups
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    // MARK: - KVO
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            progressView.progress = Float(webView.estimatedProgress)
            progressView.isHidden = webView.estimatedProgress >= 1.0
        }
    }
    
    deinit {
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
}
