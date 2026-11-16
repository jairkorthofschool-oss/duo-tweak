# Duo Tweak

Tweak voor Sileo (Dopamine, rootless, iPhone 6s / iOS 15.8.x):

- Houd je iPhone **recht** → gewoon normaal beeld.
- **Draai** je scherm → duo-effect: het beeld vervaagt (blur), blijft rechtop staan en zweeft als afgerond schermpje.
- **Instellingen** (Instellingen app → Duo Tweak): effect aan/uit, alle apps of alleen homescreen, zwevend (krimpen) aan/uit.

## Repo in Sileo toevoegen

1. Sileo → tab **Pakketten** → **Bewerken** → **+**
2. URL: `https://jairkorthofschool-oss.github.io/duo-tweak/`
3. Zoek **Duo Tweak** en installeer.

De GitHub Action (`.github/workflows/build.yml`) compileert de tweak met Theos en publiceert automatisch de APT-repo naar GitHub Pages bij elke push naar `main`.

## Bouwen

```bash
cd duo
make package FINALPACKAGE=1
```

## Aanpassen

- Tweak-code: `duo/Tweak.x`
- Instellingen-paneel: `duo/DuoTweakPrefs/Resources/DuoTweakPrefsListController.plist`
- Versie verhogen: `duo/control` → dan pushed → nieuwe .deb verschijnt automatisch in de repo.
