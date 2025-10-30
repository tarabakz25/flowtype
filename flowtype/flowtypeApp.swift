import SwiftUI

@main
struct FlowtypeApp: App {
  @StateObject private var store = FontStore() // DI: アプリ全体で共有

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
    }
    .windowStyle(.titleBar)
  }
}
