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
