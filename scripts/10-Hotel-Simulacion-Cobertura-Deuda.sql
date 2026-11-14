USE Hotel;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;


DECLARE @Guardar bit = 1;
DECLARE @Inicio date = '20260101', @Fin date = '20270101';
DECLARE @Deuda decimal(19,2) = 1000000.00;
DECLARE @Nomina decimal(19,2), @Base decimal(19,2), @Meta decimal(19,2);
DECLARE @Facturacion decimal(19,2), @MesesNomina int, @Nuevas int = 0;
DECLARE @Marcador varchar(40) = '[Simulacion deuda 2026] ';
DECLARE @Bloqueo int;

BEGIN TRY
    BEGIN TRANSACTION;
    EXEC @Bloqueo = sys.sp_getapplock
        @Resource = 'Hotel.SimulacionCoberturaDeuda.2026',
        @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
    IF @Bloqueo < 0
        THROW 50001, 'No se obtuvo el bloqueo del escenario.', 1;
    IF OBJECT_ID('BI.v_SimulacionCoberturaDeuda', 'V') IS NOT NULL
        THROW 50002, 'El escenario ya se guardo en esta base.', 1;

    SELECT @MesesNomina = COUNT(DISTINCT MONTH(Fecha_Pago)),
           @Nomina = SUM(Monto)
    FROM Finanzas.PagoNomina
    WHERE Fecha_Pago >= @Inicio AND Fecha_Pago < @Fin;
    IF @MesesNomina = 0
        THROW 50003, 'Falta la nomina de 2026 para calcular la meta.', 1;

    SET @Nomina = ROUND(@Nomina * 12 / @MesesNomina, 2);
    SET @Meta = @Nomina + @Deuda;
    SELECT @Base = COALESCE(SUM(Precio_total), 0)
    FROM Finanzas.Factura
    WHERE Fecha_factura >= @Inicio AND Fecha_factura < @Fin;
    SET @Facturacion = @Base;

    -- Consumos simulados a precios de catalogo, por persona o por estadia.
    DECLARE @Paquete table (
        Servicio int PRIMARY KEY, Nombre varchar(250), Precio decimal(10,2),
        PorNoche bit, PorPersona bit
    );
    INSERT @Paquete
    SELECT ID_Servicio, Nombre, Precio_Unitario,
        CASE WHEN Nombre IN ('Restaurante', 'Cafeteria') THEN 1 ELSE 0 END,
        CASE WHEN Nombre IN ('Restaurante', 'Cafeteria', 'SPA') THEN 1 ELSE 0 END
    FROM Operaciones.Servicio
    WHERE Nombre IN ('Restaurante', 'Cafeteria', 'SPA', 'Lavanderia');
    IF (SELECT COUNT(*) FROM @Paquete) <> 4
        THROW 50004, 'Faltan servicios del catalogo para el escenario.', 1;

    DECLARE @Reservas table (
        Huesped int NOT NULL, Entrada date NOT NULL, Salida date NOT NULL,
        INDEX IX_Reservas NONCLUSTERED (Huesped, Entrada, Salida)
    );
    INSERT @Reservas
    SELECT ID_Huesped, Fecha_Inicio, Fecha_Fin
    FROM Operaciones.Reservacion
    WHERE Estado <> 'CANCELADA' AND Fecha_Inicio < @Fin AND Fecha_Fin > @Inicio;

    DECLARE @Cuartos table (
        Hotel int, Numero int, Entrada date, Salida date,
        INDEX IX_Cuartos NONCLUSTERED (Hotel, Numero, Entrada, Salida)
    );
    INSERT @Cuartos
    SELECT rh.ID_Hotel, rh.Numero,
        COALESCE(e.Fecha_Entrada, r.Fecha_Inicio), COALESCE(e.Fecha_Salida, r.Fecha_Fin)
    FROM Operaciones.RegistroHabitaciones rh
    JOIN Operaciones.Estadia e ON e.ID_Estadia = rh.ID_Estadia
    JOIN Operaciones.Reservacion r ON r.ID_Reservacion = e.ID_Reservacion
    WHERE r.Estado <> 'CANCELADA';

    DECLARE @Huespedes table (Id int PRIMARY KEY, Usos int NOT NULL);
    INSERT @Huespedes SELECT ID_Huesped, 0 FROM Operaciones.Huesped;

    DECLARE @Hotel int, @Habitacion int, @Empleado int, @Huesped int, @Personas int;
    DECLARE @Tarifa decimal(10,2), @Hospedaje decimal(10,2), @Total decimal(10,2);
    DECLARE @Entrada date, @Salida date, @Noches int;
    DECLARE @Reserva int, @Estadia int, @Registro int, @Factura int;
    DECLARE @Consumos table (Historial int, Servicio int);

    -- Repartir las oportunidades a lo largo de 2026 con bloques de 3 o 4 noches.
    -- El orden alterna meses para distribuir la simulacion en todo el anio.
    DECLARE candidatos CURSOR LOCAL FAST_FORWARD FOR
    WITH Dias AS (
        SELECT @Inicio AS Dia
        UNION ALL
        SELECT DATEADD(day, 1, Dia) FROM Dias WHERE Dia < DATEADD(day, -2, @Fin)
    ),
    Habitaciones AS (
        SELECT h.ID_Hotel, h.Numero, h.Precio, h.Tipo,
            ROW_NUMBER() OVER (ORDER BY h.ID_Hotel, h.Numero) AS Orden,
            e.Empleado
        FROM Operaciones.Habitacion h
        CROSS APPLY (
            SELECT MIN(ID_Empleado) AS Empleado
            FROM Finanzas.Empleado
            WHERE ID_Hotel = h.ID_Hotel AND Cargo = 'EMPLEADO'
        ) e
        WHERE e.Empleado IS NOT NULL
    )
    SELECT d.Dia, h.ID_Hotel, h.Numero, h.Precio, h.Empleado,
        CASE WHEN h.Tipo = 'INDIVIDUAL' THEN 1 ELSE 2 END,
        CASE WHEN h.Orden % 2 = 0 THEN 3 ELSE 4 END
    FROM Dias d CROSS JOIN Habitaciones h
    WHERE (DATEDIFF(day, @Inicio, d.Dia) + h.Orden) % 4 = 0
    ORDER BY DAY(d.Dia), MONTH(d.Dia), h.Numero, h.ID_Hotel
    OPTION (MAXRECURSION 366);

    OPEN candidatos;
    FETCH NEXT FROM candidatos INTO @Entrada, @Hotel, @Habitacion, @Tarifa, @Empleado, @Personas, @Noches;
    WHILE @@FETCH_STATUS = 0 AND @Facturacion < @Meta
    BEGIN
        SET @Salida = DATEADD(day, @Noches, @Entrada);
        IF @Salida < @Fin AND NOT EXISTS (
            SELECT 1 FROM @Cuartos
            WHERE Hotel = @Hotel AND Numero = @Habitacion
              AND Entrada < @Salida AND Salida > @Entrada
        )
        BEGIN
            SET @Huesped = NULL;
            SELECT TOP (1) @Huesped = h.Id
            FROM @Huespedes h
            WHERE NOT EXISTS (
                SELECT 1 FROM @Reservas r
                WHERE r.Huesped = h.Id AND r.Entrada < @Salida AND r.Salida > @Entrada
            )
            ORDER BY h.Usos, h.Id;

            IF @Huesped IS NOT NULL
            BEGIN
                SET @Hospedaje = @Tarifa * @Noches;
                SELECT @Total = @Hospedaje + SUM(Precio *
                    CASE WHEN PorNoche = 1 THEN @Noches ELSE 1 END *
                    CASE WHEN PorPersona = 1 THEN @Personas ELSE 1 END)
                FROM @Paquete;

                INSERT Operaciones.Reservacion (Estado, Cantidad_Personas, Fecha_Inicio, Fecha_Fin, ID_Huesped)
                VALUES ('COMPLETADA', @Personas, @Entrada, @Salida, @Huesped);
                SET @Reserva = SCOPE_IDENTITY();

                INSERT Operaciones.Estadia (Fecha_Entrada, Fecha_Salida, Hora_Entrada, Hora_Salida, ID_Reservacion)
                VALUES (@Entrada, @Salida, '15:00', '10:00', @Reserva);
                SET @Estadia = SCOPE_IDENTITY();

                INSERT Operaciones.RegistroHabitaciones (Precio_Subtotal, ID_Estadia, Numero, ID_Hotel)
                VALUES (@Hospedaje, @Estadia, @Habitacion, @Hotel);
                SET @Registro = SCOPE_IDENTITY();

                DELETE FROM @Consumos;
                INSERT Operaciones.HistorialServicios (Fecha_servicio, ID_Estadia, ID_Servicio, ID_Empleado)
                OUTPUT inserted.ID_HistorialServicios, inserted.ID_Servicio INTO @Consumos
                SELECT @Entrada, @Estadia, Servicio, @Empleado FROM @Paquete;

                INSERT Finanzas.Factura (Fecha_factura, Precio_total, ID_Estadia)
                VALUES (@Salida, @Total, @Estadia);
                SET @Factura = SCOPE_IDENTITY();

                INSERT Finanzas.Detalle (Precio_Subtotal, Cantidad, Descripcion, Precio_Unitario,
                    ID_Factura, ID_HistorialServicios, ID_Registro)
                VALUES (@Hospedaje, @Noches, CONCAT(@Marcador, 'Hospedaje'), @Tarifa,
                    @Factura, NULL, @Registro);

                INSERT Finanzas.Detalle (Precio_Subtotal, Cantidad, Descripcion, Precio_Unitario,
                    ID_Factura, ID_HistorialServicios, ID_Registro)
                SELECT p.Precio * q.Cantidad, q.Cantidad, p.Nombre, p.Precio, @Factura, c.Historial, NULL
                FROM @Consumos c JOIN @Paquete p ON p.Servicio = c.Servicio
                CROSS APPLY (VALUES (
                    CASE WHEN p.PorNoche = 1 THEN @Noches ELSE 1 END *
                    CASE WHEN p.PorPersona = 1 THEN @Personas ELSE 1 END
                )) q(Cantidad);

                INSERT @Cuartos VALUES (@Hotel, @Habitacion, @Entrada, @Salida);
                INSERT @Reservas VALUES (@Huesped, @Entrada, @Salida);
                UPDATE @Huespedes SET Usos += 1 WHERE Id = @Huesped;
                SET @Facturacion += @Total;
                SET @Nuevas += 1;
            END;
        END;
        FETCH NEXT FROM candidatos INTO @Entrada, @Hotel, @Habitacion, @Tarifa, @Empleado, @Personas, @Noches;
    END;
    CLOSE candidatos;
    DEALLOCATE candidatos;

    IF @Facturacion < @Meta
        THROW 50005, 'La capacidad disponible no permite alcanzar la meta con este paquete.', 1;

    -- La vista resume la facturacion de 2026.
    DECLARE @Vista nvarchar(max) = CONCAT(N'
    CREATE VIEW BI.v_SimulacionCoberturaDeuda AS
    WITH Facturas2026 AS (
        SELECT r.Total_Factura, r.Total_Detalles,
            CASE WHEN EXISTS (
                SELECT 1 FROM Finanzas.Detalle d
                WHERE d.ID_Factura = r.ID_Factura
                  AND LEFT(d.Descripcion, ', LEN(RTRIM(@Marcador)) + 1, N') = ''', @Marcador, N'''
                  AND d.ID_Registro IS NOT NULL
            ) THEN 1 ELSE 0 END AS Simulada
        FROM BI.v_AnalisisResumenEjecutivo r WHERE r.Anio = 2026
    ),
    Totales AS (
        SELECT COALESCE(SUM(CASE WHEN Simulada = 0 THEN Total_Factura END),0) AS Facturacion_Base,
            COALESCE(SUM(CASE WHEN Simulada = 1 THEN Total_Factura END),0) AS Facturacion_Simulada,
            SUM(Total_Factura) AS Facturacion_Total,
            SUM(Simulada) AS Estadias_Simuladas,
            SUM(CASE WHEN Simulada = 1 AND (Total_Detalles IS NULL OR Total_Factura <> Total_Detalles)
                THEN 1 ELSE 0 END) AS Facturas_Sin_Cuadrar
        FROM Facturas2026
    )
    SELECT 2026 AS Anio, t.*, a.Nomina_Anual_Estimada, a.Deuda_Inicial,
        a.Nomina_Anual_Estimada + a.Deuda_Inicial AS Meta_Facturacion,
        d.Disponible_Para_Deuda,
        p.Pago_Simulado,
        a.Deuda_Inicial - p.Pago_Simulado AS Saldo_Deuda
    FROM Totales t
    CROSS JOIN (VALUES (CAST(', @Nomina, N' AS decimal(19,2)),
        CAST(', @Deuda, N' AS decimal(19,2)))) a(Nomina_Anual_Estimada, Deuda_Inicial)
    CROSS APPLY (VALUES (CASE WHEN t.Facturacion_Total > a.Nomina_Anual_Estimada
        THEN t.Facturacion_Total - a.Nomina_Anual_Estimada ELSE 0 END)) d(Disponible_Para_Deuda)
    CROSS APPLY (VALUES (CASE WHEN d.Disponible_Para_Deuda > a.Deuda_Inicial
        THEN a.Deuda_Inicial ELSE d.Disponible_Para_Deuda END)) p(Pago_Simulado);');
    EXEC sys.sp_executesql @Vista;

    DECLARE @Validar nvarchar(max) = N'
    IF NOT EXISTS (
        SELECT 1 FROM BI.v_SimulacionCoberturaDeuda
        WHERE Estadias_Simuladas = @Nuevas AND Facturas_Sin_Cuadrar = 0
          AND Facturacion_Total = @Facturacion AND Saldo_Deuda = 0
    )
        THROW 50006, ''La vista de BI no reconcilia con el escenario.'', 1;
    SELECT * FROM BI.v_SimulacionCoberturaDeuda;';
    EXEC sys.sp_executesql @Validar, N'@Nuevas int, @Facturacion decimal(19,2)', @Nuevas, @Facturacion;

    IF @Guardar = 1
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'Escenario guardado.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'Vista previa: se revirtieron los datos y la vista. Los valores IDENTITY pueden quedar saltados.';
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
