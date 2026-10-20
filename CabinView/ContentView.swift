import SwiftUI
import WebKit
import AVKit

struct ContentView: View {
    @Bindable var browser: BrowserCoordinator
    @State private var query = ""
    @State private var selection: TextSelection?
    @FocusState private var searching: Bool
    @State private var confirmingClear = false
    @State private var showingRoutes = false
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        VStack(spacing: 0) {
            errorBanner
            ZStack {
                BrowserSurface(browser: browser)
                    .opacity(browser.showsStartPage ? 0 : 1)
                    .allowsHitTesting(!browser.showsStartPage)
                    .accessibilityHidden(browser.showsStartPage)
                if browser.showsStartPage { startPage }
            }
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) { browserControls }
        .onChange(of: browser.currentAddress) { _, address in
            guard !searching else { return }
            query = address
        }
        .onChange(of: searching) { _, editing in
            guard editing else { return }
            query = browser.showsStartPage ? "" : browser.currentAddress
            selection = TextSelection(range: query.startIndex..<query.endIndex)
        }
        .alert("Clear all website sessions?", isPresented: $confirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear website data", role: .destructive) {
                Task { await browser.clearWebsiteData(); query = "" }
            }
        } message: { Text("This signs you out of websites in CabinView. Other browsers are unaffected.") }
        .sheet(isPresented: $showingRoutes) { PlaybackDestinationView() }
        .disabled(browser.isClearingWebsiteData)
        .overlay { clearingProgress }
        .tint(.blue)
    }

    private var startPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image("CabinViewLogo")
                    .resizable().frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    Text("CabinView").font(.largeTitle.bold())
                    Text("Search the web or enter an address below.")
                        .font(.title3).foregroundStyle(.secondary)
                }
                if browser.hasPage {
                    Button(action: resumeBrowsing) {
                        Label("Return to \(browser.pageTitle)", systemImage: "arrow.uturn.backward")
                            .lineLimit(2)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    .accessibilityIdentifier("resumeBrowsing")
                }
            }
            .frame(maxWidth: 480, alignment: .leading)
            .padding(32).frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center, for: .alignment)
        .scrollDismissesKeyboard(.interactively)
    }

    private var browserControls: some View {
        VStack(spacing: 8) {
            if browser.isLoading { ProgressView(value: browser.progress).accessibilityLabel("Page loading") }
            HStack(spacing: 8) {
                addressField
                if searching {
                    cancelButton
                }
            }
            if !searching { navigationBar }
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var addressField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundStyle(.secondary).frame(width: 32).accessibilityHidden(true)
            TextField("Search or enter website", text: $query, selection: $selection)
                .font(.body).textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(.webSearch).submitLabel(.go).focused($searching)
                .onSubmit(openSearch)
                .accessibilityLabel("Search or enter website")
                .accessibilityIdentifier("browserSearch")
            if searching { searchActions }
            else if browser.hasPage && !browser.showsStartPage { reloadButton }
        }
        .padding(.leading, 8).padding(.trailing, 4).frame(minHeight: 52)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(searching ? Color.blue : Color.primary.opacity(0.08), lineWidth: searching ? 2 : 1)
        }
    }

    private var searchActions: some View {
        HStack(spacing: 0) {
            if !query.isEmpty {
                navigationButton("Clear search", symbol: "xmark.circle.fill", identifier: "clearSearch") { query = "" }
                    .foregroundStyle(.secondary)
            }
            navigationButton("Go", symbol: "arrow.right.circle.fill", identifier: "submitSearch", action: openSearch)
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var cancelButton: some View {
        Button(action: cancelSearch) {
            if textSize.isAccessibilitySize {
                Image(systemName: "xmark.circle.fill").font(.system(size: 22)).frame(width: 44, height: 44)
            } else {
                Text("Cancel").frame(minHeight: 44)
            }
        }.accessibilityLabel("Cancel").accessibilityIdentifier("cancelSearch")
    }

    private var reloadButton: some View {
        navigationButton(browser.isLoading ? "Stop loading" : "Reload",
                         symbol: browser.isLoading ? "xmark" : "arrow.clockwise", identifier: "reloadPage") {
            if browser.isLoading { browser.stopLoading() }
            else { browser.reload() }
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 8) {
            navigationButton("Back", symbol: "chevron.left", identifier: "browserBack") { browser.goBack(); syncAddress() }
                .disabled(!browser.canNavigateBack)
            Spacer(minLength: 0)
            navigationButton("Forward", symbol: "chevron.right", identifier: "browserForward") { browser.goForward() }
                .disabled(!browser.canGoForward || browser.showsStartPage)
            Spacer(minLength: 0)
            navigationButton("Home", symbol: "house", identifier: "browserHome") { browser.showStartPage(); query = "" }
                .disabled(browser.showsStartPage)
            Spacer(minLength: 0)
            shareButton
            Spacer(minLength: 0)
            moreMenu
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var shareButton: some View {
        if let url = browser.pageURL {
            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 20, weight: .medium))
                    .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
                .accessibilityLabel("Share page").accessibilityIdentifier("sharePage")
                .disabled(browser.showsStartPage)
        } else {
            navigationButton("Share page", symbol: "square.and.arrow.up", identifier: "sharePage") {}.disabled(true)
        }
    }

    private func navigationButton(_ title: String, symbol: String, identifier: String,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 20, weight: .medium))
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
            .accessibilityLabel(title).accessibilityIdentifier(identifier)
    }

    private var moreMenu: some View {
        Menu {
            Button("Playback destination", systemImage: "airplay.audio") { showingRoutes = true }
            Button("Copy page link", systemImage: "link") { UIPasteboard.general.url = browser.pageURL }
                .disabled(browser.pageURL == nil)
            privacyPolicyLink
            Divider()
            Button("Clear website data", systemImage: "trash", role: .destructive) { confirmingClear = true }
        } label: {
            Image(systemName: "ellipsis.circle").font(.system(size: 20, weight: .medium))
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .accessibilityLabel("More browser actions").accessibilityIdentifier("browserMore")
    }

    @ViewBuilder private var privacyPolicyLink: some View {
        if let url = URL(string: Bundle.main.object(forInfoDictionaryKey: "CabinViewPrivacyPolicyURL") as? String ?? ""),
           url.scheme == "https" {
            Link(destination: url) { Label("Privacy policy", systemImage: "hand.raised") }
        } else {
            Button("Privacy policy", systemImage: "hand.raised") {}.disabled(true)
        }
    }

    @ViewBuilder private var errorBanner: some View {
        if let message = browser.errorMessage {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle").accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(message).font(.callout)
                    if browser.hasPage { Button("Try again") { browser.reload() } }
                }
                Spacer(minLength: 0)
                Button { browser.errorMessage = nil } label: {
                    Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Dismiss error")
            }
            .padding(16).background(Color(.secondarySystemGroupedBackground))
            .accessibilityIdentifier("browserError")
        }
    }

    @ViewBuilder private var clearingProgress: some View {
        if browser.isClearingWebsiteData {
            ProgressView("Clearing website data…")
                .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func openSearch() {
        browser.open(query)
        searching = false
    }

    private func cancelSearch() {
        searching = false
        syncAddress()
    }

    private func syncAddress() { query = browser.showsStartPage ? "" : browser.currentAddress }
    private func resumeBrowsing() { browser.resumePage(); syncAddress() }
}

private struct BrowserSurface: UIViewRepresentable {
    let browser: BrowserCoordinator
    func makeUIView(context: Context) -> WKWebView { browser.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}

private struct PlaybackDestinationView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "airplay.audio").font(.system(size: 40)).foregroundStyle(.blue)
                Text("Playback destination").font(.title2.bold())
                Text("Start media on the website, then choose an available destination below or in its player.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                RoutePickerView().frame(width: 64, height: 64)
            }
            .padding(32)
            .toolbar { Button("Done") { dismiss() } }
        }.presentationDetents([.medium, .large])
    }
}

private struct RoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = .label
        picker.activeTintColor = .systemBlue
        return picker
    }
    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}
