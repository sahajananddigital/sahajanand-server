# Contributing to Sahajanand Server Infrastructure

First off, thank you for considering contributing to Sahajanand Server! It's people like you that make it a great utility for the community.

Please take a moment to review this document to ensure a smooth contribution workflow.

---

## Code of Conduct

This project is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How Can I Contribute?

### 1. Reporting Bugs
* Check the existing issues list to ensure the bug hasn't already been reported.
* Open a new issue with a clear, descriptive title.
* Include a minimal reproducible example, your OS version, Docker/Docker Compose version, and any relevant logs.

### 2. Suggesting Enhancements
* Open an issue explaining the feature, why it is needed, and how it should work.
* Discuss design suggestions with the maintainers before writing code.

### 3. Submitting Pull Requests (PRs)
* Fork the repository and create your branch from `main`.
* If you've added code that should be tested, add unit/integration tests or detail how you manually verified the change.
* Ensure all shell scripts have executive permissions configured in Git (`git update-index --chmod=+x script.sh`).
* Keep commits clean, logical, and write descriptive commit messages.

---

## Local Development Setup

To test changes locally, follow these steps:

1. **Clone the fork**:
   ```bash
   git clone https://github.com/your-username/sahajanand-server.git
   cd sahajanand-server
   ```

2. **Run the Setup Wizard in Development Mode**:
   Execute the installer script:
   ```bash
   bash setup.sh
   ```
   * Select **Option 2 (Local Development)**.
   * This configures HTTP-only routing, exposes the Traefik dashboard on port `8080`, and enables passwordless login for administrative databases locally.

3. **Check the Web UI**:
   The Web UI runs locally on `http://webui.localhost`. Credentials will be written to `credentials.txt` in the root folder.

---

## Development Guidelines

### Web UI (PHP + SQLite)
* **No MySQL Dependency**: The Web UI uses a local SQLite database (`webui/data/webui.db`) for role-based authentication and user portal records. Do not add MySQL dependencies to Web UI files.
* **Role-Based Access Control (RBAC)**:
  * Ensure all client-facing pages and actions call the tenancy filter helpers: `is_admin()`, `get_user_client()`, `require_auth()`, and `require_admin()`.
  * Client users must only be allowed to see and control containers associated with their `client_name` attribute.
  * System actions, system statistics, backup deletions, and user creation are reserved strictly for administrators.
* **Aesthetic Standard**:
  * The Web UI utilizes a premium glassmorphic dark theme (styled using HSL colors, Outfit font, and translucent cards).
  * Maintain styling consistency when creating new components or layout overrides.

### Shell Scripts & Infrastructure
* Ensure all scripts verify if the user is `root` and fail early if root execution is dangerous (like in `setup.sh`).
* Keep volume configurations secure: bind mounts inside read-only containers (`:ro`) must only mount writable subfolders (`:rw`) when strictly necessary (e.g. SQLite database folders).

---

Thank you for your contributions!
