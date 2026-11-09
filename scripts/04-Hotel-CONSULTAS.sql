--consulta 1: consultar el ranking de reservaciones por huésped
SELECT
    ID_Huesped,
    ID_Reservacion,
    Estado,
    Fecha_Inicio,
    Fecha_Fin,
    ROW_NUMBER() OVER (
        PARTITION BY ID_Huesped
        ORDER BY Fecha_Inicio DESC, ID_Reservacion DESC
    ) AS Numero_Reservacion
FROM Reservacion;

--INDICE PROPUESTO:

CREATE NONCLUSTERED INDEX IX_Reservacion_Huesped_Fecha
ON Reservacion (
    ID_Huesped,
    Fecha_Inicio DESC,
    ID_Reservacion DESC
)
INCLUDE (
    Estado,
    Fecha_Fin
);


--consulta 2: último servicio realizado por cada empleado.

WITH ServiciosEmpleado AS (
    SELECT
        ID_Empleado,
        ID_HistorialServicios,
        ID_Servicio,
        ID_Estadia,
        Fecha_servicio,
        ROW_NUMBER() OVER (
            PARTITION BY ID_Empleado
            ORDER BY Fecha_servicio DESC,
                     ID_HistorialServicios DESC
        ) AS NumeroServicio
    FROM HistorialServicios
)
SELECT
    ID_Empleado,
    ID_HistorialServicios,
    ID_Servicio,
    ID_Estadia,
    Fecha_servicio
FROM ServiciosEmpleado
WHERE NumeroServicio = 1;

--INDICE PROPUESTO:

CREATE NONCLUSTERED INDEX IX_HistorialServicios_Empleado_Fecha
ON HistorialServicios (
    ID_Empleado,
    Fecha_servicio DESC,
    ID_HistorialServicios DESC
)
INCLUDE (
    ID_Servicio,
    ID_Estadia
);

--consulta 3: nómina acumulada por empleado

SELECT
    ID_Empleado,
    ID_Salario,
    Fecha_Pago,
    Metodo_Pago,
    Monto,
    SUM(Monto) OVER (
        PARTITION BY ID_Empleado
        ORDER BY Fecha_Pago, ID_Salario
        ROWS BETWEEN UNBOUNDED PRECEDING
        AND CURRENT ROW
    ) AS Nomina_Acumulada
FROM PagoNomina;


--INDICE PROPUESTO

CREATE NONCLUSTERED INDEX IX_PagoNomina_Empleado_Fecha
ON PagoNomina (
    ID_Empleado,
    Fecha_Pago,
    ID_Salario
)
INCLUDE (
    Monto,
    Metodo_Pago,
    IVA
);
