# PRD: Oggetti equipaggiati nel tab Equipaggiamento + note e bonus incantesimi

Status: ready-for-agent

## Problem Statement

In PG Mode, la sezione **Oggetti Equipaggiati** vive oggi nella tab **Combattimento**, mescolata con PF, CA e attacchi. Concettualmente sono roba indossata (anelli, mantelli, amuleti), più vicini all'inventario che al combattimento: il giocatore li cerca dove gestisce l'equipaggiamento e non li trova.

Inoltre gli oggetti equipaggiati oggi non permettono di:

- annotare informazioni libere sull'oggetto (es. "sintonizzato", "cariche 3/3");
- esprimere bonus che toccano la magia — la CD degli incantesimi, il bonus di attacco con incantesimi e un danno aggiuntivo agli incantesimi — sebbene esistano oggetti magici che li concedono.

Infine, un incantesimo nella scheda non ha un campo dove annotare il proprio danno.

## Solution

Dal punto di vista del giocatore:

- La sezione **Oggetti Equipaggiati** si sposta dalla tab Combattimento alla tab **Equipaggiamento**, collocata tra **Monete** e **Inventario**. Rimane la stessa lista con gli stessi bonus; cambia solo dove si modifica. L'**Armatura** resta in Combattimento, e i valori derivati (CA, iniziativa, velocità con i loro badge) continuano a mostrarsi in Combattimento: si sposta solo l'interfaccia di modifica, non i calcoli.
- Ogni **oggetto equipaggiato** guadagna un campo **Note** a testo libero, visibile a colpo d'occhio sotto i bonus nella card.
- I bonus configurabili di un oggetto guadagnano tre nuovi tipi: **CD Incantesimi**, **Attacco Incantesimi** e **Danno Incantesimi**. I primi due si sommano rispettivamente alla CD magia e al bonus di attacco con incantesimi mostrati nella tab Magie. Il **Danno Incantesimi** — configurabile come valore fisso o come dadi, esattamente come il danno arma — compare come riga di riepilogo globale nella tab Magie.
- Ogni **incantesimo** guadagna un campo **Danno** a testo libero (es. `8d6 fuoco`), mostrato nella card dell'incantesimo accanto a scuola e tempo di lancio.

Nessun valore viene mai scritto nei campi nudi del personaggio: i bonus si sommano nei getter derivati, come già fa il resto dell'equipaggiamento.

## User Stories

1. Come giocatore, voglio gestire gli oggetti equipaggiati nella tab Equipaggiamento, così li trovo dove gestisco monete e inventario invece che nel combattimento.
2. Come giocatore, voglio che gli oggetti equipaggiati stiano tra Monete e Inventario, così la roba indossata (con effetti attivi) sta sopra l'inventario generico.
3. Come giocatore, voglio che l'Armatura resti nella tab Combattimento, così la CA e il suo slot restano vicini alle statistiche di combattimento.
4. Come giocatore, voglio che CA/iniziativa/velocità e i loro badge continuino a mostrarsi in Combattimento anche dopo lo spostamento, così i valori derivati dagli oggetti restano visibili dove li uso.
5. Come giocatore, voglio aggiungere/modificare/eliminare oggetti equipaggiati dal nuovo posto con lo stesso flusso di prima, così non devo reimparare nulla.
6. Come giocatore, voglio un campo Note a testo libero su ogni oggetto equipaggiato, così annoto stato o dettagli (es. "sintonizzato", "cariche 3/3").
7. Come giocatore, voglio vedere le note sotto i bonus nella card dell'oggetto, così le leggo a colpo d'occhio senza aprire il dialog.
8. Come giocatore, voglio un bonus "CD Incantesimi" su un oggetto, così un oggetto magico può aumentare la CD dei miei incantesimi.
9. Come giocatore, voglio che il bonus CD Incantesimi si sommi al totale mostrato nel chip "CD Magia", così vedo direttamente la CD effettiva.
10. Come giocatore, voglio un bonus "Attacco Incantesimi" su un oggetto, così un oggetto magico può aumentare il mio bonus di attacco con incantesimi.
11. Come giocatore, voglio che il bonus Attacco Incantesimi si sommi al chip "Bonus Attacco", così vedo il valore effettivo.
12. Come giocatore, voglio che CD e Attacco Incantesimi siano due tipi di bonus distinti, così un oggetto può toccarne solo uno, o entrambi con due bonus separati.
13. Come giocatore, voglio un bonus "Danno Incantesimi" su un oggetto, così registro un danno aggiuntivo che i miei incantesimi infliggono.
14. Come giocatore, voglio configurare il Danno Incantesimi come valore fisso oppure come dadi (numero + tipo dado), esattamente come il danno arma, così esprimo sia "+2" che "+1d6".
15. Come giocatore, voglio vedere il Danno Incantesimi aggregato come una riga di riepilogo nella tab Magie (es. "Danno Incantesimi: +1d6"), così so quanto danno extra portano i miei oggetti.
16. Come giocatore, voglio che la riga Danno Incantesimi compaia solo quando c'è almeno un bonus di quel tipo, così non ingombra quando è a zero.
17. Come giocatore, voglio che il Danno Incantesimi da equipaggiamento resti separato dal campo Danno del singolo incantesimo, così i due non si confondono.
18. Come giocatore, voglio un campo Danno a testo libero nella definizione di un incantesimo, così annoto il danno che infligge (es. "8d6 fuoco").
19. Come giocatore, voglio vedere il danno dell'incantesimo nella card della lista incantesimi accanto a scuola e tempo di lancio, così lo leggo senza aprire il dettaglio.
20. Come giocatore, voglio che i nuovi tipi di bonus appaiano nel riepilogo della card oggetto con etichette brevi (CD Inc, Att Inc, Danno Inc), così scorro i bonus di un oggetto rapidamente.
21. Come giocatore esistente con oggetti/incantesimi già salvati, voglio che i miei dati continuino a caricarsi dopo l'aggiornamento, così non perdo nulla (nuovi campi assenti = default vuoto).

## Implementation Decisions

### Modello (Character)

- **`Spell`** guadagna un campo `damage` (stringa, default vuoto), incluso nel round-trip JSON. `Spell` è persistito come blob JSON: nessuna migrazione DB.
- **`EquipmentItem`** guadagna un campo `notes` (stringa, default vuoto), incluso nel round-trip JSON. Persistito come blob JSON: nessuna migrazione DB.
- **`EquipmentBonusType`** guadagna tre valori: `spellSaveDC`, `spellAttack`, `spellDamage`. Il parse tollerante esistente (nome sconosciuto → `ac`) copre i dati vecchi senza modifiche.
- Il getter `spellSaveDC` somma `sumEquipmentBonus(spellSaveDC)`.
- Il getter `spellAttackBonus` somma `sumEquipmentBonus(spellAttack)`.
- Nuovi getter `spellDamageBonus()` (fisso sommato + lista termini a dadi) e `spellDamageLabel()` (stringa "+X" / "+NdM" / null), a specchio degli esistenti `equipmentDamageBonus()` / `equipmentDamageLabel()` ma filtrando il tipo `spellDamage`.
- `spellDamage` riusa i campi già presenti su `EquipmentBonus` (`damageForm`, `diceCount`, `die`, `value`) — nessun nuovo campo: identico al tipo `damage` esistente.

### UI — spostamento

- La sezione **Oggetti Equipaggiati** (header + lista + pulsante "Aggiungi Oggetto") e il suo apparato di dialog/helper (dialog oggetto, dialog bonus, descrizione bonus, label target) si spostano dalla tab Combattimento alla tab Equipaggiamento, collocati tra la sezione Monete e la sezione Inventario. L'**Armatura** e tutti i badge derivati restano in Combattimento.

### UI — nuovi campi e bonus

- Il dialog dell'oggetto equipaggiato guadagna un campo **Note** a testo libero; le note compaiono su una riga a sé nel sottotitolo della card quando valorizzate (come il sottotitolo note dell'inventario).
- Il dialog del bonus guadagna tre voci nel selettore tipo: **CD Incantesimi**, **Attacco Incantesimi**, **Danno Incantesimi**. `Danno Incantesimi` mostra lo stesso toggle Fisso/Dadi del tipo `Danno` (arma).
- Le etichette brevi nel riepilogo bonus: `CD Inc +N`, `Att Inc +N`, `Danno Inc +N` / `+NdM`.

### UI — tab Magie

- Il dialog dell'incantesimo guadagna un campo **Danno** a testo libero, etichetta `Danno (es. 8d6 fuoco)`.
- Il sottotitolo della card incantesimo mostra il danno quando valorizzato, accanto a scuola e tempo di lancio (es. `Evocazione • 8d6`).
- Sotto i chip CD Magia / Bonus Attacco compare una riga `Danno Incantesimi: +1d6` solo quando `spellDamageLabel()` non è nullo.

## Testing Decisions

Un buon test verifica il **comportamento esterno**, non i dettagli implementativi: dati i punteggi/prof di un Character e una lista di oggetti con certi bonus, i getter derivati producono i totali attesi; un oggetto/incantesimo serializzato e rideserializzato conserva i nuovi campi. Nessun test tocca i campi privati o la struttura interna dei widget oltre alla presenza/assenza visibile.

- **Seam primario — modello `Character`** (`test/models/character_test.dart`, prior art: i test dei bonus equipaggiamento già presenti nello stesso file):
  - `spellSaveDC` riflette un bonus `spellSaveDC` sommato al valore base.
  - `spellAttackBonus` riflette un bonus `spellAttack` sommato al valore base.
  - `spellDamageLabel()` aggrega correttamente termine fisso e termini a dadi da più oggetti; è nullo quando non ci sono bonus `spellDamage`.
  - Round-trip JSON: `EquipmentItem.notes`, `Spell.damage`, e `EquipmentBonus` dei tre nuovi tipi conservano i valori; dati vecchi senza i nuovi campi/nomi caricano a default senza eccezioni.
- **Seam widget** (`test/screens/pg/character_sheet_screen_test.dart`, prior art: i test di presenza sezioni per tab già presenti): la sezione Oggetti Equipaggiati è raggiungibile dalla tab Equipaggiamento e non più dalla tab Combattimento; l'Armatura resta in Combattimento.

Nessun test di migrazione DB: non c'è cambio di schema (tutti i nuovi campi vivono in blob JSON già esistenti).

## Out of Scope

- Nessuna somma numerica tra il bonus `spellDamage` da equipaggiamento e il campo `Danno` a testo libero del singolo incantesimo: restano due valori separati e indipendenti.
- Nessun badge "effettivo" (base + quota equip) accanto ai chip CD Magia / Bonus Attacco: i chip mostrano solo il totale comprensivo dei bonus.
- Nessun tiro di dado o calcolo del danno effettivo: l'app resta descrittiva.
- Nessuna modifica all'Armatura o agli altri tipi di bonus esistenti.
- Nessuna migrazione dello schema DB.

## Further Notes

- Coerenza glossario (CONTEXT.md): "EquipmentItem" e "EquipmentBonus" vanno aggiornati per includere il campo `notes` e i tre nuovi tipi di bonus (`spellSaveDC`, `spellAttack`, `spellDamage`); "Character" già cita CD e bonus di attacco incantesimi.
- Il pattern di aggregazione fisso+dadi è già collaudato per il danno arma (`equipmentDamageBonus`/`equipmentDamageLabel`): i nuovi getter incantesimi lo ricalcano filtrando per tipo.
