import SwiftUI

/// Settings > General: the font and the text size of every note and list.
/// Both change every window at once, while the user chooses.
struct GeneralPane: View {
    let appearance: TextAppearance

    private var family: Binding<FontFamily> {
        Binding(
            get: { appearance.family },
            set: { if $0 != appearance.family { appearance.family = $0 } }
        )
    }

    private var size: Binding<Double> {
        Binding(
            get: { Double(appearance.size) },
            set: { appearance.size = Int($0.rounded()) }
        )
    }

    var body: some View {
        Form {
            Section("Text") {
                Picker("Font", selection: family) {
                    ForEach([FontFamily.typewriter, .system], id: \.self) { family in
                        Text(family.menuTitle).tag(family)
                    }
                }
                LabeledContent("Text size") {
                    HStack(spacing: 8) {
                        Text("A").font(.system(size: 10))
                        Slider(value: size,
                               in: Double(TextAppearance.sizeRange.lowerBound)...Double(TextAppearance.sizeRange.upperBound),
                               step: 1)
                            .frame(width: 160)
                            .accessibilityLabel("Text Size")
                        Text("A").font(.system(size: 18))
                        Text("\(appearance.size) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
