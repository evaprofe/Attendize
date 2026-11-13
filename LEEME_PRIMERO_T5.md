# Tarea 5 · Kit de despliegue en AWS

1. Trabaja desde tu entrega de la Tarea 4:

   ```bash
   git switch -c tarea-05-migracion-aws tarea-04-entrega
   ```

2. Descomprime este paquete en la **raíz de tu repositorio**. Añade `moderniza/deploy/aws/` y `moderniza/.dockerignore`, y sustituye `moderniza/bootstrap/app.php` (archivo base). No toca tu código de las Tareas 3 y 4.
3. Haz un commit solo con el kit y crea la etiqueta de inicio:

   ```bash
   git add -A
   git commit -m "T5: kit de despliegue proporcionado por el profesorado"
   git tag tarea-05-inicio
   git push -u origin tarea-05-migracion-aws
   git push origin tarea-05-inicio
   ```

4. Sigue el manual `moderniza/deploy/aws/README.md`. Tus `TODO T5-1` a `T5-3` están en `moderniza/deploy/aws/sql/validar-migracion.sql`.
5. **Nunca** subas a GitHub `.env.production`, contraseñas ni volcados `.sql`.
