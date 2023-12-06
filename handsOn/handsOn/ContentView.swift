//
//  ContentView.swift
//  handsOn
//
//  Created by Florian Kainberger on 18.10.23.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = CameraViewModel()
    
    
    var body: some View {
        VStack {
            Text("ASL-Detection").frame(height: 25).font(.headline)
            Text("Bitte richten Sie die Kamera auf den Gegenüber")
            CameraView(viewModel: viewModel) .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            Text("Gezeigter Buchstabe:").frame(height: 25)
            Text(viewModel.currentLetter).fontWeight(.bold).frame(height: 80).lineLimit(0, reservesSpace: false)
        }.background(Color.gray)
        
    }
}

#Preview {
    ContentView()
}
