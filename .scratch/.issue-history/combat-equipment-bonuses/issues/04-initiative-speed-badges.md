# 04 — Bonus iniziativa + velocità + badge in Combattimento

**What to build:** Il giocatore aggiunge a un oggetto un bonus all'**iniziativa** e/o alla **velocità**, e questi si sommano ai rispettivi valori nella scheda. Il giocatore continua a digitare nei campi i valori *nudi*; accanto a ogni valore influenzato compare un badge che mostra il totale effettivo e quanto arriva dall'equipaggiamento (es. "30 → 33 (+3 equip.)"). Questo ticket introduce il badge come componente riusabile nella tab Combattimento (iniziativa, velocità, e la CA finale già calcolata).

**Blocked by:** 02 (infrastruttura oggetto/bonus/dialog).

**Status:** done

- [x] `EquipmentBonus` supporta i tipi `initiative` e `speed` (valore intero); `toJson`/`fromJson` e dialog bonus estesi con le due voci.
- [x] Getter `initiativeEffective` = `initiativeBonus` nudo + somma bonus `initiative`; `speedEffective` = `speed` nudo + somma bonus `speed`.
- [x] Helper di aggregazione per il badge su `Character`: dato un campo, restituisce (valore base, totale effettivo, quota equipaggiamento).
- [x] Componente badge riusabile accanto ai campi in Combattimento: mostrato solo quando la quota equipaggiamento è diversa da zero; i campi restano editabili col valore nudo. Applicato a iniziativa, velocità e CA finale.
- [x] Test seam `Character`: somma iniziativa e velocità; helper badge restituisce base/totale/quota corretti; senza bonus il totale coincide col nudo (badge assente).
- [x] Nessuna regressione sui casi dei ticket precedenti.
