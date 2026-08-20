<p align="center">
  <img src="assets/images/logo.png" alt="WattWise Logo" width="120" />
</p>

<h1 align="center">WattWise</h1>

<p align="center">
  Meter scanning, billing cycle tracking, and tariff forecasting for electricity consumers in Pakistan.
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart" /></a>
  <a href="https://developers.google.com/ml-kit"><img src="https://img.shields.io/badge/ML%20Kit-Vision%20OCR-4285F4?style=flat-square&logo=google&logoColor=white" alt="ML Kit" /></a>
  <a href="#license"><img src="https://img.shields.io/badge/License-PolyForm%20Noncommercial-blue?style=flat-square" alt="License" /></a>
</p>

---

## Overview

WattWise is a Flutter application that helps households track electricity consumption, avoid slab jumps, and estimate utility bills before they arrive. It combines on-device camera OCR for physical meter readings with automated scraping of official PITC billing records across Pakistani power distribution companies (DISCOs).

---

## Core Capabilities

- **On-Device Optical Recognition**: Scans analog rolling dials and digital LCD meters using Google ML Kit Text Recognition with tailored 7-segment digit repair and decimal normalization.
- **Official Bill Synchronization**: Pulls reference numbers, billing months, consumed units, payable amounts, and meter reading dates directly from public PITC web endpoints.
- **Cycle-Aware Baseline Tracking**: Anchors consumption cycles to the actual meter reading day from previous bills and preserves logging data during the routine 4 to 5 day publication lag.
- **Tariff & Slab Estimator**: Computes projected cost based on current NEPRA residential slabs, protected tariff thresholds (100 / 200 units), fuel price adjustments, and applicable duties.
- **Consumption Pacing**: Tracks daily unit usage against user-defined monthly limits and provides target rates to stay within protected brackets.
- **Historical Analysis**: Visualizes daily deltas and monthly billing history using interactive area charts.

---

## Supported Distribution Companies (DISCOs)

WattWise parses bills for the following utilities via the PITC network:

| Company | Full Name | Operational Coverage |
|---|---|---|
| **LESCO** | Lahore Electric Supply Company | Lahore, Kasur, Okara, Sheikhupura, Nankana |
| **IESCO** | Islamabad Electric Supply Company | Islamabad, Rawalpindi, Attock, Jhelum, Chakwal |
| **GEPCO** | Gujranwala Electric Power Company | Gujranwala, Sialkot, Gujrat, Hafizabad, Narowal |
| **FESCO** | Faisalabad Electric Supply Company | Faisalabad, Sargodha, Jhang, Toba Tek Singh, Chiniot |
| **MEPCO** | Multan Electric Power Company | Multan, Sahiwal, Bahawalpur, D.G. Khan, Rahim Yar Khan |
| **PESCO** | Peshawar Electric Supply Company | Peshawar, Mardan, Swat, Abbottabad, Nowshera |
| **HESCO** | Hyderabad Electric Supply Company | Hyderabad, Jamshoro, Mirpurkhas, Nawabshah |
| **SEPCO** | Sukkur Electric Power Company | Sukkur, Larkana, Shikarpur, Jacobabad |
| **QESCO** | Quetta Electric Supply Company | Quetta and Balochistan districts |
| **TESCO** | Tribal Areas Electric Supply Company | Merged Tribal Districts (Khyber, Kurram, Bajaur, Waziristan) |

---

## Project Structure

```text
lib/
├── models/         # Domain entities (Meter, Reading, BillInfo, Alert)
├── screens/        # Dashboard, Details, Scanner, Insights, Alerts, Settings
├── services/       # OCR preprocessing, PITC client/parser, tariff calculations
├── store/          # Centralized store (ChangeNotifier) with SharedPreferences
├── theme/          # Design system, color palettes, and component styles
└── widgets/        # Cards, graphs, modals, and input dialogs
```

---

## Setup and Installation

### Requirements

- Flutter SDK `^3.19.0`
- Dart SDK `^3.3.0`
- Android Studio, VS Code, or Xcode with Flutter tooling configured
- A physical mobile device with a camera for testing OCR scans

### Running Locally

1. Clone the repository:
   ```bash
   git clone https://github.com/abdullahsajid0/MeterReaderflutter.git
   cd MeterReaderflutter
   ```

2. Fetch package dependencies:
   ```bash
   flutter pub get
   ```

3. Run the test suite:
   ```bash
   flutter test
   ```

4. Start the application:
   ```bash
   flutter run
   ```

---

## Testing

Unit tests for tariff calculations, OCR candidate scoring, and cycle boundary transitions are located in the `test/` directory.

Run tests with:
```bash
flutter test test/billing_cycle_test.dart
```

---

## License

This project is released under the **PolyForm Noncommercial License 1.0.0**.

Free for personal, academic, research, and non-commercial open-source evaluation. Commercial use, redistribution for profit, or inclusion in proprietary paid offerings is prohibited without prior written consent from the author.

Refer to the [LICENSE](LICENSE) file for complete terms.
