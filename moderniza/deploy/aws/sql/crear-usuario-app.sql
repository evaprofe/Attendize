-- =============================================================================
-- Usuario de la APLICACIÓN en RDS (Tarea 5). Ejecutar con el usuario maestro.
-- La aplicación NO usa el usuario maestro (mínimo privilegio).
-- Sustituye CAMBIAR_CONTRASEÑA por una contraseña generada y guárdala SOLO en
-- Parameter Store (/moderniza/<ALUMNO>/prod/DB_PASSWORD). No la subas a GitHub.
-- =============================================================================
CREATE DATABASE IF NOT EXISTS attendize CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'moderniza_app'@'%' IDENTIFIED BY 'CAMBIAR_CONTRASEÑA';

-- Lectura/escritura de datos + lo que necesitan las migraciones de Moderniza
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, REFERENCES
  ON attendize.* TO 'moderniza_app'@'%';

FLUSH PRIVILEGES;
