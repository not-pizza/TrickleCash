import SwiftUI

enum KeyboardValue {
    case number(String)
    case operation(String)
    case image(String)
    case action(String)
    case next(String)
}

struct CalculatorKeyboard: KeyboardContent {
    init(
        text: Binding<String>,
        selectedText: Binding<String>,
        onSubmit: @escaping (() -> Void),
        onBackspace: @escaping (() -> Void),
        getCharBeforeCursor: @escaping (() -> Character?)
    ) {
        _text = text
        _selectedText = selectedText
        self.onSubmit = onSubmit
        self.onBackspace = onBackspace
        self.getCharBeforeCursor = getCharBeforeCursor
    }
    
    @Binding var text: String
    @Binding var selectedText: String

    var onSubmit: (() -> Void)
    var onBackspace: (() -> Void)
    var getCharBeforeCursor: (() -> Character?)
    @State private var selectionRange: Range<String.Index>?

    var body: some View {
        VStack(spacing: 6) {
            // slightly larger spacing between buttons and numbers
            HStack(spacing: 9) {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(1...3, id: \.self) { index in
                            KeyboardButtonView(value: .number("\(index)")) {
                                selectedText = "\(index)"
                            }
                        }
                    }
                    HStack(spacing: 6) {
                        ForEach(4...6, id: \.self) { index in
                            KeyboardButtonView(value: .number("\(index)")) {
                                selectedText = "\(index)"
                            }
                        }
                    }
                    HStack(spacing: 6) {
                        ForEach(7...9, id: \.self) { index in
                            KeyboardButtonView(value: .number("\(index)")) {
                                selectedText = "\(index)"
                            }
                        }
                    }
                    HStack(spacing: 6) {
                        KeyboardButtonView(
                            value: .operation("."),
                            disabled: inputContainsDecimal()
                        ) {
                            selectedText = "."
                        }
                        KeyboardButtonView(value: .number("0")) {
                            selectedText = "0"
                        }
                        KeyboardButtonView(value: .image("delete.left")) {
                            onBackspace()
                        }
                    }
                }
                
                VStack(spacing: 6) {
                    ForEach(["+", "-", "×", "÷"], id: \.self) { operation in
                        KeyboardButtonView(
                            value: .operation(operation),
                            disabled: shouldDisableOperation(operation),
                            onTap: {
                                selectedText = operation
                            }
                        )
                        .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 50)
            }
            
            KeyboardButtonView(value: .next("Next")) {
                onSubmit()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .padding(6)
        .background(Color(.systemGray6))
    }

    func onSelectionChange(start: Int, end: Int) {
        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(text.startIndex, offsetBy: end)
        selectionRange = startIndex..<endIndex
    }
    
    private func shouldDisableOperation(_ operation: String) -> Bool {
        guard let charBeforeCursor = getCharBeforeCursor() else {
            return operation != "-"
        }
        return !charBeforeCursor.isNumber && operation != "-"
    }
    
    private func inputContainsDecimal() -> Bool {
        return text.contains(".")
    }
}

struct KeyboardButtonView: View {
    let value: KeyboardValue
    var disabled: Bool = false
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            if case .next = value {
                // Don't play haptic for the "Next" button
            } else {
                playHapticFeedback()
            }

            onTap()
        }) {
            ZStack {
                switch value {
                case .number(let string), .operation(let string), .action(let string):
                    Text(string)
                        .font(.title3)
                        .fontWeight(.regular)
                case .next(let string):
                    Text(string)
                        .font(.title3)
                        .fontWeight(.regular)
                        .foregroundStyle(Color.accentColor)
                case .image(let image):
                    Image(systemName: image)
                        .font(.title3)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .cornerRadius(5)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
    }
    
    private var backgroundColor: Color {
        switch value {
        case .number:
            return Color(.systemBackground)
        case .operation, .image, .action, .next:
            return Color(.systemGray4)
        }
    }
    
    private func playHapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

}


#Preview {
    var inputAmount = ""
    
    ZStack {
        Color(.systemBackground)
        CalculatorKeyboard(
            text: .constant(inputAmount),
            selectedText: .constant(inputAmount),
            onSubmit: {},
            onBackspace: {},
            getCharBeforeCursor: {nil}
        )
    }
}
