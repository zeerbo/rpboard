# 03 — Bonus CD Incantesimi e Attacco Incantesimi

**What to build:** Un oggetto equipaggiato può portare due nuovi tipi di bonus: **CD Incantesimi** e **Attacco Incantesimi**, tipi distinti (un oggetto può toccarne solo uno, o entrambi con due bonus separati). Il bonus CD Incantesimi si somma al totale mostrato nel chip **CD Magia** della tab Magie; il bonus Attacco Incantesimi si somma al chip **Bonus Attacco**. Il giocatore vede quindi direttamente la CD/attacco effettivi comprensivi degli oggetti. I bonus compaiono nel riepilogo della card oggetto con etichette brevi (`CD Inc +N`, `Att Inc +N`).

**Blocked by:** 01 — Sposta "Oggetti Equipaggiati" nella tab Equipaggiamento (il dialog bonus vive nel file spostato).

**Status:** ready-for-agent

- [ ] `EquipmentBonusType` guadagna i valori `spellSaveDC` e `spellAttack`; il parse tollerante esistente (nome sconosciuto → `ac`) copre i dati vecchi senza modifiche.
- [ ] Il getter `spellSaveDC` somma `sumEquipmentBonus(spellSaveDC)` al valore base.
- [ ] Il getter `spellAttackBonus` somma `sumEquipmentBonus(spellAttack)` al valore base.
- [ ] Nessun valore scritto nei campi nudi del personaggio: i bonus vivono solo nei getter derivati.
- [ ] Il dialog del bonus ha due nuove voci nel selettore tipo: CD Incantesimi, Attacco Incantesimi.
- [ ] Riepilogo card oggetto: etichette brevi `CD Inc +N` e `Att Inc +N`.
- [ ] I chip "CD Magia" e "Bonus Attacco" nella tab Magie mostrano il totale comprensivo dei bonus.
- [ ] Glossario CONTEXT.md: la voce "EquipmentBonus" include i tipi `spellSaveDC` e `spellAttack`.
- [ ] Test modello: `spellSaveDC` riflette un bonus `spellSaveDC` sommato al base; `spellAttackBonus` riflette un bonus `spellAttack` sommato al base; round-trip JSON dei due tipi conserva i valori; dati vecchi con nome tipo sconosciuto caricano senza eccezioni.
