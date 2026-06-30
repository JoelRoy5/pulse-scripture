//
//  PulseApp.swift
//  Pulse
//
//  Created by Joel Roy on 6/30/26.
//

import SwiftUI
import CoreData

@main
struct PulseApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
