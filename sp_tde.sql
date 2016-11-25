/*
 *  sp_tde_create_dmk
 */
IF EXISTS (SELECT 1 FROM SYSOBJECTS WHERE NAME = 'sp_tde_create_dmk')
	DROP PROCEDURE sp_tde_create_dmk;
GO
CREATE PROCEDURE sp_tde_create_dmk(@password nvarchar(50))
AS
BEGIN
	DECLARE @cmd varchar(5000);
	IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
		BEGIN
			PRINT 'The database already contains a DMK'
			RAISERROR('', 10, 1) WITH NOWAIT
            RETURN
		END
    
    PRINT 'Creating Database Master Key'
    SET @cmd = 'CREATE MASTER KEY ENCRYPTION BY PASSWORD = ''' + @password  + '''';
    EXEC (@cmd)
END
GO

/*
 *  sp_tde_drop_dmk
 */
IF EXISTS (SELECT 1 FROM SYSOBJECTS WHERE NAME = 'sp_tde_drop_dmk')
	DROP PROCEDURE sp_tde_drop_dmk;
GO
CREATE PROCEDURE sp_tde_drop_dmk
AS
BEGIN
	DECLARE @cmd varchar(5000);
	IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
		BEGIN
			PRINT 'The database doest not have a DMK'
			RAISERROR('', 10, 1) WITH NOWAIT
            RETURN
		END
    
    PRINT 'Dropping Database Master Key'
    EXEC ('DROP MASTER KEY')
END
GO

/*
 *  sp_tde_create_certificate
 */
IF EXISTS (SELECT 1 FROM SYSOBJECTS WHERE NAME = 'sp_tde_create_certificate')
    DROP PROCEDURE sp_tde_create_certificate;
GO
CREATE PROCEDURE sp_tde_create_certificate(@certificateName nvarchar(50), @certificateSubject nvarchar(100))
AS
BEGIN
    PRINT 'Creating certificate named ' + @certificateName
	EXEC ('CREATE CERTIFICATE ' + @certificateName + ' WITH SUBJECT = ''' + @certificateSubject + '''')
END
GO

/*
 *  sp_tde_drop_certificate
 */
IF EXISTS (SELECT 1 FROM SYSOBJECTS WHERE NAME = 'sp_tde_drop_certificate')
    DROP PROCEDURE sp_tde_drop_certificate;
GO
CREATE PROCEDURE sp_tde_drop_certificate(@certificateName nvarchar(50))
AS
BEGIN
    PRINT 'Dropping certificate ' + @certificateName
	EXEC ('DROP CERTIFICATE ' + @certificateName)
END
GO

/*
 *  sp_tde_create_dek
 */
IF EXISTS (SELECT 1 FROM SYSOBJECTS WHERE NAME = 'sp_tde_create_dek')
	DROP PROCEDURE sp_tde_create_dek;
GO
CREATE PROCEDURE sp_tde_create_dek(@dbname nvarchar(50), @certificateName nvarchar(50))
AS
BEGIN
    DECLARE @cmd varchar(5000);
    IF EXISTS (SELECT 1 FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID(@dbname))
        BEGIN
            PRINT 'The database already has a defined a DEK'
            RAISERROR('', 10, 1) WITH NOWAIT
            RETURN
        END
        
    PRINT 'Creating Database Encryption Key using certificate ' + @certificateName
    SET @cmd = 'USE [' + @dbname + '] 
    CREATE DATABASE ENCRYPTION KEY WITH ALGORITHM = AES_256 ENCRYPTION BY SERVER CERTIFICATE ' + @certificateName;
    EXEC (@cmd)
END
GO

/*
 *  sp_tde_drop_dek
 */
IF EXISTS (SELECT 1 FROM SYSOBJECTS WHERE NAME = 'sp_tde_drop_dek')
	DROP PROCEDURE sp_tde_drop_dek;
GO
CREATE PROCEDURE sp_tde_drop_dek(@dbname nvarchar(50))
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID(@dbname))
        BEGIN
            PRINT 'The database does not have a defined a DEK'
            RAISERROR('', 10, 1) WITH NOWAIT
            RETURN
        END
    PRINT 'Dropping Database Encryption Key'
    EXEC ('USE [' + @dbname + '] DROP DATABASE ENCRYPTION KEY')
END
GO

/*
 *  sp_tde_enable
 */
IF EXISTS (SELECT 1 FROM SYSOBJECTS WHERE NAME = 'sp_tde_enable')
	DROP PROCEDURE sp_tde_enable;
GO
CREATE PROCEDURE sp_tde_enable(@dbname nvarchar(50))
AS
BEGIN
	DECLARE @msg nvarchar(200)

    IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    BEGIN
        PRINT 'The database master does not contain a DMK, please run sp_tde_create_dmk'
        RAISERROR('', 10, 1) WITH NOWAIT
        RETURN
    END

    IF NOT EXISTS (SELECT 1 FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID(@dbname))
    BEGIN
        PRINT 'The database does not have a defined DEK, please run sp_tde_create_dek'
        RAISERROR('', 10, 1) WITH NOWAIT
        RETURN
    END

	PRINT 'Activating encryption'
	EXEC('ALTER DATABASE [' + @dbname + '] SET ENCRYPTION ON')

	PRINT 'Start polling encryption completion'

	DECLARE @startEncryptionTime as datetime;
	SET @startEncryptionTime = GETDATE();

	WHILE 1 = 1
	BEGIN
		WAITFOR DELAY '00:00:05'
			SELECT 
				@msg = 
				CASE encryption_state 
					WHEN 0 THEN 'No database encryption key present, no encryption' 
					WHEN 1 THEN 'Unencrypted'
					WHEN 2 THEN 'Encryption in progress'
					WHEN 3 THEN 'Encrypted'
					WHEN 4 THEN 'Key change in progress'
					WHEN 5 THEN 'Decryption in progress'
					WHEN 6 THEN 'Protection change in progress'
				END  + ' ' + CAST(percent_complete as varchar(50)) + '%'
			FROM 
				sys.dm_database_encryption_keys
			WHERE 
				database_id = DB_ID(@DbName) AND encryption_state <> 3
			IF @@ROWCOUNT = 0
				BREAK
			PRINT @msg
			RAISERROR('', 10, 1) WITH NOWAIT
	END
	SELECT @msg = 'Encryption succeeeded and took ' + CAST(DATEDIFF(MINUTE, @startEncryptionTime, GETDATE()) as nvarchar(100)) + ' minutes.'
	PRINT @msg
END
GO

/*
 *  sp_tde_disable
 */
IF EXISTS (SELECT 1 FROM SYSOBJECTS WHERE NAME = 'sp_tde_disable')
	DROP PROCEDURE sp_tde_disable;
GO
CREATE PROCEDURE sp_tde_disable(@dbname nvarchar(50))
AS
BEGIN
	DECLARE @msg nvarchar(200)

	IF NOT EXISTS (SELECT 1 FROM sys.dm_database_encryption_keys where database_id = DB_ID(@DBName))
	BEGIN
		SET @msg = 'Database ' + @dbname + ' is not listed as encrypted database';
		RAISERROR(@Msg, -1, -1)
		RETURN
	END

	PRINT 'Activating decryption'
	EXEC('ALTER DATABASE [' + @dbname + '] SET ENCRYPTION OFF')

	PRINT 'Start polling decryption completion'

	DECLARE @startEncryptionTime as datetime;
	SET @startEncryptionTime = GETDATE();

	WHILE 1 = 1
	BEGIN
		WAITFOR DELAY '00:00:05'
			SELECT 
				@msg = 
				CASE encryption_state 
					WHEN 0 THEN 'No database encryption key present, no encryption' 
					WHEN 1 THEN 'Unencrypted'
					WHEN 2 THEN 'Encryption in progress'
					WHEN 3 THEN 'Encrypted'
					WHEN 4 THEN 'Key change in progress'
					WHEN 5 THEN 'Decryption in progress'
					WHEN 6 THEN 'Protection change in progress'
				END  + ' ' + CAST(percent_complete as varchar(50)) + '%'
			FROM 
				sys.dm_database_encryption_keys
			WHERE 
				database_id = DB_ID(@dbname) AND encryption_state <> 1
			IF @@ROWCOUNT = 0
				BREAK
			PRINT @msg
			RAISERROR('', 10, 1) WITH NOWAIT
	END
	SELECT @msg = 'Decryption succeeeded and took ' + CAST(DATEDIFF(MINUTE, @startEncryptionTime, GETDATE()) as nvarchar(100)) + ' minutes.'
	PRINT @msg
END
GO
