import SwiftUI

/// Custom TextField Keyboard TextField Modifier
extension TextField {
    @ViewBuilder
    func inputView<Content: KeyboardContent>(
        _ dump: Content.Type,
        text: Binding<String>,
        onSubmit: @escaping (() -> Void) = {}
    ) -> some View {
        self
            .background {
                SetTFKeyboard<Content, Label>(text: text, onSubmit: onSubmit, textField: self)
            }
    }
}

fileprivate struct SetTFKeyboard<Content: KeyboardContent, Label: View>: UIViewRepresentable {
    @Binding var text: String
    let onSubmit: (() -> Void)
    let textField: TextField<Label>
    @State private var selectedRange: Range<String.Index> = Range(uncheckedBounds: ("".startIndex, "".endIndex))
    
    @State private var hostingController: UIHostingController<Content>?
    
    func makeUIView(context: Context) -> UIView {
        return UIView()
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    var content: Content {
        let selectedText = Binding(
            get: {
                // Validate that selectedRange is within the text's bounds
                guard selectedRange.lowerBound >= text.startIndex && selectedRange.upperBound <= text.endIndex else {
                    return ""
                }
                return String(text[selectedRange])
            },
            set: { newValue in
                DispatchQueue.main.async {
                    // Check again when setting the new value
                    guard selectedRange.lowerBound >= text.startIndex && selectedRange.upperBound <= text.endIndex else {
                        return
                    }
                    text.replaceSubrange(selectedRange, with: newValue)
                    // Update the selectedRange to be at the end of the newly inserted text
                    let newEndIndex = text.index(selectedRange.lowerBound, offsetBy: newValue.count)
                    selectedRange = newEndIndex..<newEndIndex
                }
            }
        )
        return Content(text: $text, selectedText: selectedText, onSubmit: onSubmit, onBackspace: backspace, getCharBeforeCursor: getCharBeforeCursor)
    }
    
    func getCharBeforeCursor() -> Character? {
        let cursorPosition = min(selectedRange.lowerBound, text.endIndex)
        guard cursorPosition > text.startIndex,
              !text.isEmpty else { return nil }
        
        let indexBeforeCursor = text.index(before: cursorPosition)
        guard indexBeforeCursor >= text.startIndex else { return nil }
        
        return text[indexBeforeCursor]
    }
    
    func backspace() {
        if selectedRange.isEmpty {
            // If no selection, delete the character before the cursor
            if let index = text.index(selectedRange.lowerBound, offsetBy: -1, limitedBy: text.startIndex) {
                text.remove(at: index)
                selectedRange = index..<index
            }
        } else {
            // If there's a selection, delete the selected text
            text.removeSubrange(selectedRange)
            selectedRange = selectedRange.lowerBound..<selectedRange.lowerBound
        }
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let textFieldContainerView = uiView.superview?.superview {
                if let uiTextField = textField.getUITextField(in: textFieldContainerView) {
                    if uiTextField.inputView == nil {
                        hostingController = UIHostingController(rootView: content)
                        hostingController?.view.frame = .init(origin: .zero, size: hostingController?.view.intrinsicContentSize ?? .zero)
                        uiTextField.delegate = context.coordinator
                        uiTextField.inputView = hostingController?.view
                        uiTextField.reloadInputViews()
                    } else {
                        hostingController?.rootView = content
                    }
                }
                else {
                    print("Not able to get text field \(textField) in \(textFieldContainerView)")
                }
            }
            else {
                print("Something was nil: (uiView.superview \(String(describing: uiView.superview)))?.superview / \(String(describing: uiView.superview?.superview))")
            }
        }
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SetTFKeyboard
        
        init(_ parent: SetTFKeyboard) {
            self.parent = parent
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                textField.reloadInputViews()
            }
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard let newSelectedRange = textField.selectedTextRange else { return }
                
                let selectionStart = textField.offset(from: textField.beginningOfDocument, to: newSelectedRange.start)
                let selectionEnd = textField.offset(from: textField.beginningOfDocument, to: newSelectedRange.end)
                
                // Ensure that the offsets do not exceed the bounds of the text
                let safeStartIndex = min(max(selectionStart, 0), self.parent.text.count)
                let safeEndIndex = min(max(selectionEnd, 0), self.parent.text.count)

                let startIndex = self.parent.text.index(self.parent.text.startIndex, offsetBy: safeStartIndex)
                let endIndex = self.parent.text.index(self.parent.text.startIndex, offsetBy: safeEndIndex)
                
                self.parent.selectedRange = startIndex..<endIndex
                
                print("text.indices.contains(safeStartIndex)", self.parent.text.indices.contains(startIndex), " | newSelectedRange", newSelectedRange, " | startIndex", startIndex.utf16Offset(in: self.parent.text))
                
                // Update the custom keyboard view
                if let hostingController = self.parent.hostingController {
                    hostingController.rootView.onSelectionChange(start: safeStartIndex, end: safeEndIndex)
                }
            }
        }
    }
}
protocol KeyboardContent: View {
    func onSelectionChange(start: Int, end: Int)
    
    init(
        text: Binding<String>, selectedText: Binding<String>,
        onSubmit: @escaping (() -> Void),
        onBackspace: @escaping (() -> Void),
        getCharBeforeCursor: @escaping (() -> Character?)
    )
}

extension TextField {
    func getUITextField(in view: UIView) -> UITextField? {
        for subview in view.allSubViews {
            if let textField = subview as? UITextField {
                return textField
            }
        }
        return nil
    }
}

/// Extracting TextField From the Subviews
fileprivate extension UIView {
    var allSubViews: [UIView] {
        return subviews.flatMap { [$0] + $0.subviews }
    }
    
    /// Finding the UIView is TextField or Not
    func findTextField(_ hint: String) -> UITextField? {
        if let textField = allSubViews.first(where: { view in
             let tf = view as? UITextField
            return tf?.placeholder == hint
        }) as? UITextField {
            return textField
        }
        
        return nil
    }
}
