import SwiftUI

public extension CCDesign {
    enum Gradients {

        // All stops sampled from design-assets/Gradients/*.png (see plan Task 4 table).
        // Stops are TL → center → BR; SwiftUI interpolates linearly along .topLeading→.bottomTrailing.

        public static let dawn = LinearGradient(
            colors: [Color(red: 0.596, green: 0.710, blue: 0.780),   // #98B5C7
                     Color(red: 0.584, green: 0.580, blue: 0.584),   // #959495
                     Color(red: 0.925, green: 0.784, blue: 0.737)],  // #ECC8BC
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static let sunrise = LinearGradient(
            colors: [Color(red: 0.278, green: 0.663, blue: 0.635),   // #47A9A2
                     Color(red: 0.345, green: 0.667, blue: 0.627),   // #58AAA0
                     Color(red: 0.992, green: 0.925, blue: 0.886)],  // #FDECE2
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static let midday = LinearGradient(
            colors: [Color(red: 0.486, green: 0.776, blue: 0.835),   // #7CC6D5
                     Color(red: 0.380, green: 0.631, blue: 0.733),   // #61A1BB
                     Color(red: 0.522, green: 0.796, blue: 0.698)],  // #85CBB2
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static let sunset = LinearGradient(
            colors: [Color(red: 0.827, green: 0.851, blue: 0.878),   // #D3D9E0
                     Color(red: 0.541, green: 0.514, blue: 0.604),   // #8A839A
                     Color(red: 0.643, green: 0.553, blue: 0.624)],  // #A48D9F
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static let dusk = LinearGradient(
            colors: [Color(red: 0.533, green: 0.565, blue: 0.584),   // #889095
                     Color(red: 0.239, green: 0.267, blue: 0.282),   // #3D4448
                     Color(red: 0.980, green: 0.878, blue: 0.824)],  // #FAE0D2
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static let night = LinearGradient(
            colors: [Color(red: 0.357, green: 0.388, blue: 0.494),   // #5B637E
                     Color(red: 0.224, green: 0.255, blue: 0.392),   // #394164
                     Color(red: 0.949, green: 0.945, blue: 0.969)],  // #F2F1F7
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static let midnight = LinearGradient(
            colors: [Color(red: 0.310, green: 0.310, blue: 0.396),   // #4F4F65
                     Color(red: 0.118, green: 0.125, blue: 0.173),   // #1E202C
                     Color(red: 0.671, green: 0.686, blue: 0.698)],  // #ABAFB2
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static var all: [LinearGradient] {
            [dawn, sunrise, midday, sunset, dusk, night, midnight]
        }
    }
}
