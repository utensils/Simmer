# Workflows Overview

## Release Workflow Secrets
The notarized release pipeline in `.github/workflows/release.yml` depends on the following GitHub secrets:

- `APPLE_CERTIFICATE_P12`: Base64-encoded developer ID certificate.
- `APPLE_CERTIFICATE_PASSWORD`: Password for the certificate.
- `APPLE_TEAM_ID`: Apple developer team identifier.
- `APPLE_API_KEY_ID`: Key ID for the App Store Connect API key.
- `APPLE_API_ISSUER`: Issuer ID for the App Store Connect API key.
- `APPLE_API_KEY_CONTENT`: Base64-encoded `.p8` key contents.

Set these values under **Settings → Secrets and variables → Actions** before triggering the release workflow. Ensure the certificate and API key have notarization permissions and that the key content omits header/footer whitespace.
