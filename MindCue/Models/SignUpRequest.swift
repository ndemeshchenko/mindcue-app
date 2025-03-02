import Foundation

struct SignUpRequest: Encodable {
    let username: String
    let email: String
    let password: String
} 