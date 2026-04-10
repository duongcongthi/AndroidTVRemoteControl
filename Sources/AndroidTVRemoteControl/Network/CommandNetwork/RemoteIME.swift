import Foundation

public struct RemoteIMEStatus: Equatable {
    public let imeCounter: Int
    public let fieldCounter: Int
    public let text: String
    public let selectionStart: Int
    public let selectionEnd: Int
    public let label: String?
    public let appPackage: String?

    public init(
        imeCounter: Int,
        fieldCounter: Int,
        text: String,
        selectionStart: Int,
        selectionEnd: Int,
        label: String?,
        appPackage: String?
    ) {
        self.imeCounter = imeCounter
        self.fieldCounter = fieldCounter
        self.text = text
        self.selectionStart = selectionStart
        self.selectionEnd = selectionEnd
        self.label = label
        self.appPackage = appPackage
    }
}

extension CommandNetwork {
    struct RemoteIMEBatchEditRequest: RequestDataProtocol {
        let data: Data

        init(text: String, imeCounter: Int, fieldCounter: Int) {
            let selectionIndex = max(text.count - 1, 0)

            let imeObject =
                ProtoMessageCoder.encodeVarintField(1, value: selectionIndex)
                + ProtoMessageCoder.encodeVarintField(2, value: selectionIndex)
                + ProtoMessageCoder.encodeStringField(3, value: text)

            let editInfo =
                ProtoMessageCoder.encodeVarintField(1, value: 0)
                + ProtoMessageCoder.encodeMessageField(2, payload: imeObject)

            let batchEdit =
                ProtoMessageCoder.encodeVarintField(1, value: imeCounter)
                + ProtoMessageCoder.encodeVarintField(2, value: fieldCounter)
                + ProtoMessageCoder.encodeMessageField(3, payload: editInfo)

            let message = ProtoMessageCoder.encodeMessageField(21, payload: batchEdit)
            self.data = Data(message)
        }
    }

    enum RemoteIMEParser {
        static func extractStatus(from data: Data) -> RemoteIMEStatus? {
            extractStatus(from: Array(data))
        }

        static func extractStatus(from bytes: [UInt8]) -> RemoteIMEStatus? {
            guard let message = ProtoMessageCoder.decodeDelimitedMessage(bytes),
                  let fields = ProtoMessageCoder.decodeFields(message) else {
                return nil
            }

            if let batchEditPayload = fields.first(where: { $0.number == 21 })?.payload,
               let status = parseBatchEdit(payload: batchEditPayload) {
                return status
            }

            if let showRequestPayload = fields.first(where: { $0.number == 22 })?.payload,
               let status = parseShowRequest(payload: showRequestPayload) {
                return status
            }

            if let imeKeyInjectPayload = fields.first(where: { $0.number == 20 })?.payload,
               let status = parseIMEKeyInject(payload: imeKeyInjectPayload) {
                return status
            }

            return nil
        }

        private static func parseBatchEdit(payload: [UInt8]) -> RemoteIMEStatus? {
            guard let fields = ProtoMessageCoder.decodeFields(payload) else { return nil }

            let imeCounter = fields.first(where: { $0.number == 1 })?.intValue ?? 0
            let fieldCounter = fields.first(where: { $0.number == 2 })?.intValue ?? 0

            guard let editInfoPayload = fields.first(where: { $0.number == 3 })?.payload,
                  let editInfoFields = ProtoMessageCoder.decodeFields(editInfoPayload),
                  let imeObjectPayload = editInfoFields.first(where: { $0.number == 2 })?.payload,
                  let imeObjectFields = ProtoMessageCoder.decodeFields(imeObjectPayload) else {
                return RemoteIMEStatus(
                    imeCounter: imeCounter,
                    fieldCounter: fieldCounter,
                    text: "",
                    selectionStart: 0,
                    selectionEnd: 0,
                    label: nil,
                    appPackage: nil
                )
            }

            let text = imeObjectFields.first(where: { $0.number == 3 })?.stringValue ?? ""
            let selectionStart = imeObjectFields.first(where: { $0.number == 1 })?.intValue ?? max(text.count - 1, 0)
            let selectionEnd = imeObjectFields.first(where: { $0.number == 2 })?.intValue ?? selectionStart

            return RemoteIMEStatus(
                imeCounter: imeCounter,
                fieldCounter: fieldCounter,
                text: text,
                selectionStart: selectionStart,
                selectionEnd: selectionEnd,
                label: nil,
                appPackage: nil
            )
        }

        private static func parseShowRequest(payload: [UInt8]) -> RemoteIMEStatus? {
            guard let fields = ProtoMessageCoder.decodeFields(payload),
                  let textFieldPayload = fields.first(where: { $0.number == 2 })?.payload else {
                return nil
            }

            return parseTextFieldStatus(
                payload: textFieldPayload,
                imeCounter: 0,
                appPackage: nil
            )
        }

        private static func parseIMEKeyInject(payload: [UInt8]) -> RemoteIMEStatus? {
            guard let fields = ProtoMessageCoder.decodeFields(payload) else { return nil }

            let appPackage: String?
            if let appInfoPayload = fields.first(where: { $0.number == 1 })?.payload,
               let appInfoFields = ProtoMessageCoder.decodeFields(appInfoPayload) {
                appPackage = appInfoFields.first(where: { $0.number == 12 })?.stringValue
            } else {
                appPackage = nil
            }

            guard let textFieldPayload = fields.first(where: { $0.number == 2 })?.payload else {
                return nil
            }

            return parseTextFieldStatus(
                payload: textFieldPayload,
                imeCounter: 0,
                appPackage: appPackage
            )
        }

        private static func parseTextFieldStatus(payload: [UInt8], imeCounter: Int, appPackage: String?) -> RemoteIMEStatus? {
            guard let fields = ProtoMessageCoder.decodeFields(payload) else { return nil }

            let fieldCounter = fields.first(where: { $0.number == 1 })?.intValue ?? 0
            let text = fields.first(where: { $0.number == 2 })?.stringValue ?? ""
            let selectionStart = fields.first(where: { $0.number == 3 })?.intValue ?? max(text.count - 1, 0)
            let selectionEnd = fields.first(where: { $0.number == 4 })?.intValue ?? selectionStart
            let label = fields.first(where: { $0.number == 6 })?.stringValue

            return RemoteIMEStatus(
                imeCounter: imeCounter,
                fieldCounter: fieldCounter,
                text: text,
                selectionStart: selectionStart,
                selectionEnd: selectionEnd,
                label: label,
                appPackage: appPackage
            )
        }
    }
}
