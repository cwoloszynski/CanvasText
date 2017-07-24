//
//  AppDelegate.swift
//  Example
//
//  Created by Sam Soffes on 2/17/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow? = UIWindow()

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		// Add your access token here. Make sure to undo this change after you run the app once. It will remember your
		// access token. BE SURE TO NOT COMMIT YOUR ACCESS TOKEN.
		// UserDefaults.standard.set("YOUR_ACCESS_TOKEN_HERE", forKey: "AccessToken")

		window?.rootViewController = UINavigationController(rootViewController: ViewController(nibName: nil, bundle: nil))
		window?.makeKeyAndVisible()
		
		return true
	}
}
