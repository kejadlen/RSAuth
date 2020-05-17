//
//  Token.swift
//  RSAuth WatchKit Extension
//
//  Created by Alpha on 5/16/20.
//  Copyright © 2020 Arbitrary Definitions. All rights reserved.
//

import Foundation
import CommonCrypto

struct Serial {
    let data: Data

    var string: String {
        data.map { twoDigits in
            let hundreds = String((twoDigits & 0xF0) >> 4)
            let tens = String(twoDigits & 0x0F)
            return "\(hundreds)\(tens)"
        }.joined()
    }

    init(data: Data) {
        self.data = data
    }

    init?(string: String) {
        guard var n = UInt64(string) else { return nil }

        var data = Data()
        while n > 0 {
            let (q, r) = n.quotientAndRemainder(dividingBy: 100)
            let (hundreds, tens) = r.quotientAndRemainder(dividingBy: 10)
            data.append(UInt8((hundreds << 4) | tens))
            n = q
        }
        data.reverse()
        self.data = data
    }
}

struct Seed {
    let data: Data

    var string: String {
        data
            .map { String(format:"%02X", $0) }
            .joined(separator: ":")
    }

    init(data: Data) {
        self.data = data
    }

    init?(string: String) {
        var data = Data()
        for c in string.components(separatedBy: ":") {
            guard let n = UInt8(c, radix: 16) else { return nil }
            data.append(n)
        }
        self.data = data
    }
}

let fldDigitShift: UInt8 = 6
let fldDigitMask: UInt16 = 0b111 << fldDigitShift
let fldNumsecondsShift: UInt16 = 0
let fldNumsecondsMask: UInt16 = 0b11 << fldNumsecondsShift

class Token {
    let serial: Data
    let seed: Data
    let pin = Data(count: 8)
    let flags: UInt = 17369

    let currentDate: () -> Date

    private var numDigits: Int {
        Int((UInt16(flags) & fldDigitMask) >> fldDigitShift + 1)
    }

    private var minuteMask: UInt8 {
        switch interval {
        case .thirtySeconds: return ~0b01
        case .oneMinute: return ~0b11
        }
    }

    enum Interval { case thirtySeconds, oneMinute }
    var interval: Interval {
        if (UInt16(flags) & fldNumsecondsMask) >> fldNumsecondsShift == 0 {
            return .thirtySeconds
        } else {
            return .oneMinute
        }
    }

    init?(serial: Serial, seed: Seed, currentDate: @escaping () -> Date = { Date() }) {
        self.serial = serial.data
        self.seed = seed.data

        self.currentDate = currentDate
    }

    var code: [UInt8] {
        let date = Calendar.current.dateComponents(
            in: TimeZone(identifier: "UTC")!,
            from: currentDate()
        )
        let bcdTime = self.bcdTime(date: date)

        var key1 = seed
        var key0 = key(from: bcdTime[0..<2])
        key0 = encrypt(data: key0, with: key1)

        key1 = key(from: bcdTime[0..<3])
        key1 = encrypt(data: key1, with: key0)

        key0 = key(from: bcdTime[0..<4])
        key0 = encrypt(data: key0, with: key1)

        key1 = key(from: bcdTime[0..<5])
        key1 = encrypt(data: key1, with: key0)

        key0 = key(from: bcdTime[0..<8])
        key0 = encrypt(data: key0, with: key1)

        let offset = self.offset(minute: date.minute!)
        let rawNumber = Data(key0[offset..<offset+4])
            .withUnsafeBytes { $0.load(as: UInt32.self) }
            .bigEndian

        let pin = (0..<numDigits).map { $0 < self.pin.count ? self.pin[$0] : 0 }
        return zip(rawNumber.digits.suffix(numDigits), pin).map { UInt8($0 + $1) }
    }

    private func bcdTime(date: DateComponents) -> Data {
        var data = Data()

        for component in [
            date.year! % 100,
            (date.year! / 100) % 100,
            date.month!,
            date.day!,
            date.hour!,
            date.minute! & Int(minuteMask),
        ] {
            data.append(UInt8(component).bcd)
        }
        data.append(contentsOf: [0, 0])

        return data
    }

    private func key(from bcdTime: Data) -> Data {
        var key: [UInt8] = Array(repeating: 0, count: 16)

        for i in 0..<16 {
            let byte: UInt8
            switch i {
            case 0...7:
                byte = (i < bcdTime.count) ? bcdTime[i] : 0xAA
            case 8...11:
                byte = serial[i-6]
            case 12...15:
                byte = 0xBB
            default:
                fatalError()
            }
            key[i] = byte
        }

        return Data(key)
    }

    private func encrypt(data: Data, with key: Data) -> Data {
        var encrypted = Data(count: data.count)

        encrypted.withUnsafeMutableBytes { encrypted in
            key.withUnsafeBytes { key in
                data.withUnsafeBytes { data in
                    var bytesLength = 0
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCKeySizeAES128|kCCBlockSizeAES128|kCCContextSizeAES128),
                        key.baseAddress,
                        key.count,
                        nil,
                        data.baseAddress,
                        data.count,
                        encrypted.baseAddress,
                        encrypted.count,
                        &bytesLength
                    )
                }
            }
        }

        return encrypted
    }

    private func offset(minute: Int) -> Int {
        switch interval {
        case .thirtySeconds:
            var i = 0
            if minute % 2 == 1 { i |= 0b1000 }
            if minute >= 30 { i |= 0b0100 }
            return i
        case .oneMinute:
            return (minute & 0b11) << 2
        }
    }

}

extension UnsignedInteger {
    var bcd: Data {
        var d: [UInt8] = []
        var n = self
        while n > 0 {
            let (q, r) = n.quotientAndRemainder(dividingBy: 100)
            let (hundreds, tens) = r.quotientAndRemainder(dividingBy: 10)
            d.append(UInt8((hundreds << 4) | tens))
            n = q
        }
        return Data(d.isEmpty ? [0] : d.reversed())
    }
}

extension UInt32 {
    var digits: [UInt8] {
        String(self).map { UInt8($0.wholeNumberValue!) }
    }
}
