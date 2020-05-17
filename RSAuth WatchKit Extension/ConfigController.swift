//
//  ConfigController.swift
//  RSAuth WatchKit Extension
//
//  Created by Alpha on 5/16/20.
//  Copyright © 2020 Arbitrary Definitions. All rights reserved.
//

import WatchKit
import SwiftUI
import Foundation

class ConfigController: WKHostingController<ConfigView> {
    let keychain = Keychain()

    override var body: ConfigView {
        return ConfigView()
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        if self.keychain.serial == nil || self.keychain.seed == nil {
            becomeCurrentPage()
        }
    }
}

struct ConfigView: View {
    let keychain = Keychain()

    @State private var serial: String = ""
    @State private var seed: String = ""
    @State private var pin: String = ""
    @State private var flags: String = ""

    var body: some View {
        VStack {
            SecureField("Serial", text: $serial) {
                guard let serial = Serial(string: self.serial) else { return }
                self.keychain.serial = serial.data
            }
            SecureField("Seed", text: $seed) {
                guard let seed = Seed(string: self.seed) else { return }
                self.keychain.seed = seed.data
            }
            Spacer()
            Button(action: {
                self.keychain.serial = nil
                self.keychain.seed = nil
            }) {
                Text("Clear")
            }.background(Color.red).cornerRadius(5)
        }.onAppear {
            guard
                let serial = self.keychain.serial,
                let seed = self.keychain.seed
            else { return }

            self.serial = Serial(data: serial).string
            self.seed = Seed(data: seed).string
        }
    }
}

struct ConfigController_Previews: PreviewProvider {
    static var previews: some View {
        return ConfigView()
    }
}
