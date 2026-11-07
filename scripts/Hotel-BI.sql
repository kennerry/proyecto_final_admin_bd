-- Vistas que consume el Dashboard de Power BI
USE Hotel;
GO

-- Pag 1: Resumen Ejecutivo
CREATE VIEW v_AnalisisResumenEjecutivo
AS
WITH DetallesFactura AS
(
    SELECT
        ID_Factura,
        SUM(Precio_Subtotal) AS Total_Detalles,
        COUNT(ID_Detalle) AS Cantidad_Detalles
    FROM dbo.Detalle
    GROUP BY ID_Factura
),
HabitacionesEstadia AS
(
    SELECT
        ID_Estadia,
        COUNT(*) AS Cantidad_Habitaciones
    FROM dbo.RegistroHabitaciones
    GROUP BY ID_Estadia
),
ServiciosEstadia AS
(
    SELECT
        ID_Estadia,
        COUNT(*) AS Cantidad_Servicios
    FROM dbo.HistorialServicios
    GROUP BY ID_Estadia
)
SELECT
    F.ID_Factura,
    F.Fecha_factura,
    YEAR(F.Fecha_factura) AS Anio,
    MONTH(F.Fecha_factura) AS Mes,
    DATENAME(MONTH, F.Fecha_factura) AS Nombre_Mes,
    DATEFROMPARTS(
        YEAR(F.Fecha_factura),
        MONTH(F.Fecha_factura),
        1
    ) AS Inicio_Mes,

    F.Precio_total AS Total_Factura,

    DF.Total_Detalles,
    DF.Cantidad_Detalles,

    E.ID_Estadia,
    R.ID_Reservacion,
    R.Estado AS Estado_Reservacion,

    H.ID_Huesped,
    H.Nombre AS Nombre_Huesped,

    R.Cantidad_Personas,

    ISNULL(HE.Cantidad_Habitaciones, 0)
        AS Cantidad_Habitaciones,

    ISNULL(SE.Cantidad_Servicios, 0)
        AS Cantidad_Servicios

FROM dbo.Factura F
INNER JOIN dbo.Estadia E
    ON F.ID_Estadia = E.ID_Estadia
INNER JOIN dbo.Reservacion R
    ON E.ID_Reservacion = R.ID_Reservacion
INNER JOIN dbo.Huesped H
    ON R.ID_Huesped = H.ID_Huesped

LEFT JOIN DetallesFactura DF
    ON F.ID_Factura = DF.ID_Factura

LEFT JOIN HabitacionesEstadia HE
    ON E.ID_Estadia = HE.ID_Estadia

LEFT JOIN ServiciosEstadia SE
    ON E.ID_Estadia = SE.ID_Estadia;
GO

-- Pag 2: Analisis Financiero
CREATE VIEW dbo.v_AnalisisFinanciero
AS
SELECT
    D.ID_Detalle,
    D.ID_Factura,

    F.Fecha_factura,
    YEAR(F.Fecha_factura) AS Anio,
    MONTH(F.Fecha_factura) AS Mes,
    DATENAME(MONTH, F.Fecha_factura) AS Nombre_Mes,
    DATEFROMPARTS(
        YEAR(F.Fecha_factura),
        MONTH(F.Fecha_factura),
        1
    ) AS Inicio_Mes,

    F.ID_Estadia,
    R.ID_Reservacion,
    H.ID_Huesped,
    H.Nombre AS Nombre_Huesped,

    D.Descripcion,
    D.Cantidad,
    D.Precio_Unitario,
    D.Precio_Subtotal AS Ingreso_Detalle,

    CASE
        WHEN D.ID_Registro IS NOT NULL
            THEN 'HABITACION'
        WHEN D.ID_HistorialServicios IS NOT NULL
            THEN 'SERVICIO'
    END AS Tipo_Ingreso,

    RH.Numero AS Numero_Habitacion,
    HAB.Tipo AS Tipo_Habitacion,

    S.ID_Servicio,
    S.Nombre AS Nombre_Servicio,
    S.Tipo AS Categoria_Servicio,

    HS.ID_Empleado,
    EMP.Nombre AS Nombre_Empleado,

    COALESCE(HOT_HAB.ID_Hotel, HOT_EMP.ID_Hotel)
        AS ID_Hotel,

    COALESCE(HOT_HAB.Nombre, HOT_EMP.Nombre)
        AS Nombre_Hotel

FROM dbo.Detalle D

INNER JOIN dbo.Factura F
    ON D.ID_Factura = F.ID_Factura

INNER JOIN dbo.Estadia E
    ON F.ID_Estadia = E.ID_Estadia

INNER JOIN dbo.Reservacion R
    ON E.ID_Reservacion = R.ID_Reservacion

INNER JOIN dbo.Huesped H
    ON R.ID_Huesped = H.ID_Huesped

LEFT JOIN dbo.RegistroHabitaciones RH
    ON D.ID_Registro = RH.ID_Registro

LEFT JOIN dbo.Habitacion HAB
    ON RH.Numero = HAB.Numero
   AND RH.ID_Hotel = HAB.ID_Hotel

LEFT JOIN dbo.Hotel HOT_HAB
    ON HAB.ID_Hotel = HOT_HAB.ID_Hotel

LEFT JOIN dbo.HistorialServicios HS
    ON D.ID_HistorialServicios = HS.ID_HistorialServicios

LEFT JOIN dbo.Servicio S
    ON HS.ID_Servicio = S.ID_Servicio

LEFT JOIN dbo.Empleado EMP
    ON HS.ID_Empleado = EMP.ID_Empleado

LEFT JOIN dbo.Hotel HOT_EMP
    ON EMP.ID_Hotel = HOT_EMP.ID_Hotel;
GO

-- Pag 3: Reservaciones y Estadias
CREATE VIEW dbo.v_AnalisisReservaciones
AS
WITH EstadiasReservacion AS
(
    SELECT
        ID_Reservacion,
        COUNT(ID_Estadia) AS Cantidad_Estadias
    FROM dbo.Estadia
    GROUP BY ID_Reservacion
)
SELECT
    R.ID_Reservacion,
    R.Estado,

    R.Fecha_Inicio,
    R.Fecha_Fin,

    YEAR(R.Fecha_Inicio) AS Anio,
    MONTH(R.Fecha_Inicio) AS Mes,
    DATENAME(MONTH, R.Fecha_Inicio) AS Nombre_Mes,

    DATEFROMPARTS(
        YEAR(R.Fecha_Inicio),
        MONTH(R.Fecha_Inicio),
        1
    ) AS Inicio_Mes,

    DATEDIFF(
        DAY,
        R.Fecha_Inicio,
        R.Fecha_Fin
    ) AS Noches_Reservadas,

    R.Cantidad_Personas,

    H.ID_Huesped,
    H.Nombre AS Nombre_Huesped,
    H.Correo,
    H.Telefono,

    ISNULL(ER.Cantidad_Estadias, 0)
        AS Cantidad_Estadias,

    CASE
        WHEN R.Estado = 'COMPLETADA' THEN 1
        ELSE 0
    END AS Es_Completada,

    CASE
        WHEN R.Estado = 'CANCELADA' THEN 1
        ELSE 0
    END AS Es_Cancelada,

    CASE
        WHEN R.Estado = 'PENDIENTE' THEN 1
        ELSE 0
    END AS Es_Pendiente

FROM dbo.Reservacion R

INNER JOIN dbo.Huesped H
    ON R.ID_Huesped = H.ID_Huesped

LEFT JOIN EstadiasReservacion ER
    ON R.ID_Reservacion = ER.ID_Reservacion;
GO

-- Pag 4: Habitaciones y Ocupacion
CREATE VIEW dbo.v_AnalisisHabitaciones
AS

-- Registros de ocupación
SELECT
    'OCUPACION' AS Tipo_Registro,

    RH.ID_Registro,
    RH.ID_Estadia,

    RH.Numero AS Numero_Habitacion,
    RH.ID_Hotel,

    H.Nombre AS Nombre_Hotel,
    HAB.Tipo AS Tipo_Habitacion,
    HAB.Tamaño,
    HAB.Camas,
    HAB.Baños,
    HAB.Precio AS Precio_Habitacion,

    R.ID_Reservacion,
    R.Estado AS Estado_Reservacion,
    R.ID_Huesped,

    E.Fecha_Entrada,
    E.Fecha_Salida,

    R.Fecha_Inicio AS Fecha_Inicio_Reservada,
    R.Fecha_Fin AS Fecha_Fin_Reservada,

    DATEDIFF(
        DAY,
        E.Fecha_Entrada,
        E.Fecha_Salida
    ) AS Noches_Ocupadas,

    RH.Precio_Subtotal AS Ingreso_Habitacion,

    CONCAT(
        RH.ID_Hotel,
        '-',
        RH.Numero
    ) AS Clave_Habitacion

FROM dbo.RegistroHabitaciones RH

INNER JOIN dbo.Habitacion HAB
    ON RH.Numero = HAB.Numero
   AND RH.ID_Hotel = HAB.ID_Hotel

INNER JOIN dbo.Hotel H
    ON RH.ID_Hotel = H.ID_Hotel

INNER JOIN dbo.Estadia E
    ON RH.ID_Estadia = E.ID_Estadia

INNER JOIN dbo.Reservacion R
    ON E.ID_Reservacion = R.ID_Reservacion

UNION ALL

-- Inventario completo de habitaciones
SELECT
    'INVENTARIO' AS Tipo_Registro,

    CAST(NULL AS INT) AS ID_Registro,
    CAST(NULL AS INT) AS ID_Estadia,

    HAB.Numero AS Numero_Habitacion,
    HAB.ID_Hotel,

    H.Nombre AS Nombre_Hotel,
    HAB.Tipo AS Tipo_Habitacion,
    HAB.Tamaño,
    HAB.Camas,
    HAB.Baños,
    HAB.Precio AS Precio_Habitacion,

    CAST(NULL AS INT) AS ID_Reservacion,
    CAST(NULL AS VARCHAR(20)) AS Estado_Reservacion,
    CAST(NULL AS INT) AS ID_Huesped,

    CAST(NULL AS DATE) AS Fecha_Entrada,
    CAST(NULL AS DATE) AS Fecha_Salida,

    CAST(NULL AS DATE) AS Fecha_Inicio_Reservada,
    CAST(NULL AS DATE) AS Fecha_Fin_Reservada,

    CAST(0 AS INT) AS Noches_Ocupadas,
    CAST(0 AS DECIMAL(18,2)) AS Ingreso_Habitacion,

    CONCAT(
        HAB.ID_Hotel,
        '-',
        HAB.Numero
    ) AS Clave_Habitacion

FROM dbo.Habitacion HAB

INNER JOIN dbo.Hotel H
    ON HAB.ID_Hotel = H.ID_Hotel;
GO

-- Pag 5: Analisis de Servicios
CREATE VIEW dbo.v_AnalisisServicios
AS
WITH FacturacionServicio AS
(
    SELECT
        D.ID_HistorialServicios,

        SUM(D.Precio_Subtotal)
            AS Ingreso_Facturado,

        SUM(D.Cantidad)
            AS Unidades_Facturadas,

        COUNT(D.ID_Detalle)
            AS Cantidad_Detalles,

        MIN(F.Fecha_factura)
            AS Primera_Fecha_Factura,

        MAX(F.Fecha_factura)
            AS Ultima_Fecha_Factura

    FROM dbo.Detalle D

    INNER JOIN dbo.Factura F
        ON D.ID_Factura = F.ID_Factura

    WHERE D.ID_HistorialServicios IS NOT NULL

    GROUP BY
        D.ID_HistorialServicios
)
SELECT
    HS.ID_HistorialServicios,

    HS.Fecha_servicio,

    YEAR(HS.Fecha_servicio) AS Anio,
    MONTH(HS.Fecha_servicio) AS Mes,
    DATENAME(MONTH, HS.Fecha_servicio) AS Nombre_Mes,

    DATEFROMPARTS(
        YEAR(HS.Fecha_servicio),
        MONTH(HS.Fecha_servicio),
        1
    ) AS Inicio_Mes,

    HS.ID_Estadia,
    R.ID_Reservacion,
    R.Estado AS Estado_Reservacion,

    H.ID_Huesped,
    H.Nombre AS Nombre_Huesped,

    S.ID_Servicio,
    S.Nombre AS Nombre_Servicio,
    S.Tipo AS Categoria_Servicio,
    S.Precio_Unitario AS Precio_Catalogo,

    HS.ID_Empleado,
    EMP.Nombre AS Nombre_Empleado,
    EMP.Cargo,

    EMP.ID_Hotel,
    HOT.Nombre AS Nombre_Hotel,

    ISNULL(FS.Ingreso_Facturado, 0)
        AS Ingreso_Facturado,

    ISNULL(FS.Unidades_Facturadas, 0)
        AS Unidades_Facturadas,

    ISNULL(FS.Cantidad_Detalles, 0)
        AS Cantidad_Detalles,

    FS.Primera_Fecha_Factura,
    FS.Ultima_Fecha_Factura

FROM dbo.HistorialServicios HS

INNER JOIN dbo.Estadia E
    ON HS.ID_Estadia = E.ID_Estadia

INNER JOIN dbo.Reservacion R
    ON E.ID_Reservacion = R.ID_Reservacion

INNER JOIN dbo.Huesped H
    ON R.ID_Huesped = H.ID_Huesped

INNER JOIN dbo.Servicio S
    ON HS.ID_Servicio = S.ID_Servicio

INNER JOIN dbo.Empleado EMP
    ON HS.ID_Empleado = EMP.ID_Empleado

INNER JOIN dbo.Hotel HOT
    ON EMP.ID_Hotel = HOT.ID_Hotel

LEFT JOIN FacturacionServicio FS
    ON HS.ID_HistorialServicios =
       FS.ID_HistorialServicios;
GO

-- Pag 6: RRHH y Nomina
CREATE VIEW dbo.v_AnalisisRecursosHumanos
AS
SELECT
    EMP.ID_Empleado,
    EMP.Nombre AS Nombre_Empleado,
    EMP.Correo,
    EMP.Cargo,

    EMP.Hora_Entrada,
    EMP.Hora_Salida,

    EMP.ID_Hotel,
    HOT.Nombre AS Nombre_Hotel,

    EMP.ID_Supervisor,
    SUP.Nombre AS Nombre_Supervisor,

    PN.ID_Salario,
    PN.Monto AS Monto_Nomina,
    PN.Fecha_Pago,

    YEAR(PN.Fecha_Pago) AS Anio,
    MONTH(PN.Fecha_Pago) AS Mes,
    DATENAME(MONTH, PN.Fecha_Pago) AS Nombre_Mes,

    DATEFROMPARTS(
        YEAR(PN.Fecha_Pago),
        MONTH(PN.Fecha_Pago),
        1
    ) AS Inicio_Mes,

    PN.Metodo_Pago,
    PN.IVA

FROM dbo.Empleado EMP

INNER JOIN dbo.Hotel HOT
    ON EMP.ID_Hotel = HOT.ID_Hotel

LEFT JOIN dbo.Empleado SUP
    ON EMP.ID_Supervisor = SUP.ID_Empleado

LEFT JOIN dbo.PagoNomina PN
    ON EMP.ID_Empleado = PN.ID_Empleado;
GO

