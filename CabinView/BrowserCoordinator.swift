import WebKit
import Observation

@MainActor @Observable
final class BrowserCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = BrowserCoordinator()
    let webView: WKWebView
    var isClearingWebsiteData = false
    var hasPage = false
    var showsStartPage = true
    var pageTitle = "your page"
    var isLoading = false
    var progress = 0.0
    var canGoBack = false
    var canGoForward = false
    var currentAddress = ""
    var errorMessage: String?
    private var retryURL: URL?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    var pageURL: URL? { BrowserAddress.secureURL(currentAddress) }
    var canNavigateBack: Bool { canGoBack || (showsStartPage && hasPage) }

    init(websiteDataStore: WKWebsiteDataStore = .default()) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = websiteDataStore
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.refreshNavigation() }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.refreshNavigation() }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.refreshNavigation() }
            },
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.refreshNavigation() }
            },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.refreshNavigation() }
            }
        ]
    }

    isolated deinit { observations.forEach { $0.invalidate() } }

    func open(_ input: String) {
        guard let url = BrowserAddress.destination(for: input) else {
            errorMessage = "Enter a search or a valid website address. App links, local files, and scripts cannot be opened here."
            return
        }
        load(url)
    }

    private func load(_ url: URL) {
        errorMessage = nil
        retryURL = url
        hasPage = true
        showsStartPage = false
        currentAddress = url.absoluteString
        isLoading = true
        webView.load(URLRequest(url: url))
    }

    private func refreshNavigation() {
        progress = webView.estimatedProgress
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        guard hasPage else { return }
        currentAddress = webView.url?.absoluteString ?? currentAddress
        pageTitle = webView.title.flatMap { $0.isEmpty ? nil : $0 } ?? pageURL?.host ?? "your page"
    }

    func reload() {
        guard let url = pageURL ?? retryURL else { return }
        showsStartPage = false
        errorMessage = nil
        if webView.url != url { load(url) }
        else { webView.reload() }
    }

    func stopLoading() { webView.stopLoading(); isLoading = false }
    func showStartPage() { showsStartPage = true; errorMessage = nil }
    func resumePage() { guard hasPage else { return }; showsStartPage = false }

    func goBack() {
        if showsStartPage { resumePage(); return }
        webView.goBack()
    }

    func goForward() { showsStartPage = false; webView.goForward() }

    func clearWebsiteData() async {
        guard !isClearingWebsiteData else { return }
        isClearingWebsiteData = true
        defer { isClearingWebsiteData = false }
        webView.stopLoading()
        await webView.pauseAllMediaPlayback()
        await webView.closeAllMediaPresentations()
        await webView.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        webView.loadHTMLString("", baseURL: nil)
        hasPage = false
        showsStartPage = true
        isLoading = false
        currentAddress = ""
        pageTitle = "your page"
        retryURL = nil
        errorMessage = nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard hasPage else { return }
        isLoading = true
        errorMessage = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        guard hasPage else { return }
        currentAddress = webView.url?.absoluteString ?? ""
        retryURL = webView.url
        refreshNavigation()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }

    private func failed(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        isLoading = false
        errorMessage = "This page couldn’t load. Check your connection and try again."
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        isLoading = false
        errorMessage = "The page stopped responding. Reload to continue."
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if action.request.url?.absoluteString == "about:blank" { decisionHandler(.allow); return }
        guard let url = action.request.url, let secure = BrowserAddress.secureURL(url.absoluteString) else {
            decisionHandler(.cancel)
            if action.targetFrame?.isMainFrame != false { errorMessage = "This link needs an external app or an unsupported sign-in flow." }
            return
        }
        guard url == secure else {
            decisionHandler(.cancel)
            if action.targetFrame?.isMainFrame != false { load(secure) }
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = action.request.url, let secure = BrowserAddress.secureURL(url.absoluteString) else {
            errorMessage = "This window needs an external app or an unsupported link."
            return nil
        }
        load(secure)
        return nil
    }
}
