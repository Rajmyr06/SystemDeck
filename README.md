# SystemDeck

SystemDeck is a native macOS system monitor built with SwiftUI and AppKit. It shows CPU, memory, GPU, storage, network, battery, thermal state, process activity, and collector health in one desktop app.

## Features

- CPU telemetry from Mach host statistics
- Memory usage and composition from Mach VM counters
- GPU telemetry through IOKit when available
- Storage capacity monitoring
- Network throughput from BSD interface counters
- Battery state and macOS thermal condition
- Read-only process monitoring with normalized CPU usage
- Rolling charts with bounded history
- Menu bar monitor and compact monitor
- Collector health and freshness diagnostics
- Native full screen and fit-to-screen window controls
- Launch at Login support

## Requirements

- macOS 14 or newer
- Swift 6 toolchain
- Xcode command-line tools

Apple Silicon is recommended.

## Build

```bash
./build.sh
./run.sh
```

Run tests:

```bash
./test.sh
```

Run the local validation checks:

```bash
./validate.sh
```

## Release build

```bash
./release.sh
```

Artifacts are created in `dist/`:

```text
SystemDeck.app
SystemDeck-1.0.0-macOS.zip
SystemDeck-1.0.0-macOS.dmg
SHA256SUMS.txt
```

The release build is ad-hoc signed. If macOS blocks the first launch on another Mac, open **System Settings → Privacy & Security** and choose **Open Anyway**.

## Project layout

```text
Sources/SystemDeck/      Application source
Tests/SystemDeckTests/   Unit tests
Packaging/               App metadata and icon assets
```

## Privacy

SystemDeck runs locally. It does not require an account, include analytics, or upload system telemetry.

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
