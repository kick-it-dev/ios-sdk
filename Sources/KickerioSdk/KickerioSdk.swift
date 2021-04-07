import Foundation

public enum KickerioError: Error {
    case noValueFound(forKey: String)
    case badType(forKey: String, expectedType: String, actualType: String)
    case badURL
    case badResponse(response: URLResponse?)
    case couldNotParseData(data: Data?)

    var errorDescription: String? {
        switch self {
        case let .noValueFound(key):
            return "Could not find value for key: \(key)."
        case let .badType(key, expectedType, actualType):
            return "Value for key \"\(key)\" has wrong type. Expected \(expectedType), got \(actualType)."
        case .badURL:
            return "Could not construct Kickerio base URL."
        case let .badResponse(response):
            return "Received bad response from Kickerio server: \(String(describing: response))."
        case let .couldNotParseData(data: data):
            let dataString: String?
            if let data = data {
                dataString = String(data: data, encoding: .utf8)
            } else {
                dataString = nil
            }
            return "Could not parse data from Kickerio server: \"\(String(describing: dataString))\"."
        }
    }
}

public final class KickerioSdk {
    public typealias CompletionHandler = (Result<KickerioResponse, Swift.Error>) -> Void

    enum Error: Swift.Error {
        case badURL
    }

    private static let baseURL = "http://localhost:3000"
    private static let apiKeyPlistKey = "kickerio_api_key"
    private static let appNamePlistKey = "CFBundleName"
    private static let appVersionPlistKey = "CFBundleShortVersionString"
    private static let buildNumberPlistKey = "CFBundleVersion"

    private let apiKey: String
    private let appName: String
    private let appVersion: String
    private let buildNumber: String
    private let platformVersion: String
    private let parameters: [String: String]
    private let urlSession: URLSession

    public convenience init(bundle: Bundle = .main,
                            processInfo: ProcessInfo = .processInfo,
                            parameters: [String: String] = [:],
                            urlSession: URLSession = .shared) throws {
        self.init(apiKey: try bundle.value(forKey: Self.apiKeyPlistKey),
                  appName: try bundle.value(forKey: Self.appNamePlistKey),
                  appVersion: try bundle.value(forKey: Self.appVersionPlistKey),
                  buildNumber: try bundle.value(forKey: Self.buildNumberPlistKey),
                  platformVersion: processInfo.operatingSystemVersionString,
                  parameters: parameters,
                  urlSession: urlSession)
    }

    public init(apiKey: String,
                appName: String,
                appVersion: String,
                buildNumber: String,
                platformVersion: String,
                parameters: [String: String],
                urlSession: URLSession) {
        self.apiKey = apiKey
        self.appName = appName
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.platformVersion = platformVersion
        self.parameters = parameters
        self.urlSession = urlSession
    }

    public func checkApplicationDeprecation(onComplete: @escaping CompletionHandler) {
        guard let url = URL(string: "\(Self.baseURL)/api/v1/target-checks") else {
            assertionFailure("Error initializing KickerIO URL")
            onComplete(.failure(KickerioError.badURL))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        urlRequest.setValue(appName, forHTTPHeaderField: "X-KICKERIO-APP-NAME")
        urlRequest.setValue(appVersion, forHTTPHeaderField: "X-KICKERIO-APP-VERSION")
        urlRequest.setValue(buildNumber, forHTTPHeaderField: "X-KICKERIO-BUILD-NUMBER")
        urlRequest.setValue("iOS", forHTTPHeaderField: "X-KICKERIO-PLATFORM")
        urlRequest.setValue(platformVersion, forHTTPHeaderField: "X-KICKERIO-PLATFORM-OS-VERSION")

        let body = [
            "data": parameters
        ]

        let encoder = JSONEncoder()
        do {
            let bodyData = try encoder.encode(body)
            urlRequest.httpBody = bodyData
        } catch {
            onComplete(.failure(error))
            return
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        urlSession.dataTask(with: urlRequest, completionHandler: { data, response, error in
            if let error = error {
                onComplete(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                onComplete(.failure(KickerioError.badResponse(response: response)))
                return
            }

            guard let nonNilData = data,
                  let kickerioResponse = try? decoder.decode(KickerioResponse.self, from: nonNilData) else {
                onComplete(.failure(KickerioError.couldNotParseData(data: data)))
                return
            }

            onComplete(.success(kickerioResponse))
        }).resume()
    }
}

extension Bundle {
    func value<T>(forKey key: String) throws -> T {
        guard let value = object(forInfoDictionaryKey: key) else {
            throw KickerioError.noValueFound(forKey: key)
        }
        guard let coercedValue = value as? T else {
            throw KickerioError.badType(forKey: key, expectedType: "\(T.self)", actualType: "\(type(of: value))")
        }
        return coercedValue
    }
}
