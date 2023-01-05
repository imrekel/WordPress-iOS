import Foundation

@objc
extension PeopleViewController {
    static func withJPBannerForBlog(_ blog: Blog) -> UIViewController? {
        guard let peopleViewVC = PeopleViewController.controllerWithBlog(blog) else {
            return nil
        }
        guard JetpackBrandingCoordinator.shouldShowBannerForJetpackDependentFeatures() else {
            return peopleViewVC
        }
        return JetpackBannerWrapperViewController(childVC: peopleViewVC, analyticsId: .people)
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let jetpackBannerWrapper = parent as? JetpackBannerWrapperViewController {
            jetpackBannerWrapper.processJetpackBannerVisibility(scrollView)
        }
    }
}
