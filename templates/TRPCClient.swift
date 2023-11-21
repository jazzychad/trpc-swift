//
//  TRPCClient.swift
//  Generated by trpc-swift
//  Library Author: Marko Calasan
//

import Foundation

enum DecodableValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dictionary([String: DecodableValue])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let dbl = try? container.decode(Double.self) {
            self = .double(dbl)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else {
            let dict = try container.decode([String: DecodableValue].self)
            self = .dictionary(dict)
        }
    }
}

enum TRPCErrorCode: Int, Codable {
    // tRPC Defined
    case parseError = -32700
    case badRequest = -32600
    case internalServerError = -32603
    case unauthorized = -32001
    case forbidden = -32003
    case notFound = -32004
    case methodNotSupported = -32005
    case timeout = -32008
    case conflict = -32009
    case preconditionFailed = -32012
    case payloadTooLarge = -32013
    case unprocessableContent = -32022
    case tooManyRequests = -32029
    case clientClosedRequest = -32099
    
    // Application Defined
    case unknown = -1
    case missingOutputPayload = -2
}

struct TRPCError: Error, Decodable {
    let code: TRPCErrorCode
    let message: String?
    let data: DecodableValue?

    init(code: TRPCErrorCode, message: String? = nil, data: DecodableValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

struct TRPCRequest<T: Encodable>: Encodable {
    struct DataContainer: Encodable {
        let json: T?
    }
    
    let zero: DataContainer
    
    enum CodingKeys: String, CodingKey {
        case zero = "0"
    }
}

struct TRPCResponse<T: Decodable>: Decodable {
    struct Result: Decodable {
        struct DataContainer: Decodable {
            let json: T
        }
        
        let data: DataContainer
    }
    
    struct ErrorContainer: Decodable {
        let json: TRPCError
    }
    
    let result: Result?
    let error: ErrorContainer?
}

typealias TRPCMiddleware = (URLRequest) async throws -> URLRequest

class TRPCClient {
    struct EmptyObject: Codable {}
    
    static let shared = TRPCClient()
    
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        return formatter
    }()
    
    func sendQuery<Request: Encodable, Response: Decodable>(url: URL, middlewares: [TRPCMiddleware], input: Request) async throws -> Response {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let data = try JSONEncoder(dateEncodingStrategy: .formatted(dateFormatter)).encode(TRPCRequest(zero: .init(json: Request.self == EmptyObject.self ? nil : input)))
        
        components?.queryItems = [
            URLQueryItem(name: "batch", value: "1"),
            URLQueryItem(name: "input", value: String(data: data, encoding: .utf8)!)
        ]
        
        guard let url = components?.url else {
            throw NSError(domain: "", code: -1, userInfo: nil)
        }
        
        return try await send(url: url, httpMethod: "GET", middlewares: middlewares, bodyData: nil)
    }
    
    func sendMutation<Request: Encodable, Response: Decodable>(url: URL, middlewares: [TRPCMiddleware], input: Request) async throws -> Response {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let data = try JSONEncoder(dateEncodingStrategy: .formatted(dateFormatter)).encode(TRPCRequest(zero: .init(json: Request.self == EmptyObject.self ? nil : input)))
        
        components?.queryItems = [
            URLQueryItem(name: "batch", value: "1")
        ]
        
        guard let url = components?.url else {
            throw NSError(domain: "", code: -1, userInfo: nil)
        }
        
        return try await send(url: url, httpMethod: "POST", middlewares: middlewares, bodyData: data)
    }
    
    private func send<Response: Decodable>(url: URL, httpMethod: String, middlewares: [TRPCMiddleware], bodyData: Data?) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.httpBody = bodyData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        for middleware in middlewares {
            request = try await middleware(request)
        }
        
        request.httpMethod = httpMethod
        request.httpBody = bodyData
        
        let response = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder(dateDecodingStrategy: .formatted(dateFormatter)).decode([TRPCResponse<Response>].self, from: response.0)[0]
        
        if let error = decoded.error {
            throw error.json
        }
        
        if let result = decoded.result {
            return result.data.json
        }
        
        if Response.self == EmptyObject.self {
            return EmptyObject() as! Response
        }
        
        throw TRPCError(code: .missingOutputPayload, message: "Missing output payload.", data: nil)
    }
}

protocol TRPCClientData: AnyObject {
    var url: URL { get }
    var middlewares: [TRPCMiddleware] { get }
}
