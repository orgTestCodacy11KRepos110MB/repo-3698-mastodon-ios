// Copyright © 2023 Mastodon gGmbH. All rights reserved.

import Foundation
import Combine

extension Mastodon.API.Statuses {
    private static func historyEndpointURL(domain: String, statusID: Mastodon.Entity.Status.ID) -> URL {
        return Mastodon.API.endpointURL(domain: domain)
            .appendingPathComponent("statuses")
            .appendingPathComponent(statusID)
            .appendingPathComponent("history")
    }

    private static func statusSourceEndpointURL(domain: String, statusID: Mastodon.Entity.Status.ID) -> URL {
        return Mastodon.API.endpointURL(domain: domain)
            .appendingPathComponent("statuses")
            .appendingPathComponent(statusID)
            .appendingPathComponent("source")
    }

    public static func statusSource(
        forStatusID statusID: Mastodon.Entity.Status.ID,
        session: URLSession,
        domain: String,
        authorization: Mastodon.API.OAuth.Authorization?
    ) -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.StatusSource>, Error> {
        let url = statusSourceEndpointURL(domain: domain, statusID: statusID)
        let request = Mastodon.API.get(url: url, authorization: authorization)

        return session.dataTaskPublisher(for: request)
            .tryMap { (data: Data, response: URLResponse) in
                let value = try Mastodon.API.decode(type: Mastodon.Entity.StatusSource.self, from: data, response: response)
                return Mastodon.Response.Content(value: value, response: response)
            }
            .eraseToAnyPublisher()

    }


    //TODO: @zeitschlag add [documentation](https://docs.joinmastodon.org/methods/statuses/#history)
    public static func editHistory(
        forStatusID statusID: Mastodon.Entity.Status.ID,
        session: URLSession,
        domain: String,
        authorization: Mastodon.API.OAuth.Authorization?
    ) -> AnyPublisher<Mastodon.Response.Content<[Mastodon.Entity.StatusEdit]>, Error> {

        let url = historyEndpointURL(domain: domain, statusID: statusID)
        let request = Mastodon.API.get(url: url, authorization: authorization)

        return session.dataTaskPublisher(for: request)
            .tryMap { (data: Data, response: URLResponse) in
                let value = try Mastodon.API.decode(type: [Mastodon.Entity.StatusEdit].self, from: data, response: response)
                return Mastodon.Response.Content(value: value, response: response)
            }
            .eraseToAnyPublisher()
    }

    //TODO: @zeitschlag add [documentation](https://docs.joinmastodon.org/methods/statuses/#edit)
    public static func editStatus(
        forStatusID statusID: Mastodon.Entity.Status.ID,
        editStatusQuery: EditStatusQuery,
        session: URLSession,
        domain: String,
        authorization: Mastodon.API.OAuth.Authorization?
    ) -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.Status>, Error> {
        let url = statusEndpointURL(domain: domain, statusID: statusID)
        let request = Mastodon.API.put(url: url, query: editStatusQuery, authorization: authorization)

        return session.dataTaskPublisher(for: request)
            .tryMap { (data: Data, response: URLResponse) in
                let editedStatus = try Mastodon.API.decode(type: Mastodon.Entity.Status.self, from: data, response: response)
                return Mastodon.Response.Content(value: editedStatus, response: response)
            }
            .eraseToAnyPublisher()
    }
}

extension Mastodon.API.Statuses {
    public struct EditStatusQuery: Codable, PutQuery {
        var queryItems: [URLQueryItem]? = nil

        public let status: String?
        public let mediaIDs: [String]?
        public let pollOptions: [String]?
        public let pollExpiresIn: Int?
        public let pollMultipleAnswers: Bool?
        public let sensitive: Bool?
        public let spoilerText: String?
        public let visibility: Mastodon.Entity.Status.Visibility?
        public let language: String?

        public init(
            status: String?,
            mediaIDs: [String]?,
            pollOptions: [String]?,
            pollExpiresIn: Int?,
            pollMultipleAnswers: Bool?,
            sensitive: Bool?,
            spoilerText: String?,
            visibility: Mastodon.Entity.Status.Visibility?,
            language: String?
        ) {
            self.status = status
            self.mediaIDs = mediaIDs
            self.pollOptions = pollOptions
            self.pollExpiresIn = pollExpiresIn
            self.pollMultipleAnswers = pollMultipleAnswers
            self.sensitive = sensitive
            self.spoilerText = spoilerText
            self.visibility = visibility
            self.language = language
        }

        enum CodingKeys: String, CodingKey {
            case status
            case mediaIDs
            case pollOptions
            case pollExpiresIn
            case pollMultipleAnswers
            case sensitive
            case spoilerText
            case visibility
            case language
        }
    }
}