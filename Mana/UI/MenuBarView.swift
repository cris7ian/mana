import SwiftUI

struct MenuBarView: View {
    let openSettings: () -> Void

    var body: some View {
        UsagePopoverView(openSettings: openSettings)
            .frame(width: 360)
    }
}
