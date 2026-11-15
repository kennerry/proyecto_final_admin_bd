# Administracion de Bases de Datos

## Descripción

Este proyecto implementa una base de datos para la administración de uno o varios hoteles mediante Microsoft SQL Server.

Se incluyen las operaciones relacionadas con:

- Hoteles y habitaciones.
- Huéspedes y reservaciones.
- Estadías y servicios.
- Facturación y detalle de cargos.
- Empleados y pagos de nómina.
- Consultas operativas y de rendimiento.
- Reportes mediante Power BI.
- Auditoría y respaldos de la información.

La base de datos se denomina `Hotel` y utiliza los esquemas `Operaciones`, `Finanzas`, `Auditoria` y `BI`.

## Tecnologías

- Microsoft SQL Server 2025 Developer.
- SQL Server Agent.
- Docker y Docker Compose.
- Mailpit para pruebas de correo.
- Power BI Desktop.
- SQL Server Management Studio (SSMS).

## Estructura del proyecto

```text
.
├── diagramas/
│   ├── Diagrama_Entidad_Relacion.png
│   └── Diagrama_Relacional_Normalizado.png
├── docker/
│   ├── comandos.txt
│   └── docker-compose.yml
├── power-bi/
│   ├── dashboard-hotel.pbix
│   └── theme/Theme.json
└── scripts/
    ├── 01-Hotel-DDL.sql
    ├── 02-Hotel-Containment.sql
    ├── 03-Hotel-DML-Inserts.sql
    ├── 04-Hotel-Seguridad.sql
    ├── 05-Hotel-BI.sql
    ├── 06-Hotel-Consultas.sql
    ├── 07-Hotel-Dimensionamiento.sql
    ├── 08-Hotel-Auditoria.sql
    ├── 10-Hotel-Simulacion-Cobertura-Deuda.sql
    ├── Utils.sql
    └── backup/
```

## Requisitos

Antes de iniciar, se requiere contar con:

- Docker Desktop en ejecución.
- Una herramienta para conectarse a SQL Server, como SSMS o Azure Data Studio.
- Power BI Desktop para consultar el dashboard.

## Instalación y configuración

### Inicio de los contenedores

Desde la carpeta raíz del proyecto, se deben ejecutar los siguientes comandos:

```powershell
docker compose -f docker\docker-compose.yml up -d
```

Para permitir la escritura de respaldos en el contenedor de SQL Server:

```powershell
docker exec -u 0 sqlserver-2025 bash -c "chown -R 10001:0 /backup && chmod -R 770 /backup"
```

### Datos de conexión

| Parámetro     | Valor            |
| ------------- | ---------------- |
| Servidor      | `localhost,1434` |
| Usuario       | `sa`             |
| Contraseña    | `Admin123!`      |
| Base de datos | `Hotel`          |

También se puede utilizar `sqlcmd`:

```powershell
sqlcmd -S localhost,1434 -U sa -P "Admin123!" -C
```

Mailpit se encuentra disponible en <http://localhost:8025>.

## Ejecución de los scripts

Los scripts deben ejecutarse en el orden indicado:

1. `scripts\Utils.sql`  
   Habilita la autenticación de bases de datos contenidas.
2. `scripts\01-Hotel-DDL.sql`  
   Crea la base de datos, tablas, restricciones, relaciones y triggers.
3. `scripts\02-Hotel-Containment.sql`  
   Configura la base de datos como parcialmente contenida.
4. `scripts\03-Hotel-DML-Inserts.sql`  
   Inserta los datos de prueba.
5. `scripts\04-Hotel-Seguridad.sql`  
   Crea esquemas, roles, usuarios, logins y permisos.
6. `scripts\05-Hotel-BI.sql`  
   Crea las vistas utilizadas por Power BI.
7. `scripts\06-Hotel-Consultas.sql`  
   Incluye consultas operativas e índices no agrupados.
8. `scripts\07-Hotel-Dimensionamiento.sql`  
   Configura el tamaño y crecimiento de los archivos de la base de datos.
9. `scripts\08-Hotel-Auditoria.sql`  
   Configura la auditoría del servidor y de la base de datos.
10. `scripts\10-Hotel-Simulacion-Cobertura-Deuda.sql`  
    Ejecuta una simulación financiera opcional.

## Respaldos

Los scripts ubicados en `scripts\backup\` permiten configurar el modelo de recuperación, los respaldos y los jobs de SQL Server Agent.

Se deben de ejecutar después de crear y cargar la base de datos:

1. `01-Hotel-Backups_Config.sql`: configura el modelo de recuperación completo y crea respaldos iniciales.
2. `02-Operador_Backup.sql`: crea el operador de notificaciones.
3. `03-Mail_Config.sql`: configura Database Mail con Mailpit.
4. `04-Job_Diff_6Horas.sql`: configura respaldos diferenciales cada seis horas.
5. `05-Job_Full_Semanal.sql`: configura respaldos completos semanales.
6. `06-Job_Log_45Minutos.sql`: configura respaldos del log.
7. `07-Hotel-Sentencias_Restauracion_Backup.sql`: contiene sentencias de restauración.

Los archivos de respaldo se almacenan dentro del contenedor en `/var/opt/mssql/backup/`.

## Seguridad y auditoría

Se definen los siguientes roles:

| Rol                      | Función                                                          |
| ------------------------ | ---------------------------------------------------------------- |
| `Rol_Recepcionista`      | Administración de operaciones y consulta de facturas.            |
| `Rol_Contador`           | Administración de información financiera.                        |
| `Rol_AdministradorHotel` | Administración general de operaciones, finanzas, auditoría y BI. |
| `Rol_AnalistaBI`         | Consulta de las vistas del esquema `BI`.                         |
| `Rol_Auditor`            | Consulta y ejecución de objetos del esquema de auditoría.        |

El script de seguridad crea los usuarios `usr_recepcion`, `usr_contabilidad`, `usr_gerente`, `usr_analistaBI` y `usr_auditor`.

El módulo de auditoría registra:

- Inicios de sesión exitosos y fallidos.
- Operaciones realizadas en los esquemas principales.
- Cambios en los montos de facturas.
- Cambios en los montos de pagos de nómina.

## Power BI

El archivo `power-bi\dashboard-hotel.pbix` utiliza las vistas del esquema `BI`, entre ellas:

- `BI.v_AnalisisResumenEjecutivo`.
- `BI.v_AnalisisFinanciero`.
- `BI.v_AnalisisReservaciones`.
- Vistas de habitaciones y ocupación.
- Vistas de servicios.
- Vistas de recursos humanos y nómina.

## Diagramas

- [Diagrama entidad-relación](diagramas/Diagrama_Entidad_Relacion.png)
- [Diagrama relacional normalizado](diagramas/Diagrama_Relacional_Normalizado.png)
