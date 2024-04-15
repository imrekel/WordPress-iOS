import Foundation
import Combine
import DesignSystem

final class SubmitFeedbackViewController: UIViewController {

    // MARK: - Public Properties

    private(set) var feedbackWasSubmitted = false

    var onFeedbackSubmitted: ((SubmitFeedbackViewController, String) -> Void)?

    // MARK: - Private Properties

    private let textView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = WPStyleGuide.fontForTextStyle(.body)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .init(allEdges: .DS.Padding.double)
        return textView
    }()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.setupSubviews()
        self.textView.becomeFirstResponder()
        WPAnalytics.track(.appReviewsOpenedFeedbackScreen)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard !feedbackWasSubmitted else {
            return
        }
        WPAnalytics.track(.appReviewsCanceledFeedbackScreen)
    }

    // MARK: - Setup Views

    private func setupSubviews() {
        self.setupNavigationItems()
        self.setupTextView()
    }

    private func setupNavigationItems() {
        let navBarAppearance = self.navigationController?.navigationBar.standardAppearance
        let cancel = UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }
        self.navigationItem.rightBarButtonItem = .init(
            title: Strings.submit,
            style: .done,
            target: self,
            action: #selector(didTapSubmit)
        )
        self.navigationItem.leftBarButtonItem = .init(systemItem: .cancel, primaryAction: cancel)
        self.navigationItem.title = Strings.title
        self.navigationItem.scrollEdgeAppearance = navBarAppearance
        self.navigationItem.compactScrollEdgeAppearance = navBarAppearance
    }

    private func setupTextView() {
        self.textView.delegate = self
        self.view.addSubview(textView)
        NSLayoutConstraint.activate([
            self.textView.topAnchor.constraint(equalTo: view.topAnchor),
            self.textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            self.textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            self.textView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        self.updateSubmitNavigationItem(text: textView.text)
    }

    // MARK: - Updating UI

    func updateSubmitNavigationItem(text: String?) {
        let text = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.navigationItem.rightBarButtonItem?.isEnabled = !text.isEmpty
    }

    // MARK: - User Interaction

    @objc private func didTapSubmit() {
        let text = textView.text ?? ""
        let tags = ["appreview_jetpack", "in_app_feedback"]

        SVProgressHUD.show(withStatus: Strings.submitLoadingMessage)

        let options = ZendeskUtils.IdentityAlertOptions(
            optionalIdentity: true,
            includesName: true,
            message: Strings.identityAlertMessage,
            submit: Strings.identityAlertSubmit,
            cancel: Strings.identityAlertCancel
        )

        ZendeskUtils.sharedInstance.createNewRequest(in: self, alertOptions: options, description: text, tags: tags) { [weak self] result in
            guard let self else { return }

            let completion = {
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    WPAnalytics.track(.appReviewsSentFeedback, withProperties: ["feedback": text])
                    self.feedbackWasSubmitted = true
                    self.view.endEditing(true)
                    self.dismiss(animated: true) {
                        self.onFeedbackSubmitted?(self, text)
                    }
                }
            }

            switch result {
            case .success:
                completion()
            case .failure(let error):
                DDLogError("Submitting feedback failed: \(error)")
                completion()
            }
        }
    }
}

extension SubmitFeedbackViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        updateSubmitNavigationItem(text: textView.text)
    }
}

// MARK: - Strings

private extension SubmitFeedbackViewController {

    enum Strings {
        static let submit = NSLocalizedString(
            "submit.feedback.submit.button",
            value: "Submit",
            comment: "The button title for the Submit button in the In-App Feedback screen"
        )
        static let title = NSLocalizedString(
            "submit.feedback.title",
            value: "Feedback",
            comment: "The title for the the In-App Feedback screen"
        )

        static let submitLoadingMessage = NSLocalizedString(
            "submit.feedback.submit.loading",
            value: "Submitting...",
            comment: "Notice informing user that their feedback is being submitted."
        )

        static let identityAlertMessage = NSLocalizedString(
            "submit.feedback.alert.message",
            value: "Would you share your email address and name so we can follow up on your feedback?",
            comment: "Alert users are shown when submtiting their feedback."
        )

        static let identityAlertSubmit = NSLocalizedString(
            "submit.feedback.alert.submit",
            value: "OK",
            comment: "Alert submit option for users to accept sharing their email and name when submitting feedback."
        )

        static let identityAlertCancel = NSLocalizedString(
            "submit.feedback.alert.cancel",
            value: "No, thanks",
            comment: "Alert cancel option for users to not accept sharing their email and name when submitting feedback."
        )
    }
}
