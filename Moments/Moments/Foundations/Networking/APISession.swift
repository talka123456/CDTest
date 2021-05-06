//
//  APISession.swift
//  Moments
//
//  Created by Jake Lin on 25/10/20.
//

import Foundation
import Alamofire
import RxSwift

enum APISessionError: Error {
    case networkError(error: Error, statusCode: Int)
    case invalidJSON
    case noData
}

protocol APISession {
    associatedtype ReponseType: Codable

    func post(_ path: String, headers: HTTPHeaders, parameters: Parameters?) -> Observable<ReponseType>
}

extension APISession {
    var defaultHeaders: HTTPHeaders {
        // swiftlint:disable no_hardcoded_strings
        let headers: HTTPHeaders = [
            "x-app-platform": "iOS",
            "x-app-version": UIApplication.appVersion,
            "x-os-version": UIDevice.current.systemVersion
        ]
        // swiftlint:enable no_hardcoded_strings

        return headers
    }

    var baseUrl: URL {
        return API.baseURL
    }

    func post(_ path: String, headers: HTTPHeaders = [:], parameters: Parameters? = nil) -> Observable<ReponseType> {
        return request(path, method: .post, headers: headers, parameters: parameters, encoding: JSONEncoding.default)
    }
}

private extension APISession {
    func request(_ path: String, method: HTTPMethod, headers: HTTPHeaders, parameters: Parameters?, encoding: ParameterEncoding) -> Observable<ReponseType> {
        let url = baseUrl.appendingPathComponent(path)
        let allHeaders = HTTPHeaders(defaultHeaders.dictionary.merging(headers.dictionary) { $1 })

        return Observable.create { observer -> Disposable in
            // swiftlint:disable no_hardcoded_strings
            let queue = DispatchQueue(label: "moments.app.api", qos: .background, attributes: .concurrent)
            // swiftlint:enable no_hardcoded_strings

            let request = AF.request(url, method: method, parameters: parameters, encoding: encoding, headers: allHeaders, interceptor: nil, requestModifier: nil)
                .validate()
                .responseJSON(queue: queue) { response in
                    switch response.result {
                    case .success:
                        guard let data = response.data else {
                            // if no error provided by Alamofire return .noData error instead.
                            observer.onError(response.error ?? APISessionError.noData)
                            return
                        }
                        do {
                            let model = try JSONDecoder().decode(ReponseType.self, from: data)
                            observer.onNext(model)
                            observer.onCompleted()
                        } catch {
                            observer.onError(error)
                        }
                    case .failure(let error):
                        if let statusCode = response.response?.statusCode {
                            observer.onError(APISessionError.networkError(error: error, statusCode: statusCode))
                        } else {
                            observer.onError(error)
                        }
                    }
                }

            return Disposables.create {
                request.cancel()
            }
        }
    }
}
