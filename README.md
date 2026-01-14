# Luxe

A monorepo for [the trifecta](./TRIFECTA.md) for Sagebrush Services.

Luxe is a play on lux, Latin for light, and luxurious, an homage to our founding city of Las Vegas, Nevada.

## Getting Started

Luxe is built by developers who are comfortable with macOS, Swift, and git.

1. Install the latest macOS and Xcode
2. Run the Bazaar with `swift run Bazaar`.

This will log you into the `Bazaar` web application as an anonymous public user.

### Authentication

In production, we use AWS Cognito which forwards HTTP headers about the user to our application. In development, you can
use [Proxyman](https://proxyman.io/) to mock login with HTTP headers.

#### Mocking a Customer

To mock the customer user, you can use the following HTTP headers:

## Claude Code Development

We encourage developing this repository using **Claude Code**. Review the commands and agents in the `.claude/`
directory.

## Targets

- **TBD Ace** macOS app for Neon Law attorneys
- **Bazaar** Our main web application and HTTP API served at <https://www.sagebrush.services>
- **Bouncer** Authentication and Authorization logic used across the services
- **TBD Concierge** macOS app for `{board,engineering,investors,support}@sagebrush.services`
- **TBD FoodCart** OpenAPI Client for the Bazaar API
- **MiseEnPlace** CLI a private GitHub repository for a `matters.project` for attorney-client work
- **TBD PaperPusher** Email logic for `{board,engineering,investors,support}@sagebrush.services`
- **Prospector** Grant research tool that uses OpenAI Deep Research to find non-repayable grants for Nevada companies
- **Roulette** Random file generator to choose for refactoring.
- **TBD Sagebrush** Apple app for Sagebrush Services customers.
- **TestUtiltiies** Test helpers for Swift Server targets.
- **TouchMenu** Common UI components shared across web targets
- **Vegas** AWS infrastructure-as-code

## Vegas Infrastructure

Vegas manages AWS infrastructure deployment for both production and development environments. The table below shows which services are deployed to each environment.

### Current Service Deployment

| Service Category | Stack Name | Production | Development | Notes |
|-----------------|------------|------------|-------------|-------|
| **Network Infrastructure** |
| VPC (Oregon) | oregon-vpc | ✅ | ❌ | Production only |
| VPC (Ohio) | ohio-vpc | ✅ | ❌ | For GitHub Actions runners |
| **Storage** |
| Public S3 Bucket | sagebrush-public-bucket | ✅ | ✅ | File upload testing |
| Private S3 Bucket | sagebrush-private-bucket | ✅ | ❌ | VPC-only access (dev uses MinIO) |
| S3 Bucket Policy | sagebrush-s3-bucket-policy | ✅ | ❌ | CloudFront access control |
| **CloudFront/CDN** |
| Legacy CloudFront | sagebrush-brochure-cloudfront | ✅ | ❌ | Production only |
| CloudFront Certificates (us-east-1) | neonlaw/hoshihoshi/tarotswift/etc | ✅ | ❌ | 6 certificates total |
| CloudFront Distributions | neonlaw/hoshihoshi/tarotswift/etc | ✅ | ❌ | 6 distributions total |
| **Database** |
| RDS PostgreSQL | oregon-rds | ✅ | ❌ | Production only (dev uses local DB) |
| Secrets Manager | oregon-secrets | ✅ | ❌ | Stores RDS credentials |
| **Authentication** |
| Cognito User Pool | sagebrush-cognito-prod | ✅ | ❌ | Production only |
| Cognito User Pool | sagebrush-cognito-dev | ❌ | ✅ | Development only |
| Admin Users | (created via setup-admin-users) | ✅ | ✅ | |
| **Application Load Balancer** |
| SSL Certificate | bazaar-certificate | ✅ | ❌ | For www.sagebrush.services |
| ALB with Auth | sagebrush-alb | ✅ | ❌ | Production only |
| ALB Listener Rules | bazaar-alb-listener-rules | ✅ | ❌ | Production only |
| **Application Services** |
| Bazaar ECS Service | bazaar-service | ✅ | ❌ | Production only (dev runs locally) |
| **IAM/System Accounts** |
| Engineering Account | engineering-system-account | ✅ | ❌ | Production only |
| GitHub CI/CD Account | sagebrush-github-system-account | ✅ | ❌ | Production only |
| **Disabled (Commented Out)** |
| Bastion Host | oregon-bastion | ❌ | ❌ | Updated via separate command |
| Email Processing | sagebrush-email-* | ❌ | ❌ | Cost optimization |

### Environment Architecture

**Production**: Full infrastructure deployment with database and application services
- VPCs and networking infrastructure
- S3 buckets (public and private with VPC-only access)
- CloudFront CDN with SSL certificates
- RDS PostgreSQL database
- Cognito authentication (prod user pool)
- Application Load Balancer with authentication
- Bazaar ECS Fargate service running on AWS
- System accounts for engineering and CI/CD

**Development**: Minimal AWS infrastructure for local workstation testing
- **Public S3 bucket** for file upload testing
- **Cognito User Pool** (dev) for testing auth flows
- **MinIO** (run locally) for private S3-compatible storage
- **Local PostgreSQL** instead of RDS
- **No VPCs** - not needed for local development
- **No Private S3** - use MinIO locally instead
- **No CloudFront** - not needed for local development
- **No ALB** - not needed for local development
- **No ECS service** - run `swift run Bazaar` locally

### Local Development Setup

For local development, you'll need:

```bash
# 1. Deploy minimal AWS infrastructure (Public S3 + Cognito)
swift run Vegas infrastructure --env development

# 2. Run MinIO for local S3-compatible storage
docker run -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=minioadmin \
  quay.io/minio/minio server /data --console-address ":9001"

# 3. Run local PostgreSQL
# (Use Docker, Postgres.app, or brew install postgresql)

# 4. Run Bazaar locally
swift run Bazaar
```

### Production Deployment

```bash
# Deploy production infrastructure (full AWS setup)
swift run Vegas infrastructure --env production

# Update production service with new image version (handled by CI/CD)
swift run Vegas deploy --service bazaar --version v1.2.3
```

## Managed Support

If you work for a law firm interested in deploying a custom version of Luxe to your own AWS account to service your
clients with AI, please contact Sagebrush Services at [support@sagebrush.services](mailto:support@sagebrush.services).

## License

Luxe is copyright of Sagebrush Services.
