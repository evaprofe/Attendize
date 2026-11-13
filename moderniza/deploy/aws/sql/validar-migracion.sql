-- =============================================================================
-- Validación de la migración (Tarea 5)
-- Ejecutar en el ORIGEN (local) y en el DESTINO (RDS) y comparar los resultados.
-- Toda diferencia debe quedar explicada en docs/tarea-05/02-registro-migracion.md
-- =============================================================================

-- 1. Recuentos por tabla ------------------------------------------------------
SELECT 'accounts' AS tabla, COUNT(*) AS filas FROM accounts
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'organisers', COUNT(*) FROM organisers
UNION ALL SELECT 'events', COUNT(*) FROM events
UNION ALL SELECT 'tickets', COUNT(*) FROM tickets
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'attendees', COUNT(*) FROM attendees
UNION ALL SELECT 'event_sessions', COUNT(*) FROM event_sessions
UNION ALL SELECT 'migrations (Attendize)', COUNT(*) FROM migrations
UNION ALL SELECT 'moderniza_migrations', COUNT(*) FROM moderniza_migrations;

-- 2. Relaciones huérfanas (resultado esperado: 0 en todas) --------------------
SELECT 'eventos sin cuenta' AS comprobacion, COUNT(*) AS filas
FROM events e LEFT JOIN accounts a ON a.id = e.account_id WHERE a.id IS NULL
UNION ALL
SELECT 'usuarios sin cuenta', COUNT(*)
FROM users u LEFT JOIN accounts a ON a.id = u.account_id WHERE a.id IS NULL
-- TODO T5-1: añade las sesiones (event_sessions) sin evento y sin cuenta.
;

-- 3. Coherencia de las reglas del proyecto (resultado esperado: 0) ------------
-- TODO T5-2: sesiones cuya cuenta no coincide con la de su evento (regla de permisos T3).

SELECT 'sesiones con fin <= inicio o aforo < 1' AS comprobacion, COUNT(*) AS filas
FROM event_sessions WHERE ends_at <= starts_at OR capacity < 1;

-- TODO T5-3: pares de sesiones que se solapan en la misma sala del mismo evento (cambio T4).

-- 4. Muestra reconocible (comparar a simple vista origen y destino) -----------
SELECT e.id, e.title, e.is_live, COUNT(s.id) AS sesiones, SUM(s.is_published) AS publicadas
FROM events e LEFT JOIN event_sessions s ON s.event_id = e.id
GROUP BY e.id, e.title, e.is_live
ORDER BY e.id;

-- 5. Estado del esquema de Moderniza -----------------------------------------
SELECT migration, batch FROM moderniza_migrations ORDER BY id;
