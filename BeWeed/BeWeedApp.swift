//
//  BeWeedApp.swift
//  BeWeed
//
//  Created by Lucas Zhou on 1/23/23.
//

import SwiftUI

@main
struct BeWeedApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
