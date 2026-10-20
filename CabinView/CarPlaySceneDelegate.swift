import CarPlay

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didConnect controller: CPInterfaceController) {
        interfaceController = controller
        let browse = CPListItem(text: "Browse on your iPhone", detailText: "Search for a website and start its media player.")
        browse.isEnabled = false
        let nowPlaying = CPListItem(text: "Now Playing", detailText: "Open the system playback controls")
        nowPlaying.handler = { [weak self] _, completion in
            guard let controller = self?.interfaceController else { completion(); return }
            controller.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { _, _ in completion() }
        }
        let template = CPListTemplate(title: "CabinView", sections: [CPListSection(items: [browse, nowPlaying])])
        controller.setRootTemplate(template, animated: false) { _, error in
            guard let error else { return }
            BrowserCoordinator.shared.errorMessage = "CarPlay could not open its interface: \(error.localizedDescription)"
        }
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didDisconnectInterfaceController controller: CPInterfaceController) {
        guard interfaceController === controller else { return }
        interfaceController = nil
    }
}
