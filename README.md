<p align="center">
  <img src="CabinView/Assets.xcassets/CabinViewLogo.imageset/CabinViewLogo3x.png" width="112" alt="CabinView logo">
</p>

<h1 align="center">CabinView</h1>
<p align="center"><strong>The web, in view.</strong><br>A focused iPhone browser built with SwiftUI and WebKit.</p>

CabinView brings search, browsing, and website media into a simple native interface. Open a website, keep your sessions between visits, and move around with familiar controls that stay within reach.

## Features

- **Search or browse** — enter a search term or website address in one field. Searches use Google, and web addresses use HTTPS.
- **Familiar navigation** — go back, go forward, reload, stop loading, or return home without losing your current page.
- **Persistent sessions** — WebKit stores website cookies and sign-ins on the device between visits.
- **Share and copy links** — use the system share sheet or copy the current address.
- **Playback destinations** — choose an available system playback destination for supported website media.
- **CarPlay companion** — open a native CarPlay menu and the system Now Playing screen.
- **Control website data** — clear CabinView’s website sessions with confirmation.
- **Native accessibility** — support for larger text, VoiceOver labels, dark appearance, and Reduce Motion.

## CarPlay and website playback

Browsing takes place on the iPhone. The CarPlay interface provides a native menu and access to system playback controls. Choose content and start playback on the iPhone while safely parked.

Website providers control embedded sign-in, media playback, and background behavior. Available playback destinations depend on the website and connected hardware. CabinView does not display arbitrary webpages on the CarPlay screen or add video support to a vehicle.

## Getting started

You’ll need **Xcode 27 or later** and an **iOS 27 or later** simulator or iPhone. The app uses Apple frameworks and has no third-party runtime dependencies.

1. Open `CabinView.xcodeproj` in Xcode.
2. Select the **CabinView** scheme and an iPhone simulator.
3. Build and run.

For a physical device, configure your own signing team and unique app identifiers for the app and test targets in Xcode. CarPlay device builds also require Apple’s approval and a provisioning profile with the appropriate CarPlay capability.

## Development

The project uses SwiftUI for the interface, WebKit for browsing and website storage, AVKit for the playback destination picker, and CarPlay for the companion interface.

| Location | Purpose |
| --- | --- |
| `CabinView/` | App interface, browser logic, launch experience, and CarPlay integration |
| `Config/` | App configuration and capability declarations |
| `CabinViewTests/` | Address handling, website sessions, and app configuration tests |
| `CabinViewUITests/` | Browser controls, navigation, accessibility, and confirmation flows |

Run the test suite with **Product → Test** in Xcode, or from the project directory:

```sh
xcodebuild test \
  -project CabinView.xcodeproj \
  -scheme CabinView \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
```

Choose an installed iPhone simulator if that device name differs on your machine. The website navigation smoke test requires internet access.

If SwiftLint is installed:

```sh
swiftlint lint --config .swiftlint.yml --no-cache --strict
```

## Privacy

CabinView has no app account, analytics SDK, or advertising SDK. Searches are sent to Google, and websites receive browsing requests under their own policies. WebKit keeps website data on the device; use **More → Clear website data** to remove it.

The **Privacy policy** menu item opens [CabinView’s privacy policy](https://cabinview.kodlabs.in/privacy). Its HTTPS URL is configured by `CabinViewPrivacyPolicyURL` in `Config/Info.plist`. For support, visit [Contact us](https://cabinview.kodlabs.in/contact).

## Contributing

Bug reports and focused improvements are welcome. Include steps to reproduce issues and describe the expected behavior. Keep changes small, run the relevant tests, and avoid including personal data, credentials, signing files, or device logs containing private information.
