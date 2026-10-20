import Testing
import WebKit
@testable import CabinView

struct BrowserAddressTests {
    @Test(arguments: ["example.com", "http://example.com", "https://example.com", "example.com:443/path", "  example.com  "])
    func opensHTTPS(_ input: String) throws {
        let url = try #require(BrowserAddress.destination(for: input))
        #expect(url.scheme == "https")
        #expect(url.host == "example.com")
    }

    @Test(arguments: ["", "   ", "javascript:alert(1)", "file:///tmp/private", "data:text/html,test", "https://", "https://user:password@example.com"])
    func rejectsUnsafeAddresses(_ input: String) {
        #expect(BrowserAddress.destination(for: input) == nil)
    }

    @Test(arguments: ["youtube", "best music today", "things & places", "Hindi हिंदी", "user@example.com", "site:youtube.com music", "site:youtube.com", "weather: tomorrow"])
    func preservesSearchQuery(_ input: String) throws {
        let url = try #require(BrowserAddress.destination(for: input))
        #expect(url.host == "www.google.com")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.first?.value == input)
    }
}

@MainActor @Suite(.serialized)
struct BrowserSessionTests {
    private let dataStoreID = UUID()

    private func coordinator() -> BrowserCoordinator {
        BrowserCoordinator(websiteDataStore: WKWebsiteDataStore(forIdentifier: dataStoreID))
    }

    private func cookie(named name: String) throws -> HTTPCookie {
        try #require(HTTPCookie(properties: [.domain: "cabinview-session.invalid", .path: "/", .name: name,
                                           .value: "retained", .secure: "TRUE", .expires: Date().addingTimeInterval(3600)]))
    }

    @Test func sessionsSurviveCoordinatorRecreation() async throws {
        let first = coordinator()
        let session = try cookie(named: "persistent-session")
        await first.webView.configuration.websiteDataStore.httpCookieStore.setCookie(session)
        let second = coordinator()
        let cookies = await second.webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        #expect(second.webView.configuration.websiteDataStore.isPersistent)
        #expect(second.webView.configuration.websiteDataStore !== WKWebsiteDataStore.default())
        #expect(cookies.contains { $0.name == session.name && $0.value == session.value })
        await second.webView.configuration.websiteDataStore.httpCookieStore.deleteCookie(session)
    }

    @Test func clearingDataRemovesSessionsAndReturnsHome() async throws {
        let browser = coordinator()
        let session = try cookie(named: "clear-session")
        let store = browser.webView.configuration.websiteDataStore.httpCookieStore
        await store.setCookie(session)
        browser.open("https://example.com")
        browser.stopLoading()
        await browser.clearWebsiteData()
        let cookies = await store.allCookies()
        #expect(!cookies.contains { $0.name == session.name })
        #expect(browser.showsStartPage)
        #expect(!browser.hasPage)
        #expect(browser.currentAddress.isEmpty)
        #expect(browser.pageURL == nil)
        #expect(!browser.isClearingWebsiteData)
    }

    @Test func homeAndBackPreserveThePageAndSession() async throws {
        let browser = coordinator()
        let session = try cookie(named: "home-session")
        let store = browser.webView.configuration.websiteDataStore.httpCookieStore
        await store.setCookie(session)
        browser.open("https://example.com/retained")
        browser.stopLoading()
        browser.showStartPage()
        #expect(browser.showsStartPage)
        #expect(browser.canNavigateBack)
        browser.goBack()
        #expect(!browser.showsStartPage)
        #expect(browser.pageURL?.path == "/retained")
        let cookies = await store.allCookies()
        #expect(cookies.contains { $0.name == session.name })
        await store.deleteCookie(session)
    }

    @Test func unsafeInputDoesNotNavigate() {
        let browser = coordinator()
        browser.open("javascript:alert(1)")
        #expect(browser.errorMessage != nil)
        #expect(!browser.hasPage)
        #expect(browser.showsStartPage)
        #expect(browser.webView.url == nil)
    }
}

struct AppConfigurationTests {
    @Test func productAndBundleNamesMatch() {
        #expect(Bundle.main.bundleIdentifier?.isEmpty == false)
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String == "CabinView")
        #expect(Bundle.main.bundleURL.lastPathComponent == "CabinView.app")
    }

    @Test func carPlaySceneIsPresentInBuiltApp() throws {
        let manifest = try #require(Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") as? [String: Any])
        let configurations = try #require(manifest["UISceneConfigurations"] as? [String: Any])
        let carPlay = try #require(configurations["CPTemplateApplicationSceneSessionRoleApplication"] as? [[String: Any]])
        #expect(carPlay.first?["UISceneClassName"] as? String == "CPTemplateApplicationScene")
        #expect(carPlay.first?["UISceneDelegateClassName"] as? String == "CabinView.CarPlaySceneDelegate")
        #expect(NSClassFromString("CabinView.CarPlaySceneDelegate") != nil)
    }
}
