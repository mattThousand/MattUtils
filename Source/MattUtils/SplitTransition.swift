//
//  SplitTransition.swift
//  MattUtils
//
//  Created by Matthew Buckley on 12/7/15.
//  Copyright © 2015 Matt Buckley. All rights reserved.
//

import UIKit

final public class SplitTransition: UIPercentDrivenInteractiveTransition {

    /**
     The type of transition.

     - Push: A push transition.
     - Pop:  A pop transition.
     - Interactive:  An interactive transition.
     */
    public enum TransitionType {
        case Push
        case Pop
        case Interactive
    }

    /**
     The progress state of the transition.

     - Initial: transition has not begun.
     - Finished:  transition is complete.
     - Cancelled:  transition has been cancelled.
     */
    enum TransitionState {
        case Initial
        case Finished
        case Cancelled
    }

    /// The duration (in seconds) of the transition.
    public var transitionDuration: NSTimeInterval = 1.0

    /// The delay before/after the transition (in seconds).
    public var transitionDelay: NSTimeInterval = 0.0

    /// Animation type (e.g. push/pop). Defaults to "push".
    public var transitionType: TransitionType = .Push

    /// Y coordinate where top and bottom screen captures should split.
    public var splitLocation = CGFloat(0.0)

    /// Screen capture extending from split location to top of screen
    lazy var topSplitImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = self.screenCapture
        imageView.contentMode = .Top
        imageView.clipsToBounds = true
        return imageView
    }()

    /// Screen capture extending from split location to bottom of screen
    lazy var bottomSplitImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = self.screenCapture
        imageView.contentMode = .Bottom
        imageView.clipsToBounds = true
        return imageView
    }()

    /**
     In an interactive transition, splitOffset
     determines the vertical distance of the initial
     split when the cell is first tapped.
     */
    public var splitOffset = CGFloat(0.0)

    /// Scroll distance in UI points.
    var interactiveTransitionScrollDistance = CGFloat(0.0)

    /// State of interactive transition.
    var transitionState: TransitionState = .Initial {
        didSet {
            switch transitionState {
            case .Initial:
                break
            case .Finished:
                break
            case .Cancelled:
                fromVC?.navigationController?.navigationBarHidden = false
                fromVC?.navigationController?.delegate = initialNavigationControllerDelegate
                previousTouchLocation = nil
            }
        }
    }

    /// Transition progress in UIPoints (essentially, distance scrolled from splitLocation)
    private var transitionProgress = CGFloat(0.0) {
        didSet {
            /// Calculate how much of the bottom and top screenshots have been scrolled off-screen
            let bottomHeight = bottomSplitImageView.bounds.size.height
            let topHeight = topSplitImageView.bounds.size.height

            let bottomPctComplete = max(transitionProgress / bottomHeight,
                0.0)
            let topPctComplete = max(transitionProgress / topHeight,
                0.0)

            /// Set new transforms for top and bottom imageViews
            topSplitImageView.transform = CGAffineTransformMakeTranslation(0.0,
                -(topPctComplete * topHeight))
            bottomSplitImageView.transform = CGAffineTransformMakeTranslation(0.0,
                (bottomPctComplete * bottomHeight))
        }
    }

    /**
     For interactive transition, reflects whether
     the current pan is the first one (necessary to correctly
     manage transition progress vis a vis initial offset)
     */
    private var initialPan = true

    /// Stores a gesture recognizer (interactive transition only)
    private var gestureRecognizer: UIPanGestureRecognizer?

    /// Current transition context
    private var transitionContext: UIViewControllerContextTransitioning?

    /// Stores the location of the most recent touch (interactive transition only)
    private var previousTouchLocation: CGPoint?

    /// Transition container view
    private var container: UIView?

    /// Destination view controller for current transition
    private var toVC: UIViewController?

    /// Origin view controller for current transition
    private var fromVC: UIViewController?

    /// Completion for the current transition
    private var completion: (() -> ())?

    /// Optional capture of entire screen
    var screenCapture: UIImage?


    /// The previous UINavigationControllerDelegate of the origin view controller
    var initialNavigationControllerDelegate: UINavigationControllerDelegate?

    public convenience init(transitionDuration: NSTimeInterval,
        transitionType: TransitionType,
        initialNavigationControllerDelegate: UINavigationControllerDelegate?) {
            self.init()
            self.transitionDuration = transitionDuration
            self.transitionType = transitionType
            self.initialNavigationControllerDelegate = initialNavigationControllerDelegate
    }

    func didPan(gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .Began:
            break
        case .Changed:
            panGestureDidChange(gesture: gesture)
            updateTransitionState()
        case .Ended:
            initialPan = false
            previousTouchLocation = nil
        default:
            break
        }
    }

    public override func startInteractiveTransition(transitionContext: UIViewControllerContextTransitioning) {
        setupTransition(transitionContext)
    }

}

extension SplitTransition: UIViewControllerAnimatedTransitioning {

    public func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return transitionDuration
    }

    public func animateTransition(transitionContext: UIViewControllerContextTransitioning) {

        setupTransition(transitionContext)

        guard let fromVC = fromVC,
            toVC = toVC,
            container = container,
            completion = completion else {
                print("animation setup failed")
                return
        }

        gestureRecognizer = UIPanGestureRecognizer(target: self, action: "didPan:")
        if let gestureRecognizer = gestureRecognizer {
            gestureRecognizer.delegate = self
            fromVC.view.window?.addGestureRecognizer(gestureRecognizer)
        }

        switch transitionType {
        case .Push:
            push(toViewController: toVC, fromViewController: fromVC, containerView: container, completion: completion)
            break
        case .Pop:
            pop(toVC, fromViewController: fromVC, containerView: container, completion: completion)
            break
        case .Interactive:
            push(splitOffset, toViewController: toVC, fromViewController: fromVC, containerView: container, completion: nil)
            break
        }
    }

}

private extension SplitTransition {

    // MARK: private interface

    func animatePush(toOffset toOffset: CGFloat,
        animations: (() -> ())?,
        completion: (() -> ())?) -> Void {

            /// Set animation options
            let options: UIViewAnimationOptions = transitionType == .Interactive ? .AllowUserInteraction : .LayoutSubviews

            UIView.animateWithDuration(transitionDuration,
                delay: 0.0,
                usingSpringWithDamping: 0.65,
                initialSpringVelocity: 1.0,
                options: options,
                animations: { () -> Void in
                    animations?()
                }) { [weak self] (Bool) -> Void in
                    /// When the transition is finished, top and bottom
                    /// split views are removed from the view hierarchy
                    if let controller = self {
                        if !(controller.transitionType == .Interactive) {
                            controller.topSplitImageView.removeFromSuperview()
                            controller.bottomSplitImageView.removeFromSuperview()
                        }
                        /// If a completion was passed as a parameter,
                        /// execute it
                        completion?()
                    }

            }
    }

    func panGestureDidChange(gesture gesture: UIPanGestureRecognizer) -> Void {
        /// Continue tracking touch location
        let currentTouchLocation = gesture.locationInView(container)

        /// Calculate distance between current touch location and previous
        /// touch location
        var distanceMoved = CGFloat(0.0)

        if let previousTouchLocation = previousTouchLocation {
            distanceMoved = currentTouchLocation.y - previousTouchLocation.y
        }
        else {
            distanceMoved = initialPan ? splitOffset : 0.0
        }

        /// Update transition progress
        transitionProgress += (abs(currentTouchLocation.y - splitLocation) / splitLocation)

        /// Update interactive transition
        let percentComplete = max((transitionProgress / interactiveTransitionScrollDistance), 0.0)

        /// Update 'previousTouchLocation'
        previousTouchLocation = currentTouchLocation

        /// Increment 'transitionProgress' by calculated distance
        transitionProgress += distanceMoved

        /// Update transition
        transitionContext?.updateInteractiveTransition(percentComplete)

        if percentComplete >= 1.0 {
            transitionState = .Finished
        }
        else if percentComplete == 0.0 {
            transitionState = .Cancelled
        }
    }

    func updateTransitionState() -> Void {
        switch transitionState {
        case .Finished:
            /// split views are removed from the view hierarchy
            topSplitImageView.removeFromSuperview()
            bottomSplitImageView.removeFromSuperview()

            completion?()

            /// Make destination view controller's view visible
            toVC?.view.alpha = 1.0
            fromVC?.view.alpha = 0.0
        case .Cancelled:
            /// split views are removed from the view hierarchy
            topSplitImageView.removeFromSuperview()
            bottomSplitImageView.removeFromSuperview()

            /// Cancel transition
            cancelInteractiveTransition()

            completion?()

            /// Make source view controller's view visible again
            toVC?.view.alpha = 0.0
            fromVC?.view.alpha = 1.0
        default:
            break
        }
    }

    /// Returns the view controller being navigated away from
    func fromViewController(transitionContext: UIViewControllerContextTransitioning?) -> UIViewController? {
        return transitionContext?.viewControllerForKey(UITransitionContextFromViewControllerKey)
    }

    /// Returns the view controller being navigated to
    func toViewController(transitionContext: UIViewControllerContextTransitioning?) -> UIViewController? {
        return transitionContext?.viewControllerForKey(UITransitionContextToViewControllerKey)
    }

    /// Returns the container view for the transition context
    func containerView(transitionContext: UIViewControllerContextTransitioning?) -> UIView? {
        return transitionContext?.containerView()
    }

    func setupTransition(transitionContext: UIViewControllerContextTransitioning?) -> Void {
        /// Take screenshot and store resulting UIImage
        screenCapture = UIWindow.screenShot()

        /// Grab the view in which the transition should take place.
        /// Coalesce to UIView()
        container = containerView(transitionContext) ?? UIView()

        /// Set source and destination view controllers
        fromVC = fromViewController(transitionContext) ?? UIViewController()
        toVC = toViewController(transitionContext) ?? UIViewController()
        toVC?.navigationController?.navigationBarHidden = true

        /// Set completion handler for transition
        completion = {
            let complete: Bool = transitionContext?.transitionWasCancelled() ?? false
            /// Remove gesture recognizer from view
            if let gestureRecognizer = self.gestureRecognizer {
                gestureRecognizer.view?.removeGestureRecognizer(gestureRecognizer)
            }

            /// Complete the transition
            transitionContext?.completeTransition(!complete)
            transitionContext?.finishInteractiveTransition()
        }
    }

    /// Push Transition
    func push(toOffset: CGFloat = 0.0,
        toViewController: UIViewController,
        fromViewController: UIViewController,
        containerView: UIView,
        completion: (() -> ())?) {
            /// Add subviews
            containerView.addSubview(toViewController.view)
            containerView.addSubview(topSplitImageView)
            containerView.addSubview(bottomSplitImageView)

            /// Set initial frames for screen captures
            setInitialScreenCaptureFrames(containerView)

            /// source view controller is initially hidden
            fromViewController.view.alpha = 0.0
            toViewController.view.alpha = 1.0
            toViewController.view.transform = CGAffineTransformMakeTranslation(0.0, topSplitImageView.frame.size.height)

            /// Animate all the way or only partially if a toOffset parameter is passed in
            let targetOffsetTop = toOffset != 0.0 ? -toOffset : -topSplitImageView.bounds.size.height
            let targetOffsetBottom = toOffset != 0.0 ? toOffset : bottomSplitImageView.bounds.size.height

            let animations = { [weak self] in
                self?.topSplitImageView.transform = CGAffineTransformMakeTranslation(0.0, targetOffsetTop)
                self?.bottomSplitImageView.transform = CGAffineTransformMakeTranslation(0.0, targetOffsetBottom)
                toViewController.view.transform = CGAffineTransformIdentity
            }

            animatePush(toOffset: toOffset,
                animations: animations,
                completion: completion)
    }

    /// Pop Transition
    func pop(toViewController: UIViewController,
        fromViewController: UIViewController,
        containerView: UIView,
        completion: (() -> ())?) {

            /// Add subviews
            containerView.insertSubview(toViewController.view, belowSubview: fromViewController.view)
            containerView.addSubview(toViewController.view)
            containerView.addSubview(topSplitImageView)
            containerView.addSubview(bottomSplitImageView)

            /// Destination view controller is initially hidden
            toViewController.view.alpha = 0.0

            /// Set initial transforms for top and bottom split views
            topSplitImageView.transform = CGAffineTransformMakeTranslation(0.0, -topSplitImageView.bounds.size.height)
            bottomSplitImageView.transform = CGAffineTransformMakeTranslation(0.0, bottomSplitImageView.bounds.size.height)

            UIView.animateWithDuration(transitionDuration, delay: 0.0, usingSpringWithDamping: 0.65, initialSpringVelocity: 1.0, options: .LayoutSubviews, animations: { [weak self] () -> Void in
                if let controller = self {
                    /// Restore the top and bottom screen captures to their original positions
                    controller.topSplitImageView.transform = CGAffineTransformIdentity
                    controller.bottomSplitImageView.transform = CGAffineTransformIdentity

                    /// Restore fromVC's view to its original position
                    fromViewController.view.transform = CGAffineTransformMakeTranslation(0.0, controller.topSplitImageView.bounds.size.height)
                }
                }) { [weak self] (Bool) -> Void in
                    /// When the transition is finished, top and bottom split views are removed from the view hierarchy
                    if let controller = self {
                        controller.topSplitImageView.removeFromSuperview()
                        controller.bottomSplitImageView.removeFromSuperview()
                    }

                    /// Make destination view controller's view visible again
                    toViewController.view.alpha = 1.0
                    toViewController.navigationController?.navigationBarHidden = false
                    toViewController.navigationController?.delegate = self?.initialNavigationControllerDelegate

                    /// If a completion was passed as a parameter, execute it
                    completion?()
            }
    }

    func setInitialScreenCaptureFrames(containerView: UIView) {

        /// Set bounds for top and bottom screen captures
        let width = containerView.frame.size.width ?? 0.0
        let height = containerView.frame.size.height ?? 0.0

        /// Top screen capture extends from split location to top of view
        topSplitImageView.frame = CGRectMake(0.0, 0.0, width, splitLocation)

        /// Bottom screen capture extends from split location to bottom of view
        bottomSplitImageView.frame = CGRectMake(0.0, splitLocation, width, height - splitLocation)

        /// Store a distance figure to use to calculate percent complete for
        /// the interactive transition
        interactiveTransitionScrollDistance = max(topSplitImageView.bounds.size.height, bottomSplitImageView.bounds.size.height)
    }

}

extension SplitTransition: UIGestureRecognizerDelegate {

    public func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {

        let location = gestureRecognizer.locationInView(container)
        let presentationLayer = container?.layer.presentationLayer()

        if (presentationLayer?.hitTest(location)) != nil {
            return true
        }
        return false
    }

}

extension SplitTransition: UIViewControllerTransitioningDelegate {

    public func interactionControllerForPresentation(animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return transitionType == .Interactive ? self : nil
    }
    
    public func interactionControllerForDismissal(animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return transitionType == .Interactive ? self : nil
    }
    
}
