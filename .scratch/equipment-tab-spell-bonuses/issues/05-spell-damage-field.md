# 05 — Campo Danno sull'incantesimo

**What to build:** Ogni incantesimo guadagna un campo **Danno** a testo libero (es. `8d6 fuoco`), editabile dal dialog dell'incantesimo con etichetta `Danno (es. 8d6 fuoco)`. Quando valorizzato, il danno compare nel sottotitolo della card dell'incantesimo accanto a scuola e tempo di lancio (es. `Evocazione • 8d6`), leggibile senza aprire il dettaglio. Questo campo per-incantesimo resta separato e indipendente dal bonus `spellDamage` da equipaggiamento (ticket 04). Gli incantesimi già salvati senza danno continuano a caricarsi (default vuoto).

**Blocked by:** None — can start immediately (tocca solo la tab Magie e il modello `Spell`, indipendente dallo spostamento e dai bonus).

**Status:** ready-for-agent

- [ ] `Spell` guadagna un campo `damage` (stringa, default ""), incluso nel round-trip JSON; nessuna migrazione DB (blob JSON esistente).
- [ ] Il dialog dell'incantesimo ha un campo Danno a testo libero, etichetta `Danno (es. 8d6 fuoco)`.
- [ ] Il sottotitolo della card incantesimo mostra il danno quando valorizzato, accanto a scuola e tempo di lancio; assente quando vuoto.
- [ ] Il campo Danno dell'incantesimo resta separato dal bonus `spellDamage` da equipaggiamento.
- [ ] Test modello: round-trip JSON conserva `Spell.damage`; un incantesimo serializzato senza il campo carica a default "" senza eccezioni.
