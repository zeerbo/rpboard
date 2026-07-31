# 01 — Sposta "Oggetti Equipaggiati" nella tab Equipaggiamento

**What to build:** In PG Mode la sezione **Oggetti Equipaggiati** (header + lista + pulsante "Aggiungi Oggetto") vive nella tab **Equipaggiamento**, collocata tra la sezione **Monete** e la sezione **Inventario**, invece che nella tab **Combattimento**. Il giocatore aggiunge/modifica/elimina gli oggetti con lo stesso flusso di prima, solo da un posto diverso. L'**Armatura** e i valori derivati (CA, iniziativa, velocità con i loro badge) restano visibili in Combattimento: si sposta solo l'interfaccia di modifica degli oggetti, non i calcoli.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] La sezione Oggetti Equipaggiati (header, lista card, pulsante "Aggiungi Oggetto") compare nella tab Equipaggiamento tra Monete e Inventario.
- [ ] Tutto l'apparato di dialog/helper dell'oggetto (dialog oggetto, dialog bonus, descrizione bonus, label target) accompagna la sezione nella nuova posizione.
- [ ] La sezione Oggetti Equipaggiati non compare più nella tab Combattimento.
- [ ] La sezione Armatura resta in Combattimento, invariata.
- [ ] CA, iniziativa e velocità (con i loro badge derivati dagli oggetti) continuano a mostrarsi in Combattimento; i totali sono identici a prima.
- [ ] Test widget: la sezione Oggetti Equipaggiati è raggiungibile dalla tab Equipaggiamento e non dalla tab Combattimento; l'Armatura resta in Combattimento.
