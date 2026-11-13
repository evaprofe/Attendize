# Tarea 5 · Despliegue de Moderniza en AWS (EC2 + RDS)

Kit de despliegue proporcionado por el profesorado. **Se despliega Moderniza** (Laravel 13 + React). Attendize se queda en local: sus datos se trasladan a RDS junto con las sesiones del programa.

```
Navegador ──HTTPS──► EC2 [ caddy :443 ──► moderniza (Apache + PHP 8.3) ] ──3306──► RDS MySQL (privada)
                       ▲ imagen desde ECR            ▲ secretos desde Parameter Store
```

| Archivo | Para qué sirve |
|---|---|
| `Dockerfile` | Imagen de producción: compila React (Vite) y monta PHP 8.3 + Apache sin dependencias de desarrollo |
| `entrypoint.sh` | Al arrancar: genera las cachés de producción. **No** migra automáticamente |
| `php-produccion.ini` | PHP sin errores en pantalla, opcache activado |
| `compose.aws.yml` | Servicios en EC2: `moderniza` (sin puertos públicos) y `caddy` (80/443) |
| `Caddyfile` | Proxy HTTPS con certificado automático o autofirmado |
| `.env.production.example` | Configuración de producción **sin secretos** |
| `generar-env.sh` | Crea `.env.production` en EC2 leyendo Parameter Store |
| `instalar-ec2.sh` | Instala Docker y Compose en Amazon Linux 2023 |
| `sql/crear-usuario-app.sql` | Usuario MySQL de la aplicación con mínimo privilegio |
| `sql/validar-migracion.sql` | Recuentos, huérfanos y reglas, para comparar origen y destino (**TODO T5-1 a T5-3**) |

> En todo el manual: `<ALUMNO>` es tu identificador (sin datos personales), `<REGION>` la región que indique el profesorado y `<CUENTA>` el número de tu cuenta del laboratorio. **Nunca** copies contraseñas, claves ni el contenido de `.env.production` en GitHub, Issues, capturas ni documentos.

---

## 0. Antes de empezar

- La etiqueta `tarea-04-entrega` funciona en local y sus pruebas pasan.
- `moderniza/composer.lock` y `moderniza/package-lock.json` están en el repositorio.
- AWS CLI v2 instalada en tu ordenador. Las credenciales temporales del laboratorio (*AWS Details*) se copian en `~/.aws/credentials` y **caducan** al terminar la sesión del laboratorio.

## 1. Versión candidata e imagen en ECR (en tu ordenador)

```bash
git switch tarea-05-migracion-aws
git status                 # debe estar limpio
git rev-parse --short HEAD # anota el commit: es la referencia de lo desplegado

cd moderniza
docker build -f deploy/aws/Dockerfile -t moderniza:tarea-05-rc1 .

aws ecr create-repository --repository-name moderniza-<ALUMNO> --region <REGION>
aws ecr get-login-password --region <REGION> \
  | docker login --username AWS --password-stdin <CUENTA>.dkr.ecr.<REGION>.amazonaws.com

IMG=<CUENTA>.dkr.ecr.<REGION>.amazonaws.com/moderniza-<ALUMNO>
docker tag moderniza:tarea-05-rc1 $IMG:tarea-05-rc1
docker tag moderniza:tarea-05-rc1 $IMG:$(git rev-parse --short HEAD)
docker push $IMG:tarea-05-rc1
docker push $IMG:$(git rev-parse --short HEAD)
```

Para poder volver atrás (apartado 8), construye y sube también la imagen de la versión anterior:

```bash
git worktree add ../t4 tarea-04-entrega
docker build -f deploy/aws/Dockerfile -t $IMG:tarea-04-entrega ../t4/moderniza   # usa el Dockerfile de T5 con el código de T4
docker push $IMG:tarea-04-entrega
git worktree remove ../t4
```

## 2. Red y grupos de seguridad

| Grupo | Entrada | Origen |
|---|---|---|
| `sg-moderniza-ec2` | 443 y 80 (HTTPS y redirección / certificado) | Internet o el rango que indique el profesorado |
| `sg-moderniza-ec2` | 22 (solo si usas SSH) | **Tu IP** (`x.x.x.x/32`), nunca `0.0.0.0/0` |
| `sg-moderniza-rds` | 3306 | **Solo** el grupo `sg-moderniza-ec2` |

```bash
aws ec2 authorize-security-group-ingress --group-id <sg-rds> --protocol tcp --port 3306 --source-group <sg-ec2>
```

## 3. RDS MySQL privada

Consulta las versiones disponibles y elige una MySQL 8 autorizada:

```bash
aws rds describe-db-engine-versions --engine mysql --query "DBEngineVersions[].EngineVersion" --region <REGION>
```

Crea la instancia desde la consola o con la CLI. Las opciones obligatorias son:
- **acceso público: No**;
- grupo `sg-moderniza-rds`;
- base inicial `attendize`;
- copias automáticas activadas si el laboratorio lo permite;
- etiquetas de proyecto, alumno y fecha de retirada.

```bash
aws rds create-db-instance --region <REGION> \
  --db-instance-identifier moderniza-<ALUMNO> \
  --engine mysql --db-instance-class db.t3.micro --allocated-storage 20 \
  --db-name attendize --master-username admin --master-user-password '<contraseña maestra>' \
  --no-publicly-accessible --vpc-security-group-ids <sg-rds> --backup-retention-period 1
aws rds wait db-instance-available --db-instance-identifier moderniza-<ALUMNO> --region <REGION>
```

Si tu laboratorio limita los tipos o el almacenamiento, usa los que indique el profesorado.

## 4. EC2

1. Lanza una instancia **Amazon Linux 2023** con el grupo `sg-moderniza-ec2`, el perfil de instancia del laboratorio (por ejemplo `LabInstanceProfile`, que da acceso a ECR y Parameter Store sin guardar claves) y `instalar-ec2.sh` como *User data*.
2. Conéctate por EC2 Instance Connect o SSH (puerto 22 solo desde tu IP).
3. Copia la carpeta `moderniza/deploy/aws` a la instancia (`git clone` de tu repositorio o `scp`).

## 5. Secretos en Parameter Store

Desde tu ordenador. La clave de la aplicación se genera con la propia imagen:

```bash
docker run --rm --entrypoint php moderniza:tarea-05-rc1 artisan key:generate --show   # copia el resultado (base64:...)

P=/moderniza/<ALUMNO>/prod
aws ssm put-parameter --region <REGION> --name $P/APP_KEY     --type SecureString --value 'base64:...'
aws ssm put-parameter --region <REGION> --name $P/DB_PASSWORD --type SecureString --value '<contraseña de moderniza_app>'
aws ssm put-parameter --region <REGION> --name $P/APP_URL     --type String --value 'https://<dominio>'
aws ssm put-parameter --region <REGION> --name $P/DB_HOST     --type String --value '<endpoint de RDS>'
aws ssm put-parameter --region <REGION> --name $P/DB_USERNAME --type String --value 'moderniza_app'
```

**Dominio sin comprarlo:** `<IP pública con guiones>.sslip.io` (por ejemplo `3-80-12-34.sslip.io`) resuelve a la IP de tu instancia. Si cambia la IP al reiniciar el laboratorio, actualiza `APP_URL` y `SITE_DOMAIN`.

## 6. Migración de datos

**6.1 Copia del origen (en tu ordenador, con Attendize parado para que no haya escrituras):**

```bash
docker compose stop web worker moderniza
mkdir -p ~/copias-moderniza        # FUERA del repositorio: el volcado no debe acabar en GitHub
docker compose exec -T db mysqldump -uroot -pyes --single-transaction --routines --triggers \
  --default-character-set=utf8mb4 attendize > ~/copias-moderniza/attendize-pre-migracion.sql
(cd ~/copias-moderniza && sha256sum attendize-pre-migracion.sql > attendize-pre-migracion.sql.sha256)
docker compose exec -T db mysql -uroot -pyes attendize < moderniza/deploy/aws/sql/validar-migracion.sql > ~/copias-moderniza/validacion-origen.txt
```

> El volcado contiene datos (ficticios). Se guarda **fuera** del repositorio y se borra cuando lo indique el profesorado.

**6.2 Importación en RDS (en EC2).** RDS solo es accesible desde EC2. El cliente MySQL se ejecuta en un contenedor, así que no hay que instalarlo:

```bash
scp ~/copias-moderniza/attendize-pre-migracion.sql* ec2-user@<IP>:~   # desde tu ordenador
(cd ~ && sha256sum -c attendize-pre-migracion.sql.sha256)   # en EC2: el archivo llegó íntegro

RDS=<endpoint de RDS>
read -s MYSQL_PWD && export MYSQL_PWD               # contraseña MAESTRA (no se ve ni queda en el historial)
docker run --rm -i -e MYSQL_PWD mysql:8.0 mysql -h $RDS -u admin < sql/crear-usuario-app.sql   # antes: cambia CAMBIAR_CONTRASEÑA
docker run --rm -i -e MYSQL_PWD mysql:8.0 mysql -h $RDS -u admin attendize < ~/attendize-pre-migracion.sql
docker run --rm -i -e MYSQL_PWD mysql:8.0 mysql -h $RDS -u admin attendize < sql/validar-migracion.sql > validacion-destino.txt
unset MYSQL_PWD
```

La importación se hace con el usuario **maestro**: el volcado necesita permisos (por ejemplo `LOCK TABLES`) que el usuario de la aplicación no tiene a propósito.

**6.3 Validación:** compara los dos resultados. Toda diferencia debe estar explicada:

```bash
# copia validacion-destino.txt a tu ordenador (scp) y compara:
diff ~/copias-moderniza/validacion-origen.txt validacion-destino.txt && echo "Sin diferencias"
```

## 7. Despliegue (en EC2, carpeta `deploy/aws`)

```bash
sh generar-env.sh <ALUMNO> <REGION>      # crea .env.production (permisos 600)
aws ecr get-login-password --region <REGION> | docker login --username AWS --password-stdin <CUENTA>.dkr.ecr.<REGION>.amazonaws.com

export MODERNIZA_IMAGE=<CUENTA>.dkr.ecr.<REGION>.amazonaws.com/moderniza-<ALUMNO>:tarea-05-rc1
export SITE_DOMAIN=<ip-con-guiones>.sslip.io
# export CADDY_TLS="tls internal"   # solo si no se puede obtener el certificado público
docker compose -f compose.aws.yml up -d
docker compose -f compose.aws.yml ps

# Migraciones: UNA vez y desde un único punto. Tras importar el volcado debe decir "Nothing to migrate".
docker compose -f compose.aws.yml exec moderniza php artisan migrate --force
```

**Pruebas de humo:**
- `https://<dominio>/up` responde 200;
- el login funciona con un organizador migrado;
- se crea una sesión y queda guardada en RDS;
- `https://<dominio>/eventos/<id>/programa` funciona sin login;
- la API responde 200, y 404 para un evento no publicado;
- desde tu ordenador, el puerto 3306 de RDS **no** responde.

**Registros:**

```bash
docker compose -f compose.aws.yml logs --tail 100 moderniza
docker compose -f compose.aws.yml logs --tail 100 caddy
```

## 8. Copia, restauración y vuelta atrás

**Copia (instantánea manual):**

```bash
aws rds create-db-snapshot --region <REGION> --db-instance-identifier moderniza-<ALUMNO> \
  --db-snapshot-identifier moderniza-<ALUMNO>-tarea05-rc1-<AAAAMMDD>
aws rds wait db-snapshot-available --region <REGION> --db-snapshot-identifier moderniza-<ALUMNO>-tarea05-rc1-<AAAAMMDD>
```

**Restauración en OTRA instancia** (nunca sobre la original). Anota la hora de inicio y la de fin:

```bash
aws rds restore-db-instance-from-db-snapshot --region <REGION> \
  --db-instance-identifier moderniza-<ALUMNO>-restore \
  --db-snapshot-identifier moderniza-<ALUMNO>-tarea05-rc1-<AAAAMMDD> \
  --db-instance-class db.t3.micro --no-publicly-accessible --vpc-security-group-ids <sg-rds>
aws rds wait db-instance-available --region <REGION> --db-instance-identifier moderniza-<ALUMNO>-restore
```

Comprobación sobre la base restaurada (en EC2):
1. Ejecuta `sql/validar-migracion.sql` contra el endpoint restaurado y compáralo con la validación de destino.
2. Arranca la aplicación contra esa base solo en local (`127.0.0.1:8081`). Lee el programa y escribe una sesión de prueba:

```bash
docker run --rm -d --name restore-check --env-file .env.production -e DB_HOST=<endpoint restaurado> \
  -e APP_URL=http://127.0.0.1:8081 -p 127.0.0.1:8081:80 $MODERNIZA_IMAGE
curl -s http://127.0.0.1:8081/api/events/<id>/sessions
docker stop restore-check
```

**Vuelta atrás de la aplicación.** Se activa ante un error crítico, pérdida de datos, fallo general de acceso o exposición de información.

```bash
# 1. Copia de la base ANTES de cambiar de versión (instantánea, como arriba)
# 2. Imagen anterior
export MODERNIZA_IMAGE=<CUENTA>.dkr.ecr.<REGION>.amazonaws.com/moderniza-<ALUMNO>:tarea-04-entrega
docker compose -f compose.aws.yml up -d moderniza
# 3. Pruebas de humo y registro del resultado; 4. Volver a tarea-05-rc1 del mismo modo
```

La Tarea 5 no añade migraciones, así que la base es compatible con la versión anterior. **No** ejecutes `migrate:rollback` sin una copia restaurable.

## 9. Retirada de recursos (al terminar, o cuando lo indique el profesorado)

```bash
docker compose -f compose.aws.yml down          # en EC2
aws rds delete-db-instance --region <REGION> --db-instance-identifier moderniza-<ALUMNO>-restore --skip-final-snapshot
aws rds delete-db-instance --region <REGION> --db-instance-identifier moderniza-<ALUMNO> --skip-final-snapshot
aws rds delete-db-snapshot --region <REGION> --db-snapshot-identifier moderniza-<ALUMNO>-tarea05-rc1-<AAAAMMDD>
aws ecr delete-repository --region <REGION> --repository-name moderniza-<ALUMNO> --force
aws ssm delete-parameters --region <REGION> --names /moderniza/<ALUMNO>/prod/APP_KEY /moderniza/<ALUMNO>/prod/APP_URL \
  /moderniza/<ALUMNO>/prod/DB_HOST /moderniza/<ALUMNO>/prod/DB_USERNAME /moderniza/<ALUMNO>/prod/DB_PASSWORD
# Termina la instancia EC2 y borra los grupos de seguridad desde la consola.
```

Antes de borrar nada, guarda **fuera del laboratorio** las evidencias, la validación y el registro de la migración.

## 10. Documentación que entregas (`docs/tarea-05/`)

| Archivo | Contenido |
|---|---|
| `01-inventario-plan-migracion.md` | Tablas y archivos: migrar, transformar, regenerar o excluir; orden; cancelación |
| `02-arquitectura-aws.md` | Diagrama propio, recursos, red, grupos, secretos, copias y registros |
| `03-despliegue.md` | Versión exacta (etiqueta, commit, imagen y digest) y pasos ejecutados con su resultado |
| `04-validacion-datos.md` | Recuentos origen/destino, huérfanos, reglas, muestra en la interfaz e incidencias |
| `05-pruebas.md` | Humo, funciones, permisos, errores, HTTPS, puertos cerrados y regresión |
| `06-recuperacion-vuelta-atras.md` | Instantánea, restauración en otra instancia (tiempos) y ensayo de vuelta atrás |
| `07-operacion-retirada.md` | Arranque, parada, registros, diagnóstico y retirada de recursos |
