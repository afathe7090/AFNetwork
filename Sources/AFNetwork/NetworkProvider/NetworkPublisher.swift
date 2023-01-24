
import Foundation
import Combine

extension NetworkProvider {
    public func requestPublisher<T: Decodable>(type: T.Type, endpoint: Endpoint) -> AnyPublisher<T, NetworkError> {
        return Future { promise in
            self.request(type: type, endpoint: endpoint, completion: promise)
        }.eraseToAnyPublisher()
    }
}
