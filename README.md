# Entregable Final - Migración de la base de datos `employees` (MariaDB → PostgreSQL)

| Campo | Detalle |
|---|---|
| **Estudiante** | Ruben Churqui Limachi |
| **Asignatura** | Tecnología de Base de Datos I |
| **Docente** | Ing. Jared Lopez Leaños|
| **Fecha** | 29 de septiembre de 2026 |

---

## I. Introducción

Continuando el proyecto de migración de la base de datos `employees` desde MariaDB hacia PostgreSQL, esta fase final completa el proceso migrando los **datos** de las 6 tablas, migrando las **vistas** dependientes, y ejecutando un conjunto de **consultas de verificación** que confirman que la migración conservó la cantidad, el contenido y la integridad referencial de la información.

### Entorno

| Elemento | Detalle |
|---|---|
| Origen | MariaDB 11.8.9 (contenedor Docker `mariadb`), base `employees` |
| Destino | PostgreSQL 18 (contenedor Docker `postgresql`), base `employees` |
| Orquestación | Docker Compose (`~/tecBD1/docker-compose.yml`) |
| Máquina | MINIOS (Debian 12) en VirtualBox, host `churqui` |

> **Nota:** la base `employees` en PostgreSQL ya contenía los datos migrados con `pgloader` en una fase anterior del proyecto. Esta fase verifica esa migración y agrega lo que faltaba: las vistas. La base `pdb_employees` (creada en la Actividad 5) contiene solo la estructura y no se usa aquí.

### Verificación de contenedores

```bash
cd ~/tecBD1
docker compose ps
```

```
NAME         IMAGE                    STATUS
adminer      adminer                  Up
mariadb      mariadb:11.8.9-ubi9      Up
pgadmin4     dpage/pgadmin4           Up
postgresql   postgres:18              Up (healthy)
```

---

## II. Punto 1: Migración de tablas

### 1.1 Bases de datos disponibles en PostgreSQL

```bash
docker exec postgresql psql -U ruben -d postgres -c "\l"
```

```
     Name      | Owner  | Encoding
---------------+--------+----------
 db_dvdrental  | dbadvd | UTF8
 employees     | ruben  | UTF8
 pdb_employees | ruben  | UTF8
 pdb_ruben     | ruben  | UTF8
 postgres      | ruben  | UTF8
 template0     | ruben  | UTF8
 template1     | ruben  | UTF8
 videos        | ruben  | UTF8
(8 rows)
```

La base `employees` contiene los datos completos (migrados con `pgloader`); `pdb_employees` contiene únicamente la estructura de la Actividad 5.

### 1.2 Tablas migradas

```bash
docker exec postgresql psql -U ruben -d employees -c "\dt"
```

```
             List of relations
 Schema |     Name      | Type  | Owner
--------+---------------+-------+-------
 public | departments   | table | ruben
 public | dept_emp      | table | ruben
 public | dept_manager  | table | ruben
 public | employees     | table | ruben
 public | salaries      | table | ruben
 public | titles        | table | ruben
(6 rows)
```

### 1.3 Conteo de filas en PostgreSQL

```bash
docker exec postgresql psql -U ruben -d employees -c "
SELECT 'departments' AS tabla, COUNT(*) AS filas FROM departments
UNION ALL SELECT 'dept_emp', COUNT(*) FROM dept_emp
UNION ALL SELECT 'dept_manager', COUNT(*) FROM dept_manager
UNION ALL SELECT 'employees', COUNT(*) FROM employees
UNION ALL SELECT 'salaries', COUNT(*) FROM salaries
UNION ALL SELECT 'titles', COUNT(*) FROM titles
ORDER BY tabla;
"
```

```
    tabla     |  filas
--------------+---------
 departments  |       9
 dept_emp     |  331603
 dept_manager |      24
 employees    |  300024
 salaries     | 2844047
 titles       |  443308
(6 rows)
```

### 1.4 Conteo de filas en MariaDB (origen)

```bash
docker exec mariadb mariadb -u root -p123456 employees -e "
SELECT 'departments' AS tabla, COUNT(*) AS filas FROM departments
UNION ALL SELECT 'dept_emp', COUNT(*) FROM dept_emp
UNION ALL SELECT 'dept_manager', COUNT(*) FROM dept_manager
UNION ALL SELECT 'employees', COUNT(*) FROM employees
UNION ALL SELECT 'salaries', COUNT(*) FROM salaries
UNION ALL SELECT 'titles', COUNT(*) FROM titles
ORDER BY tabla;
"
```

```
tabla	filas
departments	9
dept_emp	331603
dept_manager	24
employees	300024
salaries	2844047
titles	443308
```

### 1.5 Comparación

| Tabla | MariaDB | PostgreSQL | ¿Coinciden? |
|---|---|---|---|
| `departments` | 9 | 9 | Sí |
| `dept_emp` | 331,603 | 331,603 | Sí |
| `dept_manager` | 24 | 24 | Sí |
| `employees` | 300,024 | 300,024 | Sí |
| `salaries` | 2,844,047 | 2,844,047 | Sí |
| `titles` | 443,308 | 443,308 | Sí |
| **Total** | **3,919,015** | **3,919,015** | **Sí** |

Los conteos coinciden exactamente en las 6 tablas, sumando 3,919,015 filas migradas.

Las salidas se guardaron en archivos adjuntos:
```bash
docker exec postgresql psql -U ruben -d employees -c "..." > ~/verificacion_conteos_postgresql.txt
docker exec mariadb mariadb -u root -p123456 employees -e "..." > ~/verificacion_conteos_mariadb.txt
```

---

## III. Punto 2: Migración de vistas

### 2.1 Vistas existentes en MariaDB

```bash
docker exec mariadb mariadb -u root -p123456 employees -e "SHOW FULL TABLES WHERE Table_type = 'VIEW';"
```

```
Tables_in_employees	Table_type
current_dept_emp	VIEW
dept_emp_latest_date	VIEW
```

### 2.2 Definición de cada vista

```bash
docker exec mariadb mariadb -u root -p123456 employees -e "SHOW CREATE VIEW current_dept_emp\G"
docker exec mariadb mariadb -u root -p123456 employees -e "SHOW CREATE VIEW dept_emp_latest_date\G"
```

**`dept_emp_latest_date`** — obtiene, para cada empleado, la fecha más reciente de inicio y fin de asignación a un departamento:

```sql
SELECT dept_emp.emp_no, MAX(dept_emp.from_date) AS from_date,
       MAX(dept_emp.to_date) AS to_date
FROM dept_emp GROUP BY dept_emp.emp_no
```

**`current_dept_emp`** — cruza esa fecha más reciente con `dept_emp` para obtener la asignación de departamento vigente de cada empleado:

```sql
SELECT l.emp_no, d.dept_no, l.from_date, l.to_date
FROM dept_emp d
JOIN dept_emp_latest_date l
  ON d.emp_no = l.emp_no
  AND d.from_date = l.from_date
  AND l.to_date = d.to_date
```

`current_dept_emp` **depende de** `dept_emp_latest_date`, por lo que esta última debe crearse primero.

### 2.3 Adaptación de sintaxis MariaDB → PostgreSQL

| MariaDB | PostgreSQL | Motivo |
|---|---|---|
| Identificadores entre `` `backticks` `` | Sin comillas (o comillas dobles) | PostgreSQL no usa backticks |
| `ALGORITHM=UNDEFINED DEFINER=...` | (eliminado) | Cláusula propia del motor de vistas de MariaDB, sin equivalente necesario |
| `SQL SECURITY DEFINER` | (eliminado) | El control de permisos de vistas en PostgreSQL se maneja con `GRANT`/`REVOKE`, no con esta cláusula |
| `IF(condición, valor1, valor2)` | `CASE WHEN condición THEN valor1 ELSE valor2 END` | PostgreSQL no tiene la función `IF()`; no fue necesaria en estas dos vistas, pero se documenta por si se requiere en otras |

### 2.4 Script de vistas adaptado (`vistas_postgresql.sql`)

```sql
-- ============================================================
-- Vistas adaptadas de MariaDB a PostgreSQL
-- Base de datos: employees
-- Autor: Ruben Churqui Limachi
-- Fecha: 28 de Septiembre de 2026
-- ============================================================

-- Vista 1: dept_emp_latest_date (crear PRIMERO)
CREATE OR REPLACE VIEW public.dept_emp_latest_date AS
SELECT
    dept_emp.emp_no,
    MAX(dept_emp.from_date) AS from_date,
    MAX(dept_emp.to_date) AS to_date
FROM dept_emp
GROUP BY dept_emp.emp_no;

-- Vista 2: current_dept_emp (depende de dept_emp_latest_date)
CREATE OR REPLACE VIEW public.current_dept_emp AS
SELECT
    l.emp_no,
    d.dept_no,
    l.from_date,
    l.to_date
FROM dept_emp d
JOIN dept_emp_latest_date l
    ON d.emp_no = l.emp_no
    AND d.from_date = l.from_date
    AND l.to_date = d.to_date;
```

### 2.5 Ejecución en PostgreSQL

```bash
docker cp ~/vistas_postgresql.sql postgresql:/tmp/
docker exec postgresql psql -U ruben -d employees -f /tmp/vistas_postgresql.sql
```

```
CREATE VIEW
CREATE VIEW
```

### 2.6 Verificación de las vistas

```bash
docker exec postgresql psql -U ruben -d employees -c "\dv"
```

```
                List of views
 Schema |         Name         | Type | Owner
--------+----------------------+------+-------
 public | current_dept_emp     | view | ruben
 public | dept_emp_latest_date | view | ruben
(2 rows)
```

### 2.7 Prueba de las vistas

```bash
docker exec postgresql psql -U ruben -d employees -c "SELECT * FROM dept_emp_latest_date LIMIT 5;"
docker exec postgresql psql -U ruben -d employees -c "SELECT * FROM current_dept_emp LIMIT 5;"
```

```
 emp_no | from_date  |  to_date
--------+------------+------------
  10001 | 1986-06-26 | 9999-01-01
  10002 | 1996-08-03 | 9999-01-01
  10003 | 1995-12-03 | 9999-01-01
  10004 | 1986-12-01 | 9999-01-01
  10005 | 1989-09-12 | 9999-01-01
(5 rows)

 emp_no | dept_no | from_date  |  to_date
--------+---------+------------+------------
  10004 | d004    | 1986-12-01 | 9999-01-01
  10286 | d009    | 1994-12-24 | 1999-01-24
  10287 | d005    | 1997-09-05 | 9999-01-01
  10293 | d004    | 1992-12-12 | 9999-01-01
  10295 | d002    | 1995-06-19 | 9999-01-01
(5 rows)
```

### 2.8 Conteo de filas de las vistas

```bash
docker exec postgresql psql -U ruben -d employees -c "SELECT COUNT(*) FROM dept_emp_latest_date;"
docker exec postgresql psql -U ruben -d employees -c "SELECT COUNT(*) FROM current_dept_emp;"
```

```
  count
---------
 300024
(1 row)

  count
---------
 300024
(1 row)
```

Ambas vistas devuelven 300,024 filas, una por cada empleado, coincidiendo con el total de la tabla `employees`.

---

## IV. Punto 3: Consultas de verificación

### 3.1 Conteo de filas (tablas y vistas)

Ver secciones II.3, II.4, II.5 y III.8. Todos los conteos coinciden exactamente entre MariaDB y PostgreSQL.

### 3.2 Checksum MD5 por fila

Para verificar que el **contenido** de los datos es idéntico (no solo la cantidad de filas), se calculó el hash MD5 de cada fila de `employees` en ambos motores y se compararon los resultados.

**PostgreSQL:**
```bash
docker exec postgresql psql -U ruben -d employees -t -A -c "
SELECT MD5(emp_no::text || '|' || first_name || '|' || last_name || '|' || hire_date::text)
FROM employees ORDER BY emp_no;
" > ~/md5_postgresql.txt
```

**MariaDB:**
```bash
docker exec mariadb mariadb -u root -p123456 employees -N -e "
SELECT MD5(CONCAT(emp_no, '|', first_name, '|', last_name, '|', hire_date))
FROM employees ORDER BY emp_no;
" > ~/md5_mariadb.txt
```

**Comparación:**
```bash
wc -l ~/md5_postgresql.txt
wc -l ~/md5_mariadb.txt
diff ~/md5_postgresql.txt ~/md5_mariadb.txt
```

```
300024 /home/ruben/md5_postgresql.txt
300024 /home/ruben/md5_mariadb.txt
```

El comando `diff` no devolvió ninguna línea: los 300,024 hashes MD5 son **idénticos** entre ambas bases, confirmando que el contenido de cada fila se migró sin alteraciones.

### 3.3 Integridad referencial (registros huérfanos)

Se verificó que ninguna clave foránea en PostgreSQL apunte a un registro inexistente. Cada verificación se ejecutó por separado (ver incidencia en la sección V).

```bash
# Huérfanos dept_emp.emp_no
docker exec postgresql psql -U ruben -d employees -c "
SELECT COUNT(*) AS huerfanos_dept_emp_emp_no
FROM dept_emp d LEFT JOIN employees e ON d.emp_no = e.emp_no
WHERE e.emp_no IS NULL;"
```
```
 huerfanos_dept_emp_emp_no
---------------------------
                         0
```

```bash
# Huérfanos dept_emp.dept_no
docker exec postgresql psql -U ruben -d employees -c "
SELECT COUNT(*) AS huerfanos_dept_emp_dept_no
FROM dept_emp d LEFT JOIN departments dep ON d.dept_no = dep.dept_no
WHERE dep.dept_no IS NULL;"
```
```
 huerfanos_dept_emp_dept_no
----------------------------
                          0
```

```bash
# Huérfanos dept_manager.emp_no
docker exec postgresql psql -U ruben -d employees -c "
SELECT COUNT(*) AS huerfanos_dept_manager_emp_no
FROM dept_manager dm LEFT JOIN employees e ON dm.emp_no = e.emp_no
WHERE e.emp_no IS NULL;"
```
```
 huerfanos_dept_manager_emp_no
--------------------------------
                              0
```

```bash
# Huérfanos dept_manager.dept_no
docker exec postgresql psql -U ruben -d employees -c "
SELECT COUNT(*) AS huerfanos_dept_manager_dept_no
FROM dept_manager dm LEFT JOIN departments dep ON dm.dept_no = dep.dept_no
WHERE dep.dept_no IS NULL;"
```
```
 huerfanos_dept_manager_dept_no
---------------------------------
                               0
```

```bash
# Huérfanos salaries.emp_no
docker exec postgresql psql -U ruben -d employees -c "
SELECT COUNT(*) AS huerfanos_salaries_emp_no
FROM salaries s LEFT JOIN employees e ON s.emp_no = e.emp_no
WHERE e.emp_no IS NULL;"
```
```
 huerfanos_salaries_emp_no
----------------------------
                          0
```

```bash
# Huérfanos titles.emp_no
docker exec postgresql psql -U ruben -d employees -c "
SELECT COUNT(*) AS huerfanos_titles_emp_no
FROM titles t LEFT JOIN employees e ON t.emp_no = e.emp_no
WHERE e.emp_no IS NULL;"
```
```
 huerfanos_titles_emp_no
--------------------------
                        0
```

**Resultado: 0 registros huérfanos en las 6 relaciones de clave foránea.** La integridad referencial se conservó completamente en la migración.

### 3.4 Muestra de datos

**PostgreSQL:**
```bash
docker exec postgresql psql -U ruben -d employees -c "
SELECT emp_no, first_name, last_name, hire_date FROM employees ORDER BY emp_no LIMIT 5;"
```

**MariaDB:**
```bash
docker exec mariadb mariadb -u root -p123456 employees -e "
SELECT emp_no, first_name, last_name, hire_date FROM employees ORDER BY emp_no LIMIT 5;"
```

Salida idéntica en ambos motores:
```
 emp_no | first_name | last_name | hire_date
--------+------------+-----------+------------
  10001 | Georgi     | Facello   | 1986-06-26
  10002 | Bezalel    | Simmel    | 1985-11-21
  10003 | Parto      | Bamford   | 1986-12-01
  10004 | Chirstian  | Koblick   | 1986-12-01
  10005 | Kyoichi    | Maliniak  | 1989-09-12
(5 rows)
```

### 3.5 Resumen consolidado de verificaciones

| Verificación | Resultado |
|---|---|
| Conteo de filas por tabla (6 tablas) | Coinciden exactamente (3,919,015 filas totales) |
| Checksum MD5 por fila de `employees` | 300,024 hashes idénticos, 0 diferencias |
| Registros huérfanos en las 6 claves foráneas | 0 huérfanos |
| Muestra de datos (`employees`, primeras 5 filas) | Contenido idéntico |
| Vistas migradas y con datos | 2 vistas, 300,024 filas cada una |

Todas las verificaciones se consolidaron en el archivo adjunto `verificacion_final.txt`.

---

## V. Incidencias encontradas y soluciones

| Incidencia | Causa | Solución |
|---|---|---|
| `ERROR: could not resize shared memory segment "/PostgreSQL.XXX" to 8388608 bytes: No space left on device` | Una consulta con 6 `UNION ALL` combinados con `LEFT JOIN` sobre tablas de millones de filas (`salaries`: 2.8M) agotó la memoria compartida de PostgreSQL | Dividir la verificación de huérfanos en 6 consultas independientes, una por cada clave foránea (sección IV.3.3) |
| `mariadb-dump: Got error: 1045: Access denied for user 'root'@'172.18.0.1'` | La conexión con `-h 127.0.0.1` desde fuera del contenedor llegó a MariaDB con la IP de la red Docker (`172.18.0.1`), no autorizada para `root` | Ejecutar el comando con las credenciales correctas o directamente dentro del contenedor con `docker exec` |
| Diferencia inicial al intentar comparar checksums de toda la tabla con `GROUP_CONCAT`/`STRING_AGG` | `STRING_AGG` (PostgreSQL) y `GROUP_CONCAT` (MariaDB) usan algoritmos distintos, y `GROUP_CONCAT` tiene un límite por defecto de 1024 caracteres | Calcular el MD5 **por fila** en lugar de un solo hash agregado de toda la tabla, y comparar los 300,024 valores línea por línea con `diff` |
| Archivo `verificacion_final.txt` no encontrado inicialmente | El archivo aún no se había generado | Crearlo concatenando con `echo` y redirecciones (`>>`) cada sección de la verificación |

---

## VI. Backup de la base de datos

### 6.1 Backup binario (formato custom)

```bash
docker exec postgresql pg_dump -U ruben -d employees -Fc -f /tmp/employees_backup.dump
docker exec postgresql ls -lh /tmp/employees_backup.dump
```
```
-rw-r--r-- 1 root root 35M ... /tmp/employees_backup.dump
```

```bash
docker cp postgresql:/tmp/employees_backup.dump ~/employees_backup.dump
ls -lh ~/employees_backup.dump
```
```
-rw-r--r-- 1 ruben ruben 35M ... /home/ruben/employees_backup.dump
```

### 6.2 Backup en SQL plano

```bash
docker exec postgresql pg_dump -U ruben -d employees > ~/employees_backup.sql
ls -lh ~/employees_backup.sql
```
```
-rw-r--r-- 1 ruben ruben 135M ... /home/ruben/employees_backup.sql
```

### 6.3 Verificación del contenido del backup

```bash
docker exec postgresql pg_restore -l /tmp/employees_backup.dump | head -30
```

```
; Archive created at 2026-09-28 17:20:25 -04
;     dbname: employees
;     TOC Entries: 35
;     Compression: gzip
;     Dump Version: 1.16-0
;     Format: CUSTOM
;     Integer: 4 bytes
;     Offset: 8 bytes
;     Dumped from database version: 18.6
;     Dumped by pg_dump version: 18.6
;
; Selected TOC Entries:
;
6; 2615 16825 SCHEMA - employees ruben
222; 1259 16826 TABLE employees departments ruben
223; 1259 16831 TABLE employees dept_emp ruben
224; 1259 16838 TABLE employees dept_manager ruben
225; 1259 16845 TABLE employees employees ruben
226; 1259 16856 TABLE employees salaries ruben
227; 1259 16863 TABLE employees titles ruben
228; 1259 17010 VIEW public dept_emp_latest_date ruben
229; 1259 17014 VIEW public current_dept_emp ruben
3489; 0 16826 TABLE DATA employees departments ruben
3490; 0 16831 TABLE DATA employees dept_emp ruben
3491; 0 16838 TABLE DATA employees dept_manager ruben
3492; 0 16845 TABLE DATA employees employees ruben
3493; 0 16856 TABLE DATA employees salaries ruben
3494; 0 16863 TABLE DATA employees titles ruben
```

El backup incluye las 6 tablas con sus datos y las 2 vistas migradas.

---

## VII. Conclusiones

- Los **datos** de las 6 tablas de `employees` se verificaron migrados por completo: los conteos de filas coinciden exactamente entre MariaDB y PostgreSQL, con un total de 3,919,015 registros.
- El checksum MD5 calculado fila por fila sobre la tabla `employees` (300,024 filas) no mostró ninguna diferencia, confirmando que el contenido se migró sin alteraciones ni truncamientos.
- Las **2 vistas** de MariaDB (`dept_emp_latest_date` y `current_dept_emp`) se adaptaron y recrearon en PostgreSQL, respetando el orden de dependencia entre ellas, y ambas devuelven los mismos 300,024 registros.
- La verificación de **integridad referencial** en las 6 claves foráneas no encontró registros huérfanos, lo que confirma que las relaciones entre tablas se preservaron correctamente.
- Se generó un backup de la base `employees` en dos formatos (`.dump` binario y `.sql` plano), verificado con `pg_restore -l`, que incluye tablas, datos y vistas.

---

## VIII. Archivos adjuntos

| Archivo | Contenido |
|---|---|
| `README.md` | Este informe |
| `employees_backup.dump` | Backup binario (formato custom) de la base `employees`, 35 MB |
| `employees_backup.sql` | Backup en SQL plano de la base `employees`, 135 MB |
| `employees_estructura_mariadb.sql` | Estructura original exportada de MariaDB |
| `employees_estructura_postgresql.sql` | DDL adaptado a PostgreSQL (Actividad 5) |
| `vistas_postgresql.sql` | Script de las vistas adaptadas |
| `vistas_mariadb.txt` | Definición original de las vistas en MariaDB |
| `verificacion_conteos_mariadb.txt` | Salida del conteo de filas en MariaDB |
| `verificacion_conteos_postgresql.txt` | Salida del conteo de filas en PostgreSQL |
| `md5_mariadb.txt` | 300,024 hashes MD5 calculados en MariaDB |
| `md5_postgresql.txt` | 300,024 hashes MD5 calculados en PostgreSQL |
| `verificacion_final.txt` | Verificación consolidada (conteos, MD5, huérfanos, vistas, muestra) |

## IX. Referencias

- PostgreSQL Documentation: [pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html)
- PostgreSQL Documentation: [pg_restore](https://www.postgresql.org/docs/current/app-pgrestore.html)
- PostgreSQL Documentation: [CREATE VIEW](https://www.postgresql.org/docs/current/sql-createview.html)
- PostgreSQL Documentation: [MD5](https://www.postgresql.org/docs/current/functions-binarystring.html)
- MariaDB Documentation: [SHOW CREATE VIEW](https://mariadb.com/kb/en/show-create-view/)
- MariaDB Documentation: [GROUP_CONCAT](https://mariadb.com/kb/en/group_concat/)
