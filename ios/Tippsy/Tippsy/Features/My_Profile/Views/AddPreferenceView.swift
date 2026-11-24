//
//  AddPreferenceView.swift
//  Tippsy
//
//  Created by Joelle Ishimwe on 2024-12-25.
//

import SwiftUI

struct AddPreferenceView: View {
    let preferenceType: String
    @Binding var preferences: [String]
    @State private var newPreference: String = ""
    @Environment(\.presentationMode) var presentationMode   //dismiss the view

    var body: some View {
        VStack {
            TextField("Add \(preferenceType)", text: $newPreference)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Add") {
                if !newPreference.isEmpty {
                    preferences.append(newPreference)
                }
                newPreference = ""
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.green)
            .cornerRadius(8)

            //cancel button
            Button("Return") {
                newPreference = ""
                //dismiss the view
                presentationMode.wrappedValue.dismiss()
            }
        }
        .padding()
    }
}
