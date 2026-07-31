# 01 — Slot Armatura → CA calcolata

**What to build:** In PG Mode, tab Combattimento, il giocatore aggiunge una singola armatura (nome, CA base, flag "somma Destrezza / CA fissa") e la CA finale della scheda si adegua da sola. Con armatura "somma Destrezza" la CA è CA base + modificatore di Destrezza; con "CA fissa" è la CA base esatta. Rimossa/assente l'armatura, la CA torna a usare il valore CA manuale già digitato. La CA finale è mostrata in modo prominente nella sezione combattimento. Armatura salvata con la scheda e ritrovata alla riapertura; le schede esistenti (senza armatura) continuano a funzionare identiche.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] Nuova classe `Armor` (`name`, `baseAc`, `addsDex`) con `toJson`/`fromJson`, parsing tollerante agli errori come `Attack`/`inventory`.
- [x] `Character` ha un campo `armor` opzionale (nullable); `toMap`/`fromMap` serializzano la chiave `armor` (oggetto JSON o assente/null).
- [x] Getter `armorClassEffective`: con `armor != null` → `baseAc + dexMod` se `addsDex`, altrimenti `baseAc`; con `armor == null` → campo `armorClass` manuale.
- [x] Migrazione schema **versione 2** aggiunta in coda a `productionLadder`: due `ALTER TABLE characters ADD COLUMN` — `armor` e `equipment TEXT DEFAULT '[]'` (la colonna `equipment` è creata qui ma usata dai ticket successivi). Versione del database in db.dart portata da 1 a 2.
- [x] `onCreate` (fresh install a v2) e `onUpgrade` (v1→v2) producono lo stesso schema; un DB v1 con dati esistenti, migrato, conserva i dati e ottiene le nuove colonne coi default.
- [x] Tab Combattimento: slot Armatura con aggiungi/modifica/rimuovi (dialog sul pattern dei dialog `Attack` esistenti); la CA finale (`armorClassEffective`) è mostrata prominente.
- [x] Test seam `Character` (puro Dart, prior art `test/models/character_test.dart`): CA con `addsDex` true/false, senza armatura → CA manuale; round-trip `toMap`/`fromMap` con e senza armatura; input legacy senza chiave `armor` → `armor` null senza eccezioni.
- [x] Test migrazione: selezione step v1→v2 (dry, prior art `migrations_test.dart`) + esecuzione su SQLite reale che conserva i dati (prior art `migrations_execution_test.dart`).
- [x] Nessuna regressione: senza armatura tutti i valori coincidono coi campi nudi esistenti.
