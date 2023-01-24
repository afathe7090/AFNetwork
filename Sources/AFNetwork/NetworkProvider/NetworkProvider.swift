import Foundation
import Combine
public protocol NetworkProvidable {
    func requestPublisher<T: Decodable>(type: T.Type, endpoint: Endpoint) -> AnyPublisher<T, NetworkError>
    func request<T: Decodable>(type: T.Type, endpoint: Endpoint, completion: @escaping (Result<T, NetworkError>) -> Void)
}

public final class NetworkProvider: NetworkProvidable {
    private let session: URLSessionable
    private let globalQueue: Dispatching
    private let decoder: JSONDecodable
    
    public init(
        session: URLSessionable = URLSession.shared,
        globalQueue: Dispatching = DispatchQueue.global(),
        decoder: JSONDecodable = JSONDecoder(.convertFromSnakeCase)
    ) {
        self.session = session
        self.globalQueue = globalQueue
        self.decoder = decoder
    }
    
    public func request<T: Decodable>(type: T.Type, endpoint: Endpoint, completion: @escaping (Result<T, NetworkError>) -> Void) {
        
        let request = URLRequest(endpoint: endpoint)
        
        let task = session.dataTask(request: request) { data, response, error in
            print(" 🔗 URL: => \(String(describing: request.url?.absoluteString))")
            print(" 💡 Headers: =>  \(String(describing: request.allHTTPHeaderFields))")
            print(" ⏰ Resquest Time: => \(request.timeoutInterval / 60)s")
            if let error = error {
                print(" 🔥 \(error.localizedDescription)")
                completion(.failure(.transportError(error)))
            }
        
            guard let data = data else {
                return completion(.failure(.noData))
            }
            
            guard let dataString = String(bytes: data, encoding: .utf8) else {
                return completion(.failure(.invalidDataToStringCast))
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return completion(.failure(.invalidURLResponseToHTTPResponseCast))
            }
            
            let statusCode = httpResponse.statusCode
            
            switch statusCode {
            case 200...299:
                do {
                    let model = try self.decoder.decode(T.self, from: data)
                    print(" ✅ Data: => \(model)")
                    completion(.success(model))
                } catch let error {
                    print(" 🔥 \(error.localizedDescription)")
                    completion(.failure(.decodeFailure(error)))
                }
            case 400...499:
                completion(.failure(.clientError(statusCode, dataString)))
            case 500...599:
                completion(.failure(.serverError(statusCode, dataString)))
            default:
                completion(.failure(.untreatedCode(statusCode)))
            }
            print(" 📲 Status Code: => \(statusCode)")
        }
        
        globalQueue.async {
            task.resume()
        }
    }
}
