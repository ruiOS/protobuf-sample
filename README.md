# Protobuf Sample

> **This is a sample / reference project** demonstrating a complete, production-ready Protobuf workflow using the [Buf](https://buf.build) toolchain and GitHub Actions.  
> It covers linting, breaking-change detection, BSR push, and multi-language SDK generation (Dart + Java) — everything you need to bootstrap a Buf-based Protobuf monorepo.

This is my personal repo. Feel free to clone it, swap in your own BSR org and proto packages, and use it as a starting point for your own project.
Generated SDKs are committed directly into each GitHub Release tag and browsable on GitHub — no separate download or package registry needed.

---

## What's Included

| | |
|---|---|
| ✅ `buf.yaml` | Lint + breaking-change rules (STANDARD rule set) |
| ✅ `buf.gen.yaml` | Code-generation config — Dart & Java plugins |
| ✅ `buf.lock` | Pinned dependency checksums |
| ✅ `.github/workflows/buf-ci.yaml` | CI: lint + breaking-change check on every PR / push |
| ✅ `.github/workflows/release.yml` | Release: generate Dart + Java SDKs → commit into a versioned GitHub Release tag |
| ✅ `setup.sh` | One-command local toolchain installer (Buf CLI + Flutter) |
| ✅ `download_deps.sh` | Refresh `buf.lock` + validate workspace |
| ✅ `protos/test/` | A minimal example `.proto` to confirm code-gen works end-to-end |

### Use this sample

```sh
git clone https://github.com/ruiOS/protobuf-sample.git
cd protobuf-sample
sh setup.sh          # install Buf CLI (and optionally Flutter with -f)
buf lint             # verify schemas pass lint
```

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Repository Structure](#repository-structure)
3. [Buf Account Setup (First-Time)](#buf-account-setup-first-time)
4. [Initial Local Setup](#initial-local-setup)
5. [Day-to-Day Workflow](#day-to-day-workflow)
6. [How Buf is Used](#how-buf-is-used)
7. [GitHub Actions (CI/CD)](#github-actions-cicd)
8. [Using the Generated SDKs](#using-the-generated-sdks)
   - [Dart / Flutter](#dart--flutter)
   - [Java / Backend (Spring Boot / gRPC Server)](#java--backend-spring-boot--grpc-server)
9. [How to Edit Anything](#how-to-edit-anything)
10. [Schema Conventions](#schema-conventions)
11. [Linting & Breaking-Change Rules](#linting--breaking-change-rules)
12. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                      This Repository                             │
│                                                                  │
│  protos/                  ← All .proto schema files live here    │
│  ├── test/                                                       │
│  │   └── test_user.proto                                         │
│  └── <service>/           ← Add new service packages here       │
│      └── *.proto                                                 │
│                                                                  │
│  buf.yaml                 ← Buf module + lint/breaking config    │
│  buf.gen.yaml             ← Code-gen targets (Dart + Java)      │
│  buf.lock                 ← Pinned dependency checksums          │
│  setup.sh                 ← One-time local toolchain installer   │
│  download_deps.sh         ← Sync buf.lock & validate workspace   │
└──────────────┬───────────────────────────────────────────────────┘
               │
               │  buf lint + buf breaking  (CI on every PR/push)
               │  buf push                 (CI on merge to main)
               ▼
┌─────────────────────────────────────────────────────────────────┐
│   Buf (linting, validation, code generation)                    │
│                                                                 │
│   buf lint      → style checks                                  │
│   buf breaking  → compatibility checks                          │
│   buf build     → workspace validation                          │
│   buf generate  → produce Dart + Java stubs                     │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     │  Release SDK workflow (manual trigger)
                     ▼
┌──────────────────────────────────────────────────────────────────┐
│   GitHub Release Tag                                             │
│   https://github.com/ruiOS/protobuf-sample/releases           │
│                                                                  │
│   generated/dart/  ← Dart protobuf messages + gRPC stubs        │
│   generated/java/  ← Java protobuf classes + gRPC stubs         │
│                                                                  │
│   Files are committed directly into the release tag — browsable  │
│   on GitHub and downloadable via the Source code zip asset.      │
└──────────────────────────────────────────────────────────────────┘
```

**Key design decisions:**

| Decision | Rationale |
|----------|-----------|
| Single monolithic Buf module | Simpler — no cross-module dependency overhead while the team is small |
| Generated code never on any branch | Keeps `main` and all branches clean; generated files live only in release tags |
| GitHub Release tags as distribution | Consumers clone/download at a specific tag — no registry account or tool needed |

---

## Repository Structure

```
.
├── protos/                        # All protobuf schema files
│   └── test/
│       └── test_user.proto        # Example/reference schema
│
├── .github/
│   └── workflows/
│       ├── buf-ci.yaml            # Lint + breaking-change check on PRs/pushes
│       └── release.yml            # Manual trigger — generate & commit SDK into tag
│
├── buf.yaml                       # Buf module config, lint rules, breaking rules
├── buf.gen.yaml                   # Code-generation plugin config (Dart + Java)
├── buf.lock                       # Auto-generated lockfile — do NOT edit by hand
├── setup.sh                       # Local dev setup (installs Buf CLI, Flutter, etc.)
├── download_deps.sh               # Refresh buf.lock and validate workspace
└── .gitignore
```

---

## Buf Account Setup (First-Time)

You need a **Buf account** to push schemas to the BSR and to resolve private remote plugins used during code generation.

### 1. Create a Buf account

1. Go to **[buf.build](https://buf.build)** and click **Sign up**.
2. Sign up with GitHub (recommended) or email.
3. Once signed in, you land at your personal dashboard.

### 2. Create or join a BSR organisation *(optional)*

If you want to push schemas to a BSR org, create one at [buf.build](https://buf.build) and update `buf.yaml` → `modules[0].name` with your org slug.  
You can skip this step entirely if you only use Buf for local linting and code generation.

### 3. Generate a BSR API token

1. Log in to [buf.build](https://buf.build).
2. Click your avatar (top-right) → **Settings → API Tokens**.
3. Click **Create token**, give it a name (e.g., `local-dev`), and copy it — it is shown only once.

### 4. Authenticate your local Buf CLI

```sh
buf registry login
# Prompt: Username → your buf.build username
# Prompt: Token    → paste the token from step 3
```

Credentials are stored in `~/.netrc`. You only need to do this once per machine.

### 5. Add the token as a GitHub Secret (CI use)

For the CI workflows to push to BSR you must store the token in the repository:

1. Go to **GitHub → Repository → Settings → Secrets and variables → Actions**.
2. Click **New repository secret**.
3. Name: `BUFF_TOKEN`  
   Value: paste the BSR API token.
4. Save.

> Generate a separate, dedicated token for CI — do not reuse your personal development token.

---

## Initial Local Setup

> Run **once** on every fresh machine before doing anything else.

### 1. Clone the repository

```sh
git clone https://github.com/ruiOS/protobuf-sample.git
cd protobuf
```

### 2. Install the toolchain

```sh
# Installs Homebrew (if missing) + Buf CLI
sh setup.sh

# Also installs Flutter + Dart (needed to run buf generate locally)
sh setup.sh -f
```

`setup.sh` is idempotent — safe to re-run at any time to upgrade tools.

### 3. Authenticate with BSR

```sh
buf registry login
```

See [Buf Account Setup](#buf-account-setup-first-time) → Step 4 for details.

### 4. Pull schema dependencies

```sh
sh download_deps.sh
```

This runs `buf dep update` (refreshes `buf.lock`) and `buf build` (validates the workspace compiles cleanly). If no external deps are declared yet, it prints a warning and exits — that is expected.

---

## Day-to-Day Workflow

### Make a schema change

```sh
# 1. Edit or create a .proto file under protos/
#    e.g. protos/user/user.proto

# 2. Validate locally before pushing
buf lint
buf breaking --against .git#branch=main
buf build

# 3. Open a PR → Buf CI runs automatically
# 4. Merge → CI pushes the new schema to BSR
```

### Generate SDKs locally

```sh
buf generate
# Outputs:
#   generated/dart/   ← Dart protobuf + gRPC stubs
#   generated/java/   ← Java protobuf + gRPC stubs
```

> `generated/` is git-ignored on all branches. For official versioned releases, use the GitHub Action.

---

## How Buf is Used

Buf is used purely as a **schema management and code generation tool** in this project. Generated SDKs are distributed via GitHub Release tags — not through the Buf Schema Registry SDK tab.

| Command | What it does |
|---------|-------------|
| `buf lint` | Checks all `.proto` files against the style rules in `buf.yaml` |
| `buf breaking` | Detects backward-incompatible changes relative to the `main` branch |
| `buf build` | Compiles the workspace to verify it is valid before code generation |
| `buf push` | Publishes the schema to the Buf Schema Registry (run by CI on merge to `main`) |
| `buf generate` | Runs the plugins in `buf.gen.yaml` to produce `generated/dart/` and `generated/java/` |

---

## GitHub Actions (CI/CD)

### `buf-ci.yaml` — Continuous Integration

Runs automatically. No manual steps required.

| Trigger | Actions performed |
|---------|------------------|
| Push to `main` or `release/**` | Lint → breaking-change check → push to BSR |
| PR opened / updated / reopened targeting those branches | Lint → breaking-change check (no push) |
| Branch deleted | BSR label cleanup |

**Required GitHub Secret:** `BUFF_TOKEN`

---

### `release.yml` — Release SDK  *(manual trigger)*

This workflow generates both SDKs, commits them on a detached HEAD (so no branch is touched), and publishes the commit as a versioned GitHub Release tag.

#### How to trigger

1. Go to **GitHub → Actions → Release SDK**.
2. Click **Run workflow** (top-right of the workflow list).
3. In the dropdown:
   - **Branch** — select the branch to release from (e.g., `main`).
   - **Release version tag** — enter a semver tag, e.g., `v1.2.0`.
4. Click the green **Run workflow** button.

#### What the workflow does

| Step | Description |
|------|-------------|
| Checkout | Checks out the selected branch |
| Detach HEAD | `git checkout --detach` — subsequent commits won't move any branch pointer |
| Setup Buf | Installs Buf CLI (authenticated via `BUFF_TOKEN`) |
| Generate SDKs | Runs `buf generate` → produces `generated/dart/` and `generated/java/` |
| Commit generated files | Force-adds `generated/` and commits on the detached HEAD |
| Create GitHub Release | Tags that commit, creates a GitHub Release — `generated/` is browsable in the tag |

> **Result:** `main` and all other branches stay clean. The generated files exist **only** in the release tag's file tree.

---

## Using the Generated SDKs

Generated SDKs are committed directly into each release tag at:

```
https://github.com/ruiOS/protobuf-sample/tree/<version>/generated/dart
https://github.com/ruiOS/protobuf-sample/tree/<version>/generated/java
```

Browse all releases at: **https://github.com/ruiOS/protobuf-sample/releases**

To use them as a local dependency, download the **Source code (zip)** from the release Assets, extract it, and follow the steps below.

---

### Dart / Flutter

#### 1. Download & extract the release source

```sh
# Download the Source code zip from the release Assets
# e.g. https://github.com/ruiOS/protobuf-sample/archive/refs/tags/v1.2.0.zip

unzip v1.2.0.zip -d /path/to/your/workspace/
# This extracts to: protobuf-1.2.0/generated/dart/
```

Or clone the repo at the specific tag:

```sh
git clone --branch v1.2.0 --depth 1 https://github.com/ruiOS/protobuf-sample.git
# generated/dart/ is present at this tag
```

#### 2. Add as a path dependency in `pubspec.yaml`

In your Flutter/Dart project's `pubspec.yaml`, point to the extracted `generated/dart` folder:

```yaml
dependencies:
  # ... your other dependencies

  # Protobuf — Dart generated SDK (v1.2.0)
  protobuf_sdk:
    path: ../protobuf-1.2.0/generated/dart
    # ^ adjust this relative path to match where you extracted/cloned the SDK
```

> The `path:` must point to the directory that contains the `pubspec.yaml` inside `generated/dart/`.  
> Adjust the relative path based on your project layout.

#### 3. Install dependencies

```sh
flutter pub get
```

#### 4. Import in Dart code

```dart
// Protobuf message classes
import 'package:protobuf_sdk/<your_package>/<your_file>.pb.dart';

// gRPC service clients
import 'package:protobuf_sdk/<your_package>/<your_file>.pbgrpc.dart';
```

---

### Java / Backend (Spring Boot / gRPC Server)

#### 1. Download & extract the release source

```sh
# Download the Source code zip from the release Assets
# e.g. https://github.com/ruiOS/protobuf-sample/archive/refs/tags/v1.2.0.zip

unzip v1.2.0.zip -d /path/to/your/workspace/
# Extracts to: protobuf-1.2.0/generated/java/
```

Or clone at a specific tag:

```sh
git clone --branch v1.2.0 --depth 1 https://github.com/ruiOS/protobuf-sample.git
# generated/java/ is present at this tag
```

---

#### 2a. Maven — add source directory + dependencies (`pom.xml`)

This is the recommended approach for **Spring Boot** backends.

```xml
<build>
  <plugins>
    <!-- Add generated/java as an extra source root -->
    <plugin>
      <groupId>org.codehaus.mojo</groupId>
      <artifactId>build-helper-maven-plugin</artifactId>
      <version>3.5.0</version>
      <executions>
        <execution>
          <id>add-source</id>
          <phase>generate-sources</phase>
          <goals><goal>add-source</goal></goals>
          <configuration>
            <sources>
              <!-- adjust path to where you extracted/cloned the SDK -->
              <source>../protobuf-1.2.0/generated/java</source>
            </sources>
          </configuration>
        </execution>
      </executions>
    </plugin>
  </plugins>
</build>

<dependencies>
  <!-- Protobuf runtime (required) -->
  <dependency>
    <groupId>com.google.protobuf</groupId>
    <artifactId>protobuf-java</artifactId>
    <version>3.25.3</version>
  </dependency>

  <!-- gRPC stubs (required) -->
  <dependency>
    <groupId>io.grpc</groupId>
    <artifactId>grpc-stub</artifactId>
    <version>1.63.0</version>
  </dependency>
  <dependency>
    <groupId>io.grpc</groupId>
    <artifactId>grpc-protobuf</artifactId>
    <version>1.63.0</version>
  </dependency>

  <!-- Netty transport — needed to run the gRPC server -->
  <dependency>
    <groupId>io.grpc</groupId>
    <artifactId>grpc-netty-shaded</artifactId>
    <version>1.63.0</version>
  </dependency>

  <!-- Required at compile-time for @Generated annotation on gRPC stubs -->
  <dependency>
    <groupId>javax.annotation</groupId>
    <artifactId>javax.annotation-api</artifactId>
    <version>1.3.2</version>
    <scope>provided</scope>
  </dependency>
</dependencies>
```

---

#### 2b. Gradle — add source directory + dependencies

For plain Java / Kotlin backend projects (not Android).

**`build.gradle` (Groovy DSL)**
```groovy
sourceSets {
    main {
        java {
            // Include the Protobuf generated Java files
            srcDir '../protobuf-1.2.0/generated/java'
            // ^ adjust this path to match where you extracted/cloned the SDK
        }
    }
}

dependencies {
    // Protobuf runtime (required)
    implementation 'com.google.protobuf:protobuf-java:3.25.3'
    // gRPC stubs (required)
    implementation 'io.grpc:grpc-stub:1.63.0'
    implementation 'io.grpc:grpc-protobuf:1.63.0'
    // Netty transport — needed to run the gRPC server
    implementation 'io.grpc:grpc-netty-shaded:1.63.0'
    // Required at compile-time for @Generated annotation on gRPC stubs
    compileOnly 'javax.annotation:javax.annotation-api:1.3.2'
}
```

**`build.gradle.kts` (Kotlin DSL)**
```kotlin
sourceSets {
    main {
        java {
            // Include the Protobuf generated Java files
            srcDir("../protobuf-1.2.0/generated/java")
            // ^ adjust this path to match where you extracted/cloned the SDK
        }
    }
}

dependencies {
    // Protobuf runtime (required)
    implementation("com.google.protobuf:protobuf-java:3.25.3")
    // gRPC stubs (required)
    implementation("io.grpc:grpc-stub:1.63.0")
    implementation("io.grpc:grpc-protobuf:1.63.0")
    // Netty transport — needed to run the gRPC server
    implementation("io.grpc:grpc-netty-shaded:1.63.0")
    // Required at compile-time for @Generated annotation on gRPC stubs
    compileOnly("javax.annotation:javax.annotation-api:1.3.2")
}
```

---

#### 3. Implement the gRPC server

`buf.build/grpc/java` generates an abstract base class for each service. Extend it to implement your server logic:

```java
import com.your.company.<your_package>.v1.YourServiceGrpc;
import com.your.company.<your_package>.v1.GetYourEntityRequest;
import com.your.company.<your_package>.v1.GetYourEntityResponse;
import io.grpc.stub.StreamObserver;

public class YourServiceImpl extends YourServiceGrpc.YourServiceImplBase {

    @Override
    public void getYourEntity(GetYourEntityRequest request,
                              StreamObserver<GetYourEntityResponse> responseObserver) {
        // Your business logic here
        GetYourEntityResponse response = GetYourEntityResponse.newBuilder()
            .setEntity(/* ... */)
            .build();
        responseObserver.onNext(response);
        responseObserver.onCompleted();
    }
}
```

Start the server:

```java
import io.grpc.Server;
import io.grpc.ServerBuilder;

Server server = ServerBuilder.forPort(50051)
    .addService(new YourServiceImpl())
    .build()
    .start();

server.awaitTermination();
```

#### 4. Import message/stub classes

```java
// Protobuf message classes
import com.your.company.<your_package>.v1.YourMessage;

// gRPC generated stubs (server base + client stubs)
import com.your.company.<your_package>.v1.YourServiceGrpc;
import com.your.company.<your_package>.v1.YourServiceGrpc.YourServiceBlockingStub;  // sync client
import com.your.company.<your_package>.v1.YourServiceGrpc.YourServiceStub;          // async client
import com.your.company.<your_package>.v1.YourServiceGrpc.YourServiceImplBase;      // server impl base
```

---


## How to Edit Anything

### Add a new proto package / service

1. Create a subdirectory under `protos/`:
   ```
   protos/
   └── <your-service>/
       ├── <entity>.proto
       └── <service>_service.proto
   ```
2. Use a package name matching the directory structure:
   ```protobuf
   syntax = "proto3";
   package your_org.<your_service>.v1;
   ```
3. Run `buf lint` and fix all warnings before committing.
4. Open a PR — CI will lint and check for breaking changes automatically.

---

### Change the Buf module name or BSR target

Edit [`buf.yaml`](./buf.yaml) → `modules[0].name`:

```yaml
modules:
  - path: protos
    name: buf.build/your-bsr-org/<new-name>   # ← change this
```

> ⚠️ Also create the new module on BSR first and update all consumer `buf.yaml` deps.

---

### Add an external proto dependency (e.g., `googleapis`)

Add a `deps:` block to [`buf.yaml`](./buf.yaml):

```yaml
modules:
  - path: protos
    name: buf.build/your-bsr-org/protobuf
    deps:
      - buf.build/googleapis/googleapis
```

Then refresh the lockfile:

```sh
sh download_deps.sh
```

---

### Add a new code-generation target (language)

The current [`buf.gen.yaml`](./buf.gen.yaml):

```yaml
version: v2

managed:
  enabled: true
  override:
    - file_option: java_multiple_files
      value: true   # each proto message gets its own .java file

plugins:
  # Dart (messages + gRPC stubs) → generated/dart/
  - remote: buf.build/protocolbuffers/dart
    out: generated/dart

  # Java protobuf message classes → generated/java/
  - remote: buf.build/protocolbuffers/java
    out: generated/java

  # Java gRPC service stubs → generated/java/
  - remote: buf.build/grpc/java
    out: generated/java
```

To add a new language, append a plugin block:

```yaml
  # Example: Python
  - remote: buf.build/protocolbuffers/python
    out: generated/python
```

Also update the **Commit generated files** step in [`release.yml`](./.github/workflows/release.yml) — the `git add -f generated/` command will automatically pick up any new output folder, so no change is needed there unless you want to document the new path in the release notes.

---

### Change lint rules

Edit the `lint:` section of [`buf.yaml`](./buf.yaml).  
Full rule catalogue: [buf.build/docs/lint/rules](https://buf.build/docs/lint/rules)

---

### Change breaking-change detection rules

Edit the `breaking:` section of [`buf.yaml`](./buf.yaml).  
Available rule sets: `FILE`, `PACKAGE`, `WIRE`, `WIRE_JSON`.  
Full reference: [buf.build/docs/breaking/rules](https://buf.build/docs/breaking/rules)

---

### Update the CI workflow

Edit [`.github/workflows/buf-ci.yaml`](./.github/workflows/buf-ci.yaml).

| What to change | Where |
|----------------|-------|
| Branch filters | `on.push.branches` and `on.pull_request.branches` |
| Buf action version | `bufbuild/buf-action@v1` — pin to e.g. `@1.2.0` if needed |

---

### Update the Release workflow

Edit [`.github/workflows/release.yml`](./.github/workflows/release.yml).

| What to change | Where |
|----------------|-------|
| Add a new language | Add the plugin to `buf.gen.yaml` and `git add -f` the new output folder |
| Change release notes | Edit the `--notes` block in "Create GitHub Release" |

---

### Update toolchain version defaults

Edit the top of [`setup.sh`](./setup.sh):

```sh
BUF_VERSION="latest"       # pin to e.g. "1.47.2" for reproducibility
FLUTTER_VERSION="latest"   # pin to e.g. "3.24.0"
```

---

## Schema Conventions

### Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Directory | `snake_case` | `user_profile/` |
| Proto file | `snake_case.proto` | `user_profile.proto` |
| Package | `your_org.<domain>.v1` | `your_org.user_profile.v1` |
| Message | `PascalCase` | `UserProfile` |
| Field | `snake_case` | `display_name` |
| Enum | `SCREAMING_SNAKE_CASE` | `STATUS_ACTIVE` |
| Enum zero value | Must end in `_UNSPECIFIED` | `STATUS_UNSPECIFIED = 0` |
| Service | Must end in `Service` | `UserProfileService` |
| RPC | `PascalCase` verb-noun | `GetUserProfile` |

---

### Proto file template

```protobuf
syntax = "proto3";

package your_org.<your_domain>.v1;

option java_multiple_files = true;
option java_package = "com.your.company.<your_domain>.v1";

// YourEntity represents …
message YourEntity {
  string id   = 1;
  string name = 2;
}

// Service (add only when gRPC RPCs are needed)
service YourEntityService {
  rpc GetYourEntity(GetYourEntityRequest) returns (GetYourEntityResponse);
}

message GetYourEntityRequest {
  string id = 1;
}

message GetYourEntityResponse {
  YourEntity entity = 1;
}
```

---

### Field number rules

Field numbers **must never be reused** once a schema is published — reusing a number is a breaking wire change.

- Always increment; never recycle old numbers.
- When you delete a field, reserve its number and name so they cannot be accidentally reused:

```protobuf
message User {
  reserved 3, 4;        // numbers of deleted fields
  reserved "old_name";  // names of deleted fields
  string id   = 1;
  string name = 2;
}
```

---

### Importing other protos

**Within this module (internal import):**
```protobuf
import "your_org/common/v1/pagination.proto";
```

**External dependency (e.g., `googleapis`):**

1. Add to the `deps:` block in [`buf.yaml`](./buf.yaml):
   ```yaml
   modules:
     - path: protos
       name: buf.build/your-bsr-org/protobuf
       deps:
         - buf.build/googleapis/googleapis
   ```
2. Run `sh download_deps.sh` to update `buf.lock`.
3. Then import normally:
   ```protobuf
   import "google/protobuf/timestamp.proto";
   ```

---

## Linting & Breaking-Change Rules

| Rule area | Configuration | Effect |
|-----------|--------------|--------|
| Rule set | `STANDARD` | Buf's recommended style guide |
| Enum zero value | `enum_zero_value_suffix: _UNSPECIFIED` | e.g. `STATUS_UNSPECIFIED = 0` required |
| Service naming | `service_suffix: Service` | Service must be named `UserService`, not `User` |
| Same request/response | `rpc_allow_same_request_response: false` | Prevents ambiguous RPCs |
| Empty request | `rpc_allow_google_protobuf_empty_requests: false` | Forces explicit request messages |
| Empty response | `rpc_allow_google_protobuf_empty_responses: false` | Forces explicit response messages |
| Breaking-change set | `FILE` | Detects field removals, renames, type changes, etc. |
| Breaking exception | `EXTENSION_NO_DELETE` excluded | Extension fields may be safely deleted |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `buf: command not found` | Run `sh setup.sh` to install Buf CLI |
| `permission_denied` on `buf push` | Token missing or expired — re-run `buf registry login` or update `BUFF_TOKEN` secret |
| CI fails with "breaking change detected" | Your proto change is incompatible. Either revert, use a new field number, or coordinate a major-version bump with all consumers |
| `buf generate` fails with plugin error | You need to be authenticated — run `buf registry login` first |
| `buf.lock` has merge conflicts | Run `sh download_deps.sh` to regenerate it cleanly from scratch |
| Can't access BSR module | Make sure your buf.build account is added to the `your-bsr-org` org by an admin |
| `generated/` folder not visible in tag | Check the Release SDK workflow logs — the "Commit generated files" step must succeed before the release is created |
| `dart pub get` fails with path dependency | Verify the `path:` in `pubspec.yaml` points to the `generated/dart/` folder that contains its own `pubspec.yaml` |
| Gradle can't find generated Java classes | Confirm the `srcDir` path in `sourceSets` is correct relative to your module's `build.gradle`; run `./gradlew compileJava --info` to see what sources are picked up |
