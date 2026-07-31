# 03 — Bonus colpire + danno negli attacchi

**What to build:** Il giocatore aggiunge a un oggetto un bonus al **tiro per colpire** e/o al **danno**, e li ritrova riflessi in *tutti* i suoi attacchi (i bonus sono globali, non per-attacco). Colpire: quando il bonus attacco dell'attacco è un numero (es. "+5"), l'attacco mostra il totale calcolato (es. "+6") con nota della quota da equipaggiamento; quando non è un numero puro, il bonus da equipaggiamento è indicato accanto senza rompere né falsificare il totale. Danno: il bonus è **fisso** (es. +1) oppure a **dadi** (numero + tipo di dado, es. 3d8), mostrato come indicatore separato accanto alla formula di danno (es. "1d6+3 • +3d8 equip.") senza riscrivere `Attack.damage`.

**Blocked by:** 02 (infrastruttura oggetto/bonus/dialog).

**Status:** done

- [x] `EquipmentBonus` supporta il tipo `attack` (valore intero) e il tipo `damage` con forma **fisso** (intero) o **dadi** (`count` + `die`); `toJson`/`fromJson` estesi; dialog bonus estende il selettore tipo con "tiro per colpire" e "danno" (toggle fisso/dadi con i relativi campi).
- [x] Helper su `Character` per il colpire: interpreta la parte numerica di `Attack.attackBonus`, somma i bonus `attack`, espone totale calcolato **e** quota equipaggiamento; su `attackBonus` non intero puro il totale non è falsificato ma la quota resta disponibile.
- [x] Aggregatore su `Character` per il danno: somma la parte fissa dei bonus `damage` ed elenca i termini a dadi, in una rappresentazione mostrabile accanto all'attacco.
- [x] Tab Combattimento, lista attacchi: mostra il totale colpire con nota della quota equipaggiamento e il bonus danno come indicatore separato accanto alla formula.
- [x] Test seam `Character`: `attackBonus` numerico → totale corretto; non numerico → totale non falsificato + quota esposta; più bonus `attack` sommati; danno forma fissa, forma a dadi, aggregazione di più bonus danno; round-trip `toJson`/`fromJson` dei nuovi tipi.
- [x] Nessuna regressione: senza bonus `attack`/`damage` gli attacchi si mostrano come prima.
