import Foundation

/// UI translations. Each block is an English string followed by one line per language
/// ("it|…", "de|…", "fr|…", "es|…"). Blocks are separated by a blank line.
/// %@ marks a value filled in at runtime; %1$@ / %2$@ when a language needs a different order.
enum Translations {
    static let table: [Lang: [String: String]] = {
        var out: [Lang: [String: String]] = [:]
        for block in source.components(separatedBy: "\n\n") {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard let key = lines.first else { continue }
            for line in lines.dropFirst() {
                guard let bar = line.firstIndex(of: "|"), let lang = Lang(rawValue: String(line[..<bar])) else { continue }
                out[lang, default: [:]][key] = String(line[line.index(after: bar)...])
            }
        }
        return out
    }()

    private static let source = #"""
Flush DNS Cache
it|Svuota cache DNS
de|DNS-Cache leeren
fr|Vider le cache DNS
es|Vaciar caché DNS

Fixes websites that won't load after network changes.
it|Risolve i siti che non si caricano dopo un cambio di rete.
de|Behebt Websites, die nach einem Netzwerkwechsel nicht laden.
fr|Répare les sites qui ne se chargent plus après un changement de réseau.
es|Arregla webs que no cargan tras un cambio de red.

Free Up RAM
it|Libera RAM
de|RAM freigeben
fr|Libérer la RAM
es|Liberar RAM

Clears inactive memory so busy apps get room.
it|Libera la memoria inattiva per dare spazio alle app in uso.
de|Gibt inaktiven Speicher frei, damit aktive Apps Platz haben.
fr|Libère la mémoire inactive pour laisser de la place aux apps actives.
es|Libera memoria inactiva para dar espacio a las apps en uso.

Reset Quick Look
it|Reimposta Quick Look
de|Übersicht zurücksetzen
fr|Réinitialiser Coup d'œil
es|Restablecer Vista Rápida

Fixes blank or outdated file previews and thumbnails.
it|Risolve anteprime e miniature vuote o non aggiornate.
de|Behebt leere oder veraltete Dateivorschauen und Miniaturen.
fr|Répare les aperçus et vignettes vides ou obsolètes.
es|Arregla vistas previas y miniaturas vacías o desactualizadas.

Reindex Spotlight
it|Reindicizza Spotlight
de|Spotlight neu indizieren
fr|Réindexer Spotlight
es|Reindexar Spotlight

Rebuilds search when results are missing. Takes a while to finish.
it|Ricostruisce la ricerca quando mancano risultati. Richiede un po' di tempo.
de|Baut die Suche neu auf, wenn Ergebnisse fehlen. Dauert eine Weile.
fr|Reconstruit la recherche quand des résultats manquent. Prend un certain temps.
es|Reconstruye la búsqueda cuando faltan resultados. Tarda un rato.

Rebuild Launch Services
it|Ricostruisci Launch Services
de|Launch Services neu aufbauen
fr|Reconstruire Launch Services
es|Reconstruir Launch Services

Fixes duplicate entries in the "Open With" menu.
it|Risolve le voci doppie nel menu "Apri con".
de|Behebt doppelte Einträge im Menü „Öffnen mit“.
fr|Corrige les doublons dans le menu « Ouvrir avec ».
es|Arregla entradas duplicadas en el menú «Abrir con».

Mapping your storage…
it|Mappatura dello spazio…
de|Speicher wird kartiert…
fr|Cartographie du stockage…
es|Mapeando tu almacenamiento…

Back
it|Indietro
de|Zurück
fr|Retour
es|Atrás

Show in Finder
it|Mostra nel Finder
de|Im Finder zeigen
fr|Afficher dans le Finder
es|Mostrar en Finder

Space to preview
it|Spazio per l'anteprima
de|Leertaste für Vorschau
fr|Espace pour l'aperçu
es|Espacio para previsualizar

No items selected
it|Nessun elemento selezionato
de|Keine Objekte ausgewählt
fr|Aucun élément sélectionné
es|Ningún elemento seleccionado

%@ selected · %@
it|%@ selezionati · %@
de|%@ ausgewählt · %@
fr|%@ sélectionnés · %@
es|%@ seleccionados · %@

Move to Trash
it|Sposta nel Cestino
de|In den Papierkorb
fr|Placer dans la corbeille
es|Mover a la Papelera

Move %@ items to the Trash?
it|Spostare %@ elementi nel Cestino?
de|%@ Objekte in den Papierkorb legen?
fr|Placer %@ éléments dans la corbeille ?
es|¿Mover %@ elementos a la Papelera?

Cancel
it|Annulla
de|Abbrechen
fr|Annuler
es|Cancelar

You can put them back from the Trash until you empty it.
it|Puoi ripristinarli dal Cestino finché non lo svuoti.
de|Bis du den Papierkorb leerst, kannst du sie zurücklegen.
fr|Vous pouvez les récupérer dans la corbeille tant que vous ne la videz pas.
es|Puedes recuperarlos de la Papelera hasta que la vacíes.

Double-click to open
it|Doppio clic per aprire
de|Doppelklick zum Öffnen
fr|Double-cliquez pour ouvrir
es|Doble clic para abrir

Quick Look
it|Quick Look
de|Übersicht
fr|Coup d'œil
es|Vista Rápida

Open
it|Apri
de|Öffnen
fr|Ouvrir
es|Abrir

Open in Disk Map
it|Apri nella Mappa disco
de|In Speicherkarte öffnen
fr|Ouvrir dans Carte du disque
es|Abrir en Mapa del disco

Copy Path
it|Copia percorso
de|Pfad kopieren
fr|Copier le chemin
es|Copiar ruta

Deselect
it|Deseleziona
de|Auswahl aufheben
fr|Désélectionner
es|Deseleccionar

Select for Trash
it|Seleziona per il Cestino
de|Für Papierkorb auswählen
fr|Sélectionner pour la corbeille
es|Seleccionar para la Papelera

Mail attachments and the Trash are hidden until you give CLN Full Disk Access in System Settings. Then quit and reopen CLN and scan again.
it|Gli allegati di Mail e il Cestino restano nascosti finché non dai a CLN l'Accesso completo al disco nelle Impostazioni di Sistema. Poi chiudi e riapri CLN e ripeti la scansione.
de|Mail-Anhänge und der Papierkorb bleiben verborgen, bis du CLN in den Systemeinstellungen vollen Festplattenzugriff gibst. Beende dann CLN, öffne es erneut und scanne noch einmal.
fr|Les pièces jointes de Mail et la corbeille restent masquées tant que vous n'accordez pas à CLN l'accès complet au disque dans Réglages Système. Quittez ensuite CLN, rouvrez-le et relancez l'analyse.
es|Los adjuntos de Mail y la Papelera quedan ocultos hasta que des a CLN acceso total al disco en Ajustes del Sistema. Luego cierra y vuelve a abrir CLN y escanea de nuevo.

Open Settings
it|Apri Impostazioni
de|Einstellungen öffnen
fr|Ouvrir les réglages
es|Abrir Ajustes

Start Over
it|Ricomincia
de|Neu beginnen
fr|Recommencer
es|Empezar de nuevo

Results
it|Risultati
de|Ergebnisse
fr|Résultats
es|Resultados

We found %@ you could clean up.
it|Abbiamo trovato %@ da pulire.
de|Wir haben %@ zum Aufräumen gefunden.
fr|Nous avons trouvé %@ à nettoyer.
es|Encontramos %@ que puedes limpiar.

Your Mac is spotless.
it|Il tuo Mac è pulitissimo.
de|Dein Mac ist blitzsauber.
fr|Votre Mac est impeccable.
es|Tu Mac está impecable.

Recommended items are already selected. Tick or untick a card to include it in Clean All.
it|Gli elementi consigliati sono già selezionati. Seleziona o deseleziona una scheda per includerla in Pulisci tutto.
de|Empfohlene Objekte sind bereits ausgewählt. Hake eine Karte an oder ab, um sie in „Alles bereinigen“ einzubeziehen.
fr|Les éléments recommandés sont déjà sélectionnés. Cochez ou décochez une carte pour l'inclure dans Tout nettoyer.
es|Los elementos recomendados ya están seleccionados. Marca o desmarca una tarjeta para incluirla en Limpiar todo.

Nothing left to clean from this scan.
it|Non c'è altro da pulire in questa scansione.
de|Aus diesem Scan ist nichts mehr zu bereinigen.
fr|Plus rien à nettoyer dans cette analyse.
es|No queda nada por limpiar en este escaneo.

Review All
it|Rivedi tutto
de|Alles prüfen
fr|Tout examiner
es|Revisar todo

Clean All
it|Pulisci tutto
de|Alles bereinigen
fr|Tout nettoyer
es|Limpiar todo

Clean %@ selected items?
it|Pulire %@ elementi selezionati?
de|%@ ausgewählte Objekte bereinigen?
fr|Nettoyer %@ éléments sélectionnés ?
es|¿Limpiar %@ elementos seleccionados?

Empty the Trash permanently?
it|Svuotare definitivamente il Cestino?
de|Papierkorb endgültig leeren?
fr|Vider définitivement la corbeille ?
es|¿Vaciar la Papelera definitivamente?

Clean %@ items from %@?
it|Pulire %1$@ elementi da %2$@?
de|%1$@ Objekte aus %2$@ bereinigen?
fr|Nettoyer %1$@ éléments de %2$@ ?
es|¿Limpiar %1$@ elementos de %2$@?

Empty Trash
it|Svuota Cestino
de|Papierkorb leeren
fr|Vider la corbeille
es|Vaciar Papelera

Clean
it|Pulisci
de|Bereinigen
fr|Nettoyer
es|Limpiar

All %@ in the Trash will be deleted. This can't be undone.
it|Tutti i %@ nel Cestino verranno eliminati. L'operazione non si può annullare.
de|Alle %@ im Papierkorb werden gelöscht. Das kann nicht rückgängig gemacht werden.
fr|Les %@ de la corbeille seront supprimés. Cette action est irréversible.
es|Se eliminarán los %@ de la Papelera. No se puede deshacer.

This frees about %@. Items go to the Trash so you can put them back.
it|Libera circa %@. Gli elementi vanno nel Cestino, così puoi ripristinarli.
de|Das gibt etwa %@ frei. Objekte landen im Papierkorb, du kannst sie also zurücklegen.
fr|Cela libère environ %@. Les éléments vont dans la corbeille, vous pouvez donc les récupérer.
es|Libera unos %@. Los elementos van a la Papelera, así que puedes recuperarlos.

The Trash Bins card is ticked, so the Trash will also be emptied permanently.
it|La scheda Cestini è selezionata, quindi anche il Cestino verrà svuotato definitivamente.
de|Die Karte „Papierkörbe“ ist angehakt, daher wird auch der Papierkorb endgültig geleert.
fr|La carte Corbeilles est cochée : la corbeille sera donc aussi vidée définitivement.
es|La tarjeta Papeleras está marcada, así que la Papelera también se vaciará definitivamente.

Include in Clean All
it|Includi in Pulisci tutto
de|In „Alles bereinigen“ einbeziehen
fr|Inclure dans Tout nettoyer
es|Incluir en Limpiar todo

%@ of %@ removed
it|%1$@ di %2$@ rimossi
de|%1$@ %2$@ entfernt
fr|%1$@ de %2$@ supprimés
es|%1$@ de %2$@ eliminados

%@ of %@ found
it|%1$@ di %2$@ trovati
de|%1$@ %2$@ gefunden
fr|%1$@ de %2$@ trouvés
es|%1$@ de %2$@ encontrados

All clean now.
it|Ora è tutto pulito.
de|Jetzt ist alles sauber.
fr|Tout est propre.
es|Todo limpio.

Done
it|Fatto
de|Fertig
fr|Terminé
es|Listo

None selected
it|Nessuno selezionato
de|Nichts ausgewählt
fr|Aucune sélection
es|Nada seleccionado

%@ selected
it|%@ selezionati
de|%@ ausgewählt
fr|%@ sélectionnés
es|%@ seleccionados

Review
it|Rivedi
de|Prüfen
fr|Examiner
es|Revisar

Empty
it|Svuota
de|Leeren
fr|Vider
es|Vaciar

Auto-Clean
it|Pulizia automatica
de|Auto-Bereinigung
fr|Nettoyage auto
es|Limpieza automática

Cleans recommended System Junk (app caches, logs, Xcode build data) on a schedule, even when CLN is closed. Personal files, AI tools, Mail and the Trash are never touched automatically.
it|Pulisce i file di sistema inutili consigliati (cache delle app, log, dati di build di Xcode) a intervalli regolari, anche quando CLN è chiuso. File personali, strumenti IA, Mail e Cestino non vengono mai toccati automaticamente.
de|Bereinigt empfohlenen Systemmüll (App-Caches, Protokolle, Xcode-Build-Daten) nach Zeitplan, auch wenn CLN geschlossen ist. Persönliche Dateien, KI-Tools, Mail und der Papierkorb werden nie automatisch angerührt.
fr|Nettoie les déchets système recommandés (caches d'apps, journaux, données de build Xcode) selon un calendrier, même quand CLN est fermé. Fichiers personnels, outils d'IA, Mail et corbeille ne sont jamais touchés automatiquement.
es|Limpia la basura del sistema recomendada (cachés de apps, registros, datos de compilación de Xcode) según un horario, incluso con CLN cerrado. Los archivos personales, las herramientas de IA, Mail y la Papelera nunca se tocan automáticamente.

2 weeks
it|2 settimane
de|2 Wochen
fr|2 semaines
es|2 semanas

Next: %@
it|Prossima: %@
de|Nächste: %@
fr|Prochain : %@
es|Próxima: %@

Last auto-clean: %@ · %@ freed
it|Ultima pulizia automatica: %1$@ · %2$@ liberati
de|Letzte Auto-Bereinigung: %1$@ · %2$@ frei
fr|Dernier nettoyage auto : %1$@ · %2$@ libérés
es|Última limpieza automática: %1$@ · %2$@ liberados

Last auto-clean: never
it|Ultima pulizia automatica: mai
de|Letzte Auto-Bereinigung: nie
fr|Dernier nettoyage auto : jamais
es|Última limpieza automática: nunca

never
it|mai
de|nie
fr|jamais
es|nunca

Activity
it|Attività
de|Aktivität
fr|Activité
es|Actividad

since %@
it|dal %@
de|seit %@
fr|depuis le %@
es|desde el %@

ACTIVITY
it|ATTIVITÀ
de|AKTIVITÄT
fr|ACTIVITÉ
es|ACTIVIDAD

Scan
it|Scansiona
de|Scannen
fr|Analyser
es|Escanear

Mac Health
it|Salute del Mac
de|Mac-Zustand
fr|Santé du Mac
es|Salud del Mac

%@ of %@ used
it|%1$@ di %2$@ usati
de|%1$@ von %2$@ belegt
fr|%1$@ sur %2$@ utilisés
es|%1$@ de %2$@ usados

%@ available
it|%@ disponibili
de|%@ verfügbar
fr|%@ disponibles
es|%@ disponibles

Storage Cleaned
it|Spazio liberato
de|Bereinigter Speicher
fr|Espace nettoyé
es|Espacio liberado

Last Cleaned
it|Ultima pulizia
de|Zuletzt bereinigt
fr|Dernier nettoyage
es|Última limpieza

Never
it|Mai
de|Nie
fr|Jamais
es|Nunca

Cleanups
it|Pulizie
de|Bereinigungen
fr|Nettoyages
es|Limpiezas

Items removed
it|Elementi rimossi
de|Entfernte Objekte
fr|Éléments supprimés
es|Elementos eliminados

Tasks run
it|Attività eseguite
de|Ausgeführte Aufgaben
fr|Tâches lancées
es|Tareas ejecutadas

It's time to care for your Mac
it|È ora di prenderti cura del tuo Mac
de|Zeit, deinen Mac zu pflegen
fr|Il est temps de prendre soin de votre Mac
es|Es hora de cuidar tu Mac

Your last cleanup was %@. Run Overview to catch up.
it|L'ultima pulizia risale a %@. Avvia Panoramica per rimetterti in pari.
de|Deine letzte Bereinigung war %@. Starte die Übersicht, um aufzuholen.
fr|Dernier nettoyage : %@. Lancez Vue d'ensemble pour rattraper le retard.
es|Tu última limpieza fue %@. Ejecuta Resumen para ponerte al día.

Run your first scan
it|Fai la tua prima scansione
de|Starte deinen ersten Scan
fr|Lancez votre première analyse
es|Haz tu primer escaneo

Overview checks everything at once in about a minute.
it|Panoramica controlla tutto insieme in circa un minuto.
de|Die Übersicht prüft alles auf einmal, in etwa einer Minute.
fr|Vue d'ensemble vérifie tout en une fois, en une minute environ.
es|Resumen lo revisa todo a la vez en cerca de un minuto.

Your disk is %@ full
it|Il tuo disco è pieno al %@
de|Deine Festplatte ist zu %@ voll
fr|Votre disque est plein à %@
es|Tu disco está al %@

Disk Map shows which folders take the most space.
it|Mappa disco mostra quali cartelle occupano più spazio.
de|Die Speicherkarte zeigt, welche Ordner am meisten Platz belegen.
fr|Carte du disque montre quels dossiers prennent le plus de place.
es|Mapa del disco muestra qué carpetas ocupan más espacio.

Turn on Auto-Clean
it|Attiva la pulizia automatica
de|Auto-Bereinigung einschalten
fr|Activer le nettoyage auto
es|Activa la limpieza automática

Keep junk from piling up without thinking about it.
it|Evita che i file inutili si accumulino, senza pensarci.
de|Lass keinen Müll mehr anwachsen, ganz ohne daran zu denken.
fr|Empêchez les déchets de s'accumuler, sans y penser.
es|Evita que la basura se acumule sin pensar en ello.

Look for duplicates
it|Cerca i duplicati
de|Nach Duplikaten suchen
fr|Chercher les doublons
es|Busca duplicados

File Clutter finds identical copies and big forgotten files.
it|Disordine file trova copie identiche e file grandi dimenticati.
de|Datei-Chaos findet identische Kopien und große vergessene Dateien.
fr|Fouillis de fichiers trouve les copies identiques et les gros fichiers oubliés.
es|Desorden de archivos encuentra copias idénticas y archivos grandes olvidados.

1 Recommendation
it|1 consiglio
de|1 Empfehlung
fr|1 recommandation
es|1 recomendación

%@ Recommendations
it|%@ consigli
de|%@ Empfehlungen
fr|%@ recommandations
es|%@ recomendaciones

Go
it|Vai
de|Los
fr|Aller
es|Ir

Everything looks good.
it|È tutto a posto.
de|Alles sieht gut aus.
fr|Tout va bien.
es|Todo se ve bien.

Looking through your files
it|Controllo dei tuoi file
de|Deine Dateien werden durchsucht
fr|Analyse de vos fichiers
es|Revisando tus archivos

Scanning
it|Scansione
de|Scannt
fr|Analyse
es|Escaneando

Stop
it|Ferma
de|Stopp
fr|Arrêter
es|Detener

Now scanning
it|In scansione
de|Wird gescannt
fr|En cours
es|Escaneando ahora

Preparing…
it|Preparazione…
de|Vorbereitung…
fr|Préparation…
es|Preparando…

files checked
it|file controllati
de|Dateien geprüft
fr|fichiers vérifiés
es|archivos revisados

Examined
it|Esaminati
de|Untersucht
fr|Examinés
es|Examinado

of %@
it|di %@
de|von %@
fr|sur %@
es|de %@

Elapsed
it|Trascorso
de|Vergangen
fr|Écoulé
es|Transcurrido

%@ freed · %@ items cleaned
it|%1$@ liberati · %2$@ elementi puliti
de|%1$@ freigegeben · %2$@ Objekte bereinigt
fr|%1$@ libérés · %2$@ éléments nettoyés
es|%1$@ liberados · %2$@ elementos limpiados

Nothing was cleaned
it|Non è stato pulito nulla
de|Nichts wurde bereinigt
fr|Rien n'a été nettoyé
es|No se limpió nada

Removed items are in the Trash if you need them back.
it|Gli elementi rimossi sono nel Cestino, se ti servono di nuovo.
de|Entfernte Objekte liegen im Papierkorb, falls du sie zurückbrauchst.
fr|Les éléments supprimés sont dans la corbeille si vous en avez besoin.
es|Los elementos eliminados están en la Papelera si los necesitas.

%@ items couldn't be removed.
it|Impossibile rimuovere %@ elementi.
de|%@ Objekte konnten nicht entfernt werden.
fr|%@ éléments n'ont pas pu être supprimés.
es|No se pudieron eliminar %@ elementos.

Hide
it|Nascondi
de|Ausblenden
fr|Masquer
es|Ocultar

Details
it|Dettagli
de|Details
fr|Détails
es|Detalles

Complete
it|Completato
de|Fertig
fr|Terminé
es|Completado

%@ freed
it|%@ liberati
de|%@ freigegeben
fr|%@ libérés
es|%@ liberados

Nothing was removed
it|Non è stato rimosso nulla
de|Nichts wurde entfernt
fr|Rien n'a été supprimé
es|No se eliminó nada

Home Folder
it|Cartella Inizio
de|Benutzerordner
fr|Dossier de départ
es|Carpeta de inicio

Entire Disk (Macintosh HD)
it|Intero disco (Macintosh HD)
de|Ganze Festplatte (Macintosh HD)
fr|Disque entier (Macintosh HD)
es|Disco completo (Macintosh HD)

Choose Folder…
it|Scegli cartella…
de|Ordner wählen…
fr|Choisir un dossier…
es|Elegir carpeta…

Scan location
it|Posizione di scansione
de|Scan-Ort
fr|Emplacement analysé
es|Ubicación del escaneo

Nothing left to review here.
it|Non c'è altro da rivedere qui.
de|Hier gibt es nichts mehr zu prüfen.
fr|Plus rien à examiner ici.
es|No queda nada por revisar aquí.

This frees %@. Until you empty the Trash, you can put items back.
it|Libera %@. Finché non svuoti il Cestino, puoi ripristinare gli elementi.
de|Das gibt %@ frei. Bis du den Papierkorb leerst, kannst du Objekte zurücklegen.
fr|Cela libère %@. Tant que vous ne videz pas la corbeille, vous pouvez récupérer les éléments.
es|Libera %@. Hasta que vacíes la Papelera, puedes recuperar los elementos.

Search
it|Cerca
de|Suchen
fr|Rechercher
es|Buscar

Sort by
it|Ordina per
de|Sortieren nach
fr|Trier par
es|Ordenar por

Select
it|Seleziona
de|Auswahl
fr|Sélection
es|Seleccionar

None
it|Nessuno
de|Keine
fr|Aucun
es|Ninguno

All
it|Tutti
de|Alle
fr|Tous
es|Todos

%@ items · %@
it|%1$@ elementi · %2$@
de|%1$@ Objekte · %2$@
fr|%1$@ éléments · %2$@
es|%1$@ elementos · %2$@

Clean Up
it|Pulisci
de|Bereinigen
fr|Nettoyer
es|Limpiar

Maintenance
it|Manutenzione
de|Wartung
fr|Maintenance
es|Mantenimiento

Login Items
it|Elementi login
de|Anmeldeobjekte
fr|Éléments de connexion
es|Ítems de inicio

Background Items
it|Elementi in background
de|Hintergrundobjekte
fr|Éléments en arrière-plan
es|Ítems en segundo plano

Last maintenance
it|Ultima manutenzione
de|Letzte Wartung
fr|Dernière maintenance
es|Último mantenimiento

Remove %@?
it|Rimuovere %@?
de|%@ entfernen?
fr|Supprimer %@ ?
es|¿Eliminar %@?

Remove
it|Rimuovi
de|Entfernen
fr|Supprimer
es|Eliminar

It stops now and won't start at login. Its file goes to the Trash, so you can put it back.
it|Si ferma subito e non partirà al login. Il suo file va nel Cestino, così puoi ripristinarlo.
de|Es stoppt sofort und startet nicht mehr bei der Anmeldung. Die Datei landet im Papierkorb, du kannst sie also zurücklegen.
fr|Il s'arrête immédiatement et ne se lancera plus à la connexion. Son fichier va dans la corbeille, vous pouvez donc le récupérer.
es|Se detiene ahora y no se abrirá al iniciar sesión. Su archivo va a la Papelera, así que puedes recuperarlo.

Asks for password
it|Richiede la password
de|Fragt nach Passwort
fr|Demande le mot de passe
es|Pide contraseña

Last run
it|Ultima esecuzione
de|Zuletzt ausgeführt
fr|Dernière exécution
es|Última ejecución

Run
it|Esegui
de|Ausführen
fr|Lancer
es|Ejecutar

Startup agents installed for your account. Items marked Broken point to programs that no longer exist.
it|Agenti di avvio installati per il tuo account. Gli elementi segnati come Rotto puntano a programmi che non esistono più.
de|Startagenten für deinen Account. Als „Defekt“ markierte Objekte verweisen auf Programme, die es nicht mehr gibt.
fr|Agents de démarrage installés pour votre compte. Les éléments marqués Cassé pointent vers des programmes qui n'existent plus.
es|Agentes de inicio instalados en tu cuenta. Los marcados como Roto apuntan a programas que ya no existen.

Open Login Items Settings
it|Apri impostazioni Elementi login
de|Anmeldeobjekte-Einstellungen öffnen
fr|Ouvrir les réglages des éléments de connexion
es|Abrir ajustes de ítems de inicio

No startup agents in your account.
it|Nessun agente di avvio nel tuo account.
de|Keine Startagenten in deinem Account.
fr|Aucun agent de démarrage dans votre compte.
es|No hay agentes de inicio en tu cuenta.

Broken
it|Rotto
de|Defekt
fr|Cassé
es|Roto

System-wide
it|Per tutto il sistema
de|Systemweit
fr|Tout le système
es|Todo el sistema

Overview
it|Panoramica
de|Übersicht
fr|Vue d'ensemble
es|Resumen

System Junk
it|File di sistema
de|Systemmüll
fr|Déchets système
es|Basura del sistema

Speed
it|Velocità
de|Tempo
fr|Vitesse
es|Velocidad

Apps
it|App
de|Apps
fr|Apps
es|Apps

File Clutter
it|Disordine file
de|Datei-Chaos
fr|Fouillis de fichiers
es|Desorden de archivos

Disk Map
it|Mappa disco
de|Speicherkarte
fr|Carte du disque
es|Mapa del disco

Every scan at once. Review what was found, then clean it all in one go.
it|Tutte le scansioni insieme. Rivedi cosa è stato trovato, poi pulisci tutto in un colpo.
de|Alle Scans auf einmal. Prüfe die Funde und bereinige dann alles in einem Rutsch.
fr|Toutes les analyses à la fois. Examinez les résultats, puis nettoyez tout d'un coup.
es|Todos los escaneos a la vez. Revisa lo encontrado y límpialo todo de una vez.

Clear caches, logs and developer leftovers that quietly pile up.
it|Elimina cache, log e residui di sviluppo che si accumulano in silenzio.
de|Entferne Caches, Protokolle und Entwicklerreste, die sich still ansammeln.
fr|Supprimez caches, journaux et restes de développement qui s'accumulent en silence.
es|Elimina cachés, registros y restos de desarrollo que se acumulan sin hacer ruido.

Run maintenance tasks and decide what starts with your Mac.
it|Esegui la manutenzione e decidi cosa si avvia con il Mac.
de|Führe Wartungsaufgaben aus und entscheide, was mit deinem Mac startet.
fr|Lancez la maintenance et choisissez ce qui démarre avec votre Mac.
es|Ejecuta tareas de mantenimiento y decide qué se abre con tu Mac.

Remove apps completely, along with the files they leave behind.
it|Rimuovi le app completamente, insieme ai file che lasciano.
de|Entferne Apps vollständig, samt den Dateien, die sie zurücklassen.
fr|Supprimez complètement les apps, avec les fichiers qu'elles laissent derrière elles.
es|Elimina apps por completo, junto con los archivos que dejan atrás.

Find big, old and duplicate files hiding in your folders.
it|Trova file grandi, vecchi e duplicati nascosti nelle tue cartelle.
de|Finde große, alte und doppelte Dateien in deinen Ordnern.
fr|Trouvez les fichiers volumineux, anciens et en double cachés dans vos dossiers.
es|Encuentra archivos grandes, antiguos y duplicados escondidos en tus carpetas.

See exactly what is taking up your disk, folder by folder.
it|Scopri cosa occupa il disco, cartella per cartella.
de|Sieh genau, was deine Festplatte belegt, Ordner für Ordner.
fr|Voyez précisément ce qui occupe votre disque, dossier par dossier.
es|Mira exactamente qué ocupa tu disco, carpeta por carpeta.

What CLN has done for your Mac so far.
it|Cosa ha fatto CLN per il tuo Mac finora.
de|Was CLN bisher für deinen Mac getan hat.
fr|Ce que CLN a fait pour votre Mac jusqu'ici.
es|Lo que CLN ha hecho por tu Mac hasta ahora.

System & AI Junk
it|File inutili di sistema e IA
de|System- & KI-Müll
fr|Déchets système et IA
es|Basura del sistema e IA

Old Downloads
it|Vecchi download
de|Alte Downloads
fr|Anciens téléchargements
es|Descargas antiguas

App Leftovers
it|Residui delle app
de|App-Reste
fr|Restes d'apps
es|Restos de apps

Broken Startup Items
it|Elementi di avvio rotti
de|Defekte Startobjekte
fr|Éléments de démarrage cassés
es|Ítems de inicio rotos

Caches, Logs & Developer Junk
it|Cache, log e residui di sviluppo
de|Caches, Protokolle & Entwicklerreste
fr|Caches, journaux et restes de dev
es|Cachés, registros y restos de desarrollo

AI Clutter
it|Disordine IA
de|KI-Chaos
fr|Fouillis IA
es|Desorden de IA

Mail Attachments
it|Allegati di Mail
de|Mail-Anhänge
fr|Pièces jointes Mail
es|Adjuntos de Mail

Trash Bins
it|Cestini
de|Papierkörbe
fr|Corbeilles
es|Papeleras

Maintenance Tasks
it|Attività di manutenzione
de|Wartungsaufgaben
fr|Tâches de maintenance
es|Tareas de mantenimiento

Full Uninstall
it|Disinstallazione completa
de|Vollständige Deinstallation
fr|Désinstallation complète
es|Desinstalación completa

Leftover Files
it|File residui
de|Restdateien
fr|Fichiers restants
es|Archivos sobrantes

Orphaned Data
it|Dati orfani
de|Verwaiste Daten
fr|Données orphelines
es|Datos huérfanos

Large Files
it|File grandi
de|Große Dateien
fr|Gros fichiers
es|Archivos grandes

Old Files
it|File vecchi
de|Alte Dateien
fr|Anciens fichiers
es|Archivos antiguos

Duplicates
it|Duplicati
de|Duplikate
fr|Doublons
es|Duplicados

Downloads
it|Download
de|Downloads
fr|Téléchargements
es|Descargas

Storage Map
it|Mappa dello spazio
de|Speicherkarte
fr|Carte du stockage
es|Mapa del almacenamiento

Hidden Files Included
it|File nascosti inclusi
de|Inklusive versteckter Dateien
fr|Fichiers cachés inclus
es|Archivos ocultos incluidos

Largest Folders First
it|Cartelle più grandi prima
de|Größte Ordner zuerst
fr|Plus gros dossiers d'abord
es|Carpetas más grandes primero

Caches, logs and developer leftovers that apps rebuild on their own.
it|Cache, log e residui di sviluppo che le app ricreano da sole.
de|Caches, Protokolle und Entwicklerreste, die Apps selbst neu erstellen.
fr|Caches, journaux et restes de développement que les apps recréent d'elles-mêmes.
es|Cachés, registros y restos de desarrollo que las apps vuelven a crear solas.

Caches, logs and downloaded models from AI tools like Claude, Codex, Cursor and Ollama.
it|Cache, log e modelli scaricati da strumenti IA come Claude, Codex, Cursor e Ollama.
de|Caches, Protokolle und geladene Modelle von KI-Tools wie Claude, Codex, Cursor und Ollama.
fr|Caches, journaux et modèles téléchargés d'outils d'IA comme Claude, Codex, Cursor et Ollama.
es|Cachés, registros y modelos descargados de herramientas de IA como Claude, Codex, Cursor y Ollama.

Attachments Mail saved when you opened them. They stay in your mailbox.
it|Allegati salvati da Mail quando li hai aperti. Restano nella tua casella.
de|Anhänge, die Mail beim Öffnen gespeichert hat. Sie bleiben in deinem Postfach.
fr|Pièces jointes enregistrées par Mail à l'ouverture. Elles restent dans votre boîte aux lettres.
es|Adjuntos que Mail guardó al abrirlos. Siguen en tu buzón.

Files already in your Trash. Cleaning empties it permanently.
it|File già nel Cestino. La pulizia lo svuota definitivamente.
de|Dateien, die schon im Papierkorb liegen. Bereinigen leert ihn endgültig.
fr|Fichiers déjà dans la corbeille. Le nettoyage la vide définitivement.
es|Archivos que ya están en la Papelera. Limpiar la vacía definitivamente.

Downloads you haven't touched in over 3 months.
it|Download che non tocchi da più di 3 mesi.
de|Downloads, die du seit über 3 Monaten nicht angerührt hast.
fr|Téléchargements non utilisés depuis plus de 3 mois.
es|Descargas que no tocas desde hace más de 3 meses.

Support files left behind by apps that are no longer installed.
it|File di supporto lasciati da app non più installate.
de|Hilfsdateien von Apps, die nicht mehr installiert sind.
fr|Fichiers de support laissés par des apps désinstallées.
es|Archivos de soporte que dejaron apps ya desinstaladas.

Startup items pointing to programs that no longer exist.
it|Elementi di avvio che puntano a programmi che non esistono più.
de|Startobjekte, die auf Programme verweisen, die es nicht mehr gibt.
fr|Éléments de démarrage pointant vers des programmes qui n'existent plus.
es|Ítems de inicio que apuntan a programas que ya no existen.

Files of 100 MB or more.
it|File da 100 MB in su.
de|Dateien ab 100 MB.
fr|Fichiers de 100 Mo ou plus.
es|Archivos de 100 MB o más.

Files of 10 MB or more not changed for over a year.
it|File da 10 MB in su non modificati da oltre un anno.
de|Dateien ab 10 MB, seit über einem Jahr unverändert.
fr|Fichiers de 10 Mo ou plus inchangés depuis plus d'un an.
es|Archivos de 10 MB o más sin cambios desde hace más de un año.

Identical copies. The oldest copy is kept and never listed.
it|Copie identiche. La copia più vecchia viene tenuta e non compare nell'elenco.
de|Identische Kopien. Die älteste Kopie bleibt erhalten und wird nicht aufgelistet.
fr|Copies identiques. La plus ancienne est conservée et n'apparaît pas dans la liste.
es|Copias idénticas. Se conserva la copia más antigua y no aparece en la lista.

Everything in your Downloads folder.
it|Tutto il contenuto della cartella Download.
de|Alles in deinem Downloads-Ordner.
fr|Tout le contenu de votre dossier Téléchargements.
es|Todo lo que hay en tu carpeta Descargas.

Off
it|Off
de|Aus
fr|Non
es|No

Daily
it|Giornaliera
de|Täglich
fr|Quotidien
es|Diario

Weekly
it|Settimanale
de|Wöchentlich
fr|Hebdo
es|Semanal

Every 2 weeks
it|Ogni 2 settimane
de|Alle 2 Wochen
fr|Toutes les 2 semaines
es|Cada 2 semanas

Monthly
it|Mensile
de|Monatlich
fr|Mensuel
es|Mensual

User Cache Files
it|File cache utente
de|Benutzer-Cache-Dateien
fr|Fichiers de cache utilisateur
es|Archivos de caché del usuario

Temporary data apps rebuild automatically. Apple's own caches are listed but not selected.
it|Dati temporanei che le app ricreano da sole. Le cache di Apple sono elencate ma non selezionate.
de|Temporäre Daten, die Apps selbst neu erstellen. Apples eigene Caches werden gelistet, aber nicht ausgewählt.
fr|Données temporaires que les apps recréent d'elles-mêmes. Les caches d'Apple sont listés mais pas sélectionnés.
es|Datos temporales que las apps vuelven a crear solas. Las cachés de Apple aparecen pero no se seleccionan.

User Logs
it|Log utente
de|Benutzerprotokolle
fr|Journaux utilisateur
es|Registros del usuario

Diagnostic logs written by apps.
it|Log diagnostici scritti dalle app.
de|Diagnoseprotokolle von Apps.
fr|Journaux de diagnostic écrits par les apps.
es|Registros de diagnóstico escritos por las apps.

Developer Junk
it|Residui di sviluppo
de|Entwicklerreste
fr|Restes de développement
es|Restos de desarrollo

Xcode build products and simulator caches.
it|Prodotti di build di Xcode e cache del simulatore.
de|Xcode-Build-Produkte und Simulator-Caches.
fr|Produits de build Xcode et caches du simulateur.
es|Productos de compilación de Xcode y cachés del simulador.

Package Caches
it|Cache dei pacchetti
de|Paket-Caches
fr|Caches de paquets
es|Cachés de paquetes

Downloaded packages that tools fetch again when needed.
it|Pacchetti scaricati che gli strumenti riscaricano quando servono.
de|Geladene Pakete, die Tools bei Bedarf neu holen.
fr|Paquets téléchargés que les outils récupèrent à nouveau si besoin.
es|Paquetes descargados que las herramientas vuelven a bajar cuando hace falta.

Mail Downloads
it|Download di Mail
de|Mail-Downloads
fr|Téléchargements Mail
es|Descargas de Mail

Copies of attachments you opened. The originals stay in your mailbox.
it|Copie degli allegati che hai aperto. Gli originali restano nella tua casella.
de|Kopien von Anhängen, die du geöffnet hast. Die Originale bleiben in deinem Postfach.
fr|Copies des pièces jointes ouvertes. Les originaux restent dans votre boîte aux lettres.
es|Copias de adjuntos que abriste. Los originales siguen en tu buzón.

Trash
it|Cestino
de|Papierkorb
fr|Corbeille
es|Papelera

Emptying the Trash deletes these files permanently.
it|Svuotando il Cestino questi file vengono eliminati definitivamente.
de|Wenn du den Papierkorb leerst, werden diese Dateien endgültig gelöscht.
fr|Vider la corbeille supprime définitivement ces fichiers.
es|Vaciar la Papelera elimina estos archivos definitivamente.

AI Junk Files
it|File inutili IA
de|KI-Müll
fr|Déchets IA
es|Basura de IA

Caches, logs and temporary files from AI tools. Nothing here is selected until you choose.
it|Cache, log e file temporanei degli strumenti IA. Qui nulla è selezionato finché non scegli tu.
de|Caches, Protokolle und temporäre Dateien von KI-Tools. Hier ist nichts ausgewählt, bis du entscheidest.
fr|Caches, journaux et fichiers temporaires des outils d'IA. Rien n'est sélectionné tant que vous ne choisissez pas.
es|Cachés, registros y archivos temporales de herramientas de IA. Aquí no se selecciona nada hasta que tú elijas.

App caches
it|Cache delle app
de|App-Caches
fr|Caches d'apps
es|Cachés de apps

Log files
it|File di log
de|Protokolldateien
fr|Fichiers journaux
es|Archivos de registro

Developer leftovers
it|Residui di sviluppo
de|Entwicklerreste
fr|Restes de développement
es|Restos de desarrollo

Package manager caches
it|Cache dei gestori di pacchetti
de|Paketmanager-Caches
fr|Caches des gestionnaires de paquets
es|Cachés de gestores de paquetes

AI tools
it|Strumenti IA
de|KI-Tools
fr|Outils d'IA
es|Herramientas de IA

Mail attachments
it|Allegati di Mail
de|Mail-Anhänge
fr|Pièces jointes Mail
es|Adjuntos de Mail

The Trash
it|Il Cestino
de|Papierkorb
fr|La corbeille
es|La Papelera

Orphaned Leftovers
it|Residui orfani
de|Verwaiste Reste
fr|Restes orphelins
es|Restos huérfanos

Files from apps that are no longer installed. Check each one before removing it.
it|File di app non più installate. Controllali uno per uno prima di rimuoverli.
de|Dateien von nicht mehr installierten Apps. Prüfe jede einzeln, bevor du sie entfernst.
fr|Fichiers d'apps désinstallées. Vérifiez-les un par un avant de les supprimer.
es|Archivos de apps ya desinstaladas. Revisa cada uno antes de eliminarlo.

Leftovers of removed apps
it|Residui di app rimosse
de|Reste entfernter Apps
fr|Restes d'apps supprimées
es|Restos de apps eliminadas

Comparing files for duplicates
it|Confronto dei file per i duplicati
de|Dateien werden auf Duplikate verglichen
fr|Comparaison des fichiers en double
es|Comparando archivos en busca de duplicados

Broken Login Items
it|Elementi login rotti
de|Defekte Anmeldeobjekte
fr|Éléments de connexion cassés
es|Ítems de inicio rotos

Old downloads
it|Vecchi download
de|Alte Downloads
fr|Anciens téléchargements
es|Descargas antiguas

Startup items
it|Elementi di avvio
de|Startobjekte
fr|Éléments de démarrage
es|Ítems de inicio

Size
it|Dimensione
de|Größe
fr|Taille
es|Tamaño

Name
it|Nome
de|Name
fr|Nom
es|Nombre

Date
it|Data
de|Datum
fr|Date
es|Fecha

Good
it|Buona
de|Gut
fr|Bonne
es|Buena

Fair
it|Discreta
de|Mittel
fr|Moyenne
es|Regular

Poor
it|Scarsa
de|Schlecht
fr|Mauvaise
es|Mala

Desktop
it|Scrivania
de|Schreibtisch
fr|Bureau
es|Escritorio

Documents
it|Documenti
de|Dokumente
fr|Documents
es|Documentos

Movies
it|Filmati
de|Filme
fr|Vidéos
es|Películas

Pictures
it|Immagini
de|Bilder
fr|Images
es|Imágenes

Starting
it|Avvio
de|Start
fr|Démarrage
es|Iniciando

Reading startup items
it|Lettura degli elementi di avvio
de|Startobjekte werden gelesen
fr|Lecture des éléments de démarrage
es|Leyendo ítems de inicio

Moving items to the Trash
it|Spostamento nel Cestino
de|Objekte werden in den Papierkorb gelegt
fr|Placement dans la corbeille
es|Moviendo a la Papelera

Emptying the Trash
it|Svuotamento del Cestino
de|Papierkorb wird geleert
fr|Vidage de la corbeille
es|Vaciando la Papelera

Language
it|Lingua
de|Sprache
fr|Langue
es|Idioma

Enjoying CLN?
it|Ti piace CLN?
de|Gefällt dir CLN?
fr|Vous aimez CLN ?
es|¿Te gusta CLN?

A small tip keeps the updates coming.
it|Una piccola mancia aiuta a portare nuovi aggiornamenti.
de|Ein kleines Trinkgeld hält die Updates am Laufen.
fr|Un petit pourboire aide à faire vivre les mises à jour.
es|Una pequeña propina mantiene vivas las actualizaciones.

Last cleaned
it|Ultima pulizia
de|Zuletzt bereinigt
fr|Dernier nettoyage
es|Última limpieza

never cleaned
it|mai pulito
de|nie bereinigt
fr|jamais nettoyé
es|nunca limpiado

Trash emptied.
it|Cestino svuotato.
de|Papierkorb geleert.
fr|Corbeille vidée.
es|Papelera vaciada.

Couldn't empty the Trash.
it|Impossibile svuotare il Cestino.
de|Papierkorb konnte nicht geleert werden.
fr|Impossible de vider la corbeille.
es|No se pudo vaciar la Papelera.

This permanently deletes everything in the Trash, including anything you put there yourself. It can't be undone.
it|Elimina definitivamente tutto ciò che è nel Cestino, compreso quello che ci hai messo tu. L'operazione non si può annullare.
de|Das löscht alles im Papierkorb endgültig, auch was du selbst hineingelegt hast. Das kann nicht rückgängig gemacht werden.
fr|Cela supprime définitivement tout le contenu de la corbeille, y compris ce que vous y avez mis vous-même. Action irréversible.
es|Elimina definitivamente todo lo que hay en la Papelera, incluido lo que pusiste tú. No se puede deshacer.

About · Privacy · Terms
it|Info · Privacy · Termini
de|Info · Datenschutz · Bedingungen
fr|À propos · Confidentialité · Conditions
es|Acerca de · Privacidad · Términos

Close
it|Chiudi
de|Schließen
fr|Fermer
es|Cerrar

CLN is free, works entirely on your Mac and collects no data.
it|CLN è gratuito, funziona interamente sul tuo Mac e non raccoglie dati.
de|CLN ist kostenlos, läuft komplett auf deinem Mac und sammelt keine Daten.
fr|CLN est gratuit, fonctionne entièrement sur votre Mac et ne collecte aucune donnée.
es|CLN es gratis, funciona por completo en tu Mac y no recopila datos.

The legal text is provided in English.
it|Il testo legale è disponibile in inglese.
de|Der Rechtstext ist auf Englisch verfügbar.
fr|Le texte juridique est fourni en anglais.
es|El texto legal se ofrece en inglés.

Before you start
it|Prima di iniziare
de|Bevor du loslegst
fr|Avant de commencer
es|Antes de empezar

Welcome to CLN
it|Benvenuto in CLN
de|Willkommen bei CLN
fr|Bienvenue dans CLN
es|Te damos la bienvenida a CLN

CLN is freeware: free to use, with no ads or subscriptions.
it|CLN è freeware: gratuito, senza pubblicità né abbonamenti.
de|CLN ist Freeware: kostenlos, ohne Werbung und ohne Abo.
fr|CLN est un freeware : gratuit, sans publicité ni abonnement.
es|CLN es freeware: gratis, sin anuncios ni suscripciones.

Your data stays on your Mac. CLN collects and sends nothing.
it|I tuoi dati restano sul tuo Mac. CLN non raccoglie né invia nulla.
de|Deine Daten bleiben auf deinem Mac. CLN sammelt und sendet nichts.
fr|Vos données restent sur votre Mac. CLN ne collecte et n'envoie rien.
es|Tus datos se quedan en tu Mac. CLN no recopila ni envía nada.

Cleaned items go to the Trash first. Review them and keep a backup.
it|Gli elementi puliti finiscono prima nel Cestino. Controllali e tieni un backup.
de|Bereinigte Objekte landen zuerst im Papierkorb. Prüfe sie und halte ein Backup bereit.
fr|Les éléments nettoyés vont d'abord dans la corbeille. Vérifiez-les et gardez une sauvegarde.
es|Los elementos limpiados van primero a la Papelera. Revísalos y ten una copia de seguridad.

CLN is provided as is, without warranty. You use it at your own risk.
it|CLN è fornito così com'è, senza garanzia. Lo usi a tuo rischio.
de|CLN wird ohne Gewähr bereitgestellt. Die Nutzung erfolgt auf eigenes Risiko.
fr|CLN est fourni tel quel, sans garantie. Vous l'utilisez à vos propres risques.
es|CLN se ofrece tal cual, sin garantía. Lo usas bajo tu propia responsabilidad.

Read full terms
it|Leggi i termini completi
de|Vollständige Bedingungen lesen
fr|Lire les conditions complètes
es|Leer los términos completos

Agree & Continue
it|Accetta e continua
de|Zustimmen & weiter
fr|Accepter et continuer
es|Aceptar y continuar

Cleaned items go to the Trash first. Review them before deleting.
it|Gli elementi puliti finiscono prima nel Cestino. Controllali prima di eliminarli.
de|Bereinigte Objekte landen zuerst im Papierkorb. Prüfe sie, bevor du sie löschst.
fr|Les éléments nettoyés vont d'abord dans la corbeille. Vérifiez-les avant de les supprimer.
es|Los elementos limpiados van primero a la Papelera. Revísalos antes de eliminarlos.

By using this app, you agree to the Terms & Conditions.
it|Usando questa app accetti i Termini e condizioni.
de|Mit der Nutzung dieser App stimmst du den Nutzungsbedingungen zu.
fr|En utilisant cette app, vous acceptez les Conditions générales.
es|Al usar esta app, aceptas los Términos y condiciones.

Privacy · Terms
it|Privacy · Termini
de|Datenschutz · Bedingungen
fr|Confidentialité · Conditions
es|Privacidad · Términos

A tip keeps apps like this coming.
it|Una mancia aiuta a far nascere altre app come questa.
de|Ein Trinkgeld sorgt für mehr Apps wie diese.
fr|Un pourboire aide à créer d'autres apps comme celle-ci.
es|Una propina ayuda a que lleguen más apps como esta.

Update Check
it|Controllo aggiornamenti
de|Update-Prüfung
fr|Recherche de mises à jour
es|Buscar actualizaciones

Check for Updates
it|Cerca aggiornamenti
de|Nach Updates suchen
fr|Rechercher les mises à jour
es|Buscar actualizaciones

Checking for updates…
it|Ricerca aggiornamenti…
de|Suche nach Updates…
fr|Recherche des mises à jour…
es|Buscando actualizaciones…

All apps are up to date.
it|Tutte le app sono aggiornate.
de|Alle Apps sind aktuell.
fr|Toutes les apps sont à jour.
es|Todas las apps están actualizadas.

%@ updates available
it|%@ aggiornamenti disponibili
de|%@ Updates verfügbar
fr|%@ mises à jour disponibles
es|%@ actualizaciones disponibles

Checked %@ apps from the App Store and developer update feeds. Apps that update another way aren't listed.
it|Controllate %@ app tramite App Store e feed degli sviluppatori. Le app che si aggiornano in altro modo non sono elencate.
de|%@ Apps über den App Store und Update-Feeds der Entwickler geprüft. Apps, die sich anders aktualisieren, sind nicht aufgeführt.
fr|%@ apps vérifiées via l'App Store et les flux de mise à jour des développeurs. Les apps mises à jour autrement ne sont pas listées.
es|Se revisaron %@ apps desde la App Store y los canales de actualización de los desarrolladores. Las apps que se actualizan de otra forma no aparecen.

Only app identifiers are sent; nothing about you or your files.
it|Vengono inviati solo gli identificativi delle app, niente su di te o sui tuoi file.
de|Es werden nur App-Kennungen gesendet, nichts über dich oder deine Dateien.
fr|Seuls les identifiants des apps sont envoyés, rien sur vous ni vos fichiers.
es|Solo se envían los identificadores de las apps, nada sobre ti ni tus archivos.

Developer
it|Sviluppatore
de|Entwickler
fr|Développeur
es|Desarrollador

Open App Store
it|Apri App Store
de|App Store öffnen
fr|Ouvrir l'App Store
es|Abrir App Store

Open App
it|Apri app
de|App öffnen
fr|Ouvrir l'app
es|Abrir app

Update %@
it|Aggiorna a %@
de|Update auf %@
fr|Mettre à jour (%@)
es|Actualizar a %@

%@ left that wasn't selected.
it|Restano %@ non selezionati.
de|%@ übrig, die nicht ausgewählt waren.
fr|Il reste %@ non sélectionnés.
es|Quedan %@ sin seleccionar.

Leave a tip
it|Lascia una mancia
de|Trinkgeld geben
fr|Laisser un pourboire
es|Dejar una propina

Uninstall
it|Disinstalla
de|Deinstallieren
fr|Désinstaller
es|Desinstalar

Remove
it|Rimuovi
de|Entfernen
fr|Supprimer
es|Eliminar

Uninstall %@?
it|Disinstallare %@?
de|%@ deinstallieren?
fr|Désinstaller %@ ?
es|¿Desinstalar %@?

Uninstall %@ apps?
it|Disinstallare %@ app?
de|%@ Apps deinstallieren?
fr|Désinstaller %@ apps ?
es|¿Desinstalar %@ apps?

The apps and the leftover files you selected (%@) go to the Trash. Open apps are quit first. Until you empty the Trash, you can put them back.
it|Le app e i file residui selezionati (%@) vanno nel Cestino. Le app aperte vengono chiuse prima. Finché non svuoti il Cestino, puoi ripristinarle.
de|Die ausgewählten Apps und Restdateien (%@) kommen in den Papierkorb. Offene Apps werden vorher beendet. Bis du den Papierkorb leerst, kannst du sie zurücklegen.
fr|Les apps et fichiers restants sélectionnés (%@) vont dans la corbeille. Les apps ouvertes sont d'abord quittées. Tant que la corbeille n'est pas vidée, vous pouvez les remettre.
es|Las apps y los archivos sobrantes seleccionados (%@) van a la Papelera. Las apps abiertas se cierran antes. Hasta que vacíes la Papelera, puedes recuperarlas.

%@ and all %@ of its files (%@) go to the Trash. If it's open, it is quit first. Until you empty the Trash, you can put them back.
it|%@ e tutti i suoi %@ file (%@) vanno nel Cestino. Se è aperta, viene chiusa prima. Finché non svuoti il Cestino, puoi ripristinarli.
de|%@ und alle %@ zugehörigen Dateien (%@) kommen in den Papierkorb. Ist die App offen, wird sie vorher beendet. Bis du den Papierkorb leerst, kannst du sie zurücklegen.
fr|%@ et ses %@ fichiers (%@) vont dans la corbeille. Si l'app est ouverte, elle est d'abord quittée. Tant que la corbeille n'est pas vidée, vous pouvez les remettre.
es|%@ y sus %@ archivos (%@) van a la Papelera. Si está abierta, se cierra antes. Hasta que vacíes la Papelera, puedes recuperarlos.

Removes the app and everything it left on your Mac
it|Rimuove l'app e tutto ciò che ha lasciato sul Mac
de|Entfernt die App und alles, was sie auf dem Mac hinterlassen hat
fr|Supprime l'app et tout ce qu'elle a laissé sur le Mac
es|Elimina la app y todo lo que dejó en el Mac

Uninstalling removes the app and the files below: settings, caches, containers, logs and helpers that stay behind when you only drag an app to the Trash.
it|Disinstallare rimuove l'app e i file qui sotto: impostazioni, cache, contenitori, log e helper che restano se trascini solo l'app nel Cestino.
de|Deinstallieren entfernt die App und die Dateien unten: Einstellungen, Caches, Container, Protokolle und Helfer, die bleiben, wenn du nur die App in den Papierkorb ziehst.
fr|Désinstaller supprime l'app et les fichiers ci-dessous : réglages, caches, conteneurs, journaux et assistants qui restent si vous glissez seulement l'app dans la corbeille.
es|Desinstalar elimina la app y los archivos de abajo: ajustes, cachés, contenedores, registros y ayudantes que quedan si solo arrastras la app a la Papelera.

%@ items need your permission
it|%@ elementi richiedono il tuo permesso
de|%@ Objekte brauchen deine Erlaubnis
fr|%@ éléments nécessitent votre autorisation
es|%@ elementos necesitan tu permiso

macOS protects the data folders of other apps. To remove them: 1. Open Settings and turn on CLN under Full Disk Access. 2. Come back and click Try Again.
it|macOS protegge le cartelle dati delle altre app. Per rimuoverle: 1. Apri Impostazioni e attiva CLN in Accesso completo al disco. 2. Torna qui e fai clic su Riprova.
de|macOS schützt die Datenordner anderer Apps. So entfernst du sie: 1. Öffne die Einstellungen und aktiviere CLN unter Festplattenvollzugriff. 2. Komm zurück und klicke auf Erneut versuchen.
fr|macOS protège les dossiers de données des autres apps. Pour les supprimer : 1. Ouvrez Réglages et activez CLN dans Accès complet au disque. 2. Revenez et cliquez sur Réessayer.
es|macOS protege las carpetas de datos de otras apps. Para eliminarlas: 1. Abre Ajustes y activa CLN en Acceso total al disco. 2. Vuelve y haz clic en Reintentar.

Open Settings
it|Apri Impostazioni
de|Einstellungen öffnen
fr|Ouvrir Réglages
es|Abrir Ajustes

Try Again
it|Riprova
de|Erneut versuchen
fr|Réessayer
es|Reintentar

Done: %@ more removed.
it|Fatto: rimossi altri %@.
de|Fertig: weitere %@ entfernt.
fr|Terminé : %@ de plus supprimés.
es|Listo: %@ más eliminados.

Quitting apps…
it|Chiusura delle app…
de|Apps werden beendet…
fr|Fermeture des apps…
es|Cerrando apps…

Move All to Trash
it|Sposta tutto nel Cestino
de|Alles in den Papierkorb
fr|Tout placer dans la corbeille
es|Mover todo a la Papelera

Turn Off
it|Disattiva
de|Ausschalten
fr|Désactiver
es|Desactivar

Turn On
it|Attiva
de|Einschalten
fr|Activer
es|Activar

Running
it|In esecuzione
de|Läuft
fr|En cours
es|En ejecución

Waiting
it|In attesa
de|Wartet
fr|En attente
es|En espera

Not loaded
it|Non caricato
de|Nicht geladen
fr|Non chargé
es|No cargado

From %@
it|Da %@
de|Von %@
fr|De %@
es|De %@

Running now (process %@)
it|In esecuzione ora (processo %@)
de|Läuft gerade (Prozess %@)
fr|En cours (processus %@)
es|En ejecución (proceso %@)

Loaded; starts when needed
it|Caricato; parte quando serve
de|Geladen; startet bei Bedarf
fr|Chargé ; démarre si nécessaire
es|Cargado; se inicia cuando hace falta

It stops now and won't start again. Its file goes to the Trash, so you can put it back.
it|Si ferma subito e non ripartirà. Il suo file va nel Cestino, così puoi ripristinarlo.
de|Es stoppt sofort und startet nicht wieder. Die Datei kommt in den Papierkorb, du kannst sie zurücklegen.
fr|Il s'arrête maintenant et ne redémarrera pas. Son fichier va dans la corbeille, vous pouvez le remettre.
es|Se detiene ahora y no volverá a iniciarse. Su archivo va a la Papelera, así que puedes recuperarlo.

%@ may stop working properly or put it back the next time it updates.
it|%@ potrebbe non funzionare bene o reinstallarlo al prossimo aggiornamento.
de|%@ funktioniert dann eventuell nicht richtig oder legt es beim nächsten Update wieder an.
fr|%@ pourrait mal fonctionner ou le réinstaller à la prochaine mise à jour.
es|%@ podría dejar de funcionar bien o volver a instalarlo en la próxima actualización.

%@ couldn't be changed. If macOS asked for your password, it may have been cancelled.
it|Impossibile modificare %@. Se macOS ha chiesto la password, forse è stato annullato.
de|%@ konnte nicht geändert werden. Falls macOS nach dem Passwort gefragt hat, wurde es vielleicht abgebrochen.
fr|Impossible de modifier %@. Si macOS a demandé votre mot de passe, l'opération a peut-être été annulée.
es|No se pudo cambiar %@. Si macOS pidió tu contraseña, puede que se haya cancelado.

Helpers that apps installed for every account on this Mac: updaters, licence checks, VPN and sync services. Turn Off stops one and keeps it from starting again; you can turn it back on. Remove also moves its file to the Trash. Both ask for your password when the item is system-wide.
it|Servizi che le app hanno installato per tutti gli account di questo Mac: aggiornamenti, controlli di licenza, VPN e sincronizzazione. Disattiva ne ferma uno e gli impedisce di ripartire; puoi riattivarlo. Rimuovi sposta anche il suo file nel Cestino. Per gli elementi di sistema viene chiesta la password.
de|Helfer, die Apps für alle Benutzer dieses Macs installiert haben: Updater, Lizenzprüfungen, VPN- und Sync-Dienste. Ausschalten stoppt einen und verhindert den Neustart; du kannst ihn wieder einschalten. Entfernen legt zusätzlich die Datei in den Papierkorb. Bei systemweiten Objekten wird nach dem Passwort gefragt.
fr|Assistants installés par des apps pour tous les comptes de ce Mac : mises à jour, licences, VPN et synchronisation. Désactiver en arrête un et l'empêche de redémarrer ; vous pouvez le réactiver. Supprimer place aussi son fichier dans la corbeille. Les éléments système demandent votre mot de passe.
es|Ayudantes que las apps instalaron para todas las cuentas de este Mac: actualizadores, licencias, VPN y sincronización. Desactivar detiene uno y evita que vuelva a iniciarse; puedes reactivarlo. Eliminar además mueve su archivo a la Papelera. Los elementos del sistema piden tu contraseña.

Some apps register background items with macOS directly; switch those off under Allow in the Background.
it|Alcune app registrano elementi in background direttamente in macOS; disattivali in Consenti in background.
de|Manche Apps melden Hintergrundobjekte direkt bei macOS an; schalte sie unter „Im Hintergrund erlauben“ aus.
fr|Certaines apps déclarent leurs éléments directement à macOS ; désactivez-les sous Autoriser en arrière-plan.
es|Algunas apps registran elementos directamente en macOS; desactívalos en Permitir en segundo plano.

%@ smaller items
it|%@ elementi più piccoli
de|%@ kleinere Objekte
fr|%@ éléments plus petits
es|%@ elementos más pequeños

Smaller items, listed on the right
it|Elementi più piccoli, elencati a destra
de|Kleinere Objekte, rechts aufgelistet
fr|Éléments plus petits, listés à droite
es|Elementos más pequeños, listados a la derecha

Scan mode
it|Modalità scansione
de|Scanmodus
fr|Mode analyse
es|Modo escaneo

Reading disk
it|Lettura disco
de|Lese Festplatte
fr|Lecture du disque
es|Leyendo disco

My Activity
it|La mia attività
de|Meine Aktivität
fr|Mon activité
es|Mi actividad

MY ACTIVITY
it|LA MIA ATTIVITÀ
de|MEINE AKTIVITÄT
fr|MON ACTIVITÉ
es|MI ACTIVIDAD

Light
it|Chiaro
de|Hell
fr|Clair
es|Claro

See-through
it|Trasparente
de|Durchsichtig
fr|Transparent
es|Transparente

Flush DNS Cache
it|Svuota cache DNS
de|DNS-Cache leeren
fr|Vider le cache DNS
es|Vaciar caché DNS

Update to %@
it|Aggiorna a %@
de|Auf %@ aktualisieren
fr|Mettre à jour vers %@
es|Actualizar a %@

Updating…
it|Aggiornamento…
de|Wird aktualisiert…
fr|Mise à jour…
es|Actualizando…

Update CLN to %@?
it|Aggiornare CLN a %@?
de|CLN auf %@ aktualisieren?
fr|Mettre à jour CLN vers %@ ?
es|¿Actualizar CLN a %@?

Update & Restart
it|Aggiorna e riavvia
de|Aktualisieren & neu starten
fr|Mettre à jour et redémarrer
es|Actualizar y reiniciar

What's New
it|Novità
de|Neuigkeiten
fr|Nouveautés
es|Novedades

Later
it|Più tardi
de|Später
fr|Plus tard
es|Más tarde

CLN downloads the new version from GitHub, replaces this one and opens again. Your settings and history stay. The old version goes to the Trash.
it|CLN scarica la nuova versione da GitHub, sostituisce questa e si riapre. Impostazioni e cronologia restano. La vecchia versione va nel Cestino.
de|CLN lädt die neue Version von GitHub, ersetzt diese und startet neu. Einstellungen und Verlauf bleiben erhalten. Die alte Version kommt in den Papierkorb.
fr|CLN télécharge la nouvelle version depuis GitHub, remplace celle-ci et se rouvre. Vos réglages et votre historique sont conservés. L'ancienne version va dans la corbeille.
es|CLN descarga la nueva versión de GitHub, sustituye esta y se vuelve a abrir. Tus ajustes e historial se conservan. La versión anterior va a la Papelera.

Check for Updates
it|Cerca aggiornamenti
de|Nach Updates suchen
fr|Rechercher des mises à jour
es|Buscar actualizaciones

Checking…
it|Verifica…
de|Wird geprüft…
fr|Vérification…
es|Comprobando…

CLN is up to date.
it|CLN è aggiornato.
de|CLN ist auf dem neuesten Stand.
fr|CLN est à jour.
es|CLN está actualizado.

Version %@ is available.
it|È disponibile la versione %@.
de|Version %@ ist verfügbar.
fr|La version %@ est disponible.
es|La versión %@ está disponible.

Couldn't reach GitHub.
it|Impossibile raggiungere GitHub.
de|GitHub ist nicht erreichbar.
fr|Impossible de joindre GitHub.
es|No se pudo conectar con GitHub.

The download didn't finish.
it|Il download non è stato completato.
de|Der Download wurde nicht abgeschlossen.
fr|Le téléchargement n'a pas abouti.
es|La descarga no se completó.

The download couldn't be unpacked.
it|Impossibile estrarre il download.
de|Der Download konnte nicht entpackt werden.
fr|Le téléchargement n'a pas pu être décompressé.
es|No se pudo descomprimir la descarga.

The download isn't the expected CLN version.
it|Il download non è la versione di CLN prevista.
de|Der Download ist nicht die erwartete CLN-Version.
fr|Le téléchargement n'est pas la version de CLN attendue.
es|La descarga no es la versión de CLN esperada.
"""#
}
