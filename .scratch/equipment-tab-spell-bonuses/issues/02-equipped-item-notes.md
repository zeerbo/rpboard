# 02 — Campo Note su oggetto equipaggiato

**What to build:** Ogni oggetto equipaggiato guadagna un campo **Note** a testo libero, editabile dal dialog dell'oggetto, dove il giocatore annota stato o dettagli (es. "sintonizzato", "cariche 3/3"). Le note, quando valorizzate, compaiono su una riga a sé nel sottotitolo della card dell'oggetto (come il sottotitolo note dell'inventario), leggibili a colpo d'occhio sotto i bonus senza aprire il dialog. Gli oggetti già salvati senza note continuano a caricarsi (default vuoto).

**Blocked by:** 01 — Sposta "Oggetti Equipaggiati" nella tab Equipaggiamento (il dialog oggetto vive nel file spostato).

**Status:** ready-for-agent

- [ ] `EquipmentItem` guadagna un campo `notes` (stringa, default ""), incluso nel round-trip JSON; nessuna migrazione DB (blob JSON esistente).
- [ ] Il dialog dell'oggetto equipaggiato ha un campo Note a testo libero.
- [ ] Le note compaiono su una riga a sé nel sottotitolo della card quando valorizzate; assenti quando vuote.
- [ ] Glossario CONTEXT.md: la voce "EquipmentItem" include il campo `notes`.
- [ ] Test modello: round-trip JSON conserva `notes`; un oggetto serializzato senza il campo carica a default "" senza eccezioni.
