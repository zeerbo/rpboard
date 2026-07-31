# 02 — Oggetti equipaggiati + bonus CA additivo

**What to build:** In PG Mode, tab Combattimento, il giocatore aggiunge oggetti equipaggiati distinti dall'armatura (anelli, mantelli, amuleti…), ciascuno con un nome e uno o più bonus configurabili. Questo ticket stabilisce tutta l'infrastruttura oggetto/bonus (lista con aggiungi/modifica/elimina, dialog del bonus) e cabla il primo tipo di bonus: **CA additivo**. Un oggetto che dà +1 CA fa salire la CA finale sopra il valore di partenza (armatura calcolata, o CA manuale se nessuna armatura). Oggetti salvati con la scheda e ritrovati alla riapertura.

**Blocked by:** 01 (la colonna `equipment` e il calcolo CA di partenza arrivano da lì).

**Status:** done

- [x] Nuova classe `EquipmentItem` (`name` + `bonuses: List<EquipmentBonus>`) con `toJson`/`fromJson`.
- [x] Nuova classe `EquipmentBonus` con un `type` (categoria) e i dati che richiede; in questo ticket è implementato/selezionabile solo il tipo **CA additivo** (valore intero). La forma della classe è progettata per ospitare i tipi futuri (`attack`, `damage`, `initiative`, `speed`, `savingThrow`, `ability`) senza riscrittura.
- [x] `Character` ha `equipment: List<EquipmentItem>`; `toMap`/`fromMap` serializzano la chiave `equipment` (array JSON), parsing tollerante → lista vuota su input malformato/assente.
- [x] `armorClassEffective` esteso: base di partenza (dal ticket 01) + somma di tutti i bonus CA additivi degli oggetti.
- [x] Tab Combattimento: sezione lista oggetti equipaggiati con aggiungi/modifica/elimina oggetto; dialog oggetto con nome + gestione dei suoi bonus (aggiungi/modifica/elimina bonus); dialog bonus con selettore tipo (per ora solo "CA") e valore.
- [x] Etichetta della sezione che evita ambiguità con la tab inventario `equipaggiamento_tab.dart` esistente (es. "Armatura e oggetti" / "Equipaggiamento indossato").
- [x] Test seam `Character`: somma bonus CA additivi con armatura, senza armatura (sopra CA manuale), più oggetti con più bonus CA; round-trip `toMap`/`fromMap` di oggetti con bonus; input legacy senza chiave `equipment` → lista vuota senza eccezioni.
- [x] Nessuna regressione sui casi del ticket 01.
