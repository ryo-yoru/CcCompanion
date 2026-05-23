//
//  GroupStore.swift
//  CcCompanion
//
//  Polling store for apns-server workgroup chat.
//

import Foundation
import Combine

nonisolated struct GroupPollResponse: Codable, Sendable {
    let ok: Bool
    let records: [GroupMessage]
    let count: Int?
    let lastTs: String?
    let status: GroupStatusSnapshot?

    enum CodingKeys: String, CodingKey {
        case ok, records, count, status
        case lastTs = "last_ts"
    }
}

nonisolated struct GroupRosterResponse: Codable, Sendable {
    let ok: Bool
    let roster: [GroupMember]
    let status: GroupStatusSnapshot?
}

actor GroupNetworkClient {
    static let shared = GroupNetworkClient()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 25
        return URLSession(configuration: cfg)
    }()

    func fetchRoster() async throws -> GroupRosterResponse {
        let url = CcServerConfig.serverURL.appendingPathComponent("group/roster")
        var request = CcServerConfig.authenticatedRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response)
        return try JSONDecoder().decode(GroupRosterResponse.self, from: data)
    }

    func fetchPoll(since: String?, limit: Int) async throws -> GroupPollResponse {
        let url = CcServerConfig.serverURL.appendingPathComponent("group/poll")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let since, !since.isEmpty {
            items.append(URLQueryItem(name: "since", value: since))
        }
        components?.queryItems = items
        guard let finalURL = components?.url else { throw URLError(.badURL) }
        var request = CcServerConfig.authenticatedRequest(url: finalURL)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response)
        return try JSONDecoder().decode(GroupPollResponse.self, from: data)
    }

    private static func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

@MainActor
final class GroupStore: ObservableObject {
    @Published var messages: [GroupMessage] = []
    @Published var membersById: [String: GroupMember] = GroupMember.defaultMap
    @Published var agentStatus: [String: GroupAgentStatus] = [:]
    @Published var loading: Bool = false
    @Published var lastError: String? = nil

    private var pollTask: Task<Void, Never>? = nil
    private var lastTs: String? = nil
    private let client = GroupNetworkClient.shared

    var typingMembers: [GroupMember] {
        agentStatus
            .filter { $0.value.isTyping == true }
            .compactMap { membersById[$0.key] ?? GroupMember.defaultMap[$0.key] }
            .sorted { $0.title < $1.title }
    }

    func member(for id: String) -> GroupMember {
        if let member = membersById[id] { return member }
        if let member = GroupMember.defaultMap[id] { return member }
        return GroupMember(id: id, displayName: id, kind: nil, avatar: nil, color: "neutral", model: nil, tmux: nil, canReply: nil, optional: nil)
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.reload()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await self?.pollNext()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func reload() async {
        loading = true
        lastError = nil
        lastTs = nil
        await fetchRoster()
        await fetchMessages(reset: true)
    }

    func refreshNow() async {
        await fetchRoster()
        await fetchMessages(reset: false)
    }

    private func pollNext() async {
        await fetchMessages(reset: false)
    }

    private func fetchRoster() async {
        do {
            let response = try await client.fetchRoster()
            var map = GroupMember.defaultMap
            for member in response.roster {
                map[member.id] = member
            }
            membersById = map
            if let status = response.status {
                agentStatus = status.agents
            }
            lastError = nil
        } catch {
            lastError = "工作群成员加载失败: \(error.localizedDescription)"
        }
    }

    private func fetchMessages(reset: Bool) async {
        do {
            let response = try await client.fetchPoll(since: reset ? nil : lastTs, limit: reset ? 120 : 80)
            if reset {
                messages = response.records
            } else {
                merge(records: response.records)
            }
            if let status = response.status {
                agentStatus = status.agents
            }
            if let last = response.lastTs, !last.isEmpty {
                lastTs = last
            } else if let last = response.records.last?.ts, !last.isEmpty {
                lastTs = last
            }
            loading = false
            lastError = nil
        } catch {
            loading = false
            lastError = "工作群消息加载失败: \(error.localizedDescription)"
        }
    }

    private func merge(records: [GroupMessage]) {
        guard !records.isEmpty else { return }
        var byId = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
        for record in records {
            byId[record.id] = record
        }
        messages = byId.values.sorted { lhs, rhs in
            if lhs.ts == rhs.ts { return lhs.id < rhs.id }
            return lhs.ts < rhs.ts
        }
    }
}
