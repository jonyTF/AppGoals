//
//  ShareViewController.swift
//  ShareExtension
//
//  Receives a RevenueCat URL shared from Safari, extracts the project ID, and
//  hands it to the main app via the shared App Group so the user doesn't have to
//  copy/paste it into the setup screen.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let card = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        buildUI()
        extractSharedURL()
    }

    // MARK: Extraction

    private func extractSharedURL() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = item.attachments, !providers.isEmpty else {
            return finish(projectID: nil)
        }

        let urlType = UTType.url.identifier
        let textType = UTType.text.identifier

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] value, _ in
                let url = (value as? URL) ?? ((value as? NSURL) as URL?)
                self?.finish(projectID: ProjectURLParser.projectID(from: url))
            }
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] value, _ in
                self?.finish(projectID: ProjectURLParser.projectID(from: value as? String))
            }
        } else {
            finish(projectID: nil)
        }
    }

    private func finish(projectID: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let projectID {
                AppGroupConfig.defaults.set(projectID, forKey: AppGroupConfig.DefaultsKey.pendingProjectID)
                self.show(success: true, projectID: projectID)
            } else {
                self.show(success: false, projectID: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (projectID == nil ? 1.6 : 1.1)) {
                self.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    // MARK: UI

    private func buildUI() {
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .systemBlue
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(card)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),

            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func show(success: Bool, projectID: String?) {
        iconView.image = UIImage(systemName: success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        iconView.tintColor = success ? .systemGreen : .systemOrange
        if success {
            titleLabel.text = "Project sent to AppGoals"
            detailLabel.text = "Project ID \(projectID ?? "") is ready. Open AppGoals to finish setup."
        } else {
            titleLabel.text = "Couldn't find a project ID"
            detailLabel.text = "Share a RevenueCat project page URL (it contains /projects/<id>)."
        }
    }
}
