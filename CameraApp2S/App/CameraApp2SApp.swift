//
//  CameraApp2SApp.swift
//  CameraApp2S
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

import SwiftUI
import UIKit

/// Forces the app to stay in portrait orientation at all times.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

@main
struct CameraApp2SApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
