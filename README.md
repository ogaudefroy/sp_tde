# sp_tde
Some stored procedures to enable/disable Transparent Data Encryption in SQL Server

## sp_tde_create_dmk
Creates the database master key with password encryption.  
Usage: `exec sp_tde_create_dmk '98498aezaS'`

## sp_tde_drop_dmk
Drops the database master key
Usage: `exec sp_tde_drop_dmk`

## sp_tde_create_certificate
Creates a certificate to encrypt the database  
Usage: `exec sp_tde_create_certificate 'SampleCertificateName' 'SampleCertificateSubject'`

## sp_tde_drop_certificate
Drops a certificate stored in sys.certificates  
Usage: `exec sp_drop_certififacte 'SampleCertificateName'`

## sp_tde_create_dek
Creates a database encryption key based on the specifed certificate.  
Usage: `exec sp_tde_create_dek 'MyDataBase'`

## sp_tde_drop_dek
Creates a database encryption key based on the specifed certificate.  
Usage: `exec sp_tde_drop_dek 'MyDataBase'`

## sp_tde_enable
Turns on transparent data encryption on the specified database and encrypts its content with its configured database encryption key.
Polls the Encryption process and displays percentage progress.  
Usage: `exec sp_tde_disable 'MyDataBase'`  

## sp_tde_disable
Turns off transparent database encryption on the specified database and decrypts its content with its configured database encryption key.
Polls the decryption process and displays percentage progress.  
Usage: `exec sp_tde_disable 'MyDataBase'`  