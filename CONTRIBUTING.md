# Contributing

SystemDeck targets macOS 14 or newer and uses Swift 6.

```bash
./build.sh
./test.sh
./validate.sh
```

Keep telemetry collection outside SwiftUI views, keep process monitoring read-only, and add tests when changing metric math or status logic.

For UI changes, include a screenshot and keep user-facing copy concise.

Do not commit `.build/`, `dist/`, validation output, credentials, or signing material.
