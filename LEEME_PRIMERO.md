# Tarea 3 · Plantilla Moderniza

1. Trabaja en tu rama `tarea-03-mejora-completa`.
2. Descomprime este paquete en la **raíz de tu repositorio de Attendize** (la carpeta donde está `docker-compose.yml`).
   - Con el Explorador de Windows («Extraer todo»): por defecto propone una subcarpeta `plantilla_alumnado_T3`. **Borra ese final de la ruta** para que el destino sea la raíz del repositorio.
   - Con PowerShell, desde la raíz del repositorio: `tar -xf ruta\plantilla_alumnado_T3.zip`.

   Quedará así (comprueba que `docker-compose.override.yml` está junto a `docker-compose.yml`):

   ```
   Attendize/
   ├─ docker-compose.yml            (de Attendize, NO lo modifiques)
   ├─ docker-compose.override.yml   (NUEVO: añade los servicios de Moderniza)
   ├─ moderniza/                    (NUEVO: la aplicación modernizada)
   └─ ... resto de Attendize sin cambios
   ```

3. Haz un commit **solo con la plantilla**, antes de cambiar nada:

   ```bash
   git add docker-compose.override.yml moderniza LEEME_PRIMERO.md
   git commit -m "T3: base Moderniza proporcionada por el profesorado"
   git tag tarea-03-inicio
   git push -u origin tarea-03-mejora-completa
   git push origin tarea-03-inicio
   ```

4. Sigue `moderniza/README.md`: puesta en marcha, lista de `TODO T3-1` a `TODO T3-7` y, si algo falla, su apartado 5.
5. En Windows, escribe las órdenes en **Git Bash** (por ejemplo, la terminal de VS Code con el perfil Git Bash) y pon siempre `docker compose exec moderniza …` delante de `php`, `composer` o `npm`.
