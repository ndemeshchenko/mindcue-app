//
//  MindCueApp.swift
//  MindCue
//
//  Created by Mykyta Demeshchenko on 28/02/2025.
//

import SwiftUI

// Test AuthService accessibility
let authServiceTest = {
    print("Testing AuthService from app entry point")
    let authService = AuthService.shared
    print("AuthService instance exists: \(authService)")
    return true
}()

@main
struct MindCueApp: App {
    init() {
        print("MindCueApp initialized, AuthService test result: \(authServiceTest)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
