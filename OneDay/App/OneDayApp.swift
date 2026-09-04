import SwiftUI

/// Entry point.
///
/// Everything it does is delegate: services are started by `AppEnvironment`,
/// navigation is decided by `RootRouter`. Keeping `@main` this thin means
/// renaming or restructuring the app never touches startup logic.
@main
struct OneDayApp: App {
    @State private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .withAppEnvironment(appEnvironment)
                .task {
                    appEnvironment.start()
                }
        }
    }
}
