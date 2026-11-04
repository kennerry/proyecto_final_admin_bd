CREATE DATABASE Hotel;
GO

USE Hotel;
GO

CREATE TABLE Huesped (
    --! PK: Identificador unico de huesped
    ID_Huesped INT IDENTITY(1,1) NOT NULL,
    Nombre VARCHAR(250) NOT NULL,
    DUI CHAR(9) NOT NULL,            -- formato 00000000-0 (9 caracteres)
    Correo VARCHAR(250) NOT NULL,
    Telefono CHAR(8) NOT NULL,
    --* Llave primaria de Huesped
    CONSTRAINT pk_Huesped_IDHuesped PRIMARY KEY (ID_Huesped),
    --* Campos UNICOS para huesped
    CONSTRAINT uq_Huesped_DUI UNIQUE (DUI),
    CONSTRAINT uq_Huesped_Correo UNIQUE (Correo),
    CONSTRAINT uq_Huesped_Telefono UNIQUE (Telefono),
    --* Verificar campos (SQL Server no tiene regex: se usa LIKE)
    CONSTRAINT ck_Huesped_Correo CHECK (
        Correo LIKE '_%@_%.__%'
        AND Correo NOT LIKE '%@%@%'
        AND Correo NOT LIKE '%[^A-Za-z0-9._%+@-]%'
        AND RIGHT(Correo, 2) NOT LIKE '%[^A-Za-z]%'
    ),
    CONSTRAINT ck_Huesped_DUI_Format CHECK (DUI LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9]'),
    CONSTRAINT ck_Huesped_Telefono CHECK (Telefono LIKE '[67][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
);

CREATE TABLE Hotel (
    --! PK: Identificador unico del hotel
    ID_Hotel INT IDENTITY(1,1) NOT NULL,
    Nombre VARCHAR(250) NOT NULL,
    Direccion VARCHAR(250) NOT NULL,
    Area NUMERIC(10, 2) NOT NULL,
    Estrellas NUMERIC(2,1) NULL CONSTRAINT df_Hotel_Estrellas DEFAULT 1,
    Hora_Apertura TIME(0) NOT NULL,
    Hora_Cierre TIME(0) NOT NULL,
    --* Llave primaria del Hotel
    CONSTRAINT pk_Hotel_IDHotel PRIMARY KEY (ID_Hotel),
    --* Verificar campos
    CONSTRAINT ck_Hotel_Estrellas CHECK (Estrellas BETWEEN 1 AND 5),
    CONSTRAINT ck_Hotel_Area CHECK (Area > 0),
    CONSTRAINT ck_Hotel_HoraApertura_HHMM CHECK (DATEPART(SECOND, Hora_Apertura) = 0),
    CONSTRAINT ck_Hotel_HoraCierre_HHMM CHECK (DATEPART(SECOND, Hora_Cierre) = 0)
);

--? Servicios (Tipo) : BIENESTAR (SPA, Masajes), DEPORTIVOS (Piscina, Gimnasio),
--? HABITACION (Limpieza de Habitacion, Lavanderia), ALIMENTACION (Bar, Restaurante),
--? ENTRETENIMIENTO (Cine, Karaoke)
CREATE TABLE Servicio (
    --! PK: Tipos de servicios ofrecidos por el hotel
    ID_Servicio INT IDENTITY(1,1) NOT NULL,
    Nombre VARCHAR(250) NOT NULL,
    Tipo VARCHAR(250) NOT NULL,
    Precio_Unitario NUMERIC(10, 2) NOT NULL,
    --* Llave primaria del Servicio
    CONSTRAINT pk_Servicio_IDServicio PRIMARY KEY (ID_Servicio),
    --* Campo unico para nombre de servicio
    CONSTRAINT uq_Servicio_Nombre UNIQUE (Nombre),
    CONSTRAINT ck_Servicio_PrecioUnitario CHECK (Precio_Unitario > 0),
    CONSTRAINT ck_Servicio_Tipo CHECK (Tipo IN ('BIENESTAR', 'DEPORTIVOS', 'HABITACION', 'ALIMENTACION', 'ENTRETENIMIENTO'))
);

--? Reservacion (Estado) : CANCELADA, PENDIENTE, COMPLETADA
CREATE TABLE Reservacion (
    --! PK: Reserva asociada a un huesped
    ID_Reservacion INT IDENTITY(1,1) NOT NULL,
    Estado VARCHAR(100) NOT NULL,
    Cantidad_Personas INT NOT NULL,
    Fecha_Inicio DATE NOT NULL,
    Fecha_Fin DATE NOT NULL,
    ID_Huesped INT NOT NULL,
    --* Llave primaria de Reservacion
    CONSTRAINT pk_Reservacion_IDReservacion PRIMARY KEY (ID_Reservacion),
    --* Llave foranea de Reservacion -> Huesped (ID)
    CONSTRAINT fk_Reservacion_IDHuesped FOREIGN KEY (ID_Huesped) REFERENCES Huesped (ID_Huesped)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    --* Verificar campos
    CONSTRAINT ck_Reservacion_Estado CHECK (Estado IN ('CANCELADA', 'PENDIENTE', 'COMPLETADA')),
    CONSTRAINT ck_Reservacion_Fechas CHECK (Fecha_Fin >= Fecha_Inicio),
    CONSTRAINT ck_Reservacion_CantidadPersonas CHECK (Cantidad_Personas BETWEEN 1 AND 10)
);

CREATE TABLE Estadia (
    --! PK: Estancia concreta asociada a una reservacion
    ID_Estadia INT IDENTITY(1,1) NOT NULL,
    Fecha_Entrada DATE NULL,
    Fecha_Salida DATE NULL,
    Hora_Entrada TIME(0) NULL,
    Hora_Salida TIME(0) NULL,
    ID_Reservacion INT NOT NULL,
    --* Llave primaria de Estadia
    CONSTRAINT pk_Estadia_IDEstadia PRIMARY KEY (ID_Estadia),
    --* Llave foranea de Estadia -> Reservacion (ID)
    CONSTRAINT fk_Estadia_IDReservacion FOREIGN KEY (ID_Reservacion) REFERENCES Reservacion (ID_Reservacion)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    --* Verificar campos
    CONSTRAINT ck_Estadia_Fechas CHECK (Fecha_Salida >= Fecha_Entrada),
    CONSTRAINT ck_Estadia_HoraEntrada_HHMM CHECK (DATEPART(SECOND, Hora_Entrada) = 0),
    CONSTRAINT ck_Estadia_HoraSalida_HHMM CHECK (DATEPART(SECOND, Hora_Salida) = 0)
);

CREATE TABLE Factura (
    --! PK: Factura generada por una estadia
    ID_Factura INT IDENTITY(1,1) NOT NULL,
    Fecha_factura DATE NOT NULL,
    Precio_total NUMERIC(10, 2) NOT NULL,
    ID_Estadia INT NOT NULL,
    --* Llave primaria de Factura
    CONSTRAINT pk_Factura_IDFactura PRIMARY KEY (ID_Factura),
    --* Llave foranea de Factura -> Estadia (ID)
    CONSTRAINT fk_Factura_IDEstadia FOREIGN KEY (ID_Estadia) REFERENCES Estadia (ID_Estadia)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    --* Verificar campos
    CONSTRAINT ck_Factura_PrecioTotal CHECK (Precio_total > 0)
);

--? Habitacion (Tipo) : INDIVIDUAL (15$ la noche), DOBLE (30$ la noche),
--? FAMILIAR (20$ la noche), SUITE (50$ la noche)
CREATE TABLE Habitacion (
    --! PK compuesto: Numero de habitacion por hotel
    Numero INT NOT NULL,
    Tamaño NUMERIC(10, 2) NOT NULL,
    Camas INT NOT NULL,
    Baños INT NOT NULL,
    Tipo VARCHAR(250) NOT NULL,
    Precio NUMERIC(10, 2) NOT NULL,
    ID_Hotel INT NOT NULL,
    --* Llave primaria de la Habitacion (compuesta por Numero e ID_Hotel)
    CONSTRAINT pk_Habitacion_Numero_IDHotel PRIMARY KEY (Numero, ID_Hotel),
    --* Llave foranea Habitacion -> Hotel (ID)
    CONSTRAINT fk_Habitacion_IDHotel FOREIGN KEY (ID_Hotel) REFERENCES Hotel (ID_Hotel)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    --* Verificar campos
    CONSTRAINT ck_Habitacion_Tipo CHECK (Tipo IN ('INDIVIDUAL', 'DOBLE', 'FAMILIAR', 'SUITE')),
    CONSTRAINT ck_Habitacion_Tamaño CHECK (Tamaño > 0),
    CONSTRAINT ck_Habitacion_Baños CHECK (Baños > 0),
    CONSTRAINT ck_Habitacion_Camas CHECK (Camas > 0),
    CONSTRAINT ck_Habitacion_Precio CHECK (Precio > 0),
    CONSTRAINT ck_Habitacion_Numero CHECK (Numero > 0)
);

--? Empleado (Cargo) : JEFE (Si es jefe el ID_Supervisor = NULL),
--? EMPLEADO (Si es EMPLEADO entonces tiene un ID_Supervisor)
CREATE TABLE Empleado (
    --! PK: Datos de los empleados
    ID_Empleado INT IDENTITY(1,1) NOT NULL,
    Nombre VARCHAR(250) NOT NULL,
    Correo VARCHAR(250) NOT NULL,
    Cargo VARCHAR(250) NOT NULL,
    Hora_Entrada TIME NOT NULL,
    Hora_Salida TIME NOT NULL,
    ID_Hotel INT NOT NULL,
    ID_Supervisor INT NULL,
    --* Llave primaria del empleado
    CONSTRAINT pk_Empleado_IDEmpleado PRIMARY KEY (ID_Empleado),
    --* Llave foranea del ID_Hotel de la tabla Hotel
    CONSTRAINT fk_Empleado_IDHotel FOREIGN KEY (ID_Hotel) REFERENCES Hotel (ID_Hotel)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    --* Llave foranea ID_Supervisor de la misma tabla Empleado
    --* (SQL Server no permite CASCADE en una FK autorreferenciada)
    CONSTRAINT fk_Empleado_IDSupervisor FOREIGN KEY (ID_Supervisor) REFERENCES Empleado (ID_Empleado)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    --* Restriccion a correos unicos
    CONSTRAINT uq_Empleado_Correo UNIQUE (Correo),
    --* Validacion en base al cargo
    CONSTRAINT ck_Empleado_reglasCargo CHECK (
        (Cargo = 'JEFE' AND ID_Supervisor IS NULL) OR
        (Cargo = 'EMPLEADO' AND ID_Supervisor IS NOT NULL)
    ),
    --* Evitar que un empleado se supervise a si mismo
    CONSTRAINT ck_Empleado_NoAutoSupervision CHECK (ID_Empleado <> ID_Supervisor),
    --* Validar el email del empleado
    CONSTRAINT ck_Empleado_Correo CHECK (
        Correo LIKE '_%@_%.__%'
        AND Correo NOT LIKE '%@%@%'
        AND Correo NOT LIKE '%[^A-Za-z0-9._%+@-]%'
        AND RIGHT(Correo, 2) NOT LIKE '%[^A-Za-z]%'
    ),
    --* Validar cargo del empleado
    CONSTRAINT ck_Empleado_Cargo CHECK (Cargo IN ('JEFE', 'EMPLEADO')),
    --* Validar que la hora de entrada sea menor a la hora de salida
    CONSTRAINT ck_Empleado_Horario CHECK (Hora_Entrada < Hora_Salida)
);

CREATE TABLE PagoNomina (
    --! PK: Llave compuesta sobre el pago de los empleados
    ID_Salario INT IDENTITY(1,1) NOT NULL,
    Monto NUMERIC(10, 2) NOT NULL,
    Fecha_Pago DATE NOT NULL,
    Metodo_Pago VARCHAR(50) NOT NULL,
    IVA NUMERIC(5,2) NOT NULL,
    ID_Empleado INT NOT NULL,
    --* Llave primaria compuesta por ID_Salario y ID_Empleado
    CONSTRAINT pk_PagoNomina_IDSalario_IDEmpleado PRIMARY KEY (ID_Salario, ID_Empleado),
    --* Llave foranea de ID_Empleado de la tabla Empleado
    CONSTRAINT fk_PagoNomina_IDEmpleado FOREIGN KEY (ID_Empleado) REFERENCES Empleado (ID_Empleado)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    --* Check para limitar la cantidad de opciones en Metodo_Pago
    CONSTRAINT ck_PagoNomina_MetodoPago CHECK (Metodo_Pago IN ('CHEQUE', 'TRANSFERENCIA')),
    CONSTRAINT ck_PagoNomina_Monto CHECK (Monto > 0),
    CONSTRAINT ck_PagoNomina_IVA CHECK (IVA >= 0 AND IVA <= 100)
);

CREATE TABLE HistorialServicios (
    --! PK: Registra que servicio se entrego durante una estadia y por quien
    ID_HistorialServicios INT IDENTITY(1,1) NOT NULL,
    Fecha_servicio DATE NOT NULL,
    ID_Estadia INT NOT NULL,
    ID_Servicio INT NOT NULL,
    ID_Empleado INT NOT NULL,
    --* Llave primaria de HistorialServicios
    CONSTRAINT pk_HistorialServicio_IDHistorialServicio PRIMARY KEY (ID_HistorialServicios),
    --* Llave foranea HistorialServicios -> Estadia (ID)
    CONSTRAINT fk_HistorialServicio_IDEstadia FOREIGN KEY (ID_Estadia) REFERENCES Estadia (ID_Estadia)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    --* Llave foranea HistorialServicios -> Servicio (ID)
    CONSTRAINT fk_HistorialServicio_IDServicio FOREIGN KEY (ID_Servicio) REFERENCES Servicio (ID_Servicio)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    --* Llave foranea HistorialServicios -> Empleado (ID)
    CONSTRAINT fk_HistorialServicio_IDEmpleado FOREIGN KEY (ID_Empleado) REFERENCES Empleado (ID_Empleado)
        ON DELETE NO ACTION ON UPDATE CASCADE
);

CREATE TABLE RegistroHabitaciones (
    --! Registro de habitaciones asociadas a una estadia (puede ser mas de una)
    ID_Registro INT IDENTITY(1,1) NOT NULL,
    Precio_Subtotal NUMERIC(10, 2) NOT NULL,
    ID_Estadia INT NOT NULL,
    Numero INT NOT NULL,
    ID_Hotel INT NOT NULL,
    --* Llave primaria de RegistroHabitaciones
    CONSTRAINT pk_RegistroHabitaciones_IDRegistro PRIMARY KEY (ID_Registro),
    --* Llave foranea de RegistroHabitaciones -> Estadia (ID)
    CONSTRAINT fk_RegistroHabitacion_IDEstadia FOREIGN KEY (ID_Estadia) REFERENCES Estadia (ID_Estadia)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    --* Llave foranea de RegistroHabitaciones -> Habitacion (Numero, ID_Hotel)
    CONSTRAINT fk_RegistroHabitacion_IDHotel_Numero FOREIGN KEY (Numero, ID_Hotel) REFERENCES Habitacion (Numero, ID_Hotel)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    --* Campos unicos
    CONSTRAINT uq_RegistroHabitacion_Estadia_Habitacion UNIQUE (ID_Estadia, Numero, ID_Hotel),
    --* Verificar campos
    CONSTRAINT ck_RegistroHabitacion_PrecioSubtotal CHECK (Precio_Subtotal > 0)
);

CREATE TABLE Detalle (
    --! PK: Detalles de factura/servicios asociados
    ID_Detalle INT IDENTITY(1,1) NOT NULL,
    Precio_Subtotal NUMERIC(10, 2) NOT NULL,
    Cantidad INT NOT NULL,
    Descripcion VARCHAR(250) NOT NULL,
    Precio_Unitario NUMERIC(10, 2) NOT NULL,
    ID_Factura INT NOT NULL,
    ID_HistorialServicios INT NULL,
    ID_Registro INT NULL,
    --* Llave primaria de Detalle
    CONSTRAINT pk_Detalle_IDDetalle_IDFactura PRIMARY KEY (ID_Detalle, ID_Factura),
    --* Llave foranea de Detalle -> Factura (ID)
    CONSTRAINT fk_Detalle_IDFactura FOREIGN KEY (ID_Factura) REFERENCES Factura (ID_Factura)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    --* Llave foranea de Detalle -> HistorialServicios (ID)
    --* NO ACTION: con CASCADE SQL Server da error 1785 (multiples rutas de cascada)
    CONSTRAINT fk_Detalle_HistorialServicios FOREIGN KEY (ID_HistorialServicios) REFERENCES HistorialServicios (ID_HistorialServicios)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    --* Llave foranea de Detalle -> RegistroHabitaciones (ID)
    --* NO ACTION: mismo motivo que la anterior
    CONSTRAINT fk_Detalle_IDRegistro FOREIGN KEY (ID_Registro) REFERENCES RegistroHabitaciones (ID_Registro)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    --* Verificar campos
    CONSTRAINT ck_Detalle_PrecioUnitario CHECK (Precio_Unitario > 0),
    CONSTRAINT ck_Detalle_Cantidad CHECK (Cantidad >= 0),
    --* El detalle es un HistorialServicios (servicio) O un RegistroHabitaciones (habitacion), nunca ambos
    CONSTRAINT ck_Detalle_OrigenExclusivo CHECK (
        (ID_HistorialServicios IS NOT NULL AND ID_Registro IS NULL) OR
        (ID_HistorialServicios IS NULL AND ID_Registro IS NOT NULL)
    )
);