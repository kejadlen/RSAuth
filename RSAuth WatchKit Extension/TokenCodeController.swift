//
//  TokenCodeController.swift
//  RSAuth WatchKit Extension
//
//  Created by Alpha on 5/16/20.
//  Copyright © 2020 Arbitrary Definitions. All rights reserved.
//

import WatchKit
import Foundation

class TokenCodeController: WKInterfaceController {

    @IBOutlet weak var pinLabel: WKInterfaceLabel!
    @IBOutlet weak var timer: WKInterfaceTimer!

    let keychain = Keychain()

    var code: String? {
        guard let token = token else { return nil }
        return token.code.map { String($0) }.joined()
    }
    var token: Token? {
        guard
            let serial = keychain.serial.map({ Serial(data: $0) }),
            let seed = keychain.seed.map({ Seed(data: $0) })
        else { return nil }

        return Token(serial: serial, seed: seed)
    }

    override func willActivate() {
        super.willActivate()

        update()
    }

    private func update() {
        guard let token = token else { return }

        pinLabel.setText(code)
        timer.setHidden(false)

        let nextThirtySecond = Calendar.current.nextDate(after: Date(), matching: DateComponents(second: 30), matchingPolicy: .nextTime)!
        let nextMinute = Calendar.current.nextDate(after: Date(), matching: DateComponents(second: 0), matchingPolicy: .nextTime)!

        let nextRotation: Date
        let interval: TimeInterval
        switch token.interval {
        case .thirtySeconds:
            nextRotation = min(nextThirtySecond, nextMinute)
            interval = 30
        case .oneMinute:
            nextRotation = nextMinute
            interval = 60
        }

        timer.setDate(nextRotation)
        timer.start()

        RunLoop.current.add(
            Timer(fire: nextRotation, interval: interval, repeats: true) { _ in self.update() },
            forMode: .default
        )
    }
}
