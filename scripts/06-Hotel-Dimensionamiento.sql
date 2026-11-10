
-- AJustamos el archivo de datos principal
ALTER DATABASE Hotel
MODIFY FILE (
    NAME = 'Hotel',
    SIZE = 100MB,
    MAXSIZE = 2GB,
    FILEGROWTH = 50MB
);
GO

-- Ajustamos los logs

ALTER DATABASE Hotel
MODIFY FILE (
    NAME = 'Hotel_log',
    SIZE = 50MB,
    MAXSIZE = 1GB,
    FILEGROWTH = 25MB
);
GO

-- Consulta para probar los cambios sobre dimensionamiento y su correcta aplicacion

SELECT 
    name AS [Nombre], 
    physical_name AS [Ruta], 
    CAST(size/128.0 AS DECIMAL(10,2)) AS [Tamaño Actual (MB)],  
    CASE 
        WHEN max_size = -1 THEN 'Sin límite' 
        ELSE CAST(CAST(max_size/128.0 AS DECIMAL(10,2)) AS VARCHAR) + ' MB' 
    END AS [Tamaño Máximo], 
    CAST(growth/128.0 AS DECIMAL(10,2)) AS [Tasa de Crecimiento (MB)]
FROM sys.database_files;
GO
