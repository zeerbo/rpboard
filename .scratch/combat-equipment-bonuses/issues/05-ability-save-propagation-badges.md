# 05 — Bonus caratteristica + tiro salvezza + propagazione + badge in Statistiche

**What to build:** Il giocatore aggiunge a un oggetto un bonus a un **tiro salvezza** o a una **caratteristica**, scegliendo a quale abilità si applica (Forza…Carisma) oppure "Tutti/e". Un bonus a una caratteristica aumenta il punteggio *effettivo* e propaga a tutto ciò che ne deriva: modificatore, tiro salvezza di quella caratteristica, abilità basate su quella caratteristica, spell save DC / spell attack bonus. Un bonus a un tiro salvezza si somma al TS bersaglio (o a tutti). Nella tab Statistiche, i punteggi caratteristica, i tiri salvezza e le abilità mostrano il valore effettivo con il badge, mentre i campi editabili restano coi valori nudi. È la fetta con la propagazione più delicata.

**Blocked by:** 02 (infrastruttura oggetto/bonus/dialog); riusa il componente badge del ticket 04 se già presente, altrimenti lo introduce in Statistiche.

**Status:** done

- [x] `EquipmentBonus` supporta i tipi `savingThrow` e `ability`, ciascuno con un `target` = una delle sei abilità (`str`/`dex`/`con`/`int`/`wis`/`cha`) oppure "tutti/e"; `toJson`/`fromJson` e dialog bonus estesi con selettore tipo + selettore bersaglio condizionale.
- [x] Punteggi effettivi su `Character` (es. `effectiveStrength`) = punteggio nudo + bonus `ability` mirati a quella caratteristica + bonus `ability` "tutte". I modificatori (`strMod`…`chaMod`, `abilityMod`) leggono i punteggi effettivi.
- [x] Propagazione verificata: `savingThrowBonus`, `skillBonus`, `spellcastingAbilityMod`, `spellSaveDC`, `spellAttackBonus` riflettono i punteggi effettivi senza modifiche ai campi nudi.
- [x] `savingThrowBonus(ability)` aggiunge i bonus `savingThrow` mirati a quell'abilità + quelli "tutti", sopra la propagazione dei punteggi.
- [x] Tab Statistiche: punteggi caratteristica, tiri salvezza e abilità mostrano il valore/totale effettivo col badge; i campi punteggio restano editabili col valore nudo.
- [x] Test seam `Character` (table-driven): bonus `ability` su caratteristica specifica e "tutte" → verifica modificatore, TS della stessa caratteristica, `skillBonus` di un'abilità basata su quella caratteristica, effetto su `spellSaveDC`/`spellAttackBonus`; bonus `savingThrow` mirato vs "tutti" sopra la propagazione; round-trip `toJson`/`fromJson` con target.
- [x] Nessuna regressione: senza bonus `ability`/`savingThrow` tutti i valori derivati coincidono coi nudi.
