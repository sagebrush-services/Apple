import Foundation

struct Config {
    // Environment configuration - switch between dev and prod
    static let environment: Environment = .development

    enum Environment {
        case development
        case production

        var cognitoConfig: CognitoConfig {
            switch self {
            case .development:
                return CognitoConfig(
                    region: "us-west-2",
                    userPoolId: "us-west-2_fWEzNpuej",
                    clientId: "72evni4i91lf8kej3jspgd11os",
                    domain: "sagebrush-dev-auth",  // Domain prefix
                    redirectURI: "sagebrush://oauth/callback",
                    logoutURI: "sagebrush://logout"
                )
            case .production:
                return CognitoConfig(
                    region: "us-west-2",
                    userPoolId: "us-west-2_sQFjXf8yV",
                    clientId: "68h8fqp4aih2l1a9gc01hokklf",
                    domain: "sagebrush-prod-auth",  // Domain prefix
                    redirectURI: "sagebrush://oauth/callback",
                    logoutURI: "sagebrush://logout"
                )
            }
        }

        var apiBaseURL: String {
            switch self {
            case .development:
                return "http://localhost:8080"
            case .production:
                return "https://sagebrush.services"
            }
        }
    }

    struct CognitoConfig {
        let region: String
        let userPoolId: String
        let clientId: String
        let domain: String
        let redirectURI: String
        let logoutURI: String

        var authorizationEndpoint: String {
            "https://\(domain).auth.\(region).amazoncognito.com/oauth2/authorize"
        }

        var tokenEndpoint: String {
            "https://\(domain).auth.\(region).amazoncognito.com/oauth2/token"
        }

        var revokeEndpoint: String {
            "https://\(domain).auth.\(region).amazoncognito.com/oauth2/revoke"
        }

        var logoutEndpoint: String {
            "https://\(domain).auth.\(region).amazoncognito.com/logout"
        }

        var jwksURL: URL {
            URL(string: "https://cognito-idp.\(region).amazonaws.com/\(userPoolId)/.well-known/jwks.json")!
        }
    }
}
