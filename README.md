# UserActionResponder
A swift class for performing actions based on app launches and significant events.

## About
Now that Apple has made SKStoreReviewController, we need a way to know when to call it.  With `UserActionResponder`, in a couple of lines of code, we can ask the user for a review (or do anything else we want) after a certain number of launches, significant events, or time since the last update.  There is a setting that causes the criteria to be reset on updates.

## Requirements

* Xcode 8
* Swift 3.1
* iOS 10.0+

## Features

### Triggers
* App launch
* App activation (background -> foreground)
* Significant events (as many as you want)
* Days since install/update

### Configuration
* Can reset after an app update
* Can trigger repeatedly or just once
* Can trigger when all criteria match, or when any criteria match
* Can specify which DispatchQueue on which you are called back

### Persistence
* Data is stored in UserDefaults
* You can supply the user defaults key to use

## Usage

### Basic

````swift
// AppDelegate.swift
let responder = UserActionResponder()     // Keep this handy so you can call other functions

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

  responder.when(.one(criteria:[.launch(count:5), .activated(count:5)]) { _ in
   if #available(iOS 10.3, *) {
       SKStoreReviewController.requestReview()
   } else {
       print("Skipping review requesting due to OS version")
   }
  })

  return true
}
````

### Explicit criteria
````swift
 var criteria:[UserActionResponder.Criterion] = []

 criteria.append(.launch(count:5))
 criteria.append(.activated(count:5))
 criteria.append(.daysSinceInstallationOrUpdate(days:7))
 criteria.append(.significantEvent("Did the thing", count:5)

 responder.when(.all(criteria:criteria) { _ in
     if #available(iOS 10.3, *) {
         SKStoreReviewController.requestReview()
     } else {
         print("Skipping review requesting due to OS version")
     }
 })
````

### Significant events
 ````swift
   responder.when("Testing", trigger: .any(criteria: [.significantEvent(identifier:"Event 1", count:2)]), repeats: false) { _ in
       print("Some significant events did occur")
   }

   UserActionResponder.shared.significantEventDidOccur(identifier: "Event 1")
````

## Contribute

Thank you for considering this project for your contributions.  Please follow these [contribution guidelines](https://github.com/jessesquires/HowToContribute).

### To do

* Tests
* Cocoapods/Carthage/Swift Package Manager support
* Boolean logic for criterion

## Credits

Created and maintained by [**@troya21**](https://twitter.com/troya21).

## License

`UserActionResponder` is released under an MIT License. See `LICENSE` for details.

>**Copyright &copy; 2017-present Troy Anderson.**

*Please provide attribution, it is greatly appreciated.*


