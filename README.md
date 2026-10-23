# Puff-er 🎥 💾

Ein ressourcenschonender, temporärer Video-Puffer für Flutter Android mit integriertem In-App-Browser, automatischem 5-Stunden-Lebenszyklus (TTL) und nativer Android-Share-Integration.

---

## 🌟 Kernfunktionen

1. **In-App Browser mit Video-Erkennung & Direkt-Checkbox:**
   - Integrierter Browser zum Surfen auf beliebigen Webseiten.
   - Ein injiziertes JavaScript scannt Video-Tags (`<video>`, `<source>`, `currentSrc`, dynamische DOM-Änderungen).
   - Auf jedem gefundenen Video wird eine dezente Checkbox eingeblendet: **`[☑ Offline-Puffer (5h)]`**.
   - Zusätzlich erscheint am unteren Bildschirmrand ein Informations-Banner mit allen erfassten Videos der aktuellen Seite.
   - Ein Klick auf die Checkbox lädt das Video im Hintergrund in den temporären Cache.

2. **5-Stunden-Puffer (Automatische Speicherbereinigung):**
   - Jedes heruntergeladene Video wird für exakt **5 Stunden** offline vorgehalten.
   - Nach Ablauf von 5 Stunden wird die physikalische Datei automatisch von der Festplatte gelöscht, um Speicherplatz und Systemressourcen zu schonen.
   - Kein manuelles Aufräumen nötig.

3. **Verlauf sortiert nach Mutter-Seite:**
   - Auch wenn die Videodatei nach 5 Stunden gelöscht wird, **bleibt der Link im Verlauf dauerhaft erhalten**.
   - Der Verlauf ist übersichtlich nach der jeweiligen **Mutter-Seite** (z. B. `spiegel.de`, `vimeo.com`, `reddit.com`) gruppiert.
   - Jede Mutter-Seite kann ein- und ausgeklappt werden.
   - Mit dem Button **`Erneut reinladen`** kann ein abgelaufenes Video jederzeit mit einem Klick erneut für 5 Stunden heruntergeladen werden.
   - Die Mutter-Seite kann direkt wieder im Browser geöffnet werden.

4. **Android-Share-Target (Aus normalen Browsern teilen):**
   - Wenn du in **Google Chrome**, **Firefox** oder einem anderen Browser ein Video anschaust und auf **Teilen** klickst, wähle einfach **Puff-er** aus.
   - Die App öffnet automatisch den geteilten Link im internen Browser und bereitet das Video zum Puffern vor.

5. **Integrierter Offline-Videoplayer:**
   - Gepufferte Videos können direkt in der App komplett ohne Internetverbindung angeschaut werden.
   - Gibt nach dem Schließen sämtliche Decoder-Ressourcen und Speicher sofort wieder frei.

6. **Ressourcensparend & akkuspezifisch optimiert:**
   - Dunkles AMOLED/OLED-Design für minimalen Akkuverbrauch.
   - Geringe CPU-Last durch passive Überwachung ohne ressourcenfressende Hintergrunddienste.
   - Streaming-Downloads mit Cancel-Unterstützung bei Abbruch.

---

## 📁 Projektstruktur

```
Puff-er/
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml       # Enthält ACTION_SEND Share-Filter & Internet-Rechte
│   │   │   └── kotlin/.../MainActivity.kt # Nativer Android Intent-Empfänger für geteilte URLs
│   │   └── build.gradle
│   ├── build.gradle
│   └── settings.gradle
├── lib/
│   ├── main.dart                          # App-Einstiegspunkt mit AMOLED-Dark-Theme
│   ├── models/
│   │   └── video_item.dart                # Datenmodell (TTL, Pfade, Status, Mutter-Seite)
│   ├── services/
│   │   ├── buffer_service.dart            # Download, 5h-Bereinigung, SharedPreferences
│   │   └── share_service.dart             # Nativer MethodChannel für geteilte URLs
│   └── screens/
│       ├── main_navigation_screen.dart    # 3-Tab-Navigation & Share-Event-Handler
│       ├── browser_screen.dart            # In-App WebView + JS-Video-Checkbox-Overlay
│       ├── puffer_screen.dart             # 5h Offline-Puffer mit Live-Countdown
│       ├── history_screen.dart            # Verlauf gruppiert nach Mutter-Seiten
│       └── video_player_screen.dart       # Ressourcenschonender Offline-Player
├── changelog.js                           # Versionshistorie
└── pubspec.yaml                           # Flutter-Konfiguration & Abhängigkeiten
```

---

## 🚀 Bauen & Starten

### Voraussetzungen
- Flutter SDK (>= 3.0.0)
- Android SDK (API 21+) / Android Studio

### Befehle im Terminal:
```bash
# Abhängigkeiten installieren
flutter pub get

# Auf einem verbundenen Android-Gerät ausführen
flutter run

# APK für Android erstellen
flutter build apk --release
```
Die erstellte APK-Datei liegt anschließend in:
`build/app/outputs/flutter-apk/app-release.apk`
