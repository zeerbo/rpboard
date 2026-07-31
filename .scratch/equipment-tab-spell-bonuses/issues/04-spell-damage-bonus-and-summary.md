# 04 — Bonus Danno Incantesimi + riga riepilogo nella tab Magie

**What to build:** Un oggetto equipaggiato può portare un bonus **Danno Incantesimi**, un danno aggiuntivo che i suoi incantesimi infliggono, configurabile come valore **fisso** oppure come **dadi** (numero + tipo dado) — esattamente come il danno arma (es. "+2" o "+1d6"). Nella tab Magie, sotto i chip CD Magia / Bonus Attacco, compare una riga di riepilogo globale `Danno Incantesimi: +1d6` che aggrega tutti i bonus di quel tipo, mostrata **solo** quando c'è almeno un bonus (label non nullo). Il bonus compare nel riepilogo della card oggetto con etichetta breve (`Danno Inc +N` / `+NdM`). Questo danno da equipaggiamento resta separato dal campo Danno del singolo incantesimo (ticket 05): nessuna somma tra i due.

**Blocked by:** 03 — Bonus CD Incantesimi e Attacco Incantesimi (condivide l'enum `EquipmentBonusType` e il selettore tipo del dialog bonus; tenere le due aggiunte in sequenza mantiene CI verde).

**Status:** ready-for-agent

- [ ] `EquipmentBonusType` guadagna il valore `spellDamage`, che riusa i campi già presenti su `EquipmentBonus` (`damageForm`, `diceCount`, `die`, `value`) — nessun nuovo campo, identico al tipo `damage`.
- [ ] Nuovo getter `spellDamageBonus()` (fisso sommato + lista termini a dadi) e `spellDamageLabel()` (stringa "+X" / "+NdM" / null), a specchio di `equipmentDamageBonus()` / `equipmentDamageLabel()` ma filtrando il tipo `spellDamage`.
- [ ] Il dialog del bonus ha la voce Danno Incantesimi con lo stesso toggle Fisso/Dadi del tipo Danno (arma).
- [ ] Riepilogo card oggetto: etichetta breve `Danno Inc +N` / `Danno Inc +NdM`.
- [ ] Nella tab Magie, sotto i chip, compare la riga `Danno Incantesimi: <label>` solo quando `spellDamageLabel()` non è nullo.
- [ ] Il Danno Incantesimi da equipaggiamento resta separato dal campo Danno del singolo incantesimo: nessuna somma numerica tra i due.
- [ ] Glossario CONTEXT.md: la voce "EquipmentBonus" include il tipo `spellDamage`.
- [ ] Test modello: `spellDamageLabel()` aggrega correttamente termine fisso e termini a dadi da più oggetti ed è nullo quando non ci sono bonus `spellDamage`; round-trip JSON del tipo `spellDamage` conserva i valori.
