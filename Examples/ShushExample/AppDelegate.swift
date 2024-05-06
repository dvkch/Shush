//
//  AppDelegate.swift
//  ShushExample
//
//  Created by syan on 19/06/2023.
//

import UIKit
import Shush

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        window = .init()
        window?.makeKeyAndVisible()
        window?.rootViewController = UINavigationController(rootViewController: ViewController())
        window?.backgroundColor = .black
        window?.layer.masksToBounds = true

        return true
    }
}

