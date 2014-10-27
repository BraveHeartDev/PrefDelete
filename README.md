PrefDelete
==========
This is the source code of PrefDelete v1.1.1. It has been posted in order to help people learn from it. Please do not steal this code and call it your own.

What's New In Version 1.1.1?
==========
- Added French Localization
- Added Arabic Localization
- Added Support For PreferencesTag
- Renamed the dylib and it's corresponding plist from PrefDelete.* to ZZZPrefDelete.* to get it to load in the settings app the last so that all the other tweaks are loaded and support for them would work easily.

What's New In Version 1.1.0?
==========
- Added Support For PreferencesOrganizer2
- Added Support For PreferencesOrganizer7
- Added postinst script to fix file permissions upon installation

Credits:
==========
- Brave Heart - for code development, english localization, and support additions (support to PreferencesOrganizer2, PreferencesOrganizer7, and PreferencesTag)
- ryanb93 - for his cydelete7 code from which I obtained the setuid code and the dpkg uninstallation code. ( https://github.com/ryanb93/CyDelete7 )
- Benoit Cornier for French Localization
