import XCTest
@testable import AndroidTVRemoteControl

final class AndroidTVRemoteControlTests: XCTestCase {
    func testRemoteIMEBatchEditRequestEncoding() throws {
        let request = CommandNetwork.RemoteIMEBatchEditRequest(text: "Hello", imeCounter: 0, fieldCounter: 0)
        XCTAssertEqual(
            Array(request.data),
            [
                170, 1, 21,
                8, 0,
                16, 0,
                26, 15,
                8, 0,
                18, 11,
                8, 4,
                16, 4,
                26, 5, 72, 101, 108, 108, 111
            ]
        )
    }

    func testRemoteIMEParserExtractsBatchEditStatus() throws {
        let framedMessage: [UInt8] = [
            20,
            170, 1, 17,
            8, 3,
            16, 5,
            26, 13,
            8, 0,
            18, 9,
            8, 2,
            16, 2,
            26, 3, 97, 98, 99
        ]

        let status = CommandNetwork.RemoteIMEParser.extractStatus(from: framedMessage)

        XCTAssertEqual(
            status,
            RemoteIMEStatus(
                imeCounter: 3,
                fieldCounter: 5,
                text: "abc",
                selectionStart: 2,
                selectionEnd: 2,
                label: nil,
                appPackage: nil
            )
        )
    }
}
