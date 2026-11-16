# Duo Tweak — Projectinformatie

*Dit mapje bevat alle info over dit project zodat je het niet opnieuw hoeft uit te leggen.*

## Wat is het

**Duo Tweak** — een jailbreak-tweak (Sileo) voor iPhone 6s met iOS 15.8.x en **Dopamine** (rootless).

**Het effect (huidige versie):** als je de telefoon kantelt (op de X-as, bovenkant naar je toe/van je af), roteert het schermbeeld in **3D tegen** je beweging in, met perspectief, zodat het beeld "naar voren gericht blijft staan" (hologram-gevoel). Telefoon weer recht → beeld knalt terug naar normaal.

- Geen krimpen, geen blur meer (die versies bestaan in oudere .deb's in de repo)
- Sterkte instelbaar via schuifregelaar in de instellingen (0–10, standaard 5)

## Belangrijke links & feiten

| Ding | Waarde |
|---|---|
| GitHub repo | https://github.com/jairkorthofschool-oss/duo-tweak |
| Sileo repo URL | `https://jairkorthofschool-oss.github.io/duo-tweak/` |
| Package ID | `nl.jair.duotweak` |
| Prefs domein | `nl.jair.duotweak` (sleutels: `enabled`, `allapps`, `strength`) |
| Doelapparaat | iPhone 6s, iOS 15.8.x, Dopamine (rootless), ElleKit injectie |
| Build | GitHub Actions bouwt .deb met Theos bij elke push naar `main` |

## Installeren in Sileo

1. Sileo → tab **Pakketten** (Sources) → **Bewerken** → **+**
2. URL: `https://jairkorthofschool-oss.github.io/duo-tweak/`
3. Zoek **Duo Tweak** → installeren (respringt automatisch)
4. Instellingen → **Duo Tweak** → instellingen aanpassen → **SpringBoard herstarten**

## Instellingen (Instellingen app → Duo Tweak)

- **Effect ingeschakeld** (`enabled`, standaard aan)
- **Gebruiken in alle apps** (`allapps`, standaard uit = alleen homescreen/SpringBoard)
- **Sterkte** (`strength`, 0–10, standaard 5) — hoe hard het beeld tegendraait
- **SpringBoard herstarten** — knop die SpringBoard herstart zodat instellingen meteen toegepast worden
- Onderaan de pagina staat automatisch een **diagnose-blok** (handig bij problemen)

## Projectstructuur

```
duo/                      ← Theos tweak-project
  Tweak.x                 ← de tweak-code (CoreMotion + 3D window-transform)
  Makefile                ← Theos build (rootless, arm64)
  control                 ← pakketinfo (versie staat hier!)
  DuoTweak.plist          ← injectie-filter (Bundles, wordt binary in CI)
  DuoTweakPrefs/          ← instellingen-paneel (PSListController)
  Resources/              ← Info.plist + Root.plist (instellingen-spec) + diagnose
  layout/…/PreferenceLoader/…  ← instellingen-pagina registratie
.github/workflows/build.yml  ← CI: bouwt .deb + Sileo-repo en deployt naar GitHub Pages
scripts/gen-release.sh    ← maakt apt Release-bestand
web/                      ← repo startpagina + depiction pagina
project-info/             ← dit mapje
```

## Werkwijze bij aanpassingen

1. Code aanpassen (`duo/Tweak.x`, `duo/Resources/Root.plist`, `duo/control` versie **verhogen**)
2. `git commit` + `git push` → GitHub Actions bouwt automatisch (~2 min)
3. In Sileo: source refreshen → update installeren
4. Let op: GitHub Pages cache ~10 min; oude .deb's blijven bewaard (cache in CI) zodat 404's niet meer voorkomen
