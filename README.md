# PoolLab für iPhone

Eigenständige Billard-Übungs-App für iOS mit Aim Line, Prediction, Auto Aim und eigener Offline-Lizenzprüfung.

**Nicht** das Originalspiel 8 Ball Pool und keine i3rby-IPA. Das Repository enthält ausschließlich App-Quellcode und den **öffentlichen** Lizenz-Prüfschlüssel. Der private Ausstellerschlüssel darf niemals eingecheckt werden.

Der Workflow unter `.github/workflows/iphone-ipa.yml` erstellt auf macOS eine **unsignierte** IPA als Download-Artefakt. Für die Installation wird diese IPA anschließend mit Sideloadly auf Windows signiert.
