# UserActionResponder
A swift class for performing actions based on app launches and significant events.

## Motivation
Now that Apple has made SKStoreReviewController, I needed a way to know when to call it.  With UserActionResponder, in a couple of lines of code, you can ask the user for a review after a certain number of launches, significant events, or time since the last update.  There is a setting that causes the criteria to be reset on updates.

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

Please follow these [contribution guidelines](https://github.com/jessesquires/HowToContribute).

## Credits

Created and maintained by [**@troya2**]

## License

`UserActionResponder` is released under an [MIT License][mitLink]. See `LICENSE` for details.

>**Copyright &copy; 2017-present Troy Anderson.**

*Please provide attribution, it is greatly appreciated.*


