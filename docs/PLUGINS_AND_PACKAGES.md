# Plugins & Packages Research

Research pass for tooling to support this project's ongoing work: the Apple
HIG-inspired UI component library, biometric registration flows, and general
Flutter/Dart development. Two tracks: Claude Code plugins (agent-side
workflow tooling) and Flutter/Dart packages (runtime/dev dependencies for the
app itself).

## Claude Code plugins

Evaluated against the Anthropic `knowledge-work-plugins` marketplace and
several partner marketplaces (Qt, Unity, Wix, Miro, Qodo, Twilio, Auth0,
Zoom, Tavily, Qdrant, Browser Use). Most partner plugins target a specific
platform or SaaS this project doesn't use (Qt/QML, Unity, Wix, Zoom, Twilio,
vector DBs). The two that generalize well to any software project and are
directly relevant to this repo's current work:

| Plugin | Why it fits | Key skills |
|---|---|---|
| **`engineering`** (Anthropic) | Code review, architecture decisions, testing strategy, debugging, docs, tech-debt triage — generic to any codebase, no vendor lock-in. | `code-review`, `architecture`, `testing-strategy`, `debug`, `documentation`, `tech-debt`, `deploy-checklist` |
| **`design`** (Anthropic) | Design critique, design-system management, accessibility (WCAG) audits, UX copy, dev handoff — matches the active work on `lib/core/theme/apple_theme.dart` and the Apple HIG component library. | `design-critique`, `design-system`, `accessibility-review`, `ux-copy`, `design-handoff`, `research-synthesis` |

Both are first-party (Anthropic-authored), actively maintained (updated
2026-09-16), and don't require third-party API keys to get value from —
their MCP integrations (Figma, GitHub, Linear, etc.) are optional add-ons,
not requirements.

**Not selected:** `qt-development-skills` (C++/QML, not Dart/Flutter),
`unity` (game engine), `qodo` (third-party code review, overlaps with
`engineering:code-review` and needs its own account), `miro`/`wix`/`zoom`/
`twilio`/`auth0`/`tavily`/`qdrant` (tied to services not used in this repo).

Install these two via the suggestion cards below (Claude Code plugin
installs are a one-click user action, not something this agent can do
directly).

## Flutter/Dart packages

Current stack: `flutter_riverpod` (state), `go_router` (nav), `hive_ce` +
`build_runner` (storage/codegen), `camera`/`tflite_flutter`/`image`
(biometric capture + ML), `permission_handler`, `image_picker`,
`shared_preferences`, `lottie`, `share_plus`. Picks below fill gaps without
duplicating what's already there, and stay in a currently-maintained,
high-adoption tier of pub.dev.

### UI/UX polish

| Package | Purpose |
|---|---|
| `flutter_animate` | Declarative micro-interactions/transitions — fits the HIG-style polish already underway in `apple_theme.dart` / `core/widgets`. |
| `shimmer` | Loading-skeleton placeholders for `students_screen.dart`, `sessions_screen.dart`, `insights_screen.dart` while Hive/camera data loads. |
| `flutter_svg` | Scalable vector icons/illustrations for the design system, instead of rasterized PNGs. |

### Dev productivity / architecture

`build_runner` is already a dev dependency (used for Hive codegen), so
adding more codegen-based packages has no new tooling cost.

| Package | Purpose |
|---|---|
| `freezed_annotation` + `freezed` (dev) + `json_annotation` + `json_serializable` (dev) | Immutable, `==`/`copyWith`-safe data classes for models like `session_entry.dart` / `flavor_profile.dart` that aren't Hive-backed. |
| `mocktail` (dev) | Mocking for `flutter_test`, needed to unit-test providers/services (camera, face processor, cleanup) without hitting real platform channels. |

### Considered and skipped

- `riverpod_annotation` + `riverpod_generator` + `riverpod_lint` + `custom_lint`
  — tried first, but `flutter pub add` reported a genuine, unresolvable
  version conflict: this project's pinned `hive_ce_generator: ^1.6.0` (and
  the `flutter_riverpod: ^2.5.1` major it implies) forces old `analyzer`/
  `riverpod_annotation` versions, while `riverpod_generator`/`riverpod_lint`/
  `custom_lint`'s newer releases require incompatible `analyzer` majors.
  Resolving it would mean bumping `hive_ce_generator` and `flutter_riverpod`
  to new majors — a real migration (regenerating `.g.dart` files, checking
  the Riverpod 3.x API) that deserves its own deliberate pass, not a
  side effect of a plugin sweep. Skipped for now.
- `very_good_analysis` — would replace `flutter_lints` with a much stricter
  rule set; a lint-policy change like that should be a deliberate, separate
  decision, not bundled into a plugin sweep.
- `flutter_hooks` — overlaps with Riverpod's own provider lifecycle; mixing
  both patterns would fragment state-management style.
- `cached_network_image` — this app is an offline kiosk; no network image
  loading path exists to justify it.
- `device_preview` — useful but adds a runtime dependency for a dev-only
  concern; can be added later if multi-device QA becomes a real bottleneck.

## Outcome

Installed via `flutter pub add` (verified with `flutter pub get`, resolves
cleanly): `flutter_animate`, `shimmer`, `flutter_svg`, `freezed_annotation`,
`json_annotation`, `freezed` (dev), `json_serializable` (dev), `mocktail`
(dev).

Suggested via Claude Code plugin cards (user-installed, one click each):
`engineering`, `design`.
