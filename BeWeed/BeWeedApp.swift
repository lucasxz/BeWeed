//
//  BeWeedApp.swift
//  BeWeed
//
//  Created by Lucas Zhou on 1/23/23.
//

import SwiftUI
import Vision

@main
struct BeWeedApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            HostedViewController()
                .ignoresSafeArea()
        }
    }
}
