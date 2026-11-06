# Hva du må gjøre: steg for steg

Denne guiden er for deg som eier spillet. Claude oppdaterer den når nye steg blir aktuelle.

---

## 1. Test spillet på Android-telefonen din (nå)

Du trenger: en Android-telefon og at du er logget inn på GitHub i nettleseren.

1. Gå til **https://github.com/Felovax/legend-of-kitsune/actions** (på PC eller telefon).
2. Trykk på **android-debug-apk** i listen til venstre.
3. Trykk på den **øverste** kjøringen med grønn hake ✓. Den nyeste er alltid øverst.
4. Bla ned til **Artifacts** og trykk **legend-of-kitsune-debug-apk**. Du laster da ned en zip-fil på ca. 58 MB.
5. Hvis du lastet ned på PC: kopier zip-filen til telefonen, for eksempel med USB-kabel eller Google Drive.
6. På telefonen: åpne zip-filen i appen **Filer**, og trykk **Pakk ut**. Du får filen `legend-of-kitsune-debug.apk`.
7. Trykk på `.apk`-filen. Android spør om du vil tillate installering fra denne kilden: trykk **Innstillinger**, slå på **Tillat fra denne kilden**, gå tilbake og trykk **Installer**.
8. Hvis **Play Protect** advarer, trykk **Installer likevel**. Det skjer fordi testversjonen er signert med en testnøkkel, ikke fordi noe er galt.
9. Åpne **Legend of Kitsune** og spill noen ekspedisjoner.
10. Fortell Claude hvordan det føltes (se punkt 4).

**Nye versjoner:** gjenta steg 1–8. Den nye versjonen installeres over den gamle, og framgangen din beholdes.
Nedlastingene slettes automatisk etter 14 dager, men en ny blir laget hver gang Claude pusher kode.

**iPhone:** ikke mulig ennå. Det krever en Apple-utviklerkonto og en Mac eller en skybygging (se punkt 3).

---

## 2. Lag grafikken med et KI-verktøy (når du vil)

1. Velg **ett** verktøy og hold deg til det, for eksempel Midjourney, Leonardo, Scenario eller Adobe Firefly.
   Sjekk at abonnementet ditt tillater **kommersiell bruk**.
2. Åpne **`docs/ART_PROMPTS.md`** i repositoriet på GitHub.
3. Begynn med **kitsunen**: kopier teksten under «Character sheet» og legg til «style block»-teksten på slutten.
4. Lag mange varianter (20–40) og velg den du liker best. Det er den viktigste figuren i hele spillet.
5. Bruk favoritten som referansebilde, og lag poser, fiender, relikvie-ikoner og bakgrunner med de andre tekstene.
6. Fjern bakgrunnen (de fleste verktøy har en knapp for det) og lagre som **PNG**, helst 1024×1024.
7. Gi filene nøyaktig disse navnene:
   - `kitsune.png`
   - `moss_slime.png`, `ember_imp.png`, `stone_sentinel.png`, `lantern_wisp.png`
   - `ruin_brute.png`, `gatekeeper_golem.png`
8. Send bildene til Claude i chatten, eller last dem opp på GitHub: åpne mappen `assets/sprites/` → **Add file** → **Upload files**.
   Spillet bruker dem automatisk i stedet for de tegnede plassholderne.
9. Skriv til Claude hvilket verktøy du brukte, hvilken dato og hvilken tekst, så føres det inn i `docs/ASSET_LOG.md`. Det er viktig hvis noen spør hvor grafikken kommer fra.

---

## 3. Senere, før spillet kan legges ut i butikkene (ikke nå)

Claude sier fra når det er tid. Til orientering:

1. **Google Play-konto** (25 dollar én gang): https://play.google.com/console
   - En privat konto må ha en lukket test med **12 testere i 14 dager** før lansering. Begynn gjerne allerede nå å tenke på hvem som kan teste (venner og familie med Android).
   - En organisasjonskonto slipper det kravet, men trenger et D-U-N-S-nummer for et firma.
2. **Apple-utviklerkonto** (99 dollar i året) når vi skal ha spillet på iPhone. Da trengs også en Mac eller en skybygging. Det setter Claude opp.
3. **Varemerkesjekk** av navnet «Legend of Kitsune» før lansering, for eksempel med en patentrådgiver eller selv på https://search.patentstyret.no og EUIPO.
4. **Personvernerklæring.** Claude lager et utkast når analyse og kjøp er på plass.

---

## 4. Tilbakemelding Claude trenger fra deg

Etter at du har spilt, svar gjerne kort på dette:

- Var de første kapitlene **for lette, passe eller for vanskelige**?
- Gikk kampene **for fort eller for sakte**?
- Var **tekst og knapper** lette å lese og trykke på?
- Var det noe du **ikke skjønte**?
- Hva savnet du mest, og hva var **morsomst**?
