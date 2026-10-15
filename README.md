# TurboTast ⚡

En liten Mac-app i menylinjen som ganger opp tastetrykk og museklikk – litt som AutoHotkey.
Trykk **W** én gang, og TurboTast trykker den 10 ganger for deg.

## Funksjoner

- **Ganger opp** – ett trykk blir til 2–1000 trykk.
- **Hold for spam** – trykker om og om igjen så lenge du holder inne.
- **Taster og museklikk** – venstre- og høyreklikk kan også ganges opp.
- **Justerbar hastighet** – 1–500 ms pause mellom hvert trykk.
- **Profiler** – lagre ulike oppsett og bytt raskt fra menylinjen.
- **⌃⌥⌘M** slår TurboTast av/på hvor som helst.
- Kombinasjoner med ⌘, ⌃ eller ⌥ blir aldri ganget opp (så ⌘W lukker ikke ti vinduer).
- Innebygd **«Se etter oppdateringer…»** som installerer nye versjoner med ett klikk.

Krever macOS 15 eller nyere. Virker på både Apple Silicon og Intel.

## Installering

1. Last ned **TurboTast.zip** fra [siste release](https://github.com/olaimalm/TurboTast/releases/latest).
2. Pakk ut og dra **TurboTast.app** inn i **Programmer**.
3. Åpne appen. Første gang sier macOS at den ikke kan bekrefte utvikleren (appen er ikke notarisert av Apple).
   Gå til **Systeminnstillinger → Personvern og sikkerhet**, bla ned og klikk **Åpne likevel**.
   Alternativt i Terminal:
   ```bash
   xattr -dr com.apple.quarantine /Applications/TurboTast.app
   ```
4. Gi tilgang under **Systeminnstillinger → Personvern og sikkerhet → Tilgjengelighet** og slå på TurboTast.
   Uten dette kan ikke appen se eller sende tastetrykk.
5. Klikk ⚡-ikonet i menylinjen → **Aktiv**.

> Etter en oppdatering kan macOS «glemme» tilgangen selv om bryteren står på.
> Fjern TurboTast fra listen med **–** og legg den til igjen.

## Bruk

Klikk ⚡ → **Innstillinger…**. For hver rad velger du:

| Felt | Betydning |
| --- | --- |
| Tast / klikk | Klikk og trykk en tast, eller velg venstre-/høyreklikk |
| Modus | *Ganger opp* eller *Hold for spam* |
| Antall | Totalt antall trykk per ekte trykk (inkludert ditt eget) |
| Pause | Tid mellom hvert ekstra trykk |

⚠️ Mange nettspill har anti-juks som kan oppdage makroer. Bruk på eget ansvar.

## Utvikling

Krever Xcode (eller Command Line Tools med Swift 6).

```bash
./build.sh            # bygg for denne Macen → build/TurboTast.app
./build.sh --install  # bygg, installer i /Applications og start
./build.sh --release  # universal-bygg + build/TurboTast.zip
```

Koden ligger i `Sources/`:

- `InputEngine.swift` – fanger opp og sender tastetrykk/klikk (CGEventTap)
- `AppState.swift` – innstillinger, profiler og tilgang
- `Views.swift` – menylinjen og innstillingsvinduet (SwiftUI)
- `Updater.swift` – sjekker og installerer nye versjoner fra GitHub Releases

### Lage en ny versjon

```bash
git tag v1.1.0
git push origin v1.1.0
```

GitHub Actions bygger appen og publiserer en ny release med `TurboTast.zip`.
Alle som har appen får beskjed neste gang de starter den (eller via «Se etter oppdateringer…»).

## Lisens

MIT – se [LICENSE](LICENSE).
