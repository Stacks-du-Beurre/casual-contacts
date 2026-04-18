import SwiftUI

public extension CCDesign {
    enum Colors {
        // Light palette — L0 lightest (pure white) → L4 darkest. Extracted from Figma node 277:11175.
        public static let L0 = Color(red: 1.00, green: 1.00, blue: 1.00)   // #FFFFFF
        public static let L1 = Color(red: 0.957, green: 0.961, blue: 0.980) // #F4F5FA
        public static let L2 = Color(red: 0.914, green: 0.918, blue: 0.945) // #E9EAF1
        public static let L3 = Color(red: 0.816, green: 0.820, blue: 0.855) // #D0D1DA
        public static let L4 = Color(red: 0.690, green: 0.698, blue: 0.737) // #B0B2BC

        // Dark palette — D0 lightest dark → D4 darkest. Extracted from Figma node 277:11175.
        public static let D0 = Color(red: 0.373, green: 0.376, blue: 0.408) // #5F6068
        public static let D1 = Color(red: 0.290, green: 0.298, blue: 0.329) // #4A4C54
        public static let D2 = Color(red: 0.220, green: 0.231, blue: 0.263) // #383B43
        public static let D3 = Color(red: 0.157, green: 0.165, blue: 0.188) // #282A30
        public static let D4 = Color(red: 0.078, green: 0.078, blue: 0.082) // #141415

        public static var light: [Color] { [L0, L1, L2, L3, L4] }
        public static var dark: [Color] { [D0, D1, D2, D3, D4] }
    }
}
