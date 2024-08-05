import SwiftUI
import OSLog

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

extension ConsoleView {

    func getBackgroundColor(level: OSLogEntryLog.Level) -> Color {
        switch level {
        case .undefined, .debug, .info, .notice:
            getBackgroundColorDefault()

        case .error:
            getBackgroundColorError()

        case .fault:
            getBackgroundColorFault()

        default:
            getBackgroundColorDefault()
        }
    }


    func getBackgroundColorDefault() -> Color {
#if canImport(UIKit) && !os(tvOS) && !os(watchOS)
            Color(uiColor: UIColor.secondarySystemGroupedBackground)
#elseif canImport(AppKit)
            Color(nsColor: .init(name: "debug", dynamicProvider: { traits in
                if traits.name == .darkAqua || traits.name == .vibrantDark {
                    return .init(red: 1, green: 1, blue: 1, alpha: 1)
                } else {
                    return .init(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
                }
            }))
#else
            Color.clear
#endif
    }


    func getBackgroundColorError() -> Color {
#if canImport(UIKit) && !os(watchOS)
            Color(uiColor: .init(dynamicProvider: { traits in
                if traits.userInterfaceStyle == .light {
                    return .init(red: 1, green: 0.968, blue: 0.898, alpha: 1)
                } else {
                    return .init(red: 0.858, green: 0.717, blue: 0.603, alpha: 0.4)
                }
            }))
#elseif canImport(AppKit)
            Color(nsColor: .init(name: "Error", dynamicProvider: { traits in
                if traits.name == .darkAqua || traits.name == .vibrantDark {
                    return .init(red: 0.858, green: 0.717, blue: 0.603, alpha: 0.4)
                } else {
                    return .init(red: 1, green: 0.968, blue: 0.898, alpha: 1)
                }
            }))
#else
            Color.yellow
#endif
    }


    func getBackgroundColorFault() -> Color {
#if canImport(UIKit) && !os(watchOS)
            Color(uiColor: .init(dynamicProvider: { traits in
                if traits.userInterfaceStyle == .light {
                    return .init(red: 0.98, green: 0.90, blue: 0.90, alpha: 1)
                } else {
                    return .init(red: 0.26, green: 0.15, blue: 0.17, alpha: 1)
                }
            }))
#elseif canImport(AppKit)
            Color(nsColor: .init(name: "Fault", dynamicProvider: { traits in
                if traits.name == .darkAqua || traits.name == .vibrantDark {
                    return .init(red: 0.26, green: 0.15, blue: 0.17, alpha: 1)
                } else {
                    return .init(red: 0.98, green: 0.90, blue: 0.90, alpha: 1)
                }
            }))
#else
            Color.red
#endif
    }
}
