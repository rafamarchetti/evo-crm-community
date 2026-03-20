---
title: 'Epic 2: Automated Releases & Quality Gates'
status: 'ready-for-dev'
epic: 2
stories: [2.1, 2.2, 2.3, 2.4]
frs_covered: [FR6, FR7, FR8, FR9, FR10, FR11]
nfrs_addressed: [NFR7]
files_to_create:
  - '.github/workflows/ci.yml'
  - '.github/workflows/release.yml'
  - '.github/workflows/security.yml'
  - '.github/dependabot.yml'
---

# Epic 2: Automated Releases & Quality Gates

**Goal:** A maintainer can push a git tag and have 5 Docker images automatically built and published to ghcr.io. PRs are validated, and security vulnerabilities are detected weekly.

**Critical Constraint:** ZERO modifications inside submodule repositories. All files created at monorepo root only.

---

## Context for Development

### Docker Registry

- **Registry:** `ghcr.io/evolutionapi` — free for public repos
- **Auth:** `GITHUB_TOKEN` has built-in `write:packages` permission for ghcr.io
- **Image names:** `evo-auth-service-community`, `evo-ai-crm-community`, `evo-ai-frontend-community`, `evo-ai-processor-community`, `evo-ai-core-service-community`

### Service Dockerfile Paths

| Service | Context | Dockerfile Path |
|---------|---------|----------------|
| Auth | `evo-auth-service-community` | `Dockerfile` |
| CRM | `evo-ai-crm-community` | `docker/Dockerfile` |
| Frontend | `evo-ai-frontend-community` | `Dockerfile` |
| Processor | `evo-ai-processor-community` | `Dockerfile` |
| Core | `evo-ai-core-service-community` | `Dockerfile` |

### Key Technical Notes

- **Submodule checkout:** `actions/checkout@v4` must use `submodules: recursive`
- **Docker Buildx:** Required for multi-platform builds in release workflow
- **Auth Dockerfile:** Has `RAILS_ENV=development` hardcoded — release workflow should override with build args for production
- **Frontend build args:** VITE_* URLs should use production-ready placeholder URLs (overridable at runtime)
- **CRM Dockerfile .git dependency:** Runs `git rev-parse HEAD > .git_sha`. In docker-compose build context the submodule directory is the build context and contains `.git`. If it fails, add a `GIT_SHA` build arg.

### Dependencies

- **GitHub Actions:** Free for public repos (2,000 minutes/month)
- **Trivy:** Open source, used via `aquasecurity/trivy-action`
- **Dependabot:** Built into GitHub, zero config beyond yaml file

---

## Stories

### Story 2.1: CI Validation Workflow

As a **project maintainer**,
I want pull requests against main to be automatically validated,
So that broken docker-compose configurations and Dockerfile issues are caught before merging.

**File:** `.github/workflows/ci.yml`

**Implementation Notes:**
- Keep simple — actual service tests run in submodule repos
- Use `ubuntu-latest` runner
- Don't run full build/test of services here

**Acceptance Criteria:**

**Given** a pull request is opened against the `main` branch
**When** the CI workflow triggers
**Then** the workflow runs on `ubuntu-latest`
**And** the repository is checked out with `submodules: recursive`
**And** `docker compose config` is executed to validate the compose file
**And** hadolint runs against each submodule Dockerfile to lint for best practices
**And** the workflow does NOT build or test individual services (that belongs in each submodule's own CI)

---

### Story 2.2: Tag-Based Release Workflow

As a **project maintainer**,
I want to push a git tag `v*.*.*` and have all 5 service images automatically built and published,
So that I can release new versions with a single command without manual Docker builds.

**File:** `.github/workflows/release.yml`

**Implementation Notes:**
- Use `docker/build-push-action`
- Matrix strategy to avoid duplication across 5 services
- Each service has its Dockerfile in a different relative path

**Acceptance Criteria:**

**Given** a tag matching `v*.*.*` is pushed (e.g., `v1.0.0`)
**When** the release workflow triggers
**Then** the repository is checked out with `submodules: recursive`
**And** Docker Buildx is set up for the build
**And** the workflow authenticates to ghcr.io using `GITHUB_TOKEN`
**And** the version is extracted from the tag (stripping the `v` prefix)
**And** a matrix strategy builds all 5 services: `evo-auth-service-community`, `evo-ai-crm-community`, `evo-ai-frontend-community`, `evo-ai-processor-community`, `evo-ai-core-service-community`
**And** each image is pushed with both `ghcr.io/evolutionapi/{service-name}:{version}` AND `ghcr.io/evolutionapi/{service-name}:latest` tags (FR8)
**And** each service uses its correct Dockerfile path (CRM: `docker/Dockerfile`, others: `Dockerfile`) and build context
**And** the frontend build args use production-ready placeholder URLs (overridable)
**And** the Auth build overrides `RAILS_ENV=production`
**And** a GitHub Release is created with auto-generated release notes (FR9)

---

### Story 2.3: Security Scanning Workflow

As a **project maintainer**,
I want Dockerfiles to be automatically scanned for security vulnerabilities,
So that HIGH and CRITICAL issues are surfaced in the GitHub Security tab before they reach production.

**File:** `.github/workflows/security.yml`

**Implementation Notes:**
- Schedule with cron `0 6 * * 1` (Monday 6 AM UTC)
- Needs submodule checkout

**Acceptance Criteria:**

**Given** a push to `main` OR the weekly schedule triggers (Monday 6AM UTC, cron `0 6 * * 1`)
**When** the security workflow runs
**Then** the repository is checked out with `submodules: recursive`
**And** Trivy (via `aquasecurity/trivy-action`) scans each service's Dockerfile
**And** only HIGH and CRITICAL vulnerabilities are reported
**And** results are uploaded in SARIF format to the GitHub Security tab
**And** the workflow runs on `ubuntu-latest`

---

### Story 2.4: Dependabot Configuration

As a **project maintainer**,
I want automated dependency update monitoring for root-level dependencies,
So that GitHub Actions versions and Docker base images stay up to date without manual tracking.

**File:** `.github/dependabot.yml`

**Implementation Notes:**
- Keep minimal — only what applies to root repo files
- Individual submodule dependency updates (bundler, pip, gomod, npm) should be configured in their own repos

**Acceptance Criteria:**

**Given** the `.github/dependabot.yml` file exists in the repository
**When** Dependabot runs on its weekly schedule
**Then** it monitors `github-actions` dependencies in directory `/` weekly
**And** it monitors `docker` dependencies in directory `/` weekly
**And** it does NOT monitor submodule-level dependencies (bundler, pip, gomod, npm — those belong in each submodule's repo)

---

## Review Follow-ups (AI)

_Code review performed on 2026-03-19_

### 🔴 HIGH

- [x] [AI-Review][HIGH] **Story 2.3 AC**: Changed `scan-type: fs` → `scan-type: config` to scan Dockerfiles for misconfigurations.

### 🟡 MEDIUM — Resolved

- [x] [AI-Review][MEDIUM] **Story 2.2 bug**: Release notes now use `needs.build-and-push.outputs.version` (without `v` prefix) matching image tags.
- [x] [AI-Review][MEDIUM] **Story 2.1 AC**: hadolint `failure-threshold` changed from `error` → `warning` to catch best-practice violations.
- [x] [AI-Review][MEDIUM] `security.yml` `.env` — Not needed for `config` scan type. No change required.

### 🟢 LOW — Resolved / Dismissed

- [x] [AI-Review][LOW] Trivy action version pinning — Added `v` prefix (`@v0.28.0`) for consistency.
- [x] [AI-Review][LOW] `generate_release_notes` + `body` — Kept both: body is prepended (Docker pull commands), auto-notes appended (changelog). Intentional.
