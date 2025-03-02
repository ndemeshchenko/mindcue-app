import SwiftUI

extension TextFieldStyle where Self == RoundedTextFieldStyleImpl {
    static var rounded: RoundedTextFieldStyleImpl { .init() }
}

struct RoundedTextFieldStyleImpl: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
    }
}

extension ButtonStyle where Self == PrimaryButtonStyleImpl {
    static var primary: PrimaryButtonStyleImpl { .init() }
}

struct PrimaryButtonStyleImpl: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
} 