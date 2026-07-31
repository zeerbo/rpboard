# PRD: Equipaggiamento con bonus nella sezione Combattimento

Status: done

## Problem Statement

In PG Mode, un giocatore che indossa un'armatura o oggetti magici deve oggi ricalcolare a mano ogni valore che quegli oggetti influenzano e riscriverlo nei campi della scheda: la CA, i tiri per colpire, il danno, l'iniziativa, i tiri salvezza, i punteggi caratteristica. Quando cambia equipaggiamento — indossa uno scudo, si toglie un anello — deve rifare tutti quei conti e non ha traccia di *da dove* venga un dato bonus. È laborioso e facile da sbagliare.

## Solution

Nella sezione combattimento della scheda personaggio (PG Mode) il giocatore ottiene una nuova sezione **Equipaggiamento** con:

- uno slot **Armatura** (una sola, opzionale): nome, CA base, e un flag che dice se alla CA base va sommato il modificatore di Destrezza oppure se è una CA fissa;
- una lista **Oggetti equipaggiati**: ogni oggetto ha un nome e una lista di **bonus** che l'utente configura liberamente (tipo + valore).

La scheda si adatta da sola: la CA finale, i tiri per colpire, il danno, l'iniziativa, la velocità, i tiri salvezza e i punteggi caratteristica riflettono i bonus attivi, e ovunque compaia un valore influenzato appare accanto un badge che mostra il totale effettivo e quanto arriva dall'equipaggiamento. Il giocatore continua a digitare nei campi i valori *nudi* del personaggio; l'equipaggiamento si somma sopra, visibilmente, senza sovrascrivere ciò che ha inserito.

L'app è pensata come strumento generico per giochi di ruolo (regole ispirate a 5e ma non vincolate): per questo il calcolo della CA è controllato da un flag scelto dall'utente sull'armatura, non da un tipo di armatura 5e preimpostato.

## User Stories

1. Come giocatore, voglio una sezione Equipaggiamento dentro la tab Combattimento, così ho armatura e oggetti dove già gestisco PF, CA e attacchi.
2. Come giocatore, voglio aggiungere una singola armatura con un nome, così identifico cosa indosso.
3. Come giocatore, voglio inserire la CA base dell'armatura, così la mia CA parte da quel valore.
4. Come giocatore, voglio un flag sull'armatura che dice "somma la Destrezza" oppure "CA fissa", così adatto il calcolo al gioco che sto giocando senza essere vincolato alle regole 5e.
5. Come giocatore con armatura leggera, voglio scegliere "somma Destrezza", così la mia CA è CA base + modificatore di Destrezza.
6. Come giocatore con armatura pesante, voglio scegliere "CA fissa", così la Destrezza non viene sommata.
7. Come giocatore, voglio sostituire o rimuovere l'armatura indossata, così quando cambio equipaggiamento la CA torna a calcolarsi di conseguenza.
8. Come giocatore senza armatura equipaggiata, voglio che la CA usi il valore manuale che ho digitato, così classi/giochi con CA speciale restano supportati.
9. Come giocatore, voglio aggiungere più oggetti equipaggiati distinti dall'armatura, così registro anelli, mantelli, amuleti, ecc.
10. Come giocatore, voglio dare un nome a ciascun oggetto, così lo riconosco nella lista.
11. Come giocatore, voglio aggiungere uno o più bonus a un singolo oggetto, così un oggetto magico che dà più effetti è un'unica voce.
12. Come giocatore, voglio scegliere il tipo di ciascun bonus da un elenco (CA, tiro per colpire, danno, iniziativa, velocità, tiro salvezza, caratteristica), così indico esattamente cosa aumenta.
13. Come giocatore, voglio indicare il valore numerico del bonus, così so di quanto aumenta.
14. Come giocatore che aggiunge un bonus alla CA, voglio che si sommi alla CA di partenza, così uno scudo o un anello aumenta la CA sopra l'armatura (o sopra la CA manuale).
15. Come giocatore che aggiunge un bonus al tiro per colpire, voglio ritrovarlo sommato in tutti i miei attacchi, così vedo il totale corretto senza calcolarlo a mente.
16. Come giocatore, quando il bonus attacco di un attacco è un numero (es. "+5"), voglio vedere il totale calcolato con il bonus da equipaggiamento (es. "+6") e una nota che dice quanto viene dall'equipaggiamento.
17. Come giocatore, quando il bonus attacco di un attacco non è un numero puro, voglio comunque vedere il bonus da equipaggiamento indicato accanto, così l'app non rompe e non perde l'informazione.
18. Come giocatore che aggiunge un bonus al danno, voglio scegliere se è **fisso** (es. +1) oppure a **dadi** (numero di dadi + tipo di dado, es. 3d8), così modello sia una gemma che aggiunge +1 sia un'arma che aggiunge 3d8.
19. Come giocatore con un bonus al danno, voglio vederlo indicato separatamente accanto a ogni attacco (es. "1d6+3 • +3d8 equip."), così so quanto danno extra aggiungere senza che l'app tenti di riscrivere la mia formula di danno.
20. Come giocatore che aggiunge un bonus all'iniziativa, voglio che si sommi al mio bonus iniziativa, così il valore mostrato è già aggiornato.
21. Come giocatore che aggiunge un bonus alla velocità, voglio che si sommi alla mia velocità, così stivali del passo veloce si riflettono da soli.
22. Come giocatore che aggiunge un bonus a un tiro salvezza, voglio scegliere a quale tiro salvezza si applica (Forza, Destrezza, Costituzione, Intelligenza, Saggezza, Carisma) oppure "Tutti", così un mantello della protezione (+1 a tutti i TS) o un oggetto che aiuta un singolo TS sono entrambi esprimibili.
23. Come giocatore che aggiunge un bonus a una caratteristica, voglio scegliere quale caratteristica (o "Tutte"), così un manuale/cintura che aumenta un punteggio è modellabile.
24. Come giocatore con un bonus a una caratteristica, voglio che aumenti il punteggio *effettivo* e che tutto ciò che ne deriva (modificatore, tiri salvezza di quella caratteristica, abilità basate su quella caratteristica, tiri per colpire in mischia) si aggiorni di conseguenza, così il comportamento è coerente con le regole.
25. Come giocatore, voglio continuare a digitare nei campi editabili (CA manuale, punteggi caratteristica, iniziativa, velocità) i valori *nudi* del personaggio, così so sempre cosa è "mio" e cosa arriva dall'equipaggiamento.
26. Come giocatore, voglio un badge accanto a ogni valore influenzato che mostra il totale effettivo e quanto proviene dall'equipaggiamento (es. "10 → 12 (+2 equip.)"), così capisco a colpo d'occhio l'effetto degli oggetti.
27. Come giocatore, voglio che il badge compaia ovunque appaia il valore, anche nelle altre tab (Caratteristiche, Tiri Salvezza, Abilità), così i valori sono coerenti in tutta la scheda.
28. Come giocatore, voglio vedere la CA finale calcolata in modo prominente nella sezione combattimento, così è il primo numero che leggo.
29. Come giocatore, voglio modificare un oggetto o un suo bonus dopo averlo creato, così correggo errori senza ricrearlo.
30. Come giocatore, voglio eliminare un oggetto o un singolo bonus, così quando smetto di usarlo la scheda si riadatta.
31. Come giocatore, voglio che armatura e oggetti equipaggiati siano salvati con la mia scheda, così li ritrovo alla riapertura dell'app.
32. Come giocatore con una scheda creata prima di questa funzione, voglio che la scheda continui a funzionare senza armatura né oggetti (CA = valore manuale), così l'aggiornamento non rompe né altera i miei dati esistenti.

## Implementation Decisions

### Modello di dominio (`Character` e nuove classi di valore)

- Nuova classe **`Armor`** (una per Character, opzionale/nullable): `name` (String), `baseAc` (int), `addsDex` (bool). `addsDex = true` → la CA usa `baseAc + modDes`; `false` → CA fissa `baseAc`. Nessun concetto di tipo armatura 5e (leggera/media/pesante) nel modello: la scelta è il solo flag booleano, per genericità cross-gioco.
- Nuova classe **`EquipmentItem`**: `name` (String) + `bonuses` (`List<EquipmentBonus>`).
- Nuova classe **`EquipmentBonus`**: un `type` (enum/categoria) più i dati che quel tipo richiede:
  - tipi: `ac`, `attack`, `damage`, `initiative`, `speed`, `savingThrow`, `ability`;
  - per `savingThrow` e `ability`: un `target` = una delle sei abilità (`str`/`dex`/`con`/`int`/`wis`/`cha`) **oppure** "tutti/e";
  - valore: per la maggior parte un intero; per `damage` una **forma** — `fixed` con un intero, oppure `dice` con `count` (int) e `die` (es. `d8`, gestito come stringa o intero-facce).
- I campi base persistiti restano **nudi**: `strength`…`charisma`, `armorClass` (CA manuale), `initiativeBonus`, `speed` non vengono modificati dall'equipaggiamento. I bonus vivono solo nei nuovi campi e si applicano tramite getter derivati.
- Nuovi getter derivati puri su `Character` (il seam di test principale):
  - **CA**: `armorClassEffective` = base di partenza + somma bonus `ac`. Base di partenza = CA calcolata dall'armatura (`baseAc + dexMod` se `addsDex`, altrimenti `baseAc`) quando `armor != null`, altrimenti il campo `armorClass` manuale.
  - **Caratteristiche**: punteggi effettivi (es. `effectiveStrength`) = punteggio nudo + bonus `ability` mirati a quella caratteristica + bonus `ability` con target "tutte". I modificatori (`strMod`…`chaMod`, `abilityMod`) leggono i punteggi effettivi, così la propagazione a `savingThrowBonus`, `skillBonus`, `spellcastingAbilityMod`, `spellSaveDC`, `spellAttackBonus` è automatica.
  - **Tiri salvezza**: `savingThrowBonus(ability)` aggiunge i bonus `savingThrow` mirati a quell'abilità + quelli "tutti", sopra il valore già propagato dai punteggi effettivi.
  - **Iniziativa**: `initiativeEffective` = `initiativeBonus` nudo + bonus `initiative`.
  - **Velocità**: `speedEffective` = `speed` nudo + bonus `speed`.
  - **Colpire**: helper che, dato un `Attack`, interpreta la parte numerica di `attackBonus` (es. `"+5"` → 5) e aggiunge la somma dei bonus `attack`. Espone sia il totale calcolato sia la quota da equipaggiamento; quando `attackBonus` non è un intero puro, il totale non viene falsificato — la quota equipaggiamento resta disponibile per mostrarla a fianco.
  - **Danno**: aggregatore dei bonus `damage` attivi in una rappresentazione mostrabile (parte fissa sommata + elenco dei termini a dadi, es. `+1` e `+3d8`), da affiancare all'attacco senza toccare `Attack.damage`.
  - Helper di aggregazione per il badge: dato un campo, restituisce (valore base, totale effettivo, quota equipaggiamento).
- `Attack` **non** viene modificato: i bonus da equipaggiamento sono globali (valgono per tutti gli attacchi), non per-attacco.

### Persistenza e migrazione (secondo seam, ADR-0002 + ADR-0005)

- `Character.toMap`/`fromMap` guadagnano due chiavi JSON: `armor` (oggetto JSON o `null`) e `equipment` (array JSON di oggetti, ciascuno con `bonuses`). Serializzazione via `toJson`/`fromJson` sulle nuove classi, con lo stesso parsing tollerante degli errori già usato per `attacks`/`inventory`/`spells` (try/catch → default vuoto/null).
- Nuovo **step di migrazione versione 2** aggiunto in coda a `productionLadder`: due `ALTER TABLE characters ADD COLUMN` — `armor TEXT DEFAULT NULL` (o `'null'`/`''`, coerente col parsing) e `equipment TEXT DEFAULT '[]'`. La versione del database in `db.dart` passa da 1 a 2. Lo step è append-only: la v1 esistente non si tocca. `onCreate` (fresh install) e `onUpgrade` (install esistente) restano thin caller di `Migrations.stepsFrom`, quindi un DB nuovo e uno migrato risultano identici.
- La migrazione è pura DDL additiva (nessuna trasformazione Dart-side di dati esistenti), dunque rientra nei vincoli dichiarati da ADR-0005.

### UI (seam sottile, nessuna logica di calcolo)

- La sezione **Equipaggiamento** vive in `combattimento_tab.dart` (PG Mode), coerente con la richiesta "nella sezione combattimento". CA finale mostrata in modo prominente.
- Editing di armatura e oggetti tramite dialog, sullo stesso pattern dei dialog di `Attack` già presenti nella tab (aggiungi/modifica/elimina). Il dialog del bonus mostra i sotto-campi in modo condizionale: selettore abilità/"tutti" per `savingThrow` e `ability`; toggle fisso/dadi con i relativi campi per `damage`.
- Badge del totale effettivo accanto a ogni valore influenzato, **anche fuori dalla tab Combattimento**: i punteggi caratteristica, i tiri salvezza e le abilità in `statistiche_tab.dart` mostrano il badge/valore effettivo leggendo i getter aggiornati. I campi editabili continuano a contenere il valore nudo.
- Gli attacchi in `combattimento_tab.dart` mostrano il tiro per colpire come totale calcolato con nota della quota equipaggiamento, e il bonus danno come indicatore separato accanto alla formula di danno.

## Testing Decisions

- **Cosa rende buono un test qui**: verifica solo comportamento esterno osservabile — i valori derivati di `Character` dati input noti (armatura, oggetti, bonus, punteggi nudi) — non i dettagli interni di come i getter sono strutturati. Table-driven dove le combinazioni sono numerose.
- **Seam primario — `Character` (puro Dart, zero I/O)**, prior art [test/models/character_test.dart](test/models/character_test.dart):
  - CA: armatura `addsDex` true/false; nessuna armatura → usa CA manuale; somma dei bonus `ac` in tutti e tre i casi.
  - Punteggi effettivi e propagazione: bonus `ability` su una caratteristica specifica e su "tutte"; verifica che modificatore, `savingThrowBonus` della stessa caratteristica e `skillBonus` di un'abilità basata su quella caratteristica cambino di conseguenza; verifica anche l'effetto su `spellSaveDC`/`spellAttackBonus`.
  - Tiri salvezza: bonus `savingThrow` mirato vs "tutti", sopra la propagazione dei punteggi.
  - Iniziativa e velocità: somma semplice.
  - Colpire: `attackBonus` numerico → totale calcolato corretto; `attackBonus` non numerico → totale non falsificato ma quota equipaggiamento esposta; più bonus `attack` sommati.
  - Danno: forma fissa e forma a dadi; aggregazione di più bonus danno (parte fissa sommata + termini a dadi elencati).
  - Caso limite: nessun equipaggiamento → tutti i valori effettivi coincidono con i nudi (nessuna regressione).
- **Round-trip di serializzazione** sul modello: `toMap`→`fromMap` (e `toJson`/`fromJson`) di armatura e oggetti con bonus di ogni tipo ritorna un `Character` equivalente; input malformati/legacy (chiavi assenti) → armatura `null` e lista oggetti vuota, senza eccezioni.
- **Secondo seam — migrazione**, prior art [test/core/database/migrations_test.dart](test/core/database/migrations_test.dart) (selezione step, dry) e [test/core/database/migrations_execution_test.dart](test/core/database/migrations_execution_test.dart) (SQLite reale): un database v1 esistente, migrato a v2, conserva i dati e acquisisce le nuove colonne con i default corretti; un fresh install a v2 e un install migrato da v1 producono lo stesso schema.
- **Widget test** esistente [test/screens/pg/character_sheet_screen_test.dart](test/screens/pg/character_sheet_screen_test.dart) esteso al minimo per coprire che la sezione compaia e che aggiungere un'armatura aggiorni la CA mostrata; la logica resta testata al seam del model.

## Out of Scope

- Catalogo/import di oggetti o armature predefinite: tutto è inserito a mano.
- Attunement / limite di sintonizzazione, slot per parte del corpo, peso/ingombro dell'equipaggiamento indossato (l'inventario con peso resta la tab `equipaggiamento_tab.dart` esistente, separata).
- Bonus condizionali o situazionali (solo contro un tipo di nemico, solo di notte, ecc.), vantaggio/svantaggio, resistenze/immunità.
- Riscrittura automatica della formula di danno dell'attacco (`Attack.damage` resta intatto; il bonus danno è mostrato a fianco).
- Bonus per-singolo-attacco: i bonus `attack`/`damage` sono globali su tutti gli attacchi.
- Regola 5e "media" per la CA (Destrezza limitata a +2): il flag è binario fisso/somma-Destrezza per scelta esplicita.
- Downgrade/rollback/export dello schema (fuori ambito ADR-0005).

## Further Notes

- L'esistente `equipaggiamento_tab.dart` è l'inventario generico (nome/quantità/peso/note) e resta invariato: questa funzione è una sezione **distinta** dentro Combattimento, non una modifica a quella tab. Il nome della tab e il nome della nuova sezione coincidono in italiano ("Equipaggiamento") ma sono cose diverse — valutare un'etichetta che eviti ambiguità (es. "Equipaggiamento indossato" o "Armatura e oggetti").
- La scelta ibrida sulla CA (manuale senza armatura, calcolata con armatura) è deliberata: preserva le classi/giochi con CA speciale senza forzare una formula.
- I badge fuori dalla tab Combattimento (in `statistiche_tab.dart`) sono l'unico punto in cui questa feature tocca UI oltre Combattimento; la logica sottostante è comunque tutta nei getter di `Character`.
