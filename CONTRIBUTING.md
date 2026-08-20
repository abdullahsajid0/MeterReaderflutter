# Contributing to WattWise

Thank you for your interest in contributing to **WattWise**! We welcome contributions from developers, designers, and electricity consumers helping improve bill tracking, tariff calculations, and OCR accuracy.

---

## Code of Conduct

This project adheres to the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you agree to maintain a respectful, welcoming, and inclusive community.

---

## How Can I Contribute?

- **Report Bugs**: If you find an issue, submit a detailed report using the [Bug Report Template](https://github.com/abdullahsajid0/MeterReaderflutter/issues/new?template=bug_report.yml).
- **Suggest Features**: Have an idea for improved tariff estimation, solar tracking, or charts? Use the [Feature Request Template](https://github.com/abdullahsajid0/MeterReaderflutter/issues/new?template=feature_request.yml).
- **Report DISCO Portal Changes**: If a power company (LESCO, IESCO, MEPCO, etc.) changes its online bill layout, submit a [DISCO Update Issue](https://github.com/abdullahsajid0/MeterReaderflutter/issues/new?template=disco_request.yml).
- **Submit Pull Requests**: Implement bug fixes, performance improvements, or new features.

---

## Development Setup

### 1. Prerequisites
- **Flutter SDK**: `^3.22.0` (or latest stable)
- **Dart SDK**: `^3.4.0`
- **Android Studio** / **VS Code** with Flutter & Dart extensions
- **Java JDK**: 17

### 2. Fork and Clone
1. Fork the repository on GitHub.
2. Clone your fork locally:
```bash
git clone https://github.com/abdullahsajid0/MeterReaderflutter.git
cd MeterReaderflutter
```

### 3. Install Dependencies
```bash
flutter pub get
```

### 4. Run the Project
```bash
flutter run
```

---

## Pull Request Guidelines

1. **Branch Naming**:
   - `fix/issue-description` (for bug fixes)
   - `feat/feature-name` (for new features)
   - `refactor/component-name` (for code refactoring)
2. **Code Formatting**:
   Ensure all Dart code conforms to the standard formatter:
   ```bash
   dart format .
   ```
3. **Static Analysis & Linting**:
   Ensure no warnings or errors are reported:
   ```bash
   flutter analyze
   ```
4. **Run Tests**:
   Ensure existing unit and widget tests pass:
   ```bash
   flutter test
   ```
5. **PR Description**: Fill out all fields in the Pull Request template provided when opening a PR.

---

## Security & Privacy Note
- Never commit reference numbers, personal bills, or personal API keys in sample tests or documentation.
- On-device OCR processing happens locally using Google ML Kit and does not send camera feed or captured images to remote servers.
