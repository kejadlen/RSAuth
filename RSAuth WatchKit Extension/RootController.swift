//
//  RootController.swift
//  RSAuth WatchKit Extension
//
//  Created by Alpha on 5/16/20.
//  Copyright © 2020 Arbitrary Definitions. All rights reserved.
//

import WatchKit
import Foundation

class TokenCodeController: WKInterfaceController {

    @IBOutlet weak var pinLabel: WKInterfaceLabel!
    @IBOutlet weak var serialTextField: WKInterfaceTextField!
    @IBOutlet weak var seedTextField: WKInterfaceTextField!

    let keychain = Keychain()

    var code: String? {
        guard let token = token else { return nil }
        return token.code.map { String($0) }.joined()
    }
    var token: Token? {
        guard
            let serial = keychain.serial,
            let seed = keychain.seed
        else { return nil }

        return Token(serial: serial, seed: seed)
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        pinLabel.setText(code)

        let serial = keychain.serial.map { data in
            [UInt8](data).map { String($0) }.joined()
        }
        serialTextField.setText(serial)

        let seed = keychain.seed.map { data in
            [UInt8](data)
                .map { String(format:"%02X", $0) }
                .joined(separator: ":")
        }
        seedTextField.setText(seed?.count == 16*2 + 15 ? seed : nil)
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    @IBAction func serialChanged(_ value: String?) {
        guard
            let value = value.flatMap({ UInt64($0) })
        else { return }

        keychain.serial = value.bcd
    }

    @IBAction func seedChanged(_ value: String?) {
        guard let value = value else { return }
        keychain.seed = Data(
            value
                .components(separatedBy: ":")
                .compactMap { UInt8($0, radix: 16) }
        )
    }

    private func serial(from string: String) -> Data? {
        guard var n = UInt64(string) else { return nil }

        var data = Data()
        while n > 0 {
            let (q, r) = n.quotientAndRemainder(dividingBy: 100)
            let (hundreds, tens) = r.quotientAndRemainder(dividingBy: 10)
            data.append(UInt8((hundreds << 4) | tens))
            n = q
        }
        data.reverse()
        return data
    }

}
