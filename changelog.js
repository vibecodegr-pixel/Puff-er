// Version v0.1.012
// - Automatische Smartphone-Benachrichtigung via Gmail: CI/CD-Pipeline und Build-Prozess benachrichtigen das Google-Konto (guido.reffke@googlemail.com) bei Fertigstellung per E-Mail
// - Google Drive Statusdatei (Puff-er_v0.1.011_FERTIG.txt) direkt in 'Meine Ablage' für sofortige Drive-Synchronisation angelegt

// Version v0.1.011
// - Pornhub- & Tube-Streaming Deep-Extractor: scannt automatisch mediaDefinitions, flashvars und script-Tags nach echten Master-Streams (1080p, 720p, 480p) und markiert sie als Hauptvideo
// - Spul-Segment-Spamfilter (Anti-Seek-Duplication): filtert interne 2-Sekunden-Transport-Chunks (seg-, frag-, .ts, .m4s, start=, range=) strikt heraus, sodass beim Hin- und Herspulen im Web-Player null Dummy-Einträge entstehen
// - URL-Normalisierung: fasst Spul- und Zeitoffset-Parameter zusammen, damit dieselbe Video-Quelle immer als ein konsistenter Eintrag erkannt wird
// - Native HLS (.m3u8) Download-Engine im BufferService: lädt Playlists, lädt alle Segmente sequentiell herunter und setzt sie zu einer vollständigen, offline abspielbaren Video-Datei zusammen
// - Automatische Browser-Cookie-Synchronisation: leitet Web-Cookies an den Download-Service weiter, um 403-Forbidden-Fehler von geschützten Streaming-CDNs zu verhindern
// - Qualität- und Master-Priorisierung: platziert hochauflösende Master-Videos (1080p/720p) und die größte Datei automatisch an erster Stelle mit markanter '🏆 Hauptvideo'-Badge

// Version v0.1.010
// - Interaktive Zeitleiste im Video-Player: Flüssiges Spulen vor und zurück per Finger-Drag (Scrubbing) mit Slider-Thumb & Live-Zeitstempel
// - 10-Sekunden-Vor- und Zurückspultasten (Replay 10 / Forward 10) in der Player-Steuerung integriert
// - Automatische Video-Größenanalyse im Browser: ermittelt exakte Dateigröße (KB/MB) aller erkannten Videos via HTTP-HEAD/Range-Probe ohne Datenverbrauch
// - Erkannte Videos nach Dateigröße absteigend sortiert (größtes Hauptvideo steht immer ganz oben und ist grün markiert)
// - Echter Download-Fortschrittsbalken mit Live-Telemetrie: zeigt exakte MB (z.B. 24.1 MB / 53.6 MB), Prozentanzeige, Download-Speed und Restzeit (ETA)
// - "Aktive Downloads"-Übersicht im Offline-Puffer und schwebenden Browser-Banner mit Live-Balkenanzeige und Abbruch-Option

// Version v0.1.009
// - Integrierter Video-AdBlocker: blockiert Pre-Roll Werbenetzwerke (Google IMA, DoubleClick, VMAP) direkt in shouldInterceptRequest
// - Automatische Teaser- und Vorschau-Erkennung: unterscheidet Hauptvideos von kurzen Hover-/Vorschau-Loops
// - '⚡ In Puffer'-Schnellbutton direkt auf Video-Karten und Thumbnails im Feed implementiert (ohne Video öffnen zu müssen)
// - Werbefilter-Schutz im BufferService: weist Werbe-URLs strikt ab

// Version v0.1.008
// - Video-Download mit Referer und Origin der Mutter-Seite ausgestattet (verhindert 403-Fehler und HTML-Blockaden)
// - Dateivalidierung im BufferService: erkennt und verwirft fehlerhafte HTML-Seiten vor dem Puffern
// - Video-Player mit Netzwerk-Fallback und verständlicher Fehlerdiagnose ausgestattet ('Source error' behoben)
// - Media-Stream-Netzwerkinterception (shouldInterceptRequest) und relative URL-Auflösung in JS aktiviert

// Version v0.1.007
// - In-App Browser Ladehemmung behoben: domStorageEnabled & databaseEnabled für localStorage/IndexedDB aktiviert
// - Mobile Chrome 128 User-Agent gesetzt gegen WebView-/Bot-Blockaden
// - Vor- und Zurück-Navigationsbuttons in der Browser-Toolbar integriert
// - Android System-Zurück-Taste abgefangen (PopScope): navigiert im Web-Verlauf, wechselt Tabs und schützt vor App-Absturz/Beenden

// Version v0.1.006
// - Fertig kompilierte Release-APK (Puff-er.apk, 23,5 MB) heruntergeladen und in G:\Meine Ablage\apk\Puff-er\Puff-er.apk abgelegt

// Version v0.1.005
// - GitHub Release-Veröffentlichung im CI-Workflow integriert für direkte APK-Bereitstellung
// - APK-Artefakt umbenannt in Puff-er.apk

// Version v0.1.004
// - Fehlendes App-Icon (ic_launcher.xml) in res/drawable hinzugefügt (AAPT2 Resource Linking behoben)
// - AndroidManifest auf @drawable/ic_launcher umgestellt
// - CI-Workflow bereinigt (Verbose-Flag entfernt für saubere, kompakte Fehlerausgabe)

// Version v0.1.003
// - Gradle-Plugin-Deklaration in settings.gradle korrigiert (dev.flutter.flutter-gradle-plugin hinzugefügt)
// - Android app/build.gradle optimiert (Kotlin-Plugin synchronisiert, redundante NDK-Bindung entfernt)
// - CI-Workflow auf verbose-Logging erweitert für transparente Build-Diagnose

// Version v0.1.002
// - Zielverzeichnis G:\Meine Ablage\apk\Puff-er eingerichtet
// - Automatisches Build- und Kopier-Skript build_apk.bat für den APK-Export bereitgestellt
// - GitHub Actions CI/CD-Workflow (.github/workflows/build-apk.yml) für automatische APK-Erstellung in der Cloud konfiguriert

// Version v0.1.001
// - In-App Browser mit automatischer Video-Erkennung und In-Video Checkbox-Overlay implementiert
// - 5-Stunden Offline-Puffer mit automatischer Dateibereinigung nach Ablauf der TTL hinzugefügt
// - Dauerhafter Verlauf sortiert nach Mutter-Seiten (Host/Domain) mit 'Erneut reinladen'-Funktion integriert
// - Android Share-Target für geteilte Links aus externen Browsern (Chrome, Firefox etc.) eingerichtet
// - Integrierter Offline-Videoplayer für lokale Wiedergabe ohne Internetverbindung bereitgestellt

// Version v0.1.000
// - Initial setup of the project.
