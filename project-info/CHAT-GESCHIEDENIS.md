# Chatgeschiedenis & lesjes (voor de volgende keer)

## Wat de gebruiker wilde (origineel verzoek)

- Tweak voor Sileo op iPhone 6s (iOS 15.8.x, **Dopamine**, rootless)
- Telefoon recht → normaal beeld; telefoon kantelen → speciaal effect
- **Eerste interpretatie** (blur + zwevend scherm): aangepast na feedback
- **Definitieve wens**: beeld blijft "naar voren gericht" als je de telefoon op de X-as kantelt — 3D hologram-effect, géén krimpen, géén blur
- Instellingen: alle apps of alleen homescreen, sterkte-schuifregelaar (0–10)
- Knop "SpringBoard herstarten" in instellingen, want instellingen werden soms niet toegepast
- Effect moest nadrukkelijk zichtbaar zijn ("5x sterker", "10 op de schuif")

## Belangrijke dingen die we onderweg leerden (NIET vergeten!)

1. **Injectie-filter** (`duo/DuoTweak.plist`): sinds iOS 9 is een filter.plist verplicht. Een filter met `Mode: Any` + `com.apple.Security`-truc laadde NIET. Werkend gekregen met: `Bundles = [com.apple.springboard, com.apple.UIKit, com.apple.Security, com.apple.Preferences]` **en in CI converteren naar binary plist** (zoals de werkende tweak "SnowBoardStatusBar" op het toestel). Werkt op het toestel.

2. **Instellingen-paneel grijs** kwam door: Theos verwacht `Resources/` op **projectniveau** (niet in de bundle-map), en de controller moet `loadSpecifiersFromPlistName:@"Root"` zelf aanroepen + `detail` in de PreferenceLoader-plist.

3. **PSSpecifier**: gebruik `+[PSSpecifier groupSpecifierWithName:]` + `setProperty:forKey:` (geen `initWithType:` — bestaat niet in de headers).

4. **`system()` bestaat niet op iOS SDK** — voor respring gebruik `posix_spawn` met `/usr/bin/killall SpringBoard` (extern char **environ;).

5. **ldid** zit niet meer in Ubuntu-repos → download Procursus-binary in CI (`ProcursusTeam/ldid` release `ldid_linux_x86_64`).

6. **Theos toolchain**: Theos bundelt geen toolchain meer → CI downloadt `L1ghtmann/llvm-project` release `iOSToolchain-x86_64.tar.xz` naar `$THEOS/toolchain/`.

7. **GitHub Pages cache** (~10 min, `max-age=600`) veroorzaakte "status 404" bij installeren: oude Packages-lijst wees naar een verwijderde .deb. Fix: CI bewaart alle oude .deb's via `actions/cache` (key `debs-*`), en dpkg-scanpackages maakt --multiversion Packages.

8. **Sileo cachet ook** de Packages-lijst: bij problemen Sileo volledig afsluiten, source verversen, of repo verwijderen/opnieuw toevoegen.

9. **Debug via instellingen-pagina**: SSH werkte niet (wachtwoord onbekend), dus diagnose draait als automatisch tekstblok onderaan de Duo Tweak instellingen-pagina (`diagnoseText` in `DuoTweakPrefsListController.m`). Deze aanpak werkte en gaf de doorslaggevende info (dylib aanwezig, filter-formaat van werkende tweak).

10. **3D-effect werkt op de window layer**: `w.layer.transform` met `CATransform3D` (translate naar center-pivot, `m34 = -1/250`, rotate X-as, terug-transleren). Bij het zetten van de transform **implicit animations uitzetten** (`setDisableActions:YES`), anders dempt/lakt het effect. Instellingen live lezen (elke 0,5s in handleMotion) zodat ze altijd gelden.

## Versiegeschiedenis

| Versie | Wat erin zat | Status |
|---|---|---|
| 1.0.0–1.0.1 | Blur + zwevend scherm bij systeem-rotatie; pref-bundle fixes | Zat aan de basis; 1.0.1: settings werkten |
| 1.0.2–1.0.4 | CoreMotion tilt-sessies, debug-balken, laadmelding | Geen zichtbaar effect (injectie/filter-probleem) |
| 1.0.5–1.0.7 | Filter-proberen, diagnose-knop → diagnose als tekst | Diagnose gaf doorslaggevende info |
| 1.0.8 | Binary filter, eigen overlay-window, kleurcodes | **Eerste zichtbare effect** (kleine tilt) |
| 1.0.9 | Sterker (krimp 0.72, sterkere blur, 12° trigger) | Gebruiker wilde géén krimp/blur |
| 1.1.0 | **3D hologram**: window-layer counter-rotatie met perspectief | **Werkt** ("hij draait") |
| 1.1.1 | 5x sterker | Nog steeds subtiel (perspectief te zwak + animatie-lag) |
| 1.1.2 | **Huidig**: schuifregelaar sterkte (0–10), respring-knop, m34=-1/250, geen animatielag, live prefs | ✔ getest dat het draait; sterkte nader te testen |

## Wat de gebruiker nog zou kunnen willen (ideeën)

- Feedback over de juiste sterkte-waarde (na 1.1.2 testen)
- Ook tegen-sturen bij **rollen** (Y-as / links-rechts kantelen) — nu alleen X-as
- Misschien een optie voor blur/krimp als extra modus (code bestaat in git-geschiedenis)
- Sterkte-profiel: lijnair vs. kwadratisch? (`strength` nu lineair ×theta)

## Quick-checklist bij problemen

1. Staat de nieuwste versie geïnstalleerd in Sileo? (pakketpagina checken)
2. Dopamine: jailbreak actief + tweaks enabled? (na herstart telefoon opnieuw jailbreken!)
3. Instellingen → Duo Tweak → diagnose-blok onderaan lezen (dylib aanwezig?)
4. Sileo cache: volledig herstarten, source verversen
5. GitHub Pages cache: wacht ~10 minuten
6. CI-run checken: https://github.com/jairkorthofschool-oss/duo-tweak/actions
