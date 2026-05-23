//
//  GroupChatView.swift
//  CcCompanion
//
//  Read-only workgroup view for multi-agent coordination messages.
//

import SwiftUI

struct GroupChatView: View {
    @StateObject private var store = GroupStore()

    var body: some View {
        VStack(spacing: 0) {
            GroupChatStatusStrip(store: store)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if store.loading && store.messages.isEmpty {
                            ProgressView("加载工作群")
                                .font(.ccSerifAdaptive(size: 14))
                                .foregroundStyle(Color.ccTextDim)
                                .padding(.top, 40)
                        } else if store.messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(store.messages) { message in
                                GroupMessageRow(message: message, member: store.member(for: message.senderId))
                                    .id(message.id)
                            }
                        }

                        if !store.typingMembers.isEmpty {
                            GroupTypingIndicator(members: store.typingMembers)
                                .id("typing-indicator")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .background(Color.ccBg)
                .onChange(of: store.messages.last?.id) { _, id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
                .onChange(of: store.typingMembers.map(\.id).joined(separator: ",")) { _, marker in
                    guard !marker.isEmpty else { return }
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo("typing-indicator", anchor: .bottom)
                    }
                }
            }
        }
        .background(Color.ccBg)
        .navigationTitle("工作群")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await store.refreshNow() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .tint(Color.ccAccent)
            }
        }
        .onAppear { store.start() }
        .onDisappear { store.stop() }
        .refreshable { await store.refreshNow() }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.ccAccent)
            Text("工作群暂无消息")
                .font(.ccSerifAdaptive(size: 16, weight: .semibold))
                .foregroundStyle(Color.ccText)
            Text("打开后会从 Mac 上的 /group/poll 拉取最近协作消息。")
                .font(.ccSerifAdaptive(size: 13))
                .foregroundStyle(Color.ccTextDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }
}

private struct GroupChatStatusStrip: View {
    @ObservedObject var store: GroupStore

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(statusMembers) { member in
                        let status = store.agentStatus[member.id]
                        HStack(spacing: 6) {
                            Circle()
                                .fill(status?.state == "online" ? Color.green : Color.ccTextDim.opacity(0.35))
                                .frame(width: 7, height: 7)
                            Text(member.title)
                                .font(.ccSerifAdaptive(size: 12, weight: .semibold))
                                .foregroundStyle(Color.ccText)
                            if status?.isTyping == true {
                                Text("typing")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.ccAccent)
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.ccCard.opacity(0.75)))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            if let lastError = store.lastError {
                Text(lastError)
                    .font(.ccSerifAdaptive(size: 11))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 7)
            }
        }
        .background(Color.ccBg)
    }

    private var statusMembers: [GroupMember] {
        let preferred = ["opia", "sonnet", "di", "shu", "opus47_fresh"]
        return preferred.map { store.member(for: $0) }
    }
}

private struct GroupMessageRow: View {
    let message: GroupMessage
    let member: GroupMember

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isHumanSender { Spacer(minLength: 46) }

            if !message.isHumanSender {
                avatar
            }

            VStack(alignment: message.isHumanSender ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if message.isHumanSender { messageTypeBadge }
                    Text(member.title)
                        .font(.ccSerifAdaptive(size: 12, weight: .semibold))
                        .foregroundStyle(Color.ccTextDim)
                    Text(message.shortTime)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.ccTextDim.opacity(0.8))
                    if !message.isHumanSender { messageTypeBadge }
                }

                highlightedText(message.text)
                    .font(.ccSerifAdaptive(size: 15))
                    .foregroundStyle(Color.ccText)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(bubbleColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.ccTextDim.opacity(0.08), lineWidth: 0.5)
                    )
                    .frame(maxWidth: 330, alignment: message.isHumanSender ? .trailing : .leading)
            }

            if message.isHumanSender {
                avatar
            }

            if !message.isHumanSender { Spacer(minLength: 46) }
        }
    }

    private var avatar: some View {
        Text(member.avatarText)
            .font(.ccSerifAdaptive(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Circle().fill(memberColor))
    }

    @ViewBuilder
    private var messageTypeBadge: some View {
        if message.messageType != "chat" {
            Text(message.messageType.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(messageTypeColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(messageTypeColor.opacity(0.12)))
        }
    }

    private var bubbleColor: Color {
        if message.isHumanSender { return Color.ccAccent.opacity(0.16) }
        if message.isBlock { return Color.red.opacity(0.12) }
        if message.isTask { return Color.blue.opacity(0.11) }
        if message.isShip { return Color.green.opacity(0.12) }
        return Color.ccCard.opacity(0.82)
    }

    private var messageTypeColor: Color {
        if message.isBlock { return .red }
        if message.isTask { return .blue }
        if message.isShip { return .green }
        return Color.ccAccent
    }

    private var memberColor: Color {
        switch member.color {
        case "orange": return Color(red: 0.92, green: 0.45, blue: 0.20)
        case "blue": return Color(red: 0.25, green: 0.48, blue: 0.95)
        case "green": return Color(red: 0.20, green: 0.62, blue: 0.38)
        case "purple": return Color(red: 0.52, green: 0.38, blue: 0.86)
        case "slate": return Color(red: 0.38, green: 0.44, blue: 0.52)
        default: return Color.ccAccent
        }
    }

    private func highlightedText(_ text: String) -> Text {
        let pattern = #"@([A-Za-z0-9_\-]+|[\u{4E00}-\u{9FFF}]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Text(text)
        }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return Text(text) }

        var result = Text("")
        var cursor = text.startIndex
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            if cursor < range.lowerBound {
                result = result + Text(String(text[cursor..<range.lowerBound]))
            }
            result = result + Text(String(text[range]))
                .foregroundColor(Color.ccAccent)
                .bold()
            cursor = range.upperBound
        }
        if cursor < text.endIndex {
            result = result + Text(String(text[cursor..<text.endIndex]))
        }
        return result
    }
}

private struct GroupTypingIndicator: View {
    let members: [GroupMember]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(members.prefix(3)) { member in
                Text(member.avatarText)
                    .font(.ccSerifAdaptive(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.ccAccent.opacity(0.85)))
            }
            Text("\(members.map(\.title).joined(separator: "、")) 正在输入")
                .font(.ccSerifAdaptive(size: 13))
                .foregroundStyle(Color.ccTextDim)
            GroupTypingDots()
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.ccCard.opacity(0.72)))
    }
}

private struct GroupTypingDots: View {
    var body: some View {
        TimelineView(.periodic(from: Date(), by: 0.32)) { context in
            let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.32) % 3
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.ccAccent.opacity(phase == i ? 1.0 : 0.35))
                        .frame(width: 5, height: 5)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        GroupChatView()
    }
}
