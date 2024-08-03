//
//  AddApplePayTransactionShortcutExtension.swift
//  AddApplePayTransactionShortcut
//
//  Created by Andre Popovitch on 8/2/24.
//

import AppIntents

@main
struct AddApplePayTransactionShortcutExtension: AppIntentsExtension {
    static var appIntents: [any AppIntent.Type] {
        [AddApplePayTransactionShortcut.self]
    }
}
