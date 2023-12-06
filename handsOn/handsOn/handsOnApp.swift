//
//  handsOnApp.swift
//  handsOn
//
//  Created by Florian Kainberger on 18.10.23.
//

import SwiftUI

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        return true
    }
}

@main
struct handsOnApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    var launchScreen: some Scene {
        WindowGroup {
            VStack {
                Text("Welcome to HandsOn!")
            }
        }
    }
    
    
}
