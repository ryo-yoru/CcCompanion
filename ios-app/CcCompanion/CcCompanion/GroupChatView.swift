//
//  GroupChatView.swift
//  CcCompanion
//
//  Workgroup chat view (build 214 — 输入框 + agent picker + 视觉对齐 ChatView).
//

import SwiftUI

struct GroupChatView: View {
    @StateObject private var store = GroupStore()
    @AppStorage("group_name") private var groupName: String = "群聊"
    @AppStorage("chat_font_size_level") private var chatFontLevel: String = "medium"
    @State private var searchVisible = false
    @State private var searchText = ""
    @State private var showFavorites = false
    @State private var favoriteMessageIds: Set<String> = GroupFavoritesStore.ids()

    // Build 214 T1 — input bar state
    @State private var draftText: String = ""
    @FocusState private var inputFocused: Bool
    @State private var showAgentPicker: Bool = false
    @State private var sending: Bool = false
    @State private var inputToast: String = ""

    private var chatBodySize: CGFloat {
        chatFontLevel == "small" ? 15 : chatFontLevel == "large" ? 18 : 17
    }

    private var visibleMessages: [GroupMessage] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard searchVisible, !q.isEmpty else { return store.messages }
        return store.messages.filter { message in
            GroupMessageSearch.matches(message, member: store.member(for: message.senderId), query: q)
        }
    }

    private var headerTitle: String {
        let trimmed = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "群聊" : trimmed
    }

    var body: some View {
        VStack(spacing: 0) {
            // Build 214 T4 — 自画 header (照 ChatView 模式)
            customHeader

            GroupChatStatusStrip(store: store)
            if searchVisible {
                GroupSearchBar(
                    text: $searchText,
                    visibleCount: visibleMessages.count,
                    totalCount: store.messages.count,
                    onClose: {
                        searchText = ""
                        searchVisible = false
                    }
                )
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if store.loading && store.messages.isEmpty {
                            ProgressView("加载群聊")
                                .font(.ccSerifAdaptive(size: 14))
                                .foregroundStyle(Color.ccTextDim)
                                .padding(.top, 40)
                        } else if store.messages.isEmpty {
                            emptyState
                        } else if visibleMessages.isEmpty {
                            GroupSearchEmptyState(query: searchText)
                        } else {
                            ForEach(visibleMessages) { message in
                                let member = store.member(for: message.senderId)
                                GroupMessageRow(
                                    message: message,
                                    member: member,
                                    bodySize: chatBodySize,
                                    isFavorite: favoriteMessageIds.contains(message.id),
                                    onToggleFavorite: {
                                        toggleFavorite(message: message, member: member)
                                    }
                                )
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

            if !inputToast.isEmpty {
                Text(inputToast)
                    .font(.ccSerifAdaptive(size: 11))
                    .foregroundStyle(Color.ccTextDim)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Build 214 T1 — input bar
            GroupInputBar(
                draft: $draftText,
                sending: $sending,
                inputFocused: $inputFocused,
                onSend: { commitSend() },
                onAt: { showAgentPicker = true },
                onPlusFile: {
                    inputToast = "T1 backend wire pending — 文件发送待接 /group/append"
                },
                onPlusCamera: {
                    inputToast = "T1 backend wire pending — 拍照待接 /group/append"
                },
                onImage: {
                    inputToast = "T1 backend wire pending — 图片待接 /group/append"
                }
            )
        }
        .background(Color.ccBg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showFavorites) {
            NavigationStack { GroupFavoritesView() }
        }
        .sheet(isPresented: $showAgentPicker) {
            AgentMentionPicker(members: store.agentMembers) { member in
                insertMention(member: member)
                showAgentPicker = false
            }
        }
        .onAppear {
            favoriteMessageIds = GroupFavoritesStore.ids()
            store.start()
        }
        .onDisappear { store.stop() }
        .onReceive(NotificationCenter.default.publisher(for: .ccGroupFavoritesDidChange)) { _ in
            favoriteMessageIds = GroupFavoritesStore.ids()
        }
        .refreshable { await store.refreshNow() }
    }

    @ViewBuilder
    private var customHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.ccAccent)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.ccCard.opacity(0.6)))
            Text(headerTitle)
                .font(.ccSerifAdaptive(size: 17, weight: .semibold))
                .foregroundStyle(Color.ccAccent)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    searchVisible.toggle()
                    if !searchVisible { searchText = "" }
                }
            } label: {
                Image(systemName: searchVisible ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .font(.ccSerifAdaptive(size: 20, weight: .semibold))
                    .foregroundStyle(Color.ccAccent)
            }
            Button {
                showFavorites = true
            } label: {
                Image(systemName: "bookmark.fill")
                    .font(.ccSerifAdaptive(size: 20, weight: .semibold))
                    .foregroundStyle(Color.ccAccent)
            }
            Button {
                Task { await store.refreshNow() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.ccSerifAdaptive(size: 18, weight: .semibold))
                    .foregroundStyle(Color.ccAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.ccBg)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.ccAccent)
            Text("群聊暂无消息")
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

    private func toggleFavorite(message: GroupMessage, member: GroupMember) {
        let isNowFavorite = GroupFavoritesStore.toggle(message: message, member: member)
        favoriteMessageIds = GroupFavoritesStore.ids()
        CcToastBus.shared.show(isNowFavorite ? "已收藏群聊消息" : "已取消收藏")
    }

    // Build 214 T1 — 在 draftText 当前末尾插入 @displayName (含尾空格).
    // SwiftUI TextField 不暴露 cursor 位置 — 直接 append, 跟 iOS 微信/Telegram pattern 一致.
    private func insertMention(member: GroupMember) {
        let token = "@\(member.displayName) "
        if draftText.isEmpty {
            draftText = token
        } else if draftText.hasSuffix(" ") || draftText.hasSuffix("\n") {
            draftText += token
        } else {
            draftText += " " + token
        }
        inputFocused = true
    }

    private func commitSend() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }
        let mentions = resolveMentions(in: text)
        sending = true
        inputToast = ""
        Task {
            let ok = await store.sendUserMessage(text: text, mentions: mentions)
            await MainActor.run {
                sending = false
                if ok {
                    draftText = ""
                } else {
                    inputToast = store.lastError ?? "发送失败"
                }
            }
        }
    }

    /// 把消息文本里 @xxx 解析成 agent id list. 匹配 displayName 跟 id 两种.
    private func resolveMentions(in text: String) -> [String] {
        let pattern = #"@([A-Za-z0-9_\-]+|[\u{4E00}-\u{9FFF}]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var hits: [String] = []
        let agents = store.agentMembers
        for m in matches where m.numberOfRanges >= 2 {
            let token = nsText.substring(with: m.range(at: 1))
            if let hit = agents.first(where: { $0.displayName == token || $0.id == token || $0.title == token }) {
                if !hits.contains(hit.id) { hits.append(hit.id) }
            }
        }
        return hits
    }
}

// MARK: - Status Strip

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
                            // Build 214 T2 — agent 名字后带模型名 半透明小字
                            if let model = member.model, !model.isEmpty {
                                Text("· \(model)")
                                    .font(.ccSerifAdaptive(size: 11))
                                    .foregroundStyle(Color.ccTextDim)
                                    .lineLimit(1)
                            }
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

// MARK: - Message Row

private struct GroupMessageRow: View {
    let message: GroupMessage
    let member: GroupMember
    let bodySize: CGFloat
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

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
                    // Build 214 T2 — name · model
                    if let model = member.model, !model.isEmpty {
                        Text("· \(model)")
                            .font(.ccSerifAdaptive(size: 11))
                            .foregroundStyle(Color.ccTextDim.opacity(0.7))
                            .lineLimit(1)
                    }
                    Text(message.shortTime)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.ccTextDim.opacity(0.8))
                    if !message.isHumanSender { messageTypeBadge }
                }

                // Build 214 T4 — 字号/bubble 对齐 ChatView (chatBodySize / cornerRadius 14 / pad 12,8)
                highlightedText(message.text)
                    .font(.ccSerifAdaptive(size: bodySize))
                    .foregroundStyle(Color.ccText)
                    .lineSpacing(3)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(bubbleColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.ccTextDim.opacity(0.08), lineWidth: 0.5)
                    )
                    .frame(maxWidth: 330, alignment: message.isHumanSender ? .trailing : .leading)
            }

            if message.isHumanSender {
                avatar
            }

            if !message.isHumanSender { Spacer(minLength: 46) }
        }
        .contextMenu {
            Button(action: onToggleFavorite) {
                Label(isFavorite ? "取消收藏" : "收藏", systemImage: isFavorite ? "star.slash" : "star")
            }
        }
    }

    private var avatar: some View {
        GroupAvatarView(member: member, size: 32)
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

// MARK: - Typing Indicator

private struct GroupTypingIndicator: View {
    let members: [GroupMember]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(members.prefix(3)) { member in
                GroupAvatarView(member: member, size: 26)
            }
            Text("\(joinedLabel) 正在输入")
                .font(.ccSerifAdaptive(size: 13))
                .foregroundStyle(Color.ccTextDim)
            GroupTypingDots()
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.ccCard.opacity(0.72)))
    }

    /// Build 214 T2 — typing 行 agent 名字后带模型名 (有 model 才显示 · model).
    private var joinedLabel: String {
        members.map { member -> String in
            if let model = member.model, !model.isEmpty {
                return "\(member.title) · \(model)"
            }
            return member.title
        }.joined(separator: "、")
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

// MARK: - Input Bar (build 214 T1)

private struct GroupInputBar: View {
    @Binding var draft: String
    @Binding var sending: Bool
    var inputFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onAt: () -> Void
    let onPlusFile: () -> Void
    let onPlusCamera: () -> Void
    let onImage: () -> Void

    private var hasContent: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button {
                    onPlusCamera()
                } label: { Label("拍照", systemImage: "camera") }
                Button {
                    onPlusFile()
                } label: { Label("文件", systemImage: "doc") }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.ccSerifAdaptive(size: 28, weight: .bold))
                    .foregroundStyle(Color.ccTextDim)
            }
            .disabled(sending)

            // @ button — picker
            Button {
                onAt()
            } label: {
                Image(systemName: "at")
                    .font(.ccSerifAdaptive(size: 22, weight: .semibold))
                    .foregroundStyle(Color.ccTextDim)
            }
            .disabled(sending)

            ZStack(alignment: .trailing) {
                TextField("说点什么…", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.system(size: 17))
                    .tint(Color.ccAccent)
                    .padding(.leading, 6)
                    .textFieldStyle(.roundedBorder)
                    .focused(inputFocused)
                    .submitLabel(.send)
                    .onSubmit { onSend() }
                    .onChange(of: draft) { oldValue, newValue in
                        if newValue.hasSuffix("\n") && !oldValue.hasSuffix("\n") {
                            draft = String(newValue.dropLast())
                            onSend()
                        }
                    }
                    .padding(.trailing, 40)

                if !inputFocused.wrappedValue {
                    // mic inset placeholder — 群聊暂不接语音输入 (跟 ChatView 一致样式 但 disabled).
                    Image(systemName: "mic")
                        .font(.ccSerifAdaptive(size: 17))
                        .foregroundStyle(Color.ccTextDim.opacity(0.5))
                        .padding(.trailing, 10)
                }
            }

            // 图片按钮 (照 ChatInputBar 摘出加号菜单的设计)
            Button {
                onImage()
            } label: {
                Image(systemName: "photo.fill")
                    .font(.ccSerifAdaptive(size: 20, weight: .semibold))
                    .foregroundStyle(Color.ccTextDim)
            }
            .disabled(sending)

            Button {
                onSend()
            } label: {
                Image(systemName: sending ? "ellipsis.circle" : "paperplane.fill")
                    .font(.ccSerifAdaptive(size: 20, weight: .semibold))
                    .scaleEffect(x: sending ? 1 : -1, y: 1)
                    .rotationEffect(.degrees(sending ? 0 : -15))
                    .foregroundStyle(Color.ccAccent.opacity(hasContent ? 1.0 : 0.35))
            }
            .disabled(sending || !hasContent)
        }
        .padding(10)
        .background(Color.ccBg)
    }
}

// MARK: - Agent @ Picker

private struct AgentMentionPicker: View {
    let members: [GroupMember]
    let onPick: (GroupMember) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(members) { member in
                    Button {
                        onPick(member)
                    } label: {
                        HStack(spacing: 12) {
                            GroupAvatarView(member: member, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.displayName)
                                    .font(.ccSerifAdaptive(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.ccText)
                                if let model = member.model, !model.isEmpty {
                                    Text(model)
                                        .font(.ccSerifAdaptive(size: 11))
                                        .foregroundStyle(Color.ccTextDim)
                                }
                            }
                            Spacer()
                            Text("@\(member.id)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.ccTextDim)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("选 agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack {
        GroupChatView()
    }
}
