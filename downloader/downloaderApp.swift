//
//  downloaderApp.swift
//  downloader
//
//  Created by Eşref Erdoğan on 2.05.2025.
//

import SwiftUI

@main
struct downloaderApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
