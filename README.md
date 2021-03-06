# MattUtils
My favorite tools

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/mattthousand/mattutils)

## Installation with Carthage

Carthage is a decentralized dependency manager that automates the process of adding frameworks to your Cocoa application.

You can install Carthage with Homebrew using the following command:

```
$ brew update
$ brew install carthage
```

To integrate MattUtils into your Xcode project using Carthage, specify it in your Cartfile:

`github "mattthousand/MattUtils"`

## Installation with CocoaPods

... Coming soon.

## Usage

First, make sure you import the MattUtils module: `import MattUtils`.

The rest is easy. If you are pushing a view controller to the navigation stack, follow these three steps:

- Set your navigation controller's delegate :

```
navigationController?.delegate = self
```
- Store the transition on your view controller:

```
var currentTransition: UIViewControllerAnimatedTransitioning?
``` 

- Extend your view controller to implement `UINavigationControllerDelegateTransitioning`. In your implementation, make sure to set the `currentTransition`:

```
extension ViewController: UINavigationControllerDelegate {

    func navigationController(navigationController: UINavigationController,
        animationControllerForOperation operation: UINavigationControllerOperation,
        fromViewController fromVC: UIViewController,
        toViewController toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {

        if (operation == .Push && fromVC == self) {
			/*
			* set currentTransition here
        	*/
        }
        else if (operation == .Pop && toVC == self) {
        }

        return currentTransition
    }

}

```


## What's Inside

### SplitAnimation


<p align="center" >
<br/>
<img src="https://raw.github.com/mattthousand/mattutils/master/SplitTransition.gif" alt="Overview" />
<br/>
</p>

`SplitAnimation` exposes 4 key properties: 

1. `splitLocation` (optional, defaults to `0.0`) - y coordinate where the top and bottom views part
2. `transitionDuration` (optional, defaults to `1.0`) - duration (in seconds) of the transition animation 
3. `transitionDelay` (optional, defaults to `0.0`) - delay (in seconds) before the start of the transition animation
4. `transitionType` (optional, defaults to `.Push`) - `.Push` or `.Pop`

Set these properties in your implementation of	`UINavigationControllerDelegateTransitioning`:

```
func navigationController(navigationController: UINavigationController,
    animationControllerForOperation operation: UINavigationControllerOperation,
    fromViewController fromVC: UIViewController,
    toViewController toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {

    if (operation == .Push && fromVC == self) {
        let splitTransition = SplitTransitionController()
        splitTransition.transitionDuration = 2.0
        splitTransition.transitionType = .Push
        splitTransition.splitLocation = currentCell != nil ? CGRectGetMidY(currentCell!.frame) : CGRectGetMidY(view.frame)
        currentTransition = splitTransition
    }
    else if (operation == .Pop && toVC == self) {
        currentTransition?.transitionType = .Pop
    }

    return currentTransition
}
```
