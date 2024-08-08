//
//  TrickleApp.swift
//  Trickle
//
//  Created by Andre Popovitch on 5/20/24.
//

import SwiftUI

@main
struct TrickleApp: App {
    @State var finishedIntro = AppData.load() != nil
    
    var body: some Scene {
        WindowGroup {
            if finishedIntro {
                ContentView(initialAppData: AppData.loadOrDefault())
            }
            else {
                Intro (
                    finishIntro: { appData in
                        let _ = appData.save()
                        finishedIntro = true
                    }
                )
            }
        }
    }
}
