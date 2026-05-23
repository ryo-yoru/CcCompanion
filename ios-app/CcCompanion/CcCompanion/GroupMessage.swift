//
//  GroupMessage.swift
//  CcCompanion
//
//  Workgroup chat records from apns-server /group endpoints.
//

import Foundation
import SwiftUI

nonisolated struct GroupMessage: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let ts: String
    let conversationId: String?
    let senderId: String
    let senderModel: String?
    let text: String
    let mentions: [String]
    let parentMsgId: String?
    let replyTo: String?
    let source: String?
    let messageType: String
    let taskId: String?
    let parentTaskId: String?
    let owner: String?

    enum CodingKeys: String, CodingKey {
        case id, ts, text, mentions, source, owner
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case senderModel = "sender_model"
        case parentMsgId = "parent_msg_id"
        case replyTo = "reply_to"
        case messageType = "message_type"
        case taskId = "task_id"
        case parentTaskId = "parent_task_id"
    }

    init(
        id: String,
        ts: String,
        conversationId: String? = nil,
        senderId: String,
        senderModel: String? = nil,
        text: String,
        mentions: [String] = [],
        parentMsgId: String? = nil,
        replyTo: String? = nil,
        source: String? = nil,
        messageType: String = "chat",
        taskId: String? = nil,
        parentTaskId: String? = nil,
        owner: String? = nil
    ) {
        self.id = id
        self.ts = ts
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderModel = senderModel
        self.text = text
        self.mentions = mentions
        self.parentMsgId = parentMsgId
        self.replyTo = replyTo
        self.source = source
        self.messageType = messageType
        self.taskId = taskId
        self.parentTaskId = parentTaskId
        self.owner = owner
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.ts = try c.decodeIfPresent(String.self, forKey: .ts) ?? ""
        self.conversationId = try c.decodeIfPresent(String.self, forKey: .conversationId)
        self.senderId = try c.decodeIfPresent(String.self, forKey: .senderId) ?? "unknown"
        self.senderModel = try c.decodeIfPresent(String.self, forKey: .senderModel)
        self.text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.mentions = try c.decodeIfPresent([String].self, forKey: .mentions) ?? []
        self.parentMsgId = try c.decodeIfPresent(String.self, forKey: .parentMsgId)
        self.replyTo = try c.decodeIfPresent(String.self, forKey: .replyTo)
        self.source = try c.decodeIfPresent(String.self, forKey: .source)
        self.messageType = try c.decodeIfPresent(String.self, forKey: .messageType) ?? "chat"
        self.taskId = try c.decodeIfPresent(String.self, forKey: .taskId)
        self.parentTaskId = try c.decodeIfPresent(String.self, forKey: .parentTaskId)
        self.owner = try c.decodeIfPresent(String.self, forKey: .owner)
    }

    var isHumanSender: Bool { senderId == "amian" }
    var isShip: Bool { messageType == "ship" }
    var isTask: Bool { messageType == "task" }
    var isBlock: Bool { messageType == "block" }

    var shortTime: String {
        guard let tIndex = ts.firstIndex(of: "T") else { return "" }
        let afterT = ts[ts.index(after: tIndex)...]
        return String(afterT.prefix(5))
    }
}

nonisolated struct GroupMember: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let displayName: String
    let kind: String?
    let avatar: String?
    let color: String?
    let model: String?
    let tmux: String?
    let canReply: Bool?
    let optional: Bool?

    enum CodingKeys: String, CodingKey {
        case id, kind, avatar, color, model, tmux, optional
        case displayName = "display_name"
        case canReply = "can_reply"
    }

    var title: String {
        if id == "sonnet", displayName.lowercased() == "sonnet" {
            return "小豹"
        }
        return displayName
    }

    var avatarText: String {
        if let avatar, !avatar.isEmpty { return avatar }
        return String(title.prefix(1))
    }

    static let defaults: [GroupMember] = [
        GroupMember(id: "amian", displayName: "阿眠", kind: "human", avatar: "眠", color: "neutral", model: nil, tmux: nil, canReply: false, optional: nil),
        GroupMember(id: "opia", displayName: "Opia", kind: "agent", avatar: "O", color: "orange", model: "Claude Opus 4.7 1m", tmux: "opia", canReply: true, optional: nil),
        GroupMember(id: "sonnet", displayName: "小豹", kind: "agent", avatar: "S", color: "blue", model: "Claude Sonnet 4.6", tmux: "bao", canReply: true, optional: nil),
        GroupMember(id: "shu", displayName: "枢", kind: "agent", avatar: "枢", color: "green", model: "Codex GPT-5.5", tmux: "shu", canReply: true, optional: nil),
        GroupMember(id: "opus47_fresh", displayName: "Opus47-fresh", kind: "agent", avatar: "F", color: "purple", model: "Claude Opus 4.7 fresh", tmux: "opus47-fresh", canReply: true, optional: true),
        GroupMember(id: "di", displayName: "砥", kind: "agent", avatar: "砥", color: "slate", model: "Claude Opus 4.7", tmux: "砥", canReply: true, optional: nil),
    ]

    static var defaultMap: [String: GroupMember] {
        Dictionary(uniqueKeysWithValues: defaults.map { ($0.id, $0) })
    }
}

nonisolated struct GroupAgentStatus: Codable, Hashable, Sendable {
    let state: String?
    let tmux: String?
    let lastSeen: String?
    let isTyping: Bool?
    let typingSince: String?
    let dispatchId: String?
    let statusText: String?

    enum CodingKeys: String, CodingKey {
        case state, tmux
        case lastSeen = "last_seen"
        case isTyping = "is_typing"
        case typingSince = "typing_since"
        case dispatchId = "dispatch_id"
        case statusText = "status_text"
    }
}

nonisolated struct GroupStatusSnapshot: Codable, Hashable, Sendable {
    let agents: [String: GroupAgentStatus]
}

