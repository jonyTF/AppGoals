//
//  View+Keyboard.swift
//  AppGoals
//
//  Keyboard-dismissal helpers. The numeric (decimal-pad) fields have no return
//  key, so we give every text-entry form a "Done" button above the keyboard and
//  interactive swipe-to-dismiss.
//

import SwiftUI

extension View {
    /// Adds a "Done" button to the keyboard accessory bar and lets the user
    /// swipe down in the scroll view to dismiss the keyboard.
    func dismissKeyboardSupport() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                }
            }
    }
}
