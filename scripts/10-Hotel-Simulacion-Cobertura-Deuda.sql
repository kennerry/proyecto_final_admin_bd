USE Hotel;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;


DECLARE @Guardar bit = 1;
DECLARE @Inicio date = '20260101', @Fin date = '20270101';
DECLARE @Deuda decimal(19,2) = 1000000.00;
DECLARE @Nomina decimal(19,2), @Base decimal(19,2), @Meta decimal(19,2);
DECLARE @Facturacion decimal(19,2), @MesesNomina int, @Nuevas int = 0;
DECLARE @Marcador varchar(40) = '[Simulacion deuda 2026 v3] ';
DECLARE @MarcadorAnterior varchar(40) = '[Simulacion deuda 2026] ';
DECLARE @MarcadorV2 varchar(40) = '[Simulacion deuda 2026 v2] ';
DECLARE @Bloqueo int;

BEGIN TRY
    BEGIN TRANSACTION;
    EXEC @Bloqueo = sys.sp_getapplock
        @Resource = 'Hotel.SimulacionCoberturaDeuda.2026',
        @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
    IF @Bloqueo < 0
        THROW 50001, 'No se obtuvo el bloqueo del escenario.', 1;
DECLARE @MarcaAnterior2025 varchar(50) = '[Variedad hotel 2025-2026] ';
DECLARE @Marca varchar(50) = '[Escenario hotel 2025 v4] ';
DECLARE @EstadosCargados bit = 0;
DECLARE @Metas table (
    Anio int, Estado varchar(100), Cantidad int, PRIMARY KEY (Anio, Estado)
);
INSERT @Metas VALUES
    (2025, 'COMPLETADA', 3500), (2025, 'CANCELADA', 100), (2025, 'PENDIENTE', 80),
    (2026, 'CANCELADA', 1100), (2026, 'PENDIENTE', 900);
DECLARE @Agregadas table (
    Reserva int PRIMARY KEY, Anio int, Estado varchar(100), Factura int NULL
);
DECLARE @Servicios table (
    Id int PRIMARY KEY, Nombre varchar(250), Precio decimal(10,2), Orden int
);
DECLARE @VarConsumos table (Id int PRIMARY KEY, Cantidad int, Fecha date);
DECLARE @Historiales table (Servicio int PRIMARY KEY, Historial int);
DECLARE @Anio int, @Estado varchar(100), @VarMeta int, @Hechas int;
DECLARE @Fecha date, @VarSalida date, @VarNoches int, @VarPersonas int, @Paso int;
DECLARE @VarHotel int, @Cuarto int, @VarEmpleado int, @VarHuesped int;
DECLARE @VarReserva int, @VarEstadia int, @VarRegistro int, @VarFactura int;
DECLARE @VarTarifa decimal(10,2), @VarHospedaje decimal(10,2), @VarTotal decimal(10,2);

    -- Reemplazar las reservas identificadas por el marcador de la version anterior.
    DELETE r
    FROM Operaciones.Reservacion r
    WHERE EXISTS (
        SELECT 1 FROM Operaciones.Estadia e
        JOIN Finanzas.Factura f ON f.ID_Estadia = e.ID_Estadia
        JOIN Finanzas.Detalle d ON d.ID_Factura = f.ID_Factura
        WHERE e.ID_Reservacion = r.ID_Reservacion AND d.ID_Registro IS NOT NULL
          AND (LEFT(d.Descripcion, LEN(@MarcadorAnterior) + 1) = @MarcadorAnterior
            OR LEFT(d.Descripcion, LEN(@MarcadorV2) + 1) = @MarcadorV2)
    );
    IF @@ROWCOUNT > 0
        DROP VIEW IF EXISTS BI.v_SimulacionCoberturaDeuda;

    IF OBJECT_ID('BI.v_SimulacionCoberturaDeuda', 'V') IS NULL
    BEGIN
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
            Tipo varchar(100), Orden int
        );
        INSERT @Paquete
        SELECT ID_Servicio, Nombre, Precio_Unitario, Tipo,
            ROW_NUMBER() OVER (ORDER BY ID_Servicio)
        FROM Operaciones.Servicio;
        IF @@ROWCOUNT < 7
            THROW 50004, 'Faltan servicios del catalogo para el escenario.', 1;
        DECLARE @Seleccion table (Servicio int PRIMARY KEY, Cantidad int, Fecha date);

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
        -- Los meses con mayor peso reciben mas oportunidades antes de alcanzar la meta.
        ORDER BY DAY(d.Dia) * 100.0 / CASE MONTH(d.Dia)
            WHEN 1 THEN 100 WHEN 2 THEN 76 WHEN 3 THEN 91 WHEN 4 THEN 120
            WHEN 5 THEN 74 WHEN 6 THEN 86 WHEN 7 THEN 116 WHEN 8 THEN 109
            WHEN 9 THEN 72 WHEN 10 THEN 83 WHEN 11 THEN 96 WHEN 12 THEN 125
        END, MONTH(d.Dia), h.Numero, h.ID_Hotel
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
                    DELETE FROM @Seleccion;
                    INSERT @Seleccion
                    SELECT TOP (3 + @Nuevas % 5) p.Servicio,
                        CASE WHEN p.Tipo = 'ALIMENTACION' THEN @Noches * @Personas
                             ELSE @Personas + (p.Orden + @Nuevas) % 3 END,
                        DATEADD(day, (p.Orden + @Nuevas) % @Noches, @Entrada)
                    FROM @Paquete p
                    ORDER BY HASHBYTES('SHA2_256', CONCAT(@Nuevas, ':', p.Servicio)), p.Servicio;

                    SELECT @Total = @Hospedaje + SUM(p.Precio * s.Cantidad)
                    FROM @Seleccion s JOIN @Paquete p ON p.Servicio = s.Servicio;

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
                    SELECT Fecha, @Estadia, Servicio, @Empleado FROM @Seleccion;

                    INSERT Finanzas.Factura (Fecha_factura, Precio_total, ID_Estadia)
                    VALUES (@Salida, @Total, @Estadia);
                    SET @Factura = SCOPE_IDENTITY();

                    INSERT Finanzas.Detalle (Precio_Subtotal, Cantidad, Descripcion, Precio_Unitario,
                        ID_Factura, ID_HistorialServicios, ID_Registro)
                    VALUES (@Hospedaje, @Noches, CONCAT(@Marcador, 'Hospedaje'), @Tarifa,
                        @Factura, NULL, @Registro);

                    INSERT Finanzas.Detalle (Precio_Subtotal, Cantidad, Descripcion, Precio_Unitario,
                        ID_Factura, ID_HistorialServicios, ID_Registro)
                    SELECT p.Precio * s.Cantidad, s.Cantidad, p.Nombre, p.Precio, @Factura, c.Historial, NULL
                    FROM @Consumos c
                    JOIN @Seleccion s ON s.Servicio = c.Servicio
                    JOIN @Paquete p ON p.Servicio = c.Servicio;

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
    END
    ELSE
        PRINT 'La simulacion de deuda de 2026 ya esta cargada.';

    -- Las versiones anteriores ya cargaron los estados sin factura.
    IF EXISTS (
        SELECT 1 FROM Finanzas.Detalle
        WHERE LEFT(Descripcion, LEN(@MarcaAnterior2025) + 1) = @MarcaAnterior2025
    )
    BEGIN
        SET @EstadosCargados = 1;
        DELETE r
        FROM Operaciones.Reservacion r
        WHERE EXISTS (
            SELECT 1 FROM Operaciones.Estadia e
            JOIN Finanzas.Factura f ON f.ID_Estadia = e.ID_Estadia
            JOIN Finanzas.Detalle d ON d.ID_Factura = f.ID_Factura
            WHERE e.ID_Reservacion = r.ID_Reservacion AND d.ID_Registro IS NOT NULL
              AND f.Fecha_factura >= '20250101' AND f.Fecha_factura < @Inicio
              AND LEFT(d.Descripcion, LEN(@MarcaAnterior2025) + 1) = @MarcaAnterior2025
        );
    END;

    IF NOT EXISTS (
        SELECT 1 FROM Finanzas.Detalle WHERE LEFT(Descripcion, LEN(@Marca) + 1) = @Marca
    )
    BEGIN
        INSERT @Servicios
        SELECT ID_Servicio, Nombre, Precio_Unitario, ROW_NUMBER() OVER (ORDER BY ID_Servicio)
        FROM Operaciones.Servicio;
        DECLARE @NumServicios int = @@ROWCOUNT;
        IF @NumServicios < 6
            THROW 50102, 'El catalogo debe tener al menos seis servicios.', 1;

        DECLARE @Ocupacion table (
            Hotel int, Cuarto int, Entrada date, Salida date,
            INDEX IX_Ocupacion NONCLUSTERED (Hotel, Cuarto, Entrada, Salida)
        );
        INSERT @Ocupacion
        SELECT rh.ID_Hotel, rh.Numero, COALESCE(e.Fecha_Entrada, r.Fecha_Inicio),
            COALESCE(e.Fecha_Salida, r.Fecha_Fin)
        FROM Operaciones.RegistroHabitaciones rh
        JOIN Operaciones.Estadia e ON e.ID_Estadia = rh.ID_Estadia
        JOIN Operaciones.Reservacion r ON r.ID_Reservacion = e.ID_Reservacion
        WHERE r.Estado <> 'CANCELADA';

        DECLARE @Agenda table (
            Huesped int, Entrada date, Salida date,
            INDEX IX_Agenda NONCLUSTERED (Huesped, Entrada, Salida)
        );
        INSERT @Agenda
        SELECT ID_Huesped, Fecha_Inicio, Fecha_Fin
        FROM Operaciones.Reservacion WHERE Estado <> 'CANCELADA';

        DECLARE metas CURSOR LOCAL FAST_FORWARD FOR
            SELECT Anio, Estado, Cantidad FROM @Metas
            WHERE @EstadosCargados = 0 OR Estado = 'COMPLETADA'
            ORDER BY Anio, CASE Estado WHEN 'COMPLETADA' THEN 0 WHEN 'PENDIENTE' THEN 1 ELSE 2 END;

        OPEN metas;
        FETCH NEXT FROM metas INTO @Anio, @Estado, @VarMeta;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Hechas = 0;
            SET @Paso = 0;
            WHILE @Hechas < @VarMeta AND @Paso < @VarMeta * 4
            BEGIN
                -- 37 distribuye los intentos a lo largo de los primeros 359 dias.
                SET @Fecha = DATEADD(day, (@Paso * 37) % 359, DATEFROMPARTS(@Anio, 1, 1));
                SET @VarNoches = 1 + (@Paso % 5);
                SET @VarSalida = DATEADD(day, @VarNoches, @Fecha);
                SET @VarHuesped = NULL;
                SET @Cuarto = NULL;

                SELECT TOP (1) @VarHuesped = h.ID_Huesped
                FROM Operaciones.Huesped h
                WHERE NOT EXISTS (
                    SELECT 1 FROM @Agenda a
                    WHERE a.Huesped = h.ID_Huesped AND a.Entrada < @VarSalida AND a.Salida > @Fecha
                )
                ORDER BY CHECKSUM(h.ID_Huesped, @Anio, @Estado, @Paso), h.ID_Huesped;

                IF @Estado = 'COMPLETADA'
                BEGIN
                    SELECT TOP (1) @VarHotel = h.ID_Hotel, @Cuarto = h.Numero,
                        @VarEmpleado = e.ID_Empleado, @VarTarifa = h.Precio,
                        @VarPersonas = CASE WHEN h.Tipo = 'INDIVIDUAL' THEN 1 ELSE 1 + (@Paso % 2) END
                    FROM Operaciones.Habitacion h
                    CROSS APPLY (
                        SELECT TOP (1) emp.ID_Empleado FROM Finanzas.Empleado emp
                        WHERE emp.ID_Hotel = h.ID_Hotel AND emp.Cargo = 'EMPLEADO'
                        ORDER BY CHECKSUM(emp.ID_Empleado, @Paso), emp.ID_Empleado
                    ) e
                    WHERE NOT EXISTS (
                        SELECT 1 FROM @Ocupacion o WHERE o.Hotel = h.ID_Hotel AND o.Cuarto = h.Numero
                            AND o.Entrada < @VarSalida AND o.Salida > @Fecha
                    )
                    ORDER BY CHECKSUM(h.ID_Hotel, h.Numero, @Paso), h.ID_Hotel, h.Numero;
                END;

                IF @VarHuesped IS NOT NULL AND (@Estado <> 'COMPLETADA' OR @Cuarto IS NOT NULL)
                BEGIN
                    IF @Estado <> 'COMPLETADA' SET @VarPersonas = 1 + (@Paso % 4);
                    INSERT Operaciones.Reservacion (Estado, Cantidad_Personas, Fecha_Inicio, Fecha_Fin, ID_Huesped)
                    VALUES (@Estado, @VarPersonas, @Fecha, @VarSalida, @VarHuesped);
                    SET @VarReserva = SCOPE_IDENTITY();
                    SET @VarFactura = NULL;

                    IF @Estado <> 'CANCELADA'
                        INSERT @Agenda VALUES (@VarHuesped, @Fecha, @VarSalida);

                    IF @Estado = 'COMPLETADA'
                    BEGIN
                        INSERT @Ocupacion VALUES (@VarHotel, @Cuarto, @Fecha, @VarSalida);

                        INSERT Operaciones.Estadia (Fecha_Entrada, Fecha_Salida, Hora_Entrada, Hora_Salida, ID_Reservacion)
                        VALUES (@Fecha, @VarSalida, '15:00', '10:00', @VarReserva);
                        SET @VarEstadia = SCOPE_IDENTITY();

                        SET @VarHospedaje = @VarTarifa * @VarNoches;
                        INSERT Operaciones.RegistroHabitaciones (Precio_Subtotal, ID_Estadia, Numero, ID_Hotel)
                        VALUES (@VarHospedaje, @VarEstadia, @Cuarto, @VarHotel);
                        SET @VarRegistro = SCOPE_IDENTITY();

                        -- Cada estadia consume entre 2 y 6 servicios distintos del catalogo.
                        DELETE FROM @VarConsumos;
                        DELETE FROM @Historiales;
                        INSERT @VarConsumos
                        SELECT TOP (2 + (@Paso % 5)) s.Id,
                            1 + ((s.Orden + @Paso) % (2 * @VarPersonas)),
                            DATEADD(day, (s.Orden + @Paso) % @VarNoches, @Fecha)
                        FROM @Servicios s
                        ORDER BY HASHBYTES('SHA2_256', CONCAT(@Paso, ':', s.Id)), s.Id;

                        INSERT Operaciones.HistorialServicios (Fecha_servicio, ID_Estadia, ID_Servicio, ID_Empleado)
                        OUTPUT inserted.ID_Servicio, inserted.ID_HistorialServicios INTO @Historiales
                        SELECT Fecha, @VarEstadia, Id, @VarEmpleado FROM @VarConsumos;

                        SELECT @VarTotal = @VarHospedaje + SUM(c.Cantidad * s.Precio)
                        FROM @VarConsumos c JOIN @Servicios s ON s.Id = c.Id;

                        INSERT Finanzas.Factura (Fecha_factura, Precio_total, ID_Estadia)
                        VALUES (@VarSalida, @VarTotal, @VarEstadia);
                        SET @VarFactura = SCOPE_IDENTITY();

                        INSERT Finanzas.Detalle (Precio_Subtotal, Cantidad, Descripcion, Precio_Unitario,
                            ID_Factura, ID_HistorialServicios, ID_Registro)
                        VALUES (@VarHospedaje, @VarNoches, CONCAT(@Marca, 'Hospedaje'), @VarTarifa,
                            @VarFactura, NULL, @VarRegistro);

                        INSERT Finanzas.Detalle (Precio_Subtotal, Cantidad, Descripcion, Precio_Unitario,
                            ID_Factura, ID_HistorialServicios, ID_Registro)
                        SELECT c.Cantidad * s.Precio, c.Cantidad, s.Nombre, s.Precio, @VarFactura, h.Historial, NULL
                        FROM @VarConsumos c JOIN @Servicios s ON s.Id = c.Id
                        JOIN @Historiales h ON h.Servicio = c.Id;
                    END;

                    INSERT @Agregadas VALUES (@VarReserva, @Anio, @Estado, @VarFactura);
                    SET @Hechas += 1;
                END;
                SET @Paso += 1;
            END;
            IF @Hechas <> @VarMeta
                THROW 50103, 'No hubo disponibilidad para completar las metas de reservas.', 1;
            FETCH NEXT FROM metas INTO @Anio, @Estado, @VarMeta;
        END;
        CLOSE metas;
        DEALLOCATE metas;

        IF EXISTS (
            SELECT 1 FROM @Agregadas a
            LEFT JOIN BI.v_AnalisisResumenEjecutivo v ON v.ID_Factura = a.Factura
            WHERE a.Factura IS NOT NULL AND
                (v.ID_Factura IS NULL OR v.Total_Detalles IS NULL OR v.Total_Detalles <> v.Total_Factura)
        )
            THROW 50104, 'Hay facturas de la ampliacion que no cuadran en BI.', 1;

        SELECT a.Anio, a.Estado, COUNT(*) AS Reservaciones_Nuevas,
            COALESCE(SUM(v.Cantidad_Servicios), 0) AS Consumos_Nuevos,
            COALESCE(SUM(v.Total_Factura), 0) AS Facturacion_Nueva
        FROM @Agregadas a
        LEFT JOIN BI.v_AnalisisResumenEjecutivo v ON v.ID_Factura = a.Factura
        GROUP BY a.Anio, a.Estado ORDER BY a.Anio, a.Estado;
    END
    ELSE
        PRINT 'La ampliacion de reservaciones y servicios ya esta cargada.';

    -- Aumentar los estados sin facturacion una sola vez
    IF NOT EXISTS (
        SELECT 1 FROM sys.extended_properties
        WHERE class = 0 AND name = 'Hotel.Reservaciones.Estados.2026.v3'
    )
    BEGIN
        DECLARE @Extras int = 0;
        SET @Paso = 0;
        WHILE @Extras < 1500 AND @Paso < 6000
        BEGIN
            SET @Fecha = DATEADD(day, (@Paso * 37) % 359, @Inicio);
            SET @VarSalida = DATEADD(day, 1 + @Paso % 5, @Fecha);
            SET @VarHuesped = NULL;
            SELECT TOP (1) @VarHuesped = h.ID_Huesped
            FROM Operaciones.Huesped h
            WHERE NOT EXISTS (
                SELECT 1 FROM Operaciones.Reservacion r
                WHERE r.ID_Huesped = h.ID_Huesped AND r.Estado <> 'CANCELADA'
                  AND r.Fecha_Inicio < @VarSalida AND r.Fecha_Fin > @Fecha
            )
            ORDER BY HASHBYTES('SHA2_256', CONCAT(@Paso, ':', h.ID_Huesped)), h.ID_Huesped;

            IF @VarHuesped IS NOT NULL
            BEGIN
                INSERT Operaciones.Reservacion
                    (Estado, Cantidad_Personas, Fecha_Inicio, Fecha_Fin, ID_Huesped)
                VALUES (CASE WHEN @Extras % 15 < 8 THEN 'CANCELADA' ELSE 'PENDIENTE' END,
                    1 + @Paso % 4, @Fecha, @VarSalida, @VarHuesped);
                SET @Extras += 1;
            END;
            SET @Paso += 1;
        END;
        IF @Extras <> 1500
            THROW 50105, 'No hubo disponibilidad para ajustar la distribucion por estado.', 1;
        EXEC sys.sp_addextendedproperty @name = 'Hotel.Reservaciones.Estados.2026.v3', @value = 1;
    END;

    SELECT YEAR(Fecha_Inicio) AS Anio, Estado, COUNT(*) AS Reservaciones
    FROM Operaciones.Reservacion
    WHERE Fecha_Inicio >= '20250101' AND Fecha_Inicio < @Fin
    GROUP BY YEAR(Fecha_Inicio), Estado ORDER BY Anio, Estado;

    SELECT Inicio_Mes, Tipo_Ingreso, SUM(Ingreso_Detalle) AS Ingresos
    FROM BI.v_AnalisisFinanciero
    WHERE Anio IN (2025, 2026)
    GROUP BY Inicio_Mes, Tipo_Ingreso ORDER BY Inicio_Mes, Tipo_Ingreso;

    EXEC(N'SELECT Facturacion_Total, Pago_Simulado, Saldo_Deuda FROM BI.v_SimulacionCoberturaDeuda;');

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

