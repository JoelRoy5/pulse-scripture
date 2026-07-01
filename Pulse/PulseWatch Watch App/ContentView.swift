//
//  ContentView.swift
//  PulseWatch Watch App
//
//  Created by Joel Roy on 6/30/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VerseFullView()
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSessionManager.shared)
}
