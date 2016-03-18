/*   
  DATE: 7 Dec 2015	 
  VERSION: 15.7 (store verion)
  AUTHOR:  SUJI NAIR

  DETAILS ABOUT THIS SCRIPT:  
   - Mini version for CEX Stores
*/

-- Step  1 i.e. To create the SQL_ADMIN database which will store the monitoring configuratiON details AND stored procedures
SET NOCOUNT ON
SET ANSI_PADDING ON

USE [master]
EXEC sp_configure 'show advanced options',1
RECONFIGURE WITH OVERRIDE
EXEC sp_configure 'xp_cmdshell',1
RECONFIGURE  WITH OVERRIDE
EXEC sp_configure 'backup compression default',1
RECONFIGURE  WITH OVERRIDE
Exec sp_configure 'remote admin connections',1
RECONFIGURE  WITH OVERRIDE
EXEC SP_CONFIGURE  'Ad Hoc Distributed Queries', 1 
RECONFIGURE  WITH OVERRIDE

                -- To change Job History Retention settings
EXEC msdb.dbo.sp_set_sqlagent_properties @jobhistory_max_rows=-1, @jobhistory_max_rows_per_job=-1 
GO

DBCC TRACEON (1204,1222,-1)  --3605...these 3 flags need to be enabled fOR deadlock detection

IF NOT EXISTS(SELECT * FROM sys.databases WHERE name='SQL_ADMIN')
BEGIN
	CREATE DATABASE SQL_ADMIN
	ALTER DATABASE  SQL_ADMIN SET RECOVERY SIMPLE
END
GO

-- Step 2 i.e. to SELECT the monitoring database created above in step 1
USE SQL_ADMIN
GO

-- Step 3 i.e. IF schema does not EXISTS then create a schema called SqlMantainence 
IF SCHEMA_ID('SqlMantainence') IS NULL    
	EXEC ( 'CREATE SCHEMA [SQLMantainence] AUTHORIZATION [DBO]')
GO

IF SCHEMA_ID('Tracing') IS NULL    
	EXEC ( 'CREATE SCHEMA [Tracing] AUTHORIZATION [DBO]')
GO

IF SCHEMA_ID('TOBEDELETED') IS NULL    
	EXEC ( 'CREATE SCHEMA [TOBEDELETED] AUTHORIZATION [DBO]')
GO

IF SCHEMA_ID('Catalogue') IS NULL    
	EXEC ( 'CREATE SCHEMA [Catalogue] AUTHORIZATION [DBO]')
GO

IF SCHEMA_ID('ExtendedEvents') IS NULL    
	EXEC ( 'CREATE SCHEMA [ExtendedEvents] AUTHORIZATION [DBO]')
GO


IF  NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_id = OBJECT_ID(N'[SQLMantainence].[DBMantainenceConfiguration]') AND TYPE IN (N'U'))
BEGIN
	CREATE TABLE [SQLMantainence].[DBMantainenceConfiguration](
		[configurationType] [nvarchar](50) NOT NULL,
		[VALUE] [nvarchar](1000) NOT NULL,
		[IsDeleted] [smallint] NOT NULL,
		[Comments] [varchar](100) NULL,
		[ID] [int] IDENTITY(1,1) NOT NULL
	) 
END
GO

-- Step 4 ...CREATE DEFAULT CONFIGURATION ENTRIES AND ALSO MODIFY EXISTINGS ENTRIES WHERE REQUIRED FOR THIS UPGRADE

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'Environment')
    INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('Environment','IN_ Store',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {PROD/TEST/DEV}' WHERE [configurationType] = 'Environment' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'EmailRecipient')
   INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('EmailRecipient','sys-dba@webuy.com',0) 
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {semicolON seperated email add., who need to receive all SQL maintenance alerts}' WHERE [configurationType] = 'EmailRecipient' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'MinimumDiskSpaceForBackup')
  INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('MinimumDiskSpaceForBackup','5',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {numeric value as percentage}, minimum disk space fOR taking backup' WHERE [configurationType] = 'MinimumDiskSpaceForBackup' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'RetentionPeriodForFullbackupInDays')  
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('RetentionPeriodForFullbackupInDays','9',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {numeric value in days}' WHERE [configurationType] = 'RetentionPeriodForFullbackupInDays' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'RetentionPeriodForDiffbackupInDays')  
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('RetentionPeriodForDiffbackupInDays','9',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {numeric value in days}' WHERE [configurationType] = 'RetentionPeriodForDiffbackupInDays' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'RetentionPeriodForTLogbackupInDays')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('RetentionPeriodForTLogbackupInDays','8',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {numeric value in days}' WHERE [configurationType] = 'RetentionPeriodForTLogbackupInDays' 


IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'Full_BackupFolder')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('Full_BackupFolder','?',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {absolute path / network folder path WHERE FULL will be taken}' WHERE [configurationType] = 'Full_BackupFolder' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'Diff_BackupFolder')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('Diff_BackupFolder','?',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {absolute path / network folder path WHERE Differential will be taken}' WHERE [configurationType] = 'Diff_BackupFolder' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'T-log_BackupFolder')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('T-log_BackupFolder','?',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {absolute path / network folder path WHERE TLOG will be taken}' WHERE [configurationType] = 'T-log_BackupFolder' 

---------------

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'ExcludeDatabase')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('ExcludeDatabase','sql_admin',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {DATABASE NAME which need to be excluded FROM all maintenance tasks}' WHERE [configurationType] = 'ExcludeDatabase' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'ExcludeDatabase')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('ExcludeDatabase','sql_admin',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {DATABASE NAME which need to be excluded FROM all maintenance tasks}' WHERE [configurationType] = 'ExcludeDatabase' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'ExcludeDatabase')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('ExcludeDatabase','ReportServer',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {DATABASE NAME which need to be excluded FROM all maintenance tasks}' WHERE [configurationType] = 'ExcludeDatabase' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'ExcludeDatabase')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('ExcludeDatabase','ReportServerTempDB',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {DATABASE NAME which need to be excluded FROM all maintenance tasks}' WHERE [configurationType] = 'ExcludeDatabase' 

-------------

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'ShrinkDBRequired')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('ShrinkDBRequired','0',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {0/1}. IF true then database log file will bebacked up and shrinked if it grows' WHERE [configurationType] = 'ShrinkDBRequired' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'MaximumLogSizeAllowedOnServerForEachDatabase')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('MaximumLogSizeAllowedOnServerForEachDatabase','20000',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {numeric value in MB}' WHERE [configurationType] = 'MaximumLogSizeAllowedOnServerForEachDatabase' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'CheckDatabaseOnlineStatus')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('CheckDatabaseOnlineStatus','1',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {0/1}' WHERE [configurationType] = 'CheckDatabaseOnlineStatus' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'MinimumDiskSpaceForWarningInGB')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('MinimumDiskSpaceForWarningInGB','3',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'exected value = {numeric value in GB}, warning will be generated fOR all drives less than this value' WHERE [configurationType] = 'MinimumDiskSpaceForWarningInGB' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'ExcludeDiskSpaceCheckForDrive' AND VALUE = '?')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('ExcludeDiskSpaceCheckForDrive','?',0)

UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {Drive letter e.g. C/D/Q/etc }' WHERE [configurationType] = 'ExcludeDiskSpaceCheckForDrive' 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'CheckForFailedJobs')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('CheckForFailedJobs','1',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {0/1}' WHERE [configurationType] = 'CheckForFailedJobs' 


IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'CheckDeadLocksOnServer')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('CheckDeadLocksOnServer','1',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value = {0/1}. Do you need alert on each Deadlocks?' WHERE [configurationType] = 'CheckDeadLocksOnServer' 


Declare @VirtualServerAccount Varchar(100)
select @VirtualServerAccount = Cast( SERVERPROPERTY('MachineName') as varchar) + '$'

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'SQL_SERVER_SERVICE_ACCOUNT')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('SQL_SERVER_SERVICE_ACCOUNT','',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] 
SET COMMENTS = 'expected value = {domain\account name}, account used to run SQL server agent',  
Value = 'Local SERVICE, Local System, Network Service, NT Service,NT AUTHORITY\SYSTEM, NT SERVICE\SQLSERVERAGENT,SQLAccount_SVC,' + @VirtualServerAccount 
WHERE [configurationType] = 'SQL_SERVER_SERVICE_ACCOUNT'


IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'SQLTeamMembers')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('SQLTeamMembers','',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] 
SET COMMENTS = 'expected value= comma seperated list of SQL team members login id ',
    VALUE =  'SA, snair, nkhakharia, asingh, breddy, asingh, snair_adm, nkhakharia_adm, asingh_adm, breddy_adm, asingh_adm, sdubey, sdubey_adm, ndoke, ndoke_adm  '
WHERE [configurationType] = 'SQLTeamMembers'

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'CheckServerAuditLog')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('CheckServerAuditLog','1',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value= {0/1}. IF True then any server permissiON given by NON SQL member will be reported.' WHERE [configurationType] = 'CheckServerAuditLog'

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'ThresholdValueToGenerateSpaceUsageInDB')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('ThresholdValueToGenerateSpaceUsageInDB','80',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value= {Numeric Value}. e.g. 80 means  80% threshold value SET fOR warning' WHERE [configurationType] = 'ThresholdValueToGenerateSpaceUsageInDB'

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'DBNameForTrackingSpaceUsage')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('DBNameForTrackingSpaceUsage','?',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value= {database name}. DB name to track the database usage' WHERE [configurationType] = 'DBNameForTrackingSpaceUsage'

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'LogDatabaseAutoGrowth')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('LogDatabaseAutoGrowth','0',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value= [0/1]. IF 1 then every database auto growth is captured' WHERE [configurationType] = 'LogDatabaseAutoGrowth'

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'MonitorLogShippingStatus')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('MonitorLogShippingStatus','0',0)




UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value= {0/1}.  IF 1 (True) then the tool will monitOR Log Shipping status ON that server' WHERE [configurationType] = 'MonitorLogShippingStatus'

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'MonitorMirroringStatus')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('MonitorMirroringStatus','0',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value= {0/1}.  IF 1 (True) then the tool will monitOR Mirroring status ON that server' WHERE [configurationType] = 'MonitorMirroringStatus'

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'MonitorReplicationStatus')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('MonitorReplicationStatus','0',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value= {0/1}.  IF 1 (True) then the tool will monitOR ReplicatiON status ON that server' WHERE [configurationType] = 'MonitorReplicationStatus'

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'Replication_Publisher_Name')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('Replication_Publisher_Name','{enter publisher name}',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'expected value= Actual publisher server instance name e.g. AX-SQLPSC01-PRD\AXPROD' WHERE [configurationType] = 'Replication_Publisher_Name'

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'Threshold_For_Blocking_Seconds')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('Threshold_For_Blocking_Seconds','300',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'Threshold value for detecting blocking process in seconds' WHERE [configurationType] = 'Threshold_For_Blocking_Seconds'

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'Enable_Blocking_Alerts')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('Enable_Blocking_Alerts','0',0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = '0 for disbaling blocking alerts ..1 for enabling blocking alerts' WHERE [configurationType] = 'Enable_Blocking_Alerts'

Declare @LastDeploymentDetails varchar(100)
SET @LastDeploymentDetails =  '(Version 15.7 store version) => Deployed By ' + SUSER_NAME() + ' on ' + Cast(getdate() as Varchar(100)) 

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'LastDeploymentDetails')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted]) VALUES ('LastDeploymentDetails',@LastDeploymentDetails,0)
UPDATE   [SqlMantainence].[DBMantainenceConfiguration] SET COMMENTS = 'Who last deployed SQL tool & when ? ', Value = @LastDeploymentDetails 
WHERE [configurationType] = 'LastDeploymentDetails'

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'Enable_SQL_Trace_FLag' AND VALUE = '1222')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted], Comments) VALUES ('Enable_SQL_Trace_FLag','1222',0,'Flag No to enable deadlock tracing details')

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'Enable_SQL_Trace_FLag' AND VALUE = '1204')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted],Comments) VALUES ('Enable_SQL_Trace_FLag','1204',0,'Flag No to enable deadlock tracing details')

IF NOT EXISTS(SELECT  [configurationType] FROM [SqlMantainence].[DBMantainenceConfiguration] WHERE [configurationType] = 'UKDateFormatIssueExists')
	INSERT INTO [SQL_ADMIN].[SqlMantainence].[DBMantainenceConfiguration] ([configurationType], [VALUE],[IsDeleted],Comments) VALUES ('UKDateFormatIssueExists','No',0,'To handle date format issue on few servers i.e. UK date format conflicting while deleting backups')

		
-- Step 5 Creating ErrOR Log  Table fOR trapping errors 
USE [SQL_ADMIN]


IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[DBMantainenceLOG_National]') AND TYPE IN (N'U'))
BEGIN
CREATE TABLE [SQLMantainence].[DBMantainenceLOG_National](
[LogDate] [datetime] NOT NULL,
[TYPE] [varchar](300) NULL,
[LogDetails] [varchar](2000) NULL,
[Status] [char](1) NULL,
[Server] [varchar](50) NULL,
[id] [uniqueidentifier] NOT NULL DEFAULT (newid()),
PRIMARY KEY CLUSTERED 
(
[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

END
GO


IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[Blocking_History]') AND TYPE IN (N'U'))
BEGIN
CREATE TABLE [SQLMantainence].[Blocking_History](
	[ServerName] [nvarchar](200) NULL,
	[Blocked_DataBaseName] [nvarchar](200) NULL,
	[Blockee_ID] [varchar](100) NULL,
	[Blocker_ID] [varchar](100) NULL,
	[Wait_Time_Minutes] [int] NULL,
	[Wait_Type] [varchar](100) NULL,
	[Resource_Type] [varchar](100) NULL,
	[Requesting_Text] [nvarchar](max) NULL,
	[Blocking_Text] [nvarchar](max) NULL,
	[Blocking_DateTime] [datetime] NULL DEFAULT (GETDATE())
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[SQLJobDetails_OnThisServer]') AND TYPE IN (N'U'))
BEGIN
CREATE TABLE [SQLMantainence].[SQLJobDetails_OnThisServer](
	[JobID] [uniqueidentifier] NULL,
	[JobName] [varchar](256) NULL,
	[Owner] [varchar](256) NULL,
	[AppName] [varchar](100) NULL,
	[OtherDetails] [varchar](max) NULL,
	[CreatedOn] [smalldatetime] NULL,
	[LastModifiedOn] [smalldatetime] NULL,
	[JobEnabled] [bit] NULL,
	[IsDeleted] [bit] NULL,
	[DeletedOn] [smalldatetime] NULL,
	[DeletedBy] [varchar](256) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[HistoryOfDatabaseSize]') AND TYPE IN (N'U'))
BEGIN
CREATE TABLE [SQLMantainence].[HistoryOfDatabaseSize](
	[DatabaseID] [smallint] NULL,
	[DatabaseName] [varchar](1000) NULL,
	[AddedOn] [smalldatetime] NULL,
	[FileType] [varchar](50) NULL,
	[FileName] [varchar](1000) NULL,
	[PhysicalFileName] [varchar](1000) NULL,
	[TotalSpaceInMB] [float] NULL,
	[UsedSpaceInMB] [float] NULL,
	[FreeSpaceInMB] [float] NULL,
	[Percentage_SpaceAvailable] [float] NULL
) ON [PRIMARY]
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[DatabaseCatalogue]') AND TYPE IN (N'U'))
BEGIN
CREATE TABLE [SQLMantainence].[DatabaseCatalogue](
	[DatabaseID] [smallint] NOT NULL,
	[DatabaseName] [varchar](1000) NOT NULL,
	[Owner] [varchar](100) NULL,
	[AppName] [varchar](100) NULL,
	[CreatedOn] [smalldatetime] NULL,
	[CreatedBy] [varchar](256) NULL,
	[OtherDetails] [varchar](max) NULL,
	[IsDeleted] [bit] NULL,
	[DeletedOn] [smalldatetime] NULL,
	[DeletedBy] [varchar](256) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

END
ELSE
   Print 'DatabaseCatalogue Table already existed....please check the structure manually for confirmation'
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[DBMantainenceLOG]') AND TYPE IN (N'U'))
BEGIN
	CREATE TABLE [SQLMantainence].[DBMantainenceLOG](
		[LogDate] [DATETIME] NOT NULL,
		[TYPE] [VarChar](300) NULL,
		[LogDetails] [VarChar](MAX) NULL,
		[Status] [CHAR](1) NULL
	) 
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[tmpColumnsDetailsForDatabaseOnlineRebuild]') AND TYPE IN (N'U'))
BEGIN
	CREATE TABLE [SQLMantainence].[tmpColumnsDetailsForDatabaseOnlineRebuild](
		[object_id] [int] NULL,
		[user_type_id] [int] NULL,
		[max_length] [smallint] NULL,
		[IDXname] [varchar](1000) NULL,
		[IDXtype] [tinyint] NULL
	) 
END







-- Step 6  CREATING DEPLOYMENT TABLE USED FOR ANY FUTURE REMOTE DEPLOYMENT FROM THIS SERVER
USE [SQL_ADMIN]
GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_ServerDetails_IsDeploymentRequired]') AND TYPE = 'D')
BEGIN
ALTER TABLE [SQLMantainence].[ServerDetails] DROP CONSTRAINT [DF_ServerDetails_IsDeploymentRequired]
END

GO

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[DF_ServerDetails_IsDeploymentCompleted]') AND TYPE = 'D')
BEGIN
ALTER TABLE [SQLMantainence].[ServerDetails] DROP CONSTRAINT [DF_ServerDetails_IsDeploymentCompleted]
END

GO

USE [SQL_ADMIN]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[ServerDetails]') AND TYPE IN (N'U'))
DROP TABLE [SQLMantainence].[ServerDetails]
GO

USE [SQL_ADMIN]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [SQLMantainence].[ServerDetails](
	[SERVERNAME] [VarChar](1000) NULL,
	[Environment] [VarChar](50) NULL,
	[IsDeploymentRequired] [BIT] NULL,
	[IsDeploymentCompleted] [BIT] NULL,
	[Comments] [VarChar](1000) NULL
) ON [PRIMARY]

GO

ALTER TABLE [SQLMantainence].[ServerDetails] ADD  CONSTRAINT [DF_ServerDetails_IsDeploymentRequired]  DEFAULT ((0)) FOR [IsDeploymentRequired]
GO

ALTER TABLE [SQLMantainence].[ServerDetails] ADD  CONSTRAINT [DF_ServerDetails_IsDeploymentCompleted]  DEFAULT ((0)) FOR [IsDeploymentCompleted]
GO

-- Deleting the old PermissiON Audit table in SQL_ADMIN database, IF it EXISTS
IF EXISTS (SELECT 1 FROM SQL_ADMIN.sys.objects WHERE Name = 'PermissionAudit' AND TYPE IN (N'U'))
	Drop Table SQL_ADMIN.SQLMantainence.PermissionAudit
GO


Use SQL_Admin
GO

If EXISTS(SELECT  1 from INFORMATION_SCHEMA.ROUTINES  WHERE SPECIFIC_SCHEMA = 'SQLMantainence' and  ROUTINE_NAME = 'Log_Error')
    DROP PROCEDURE [SQLMantainence].[Log_Error]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Exec [SQLMantainence].[Log_Error] ''faf'',''fafda'
-- =============================================
CREATE PROCEDURE [SQLMantainence].[Log_Error] 
  (
  @ProcedureName VarChar(100),
  @Type VarChar(50)
  )
-- With Encryption  	
AS
BEGIN
	SET NOCOUNT ON;

    DECLARE @ERRORMESSAGE VarChar(MAX) ,
	@FormattedErrorMessage  VarChar(MAX),
	@ErrorNumber VarChar(50),
	@ErrorSeverity VarChar(50),
	@ErrorState  VarChar(50),
	@ErrorLine  VarChar(50),
	@ErrorProcedure  VarChar(200)          
                  
	IF(@ErrorMessage IS NOT NULL) 
	BEGIN     
		SELECT  @ErrorNumber = CAST(ERROR_NUMBER() AS VarChar(50)),
			@ErrorMessage = ERROR_MESSAGE(),
			@ErrorSeverity = CAST(ERROR_SEVERITY() AS VarChar),
			@ErrorState = CAST(ERROR_STATE() AS VarChar), 
			@ErrorLine = CAST(ERROR_LINE() AS VarChar),
			@ErrorProcedure = ISNULL(@ProcedureName, '-'); 
	               
		SELECT @FormattedErrorMessage='ERROR NUMBER= '+@ErrorNumber+' '+'ERROR LEVEL= '+@ErrorSeverity+' '+'ERROR STATE= '+@ErrorState+' '+'ERROR LINE= '+@ErrorLine+' '+'ERROR PROCEDURE= '+@ErrorProcedure+' '+'ERROR MESSAGE='+@ErrorMessage+' '
		INSERT INTO SQL_ADMIN.SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),@Type,@FormattedErrorMessage,'C');         
	END
END	
GO


-- Step   ...CREATE SP_HEXADECIMAL FUNCTION TO RETRIEVE BINARY VALUES FOR PASSWORD RETIREVAL
USE master
GO
IF OBJECT_ID ('sp_hexadecimal') IS NOT NULL
	DROP PROCEDURE sp_hexadecimal
GO

CREATE PROCEDURE sp_hexadecimal
@binvalue VARBINARY(256),
@hexvalue VarChar(256) OUTPUT
AS
	DECLARE @charvalue VarChar(256)
	DECLARE @i INT
	DECLARE @length INT
	DECLARE @hexstring CHAR(16)
	SELECT @charvalue = '0x'
	SELECT @i = 1
	SELECT @length = DATALENGTH (@binvalue)
	SELECT @hexstring = '0123456789ABCDEF'
	WHILE (@i <= @length)
	BEGIN
	DECLARE @tempint INT
	DECLARE @firstint INT
	DECLARE @secondint INT
	SELECT @tempint = CONVERT(INT, SUBSTRING(@binvalue,@i,1))
	SELECT @firstint = FLOOR(@tempint/16)
	SELECT @secondint = @tempint - (@firstint*16)
	SELECT @charvalue = @charvalue +
	SUBSTRING(@hexstring, @firstint+1, 1) +
	SUBSTRING(@hexstring, @secondint+1, 1)
	SELECT @i = @i + 1
END
SELECT @hexvalue = @charvalue
GO

-- Step 8  ...ENABLING SERVER AUDIT TRACING USING ALL SERVER TRIGGER

IF NOT EXISTS (SELECT 1 FROM master.sys.objects WHERE NAME = N'PermissionAudit')
BEGIN
	CREATE TABLE Master.dbo.PermissionAudit (eventtime DATETIME DEFAULT GETDATE(), eventtype NVarChar (100), serverLogin NVarChar(100) NOT NULL,DBUser NVarChar (100) NOT NULL,TSQLText VarChar (MAX), eventdata XML NOT NULL)
END
GO

USE Master
Grant Insert ON master.dbo.PermissionAudit To Public 
GO


USE [master]
GO

IF NOT EXISTS (SELECT 1 FROM master.sys.objects WHERE NAME = N'EPOS2000Audit')
BEGIN
	CREATE TABLE [dbo].[EPOS2000Audit](
		[event_time] [datetime2](7) NOT NULL,
		[user_name] [varchar](150) NULL,
		[Action] [varchar](10) NULL,
		[database_name] [varchar](150) NULL,
		[schema_name] [varchar](150) NULL,
		[table_name] [varchar](150) NULL,
		[host_name] [varchar](150) NULL,
		[app_name] [varchar](150) NULL,
		[OldContent] [xml] NULL,
		[NewContent] [xml] NULL
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO

Grant Insert ON master.dbo.EPOS2000Audit To Public 
GO


IF EXISTS(SELECT 1 FROM master.sys.server_triggers WHERE name = N'PermissionAudit')
BEGIN
	DISABLE TRIGGER permissionAudit ON ALL SERVER
	DROP TRIGGER PermissionAudit ON ALL SERVER
END
GO

CREATE TRIGGER [PermissionAudit]
	ON ALL SERVER
	FOR CREATE_LOGIN,ALTER_LOGIN, DROP_LOGIN, ALTER_AUTHORIZATION_SERVER,
		GRANT_SERVER,DENY_SERVER, REVOKE_SERVER,
		GRANT_DATABASE, DENY_DATABASE, REVOKE_DATABASE, CREATE_ROLE, ALTER_ROLE, DROP_ROLE ,
		CREATE_DATABASE, ALTER_DATABASE, DROP_DATABASE,CREATE_SCHEMA, ALTER_SCHEMA, DROP_SCHEMA,
		CREATE_USER,  ALTER_USER, DROP_USER, ADD_ROLE_MEMBER, DROP_ROLE_MEMBER, ADD_SERVER_ROLE_MEMBER
	    , ALTER_TABLE, CREATE_TABLE, DROP_TABLE
	AS
	BEGIN
		  DECLARE @Eventdata XML
		  SET @Eventdata = EVENTDATA()

			IF EXISTS(SELECT 1 FROM master.information_schema.tables WHERE table_name = 'PermissionAudit')
			Begin
				INSERT into master.dbo.PermissionAudit
					(EventType,EventData, ServerLogin,DBUser,TSQLText)
					VALUES (@Eventdata.value('(/EVENT_INSTANCE/EventType)[1]', 'nVarChar(100)'),
							@Eventdata, system_USER,CONVERT(nVarChar(100), CURRENT_USER),
							@Eventdata.value('(/EVENT_INSTANCE/TSQLCommand)[1]', 'nVarChar(2000)' ))
			End

	END                  


GO
Enable TRIGGER PermissionAudit ON ALL SERVER 

 /* 

Disable trigger permissionAudit ON all server
drop trigger PermissionAudit ON all server
drop table  master.dbo.PermissionAudit

SELECT * FROM master.dbo.PermissionAudit ORDER BY 1 desc
*/        

---------------------------------------------------------------------------------------
-- Next Step ...enable audit for epos2000 database

USE [master]
GO

IF EXISTS(SELECT 1 FROM SYS.SERVER_TRIGGERS WHERE NAME = 'TRG_TO_STOP_SSMS_USAGE')
	DROP TRIGGER [TRG_TO_STOP_SSMS_USAGE] ON ALL SERVER
GO

CREATE TRIGGER [Trg_to_stop_SSMS_Usage] 
ON ALL SERVER FOR  LOGON 
AS 
BEGIN 
	DECLARE  @program_name nvarchar(128)
	DECLARE @host_name nvarchar(128) 
	DECLARE @lOGIN nvarchar(128) = ORIGINAL_LOGIN()

	SELECT @program_name = program_name,  @host_name = host_name FROM sys.dm_exec_sessions AS c 
	WHERE c.session_id = @@spid IF ORIGINAL_LOGIN()  IN('boffice','BOPlus','cexservices','eposv2') AND @program_name LIKE '%Management%Studio%' 
		ROLLBACK; 

END
GO

ENABLE TRIGGER [Trg_to_stop_SSMS_Usage] ON ALL SERVER
GO


 /* 

Disable trigger Trg_to_stop_SSMS_Usage ON all server
drop trigger Trg_to_stop_SSMS_Usage ON all server
drop table  master.dbo.EPOS2000Audit

SELECT * FROM master.dbo.EPOS2000Audit ORDER BY 1 desc
*/        

--------------------------------------------

--- creating audit triggers for all configuration tables in epos2000 
USE [epos2000]
GO


IF  OBJECT_ID('trg_DMLAudit_StockTransferType') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_StockTransferType

GO
IF  OBJECT_ID('StockTransferType') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_StockTransferType]
   ON [dbo].[StockTransferType]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_StockTransferStatus') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_StockTransferStatus

GO

IF  OBJECT_ID('StockTransferStatus') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_StockTransferStatus]
   ON [dbo].[StockTransferStatus]
   FOR DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END


----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_StockTransferMethod') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_StockTransferMethod

GO

IF  OBJECT_ID('StockTransferMethod') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_StockTransferMethod]
   ON [dbo].[StockTransferMethod]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_RMAStoresBranches') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_RMAStoresBranches

GO
IF  OBJECT_ID('RMAStoresBranches') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_RMAStoresBranches]
   ON [dbo].[RMAStoresBranches]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_RMAReasonCode') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_RMAReasonCode

GO
IF  OBJECT_ID('RMAReasonCode') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_RMAReasonCode]
   ON [dbo].[RMAReasonCode]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_RMAReason') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_RMAReason

GO
IF  OBJECT_ID('RMAReason') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_RMAReason]
   ON [dbo].[RMAReason]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_Permissions') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_Permissions

GO
IF  OBJECT_ID('Permissions') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_Permissions]
   ON [dbo].[Permissions]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_Permission') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_Permission

GO
IF  OBJECT_ID('Permission') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_Permission]
   ON [dbo].[Permission]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_PaymentMethods') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_PaymentMethods

GO
IF  OBJECT_ID('PaymentMethods') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_PaymentMethods]
   ON [dbo].[PaymentMethods]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_OperatingCompany') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_OperatingCompany

GO
IF  OBJECT_ID('OperatingCompany') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_OperatingCompany]
   ON [dbo].[OperatingCompany]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_numbers') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_numbers
GO
/*
IF  OBJECT_ID('numbers') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_numbers]
   ON [dbo].[numbers]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

*/
----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_LocnBranchLiveOnes') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_LocnBranchLiveOnes

GO
IF  OBJECT_ID('LocnBranchLiveOnes') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_LocnBranchLiveOnes]
   ON [dbo].[LocnBranchLiveOnes]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END


----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_locations') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_locations

GO
IF  OBJECT_ID('locations') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_locations]
   ON [dbo].[locations]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_LocationBranches') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_LocationBranches

GO
IF  OBJECT_ID('LocationBranches') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_LocationBranches]
   ON [dbo].[LocationBranches]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_LabelPrinterType') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_LabelPrinterType

GO
IF  OBJECT_ID('LabelPrinterType') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_LabelPrinterType]
   ON [dbo].[LabelPrinterType]
   FOR INSERT,DELETE,UPDATE





AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_BranchSetting') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_BranchSetting

GO
IF  OBJECT_ID('BranchSetting') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_BranchSetting]
   ON [dbo].[BranchSetting]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_branchesonline') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_branchesonline
GO
IF  OBJECT_ID('branchesonline') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_branchesonline]
   ON [dbo].[branchesonline]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_Branches') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_Branches
GO
IF  OBJECT_ID('Branches') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_Branches]
   ON [dbo].[Branches]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_Banking') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_Banking
GO
IF  OBJECT_ID('Banking') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_Banking]
   ON [dbo].[Banking]
   FOR DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------
IF  OBJECT_ID('trg_DMLAudit_BackOfficeApp') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_BackOfficeApp
GO
IF  OBJECT_ID('BackOfficeApp') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_BackOfficeApp]
   ON [dbo].[BackOfficeApp]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------

IF  OBJECT_ID('trg_DMLAudit_AuditEntryTypes') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_AuditEntryTypes
GO
IF  OBJECT_ID('AuditEntryTypes') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_AuditEntryTypes]
   ON [dbo].[AuditEntryTypes]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),


	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END
----------------------------------------

IF  OBJECT_ID('trg_DMLAudit_WorkstationBranches') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_WorkstationBranches
GO
IF  OBJECT_ID('WorkstationBranches') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_WorkstationBranches]




   ON [dbo].[WorkstationBranches]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END

----------------------------------------

IF  OBJECT_ID('trg_DMLAudit_Workstations') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_Workstations
GO
IF  OBJECT_ID('Workstations') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_Workstations]
   ON [dbo].[Workstations]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END


----------------------------------------

IF  OBJECT_ID('trg_DMLAudit_RMABranches') IS NOT NULL
	DROP TRIGGER trg_DMLAudit_RMABranches
GO
IF  OBJECT_ID('RMABranches') IS NOT NULL
BEGIN
EXECUTE ('
CREATE TRIGGER [dbo].[trg_DMLAudit_RMABranches]
   ON [dbo].[RMABranches]
   FOR INSERT,DELETE,UPDATE
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @Action varchar(10) 

	IF NOT EXISTS(SELECT 1 FROM INSERTED)
	SET @ACTION = ''DELETE''
	ELSE IF NOT EXISTS(SELECT 1 FROM DELETED)
	SET @ACTION = ''INSERT''
	ELSE
	SET @ACTION = ''UPDATE''	


   	Insert into master.dbo.EPOS2000Audit
               ([event_time],[user_name],[database_name],[schema_name],[table_name],[host_name],[app_name],[OldContent],[NewContent], Action)
	SELECT getdate(), SUSER_NAME(), db_name() ,
	       OBJECT_SCHEMA_NAME(parent_obj), OBJECT_NAME(parent_obj),HOST_NAME(),APP_NAME(),
	  case when (select count(1) from deleted) > 0 then (select * from deleted for xml raw ) end,
              case when (select count(1) from inserted) > 0 then (select * from inserted for xml raw) end,
	  @Action
        FROM sysobjects so  WHERE so.id = @@PROCID  
END

')
END
--=======================================
-----------------------------------------------------------------------------------------



-- Step  .... CREATING REST OF THE STORED PROCEDURES / FUNCTIONS

USE [SQL_ADMIN]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[udf_IsOnlineIndexingPossible]') AND TYPE IN (N'FN', N'IF', N'TF', N'FS', N'FT'))
	DROP FUNCTION [SQLMantainence].[udf_IsOnlineIndexingPossible]
GO

CREATE FUNCTION [SQLMantainence].[udf_IsOnlineIndexingPossible] 
(@avg_fragmentation_in_percent Float
,@IndexName VarChar(1000)
,@IndexType smallint
,@Key_Ordinal TinyInt
) 
RETURNS BIT AS 
BEGIN 
	DECLARE @bitRETURNValue BIT = 1  -- Default is True  

	-- ***********************************************************************************************
	-- Refer http://technet.microsoft.com/en-us/library/ms188388.aspx fOR more details ON line indexing
	-- This functiON RETURNs whether to choose ReOrganize OR ONLINE REBUILD of Indexes
	-- ***********************************************************************************************

		-- IF the server is not using SQL Enterprise EditiON then ONLINE indexing is not possible
	IF CharIndex('enterprise',Cast(SERVERPROPERTY('edition') as nVarChar(1000)),1) = 0
		SET @bitRETURNValue = 0   
	ELSE IF @avg_fragmentation_in_percent <= 30	 -- IF FragmentatiON Level less then 30 then GO fOR REORGANIZING (i.e. ONLINE Indexing = not required ) 
		SET @bitRETURNValue = 0 
	ELSE  IF @IndexType =3 --IF xml Type then Reorganize 
	    SET @bitRETURNValue = 0 
	ELSE IF @Key_Ordinal = 0 -- Key Ordinal = 0 means Not a key column, OR is an XML index, xVelocity memory optimized columnstore, OR spatial index.
		SET @bitRETURNValue = 0  
    ELSE IF EXISTS(
				SELECT 1 FROM SQL_Admin.SQLMantainence.tmpColumnsDetailsForDatabaseOnlineRebuild c 
				WHERE IDXname=@IndexName AND IDXtype = 1 AND (TYPE_NAME(c.user_type_id) IN ('xml','text', 'ntext','image','VarChar','nVarChar','varbinary') or max_length = -1)
				) 	   
			  SET @bitRETURNValue=0
     ELSE
		 SET @bitRETURNValue = 1      -- Default is True  
	 
	RETURN @bitRETURNValue 
END
GO


USE [SQL_ADMIN]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[udf_GetSchedule_DescriptionOfJob]') AND TYPE IN (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [SQLMantainence].[udf_GetSchedule_DescriptionOfJob]
GO


CREATE FUNCTION [SQLMantainence].[udf_GetSchedule_DescriptionOfJob] (@freq_type INT , 
  @freq_interval INT , 
  @freq_subday_type INT , 
  @freq_subday_interval INT , 
  @freq_relative_interval INT , 
  @freq_recurrence_factOR INT , 
  @active_start_date INT , 
  @active_end_date INT, 
  @active_start_time INT , 
  @active_end_time INT ) 
RETURNS NVarChar(255) AS 
BEGIN 
	DECLARE @schedule_descriptiON NVarChar(255) 
	DECLARE @loop INT 
	DECLARE @idle_cpu_percent INT 
	DECLARE @idle_cpu_duratiON INT 

	SELECT @schedule_descriptiON = ''
	
	IF (@freq_type = 0x8) -- Weekly 
	BEGIN 		
		SELECT @loop = 1 
		WHILE (@loop <= 7) 
		BEGIN 
			IF (@freq_interval & POWER(2, @loop - 1) = POWER(2, @loop - 1)) 
				SELECT @schedule_descriptiON = @schedule_descriptiON + DATENAME(dw, N'1996120' + CONVERT(NVarChar, @loop)) + N', ' 
			
			SELECT @loop += 1 
		END 

		IF (RIGHT(@schedule_description, 2) = N', ') 
			SELECT @schedule_descriptiON = SUBSTRING(@schedule_description, 1, (DATALENGTH(@schedule_description) / 2) - 2) + N' ' 	
	END   -- END of IF freq = Weekly 
	
	
	IF (@freq_type = 0x10) -- Monthly 
		SELECT @schedule_descriptiON = N'Every ' + CONVERT(NVarChar, @freq_recurrence_factor) + N' months(s) ON day ' + CONVERT(NVarChar, @freq_interval) + N' of that month ' 


	IF (@freq_type = 0x20) -- Monthly Relative 
	BEGIN 
		SELECT @schedule_descriptiON = N'Every ' + CONVERT(NVarChar, @freq_recurrence_factor) + N' months(s) ON the ' 
		
		SELECT @schedule_descriptiON = @schedule_descriptiON + 		
			CASE @freq_relative_interval 
				WHEN 0x01 THEN N'first ' 
				WHEN 0x02 THEN N'second ' 
				WHEN 0x04 THEN N'third ' 
				WHEN 0x08 THEN N'fourth ' 
				WHEN 0x10 THEN N'last ' 
			END + 
			CASE 
			WHEN (@freq_interval > 00) AND (@freq_interval < 08) THEN DATENAME(dw, N'1996120' + CONVERT(NVarChar, @freq_interval)) 
			WHEN (@freq_interval = 08) THEN N'day' 
			WHEN (@freq_interval = 09) THEN N'week day' 
			WHEN (@freq_interval = 10) THEN N'weekEND day' 
		 END + N' of that month ' 
	END 

	RETURN @schedule_descriptiON 
END
GO





USE [SQL_ADMIN]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[sp_ReOrganizeALLIndexInaDatabase]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[sp_ReOrganizeALLIndexInaDatabase]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[sp_ShrinkDatabase]') AND TYPE IN (N'P', N'PC'))



DROP PROCEDURE [SQLMantainence].[sp_ShrinkDatabase]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[RunSQLMaintenanceDeployment]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[RunSQLMaintenanceDeployment]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[proc_DeleteOldFullBackups]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[proc_DeleteOldFullBackups]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[proc_DeleteOldTLOGBackups]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[proc_DeleteOldTLOGBackups]
GO


IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[ResolveOrphanUsers]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[ResolveOrphanUsers]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[SP_MantainencePlanScriptForDiffBackup]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[SP_MantainencePlanScriptForDiffBackup]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[DBO].[PROC_EXECUTEBACKUP]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [DBO].[PROC_EXECUTEBACKUP]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[SP_MantainencePlanScriptForFullBackup_ForSecondBackupJob]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[SP_MantainencePlanScriptForFullBackup_ForSecondBackupJob]
GO


IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[SP_MantainencePlanScriptForFullBackup]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[SP_MantainencePlanScriptForFullBackup]
GO

GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[SP_MantainencePlanScriptForTLogBackup]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[SP_MantainencePlanScriptForTLogBackup]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[SP_MantainencePlanScriptForMonthlyBackup]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[SP_MantainencePlanScriptForMonthlyBackup]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[SP_MantainencePlanScriptForYearlyBackup]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[SP_MantainencePlanScriptForYearlyBackup]
GO



IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[UpdateStatisticsForAllDatabases]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[UpdateStatisticsForAllDatabases]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[CheckFreeSpaceInDrivee]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[CheckFreeSpaceInDrivee]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[Check_DailyBackupFailures]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[Check_DailyBackupFailures]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[Get_Job_Day]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[Get_Job_Day]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[MaintenanceLogCleanUp]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[MaintenanceLogCleanUp]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[MonitoringAlerts1_15Minutes]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[MonitoringAlerts1_15Minutes]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[MonitoringAlerts2_5Minutes]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[MonitoringAlerts2_5Minutes]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[MonitoringAlerts3_Hourly]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[MonitoringAlerts3_Hourly]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[MonitoringAlerts4_DailyOnce]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[MonitoringAlerts4_DailyOnce]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[CreateAllServerTrigger]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[CreateAllServerTrigger]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[CreateLinkedServer]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[CreateLinkedServer]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[ScriptDatabaseUsersAfterDatabaseRefresh]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[ScriptDatabaseUsersAfterDatabaseRefresh]
GO


IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[DatabaseRefresh_ScriptDatabaseUsersBeforeRestore]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[DatabaseRefresh_ScriptDatabaseUsersBeforeRestore]
GO



IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[TrackDBSpaceUsage]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[TrackDBSpaceUsage]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[ExecuteAdhocBackupRequest]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[ExecuteAdhocBackupRequest]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[sp_DeleteAdhocBackupFilesAFterRetentionPeriod]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[sp_DeleteAdhocBackupFilesAFterRetentionPeriod]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[sp_DeleteTableBackupsAFterRetentionPeriod]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[sp_DeleteTableBackupsAFterRetentionPeriod]
GO


IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[Monitor_LogShippingStatus]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[Monitor_LogShippingStatus]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[Monitor_MirroringStatus]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[Monitor_MirroringStatus]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[CheckDatabaseAutoGrowth]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[CheckDatabaseAutoGrowth]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[sp_Rebuild_OR_ReOrganize_ALLIndexInAllDatabases]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[sp_Rebuild_OR_ReOrganize_ALLIndexInAllDatabases]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[Replication_Publisher_Details]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[Replication_Publisher_Details]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[Monitor_ReplicationStatus]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[Monitor_ReplicationStatus]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[GetFreeSpaceofDrive]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[GetFreeSpaceofDrive]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[GetTotalSpaceofDrive]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[GetTotalSpaceofDrive]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[DatabaseRefresh_DeleteAllUsersFromADatabase]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[DatabaseRefresh_DeleteAllUsersFromADatabase]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[UpdateDatabaseCatalogue]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[UpdateDatabaseCatalogue]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[CreateAdditinalFileGroupForADatabase]') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE [SQLMantainence].[CreateAdditinalFileGroupForADatabase]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[CreateDBRolesAndAutoGrowthForDevelopmentServer]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [SQLMantainence].[CreateDBRolesAndAutoGrowthForDevelopmentServer]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[CreateDBRolesAndAutoGrowthForTestServer]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [SQLMantainence].[CreateDBRolesAndAutoGrowthForTestServer]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[CreateDBRolesAndAutoGrowthForProductionServer]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [SQLMantainence].[CreateDBRolesAndAutoGrowthForProductionServer]
GO


IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[Check_ProcessBlockings]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [SQLMantainence].[Check_ProcessBlockings]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_id = OBJECT_ID(N'[SQLMantainence].[WhatIsGoingOn]') AND TYPE IN (N'V'))
	DROP VIEW [SQLMantainence].[WhatIsGoingOn]


IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[TRACING].[TrapLiveQueriesDuringTempDbAutoGrowth]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [TRACING].[TrapLiveQueriesDuringTempDbAutoGrowth]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[TRACING].[GetTempDBRelatedDataOnAutoGrowthEvent]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [TRACING].[GetTempDBRelatedDataOnAutoGrowthEvent]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[SP_MantainencePlanScriptForFullBackupOfSSASDatabases]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [SQLMantainence].[SP_MantainencePlanScriptForFullBackupOfSSASDatabases]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[GenerateSQLServerHealthCheckReport]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [SQLMantainence].[GenerateSQLServerHealthCheckReport]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[CaptureAndSendSQLServerHealthCheckReport]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [SQLMantainence].CaptureAndSendSQLServerHealthCheckReport
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[DBO].[GenerateCPUUtilizationStatsByEachDatabases]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE GenerateCPUUtilizationStatsByEachDatabases
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[PROC_DELETEOLD_AzureFULLBACKUPS]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [SQLMantainence].[PROC_DELETEOLD_AzureFULLBACKUPS]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[PROC_DELETEOLD_AzureTLogBACKUPS]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [SQLMantainence].[PROC_DELETEOLD_AzureTLogBACKUPS]
GO

 IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[ExecuteCheckDBForAllDatabases]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [SQLMantainence].[ExecuteCheckDBForAllDatabases] 
GO

 IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[proc_LatencyCheckReport]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [dbo].[proc_LatencyCheckReport] 
GO

 IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[Useful_Queries_ToBeUsedWith_Dedicated_Admin_connection]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [dbo].[Useful_Queries_ToBeUsedWith_Dedicated_Admin_connection] 
GO

 IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[Catalogue].[FillSQLCatalogueTablesThruPowershell]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [Catalogue].[FillSQLCatalogueTablesThruPowershell] 
GO

 IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[SentEmailWithLatestSQLSoftwareCatalogues]') AND TYPE IN (N'P', N'PC'))
	DROP PROCEDURE [SQLMantainence].[SentEmailWithLatestSQLSoftwareCatalogues] 
GO

--*************************************
-- END OF DROP PROCEDURE SECTION ABOVE
--**************************************


-- *****************************************
-- START OF CREATING NEW PROCEDURES BELOW
--*******************************************

USE [SQL_Admin]
GO
/****** Object:  StoredProcedure [Catalogue].[FillSQLCatalogueTablesThruPowershell]    Script Date: 11/4/2014 6:21:47 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
	
Create procedure [Catalogue].[FillSQLCatalogueTablesThruPowershell]
AS
BEGIN
EXEC master..xp_cmdshell '"C:\SQL_Admin\PS Catalog scripts\DBSInventoryDev.cmd'

EXEC master..xp_cmdshell '"C:\SQL_Admin\PS Catalog scripts\DBSInventoryTest.cmd"'

EXEC master..xp_cmdshell '"C:\SQL_Admin\PS Catalog scripts\DBSInventoryProd.cmd"'

END
GO


/****** Object:  StoredProcedure [SQLMantainence].[SentEmailWithLatestSQLSoftwareCatalogues]    Script Date: 11/4/2014 6:22:43 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		SQL Support Team
-- Create date: 3rd July 2014
-- Description:	Update LAtest Software Catalogue Details to SQL Team ....weeekly
-- =============================================
CREATE PROCEDURE [SQLMantainence].[SentEmailWithLatestSQLSoftwareCatalogues]
AS
BEGIN
	SET NOCOUNT ON;
	Declare @SQLError INT
	 Declare @SQL varchar(5000)
	 Declare @FileName varchar(1000)
	 Declare @FilePath varchar(1000) = 'F:\SoftwareCatalogueReportingDONOTDELETE\Data\'   -- ENSURE THAT THIS FOLDER ALWAYS EXISTS
	 Declare @SQLTeamMail_Attachment varchar(8000) = ''

	

	 -- **************************************************************************************************************************************
	 -- Fill SQL Catalogue Tables Thru Powershell
	 -- **************************************************************************************************************************************

		EXEC Catalogue.FillSQLCatalogueTablesThruPowershell

	 -- **************************************************************************************************************************************

	 -- **************************************************************************************************************************************
	 -- Report 1 : Export SQL Sotware Catalogue i.e. SQL Server List
	 -- **************************************************************************************************************************************
	 SET @FileName = @FilePath + 'SQLServersCatalogue.CSV'

	 --Replace(Replace(Replace(IsNull([BLOCKED_SQL],''''),char(10),''''),'','',Char(130)),char(13),'''') as BLOCKED_SQL
	 SET @SQL = 'SELECT  Row_Number() over (order by Environment,ServerName) as SrNo,[Environment], Row_Number() over (partition by Environment Order By ServerName) as Ref_No, Replace(Replace(Replace(IsNull([IPAddress],''''),char(10),''''),'','',Char(130)),char(13),'''') as [IPAddress], Replace(Replace(Replace(IsNull([ServerName],''''),char(10),''''),'','',Char(130)),char(13),'''') as [ServerName], Replace(Replace(Replace(IsNull([Location],''''),char(10),''''),'','',Char(130)),char(13),'''') as [Location],[IsCluster] ,Replace(Replace(Replace(IsNull([Applications],''''),char(10),''''),'','',Char(130)),char(13),'''') as [Applications],Replace(Replace(Replace(IsNull([PrimaryFunction],''''),char(10),''''),'','',Char(130)),char(13),'''') as [PrimaryFunction],Replace(Replace(Replace(IsNull([SQLVersion],''''),char(10),''''),'','',Char(130)),char(13),'''') as [SQLVersion],Replace(Replace(Replace(IsNull([SSRSDetails],''''),char(10),''''),'','',Char(130)),char(13),'''') as [SSRSDetails], Replace(Replace(Replace(IsNull([DriveDetails],''''),char(10),''''),'','',Char(130)),char(13),'''') as [DriveDetails], Replace(Replace(Replace(IsNull([RAM],''''),char(10),''''),'','',Char(130)),char(13),'''') as [RAM],Replace(Replace(Replace(IsNull([Processor],''''),char(10),''''),'','',Char(130)),char(13),'''') as [Processor], Replace(Replace(Replace(IsNull([DataFiles],''''),char(10),''''),'','',Char(130)),char(13),'''') as [DataFiles], Replace(Replace(Replace(IsNull([LogFiles],''''),char(10),''''),'','',Char(130)),char(13),'''') as [LogFiles], Replace(Replace(Replace(IsNull([FULLbackups],''''),char(10),''''),'','',Char(130)),char(13),'''') as [FULLbackups], Replace(Replace(Replace(IsNull([DIFFbackups],''''),char(10),''''),'','',Char(130)),char(13),'''') as [DIFFbackups],Replace(Replace(Replace(IsNull([TLOGbackups],''''),char(10),''''),'','',Char(130)),char(13),'''') as [TLOGbackups], IsNull([IsServerInUse],1) as IsServerInUse, Replace(Replace(Replace(IsNull([Remarks],''''),char(10),''''),'','',Char(130)),char(13),'''') as [Remarks]  FROM [Catalogue].[SQLServers] WITH(NOLOCK) ORDER BY Environment, SERVERNAME'

	 SET @SQL = 'sqlcmd -S "TWI-SQLPSC01PRD\TEMPURSQLPRD" -E  -d SQL_Admin -q "set nocount on;' + @SQL + '" -I -s","  -o "' + @FileName + '"'
	Execute @SQLError = xp_cmdshell @SQL , no_output
	IF @SQLError <> 1
		 SET @SQLTeamMail_Attachment +=   @FileName
	 -- **************************************************************************************************************************************

	 -- **************************************************************************************************************************************
	 -- Report 2 : Export SQL Activities Approver list
	 -- **************************************************************************************************************************************
	 SET @FileName = @FilePath + 'ApproversForSQLActivities.CSV'

	 --Replace(Replace(Replace(IsNull([BLOCKED_SQL],''''),char(10),''''),'','',Char(130)),char(13),'''') as BLOCKED_SQL
	 SET @SQL = 'SELECT Row_Number() over (order by Activity) as SrNo, Replace(Replace(Replace(IsNull([Activity],''''),char(10),''''),'','',Char(130)),char(13),'''') as [Activity],CASE IsNull([ApprovalRequired],1) When 1 Then ''Yes''  Else ''No'' End as ApprovalRequired,Replace(Replace(Replace(IsNull([Approver],''''),char(10),''''),'','',Char(130)),char(13),'''') as [Approver] FROM [Catalogue].[SQLActivities_Approvers] WITH(NOLOCK) ORDER BY [Activity]'

	 SET @SQL = 'sqlcmd -S "TWI-SQLPSC01PRD\TEMPURSQLPRD" -E  -d SQL_Admin -q "set nocount on;' + @SQL + '" -I -s","  -o "' + @FileName + '"'
	Execute @SQLError = xp_cmdshell @SQL, no_output
	IF @SQLError <> 1
		 SET @SQLTeamMail_Attachment +=   @FileName
	 -- **************************************************************************************************************************************

	 -- **************************************************************************************************************************************
	 -- Report 3 : Export Application's Approver list
	 -- **************************************************************************************************************************************
	 SET @FileName = @FilePath + 'ApproversForEachApplications.CSV'

	 --Replace(Replace(Replace(IsNull([BLOCKED_SQL],''''),char(10),''''),'','',Char(130)),char(13),'''') as BLOCKED_SQL
	 SET @SQL = 'SELECT Row_Number() over (order by Category, Application) as SrNo, IsNull([Category],'''') as [Category], Row_Number() over (PARTITION by Category ORDER BY Application) as Ref_No, Replace(Replace(Replace(IsNull([Application],''''),char(10),''''),'','',Char(130)),char(13),'''') as [Application],Replace(Replace(Replace(IsNull([ProjectManager],''''),char(10),''''),'','',Char(130)),char(13),'''') as [ProjectManager],Replace(Replace(Replace(IsNull([ProjectLeads],''''),char(10),''''),'','',Char(130)),char(13),'''') as [ProjectLeads],Replace(Replace(Replace(IsNull([SupportTeamLeads],''''),char(10),''''),'','',Char(130)),char(13),'''') as [SupportTeamLeads] FROM [Catalogue].[SQLApplications_Approvers] ORDER BY Category, Application'

	 SET @SQL = 'sqlcmd -S "TWI-SQLPSC01PRD\TEMPURSQLPRD" -E  -d SQL_Admin -q "set nocount on;' + @SQL + '" -I -s","  -o "' + @FileName + '"'
	Execute @SQLError = xp_cmdshell @SQL , no_output
	IF @SQLError <> 1
		 SET @SQLTeamMail_Attachment +=   @FileName
	 -- **************************************************************************************************************************************

	 
	 -- **************************************************************************************************************************************
	 -- Report 4 : Export Server OS info
	 -- **************************************************************************************************************************************
	 SET @FileName = @FilePath + 'ServerOSInfo.CSV'

	 --Replace(Replace(Replace(IsNull(OSName,''''),char(10),''''),'','',Char(130)),char(13),'''') as OSName
	 SET @SQL = 'SELECT Row_Number() over (order by Server_Name) as SrNo , Server_Name,Replace(Replace(Replace(IsNull(OSName,''''),char(10),''''),'','',Char(130)),char(13),'''') as OSName,OSVersion,OSLanguage,OSProductSuite,OSType,ServicePackMajorVersion,ServicePackMinorVersion  FROM [Sql_Admin].[Catalogue].[OS_Info]'

	 SET @SQL = 'sqlcmd -S "TWI-SQLPSC01PRD\TEMPURSQLPRD" -E  -d SQL_Admin -q "set nocount on;' + @SQL + '" -I -s","  -o "' + @FileName + '"'
	Execute @SQLError = xp_cmdshell @SQL , no_output
	IF @SQLError <> 1
		 SET @SQLTeamMail_Attachment +=   @FileName
	 -- **************************************************************************************************************************************
	 
	 -- **************************************************************************************************************************************
	 -- Report 5 : Export Server System info
	 -- **************************************************************************************************************************************
	 SET @FileName = @FilePath + 'ServerSystemInfo.CSV'

	 --Replace(Replace(Replace(IsNull([BLOCKED_SQL],''''),char(10),''''),'','',Char(130)),char(13),'''') as BLOCKED_SQL
	 SET @SQL = 'SELECT Row_Number() over (order by Server_Name) as SrNo ,Server_Name,Model      ,Manufacturer      ,Description      ,DNSHostName      ,Domain    ,DomainRole    ,PartOfDomain     ,NumberOfProcessors     ,NumberOfCores     ,SystemType     ,TotalPhysicalMemory      ,UserName  ,Workgroup FROM Sql_Admin.Catalogue.System_Info'

	 SET @SQL = 'sqlcmd -S "TWI-SQLPSC01PRD\TEMPURSQLPRD" -E  -d SQL_Admin -q "set nocount on;' + @SQL + '" -I -s","  -o "' + @FileName + '"'
	Execute @SQLError = xp_cmdshell @SQL , no_output
	IF @SQLError <> 1
		 SET @SQLTeamMail_Attachment +=   @FileName
	 -- **************************************************************************************************************************************


	-- **************************************************************************************************************************************
	-- Sends  email SQL Team 
	-- **************************************************************************************************************************************
	DECLARE @SubjectForSQLTeam varchar(1000)= 'PFA - Updated Software Catalogue and Approver''s List'
	DECLARE @RECIPIENTSForsqlTeam VARCHAR(2000) 
	SELECT Top 1 @RECIPIENTSForsqlTeam =  [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='EmailRecipient'

 	DECLARE @EmailTextForSQLTeam VARCHAR(MAX) = '<HTML><BODY><BR><BR>PFA - the updated Software Catalogue, Approvers List for SQL actvities and supported applications<br><br><br></BODY></HTML>'

	Execute @SQLError = xp_cmdshell 'F:\SoftwareCatalogueReportingDONOTDELETE\ScriptForZip\ZipSQLReports.bat', no_output
	IF @SQLError <> 1
	BEGIN
		WAITFOR DELAY '00:00:05'
		EXECUTE msdb..sp_send_dbmail @Profile_Name = 'DBMaintenance', 
		@RECIPIENTS = @RECIPIENTSForSQLTeam ,  @Subject = @SubjectForSQLTeam, @Body_Format= 'HTML', 	
		@Body =	@EmailTextForSQLTeam ,@file_attachments = 'F:\SoftwareCatalogueReportingDONOTDELETE\SQLReport.zip' 
	END

END

GO

CREATE PROCEDURE [dbo].[Useful_Queries_ToBeUsedWith_Dedicated_Admin_connection]
	
AS
BEGIN
	
	SET NOCOUNT ON;
	PRINT 'DAC Queries are commented in this procedures...please use them as per situation!!'

	/*
		--useful DAC queries

/*
ADDITIONAL INFORMATION:
Dedicated administrator connections are not supported via SSMS as it establishes multiple connections by design. 

SQLCMD -S servername -d master -E/ -U user -P password -i inputFile -A
SQLCMD -S servername -d master -E/ -U user -P password -i inputFile -A
*/

--// system info
select * FROM 
sys.dm_os_sys_info
--// system info

--// list of databases with CPU utilization for each
WITH DB_CPU_Stats
AS
(SELECT DatabaseID, DB_Name(DatabaseID) AS [DatabaseName], SUM(total_worker_time) AS [CPU_Time_Ms]
 FROM sys.dm_exec_query_stats AS qs
 CROSS APPLY (SELECT CONVERT(int, value) AS [DatabaseID] 
              FROM sys.dm_exec_plan_attributes(qs.plan_handle)
              WHERE attribute = N'dbid') AS F_DB
 GROUP BY DatabaseID)

SELECT ROW_NUMBER() OVER(ORDER BY [CPU_Time_Ms] DESC) AS [row_num],
       DatabaseName, [CPU_Time_Ms], 
       CAST([CPU_Time_Ms] * 1.0 / SUM([CPU_Time_Ms]) OVER() * 100.0 AS DECIMAL(5, 2)) AS [CPUPercent]
FROM DB_CPU_Stats
--// list of databases with CPU utilization for each

--// Clear Cache and buffer//-
DBCC FREEPROCCACHE 

DBCC FREESYSTEMCACHE ('ALL')


--Use this command to remove all the data from SQL Server’s data cache (buffer) between performance tests to ensure fair testing.
-- Keep in mind that this command only removes clean buffers, not dirty buffers. 
-- Because of this, before running the DBCC DROPCLEANBUFFERS command, you may first want to run the CHECKPOINT command first. Running CHECKPOINT will write all dirty buffers to disk. 
-- And then when you run DBCC DROPCLEANBUFFERS, you can be assured that all data buffers are cleaned out, not just the clean ones.

DBCC DROPCLEANBUFFERS


--Used to clear out the stored procedure cache for a specific database on a SQL Server, not the entire SQL Server. 
--The database ID number to be affected must be entered as part of the command.

DECLARE @intDBID INTEGER 
SET @intDBID = (SELECT dbid FROM master.dbo.sysdatabases WHERE name = '?') 
DBCC FLUSHPROCINDB (@intDBID)

--// Clear cache and buffer //--

--// Query to find catche size with database Name:

SELECT DB_NAME(database_id) AS [Database Name],
CAST(COUNT(*) * 8/1024.0 AS DECIMAL (10,2))  AS [Cached Size (MB)]
FROM sys.dm_os_buffer_descriptors WITH (NOLOCK)
WHERE database_id > 4 -- system databases
AND database_id <> 32767 -- ResourceDB
GROUP BY DB_NAME(database_id)
ORDER BY [Cached Size (MB)] DESC 

--// Query to find catche size with database Name:

--// Query to find pageiolatch info 
select *
from sys.dm_os_wait_stats  
where wait_type like 'PAGEIOLATCH%'
order by wait_type asc
--// Query to find pageiolatch info 


--// Pending I/O requests can be found by querying the following DMVs and can be used to identify which disk is responsible for the bottleneck.
select database_id, 
       file_id, 
       io_stall,
       io_pending_ms_ticks,
       scheduler_address 
from sys.dm_io_virtual_file_stats(NULL, NULL) iovfs,
     sys.dm_io_pending_io_requests as iopior
where iovfs.file_handle = iopior.io_handle
--// Pending I/O requests can be found by querying the following DMVs and can be used to identify which disk is responsible for the bottleneck.

--// returns current SQL query and sessions (like sp_who2)
SELECT t.text,*
FROM sys.dm_exec_requests r
cross apply sys.dm_exec_sql_text(r.sql_handle) t
WHERE session_id = ?

select * from sys.dm_exec_sessions

--long running transactins
select * from sys.dm_tran_database_transactions

--to view the last statement sent by the client connection to SQL Server
DBCC INPUTBUFFER(sessionid)

--// returns current SQL query and sessions (like sp_who2)

--// Kill all blocking sessions
Create Table #temp1 (spid int, status varchar(100), login varchar(100), hostname varchar(100), blkby varchar(100), DBName  varchar(100), Command  varchar(100), CPUTime  varchar(100), DiskIO  varchar(100), LastBatch  varchar(100), ProgramName  varchar(100), SPID1 varchar(100), RequestID  varchar(100))
insert into #temp1
Exec sp_who2
Select 'kill '+blkby,* from #temp1 where blkby <>'  .'
Drop Table #temp1
--// Kill all blocking sessions

--// if you are using SQLCMD then use input file method //--
--// What's in memory ... use result to text option //--

-- We don't need the row count 
 SET NOCOUNT ON 
 
 -- Get size of SQL Server Page in bytes 
 DECLARE @pg_size INT, @Instancename varchar(50) 
 SELECT @pg_size = low from master..spt_values where number = 1 and type = 'E' 
 
 -- Extract perfmon counters to a temporary table 
 IF OBJECT_ID('tempdb..#perfmon_counters') is not null DROP TABLE #perfmon_counters 
 SELECT * INTO #perfmon_counters FROM sys.dm_os_performance_counters 
 
 -- Get SQL Server instance name 
 SELECT @Instancename = LEFT([object_name], (CHARINDEX(':',[object_name]))) FROM #perfmon_counters WHERE counter_name = 'Buffer cache hit ratio' 
 
 -- Print Memory usage details 
 PRINT '----------------------------------------------------------------------------------------------------' 
 PRINT 'Memory usage details for SQL Server instance ' + @@SERVERNAME + ' (' + CAST(SERVERPROPERTY('productversion') AS VARCHAR) + ' - ' + SUBSTRING(@@VERSION, CHARINDEX('X',@@VERSION),4) + ' - ' + CAST(SERVERPROPERTY('edition') AS VARCHAR) + ')' 
 PRINT '----------------------------------------------------------------------------------------------------' 
 print 'Memory visible to the Operating System' 
 --SELECT CEILING(physical_memory_in_bytes/1048576.0) as [Physical Memory_MB], CEILING(physical_memory_in_bytes/1073741824.0) as [Physical Memory_GB], CEILING(virtual_memory_in_bytes/1073741824.0) as [Virtual Memory GB] FROM sys.dm_os_sys_info 
 print 'Buffer Pool Usage at the Moment' 
 --SELECT (bpool_committed*8)/1024.0 as BPool_Committed_MB, (bpool_commit_target*8)/1024.0 as BPool_Commit_Tgt_MB,(bpool_visible*8)/1024.0 as BPool_Visible_MB FROM sys.dm_os_sys_info 
 print 'Total Memory used by SQL Server Buffer Pool as reported by Perfmon counters' 
 SELECT cntr_value as Mem_KB, cntr_value/1024.0 as Mem_MB, (cntr_value/1048576.0) as Mem_GB FROM #perfmon_counters WHERE counter_name = 'Total Server Memory (KB)' 
 print 'Memory needed as per current Workload for SQL Server instance' 
 SELECT cntr_value as Mem_KB, cntr_value/1024.0 as Mem_MB, (cntr_value/1048576.0) as Mem_GB FROM #perfmon_counters WHERE counter_name = 'Target Server Memory (KB)' 
 print 'Total amount of dynamic memory the server is using for maintaining connections' 
 SELECT cntr_value as Mem_KB, cntr_value/1024.0 as Mem_MB, (cntr_value/1048576.0) as Mem_GB FROM #perfmon_counters WHERE counter_name = 'Connection Memory (KB)' 
 print 'Total amount of dynamic memory the server is using for locks' 
 SELECT cntr_value as Mem_KB, cntr_value/1024.0 as Mem_MB, (cntr_value/1048576.0) as Mem_GB FROM #perfmon_counters WHERE counter_name = 'Lock Memory (KB)' 
 print 'Total amount of dynamic memory the server is using for the dynamic SQL cache' 
 SELECT cntr_value as Mem_KB, cntr_value/1024.0 as Mem_MB, (cntr_value/1048576.0) as Mem_GB FROM #perfmon_counters WHERE counter_name = 'SQL Cache Memory (KB)' 
 print 'Total amount of dynamic memory the server is using for query optimization' 
 SELECT cntr_value as Mem_KB, cntr_value/1024.0 as Mem_MB, (cntr_value/1048576.0) as Mem_GB FROM #perfmon_counters WHERE counter_name = 'Optimizer Memory (KB) ' 
 print 'Total amount of dynamic memory used for hash, sort and create index operations.' 
 SELECT cntr_value as Mem_KB, cntr_value/1024.0 as Mem_MB, (cntr_value/1048576.0) as Mem_GB FROM #perfmon_counters WHERE counter_name = 'Granted Workspace Memory (KB) ' 
 print 'Total Amount of memory consumed by cursors' 
 SELECT cntr_value as Mem_KB, cntr_value/1024.0 as Mem_MB, (cntr_value/1048576.0) as Mem_GB FROM #perfmon_counters WHERE counter_name = 'Cursor memory usage' and instance_name = '_Total' 
 print 'Number of pages in the buffer pool (includes database, free, and stolen).' 
 SELECT cntr_value as [8KB_Pages], (cntr_value*@pg_size)/1024.0 as Pages_in_KB, (cntr_value*@pg_size)/1048576.0 as Pages_in_MB FROM #perfmon_counters WHERE object_name= @Instancename+'Buffer Manager' and counter_name = 'Total pages' 
 print 'Number of Data pages in the buffer pool' 
 SELECT cntr_value as [8KB_Pages], (cntr_value*@pg_size)/1024.0 as Pages_in_KB, (cntr_value*@pg_size)/1048576.0 as Pages_in_MB FROM #perfmon_counters WHERE object_name=@Instancename+'Buffer Manager' and counter_name = 'Database pages' 
 print 'Number of Free pages in the buffer pool' 
 SELECT cntr_value as [8KB_Pages], (cntr_value*@pg_size)/1024.0 as Pages_in_KB, (cntr_value*@pg_size)/1048576.0 as Pages_in_MB FROM #perfmon_counters WHERE object_name=@Instancename+'Buffer Manager' and counter_name = 'Free pages' 
 print 'Number of Reserved pages in the buffer pool' 
 SELECT cntr_value as [8KB_Pages], (cntr_value*@pg_size)/1024.0 as Pages_in_KB, (cntr_value*@pg_size)/1048576.0 as Pages_in_MB FROM #perfmon_counters WHERE object_name=@Instancename+'Buffer Manager' and counter_name = 'Reserved pages' 
 print 'Number of Stolen pages in the buffer pool' 
 SELECT cntr_value as [8KB_Pages], (cntr_value*@pg_size)/1024.0 as Pages_in_KB, (cntr_value*@pg_size)/1048576.0 as Pages_in_MB FROM #perfmon_counters WHERE object_name=@Instancename+'Buffer Manager' and counter_name = 'Stolen pages' 
 print 'Number of Plan Cache pages in the buffer pool' 
 SELECT cntr_value as [8KB_Pages], (cntr_value*@pg_size)/1024.0 as Pages_in_KB, (cntr_value*@pg_size)/1048576.0 as Pages_in_MB FROM #perfmon_counters WHERE object_name=@Instancename+'Plan Cache' and counter_name = 'Cache Pages' and instance_name = '_Total' 
 print 'Page Life Expectancy - Number of seconds a page will stay in the buffer pool without references' 
 SELECT cntr_value as [Page Life in seconds],CASE WHEN (cntr_value > 300) THEN 'PLE is Healthy' ELSE 'PLE is not Healthy' END as 'PLE Status' FROM #perfmon_counters WHERE object_name=@Instancename+'Buffer Manager' and counter_name = 'Page life expectancy' 
 print 'Number of requests per second that had to wait for a free page' 
 SELECT cntr_value as [Free list stalls/sec] FROM #perfmon_counters WHERE object_name=@Instancename+'Buffer Manager' and counter_name = 'Free list stalls/sec' 
 print 'Number of pages flushed to disk/sec by a checkpoint or other operation that require all dirty pages to be flushed' 
 SELECT cntr_value as [Checkpoint pages/sec] FROM #perfmon_counters WHERE object_name=@Instancename+'Buffer Manager' and counter_name = 'Checkpoint pages/sec' 
 print 'Number of buffers written per second by the buffer manager"s lazy writer' 
 SELECT cntr_value as [Lazy writes/sec] FROM #perfmon_counters WHERE object_name=@Instancename+'Buffer Manager' and counter_name = 'Lazy writes/sec' 
 print 'Total number of processes waiting for a workspace memory grant' 
 SELECT cntr_value as [Memory Grants Pending] FROM #perfmon_counters WHERE object_name=@Instancename+'Memory Manager' and counter_name = 'Memory Grants Pending' 
 print 'Total number of processes that have successfully acquired a workspace memory grant' 
 SELECT cntr_value as [Memory Grants Outstanding] FROM #perfmon_counters WHERE object_name=@Instancename+'Memory Manager' and counter_name = 'Memory Grants Outstanding'

--// if you are using SQLCMD then use input file method //--
--// What's in memory ... use result to text option //--


	*/
    
END

GO




go

USE [SQL_Admin]
GO

CREATE Procedure [dbo].[proc_LatencyCheckReport] 
-- With Encryption
as
BEGIN

PRINT 'This is stored procedure for checking latency between Prod and DR servers.Uncomment code to use the same'
--Create TABLE #LatencyCheckReport (ServerName Varchar(1000), DatabaseName varchar(1000), LastUpdatedOn DateTime, ApplicationName varchar(100))


----**********************************************
---- DR server for PNP MAIN Scribe TO DR SERVER SYNCH 
--Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TPATT-SCRIBE1\SQLSCRIBE2012;UID=SA;PWD=Th1s1sSApassword;',
--  'SELECT ''TPATT-SCRIBE1\SQLSCRIBE2012 => TRI-SCRIBE1-UAT\SQLScribe2012'' + char(10) + ''(SQL Job)'',''ScribeInternal_PNP'', Value, ''PNP Main Scribe Server Synch with DR'' From SQL_Admin.SQLMANTAINENCE.DBMANTAINENCECONFIGURATION  WITH(NOLOCK)  WHERE CONFIGURATIONTYPE = ''SCRIBERECORDMOVEMENT_TO_LINKSERVER2'' '
--); 


---- DR server for PNP BACKUP Scribe TO DR SERVER SYNCH 
--Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TPATT-SCRIBE1B\SQLSCRIBE2012;UID=SA;PWD=Th1s1sSApassword;',
--  'SELECT ''TPATT-SCRIBE1B\SQLSCRIBE2012 => TRI-SCRIBE1-UAT\SQLScribe2012'' + char(10) + ''(SQL Job)'',''ScribeInternal_PNP'', Value, ''PNP Backup Scribe Server Synch with DR'' From SQL_Admin.SQLMANTAINENCE.DBMANTAINENCECONFIGURATION  WITH(NOLOCK)  WHERE CONFIGURATIONTYPE = ''SCRIBERECORDMOVEMENT_TO_LINKSERVER2'' '
--); 

---- ****************************************************
---- DR server for TPI MAIN Scribe TO DR SERVER SYNCH 
--Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TPATT-SCRIBE2\SQLSCRIBE2012;UID=SA;PWD=Th1s1sSApassword;',
--  'SELECT ''TPATT-SCRIBE2\SQLSCRIBE2012 => TRI-SCRIBE2-UAT\SQLScribe2012'' + char(10) + ''(SQL Job)'',''ScribeInternal_TPI'', Value, ''TPI Main Scribe Server Synch with DR'' From SQL_Admin.SQLMANTAINENCE.DBMANTAINENCECONFIGURATION  WITH(NOLOCK)  WHERE CONFIGURATIONTYPE = ''SCRIBERECORDMOVEMENT_TO_LINKSERVER2'' '
--); 

---- DR server for TPI BACKUP Scribe TO DR SERVER SYNCH 
--Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TPATT-SCRIBE2B\SQLSCRIBE2012;UID=SA;PWD=Th1s1sSApassword;',
--  'SELECT ''TPATT-SCRIBE2B\SQLSCRIBE2012 => TRI-SCRIBE2-UAT\SQLScribe2012'' + char(10) + ''(SQL Job)'',''ScribeInternal_TPI'', Value, ''TPI Backup Scribe Server Synch with DR'' From SQL_Admin.SQLMANTAINENCE.DBMANTAINENCECONFIGURATION  WITH(NOLOCK)  WHERE CONFIGURATIONTYPE = ''SCRIBERECORDMOVEMENT_TO_LINKSERVER2'' '
--); 



---- DR server for TPI ABQ TO DR SERVER SYNCH 
--Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TRI-SQL2-UAT;UID=SA;PWD=Th1s1sSApassword;',
--  'Select ''TWI-SQLPSC01PRD\TEMPURSQLPRD => TRI-SQL2-UAT'' + char(10) + ''(Always On)'' as ServerName, * From TPI_NM.dbo.DBA_Latency WITH(NOLOCK) '
--); 

---- DR server for EDI DATAMASON TO DR SERVER SYNCH 
--Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TRI-EDI1-UATV;UID=SA;PWD=Th1s1sSApassword;',
--  'Select ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(Log Shipping)'', Secondary_Database, LAST_RESTORED_DATE, ''EDI DataMasons'' FROM MSDB.DBO.LOG_SHIPPING_MONITOR_SECONDARY WITH(NOLOCK) WHERE SECONDARY_DATABASE in (''swWorkFlow'',''vpEDI_DNK_PROD'',''vpEDI_Company'')'
--); 


---- DR server for EDI DataMasons TO DR SERVER SYNCH 
--Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TRI-EDI1-UATV;UID=SA;PWD=Th1s1sSApassword;',
--  'Declare @LastUpdateTime1 DAteTime,@LastUpdateTime2 DAteTime,@LastUpdateTime3 DAteTime
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''swWorkFlow'',  @LastUpdateTime1 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''vpEDI_Company'',  @LastUpdateTime2 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''vpEDI_DNK_PROD'',  @LastUpdateTime3 OUTPUT

--   ;SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''swWorkFlow'', @LastUpdateTime1, ''EDI DataMasons Server Synch with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''vpEDI_Company'', @LastUpdateTime2, ''EDI DataMasons Server Synch with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''vpEDI_DNK_PROD'', @LastUpdateTime3, ''EDI DataMasons Server Synch with DR'' '
--); 

------ DR server for PNP APPLICATION SYNCH 

--Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TRI-SQL1-UAT;UID=SA;PWD=Th1s1sSApassword;',
--  'Declare   @LastUpdateTime18 DAteTime,@LastUpdateTime17 DAteTime,@LastUpdateTime16 DAteTime,@LastUpdateTime15 DAteTime,@LastUpdateTime1 DAteTime,@LastUpdateTime2 DAteTime,@LastUpdateTime3 DAteTime,@LastUpdateTime4 DAteTime,@LastUpdateTime5 DAteTime,@LastUpdateTime6 DAteTime,@LastUpdateTime7 DAteTime,@LastUpdateTime8 DAteTime,@LastUpdateTime9 DAteTime,@LastUpdateTime10 DAteTime,@LastUpdateTime11 DAteTime,@LastUpdateTime12 DAteTime,@LastUpdateTime13 DAteTime,@LastUpdateTime14 DAteTime
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''EFTDB'',  @LastUpdateTime1 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_Common'',  @LastUpdateTime2 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_EComAxIntegration'',  @LastUpdateTime3 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_EComAxIntegrationLogs'',  @LastUpdateTime4 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_EComAxJapan'',  @LastUpdateTime5 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_EComAxLogsJapan'',  @LastUpdateTime6 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_ECommerce'',  @LastUpdateTime7 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_FSI'',  @LastUpdateTime8 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_MarketingDB'',  @LastUpdateTime9 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_MDM'',  @LastUpdateTime10 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnPEcommerce_Invoicing'',  @LastUpdateTime11 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnPEcommerce_XInvoiceIntegrations'',  @LastUpdateTime12 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnPEcommerceROW'',  @LastUpdateTime13 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnPEcommerceROWLogs'',  @LastUpdateTime14 OUTPUT

--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnPAXPOSIntegration'',  @LastUpdateTime15 OUTPUT
--    ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnPRetailStoreLocator'',  @LastUpdateTime16 OUTPUT
--       ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnPRetailStoreLocatorLogs'',  @LastUpdateTime17 OUTPUT
--         ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TaxCalc'',  @LastUpdateTime18 OUTPUT

--   ;SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''EFTDB'', @LastUpdateTime1, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_Common'', @LastUpdateTime2, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_EComAxIntegration'', @LastUpdateTime3, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_EComAxIntegrationLogs'', @LastUpdateTime4, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_EComAxJapan'', @LastUpdateTime5, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_EComAxLogsJapan'', @LastUpdateTime6, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_ECommerce'', @LastUpdateTime7, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_FSI'', @LastUpdateTime8, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_MarketingDB'', @LastUpdateTime9, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_MDM'', @LastUpdateTime10, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnPEcommerce_Invoicing'', @LastUpdateTime11, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnPEcommerce_XInvoiceIntegrations'', @LastUpdateTime12, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnPEcommerceROW'', @LastUpdateTime13, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnPEcommerceROWLogs'', @LastUpdateTime14, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnPAXPOSIntegration'', @LastUpdateTime15, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnPRetailStoreLocator'', @LastUpdateTime16, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnPRetailStoreLocatorLogs'', @LastUpdateTime17, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''TaxCalc'', @LastUpdateTime18, ''CCH'' '

--); 
--/*Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TRI-SQL1-UAT;UID=SA;PWD=Th1s1sSApassword;',
--  'Declare @LastUpdateTime1 DAteTime,@LastUpdateTime2 DAteTime,@LastUpdateTime3 DAteTime,@LastUpdateTime4 DAteTime,@LastUpdateTime5 DAteTime,@LastUpdateTime6 DAteTime,@LastUpdateTime7 DAteTime,@LastUpdateTime8 DAteTime,@LastUpdateTime9 DAteTime,@LastUpdateTime10 DAteTime,@LastUpdateTime11 DAteTime,@LastUpdateTime12 DAteTime,@LastUpdateTime13 DAteTime,@LastUpdateTime14 DAteTime
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''EFTDB'',  @LastUpdateTime1 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_Common'',  @LastUpdateTime2 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_EComAxIntegration'',  @LastUpdateTime3 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_EComAxIntegrationLogs'',  @LastUpdateTime4 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_EComAxJapan'',  @LastUpdateTime5 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_EComAxLogsJapan'',  @LastUpdateTime6 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_ECommerce'',  @LastUpdateTime7 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_FSI'',  @LastUpdateTime8 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_MarketingDB'',  @LastUpdateTime9 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnP_MDM'',  @LastUpdateTime10 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnPEcommerce_Invoicing'',  @LastUpdateTime11 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnPEcommerce_XInvoiceIntegrations'',  @LastUpdateTime12 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnPEcommerceROW'',  @LastUpdateTime13 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''PnPEcommerceROWLogs'',  @LastUpdateTime14 OUTPUT
--   ;SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''EFTDB'', @LastUpdateTime1, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_Common'', @LastUpdateTime2, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_EComAxIntegration'', @LastUpdateTime3, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_EComAxIntegrationLogs'', @LastUpdateTime4, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_EComAxJapan'', @LastUpdateTime5, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_EComAxLogsJapan'', @LastUpdateTime6, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_ECommerce'', @LastUpdateTime7, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_FSI'', @LastUpdateTime8, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_MarketingDB'', @LastUpdateTime9, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnP_MDM'', @LastUpdateTime10, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnPEcommerce_Invoicing'', @LastUpdateTime11, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnPEcommerce_XInvoiceIntegrations'', @LastUpdateTime12, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnPEcommerceROW'', @LastUpdateTime13, ''PNP & EFTB ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring)'',''PnPEcommerceROWLogs'', @LastUpdateTime14, ''PNP & EFTB ServerSynch with DR'' '

--); 


---- ENABLE...UNCOMMENT BELOW CODE ONCE DATABASE MIRRORING IS ENABLED FOR EDI VSYNC APPLICATIONS
------ DR server for EDI Vsync APPLICATION SYNCH 
--Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TRI-SQL3-UAT\VSUAT;UID=SA;PWD=Th1s1sSApassword;',
--  'Declare @LastUpdateTime1 DAteTime,@LastUpdateTime2 DAteTime,@LastUpdateTime3 DAteTime,@LastUpdateTime4 DAteTime,@LastUpdateTime5 DAteTime,@LastUpdateTime6 DAteTime,@LastUpdateTime7 DAteTime,@LastUpdateTime8 DAteTime,@LastUpdateTime9 DAteTime,@LastUpdateTime10 DAteTime,@LastUpdateTime11 DAteTime,@LastUpdateTime12 DAteTime,@LastUpdateTime13 DAteTime,@LastUpdateTime14 DAteTime,@LastUpdateTime15 DAteTime

--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''A1FCore'',  @LastUpdateTime1 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''BAMArchive'',  @LastUpdateTime2 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''BAMPrimaryImport'',  @LastUpdateTime3 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''BizTalkDTADb'',  @LastUpdateTime4 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''BizTalkMgmtDb'',  @LastUpdateTime5 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''BizTalkMsgBoxDb'',  @LastUpdateTime6 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''BizTalkRuleEngineDb'',  @LastUpdateTime7 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''Nexus'',  @LastUpdateTime8 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''NexusAppServer'',  @LastUpdateTime9 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''NexusCurrentDataStore'',  @LastUpdateTime10 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''ReportServer$CRMPRDTMP'',  @LastUpdateTime11 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''ReportServer$CRMPRDTMPTempDB'',  @LastUpdateTime12 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''SSODB'',  @LastUpdateTime13 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''VSyncAppServer'',  @LastUpdateTime14 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''VSyncMailboxes'',  @LastUpdateTime15 OUTPUT
--   ;SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''A1FCore'', @LastUpdateTime1, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''BAMArchive'', @LastUpdateTime2, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''BAMPrimaryImport'', @LastUpdateTime3, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''BizTalkDTADb'', @LastUpdateTime4, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''BizTalkMgmtDb'', @LastUpdateTime5, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''BizTalkMsgBoxDb'', @LastUpdateTime6, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''BizTalkRuleEngineDb'', @LastUpdateTime7, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''Nexus'', @LastUpdateTime8, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''NexusAppServer'', @LastUpdateTime9, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''NexusCurrentDataStore'', @LastUpdateTime10, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''ReportServer$CRMPRDTMP'', @LastUpdateTime11, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''ReportServer$CRMPRDTMPTempDB'', @LastUpdateTime12, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''SSODB'', @LastUpdateTime13, ''EDI Vsync with DR'' 
--   UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''VSyncAppServer'', @LastUpdateTime14, ''EDI Vsync with DR'' 
--       UNION ALL 
--   SELECT ''PIS-EDI01-PRD-V => TRI-EDI1-UATV'' + char(10) + ''(DB Mirroring)'',''VSyncMailboxes'', @LastUpdateTime15, ''EDI Vsync with DR'' '
--); 

--*/


----DR Server (TRI-SQLAX-UAT) for AXProd
--Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TRI-SQLAX-UAT\AXPROD;UID=SA;PWD=Th1s1sSApassword;',
--  'SELECT ''AX-SQLPSC01-PRD\AXPROD => TRI-SQLAX-UAT\AXPROD'' + char(10) + ''(AlwaysOn)'' as ServerName,* From MDAR2.dbo.DBA_Latency WITH(NOLOCK) UNION 
--   Select ''AX-SQLPSC01-PRD\AXPROD => TRI-SQLAX-UAT\AXPROD'' + char(10) + ''(AlwaysOn)'' as ServerName, * From MDAR2_model.dbo.DBA_Latency WITH(NOLOCK) UNION 
--   Select ''AX-SQLPSC01-PRD\AXPROD => TRI-SQLAX-UAT\AXPROD'' + char(10) + ''(AlwaysOn)'' as ServerName, * From MDABaselineR2.dbo.DBA_Latency WITH(NOLOCK)  UNION
--   Select ''AX-SQLPSC01-PRD\AXPROD => TRI-SQLAX-UAT\AXPROD'' + char(10) + ''(AlwaysOn)'' as ServerName, * From RFSMART.dbo.DBA_Latency WITH(NOLOCK) '
--); 

------ DR Server (AX-SQLMRR01-PRD) for Mirror Server
--Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=AX-SQLMRR01-PRD\AXSQLMRR;UID=SA;PWD=Th1s1sSApassword;',
--  'SELECT ''AX-SQLPSC01-PRD\AXPROD => AX-SQLMRR01-PRD\AXSQLMRR'' + char(10) + ''(AlwaysOn)'' as ServerName,* From MDAR2.dbo.DBA_Latency WITH(NOLOCK) UNION 
--   Select ''AX-SQLPSC01-PRD\AXPROD => AX-SQLMRR01-PRD\AXSQLMRR'' + char(10) + ''(AlwaysOn)'' as ServerName, * From MDAR2_model.dbo.DBA_Latency WITH(NOLOCK) UNION 
--   Select ''AX-SQLPSC01-PRD\AXPROD => AX-SQLMRR01-PRD\AXSQLMRR'' + char(10) + ''(AlwaysOn)'' as ServerName, * From MDABaselineR2.dbo.DBA_Latency WITH(NOLOCK) UNION
--   Select ''AX-SQLPSC01-PRD\AXPROD => AX-SQLMRR01-PRD\AXSQLMRR'' + char(10) + ''(AlwaysOn)'' as ServerName, * From RFSMART.dbo.DBA_Latency WITH(NOLOCK) '
--); 


------ DR Server (TRI-SQLM-UAT) for Trinity Mirror Server
----Insert into #LatencyCheckReport
----Select * FROM OPENROWSET
----(
----  'SQLNCLI', 'Server=TRI-SQLM-UAT;UID=SA;PWD=Th1s1sSApassword;',
----  'SELECT ''AX-SQLPSC01-PRD\AXPROD => TRI-SQLM-UAT'' + char(10) + ''(AlwaysOn)'' as ServerName,* From MDAR2.dbo.DBA_Latency WITH(NOLOCK) UNION 
----   Select ''AX-SQLPSC01-PRD\AXPROD => TRI-SQLM-UAT'' + char(10) + ''(AlwaysOn)'' as ServerName, * From MDAR2_model.dbo.DBA_Latency WITH(NOLOCK) UNION 
----   Select ''AX-SQLPSC01-PRD\AXPROD => TRI-SQLM-UAT'' + char(10) + ''(AlwaysOn)'' as ServerName, * From MDABaselineR2.dbo.DBA_Latency WITH(NOLOCK) UNION
----   Select ''AX-SQLPSC01-PRD\AXPROD => TRI-SQLM-UAT'' + char(10) + ''(AlwaysOn)'' as ServerName, * From RFSMART.dbo.DBA_Latency WITH(NOLOCK) '
----); 


------ DR server for BizTalk APPLICATION SYNCH 
--Insert into #LatencyCheckReport
--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TRI-SQL3-UAT;UID=SA;PWD=Th1s1sSApassword;',
--  'Declare @LastUpdateTime15 DAteTime,@LastUpdateTime1 DAteTime,@LastUpdateTime2 DAteTime,@LastUpdateTime3 DAteTime,@LastUpdateTime4 DAteTime,@LastUpdateTime5 DAteTime,@LastUpdateTime6 DAteTime,@LastUpdateTime7 DAteTime,@LastUpdateTime8 DAteTime
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''BAMArchive'',  @LastUpdateTime1 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''BAMPrimaryImport'',  @LastUpdateTime2 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''BizTalkDTADb'',  @LastUpdateTime3 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''BizTalkMgmtDb'',  @LastUpdateTime4 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''BizTalkMsgBoxDb'',  @LastUpdateTime5 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''BizTalkRuleEngineDb'',  @LastUpdateTime6 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''ReportServer$CRMPRDTMP'',  @LastUpdateTime7 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''SSODB'',  @LastUpdateTime8 OUTPUT
--   ;SELECT ''TWI-SQLPSC01PRD => TRI-SQL3-UAT'' + char(10) + ''(DB Mirroring)'',''BAMArchive'', @LastUpdateTime1, ''BizTalk Synch with DR'' 
--   UNION ALL 
--   SELECT ''TWI-SQLPSC01PRD => TRI-SQL3-UAT'' + char(10) + ''(DB Mirroring)'',''BAMPrimaryImport'', @LastUpdateTime2, ''BizTalk Synch with DR'' 
--   UNION ALL 
--   SELECT ''TWI-SQLPSC01PRD => TRI-SQL3-UAT'' + char(10) + ''(DB Mirroring)'',''BizTalkDTADb'', @LastUpdateTime3, ''BizTalk Synch with DR'' 
--   UNION ALL 
--   SELECT ''TWI-SQLPSC01PRD => TRI-SQL3-UAT'' + char(10) + ''(DB Mirroring)'',''BizTalkMgmtDb'', @LastUpdateTime4, ''BizTalk Synch with DR'' 
--   UNION ALL 
--   SELECT ''TWI-SQLPSC01PRD => TRI-SQL3-UAT'' + char(10) + ''(DB Mirroring)'',''BizTalkMsgBoxDb'', @LastUpdateTime5, ''BizTalk Synch with DR'' 
--   UNION ALL 
--   SELECT ''TWI-SQLPSC01PRD => TRI-SQL3-UAT'' + char(10) + ''(DB Mirroring)'',''BizTalkRuleEngineDb'', @LastUpdateTime6, ''BizTalk Synch with DR'' 
--   UNION ALL 
--   SELECT ''TWI-SQLPSC01PRD => TRI-SQL3-UAT'' + char(10) + ''(DB Mirroring)'',''ReportServer$CRMPRDTMP'', @LastUpdateTime7, ''BizTalk Synch with DR'' 
--   UNION ALL 
--   SELECT ''TWI-SQLPSC01PRD => TRI-SQL3-UAT'' + char(10) + ''(DB Mirroring)'',''SSODB'', @LastUpdateTime8, ''BizTalk Synch with DR'' ')


---- DR server for CRM APPLICATION SYNCH 

--Insert into #LatencyCheckReport

--Select * FROM OPENROWSET
--(
--  'SQLNCLI', 'Server=TRI-SQL1-UAT;UID=SA;PWD=Th1s1sSApassword;',
--  'Declare  @LastUpdateTime23 datetime,@LastUpdateTime22 datetime,@LastUpdateTime21 datetime,@LastUpdateTime20 DAteTime, @LastUpdateTime19 DAteTime,@LastUpdateTime18 DAteTime,@LastUpdateTime17 DAteTime,@LastUpdateTime16 DAteTime,@LastUpdateTime15 DAteTime,@LastUpdateTime1 DAteTime,@LastUpdateTime2 DAteTime,@LastUpdateTime3 DAteTime,@LastUpdateTime4 DAteTime,@LastUpdateTime5 DAteTime,@LastUpdateTime6 DAteTime,@LastUpdateTime7 DAteTime,@LastUpdateTime8 DAteTime,@LastUpdateTime9 DAteTime,@LastUpdateTime10 DAteTime,@LastUpdateTime11 DAteTime,@LastUpdateTime12 DAteTime,@LastUpdateTime13 DAteTime,@LastUpdateTime14 DAteTime

--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPBenelux_MSCRM'',  @LastUpdateTime1 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPCanada_MSCRM'',  @LastUpdateTime2 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPChina_MSCRM'',  @LastUpdateTime3 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPCRM_MSCRM'',  @LastUpdateTime4 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPDenmark_MSCRM'',  @LastUpdateTime5 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPFinland_MSCRM'',  @LastUpdateTime6 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPFrance_MSCRM'',  @LastUpdateTime7 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPGermany_MSCRM'',  @LastUpdateTime8 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPItaly_MSCRM'',  @LastUpdateTime9 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPJapan_MSCRM'',  @LastUpdateTime10 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPNewzealand_MSCRM'',  @LastUpdateTime11 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPNorway_MSCRM'',  @LastUpdateTime12 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPPoland_MSCRM'',  @LastUpdateTime13 OUTPUT
--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPSingapore_MSCRM'',  @LastUpdateTime14 OUTPUT

--   ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPSouthKorea_MSCRM'',  @LastUpdateTime15 OUTPUT
--    ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPSpain_MSCRM'',  @LastUpdateTime16 OUTPUT
--       ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPSweden_MSCRM'',  @LastUpdateTime17 OUTPUT
--         ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPSwitzerland_MSCRM'',  @LastUpdateTime18 OUTPUT
--          ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPUK_MSCRM'',  @LastUpdateTime19 OUTPUT
--          ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TSUSA_MSCRM'',  @LastUpdateTime20 OUTPUT
--          ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPAustralia_MSCRM'',  @LastUpdateTime21 OUTPUT
--          ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''CRM_Lead_Generator'',  @LastUpdateTime22 OUTPUT
--          ;Execute  sql_admin.dbo.CheckLatencyForMirroredDatabaseOnThisServer ''TPAustria_MSCRM'',  @LastUpdateTime23 OUTPUT

--   ;SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPBenelux_MSCRM'', @LastUpdateTime1, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPCanada_MSCRM'', @LastUpdateTime2, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPChina_MSCRM'', @LastUpdateTime3, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPCRM_MSCRM'', @LastUpdateTime4, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPDenmark_MSCRM'', @LastUpdateTime5, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPFinland_MSCRM'', @LastUpdateTime6, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPFrance_MSCRM'', @LastUpdateTime7, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPGermany_MSCRM'', @LastUpdateTime8, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPItaly_MSCRM'', @LastUpdateTime9, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPJapan_MSCRM'', @LastUpdateTime10, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPNewzealand_MSCRM'', @LastUpdateTime11, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPNorway_MSCRM'', @LastUpdateTime12, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPPoland_MSCRM'', @LastUpdateTime13, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPSingapore_MSCRM'', @LastUpdateTime14, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPSouthKorea_MSCRM'', @LastUpdateTime15, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPSpain_MSCRM'', @LastUpdateTime16, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPSweden_MSCRM'', @LastUpdateTime17, ''CRM ServerSynch with DR'' 
--   UNION ALL 
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPSwitzerland_MSCRM'', @LastUpdateTime18, ''CRM ServerSynch with DR'' 
--      UNION ALL
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPUK_MSCRM'', @LastUpdateTime19, ''CRM ServerSynch with DR''
--   UNION ALL

--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TSUSA_MSCRM'', @LastUpdateTime20, ''CRM ServerSynch with DR''
--   UNION ALL
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPAustralia_MSCRM'', @LastUpdateTime21, ''CRM ServerSynch with DR''
--   UNION ALL
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''CRM_Lead_Generator'', @LastUpdateTime22, ''CRM ServerSynch with DR''
--   UNION ALL
--   SELECT ''17580SQLVS1\CRMSQLPRD => TRI-SQL1-UAT'' + char(10) + ''(DB Mirroring_ForCRM)'',''TPAustria_MSCRM'', @LastUpdateTime23, ''CRM ServerSynch with DR''
   
--   ')

--SELECT * FROM #LatencyCheckReport WITH(NOLOCK)
--DROP TABLE #LatencyCheckReport
END 

GO


USE [SQL_ADMIN]
GO


-- http://msdn.microsoft.com/en-IN/library/ms176064.aspx 
-- Any repair option with checkdb needs the database to be in single user mode
-- TABLOCK will cause DBCC CHECKDB to run faster on a database under heavy load, but decreases the concurrency available on the database while DBCC CHECKDB is running.
-- TABLOCK limits the checks that are performed; DBCC CHECKCATALOG is not run on the database, and Service Broker data is not validated.
-- PHYSICAL_ONLY  Limits the checking to the integrity of the physical structure of the page and record headers and the allocation consistency of the database. 
CREATE PROCEDURE [SQLMantainence].[ExecuteCheckDBForAllDatabases]
AS 
BEGIN

SET NOCOUNT ON
	DECLARE  @dbName varchar(1000) 
    DECLARE  @PHYSICAL_ONLY bit = 1
    DECLARE   @allMessages bit = 0
	DECLARE @ACTUAL_IP_ADDRESS VARCHAR(1000) 
	DECLARE @SQL varchar(4000)
	DECLARE @ENVIRONMENT VARCHAR(50)

	SELECT @Environment	=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Environment'
	SELECT @Environment = ISNULL(@Environment, 'Prod')
	SELECT @Environment = CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END

	DECLARE @Subject varchar(1000) = @Environment + ' - Results from DBCC CheckDB execution on server ' + @@SERVERNAME + ' IP : ' +@ACTUAL_IP_ADDRESS       
	DECLARE @LogDate DateTime = Cast(CONVERT(datetime,getdate(),10) as varchar(17))
	
		-- This is temporary table created in tempDB database for storing results from every RUN.
     IF OBJECT_ID('TempDB.DBO.DBCC_OUTPUT') IS  NULL
	 BEGIN
	   IF CharIndex('Microsoft SQL Server 2012',@@VERSION,1) > 0 OR CharIndex('Microsoft SQL Server 2014',@@VERSION,1) > 0	  	 
		   CREATE TABLE TempDB.DBO.DBCC_OUTPUT ([Error] int,[Level] int,[State] int    ,[MessageText] varchar(7000),[RepairLevel] int	,[Status] int
							     ,[DbId] int,[DbFragId] int,[ObjectID] int,[IndexId] int,[PartitionId] int   ,[AllocUnitId] int	,[RidDbId] int
							     ,[RidPruId] int,[File] int,[Page] int,[Slot] int,[RefDbID] int,[RefPruId] int,[RefFile] int,[RefPage] int,[RefSlot] int
								 ,[Allocation] int)		
		ELSE   -- 2008 R2 OR PRIOR VERSION
			CREATE TABLE TempDB.DBO.DBCC_OUTPUT(Error int NOT NULL,[Level] int NOT NULL,State int NOT NULL, MessageText nvarchar(256) NOT NULL,
			        RepairLevel varchar(255) NULL, Status int NOT NULL, DbId int NOT NULL, ObjectId int NOT NULL, IndexId int NOT NULL,
			        PartitionId bigint NOT NULL, AllocUnitId bigint NOT NULL, [File] int NOT NULL,Page int NOT NULL,Slot int NOT NULL,
			        RefFile int NOT NULL,RefPage int NOT NULL, RefSlot int NOT NULL, Allocation int NOT NULL)
     END       
       
		CREATE TABLE #TEMP1(SQL_IP VARCHAR(3000))
		INSERT INTO #TEMP1 EXECUTE XP_CMDSHELL 'IPCONFIG' 
		DECLARE @IPADDRESS VARCHAR(300) 
		SET @IPADDRESS = (SELECT TOP 1 SQL_IP FROM #TEMP1  WITH(NOLOCK)  WHERE SQL_IP LIKE '%IPV4%' ORDER BY SQL_IP DESC) 
		If @IPAddress IS NULL
		   SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IP Address%' ORDER BY SQL_IP DESC) 	
	
		SET @IPAddress = IsNull(@IPAddress,'')
		 
		DECLARE @LEN INT 
		SET @LEN = CHARINDEX(':', @IPADDRESS) 
		SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPADDRESS, @LEN+1, LEN(@IPADDRESS)))) 
		DROP TABLE #TEMP1 
	            
        DECLARE c_databases CURSOR LOCAL FAST_FORWARD
        FOR
		  SELECT NAME FROM SYS.DATABASES  WITH(NOLOCK) 
		  WHERE STATE_DESC='ONLINE' AND NAME NOT LIKE '%_TOBEDELETED%' AND SOURCE_DATABASE_ID IS NULL AND  NAME NOT IN('TEMPDB') AND
				NAME NOT IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM [SQLMANTAINENCE].[DBMANTAINENCECONFIGURATION]  WITH(NOLOCK) 
				WHERE CONFIGURATIONTYPE = 'EXCLUDEDATABASE') 

        OPEN c_databases
        
        FETCH NEXT FROM c_databases INTO @dbName
        WHILE @@FETCH_STATUS = 0
        BEGIN      
		        TRUNCATE TABLE TempDB.DBO.DBCC_OUTPUT
				          
                SET @SQL = 'DBCC CHECKDB('+ @dbName +') WITH TABLERESULTS, ALL_ERRORMSGS'                
                IF @PHYSICAL_ONLY = 1 
                        SET @SQL = @SQL + ', PHYSICAL_ONLY '

                INSERT INTO TempDB.DBO.DBCC_OUTPUT
                EXEC(@SQL)

				SET @SQL = 
				
				'INSERT INTO SQL_ADMIN.SQLMantainence.DBMantainenceLOG
				(LogDate,Type, LogDetails, Status)
				SELECT ''' + Cast(Convert(DateTime, @LogDate,113) as varchar(100)) + ''', ''DBCC-CHECK-RESULTS'',MessageText,CASE WHEN MessageText LIKE ''%0 allocation errors and 0 consistency errors%'' THEN ''I'' ELSE ''C'' END             
                FROM TempDB.DBO.DBCC_OUTPUT 
				WHERE Error = 8989
				' 
				
				EXEC(@SQL)


				SET @SQL = 
				
				'
				INSERT INTO [SQL_ADMIN].[SQLMantainence].[DBMantainenceLOG_National] 
				([LogDate], [TYPE], [LogDetails], [Status], [Server])
				SELECT GETDATE(), ''CHECKDB-STATUS'', MessageText, CASE WHEN MessageText LIKE ''%0 allocation errors and 0 consistency errors%'' THEN ''I'' ELSE ''C'' END,@@SERVERNAME
				FROM TempDB.DBO.DBCC_OUTPUT 
				WHERE Error = 8989
				'
				
				EXEC(@SQL)



                FETCH NEXT FROM c_databases INTO @dbName
        END  -- END OF CURSOR LOOP        
        CLOSE c_databases
        DEALLOCATE c_databases
      
		          
		IF EXISTS(Select Top 1 1 From SQL_ADMIN.SQLMantainence.DBMantainenceLOG WITH(NOLOCK) 
		          Where Type = 'DBCC-CHECK-RESULTS' AND LogDate = Cast(CONVERT(datetime,@LogDate,10) as varchar(17)) AND Status = 'C') 
		BEGIN
			SELECT @SQL = 'SET NOCOUNT ON;SELECT LogDate,LogDetails
						FROM  SQL_ADMIN.SQLMantainence.DBMantainenceLOG  WITH(NOLOCK)
						WHERE Type = ''DBCC-CHECK-RESULTS'' AND LogDate = ''' + Cast(CONVERT(datetime,@LogDate,10) as varchar(17)) + ''' AND Status = ''C'''

		    DECLARE @MailRecipients varchar(2000)
	   		SELECT Top 1 @MailRecipients =  [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='EmailRecipient'

		    EXECUTE MSDB..SP_Send_DBmail 
				@Profile_Name = 'DBMAINTENANCE', 
				@Recipients = @MailRecipients ,    
				@Subject = @Subject,
				@Query = @SQL,
				@Attach_Query_Result_As_File = 1,
				@Execute_Query_Database = 'SQL_admin'
      END


END

GO


CREATE PROCEDURE [SQLMantainence].[PROC_DELETEOLD_AzureTLogBACKUPS] 
@DBNAME VARCHAR(1000) = '',
@TLOGBackupFolder  VARCHAR(1000) = '',
@RetentionPeriodForTLOGBackupsInDays INT = 8
-- With Encryption
AS
BEGIN
SET NOCOUNT ON
	--SET @TLOGBackupFolder_Azure = 'TLog backups'--temp
	--SET @DBNAME  = 'SQL_Admin'--temp
	--SET @DIFF_BACKUPFOLDER_Azure = 'Diff backups' -- temp
	DECLARE  @PowershellOutput TABLE (output varchar(max))
	DECLARE @CleanedOutput TABLE (backup_filename varchar(max), Backup_Date datetime)
	DECLARE @CleanupCandidates TABLE ( RowNo int,backup_filename varchar(max), Backup_Date datetime)
	DECLARE @PSAzureCmd VARCHAR(5000)  
	DECLARE @AzureBackupContainer VARCHAR(100)
	DECLARE @BackupFileToBeDeleted VARCHAR(500)
	DECLARE @TLog_BackupLocation VARCHAR(100)
	Declare @i int, -- Iterator
			@j int -- Increment

	SELECT @AzureBackupContainer = LTRIM(RTRIM(REVERSE(LEFT(REVERSE(LEFT(@TLOGBackupFolder,LEN(@TLOGBackupFolder)-CHARINDEX('/',REVERSE(@TLOGBackupFolder),0))),CHARINDEX('/',REVERSE(LEFT(@TLOGBackupFolder,LEN(@TLOGBackupFolder)-CHARINDEX('/',REVERSE(@TLOGBackupFolder),0))),0)-1))))     
	SELECT @TLog_BackupLocation = REVERSE(LEFT(REVERSE(@TLOGBackupFolder),CHARINDEX('/',REVERSE(@TLOGBackupFolder),0)-1))
	--select @AzureBackupContainer
	--// Routine for Log backup cleanup // --
	SET @PSAzureCmd = 'powershell.exe "import-Module azure;$destContext = New-AzureStorageContext –StorageAccountName naestgrsrv01 -StorageAccountKey IC4M5F5Ux8LwgkMxqgbwGdhtgsnpp+pSDCLLQFDwcqVhsXzbrGuKLOZcKw2oRsIgpiYl18MEmh/2cOYj7DvjuA==;Get-AzureStorageBlob -Container "'+@AzureBackupContainer+'" -Context $destContext | SELECT Name,LastModified,BlobType | Where-Object {$_.Name -like '''+@TLog_BackupLocation+'/'+@DBNAME+'*'' -and $_.BlobType -eq ''PageBlob''} | Format-Table -Wrap -Auto"' 
	--PRINT @PSAzureCmd
	insert into @PowershellOutput
	exec master..xp_cmdshell @PSAzureCmd

	--select * from @PowershellOutput 

	INSERT INTO @CleanedOutput
	select 
	left(output,charindex('.trn',output,0)+3) backup_filename,
	RTRIM(LTRIM(substring(replace(replace(output,'PageBlob',''),'+00:00',''),charindex('.trn',replace(replace(output,'PageBlob',''),'+00:00',''),0)+4,len(replace(replace(output,'PageBlob',''),'+00:00',''))))) Backup_date
	from @PowershellOutput 
	where isnull(output,'') like '%.trn%'

	--select * from @CleanedOutput 

	INSERT INTO @CleanupCandidates
	SELECT ROW_NUMBER() OVER (ORDER BY Backup_Date) AS RowNo , backup_filename,Backup_Date
	FROM @CleanedOutput where Backup_Date < CONVERT(DATE,getdate() - @RetentionPeriodForTLOGBackupsInDays)

	--select * from @CleanupCandidates

	
	select @i= count(1) from @CleanupCandidates where Backup_Date < CONVERT(DATE,getdate() - @RetentionPeriodForTLOGBackupsInDays)
	SET @j=1
	
	WHILE(@j <= @i)
	BEGIN
		
		SELECT @BackupFileToBeDeleted = backup_filename 
		from @CleanupCandidates where RowNo = @j
		BEGIN TRY
			SELECT @PSAzureCmd = 'powershell.exe "import-Module azure;$destContext = New-AzureStorageContext  –StorageAccountName naestgrsrv01 -StorageAccountKey IC4M5F5Ux8LwgkMxqgbwGdhtgsnpp+pSDCLLQFDwcqVhsXzbrGuKLOZcKw2oRsIgpiYl18MEmh/2cOYj7DvjuA==;Get-AzureStorageBlob -Container "'+@AzureBackupContainer+'" -Context $destContext | Where-Object {$_.Name -like '''+@BackupFileToBeDeleted+''' -and $_.BlobType -eq ''PageBlob''} | Remove-AzureStorageBlob"'
			PRINT @PSAzureCmd
			exec master..xp_cmdshell @PSAzureCmd

			INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'Delete Azure TLOG-BACKUP','Successfully deleted TLOG BACKUP file : '+@BackupFileToBeDeleted+' From Azure Container :'+@AzureBackupContainer ,'I');
		END TRY
		BEGIN CATCH
			INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'Delete Azure TLOG-BACKUP','Couldn''t delete TLOG BACKUP file : '+@BackupFileToBeDeleted+' From Azure Container :'+@AzureBackupContainer ,'C');

		END CATCH
		 
		SET @j=@j+1
	END
	--// Routine for Log backup cleanup // --


END

GO


CREATE PROCEDURE [SQLMantainence].[PROC_DELETEOLD_AzureFULLBACKUPS] 
	@DBNAME VARCHAR(200) = NULL,
	@AzureBackupContainer VARCHAR(1000) = NULL,
	@FULL_BACKUPFOLDER_Azure VARCHAR(1000) = NULL,
	@DIFF_BACKUPFOLDER_Azure VARCHAR (1000) = NULL,
	@RETENTIONPERIODFORFULLBACKUPINDAYS INT = 8,
	@RETENTIONPERIODFORDIFFBACKUPINDAYS INT = 4
-- With Encryption
AS
BEGIN
SET NOCOUNT ON
	--SET @FULL_BACKUPFOLDER_Azure = 'full backups'--temp
	--SET @DBNAME  = 'PrismAdmin'--temp
	--SET @DIFF_BACKUPFOLDER_Azure = 'Diff backups' -- temp
	DECLARE  @PowershellOutput TABLE (output varchar(max))
	DECLARE @CleanedOutput TABLE (backup_filename varchar(max), Backup_Date datetime)
	DECLARE @CleanupCandidates TABLE ( RowNo int,backup_filename varchar(max), Backup_Date datetime)
	DECLARE @PSAzureCmd VARCHAR(5000)  
	
	DECLARE @BackupFileToBeDeleted VARCHAR(500)
	Declare @i int, -- Iterator
			@j int -- Increment

	
	--// Routine for full backup cleanup // --
	SET @PSAzureCmd = 'powershell.exe "import-Module azure;$destContext = New-AzureStorageContext –StorageAccountName naestgrsrv01 -StorageAccountKey IC4M5F5Ux8LwgkMxqgbwGdhtgsnpp+pSDCLLQFDwcqVhsXzbrGuKLOZcKw2oRsIgpiYl18MEmh/2cOYj7DvjuA==;Get-AzureStorageBlob -Container "'+@AzureBackupContainer+'" -Context $destContext | SELECT Name,LastModified,BlobType | Where-Object {$_.Name -like '''+@FULL_BACKUPFOLDER_Azure+'/'+@DBNAME+'*'' -and $_.BlobType -eq ''PageBlob''} | Format-Table -Wrap -Auto"' 
	--PRINT @PSAzureCmd
	insert into @PowershellOutput
	exec master..xp_cmdshell @PSAzureCmd

	--select * from @PowershellOutput
	INSERT INTO @CleanedOutput
	select 
	left(output,charindex('.bak',output,0)+3) backup_filename,
	RTRIM(LTRIM(substring(replace(replace(output,'PageBlob',''),'+00:00',''),charindex('.bak',replace(replace(output,'PageBlob',''),'+00:00',''),0)+4,len(replace(replace(output,'PageBlob',''),'+00:00',''))))) Backup_date
	from @PowershellOutput 
	where isnull(output,'') like '%.bak%'


	INSERT INTO @CleanupCandidates
	SELECT ROW_NUMBER() OVER (ORDER BY Backup_Date) AS RowNo , backup_filename,Backup_Date

	FROM @CleanedOutput where Backup_Date < CONVERT(DATE,getdate() - @RETENTIONPERIODFORFULLBACKUPINDAYS)

	--select * from @CleanupCandidates

	
	select @i= count(1) from @CleanupCandidates
	SET @j=1
	
	WHILE(@j <= @i)
	BEGIN
		
		SELECT @BackupFileToBeDeleted = backup_filename 
		from @CleanupCandidates where RowNo = @j

		BEGIN TRY
			SELECT @PSAzureCmd = 'powershell.exe "import-Module azure;$destContext = New-AzureStorageContext  –StorageAccountName naestgrsrv01 -StorageAccountKey IC4M5F5Ux8LwgkMxqgbwGdhtgsnpp+pSDCLLQFDwcqVhsXzbrGuKLOZcKw2oRsIgpiYl18MEmh/2cOYj7DvjuA==;Get-AzureStorageBlob -Container "'+@AzureBackupContainer+'" -Context $destContext | Where-Object {$_.Name -like '''+@BackupFileToBeDeleted+''' -and $_.BlobType -eq ''PageBlob''} | Remove-AzureStorageBlob"'
		--	PRINT @PSAzureCmd
			exec master..xp_cmdshell @PSAzureCmd,No_output
			INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'Delete Azure FULL-BACKUP','Successfully deleted FULLBACKUP file : '+@BackupFileToBeDeleted+' From Azure Container :'+@AzureBackupContainer ,'I');
		END TRY
		BEGIN CATCH
			INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'Delete Azure FULL-BACKUP','Couldn''t delete FULLBACKUP file : '+@BackupFileToBeDeleted+' From Azure Container :'+@AzureBackupContainer ,'C');

		END CATCH
		 
		SET @j=@j+1
	END
	--// Routine for full backup cleanup // --

	DELETE FROM @PowershellOutput;
	DELETE FROM @CleanedOutput;
	DELETE FROM @CleanupCandidates;

	--// Routine for differntial backup cleanup // --
	SET @PSAzureCmd = 'powershell.exe "import-Module azure;$destContext = New-AzureStorageContext –StorageAccountName naestgrsrv01 -StorageAccountKey IC4M5F5Ux8LwgkMxqgbwGdhtgsnpp+pSDCLLQFDwcqVhsXzbrGuKLOZcKw2oRsIgpiYl18MEmh/2cOYj7DvjuA==;Get-AzureStorageBlob -Container "'+@AzureBackupContainer+'" -Context $destContext | SELECT Name,LastModified,BlobType | Where-Object {$_.Name -like '''+@DIFF_BACKUPFOLDER_Azure+'/'+@DBNAME+'*'' -and $_.BlobType -eq ''PageBlob''} | Format-Table -Wrap -Auto"' 
	--PRINT @PSAzureCmd
	insert into @PowershellOutput
	exec master..xp_cmdshell @PSAzureCmd

	--select * from @PowershellOutput
	INSERT INTO @CleanedOutput
	select 
	left(output,charindex('.bak',output,0)+3) backup_filename,
	RTRIM(LTRIM(substring(replace(replace(output,'PageBlob',''),'+00:00',''),charindex('.bak',replace(replace(output,'PageBlob',''),'+00:00',''),0)+4,len(replace(replace(output,'PageBlob',''),'+00:00',''))))) Backup_date
	from @PowershellOutput 
	where isnull(output,'') like '%.bak%'
	--select 
	--left(output,charindex('.bak',output,0)+3) backup_filename,
	--rtrim(ltrim(substring(output,charindex('.bak',output,0)+4,10))) Backup_Date
	--from @PowershellOutput 
	--where isnull(output,'') like '%.bak%'
	
	INSERT INTO @CleanupCandidates
	SELECT ROW_NUMBER() OVER (ORDER BY Backup_Date) AS RowNo , backup_filename,Backup_Date
	FROM @CleanedOutput where Backup_Date < CONVERT(DATE,getdate() - @RETENTIONPERIODFORFULLBACKUPINDAYS)

	--select * from @CleanupCandidates

	select @i= count(1) from @CleanupCandidates 
	SET @j=1
	
	WHILE(@j <= @i)
	BEGIN
		SELECT @BackupFileToBeDeleted = backup_filename 
		from @CleanupCandidates where RowNo = @j

		BEGIN TRY
		
			SELECT @PSAzureCmd = 'powershell.exe "import-Module azure;$destContext = New-AzureStorageContext  –StorageAccountName naestgrsrv01 -StorageAccountKey IC4M5F5Ux8LwgkMxqgbwGdhtgsnpp+pSDCLLQFDwcqVhsXzbrGuKLOZcKw2oRsIgpiYl18MEmh/2cOYj7DvjuA==;Get-AzureStorageBlob -Container "'+@AzureBackupContainer+'" -Context $destContext | Where-Object {$_.Name -like '''+@BackupFileToBeDeleted+''' -and $_.BlobType -eq ''PageBlob''} | Remove-AzureStorageBlob"'
		  --  PRINT @PSAzureCmd
			exec master..xp_cmdshell @PSAzureCmd,No_output
			INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'Delete Azure Diff-BACKUP','Successfully deleted DIFFBACKUP file : '+@BackupFileToBeDeleted+' From Azure Container :'+@AzureBackupContainer ,'I');
		
		END TRY
		BEGIN CATCH
		
				INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'Delete Azure Diff-BACKUP','Couldn''t delete DIFFBACKUP file : '+@BackupFileToBeDeleted+' From Azure Container :'+@AzureBackupContainer ,'C');
		
		END CATCH 
		SET @j=@j+1;
	END
	--// Routine for full backup cleanup // --


END
GO

create PROCEDURE GENERATECPUUTILIZATIONSTATSBYEACHDATABASES
-- With Encryption
AS
BEGIN
--QUERY FOR CPU USAGE PERCENT WITH DATABASE NAME

WITH DB_CPU_STATS
AS
(SELECT DATABASEID, DB_NAME(DATABASEID) AS [DATABASENAME], SUM(TOTAL_WORKER_TIME) AS [CPU_TIME_MS]
FROM SYS.DM_EXEC_QUERY_STATS AS QS
CROSS APPLY (SELECT CONVERT(INT, VALUE) AS [DATABASEID] 
 FROM SYS.DM_EXEC_PLAN_ATTRIBUTES(QS.PLAN_HANDLE)
 WHERE ATTRIBUTE = N'DBID') AS F_DB
GROUP BY DATABASEID)

SELECT ROW_NUMBER() OVER(ORDER BY [CPU_TIME_MS] DESC) AS [ROW_NUM],
DATABASENAME, [CPU_TIME_MS], 
CAST([CPU_TIME_MS] * 1.0 / SUM([CPU_TIME_MS]) OVER() * 100.0 AS DECIMAL(5, 2)) AS [CPUPERCENT]
FROM DB_CPU_STATS
WHERE DATABASEID > 4 -- SYSTEM DATABASES
AND DATABASEID <> 32767 -- RESOURCEDB
ORDER BY ROW_NUM OPTION (RECOMPILE);


--QUERY TO FIND CATCHE SIZE USED BY EACH DATABASES

SELECT DB_NAME(DATABASE_ID) AS [DATABASE NAME],
CAST(COUNT(*) * 8/1024.0 AS DECIMAL (10,2)) AS [CACHED SIZE (MB)]
FROM SYS.DM_OS_BUFFER_DESCRIPTORS WITH (NOLOCK)
WHERE DATABASE_ID > 4 -- SYSTEM DATABASES
AND DATABASE_ID <> 32767 -- RESOURCEDB
GROUP BY DB_NAME(DATABASE_ID)
ORDER BY [CACHED SIZE (MB)] DESC OPTION (RECOMPILE);

--QUERY TO FIND OUT QUERY TEXT FOR SESSION ID

SELECT TEXT,EXECUTION_COUNT,LAST_WORKER_TIME,TOTAL_WORKER_TIME,* FROM SYS.DM_EXEC_QUERY_STATS CROSS APPLY SYS.DM_EXEC_SQL_TEXT(SQL_HANDLE)


--QUERY TO FIND EXECUTION COUNT, TOTAL WORKER TIME, LAST WORKER TIME.

SELECT TOP 1000
OBJECTNAME = 
OBJECT_SCHEMA_NAME(QT.OBJECTID,DBID) + '.' + OBJECT_NAME(QT.OBJECTID, 
QT.DBID)
 
,TEXTDATA = 
QT.TEXT
 
,DISKREADS = 
QS.TOTAL_PHYSICAL_READS -- THE WORST READS, DISK READS
 
,MEMORYREADS = 
QS.TOTAL_LOGICAL_READS --LOGICAL READS ARE MEMORY 

 
,EXECUTIONS = 
QS.EXECUTION_COUNT
 
,TOTALCPUTIME = 
QS.TOTAL_WORKER_TIME
 ,AVERAGECPUTIME = 
QS.TOTAL_WORKER_TIME/QS.EXECUTION_COUNT
 ,DISKWAITANDCPUTIME = 
QS.TOTAL_ELAPSED_TIME
 
,MEMORYWRITES = 
QS.MAX_LOGICAL_WRITES
 
,DATECACHED = 
QS.CREATION_TIME
 
,DATABASENAME = DB_NAME(QT.DBID)
 ,LASTEXECUTIONTIME = 
QS.LAST_EXECUTION_TIME
 FROM SYS.DM_EXEC_QUERY_STATS AS QS
 CROSS APPLY SYS.DM_EXEC_SQL_TEXT(QS.SQL_HANDLE) AS QT
 ORDER BY QS.TOTAL_WORKER_TIME DESC
END
GO

CREATE PROCEDURE [SQLMantainence].[CaptureAndSendSQLServerHealthCheckReport]
-- With Encryption
AS
BEGIN
       SET NOCOUNT ON
       DECLARE @TBLSERVERS TABLE (ID INT IDENTITY(1,1), SERVERNAME VARCHAR(1000))
       DECLARE @ServerName varchar(1000) 
       DECLARE @TOTAL INT
       DECLARE @ID INT
       DECLARE @NAME varchar(1000)
       DECLARE @StartDAteTime SmallDateTime = DateAdd(day,-1,getDate())
       Declare @EndDateTime   SmallDateTime = getDate()
       DECLARE @SQL VARCHAR(2000)

	   DECLARE @Environment varchar(100)
	   SELECT @Environment =  UPPER(IsNull(Value,'')) 
		FROM SQL_ADMIN.SQLMantainence.DBMantainenceConfiguration WITH(NOLOCK) 
		WHERE CONFIGURATIONTYPE = 'Environment'
	   SET @Environment = UPPER(IsNUll(@Environment,'PROD'))

       INSERT INTO @tblServers (SERVERNAME) 
	   SELECT   Instance_name 
	   FROM      Catalogue.SQLServers WITH(NOLOCK)
       WHERE  Is_DailyHealthCheckReporting_Enabled = 1


       --select * from @tblServers
       --//  Creating ReportPath
	
       DECLARE  @tempDIRTable TABLE (output varchar(1000))

       SELECT @SQL = 'DIR C:\Temp\SQLHealthCheckReporting'
       INSERT INTO @tempDIRTable Execute master..xp_cmdshell @SQL
       IF EXISTS (select * from @tempDIRTable where output like '%File Not Found%')
       BEGIN 
              SELECT @SQL = 'MKDIR C:\Temp'
              Execute master..xp_cmdshell @SQL

              SELECT @SQL = 'MKDIR C:\Temp\SQLHealthCheckReporting'
              Execute master..xp_cmdshell @SQL

			  SELECT @SQL = 'MKDIR C:\Temp\SQLHealthCheckReporting\Data'
              Execute master..xp_cmdshell @SQL

			  SELECT @SQL = 'MKDIR C:\Temp\SQLHealthCheckReporting\ScriptForZip'
              Execute master..xp_cmdshell @SQL

			-- CREATNG .BAT FILE I.E. ZIPAXREPORTS.BAT 
			  EXECUTE Master.dbo.xp_CmdShell 'ECHO CScript  C:\Temp\SQLHealthCheckReporting\ScriptForZip\zip.vbs  C:\Temp\SQLHealthCheckReporting\Data C:\Temp\SQLHealthCheckReporting\HealthCheckReport_ForSQLServers.zip   > C:\Temp\SQLHealthCheckReporting\ScriptForZip\ZipAXReports.bat', NO_OUTPUT

			  -- CREATING CSCRIPT FILE ZIP.VBS
			  EXECUTE Master.dbo.xp_CmdShell 'ECHO ''Get command-line arguments. > C:\Temp\SQLHealthCheckReporting\ScriptForZip\zip.vbs', NO_OUTPUT
			  EXECUTE Master.dbo.xp_CmdShell 'ECHO Set objArgs = WScript.Arguments >> C:\Temp\SQLHealthCheckReporting\ScriptForZip\zip.vbs', NO_OUTPUT
			  EXECUTE Master.dbo.xp_CmdShell 'ECHO InputFolder = objArgs(0) >> C:\Temp\SQLHealthCheckReporting\ScriptForZip\zip.vbs', NO_OUTPUT
			  EXECUTE Master.dbo.xp_CmdShell 'ECHO ZipFile = objArgs(1) >> C:\Temp\SQLHealthCheckReporting\ScriptForZip\zip.vbs', NO_OUTPUT
			  EXECUTE Master.dbo.xp_CmdShell 'ECHO ''Create empty ZIP file. >> C:\Temp\SQLHealthCheckReporting\ScriptForZip\zip.vbs', NO_OUTPUT
			  EXECUTE Master.dbo.xp_CmdShell 'ECHO CreateObject("Scripting.FileSystemObject").CreateTextFile(ZipFile, True).Write "PK" & Chr(5) & Chr(6) & String(18, vbNullChar) >> C:\Temp\SQLHealthCheckReporting\ScriptForZip\zip.vbs', NO_OUTPUT
			  EXECUTE Master.dbo.xp_CmdShell 'ECHO Set objShell = CreateObject("Shell.Application") >> C:\Temp\SQLHealthCheckReporting\ScriptForZip\zip.vbs', NO_OUTPUT
			  EXECUTE Master.dbo.xp_CmdShell 'ECHO Set source = objShell.NameSpace(InputFolder).Items >> C:\Temp\SQLHealthCheckReporting\ScriptForZip\zip.vbs', NO_OUTPUT
			  EXECUTE Master.dbo.xp_CmdShell 'ECHO objShell.NameSpace(ZipFile).CopyHere(source) >> C:\Temp\SQLHealthCheckReporting\ScriptForZip\zip.vbs', NO_OUTPUT
			  EXECUTE Master.dbo.xp_CmdShell 'ECHO ''Required! >> C:\Temp\SQLHealthCheckReporting\ScriptForZip\zip.vbs', NO_OUTPUT
			  EXECUTE Master.dbo.xp_CmdShell 'ECHO wScript.Sleep 2000 >> C:\Temp\SQLHealthCheckReporting\ScriptForZip\zip.vbs', NO_OUTPUT

       END

       --DECLARE @ReportPath varchar(100) = 'C:\Temp\SQLHealthCheckReporting\Data'
       --//  Creating ReportPath

       DECLARE @i INT = 1, @j INT
       SELECT @J = max(id) from @tblServers

       WHILE @I <= @j
       BEGIN
              SELECT @ServerName = ServerName From @tblServers WHERE ID = @I
              Print 'Server: ' + @ServerName
       
              IF Ltrim(IsNull(@ServerName,'')) <> ''
              BEGIN
                           SET @sql = 'EXECUTE [SQLMantainence].GenerateSQLServerHealthCheckReport ''' + Convert(varchar(100),@StartDAteTime,20) + ''',''' + Convert(varchar(100),@EndDateTime,20) + ''''
                           --select @sql

                           SET @SQL = 'SQLCMD -S ' + @SERVERNAME + ' -E  -d SQL_ADMIN -Q "SET NOCOUNT ON;' + @SQL + '" -I -s","  -o "' + 'C:\Temp\SQLHealthCheckReporting\Data' + '\' + Replace(Replace(Replace(@ServerName,'\','_'),' ','_'),'*','_') + '.CSV"'  
                           select @sql
                           Declare @SQLError INT
                           Execute @SQLError =  xp_cmdshell @SQL, no_output


              End   -- eND OF iF @SERVERNAME <> ''

              SELECT @I += 1 
       END   -- END OF WHILE LOOP.   SERVER LIST


       ---// Zip the reports and send through Mails

       DECLARE @MailSubject varchar(1000)= 'Daily Report: ' + @Environment + ' SQL Server Health Check'
	   DECLARE @MailRecipients varchar(2000)
	   SELECT Top 1 @MailRecipients =  [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='EmailRecipient'
       DECLARE @MailBody VARCHAR(MAX) = '<HTML><BODY>'
                     + 'Hi SQL Admins,<BR><BR>PFA Health Check Report of major ' + @Environment +  ' servers.<BR>Please review and take action if required.<BR><BR>Regards,<BR>SQL Team<BR><BR>' + '</BODY></HTML>'

       Execute @SQLError = xp_cmdshell 'C:\Temp\SQLHealthCheckReporting\ScriptForZip\ZipAXReports.bat', no_output







       IF @SQLError <> 1
       BEGIN
              WAITFOR DELAY '00:00:05'
              EXECUTE msdb..sp_send_dbmail @Profile_Name = 'DBMaintenance', @RECIPIENTS = @MailRecipients ,  @Subject = @MailSubject, @Body_Format= 'HTML',    @Body =              @MailBody ,@file_attachments = 'C:\Temp\SQLHealthCheckReporting\HealthCheckReport_ForSQLServers.zip' 
       END
       ---// Zip the reports and send through Mails

END
GO

-- ****************************************************************************************************
-- Execute [SQLMantainence].GenerateSQLServerHealthCheckReport '2014-08-05 08:00:22.930','2014-08-06 08:00:22.930'
--*****************************************************************************************************
CREATE PROCEDURE [SQLMantainence].GenerateSQLServerHealthCheckReport
(
@STARTDATETIME DateTime,
@ENDDATETIME DateTime
)
-- With Encryption
AS
BEGIN
SET NOCOUNT ON
DECLARE @SQL VARCHAR(2000)
DECLARE @TOTAL INT
DECLARE @ID INT
DECLARE @NAME varchar(1000)
Declare @SrNo INT = 0

DECLARE @Report TABLE (Topic varchar(1000),DETAILS VARCHAR(4000))

      IF NOT EXISTS(SELECT 1 FROM SQL_ADMIN.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'REPORT')
              CREATE TABLE dbo.Report (Tile INT, ID INT Identity(1,1),Topic varchar(1000),DETAILS VARCHAR(4000))
       ELSE   
              TRUNCATE TABLE SQL_ADMIN.DBO.REPORT

              INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:','')
              

                     --*********************************************************************************************
                     -- Check: Free space for each drive
                     --*********************************************************************************************
                     DECLARE  @OUTPUT TABLE (LINE VARCHAR(255))
                     SET @SQL = 'POWERSHELL.EXE -C "GET-WMIOBJECT -CLASS WIN32_VOLUME -FILTER ''DRIVETYPE = 3'' | SELECT NAME,CAPACITY,FREESPACE | FOREACH{''Drive = '' + $_.NAME + '' (Total Capacity='' +  [decimal]::round(((($_.CAPACITY/1024)/1024)/1024)) + '' GB, Free Space ='' +  [decimal]::round(((($_.FREESPACE/1024)/1024)/1024)) + '' GB('' + [decimal]::round(($_.FREESPACE * 100)/$_.CAPACITY) + ''%))''}"' 
                     INSERT INTO @OUTPUT (LINE)  EXECUTE XP_CMDSHELL @SQL 

                     INSERT INTO dbo.Report (Topic,DETAILS) 
                           SELECT 'Disk Info', LINE FROM @OUTPUT  WHERE (LINE IS NOT NULL AND CharIndex(':',LINE,1) > 0) 

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. disk space consumption and availability check')

                     --*********************************************************************************************
                     -- Check: CPU UTILIZATION DURING THE DAY
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (Topic,DETAILS) 
                           SELECT  Type, Convert(varchar(100),LogDate,20) + ' => ' + LogDetails  
                           FROM SQLMANTAINENCE.DBMANTAINENCELOG WITH(NOLOCK)
                           WHERE TYPE = 'CPU UTILIZATION' AND (LOGDATE >= @STARTDATETIME AND LOGDATE <= @ENDDATETIME)
                           ORDER BY LOGDATE DESC

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. List all high CPU utilization alerts generated in last 24 hours')
       
                     --*********************************************************************************************
                     -- Check: SQL CONFIGURATION 
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT 'Current SQL Server Configuration',UPPER(NAME) + ' = ' +  CAST(value_in_use AS VARCHAR(100)) 
                           FROM SYS.CONFIGURATIONS WITH(NOLOCK) 
                           WHERE NAME IN ('BACKUP COMPRESSION DEFAULT','MAX DEGREE OF PARALLELISM','MAX SERVER MEMORY (MB)','MIN SERVER MEMORY (MB)','REMOTE ACCESS')

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. Database related CONFIGURATION change captured in last 24 hrs')
       

                     --*********************************************************************************************
                     -- Check: ENABLED TRRACE FLAGS ON SQL SERVER
                     --*********************************************************************************************
                     DECLARE @TraceFlagStatus TABLE (Flag varchar(100), Status INT, Global INT, Session INT)

                     INSERT INTO @TraceFlagStatus
                       EXECUTE('DBCC TRACESTATUS')

					IF EXISTS(SELECT TOP 1 1 FROM @TraceFlagStatus)
					BEGIN
						 INSERT INTO dbo.Report (TOPIC,DETAILS)
						 SELECT 'SQL Trace Flags',Flag + ' => ENABLED' FROM @TraceFlagStatus
					END
					ELSE
					BEGIN
						INSERT INTO dbo.Report (TOPIC,DETAILS)
						  VALUES ('SQL Trace Flags','NO TRACE FLAGS ARE CURRENTLY ENABLED ON THIS SQL SERVER' )
					END

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. TRACE FLAGS STATUS ON SQL SERVER')
       

                     --*********************************************************************************************
                     -- Check: OFFLINE DATABASES
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT 'Un-Available Database(s)','Database ' + upper(Name) + ' is ' + state_desc 
                           FROM SYS.DATABASES  WITH(NOLOCK) 
                           WHERE STATE_DESC <> 'ONLINE' 

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. list of OFFLINE databases')

                     --*********************************************************************************************
                     -- Check: Check for DISABLED SQL JOBS on the server
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (TOPIC,DETAILS)
						   SELECT 'DISABLED SQL Jobs' , 'Job Name ' + upper(NAME) + ' is DISABLED' 
						   FROM MSDB.DBO.SYSJOBS WITH(NOLOCK) 
						   WHERE ENABLED = 0

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. list of Disabled SQL Jobs')

                     --*********************************************************************************************
                     -- Check: MONITORING ALERT DURING THE DAY
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT TOP 50 'Monitoring Alerts during the day',Convert(varchar(100),LogDate,20) + ' => ' + LogDetails 
                           FROM SQLMANTAINENCE.DBMANTAINENCELOG WITH(NOLOCK) 
                           WHERE (STATUS = 'C' AND TYPE = 'MONITORING-ALERTS') AND (LOGDATE BETWEEN @StartDAteTime AND @EndDateTime )
                           ORDER BY LogDate DESC

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. List all monitoring alerts in last 24 hours')

                     --*********************************************************************************************
                     -- Check: CONFIGURATION CHANGES DONE ON THE SERVER
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT TOP 50 'Server Configuration Changes during the day', LogDetails 
                           FROM SQLMantainence.DBMantainenceLOG WITH(NOLOCK) 
                           WHERE TYPE = 'ServerConfigurationChanges' AND (LOGDATE BETWEEN @StartDAteTime AND @EndDateTime )
                           ORDER BY LogDate Desc

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. Server related configuration changes in last 24 hrs')

                     --*********************************************************************************************
                     -- Check: FAILED SQL JOBS ON THE SERVER
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT TOP 50 'SQL Jobs failed during the day', LogDetails 
                           FROM SQLMantainence.DBMantainenceLOG WITH(NOLOCK) 
                           WHERE TYPE = 'CheckForFailedJobs' AND (LOGDATE BETWEEN @StartDAteTime AND @EndDateTime )
                           ORDER BY LogDate Desc

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. list of Failed Jobs in last 24 hrs')

                     --*********************************************************************************************
                     -- Check: ADHOC BACKUPS DONE ON THE SERVER BY NON SQL TEAM MEMBER
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT TOP 50 'Ad-Hoc Backups taken by non SQL team member', LogDetails 
                           FROM SQLMantainence.DBMantainenceLOG WITH(NOLOCK) 
                           WHERE TYPE = 'AdhocBackups' AND (LOGDATE BETWEEN @StartDAteTime AND @EndDateTime )
                           ORDER BY LogDate Desc

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. list of ad hoc backups taken by Non- SQL members in last 24 hrs ')
                     --*********************************************************************************************
                     -- Check:  restore  DONE ON THE SERVER BY NON SQL TEAM MEMBER
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT TOP 50 'Database Restoration done by non SQL team member', LogDetails 
                           FROM SQLMantainence.DBMantainenceLOG WITH(NOLOCK) 
                           WHERE TYPE = 'DatabaseRestore' AND (LOGDATE BETWEEN @StartDAteTime AND @EndDateTime )
                           ORDER BY LogDate Desc

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. List of db restore performed by Non- SQL members in last 24 hrs ')

                     --*********************************************************************************************
                     -- Check: SQL Services Restarted during the day
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT TOP 50 'SQL Server restart during the day', LogDetails 
                           FROM SQLMantainence.DBMantainenceLOG WITH(NOLOCK) 
                           WHERE TYPE = 'SQLRestart' AND (LOGDATE BETWEEN @StartDAteTime AND @EndDateTime )
                           ORDER BY LogDate Desc
                     
                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. List all SQL Server restart in last 24 hours')

                     --*********************************************************************************************
                     -- Check: SQL Audit Alerts during the day
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT TOP 50 'SQL Server Audit Alerts', LogDetails 
                           FROM SQLMantainence.DBMantainenceLOG WITH(NOLOCK) 
                           WHERE TYPE = 'CheckServerAuditLog' AND (LOGDATE BETWEEN @StartDAteTime AND @EndDateTime )
                           ORDER BY LogDate Desc

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. List all SQL server audit alerts in last 24 hours')


                     --*********************************************************************************************
                     -- Check: SUSPECT PAGES
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT 'Suspect Pages Report','Database = ' + DB_Name(database_id) + ', File ID = ' + Cast(File_id as varchar(100)) + 
                           ', Page ID = ' +  Cast(Page_id as varchar(100)) + ', Event Type = ' +  Cast(Event_Type as varchar(100)) + 
                           ', Error Count =' + Cast(Error_Count as varchar(100)) + ', Last Update Date = '  + Cast(Last_Update_Date as varchar(100))
                           FROM MSDB..SUSPECT_PAGES WITH(NOLOCK)

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. Detection of MSDB suspect pages in last 24 hrs')


                     --*********************************************************************************************
                     -- Check: for Database with data file having less than 30% free available space in MDF
                     --*********************************************************************************************
                     DECLARE  @DBSIZE TABLE  (DBNAME SYSNAME,DBSTATUS VARCHAR(50),RECOVERY_MODEL VARCHAR(40) DEFAULT ('NA'), FILE_SIZE_MB DECIMAL(30,2)DEFAULT (0),SPACE_USED_MB DECIMAL(30,2)DEFAULT (0),FREE_SPACE_MB DECIMAL(30,2) DEFAULT (0)) 
  
                     INSERT INTO @DBSIZE(DBNAME,DBSTATUS,RECOVERY_MODEL,FILE_SIZE_MB,SPACE_USED_MB,FREE_SPACE_MB) 
                     EXEC SP_MSFOREACHDB 
                     'USE [?]; SELECT DB_NAME() AS DBNAME, CONVERT(VARCHAR(20),DATABASEPROPERTYEX(''?'',''STATUS'')) , CONVERT(VARCHAR(20),DATABASEPROPERTYEX(''?'',''RECOVERY'')), SUM(SIZE)/128.0 AS FILE_SIZE_MB, SUM(CAST(FILEPROPERTY(NAME, ''SPACEUSED'') AS INT))/128.0 AS SPACE_USED_MB, SUM( SIZE)/128.0 - SUM(CAST(FILEPROPERTY (NAME, ''SPACEUSED'') AS INT))/128.0 AS FREE_SPACE_MB FROM SYS.DATABASE_FILES WITH(NOLOCK)  WHERE TYPE=0 GROUP BY TYPE' 

                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT 'Database space availability < 30%','Database = ' + upper(DBNAME) +  ' (' + RECOVERY_MODEL + ' Recovery Model), Total Size (MB) = ' +  Cast(FILE_SIZE_MB as varchar(100)) + ', Free Space = ' + Cast(FREE_SPACE_MB as varchar(100)) + ' (' + cast(Cast(((FREE_SPACE_MB * 100)/FILE_SIZE_MB) as decimal(10,2)) as varchar(100)) + '%)' 
                           FROM @DBSIZE 
                           WHERE ((FREE_SPACE_MB * 100) / FILE_SIZE_MB) <= 30 
                           ORDER BY DBNAME

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. List all databases with data files having < 30% space availability')


			--*********************************************************************************************
			-- Check: for Database with Transaction Log is having less than 20% free available space in LDF
			--*********************************************************************************************
			INSERT INTO @DBSIZE(DBNAME,DBSTATUS,RECOVERY_MODEL,FILE_SIZE_MB,SPACE_USED_MB,FREE_SPACE_MB) 
			EXEC SP_MSFOREACHDB 
			'USE [?]; SELECT DB_NAME() AS DBNAME, CONVERT(VARCHAR(20),DATABASEPROPERTYEX(''?'',''STATUS'')) , CONVERT(VARCHAR(20),DATABASEPROPERTYEX(''?'',''RECOVERY'')), SUM(SIZE)/128.0 AS FILE_SIZE_MB, SUM(CAST(FILEPROPERTY(NAME, ''SPACEUSED'') AS INT))/128.0 AS SPACE_USED_MB, SUM( SIZE)/128.0 - SUM(CAST(FILEPROPERTY (NAME, ''SPACEUSED'') AS INT))/128.0 AS FREE_SPACE_MB FROM SYS.DATABASE_FILES WITH(NOLOCK)  WHERE TYPE=1 GROUP BY TYPE' 

			INSERT INTO dbo.Report (TOPIC,DETAILS)
			SELECT 'Transaction Log space availability < 20%','Database = ' + upper(DBNAME) +  ' (' + RECOVERY_MODEL + ' Recovery Model), Total Size (MB) = ' +  Cast(FILE_SIZE_MB as varchar(100)) + ', Free Space = ' + Cast(FREE_SPACE_MB as varchar(100)) + ' (' + cast(Cast(((FREE_SPACE_MB * 100)/FILE_SIZE_MB) as decimal(10,2)) as varchar(100)) + '%)' 
			FROM @DBSIZE 
			WHERE ((FREE_SPACE_MB * 100) / FILE_SIZE_MB) <= 20 
			ORDER BY DBNAME

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. List all databases with Transaction Log is having < 20% space availability')


                     --*********************************************************************************************
                     -- Check: Database and Jobs where owner is not SA or SA
                     --*********************************************************************************************
                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT 'DATABASE/JOBS where owner is NOT "SA"','Database = [' + upper(A.Name) + '], Owner = ' +  upper(B.NAME) AS Owner 
                           FROM SYS.SYSDATABASES A WITH(NOLOCK) INNER JOIN SYS.SYSLOGINS B WITH(NOLOCK) ON A.SID = B.SID 
                           WHERE B.NAME NOT IN ('SA')
                           ORDER BY A.NAME

                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT 'DATABASE/JOBS where owner is NOT "SA"','SQL Job = [' + upper(A.NAME) + '], Owner' +  upper(B.NAME) 
                           FROM MSDB.DBO.SYSJOBS A WITH(NOLOCK) INNER JOIN SYS.SYSLOGINS B ON A.owner_sid = B.SID
                           WHERE B.NAME NOT IN ('SA')
                           ORDER BY A.NAME

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. Detecting database owner')


                     --*********************************************************************************************
                     -- Check: Deadlock events during the day
                     --*********************************************************************************************

                     SET @SQL = 'MASTER.DBO.XP_READERRORLOG 0, 1, N''Deadlock ENCOUNTERED'',NULL, ''' + 
                                         REPLACE(CONVERT(VARCHAR(100),@STARTDATETIME,126),'T',' ') + ''',  ''' + 
                                         REPLACE(CONVERT(VARCHAR(100),@ENDDATETIME,126),'T',' ')  + ''', N''ASC''' 

                     DECLARE  @TEMPDEADLOCKDETAILS TABLE (LOGDATE DATETIME, PROCESSINFO VARCHAR(100), TEXT VARCHAR(MAX),ROW_NO INT  IDENTITY(1,1)) 
                     INSERT INTO @TEMPDEADLOCKDETAILS  EXEC (@SQL)

                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT 'Deadlock Encountered on server','Deadlock Event Time = ' + Cast(Convert(DateTime,LOGDATE,21) as varchar(100))
                           FROM @TEMPDEADLOCKDETAILS

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. Deadlock occurences in last 24 hrs')


                     --*********************************************************************************************
                     -- Check: Orphan user reporting for any databases
                     --*********************************************************************************************
                     CREATE TABLE #ORPHAN_USERS  (DATABASE_NAME NVARCHAR(128) NOT NULL,[USER_NAME] NVARCHAR(128) NOT NULL)

                     DECLARE  @DATABASES  TABLE (ID INT IDENTITY(1,1), DATABASE_NAME NVARCHAR(128) NOT NULL)

                     INSERT  @DATABASES ( DATABASE_NAME)
                           SELECT NAME   FROM MASTER.SYS.DATABASES 
                           WHERE NAME NOT IN ('MASTER', 'TEMPDB', 'MSDB', 'DISTRIBUTION', 'MODEL') AND state_desc = 'ONLINE'

                     SELECT @TOTAL = COUNT(ID) FROM @DATABASES
                     SELECT @ID = 1

                     WHILE @ID <= @TOTAL
                     BEGIN
                           SELECT @NAME = DATABASE_NAME  FROM @DATABASES WHERE ID = @ID

                           SELECT @SQL = 'USE [' + @NAME + '];
                                  INSERT INTO #ORPHAN_USERS (DATABASE_NAME, USER_NAME)
                                  SELECT DB_NAME(), U.NAME FROM MASTER..SYSLOGINS L RIGHT JOIN [' + @NAME + '].dbo.SYSUSERS U  
                                  ON L.SID = U.SID WHERE L.SID IS NULL AND ISSQLROLE <> 1 AND ISAPPROLE <> 1 AND 
                                  U.NAME NOT IN  (''INFORMATION_SCHEMA'',''GUEST'',''DBO'',''SYS'',''SYSTEM_FUNCTION_SCHEMA'')'
                     --PRINT @SQL
                           EXEC (@SQL)

                           SELECT @ID += 1
                     END   -- END OF WHILE LOOP 

                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                           SELECT 'Orphan User(s)','Database = ' + Database_Name + ', User Name = ' + upper(USER_NAME) FROM #ORPHAN_USERS ORDER BY  [DATABASE_NAME], [USER_NAME];
                     DROP TABLE #ORPHAN_USERS


                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. list of Orphan users')


                     --*********************************************************************************************
                     -- Check: for any database for which backup has not happened since last 24 hours.....excluding the 
					 -- marked databases and system databases
                     --*********************************************************************************************
                --  DECLARE  @DBBackupFailure TABLE  (DBNAME SYSNAME, Last_Backup_Date DateTime) 
  
      
					DECLARE @TMPBACKUPS TABLE(DATABASENAME VARCHAR(1000), LASTBACKUP DATETIME)

					INSERT INTO @TMPBACKUPS


					EXEC SP_MSFOREACHDB '
					SELECT ''?'', MAX(A.LOGDATE) 
					FROM SQL_ADMIN.SQLMANTAINENCE.DBMANTAINENCELOG A WITH(NOLOCK)
					WHERE TYPE IN (''FULL-BACKUP'',''DIFFERENTIAL-BACKUP'',''TLOG-BACKUP'') AND LOGDETAILS LIKE ''%DATABASE: ?'' AND STATUS = ''I''
					 '

					INSERT INTO dbo.Report (TOPIC,DETAILS)
					 SELECT 'Backup Failures/Missing', 'Backup Not available for ' + upper(a.NAME) +  
						   Case When LastBackup IS NULL Then '' ELSE  ' since ' + Cast(LastBackup as varchar(1000)) END
				    FROM sys.SysDatabases A WITH(NOLOCK) LEFT JOIN  @TMPBACKUPS B  ON A.Name  COLLATE DATABASE_DEFAULT = B.DATABASENAME COLLATE DATABASE_DEFAULT
					 Where  (b.LASTBACKUP is NULL OR b.LastBackup < getDate() - 1) AND
							A.NAME NOT LIKE '%_TOBEDELETED%'  AND  A.NAME NOT IN('TEMPDB','Model') AND
							A.NAME NOT IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM [Sql_Admin].[SQLMANTAINENCE].[DBMANTAINENCECONFIGURATION]  WITH(NOLOCK) 
							WHERE CONFIGURATIONTYPE = 'EXCLUDEDATABASE') 

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. Check for database for which backup is not available since last 24 hour')

              --*********************************************************************************************
              -- Check: Check eventviwer critical error message
              --*********************************************************************************************
                     Declare @tblEventLogsForSQLApplication TABLE (Message varchar(2000))
                    -- SELECT @SQL = 'powershell -C "get-eventLog -logname application -Source "MSSQL*" -Entrytype error  -After '''+CONVERT(VARCHAR,@StartDAteTime,100) +''' | Format-Table -WRap -Auto TimeGenerated, message "'

                     SELECT @SQL = 'powershell -C "get-eventLog -logname application -Source "*" -Entrytype error  -After '''+CONVERT(VARCHAR,@StartDAteTime,100) +''' | Format-Table -WRap -Auto TimeGenerated, message "'

                     INSERT INTO @tblEventLogsForSQLApplication (message) Execute xp_cmdshell @SQL
                     DELETE FROM @tblEventLogsForSQLApplication WHERE (Message is NULL OR Left(Message,Len('TimeGenerated       Message')) = 'TimeGenerated       Message'  OR Left(Message,Len('-------------       ------- ')) = '-------------       ------- ')

                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                     SELECT 'SQL Critical Alerts in Event Viewer',Message FROM @tblEventLogsForSQLApplication

                     SET @SrNo += 1
                     INSERT INTO  @Report (Topic,DETAILS) values (char(216)+'Checks performed in this report:', Cast(@SrNo as varchar(100)) + '. eventviwer- critical error message')

                     INSERT INTO dbo.Report (TOPIC,DETAILS)
                     SELECT Topic,DETAILS FROM @Report

                     --******************************************************************************************
                     -- BELOW ARE SOME CLEANUP ACTIVITY REQUIRED FOR REPORTING IN EXCEL PURPOSE...
                     --*****************************************************************************************
                     ;WITH CTE1 (SR, TOPIC, DETAILS, ID, TILE)
                     AS ( SELECT RANK() OVER (PARTITION BY TOPIC ORDER BY ID) AS SR, TOPIC, DETAILS, ID, TILE FROM REPORT )
                     UPDATE CTE1 SET TILE = CTE1.SR
                     UPDATE REPORT SET  TOPIC = ''  WHERE TILE > 1
                     --******************************************************************************************
                     
                     SELECT Topic as [Check], Replace(Details,',',char(130)) AS [Value] FROM sql_admin.DBO.REPORT ORDER BY ID
END
GO

CREATE Procedure SQLMantainence.SP_MantainencePlanScriptForFullBackupOfSSASDatabases
-- With Encryption
AS

BEGIN
	SET NOCOUNT ON;

	
    DECLARE @SSAS_BACKUPFOLDER VARCHAR(1000), @SSAS_Backup_RetentionDays INT

	SELECT @SSAS_BACKUPFOLDER = Ltrim(Rtrim(IsNull(VALUE,''))) 
	FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  
	WHERE configurationType='SSAS_BackupFolder'

	SELECT @SSAS_Backup_RetentionDays = Value  
	FROM [SQL_ADMIN].SQLMantainence.DBMantainenceConfiguratiON With(NoLock) 
	WHERE configurationType = 'RetentionPeriodForSSASbackupInDays'
	IF IsNumeric(@SSAS_Backup_RetentionDays) = 0 
		SET @SSAS_Backup_RetentionDays = 8 -- default 8 dayss for retaining SSAS backup


	IF @SSAS_BACKUPFOLDER = '?' OR @SSAS_BACKUPFOLDER = ''
		Print '*** Error: SSAS Backup Folder is not defined *****'
	ELSE
	BEGIN
		-- *******************************************************************************
		-- BELOW PART IS TO EXTRACT LIST OF AVAILABLE SSAS DATABASES ...for taking backups
		DECLARE @sql varchar(1000)
		SET @SQL = @SSAS_BACKUPFOLDER + '\SCRIPT\LISTSSASDATABASES.CMD ' +  Left(@SSAS_BACKUPFOLDER,2) + ',' + @SSAS_BACKUPFOLDER + '\script,' + @@servername

		DECLARE @tblSSASDatabases TABLE (ID INT Identity(1,1), DatabaseName varchar(1000))
		INSERT INTO @TBLSSASDATABASES (DATABASENAME)
		EXECUTE XP_CMDSHELL @SQL
		-- REMOVING UNWANTED DATA FROM THE LIST...CLEANUP
		DELETE FROM @TBLSSASDATABASES WHERE DATABASENAME IS NULL OR  LEFT(DATABASENAME,9) <> 'DATABASE:'
		UPDATE @TBLSSASDATABASES SET DATABASENAME = SUBSTRING(DATABASENAME,10,1000)
		-- *******************************************************************************

		Declare @I INT = 1
		DECLARE @Total INT 
		DECLARE @XMLA_SQL VARCHAR(4000)

		SELECT @TOTAL = MAX(ID) FROM @tblSSASDatabases
		DECLARE @DBName varchar(1000), @BackupFileName varchar(1000) 


		WHILE @I <= @TOTAL
		BEGIN
		
			SELECT @DBName = DatabaseName FROM @tblSSASDatabases WHERE ID = @I
		    SELECT @BackupFileName = @SSAS_BACKUPFOLDER + '\' +  @DBName + '@' + Cast(DatePart(hour,getdate()) as varchar(2)) + Cast(DatePart(minute,getdate()) as varchar(2)) + Cast(DatePart(second,getdate()) as varchar(2)) + '@DONOTDELETETILL@' + CONVERT(VARCHAR(100),DateAdd(Day, @SSAS_Backup_RetentionDays, getdate()),112) + '.abf'

			BEGIN TRY
					--ascmd -S <server name> -i process.xmla -v cube=<CubeID>
					-- BELOW IS THE ACTUAL BACKUP SCRIPT I.E. XMLA script for taking each SSAS database backup
	
					SELECT @XMLA_SQL = '<Backup xmlns="http://schemas.microsoft.com/analysisservices/2003/engine"><Object><DatabaseID>' + @DBName + '</DatabaseID></Object><File>' + @BackupFileName + '</File></Backup>'

					--PRINT @XMLA_SQL
					EXECUTE (@XMLA_SQL)  AT [LOCAL_SSAS_SERVER_FORDAILYBACKUPS]

						-- SCRIPT BELOW IS EXECUTED TO LOG THE ENTRY IN MAINTENANCE LOG FOR THE SUCESSFUL BACKUP OF THE CURRENT DATABASE
					INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'SSAS-BACKUP','SSAS Backup Successfull for the database: '+@DBName,'I');
					EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackupOfSSASDatabases','SSAS-BACKUP'	
			END TRY
					
			BEGIN CATCH
					-- SCRIPT BELOW IS TO RECORD FAILED BACKUP ENTRY FOR THE CURRENT DATABASE
				INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'FULL-BACKUP','SSAS Backup failed for the database: '+@DBName,'C');
				EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackupOfSSASDatabases','SSAS-BACKUP'
			END CATCH
			SELECT @i += 1
		END  -- END OF WHILE LOOP

		-- ******************************************************************
		-- CALL THE DELETE OLDER SSAS BACKUP SCRIPT BEOW

		-- ******************************************************************

	END -- END OF IF BACKUP FOLDER <> ''
END  -- END OF PROCEDURE
GO


CREATE PROCEDURE TRACING.GetTempDBRelatedDataOnAutoGrowthEvent
@AutoGrowthEventDate datetime = NULL
AS
BEGIN
SET NOCOUNT ON

--DECLARE @AutoGrowthEventDate datetime

IF @AutoGrowthEventDate IS NULL
SELECT @AutoGrowthEventDate = max(tracingDate) from sql_admin.tracing.VersionStoreInfoTempDB (NOLOCK)

select  *  from sql_admin.tracing.InternalAndUserObjectsInfoTempDB I (NOLOCK)
inner join sql_admin.tracing.VersionStoreInfoTempDB V (NOLOCK) 
on convert(varchar(20),I.TracingDate,100) = convert(varchar(20),V.TracingDate,100)
inner join sql_admin.tracing.OpenTransactionsTempDB O (NOLOCK) 
on convert(varchar(20),I.TracingDate,100) = convert(varchar(20),O.TracingDate,100)
where I.tracingDate between 
convert(varchar(20),@AutoGrowthEventDate,100) and convert(varchar(20),dateadd(mi,2,@AutoGrowthEventDate),100)

END
GO


-- =============================================
-- Author:	 Suji
-- Create date: 2014-03-12
-- Description:	trap data on tempdb autogrowth 
-- =============================================
CREATE PROCEDURE [TRACING].[TrapLiveQueriesDuringTempDbAutoGrowth] 
  
AS 
BEGIN
       SET NOCOUNT ON
       DECLARE 
--     @SecondLastExecutionTime datetime,
--     ,@InsertedDateTime datetime 
       @InsertedDatabaseName VARCHAR(200)
--     ,@InsertedFileType VARCHAR(10)


--select 
----@InsertedDateTime = i.startTime,@InsertedFileType = i.FileType,
--@InsertedDatabaseName= i.DatabaseName from inserted i


       IF EXISTS(SELECT 1 FROM SQL_Admin.SYS.TABLES WHERE NAME = 'VersionStoreInfoTempDB' AND schema_id = schema_id('Tracing'))
       BEGIN
              --Version Store Info
              INSERT INTO [TRACING].[VersionStoreInfoTempDB]
           ([version store pages used]
           ,[version store space in MB])
              SELECT SUM(version_store_reserved_page_count) AS [version store pages used],
              (SUM(version_store_reserved_page_count)*1.0/128) AS [version store space in MB]
              --INTO TRACING.VersionStoreInfoTempDB
              FROM tempdb.sys.dm_db_file_space_usage;
       END

       IF EXISTS(SELECT 1 FROM SQL_Admin.SYS.TABLES WHERE NAME = 'OpenTransactionsTempDB' AND schema_id = schema_id('Tracing'))
       BEGIN
              --Open Transactions
              INSERT INTO [TRACING].[OpenTransactionsTempDB]
           ([session_id]
           ,[transaction_id]
           ,[text]
           ,[is_snapshot]
           ,[loginame]
           ,[hostname]
           ,[login_time]
           ,[last_batch])
              SELECT t.session_id,transaction_id,[sql].[text],t.is_snapshot,s.loginame,s.hostname,s.login_time,s.last_batch
              --INTO TRACING.OpenTransactionsTempDB
              FROM tempdb.sys.dm_tran_active_snapshot_database_transactions t
              inner join sys.sysprocesses s on s.spid = t.session_id
              cross apply sys.dm_exec_sql_text(s.sql_handle) [sql]
       END

       IF EXISTS(SELECT 1 FROM SQL_Admin.SYS.TABLES WHERE NAME = 'InternalAndUserObjectsInfoTempDB' AND schema_id = schema_id('Tracing'))
       BEGIN
              --Determining the Amount of Space Used by Internal Objects and UserObjects
              INSERT INTO [TRACING].[InternalAndUserObjectsInfoTempDB]
           ([internal object pages used]
           ,[internal object space in MB]
           ,[user object pages used]
           ,[user object space in MB])
              SELECT SUM(internal_object_reserved_page_count) AS [internal object pages used],
              (SUM(internal_object_reserved_page_count)*1.0/128) AS [internal object space in MB],
              SUM(user_object_reserved_page_count) AS [user object pages used],
              (SUM(user_object_reserved_page_count)*1.0/128) AS [user object space in MB]
              --INTO TRACING.InternalAndUserObjectsInfoTempDB
              FROM tempdb.sys.dm_db_file_space_usage;
       END

       
DECLARE @GrowthINKB INT
,@DataFileSizeThreshold INT,
@NewThreshold INT,
@NewPerfomanceCondition NVARCHAR(1000)

select @GrowthINKB = (Growth/128)*1024 from tempdb.sys.database_files where type_desc = 'rows'

--select @CurrentDataFileSize = cntr_value from sys.dm_os_performance_counters where counter_name = 'Data File(s) Size (KB)' and instance_name = 'tempdb'

select @DataFileSizeThreshold = substring(performance_condition,CHARINDEX('>|',performance_condition,0)+2,len(performance_condition)) from msdb.dbo.sysalerts where name = 'TempDBDatabaseAutogrowthAlert' 

select @NewThreshold  = @DataFileSizeThreshold + @GrowthINKB

SELECT @NewPerfomanceCondition = 'Databases|Data File(s) Size (KB)|tempdb|>|'+CAST(@NewThreshold AS nvarchar(100))

EXEC msdb.dbo.sp_update_alert @name=N'TempDBDatabaseAutogrowthAlert', 
              @message_id=0, 
              @severity=0, 
              @enabled=1, 
              @delay_between_responses=0, 
              @include_event_description_in=0, 
              @database_name=N'', 
              @notification_message=N'', 
              @event_description_keyword=N'', 
              @performance_condition=@NewPerfomanceCondition, 
              @wmi_namespace=N'', 
              @wmi_query=N'', 
              @job_name=N'Tracing.TrapLiveQueriesDuringTempDbAutoGrowth'
END
GO




CREATE VIEW [SQLMantainence].[WhatIsGoingOn]
AS
SELECT OBJECT_NAME(objectid) as ObjectName, SUBSTRING(stateText.text, (statement_start_offset/2)+1, ((CASE statement_end_offset
WHEN -1 THEN DATALENGTH(stateText.text) ELSE statement_end_offset END - statement_start_offset)/2) + 1) AS statement_text --,DB_Name(database_id) as DatabaseName
,req.cpu_time AS CPU_Time ,DATEDIFF(minute, last_request_start_time, getdate()) AS RunningMinutes ,req.Percent_Complete,sess.HOST_NAME as RunningFrom ,LEFT(CLIENT_INTERFACE_NAME, 25) AS RunningBy
,sess.session_id AS SessionID, req.blocking_session_id AS BlockingWith, req.reads, req.writes, sess.[program_name], sess.login_name, sess.status, sess.last_request_start_time,req.logical_reads
FROM sys.dm_exec_requests req
     INNER JOIN sys.dm_exec_sessions sess ON sess.session_id = req.session_id AND sess.is_user_process = 1
     CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS stateText
GO


-- =============================================
-- Created By---SQL Team on 28th November 2013
-- This stored procedure records SQL Process Blockings in the SQL_Admin database
-- -- Select * From [SQLMantainence].[WhatIsGoingOn]
-- =============================================
CREATE PROCEDURE [SQLMANTAINENCE].[CHECK_PROCESSBLOCKINGS] 
-- With Encryption  	
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @THRESHOLD_FOR_BLOCKING_SECONDS INT 

	SELECT @THRESHOLD_FOR_BLOCKING_SECONDS=VALUE 
	FROM SQLMANTAINENCE.DBMANTAINENCECONFIGURATION WITH(NOLOCK)
	WHERE CONFIGURATIONTYPE='THRESHOLD_FOR_BLOCKING_SECONDS'

	DECLARE @HTML_BODY  NVARCHAR(MAX) 

	 CREATE TABLE #BLOCKING (BLOCK_SESSIONID INT, BLOCK_EVENT_INFO NVARCHAR(MAX),
		 BLOCKINGSTATEMENTTEXT NVARCHAR(MAX), RUNNINGMINUTES INT, BLOCKINGSESSIONID INT,
		 PROGRAM_NAME NVARCHAR(MAX), LOGIN_NAME NVARCHAR(MAX),  RUNNINGBY NVARCHAR(MAX),
		 RUNNINGFROM NVARCHAR(MAX), BLOCKINGSTATUS NVARCHAR(MAX), DATECREATED DATETIME)

	INSERT INTO #BLOCKING
		SELECT W1.SESSIONID AS BLOCK_SESSIONID, W1.STATEMENT_TEXT AS BLOCK_EVENT_INFO,
		W2.STATEMENT_TEXT AS BLOCKINGSTATEMENTTEXT, W2.RUNNINGMINUTES,
		W2.SESSIONID AS BLOCKINGSESSIONID, W2.PROGRAM_NAME, W2.LOGIN_NAME,
		W2.RUNNINGBY, W2. RUNNINGFROM, W2.STATUS AS BLOCKINGSTATUS,	GETDATE() AS DATECREATED
		FROM SQL_ADMIN.SQLMANTAINENCE.WHATISGOINGON W1 INNER JOIN SQL_ADMIN.SQLMANTAINENCE.WHATISGOINGON W2
		ON W1.BLOCKINGWITH > 0 AND W1.BLOCKINGWITH = W2.SESSIONID


	IF EXISTS (SELECT * FROM #BLOCKING WHERE (RUNNINGMINUTES * 60)  >= @THRESHOLD_FOR_BLOCKING_SECONDS )
	BEGIN
		SET @HTML_BODY =
			N'<H3><font color="660000">Blocking Report for PLSUPDB01</font></H3>' +
			N'<table border="1">' + N'<tr><th> Block_SessionID </th> <th> Block_event_info </th>
			<th>  BlockingSessionID  </th> 	<th>  BlockingStatementText  </th>' + N'<th>  RunningMinutes  </th>
			<th>  Program_Name  </th>'+ N'<th>  Login_name  </th>' +
			 N'<th>  RunningBy  </th><th>  RunningFrom  </th><th>  BlockingStatus  </th><th> DateCreated </th>' +
			   CAST (( SELECT td = Block_SessionID ,       '', td = Block_event_info, '', td = BlockingSessionID, '',
							td = BlockingStatementText , '', td = RunningMinutes, '', td = Program_Name  , '', td = login_name    , '', td = RunningBy    , '',
							td = RunningFrom    , '', td = BlockingStatus    , '', td = DateCreated     
						FROM #blocking WHERE (RUNNINGMINUTES * 60)  >= @THRESHOLD_FOR_BLOCKING_SECONDS 
						FOR XML PATH('tr'), TYPE ) AS NVARCHAR(MAX) ) +
			   N'</table>' ;

			DECLARE @ACTUAL_IP_ADDRESS VarChar(1000)
			CREATE TABLE #temp1(SQL_IP VarChar(3000))
			INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 	
			DECLARE @IPAddress VarChar(300) 
			SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IPv4%' ORDER BY SQL_IP DESC) 	
			DECLARE @len INT 
			SET @Len = CHARINDEX(':', @IPAddress) 
			SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPAddress, @Len+1, LEN(@IPAddress)))) 
			DROP TABLE #temp1

			DECLARE @EMAILRECEPIENTS NVarChar(2000) 
			DECLARE @SUBJECT NVarChar(2000)
			DECLARE @Environment VarChar (50), @EnvironmentDesc VarChar (50)
			
			SELECT TOP 1  @Environment = [VALUE]  FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='Environment'
			SELECT TOP 1 @EnvironmentDesc = CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END
			SELECT @SUBJECT = UPPER(@EnvironmentDesc) +  ' Blocking Issue found ON Server ' + @@SERVERNAME  + '( IP Address: ' + @ACTUAL_IP_ADDRESS + ')'
			SELECT Top 1 @EMAILRECEPIENTS =  [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='EmailRecipient'

			EXECUTE msdb..sp_send_dbmail 
			@Profile_Name  =  'DBMaintenance', 
			@Recipients  = @EMAILRECEPIENTS,
			@Subject  = @SUBJECT,
			@Body_format =  'HTML',
			@Body  = @HTML_BODY,
			@Execute_Query_Database  =  'SQL_ADMIN'	

END
DROP TABLE #BLOCKING


/*
   -- OLD - NDS Script

	IF EXISTS(SELECT TOP 1 BLOCKING_SESSION_ID  FROM SYS.DM_OS_WAITING_TASKS WHERE BLOCKING_SESSION_ID IS NOT NULL AND  RESOURCE_DESCRIPTION IS NOT NULL)
	BEGIN	
		INSERT INTO SQL_ADMIN.SQLMANTAINENCE.BLOCKING_HISTORY(SERVERNAME,BLOCKED_DATABASENAME,BLOCKEE_ID,BLOCKER_ID,WAIT_TIME_MINUTES,WAIT_TYPE,RESOURCE_TYPE,REQUESTING_TEXT,BLOCKING_TEXT)
	    SELECT  @@SERVERNAME AS SERVERNAME ,
		DB_NAME(TLS.RESOURCE_DATABASE_ID) AS 'DATABASE NAME', 	-- PAT.OBJECT_ID BLOCKEDOBJECTNAME,			
		OWT.SESSION_ID AS 'REQUEST SESSION ID(BLOCKEE)' ,  OWT.BLOCKING_SESSION_ID AS 'BLOCKING SESSION ID',
		(ERS.WAIT_TIME/1000) AS 'WAITTIME_MINUTES', OWT.WAIT_TYPE AS WAITTYPE ,
		TLS.RESOURCE_TYPE AS RESOURCETYPE, H1.TEXT AS REQUESTINGTEXT, H2.TEXT AS BLOCKINGTEST				
		FROM SYS.DM_TRAN_LOCKS AS TLS						    
		INNER JOIN SYS.DM_OS_WAITING_TASKS OWT ON TLS.LOCK_OWNER_ADDRESS = OWT.RESOURCE_ADDRESS
		INNER JOIN SYS.DM_EXEC_REQUESTS ERS ON TLS.REQUEST_REQUEST_ID = ERS.REQUEST_ID AND OWT.SESSION_ID = ERS.SESSION_ID
		--INNER JOIN SYS.PARTITIONS PAT ON PAT.HOBT_ID = TLS.RESOURCE_ASSOCIATED_ENTITY_ID			
		INNER JOIN SYS.DM_EXEC_CONNECTIONS EC1 ON EC1.SESSION_ID = TLS.REQUEST_SESSION_ID
		INNER JOIN SYS.DM_EXEC_CONNECTIONS EC2 ON EC2.SESSION_ID = OWT.BLOCKING_SESSION_ID
		CROSS APPLY SYS.DM_EXEC_SQL_TEXT(EC1.MOST_RECENT_SQL_HANDLE) AS H1
		CROSS APPLY SYS.DM_EXEC_SQL_TEXT(EC2.MOST_RECENT_SQL_HANDLE) AS H2
		OUTER APPLY SYS.DM_EXEC_QUERY_PLAN(ERS.[PLAN_HANDLE]) AS QP
		WHERE (ERS.WAIT_TIME/1000) > @THRESHOLD_FOR_BLOCKING_SECONDS 
	END

*/

END
GO



CREATE PROCEDURE [SQLMantainence].[CreateDBRolesAndAutoGrowthForTestServer]
-- With Encryption
AS
Begin
	SET NOCOUNT ON
	DECLARE @SQLCMD varchar(1000)
	DECLARE @DBNAME VARCHAR(1000)
	
	/* EXECUTE THIS PART ON TEST ENVIRONMENT ONLY */
	/* 
	On UAT environment development team will have READ and EXECUTE rights.
	Application Support Team will have READ,WRITE,EXECUTE,SQL JOB access
	*/
	/* These AutoGrowth values and Roles are added to Model Database tobe set as default for all new database created on this server */


	SET @SQLCMD = 'USE [MSDB];IF NOT EXISTS(SELECT 1 FROM DBO.SYSUSERS WHERE NAME = ''DB_SUPPORT'' AND (ISSQLROLE = 1 OR ISAPPROLE = 1)) CREATE ROLE DB_SUPPORT AUTHORIZATION [dbo]'
	Execute(@SQLCMD)

	--SET @SQLCMD = 'USE [MSDB];ALTER ROLE SQLAgentOperatorRole ADD MEMBER DB_SUPPORT'

	SET @SQLCMD ='USE [MSDB]; EXEC sp_AddRoleMember ''SQLAgentOperatorRole'',''DB_SUPPORT'''
	Execute(@SQLCMD)

	CREATE TABLE ##DBLIST  (ID INT IDENTITY(1,1),DBNAME VARCHAR(MAX), DATAFILENAME VARCHAR(MAX), LOGFILENAME VARCHAR(MAX), DATAFILESIZE FLOAT,LOGFILESIZE FLOAT, DoesDeveloperRoleExists bit Default(0), DoesSupportRoleExists bit Default(0))

	INSERT INTO ##DBLIST (DBNAME)
	SELECT A.NAME FROM SYS.databases A WITH(NOLOCK)
	--INNER JOIN SYS.master_files B ON A.dbid = B.database_id
	WHERE A.NAME NOT IN ('master', 'msdb', 'tempdb','ReportServer','ReportServerTempDB','distribution')
	and state_desc = 'ONLINE'

	UPDATE ##DBLIST 
	SET LOGFILENAME = SYS.master_files.NAME, LOGFILESIZE = SYS.master_files.SIZE 		
	FROM SYS.master_files, ##DBLIST 
	WHERE SYS.MASTER_FILEs.database_id = DB_ID(dbname) AND FILE_ID = 2

	UPDATE ##DBLIST 
	SET DATAFILENAME = SYS.master_files.NAME, DATAFILESIZE = SYS.master_files.SIZE 		
	FROM SYS.master_files, ##DBLIST 
	WHERE SYS.MASTER_FILEs.database_id = DB_ID(dbname) AND FILE_ID = 1 


	EXEC sp_MSForEachDB 'Use [?]; UPDATE ##DBLIST 
	SET DoesDeveloperRoleExists = 1
	FROM [?].DBO.SYSUSERS 
	WHERE DBNAME = ''?'' AND NAME = ''DB_DEVELOPERS'' AND (ISSQLROLE = 1 OR ISAPPROLE = 1)'

	EXEC sp_MSForEachDB 'Use [?]; UPDATE ##DBLIST 
	SET DoesSupportRoleExists = 1
	FROM [?].DBO.SYSUSERS 
	WHERE DBNAME = ''?'' AND NAME = ''DB_SUPPORT'' AND (ISSQLROLE = 1 OR ISAPPROLE = 1)'

	SET @DBNAME = ''
	DECLARE @I INT = 1
	DECLARE @DATAFILENAME VARCHAR(1000)
	DECLARE @LOGFILENAME VARCHAR(1000)
	DECLARE @DATAFILESIZE FLOAT
	DECLARE @LOGFILESIZE FLOAT 
	DECLARE @DoesDeveloperRoleExists BIT
	DECLARE @DoesSupportRoleExists BIT

	WHILE @I <= (SELECT MAX(ID) FROM ##DBLIST)
	BEGIN
		SELECT @DBNAME = DBNAME, @DATAFILENAME = DATAFILENAME,
		@LOGFILENAME = LOGFILENAME, @DATAFILESIZE   = DATAFILESIZE,
		@LOGFILESIZE = LOGFILESIZE,@DoesDeveloperRoleExists = DoesDeveloperRoleExists,
		@DoesSupportRoleExists = DoesSupportRoleExists
		FROM ##DBLIST WHERE ID = @I
		 
 			-- Default Auto FileGrowthvalue FOR DATA FILE in  SELECTED Database
		IF  ((@DATAFILESIZE * 8.0 / 1024) < 200) 
			EXEC ('ALTER DATABASE [' + @DBNAME + '] MODIFY FILE ( NAME = N''' + @DATAFILENAME + ''', SIZE = 200MB , FILEGROWTH = 250MB)' )
--PRINT 'ALTER DATABASE [' + @DBNAME + '] MODIFY FILE ( NAME = N''' + @DATAFILENAME + ''', SIZE = 200MB , FILEGROWTH = 250MB)' 		
 			-- Default Auto FileGrowthvalue FOR LOG FILE in  SELECTED Database
		IF  ((@LOGFILESIZE * 8.0 / 1024) < 200) 
			EXEC ('ALTER DATABASE [' + @DBNAME + '] MODIFY FILE ( NAME = N''' + @LOGFILENAME + ''', SIZE = 200MB , FILEGROWTH = 250MB)') 		


				-- For Developer Group
			IF @DoesDeveloperRoleExists = 0
			BEGIN
				SET @SQLCMD = 'USE [' + @DBNAME + ']; CREATE ROLE DB_DEVELOPERS AUTHORIZATION [dbo]'
				Execute(@SQLCMD)

				SET @SQLCMD = 'USE [' + @DBNAME + '];ALTER ROLE db_datareader ADD MEMBER DB_DEVELOPERS'
				SET @SQLCMD += ';GRANT EXECUTE TO DB_DEVELOPERS'
				Execute(@SQLCMD)
			END 

			IF @DoesDeveloperRoleExists = 0
			BEGIN
				SET @SQLCMD = 'USE [' + @DBNAME + '];CREATE ROLE DB_SUPPORT AUTHORIZATION [dbo]'
				Execute(@SQLCMD)

				SET @SQLCMD = 'USE [' + @DBNAME + '];ALTER ROLE db_datareader ADD MEMBER DB_SUPPORT'
				SET @SQLCMD += ';ALTER ROLE db_datawriter ADD MEMBER DB_SUPPORT'
				SET @SQLCMD += ';GRANT EXECUTE TO DB_SUPPORT'
				Execute(@SQLCMD)
			END 


		SET @I += 1
	END  -- END OF LOOP

	DROP TABLE ##DBLIST
End
go


CREATE PROCEDURE [SQLMantainence].[CreateDBRolesAndAutoGrowthForProductionServer]
-- With Encryption
AS
Begin
	SET NOCOUNT ON
	DECLARE @SQLCMD varchar(1000)
	DECLARE @DBNAME VARCHAR(1000)
	
/* EXECUTE THIS PART ON PRODUCTION ENVIRONMENT ONLY */
/* 
On PROD environment development team will not have any access.
Application Team will have READ,WRITE,EXECUTE,SQL JOB access and view definition rights.
*/
	/* These AutoGrowth values and Roles are added to Model Database tobe set as default for all new database created on this server */


	SET @SQLCMD = 'USE [MSDB];IF NOT EXISTS(SELECT 1 FROM DBO.SYSUSERS WHERE NAME = ''DB_SUPPORT'' AND (ISSQLROLE = 1 OR ISAPPROLE = 1)) CREATE ROLE DB_SUPPORT AUTHORIZATION [dbo]'
	Execute(@SQLCMD)

	--SET @SQLCMD = 'USE [MSDB];ALTER ROLE SQLAgentOperatorRole ADD MEMBER DB_SUPPORT'
	SET @SQLCMD ='USE [MSDB]; EXEC sp_AddRoleMember ''SQLAgentOperatorRole'',''DB_SUPPORT'''
	Execute(@SQLCMD)

	CREATE TABLE ##DBLIST  (ID INT IDENTITY(1,1),DBNAME VARCHAR(MAX), DATAFILENAME VARCHAR(MAX), LOGFILENAME VARCHAR(MAX), DATAFILESIZE FLOAT,LOGFILESIZE FLOAT, DoesDeveloperRoleExists bit Default(0), DoesSupportRoleExists bit Default(0))

	INSERT INTO ##DBLIST (DBNAME)
	SELECT A.NAME FROM SYS.databases A WITH(NOLOCK)
	--INNER JOIN SYS.master_files B ON A.dbid = B.database_id
	WHERE A.NAME NOT IN ('master', 'msdb', 'tempdb','ReportServer','ReportServerTempDB','distribution')
	and state_desc = 'ONLINE'

	UPDATE ##DBLIST 
	SET LOGFILENAME = SYS.master_files.NAME, LOGFILESIZE = SYS.master_files.SIZE 		
	FROM SYS.master_files, ##DBLIST 
	WHERE SYS.MASTER_FILEs.database_id = DB_ID(dbname) AND FILE_ID = 2

	UPDATE ##DBLIST 
	SET DATAFILENAME = SYS.master_files.NAME, DATAFILESIZE = SYS.master_files.SIZE 		
	FROM SYS.master_files, ##DBLIST 
	WHERE SYS.MASTER_FILEs.database_id = DB_ID(dbname) AND FILE_ID = 1 


	EXEC sp_MSForEachDB 'Use [?]; UPDATE ##DBLIST 
	SET DoesDeveloperRoleExists = 1
	FROM [?].DBO.SYSUSERS 
	WHERE DBNAME = ''?'' AND NAME = ''DB_DEVELOPERS'' AND (ISSQLROLE = 1 OR ISAPPROLE = 1)'

	EXEC sp_MSForEachDB 'Use [?]; UPDATE ##DBLIST 
	SET DoesSupportRoleExists = 1
	FROM [?].DBO.SYSUSERS 
	WHERE DBNAME = ''?'' AND NAME = ''DB_SUPPORT'' AND (ISSQLROLE = 1 OR ISAPPROLE = 1)'

	SET @DBNAME = ''
	DECLARE @I INT = 1
	DECLARE @DATAFILENAME VARCHAR(1000)
	DECLARE @LOGFILENAME VARCHAR(1000)
	DECLARE @DATAFILESIZE FLOAT
	DECLARE @LOGFILESIZE FLOAT 
	DECLARE @DoesDeveloperRoleExists BIT
	DECLARE @DoesSupportRoleExists BIT

	WHILE @I <= (SELECT MAX(ID) FROM ##DBLIST)
	BEGIN
		SELECT @DBNAME = DBNAME, @DATAFILENAME = DATAFILENAME,
		@LOGFILENAME = LOGFILENAME, @DATAFILESIZE   = DATAFILESIZE,
		@LOGFILESIZE = LOGFILESIZE,@DoesDeveloperRoleExists = DoesDeveloperRoleExists,
		@DoesSupportRoleExists = DoesSupportRoleExists
		FROM ##DBLIST WHERE ID = @I
		 
 			-- Default Auto FileGrowthvalue FOR DATA FILE in  SELECTED Database
		IF  ((@DATAFILESIZE * 8.0 / 1024) < 200) 
			EXEC ('ALTER DATABASE [' + @DBNAME + '] MODIFY FILE ( NAME = N''' + @DATAFILENAME + ''', SIZE = 200MB , FILEGROWTH = 250MB)' )
--PRINT 'ALTER DATABASE [' + @DBNAME + '] MODIFY FILE ( NAME = N''' + @DATAFILENAME + ''', SIZE = 200MB , FILEGROWTH = 250MB)' 		
 			-- Default Auto FileGrowthvalue FOR LOG FILE in  SELECTED Database
		IF  ((@LOGFILESIZE * 8.0 / 1024) < 200) 
			EXEC ('ALTER DATABASE [' + @DBNAME + '] MODIFY FILE ( NAME = N''' + @LOGFILENAME + ''', SIZE = 200MB , FILEGROWTH = 250MB)') 		


				-- For Developer Group
			IF @DoesDeveloperRoleExists = 0
			BEGIN
				SET @SQLCMD = 'USE [' + @DBNAME + ']; CREATE ROLE DB_DEVELOPERS AUTHORIZATION [dbo]'
				Execute(@SQLCMD)
			END 

			IF @DoesDeveloperRoleExists = 0
			BEGIN
				SET @SQLCMD = 'USE [' + @DBNAME + '];CREATE ROLE DB_SUPPORT AUTHORIZATION [dbo]'
				Execute(@SQLCMD)

				SET @SQLCMD = 'USE [' + @DBNAME + ']; ALTER ROLE db_datareader ADD MEMBER DB_SUPPORT'
				SET @SQLCMD += ';GRANT EXECUTE TO DB_SUPPORT'
				SET @SQLCMD += ';GRANT View Definition TO DB_SUPPORT'  
				Execute(@SQLCMD)
			END 


		SET @I += 1
	END  -- END OF LOOP

	DROP TABLE ##DBLIST
End
go


CREATE PROCEDURE [SQLMantainence].[CreateDBRolesAndAutoGrowthForDevelopmentServer]
-- With Encryption
AS
Begin
	SET NOCOUNT ON
	DECLARE @SQLCMD varchar(1000)
	DECLARE @DBNAME VARCHAR(1000)
	
/* EXECUTE THIS PART ON development ENVIRONMENT ONLY */
/* 
On PROD environment development team will have db_owner rights
Application Team will have db_owner rights
*/
	/* These AutoGrowth values and Roles are added to Model Database tobe set as default for all new database created on this server */



	SET @SQLCMD = 'USE [MSDB];IF NOT EXISTS(SELECT 1 FROM DBO.SYSUSERS WHERE NAME = ''DB_SUPPORT'' AND (ISSQLROLE = 1 OR ISAPPROLE = 1)) CREATE ROLE DB_SUPPORT AUTHORIZATION [dbo]'
	Execute(@SQLCMD)

	--SET @SQLCMD = 'USE [MSDB];ALTER ROLE SQLAgentOperatorRole ADD MEMBER DB_SUPPORT'
	SET @SQLCMD ='USE [MSDB]; EXEC sp_AddRoleMember ''SQLAgentOperatorRole'',''DB_SUPPORT'''
	Execute(@SQLCMD)

	CREATE TABLE ##DBLIST  (ID INT IDENTITY(1,1),DBNAME VARCHAR(MAX), DATAFILENAME VARCHAR(MAX), LOGFILENAME VARCHAR(MAX), DATAFILESIZE FLOAT,LOGFILESIZE FLOAT, DoesDeveloperRoleExists bit Default(0), DoesSupportRoleExists bit Default(0))

	INSERT INTO ##DBLIST (DBNAME)
	SELECT A.NAME FROM SYS.databases A WITH(NOLOCK)
	--INNER JOIN SYS.master_files B ON A.dbid = B.database_id
	WHERE A.NAME NOT IN ('master', 'msdb', 'tempdb','ReportServer','ReportServerTempDB','distribution')
	and state_desc = 'ONLINE'

	UPDATE ##DBLIST 
	SET LOGFILENAME = SYS.master_files.NAME, LOGFILESIZE = SYS.master_files.SIZE 		
	FROM SYS.master_files, ##DBLIST 
	WHERE SYS.MASTER_FILEs.database_id = DB_ID(dbname) AND FILE_ID = 2

	UPDATE ##DBLIST 
	SET DATAFILENAME = SYS.master_files.NAME, DATAFILESIZE = SYS.master_files.SIZE 		
	FROM SYS.master_files, ##DBLIST 
	WHERE SYS.MASTER_FILEs.database_id = DB_ID(dbname) AND FILE_ID = 1 


	EXEC sp_MSForEachDB 'Use [?]; UPDATE ##DBLIST 
	SET DoesDeveloperRoleExists = 1
	FROM [?].DBO.SYSUSERS 
	WHERE DBNAME = ''?'' AND NAME = ''DB_DEVELOPERS'' AND (ISSQLROLE = 1 OR ISAPPROLE = 1)'

	EXEC sp_MSForEachDB 'Use [?]; UPDATE ##DBLIST 
	SET DoesSupportRoleExists = 1
	FROM [?].DBO.SYSUSERS 
	WHERE DBNAME = ''?'' AND NAME = ''DB_SUPPORT'' AND (ISSQLROLE = 1 OR ISAPPROLE = 1)'

	SET @DBNAME = ''
	DECLARE @I INT = 1
	DECLARE @DATAFILENAME VARCHAR(1000)
	DECLARE @LOGFILENAME VARCHAR(1000)
	DECLARE @DATAFILESIZE FLOAT
	DECLARE @LOGFILESIZE FLOAT 
	DECLARE @DoesDeveloperRoleExists BIT
	DECLARE @DoesSupportRoleExists BIT

	WHILE @I <= (SELECT MAX(ID) FROM ##DBLIST)
	BEGIN
		SELECT @DBNAME = DBNAME, @DATAFILENAME = DATAFILENAME,
		@LOGFILENAME = LOGFILENAME, @DATAFILESIZE   = DATAFILESIZE,
		@LOGFILESIZE = LOGFILESIZE,@DoesDeveloperRoleExists = DoesDeveloperRoleExists,
		@DoesSupportRoleExists = DoesSupportRoleExists
		FROM ##DBLIST WHERE ID = @I
		 
 			-- Default Auto FileGrowthvalue FOR DATA FILE in  SELECTED Database
		IF  ((@DATAFILESIZE * 8.0 / 1024) < 200) 
			EXEC ('ALTER DATABASE [' + @DBNAME + '] MODIFY FILE ( NAME = N''' + @DATAFILENAME + ''', SIZE = 200MB , FILEGROWTH = 250MB)' )
--PRINT 'ALTER DATABASE [' + @DBNAME + '] MODIFY FILE ( NAME = N''' + @DATAFILENAME + ''', SIZE = 200MB , FILEGROWTH = 250MB)' 		
 			-- Default Auto FileGrowthvalue FOR LOG FILE in  SELECTED Database
		IF  ((@LOGFILESIZE * 8.0 / 1024) < 200) 
			EXEC ('ALTER DATABASE [' + @DBNAME + '] MODIFY FILE ( NAME = N''' + @LOGFILENAME + ''', SIZE = 200MB , FILEGROWTH = 250MB)') 		


				-- For Developer Group
			IF @DoesDeveloperRoleExists = 0
			BEGIN
				SET @SQLCMD = 'USE [' + @DBNAME + ']; CREATE ROLE DB_DEVELOPERS AUTHORIZATION [dbo]'
				Execute(@SQLCMD)

				SET @SQLCMD = 'USE [' + @DBNAME + '];ALTER ROLE DB_OWNER ADD MEMBER DB_DEVELOPERS'
				Execute(@SQLCMD)
			END 

			IF @DoesDeveloperRoleExists = 0
			BEGIN
				SET @SQLCMD = 'USE [' + @DBNAME + '];CREATE ROLE DB_SUPPORT AUTHORIZATION [dbo]'
				Execute(@SQLCMD)

				SET @SQLCMD = 'USE [' + @DBNAME + '];ALTER ROLE DB_OWNER ADD MEMBER DB_SUPPORT'
				Execute(@SQLCMD)
			END 


		SET @I += 1
	END  -- END OF LOOP

	DROP TABLE ##DBLIST
End
go


CREATE Procedure [SQLMantainence].[CreateAdditinalFileGroupForADatabase]
@databaseName VARCHAR(1000) ,
@DBName_Verified BIT = 0
-- With Encryption
As
Begin
/*

EXECUTE THIS SCRIPT by selecting Appropriate DATABASE from SSMS or Any Tool

*/
SET NOCOUNT ON 

--DECLARE @databaseName VARCHAR(1000) 
DECLARE @PhysicalPath VARCHAR(MAX) 
--DECLARE @DBName_Verified BIT


----------------------------------------------------------------------------------
---Change this flag to 1 if db name in session is verified!!
--SELECT @DBName_Verified = 0
--SELECT @databaseName = DB_NAME()
----------------------------------------------------------------------------------

IF @DBName_Verified = 1
BEGIN

	IF @databaseName not in ('master','tempDB','model','msdb') 
	BEGIN

		SELECT  @PhysicalPath=substring(physical_name,1,charindex(reverse(left(reverse(physical_name), charindex('\', reverse(physical_name)) -1)),physical_name)-1) 
		FROM sys.database_files df inner join sys.filegroups f on df.data_space_id = f.data_space_id
		WHERE f.name = 'PRIMARY'

		IF EXISTS(SELECT 1 FROM sys.filegroups) --WHERE name = 'SECONDARY')  -- Will not work if already multiple filegroup exists for this database
		BEGIN
			SELECT 'Multiple FILEGROUPs for this database i.e. "'+@databaseName+ '" alerady Exists!!'
		END
		ELSE
		BEGIN
			BEGIN TRY
				EXEC('alter database '+@databaseName+' add filegroup [USERDATA]')

				EXEC ('ALTER DATABASE '+@databaseName + 
				' ADD FILE (
				NAME = '''+@databaseName+'_USERDATA'' ,
				FILENAME = '''+@PhysicalPath+@databaseName+'_USERDATA.ndf'',
				SIZE = 2GB,
				FILEGROWTH = 250MB
				)
				TO FILEGROUP [USERDATA]')

				EXEC('alter database '+@databaseName+' MODIFY FILEGROUP [USERDATA] DEFAULT')
			END TRY
			BEGIN CATCH
				SELECT 'Adding USERDATA Filegroup to '+@databaseName +'DATABASE is failed due to following error :'+ISNULL(ERROR_MESSAGE(),'')
			END CATCH
		END
	END
	ELSE
	BEGIN
		SELECT 'We are not supposed to alter system databases with this script! Please check your input!!'
	END
	END
ELSE
BEGIN 
	SELECT 'Please verify the DB name and change flag @DBName_Verified to 1'
END

END
GO


/****** Object:  StoredProcedure [SQLMantainence].[DeleteAllUsers]    Script Date: 07/30/2013 15:56:22 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- Accepts a database name and deletes all database users 
-- This script is used after database refresh from another server
-- This script to be used on target server to remove all source server users after database refresh is completed
-- [SQLMantainence].[DatabaseRefresh_DeleteAllUsersFromADatabase] '{Database Name}'
CREATE Procedure [SQLMantainence].[DatabaseRefresh_DeleteAllUsersFromADatabase] 
(
 @DatabaseName varchar(500)
)
AS

BEGIN

SET NOCOUNT ON

--DECLARE @DatabaseName VARCHAR(1000)
DECLARE @SQL NVARCHAR(1000)
DECLARE @CurrentUserName VARCHAR(1000)
DECLARE @iRow INT,@TotalRows INT
DECLARE @ListOfUsersInDatabase TABLE (ID INT,Username VARCHAR(1000))
DECLARE @ParmDefinition NVARCHAR(100)




BEGIN TRY    
	
	-- TO GET LIST OF Users present in given database
	INSERT INTO @ListOfUsersInDatabase
	EXEC ('SELECT RowNum = ROW_NUMBER() OVER(ORDER BY Name), Name  from '+@DatabaseName+'.sys.database_principals
	where type_desc <> ''database_role''
	and name not in (''dbo'',''guest'',''INFORMATION_SCHEMA'',''sys'')')

select * from @ListOfUsersInDatabase

	PRINT 'Used Database :'+@DatabaseName

	SELECT @TotalRows = Count(1) FROM @ListOfUsersInDatabase 
	
	IF  @TotalRows = 0 PRINT 'No users present!'
	
	SELECT @iRow = 1
	WHILE @iRow <= @TotalRows 
	BEGIN
  		SELECT @CurrentUserName = Username FROM @ListOfUsersInDatabase WHERE ID = @iRow
		
		PRINT CAST (@iRow AS VARCHAR)+') Deleting User : '+ @CurrentUserName 
		
		--Deletion of schema owned by user with same name
		SET @SQL = N'IF EXISTS (SELECT 1 FROM '+@DatabaseName+'.INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_OWNER = '''+@CurrentUserName+''' AND  SCHEMA_NAME = '''+@CurrentUserName+''')  BEGIN   Use [' +@DatabaseName+  ']; DROP SCHEMA ['+ @CurrentUserName+'] ; END'
		SET @ParmDefinition = N'@DatabaseName VARCHAR(100), @CurrentUserName varchar(1000)';

		EXECUTE sp_executesql @SQL, @ParmDefinition, @DatabaseName=@DatabaseName, @CurrentUserName=@CurrentUserName;
		
		--Deletion of user from selected database			
		SELECT @SQL =   'Use ' + QUOTENAME(@DatabaseName) +  '; DROP USER '+QUOTENAME(@CurrentUserName)
		
		EXEC (@SQL)

		PRINT 'User '+@CurrentUserName +' is deleted'

		

		SELECT @iRow += 1  
	END -- END OF WHILE LOOP
END TRY  
	
BEGIN CATCH
	IF ERROR_NUMBER() > 0	
	BEGIN
		PRINT 'User '+@CurrentUserName + ' Could not be deleted with error as '+ ERROR_MESSAGE()
	END
END CATCH

END
GO

USE [Sql_Admin]
GO

/****** Object:  StoredProcedure [SQLMantainence].[GetTotalSpaceofDrive]    Script Date: 5/28/2013 3:18:23 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [SQLMantainence].[GetTotalSpaceofDrive] 
(
 @BackupDrive VARCHAR(50),
 @TotalCapacity FLOAT OUTPUT 
) 
-- With Encryption
 AS
BEGIN 
	DECLARE @sql NVARCHAR(400) 

	--Powershell command to get drive's  information
	SET @sql = 'powershell.exe -c "Get-WmiObject -Class Win32_Volume -Filter ''DriveType = 3'' | SELECT name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1048576+''%''+$_.freespace/1048576+''*''}"' 

	-- Table Variable for storing disk information
	DECLARE  @output TABLE (Line VARCHAR(255)) 

	--Inserting disk name, total space and free space value into table variable 
	INSERT INTO @output (line)  EXECUTE xp_cmdshell @sql 

	--Script to retrieve the values FROM temporary table
	SELECT @TotalCapacity = capacityGB
		FROM (SELECT RTRIM(LTRIM(SUBSTRING(line,1,CHARINDEX('|',line) -1))) as BackupDrive 
		,ROUND(RTRIM(LTRIM(SUBSTRING(line,CHARINDEX('|',line)+1,(CHARINDEX('%',line) -1)-CHARINDEX('|',line)) )),2) as 'capacityGB' 
		FROM @output ) a
		WHERE a.BackupDrive LIKE @BackupDrive+'%'
END
GO

GO

/****** Object:  StoredProcedure [SQLMantainence].[GetFreeSpaceofDrive]    Script Date: 5/28/2013 3:17:49 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [SQLMantainence].[GetFreeSpaceofDrive] 
(
 @BackupDrive VARCHAR(50),
 @FreeSpace FLOAT OUTPUT 
) 
-- With Encryption
 AS
BEGIN 
	SET NOCOUNT ON

	DECLARE @sql NVARCHAR(4000) 

	--Powershell command to get drive's  information
	SET @sql = 'powershell.exe -c "Get-WmiObject -Class Win32_Volume -Filter ''DriveType = 3'' | SELECT name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1048576+''%''+$_.freespace/1048576+''*''}"' 

	-- Table Variable for storing disk information
	DECLARE  @output TABLE (Line VARCHAR(1000)) 

	--Inserting disk name, total space and free space value into table variable 
	INSERT INTO @output (Line) EXECUTE xp_cmdshell @sql 

	--Script to retrieve the values FROM temporary table
	SELECT  @FreeSpace = freespaceGB
		FROM ( SELECT RTRIM(LTRIM(SUBSTRING(line,1,CHARINDEX('|',line) -1))) as BackupDrive 
		,ROUND(RTRIM(LTRIM(SUBSTRING(line,CHARINDEX('%',line)+1,(CHARINDEX('*',line) -1)-CHARINDEX('%',line)) )),2) as 'freespaceGB'
		FROM @output ) a
		WHERE a.BackupDrive LIKE @BackupDrive+'%'
END
GO


USE [Sql_Admin]
GO

/****** Object:  StoredProcedure [SQLMantainence].[Monitor_ReplicationStatus]    Script Date: 05/20/2013 08:43:35 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [SQLMantainence].[Monitor_ReplicationStatus]
-- With Encryption
AS 
BEGIN 
SET NOCOUNT ON;

DECLARE @PublicationNAME NVARCHAR(2000)
DECLARE @SubscriberName NVARCHAR(2000)
DECLARE @COUNT SMALLINT
DECLARE @COUNTER SMALLINT
DECLARE @SUBJECT NVARCHAR(2000)
DECLARE @HTML_BODY NVARCHAR(MAX) = ''
DECLARE @ACTUAL_IP_ADDRESS VARCHAR(1000) 
DECLARE @EmailRecipient VARCHAR (2000)
DECLARE @ReplicationStatus INT 
DECLARE @SQLCMD NVARCHAR(MAX)
DECLARE @Replication_PublisherName nvarchar(1000)
DECLARE @SQLCMD2 NVARCHAR(MAX)
DECLARE @SubscriberStatus INT
DECLARE @COUNT_S SMALLINT

CREATE TABLE #temp1(SQL_IP VARCHAR(3000))
INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 
DECLARE @IPAddress VARCHAR(300) 
SET @IPADDRESS = (SELECT TOP 1 SQL_IP FROM #TEMP1  WITH(NOLOCK)  WHERE SQL_IP LIKE '%IPV4%' ORDER BY SQL_IP DESC) 
If @IPAddress IS NULL
	SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IP Address%' ORDER BY SQL_IP DESC) 	
	
SET @IPAddress = IsNull(@IPAddress,'')

DECLARE @len INT 
SET @Len = CHARINDEX(':', @IPAddress) 
SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPAddress, @Len+1, LEN(@IPAddress)))) 
DROP TABLE #temp1 

SET @COUNTER= 1

SELECT @Subject =  ' Replication Failure on Server:  ' + @@SERVERNAME + ' IP : ' + @ACTUAL_IP_ADDRESS
SELECT @EmailRecipient=VALUE FROM [SqlMantainence].DBMantainenceConfiguratiON WITH(NOLOCK)  WHERE configurationType='EmailRecipient'

SELECT @Replication_PublisherName=LTrim(RTrim(Value)) FROM  [Sql_Admin].SQLMantainence.DBMantainenceConfiguration WHERE configurationType='Replication_Publisher_Name'

Create table #tbl_Replication	(row_no int  identity(1,1), publisher sysname, distribution_db sysname, status int, warning int, publication_count int , returnstamp nvarchar(100))
		
Create table #tbl_SubscriberDetails (row_no int  identity(1,1),	status int ,warning int ,subscriber sysname,subscriber_db sysname,publisher_db sysname,publication sysname,
                                     publication_type int,subtype int ,latency int,latencythreshold int,agentnotrunning int,agentnotrunningthreshold int,timetoexpiration  int,
									 expirationthreshold int,last_distsync  datetime,distribution_agentname sysname,mergeagentname VARCHAR(100),mergesubscriptionfriENDlyname VARCHAR(100),
									 mergeagentlocation VARCHAR(100),mergeconnectiontype int,mergePerformance int,mergerunspeed float,mergerunduration int ,monitorranking int,distributionagentjobid binary(16),	
									 mergeagentjobid binary(16),	distributionagentid int,distributionagentprofileid int,mergeagentid int,mergeagentprofileid int,logreaderagentname sysname)
	
IF EXISTS(SELECT 1  FROM sys.databases WITH(NOLOCK) WHERE is_published = 1)  --- I.E. If this server is a publisher
BEGIN
	SET @SQLCMD='SELECT a.* FROM OPENROWSET(''MSDASQL'',''DRIVER={SQL Server}; SERVER='+@@SERVERNAME+';trusted_connection=yes'',
				''SET FMTONLY OFF Exec [SQL_Admin].[SQLMantainence].[Replication_Publisher_Details] '''''+@Replication_PublisherName+''''''')as a';


	Insert into #tbl_Replication EXECUTE sp_executesql  @SQLCMD

	--SELECT * FROM #tbl_Replication   ...DEBUG CODE
	SELECT @COUNT=COUNT(*) FROM #tbl_Replication
	
	SET @SQLCMD2='SELECT b.* FROM OPENROWSET(''MSDASQL'',''DRIVER={SQL Server}; SERVER='+@@SERVERNAME+';trusted_connection=yes'',
				''SET FMTONLY OFF Exec distribution.DBO.SP_ReplMonitorHelpSubscription @Publisher='''''+@Replication_PublisherName+''''',@publication_type=0, @mode = 0'')as b';

	INSERT INTO #tbl_SubscriberDetails EXECUTE sp_executesql @SQLCMD2
	--SELECT * FROM #tbl_SubscriberDetails  ...DEBUG CODE
	SELECT @COUNT_S=COUNT(*) FROM #tbl_SubscriberDetails

	WHILE(@COUNTER <=@COUNT)
	BEGIN

		SELECT @ReplicationStatus=status FROM #tbl_Replication WHERE ROW_NO=@COUNTER
		SELECT @PublicationNAME=publisher FROM #tbl_Replication WHERE ROW_NO=@COUNTER
	
		-- There are different status of Publisher i.e. 
		-- 1 = Started, 2 = Succeeded,3 = In progress,4 = Idle,5 = Retrying,6 = Failed
		IF(@ReplicationStatus=6)
			SET @HTML_BODY+='Replication for Publisher  '+@PublicationNAME+' is Failing  <br><br>'

		SET @COUNTER=@COUNTER+ 1 
	END


	SET @COUNTER= 1
	WHILE(@COUNTER <= @COUNT_S)
	BEGIN
		SELECT @SubscriberStatus=STATUS FROM #tbl_SubscriberDetails WHERE ROW_NO=@COUNTER
		SELECT @SubscriberName=subscriber FROM #tbl_SubscriberDetails WHERE ROW_NO=@COUNTER

		-- There are different status of Subscriber i.e. 
		-- 1 = Started, 2 = Succeeded,3 = In progress,4 = Idle,5 = Retrying,6 = Failed
		IF(@SubscriberStatus=6)
			SET @HTML_BODY+='Replication for Subscriber  '+@SubscriberName+' is Failing  <br><br>'
		
		SET @COUNTER=@COUNTER+ 1  
	END


	IF @HTML_BODY <> ''
	BEGIN
		EXECUTE msdb..sp_sEND_dbmail @profile_name = 'DBMaintenance', 
				@recipients = @EmailRecipient ,
				@subject =@subject, 
				@body_format= 'HTML',
				@body = @HTML_BODY, 
				@execute_query_database = 'SQL_Admin'
	END

END    --- End of  If this server is a publisher condition

END  
GO




USE [Sql_Admin]
GO
/****** Object:  StoredProcedure [dbo].[replication_publisher_details]    Script Date: 05/20/2013 11:25:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- This code should be EXECUTEd on valid SQL Replilcation server used as Publisher
CREATE procedure [SQLMantainence].[Replication_Publisher_Details]  --'AX-SQLPSC01-PRD\AXPROD'
(  
    @publisher sysname = NULL  -- pubisher - null means all publisher  
)  
-- With Encryption
as  
BEGIN  
SET nocount on  
DECLARE @distdb varchar(1000),@sqlcmd nvarchar(max) 

IF  (@publisher is not null)
BEGIN
	SELECT @distdb = distribution_db   FROM msdb..MSdistpublishers WITH(NOLOCK)  WHERE upper(name) = upper(@publisher) 
 	SET @distdb=quotename(@distdb)
 	SET @sqlcmd = 'EXECUTE  ' + @distdb + '..sp_replmonitorhelppublisher '''+@publisher+''''
	EXECUTE sp_EXECUTEsql   @sqlcmd
END  
END 
GO


USE [SQL_ADMIN]
GO
/****** Object:  StoredProcedure [SQLMantainence].[sp_ShrinkDatabase]    Script Date: 4/5/2013 7:24:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- **************************************************************
-- CHECKS FOR AUTO GROWTHS SINCE THE LAST AUTO GROWTH RECORDED BY THIS TOOL
--**************************************************************
CREATE PROCEDURE [SQLMantainence].[CheckDatabaseAutoGrowth] 
-- With Encryption
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		DECLARE @StartDate DateTime
		SELECT @StartDate = MAX(StartTime) FROM SQL_ADMIN.SQLMantainence.Audit_DatabaseAutoGrowth (NOLOCK)

		insert into SQL_ADMIN.SQLMantainence.Audit_DatabaseAutoGrowth

        SELECT A.StartTime, DB_NAME(A.databaseid)as DatabaseName, A.Filename, SUM ((A.IntegerData*8)/1024) AS [Growth in MB], (A.Duration/1000)as [Duration in seconds],
        Case B.GroupID When 0 Then 'Log' Else 'Rows' End as 'FileType'
        FROM ::fn_trace_gettable((SELECT path FROM sys.traces WHERE is_default = 1), default) A
        INNER JOIN  master.sys.sysaltfiles  B on A.FileName=B.name
        WHERE (EventClass = 92 OR EventClass = 93) --AND DatabaseName = 'tempdb'
        AND STARTTIME >  @StartDate 
        GROUP BY StartTime,Databaseid, A.Filename, IntegerData, Duration,B.GroupID
        ORDER BY StartTime         

	 END TRY

	 BEGIN CATCH   
	    PRINT  @@ERROR
	 END CATCH 
END
GO

USE [SQL_ADMIN]
GO
/****** Object:  StoredProcedure [SQLMantainence].[Monitor_MirroringStatus]    Script Date: 4/5/2013 7:12:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [SQLMantainence].[Monitor_MirroringStatus]
-- With Encryption
AS 
BEGIN 
SET NOCOUNT ON;

DECLARE @DATABASENAME NVarChar(2000)

DECLARE @COUNT SMALLINT
DECLARE @EMAILRECEPIENTS NVarChar(2000)
DECLARE @COUNTER SMALLINT
DECLARE @SUBJECT NVarChar(2000)
DECLARE @HTML_BODY NVarChar(MAX)
DECLARE @Mirroring_State VarChar(1000)
DECLARE @LogShippingStatus int
DECLARE @ACTUAL_IP_ADDRESS VarChar(1000) 
DECLARE @EmailRecipient VarChar (2000)
DECLARE @Monitor_Mirroring_Status INT

CREATE TABLE #temp1(SQL_IP VarChar(3000))
INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 
DECLARE @IPAddress VarChar(300) 
SET @IPADDRESS = (SELECT TOP 1 SQL_IP FROM #TEMP1  WITH(NOLOCK)  WHERE SQL_IP LIKE '%IPV4%' ORDER BY SQL_IP DESC) 
If @IPAddress IS NULL
	SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IP Address%' ORDER BY SQL_IP DESC) 	
	
SET @IPAddress = IsNull(@IPAddress,'')

DECLARE @len INT 
SET @Len = CHARINDEX(':', @IPAddress) 
SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPAddress, @Len+1, LEN(@IPAddress)))) 
DROP TABLE #temp1 
	
SELECT @Subject =  ' SQL Maintenance Disaster Recovery Plan Failure ON Server:  ' + @@SERVERNAME + ' IP : ' +@ACTUAL_IP_ADDRESS
SELECT @EmailRecipient=VALUE FROM [SqlMantainence].DBMantainenceConfiguratiON WITH(NOLOCK)  WHERE configurationType='EmailRecipient'
   

Create table #tbl_Mirroring
(
	Row_No int  identity(1,1),
	DatabaseName VarChar(2000),
	Mirroring_State VarChar(1000)
)

INSERT into #tbl_Mirroring(DatabaseName,Mirroring_State)(SELECT DB_NAME(database_id) AS 'DataBaseName' ,mirroring_state_desc AS 'Mirroring_State' FROM sys.database_mirroring WHERE mirroring_guid IS NOT NULL)
	 
SELECT @COUNT=COUNT(*) FROM #tbl_Mirroring
SET @COUNTER=1
SET @HTML_BODY=''

WHILE(@COUNTER <=@COUNT)
	BEGIN
	SELECT @Mirroring_State=Mirroring_State FROM #tbl_Mirroring WHERE ROW_NO=@COUNTER
	SELECT @DATABASENAME=DatabaseName FROM #tbl_Mirroring WHERE ROW_NO=@COUNTER
	IF(@Mirroring_State <> 'SYNCHRONIZED')
		BEGIN
		SET @HTML_BODY+='Mirroring fOR Database '+@DATABASENAME+' is in '+@Mirroring_State+' status <br>'
		END
	SET @COUNTER=@COUNTER+ 1 
	END 



IF @HTML_BODY <> ''
BEGIN
	EXECUTE msdb..sp_send_dbmail @profile_name = 'DBMaintenance', @recipients = @EmailRecipient ,
					@subject =@subject, 
					@body_format= 'HTML',
					@body = @HTML_BODY, 
					@execute_query_database = 'SQL_ADMIN'
END
END
GO


--*******************************************************************************
--   ... CREATING STORED PROCEDURE [Monitor_LogShippingStatus]
--*******************************************************************************

USE [SQL_ADMIN]
GO
/****** Object:  StoredProcedure [SQLMantainence].[Monitor_LogShippingStatus]    Script Date: 4/5/2013 7:13:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [SQLMantainence].[Monitor_LogShippingStatus]
-- With Encryption
AS 

BEGIN 
SET NOCOUNT ON;

DECLARE @DATABASENAME NVarChar(2000)
DECLARE @COUNT SMALLINT
DECLARE @EMAILRECEPIENTS NVarChar(2000)
DECLARE @COUNTER SMALLINT
DECLARE @SUBJECT NVarChar(2000)
DECLARE @HTML_BODY NVarChar(MAX)
DECLARE @ACTUAL_IP_ADDRESS VarChar(1000) 
DECLARE @EmailRecipient VarChar (2000)
DECLARE @Monitor_LogShipping_Status INT
DECLARE @LogShippingStatus BIT 

CREATE TABLE #temp1(SQL_IP VarChar(3000))
INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 
DECLARE @IPAddress VarChar(300) 
SET @IPADDRESS = (SELECT TOP 1 SQL_IP FROM #TEMP1  WITH(NOLOCK)  WHERE SQL_IP LIKE '%IPV4%' ORDER BY SQL_IP DESC) 
If @IPAddress IS NULL
	SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IP Address%' ORDER BY SQL_IP DESC) 	
	
SET @IPAddress = IsNull(@IPAddress,'')

DECLARE @len INT 
SET @Len = CHARINDEX(':', @IPAddress) 

SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPAddress, @Len+1, LEN(@IPAddress)))) 
DROP TABLE #temp1 
	
SELECT @Subject =  ' SQL Maintenance Disaster Recovery Plan Failure ON Server:  ' + @@SERVERNAME + ' IP : ' +@ACTUAL_IP_ADDRESS
SELECT @EmailRecipient=VALUE FROM [SqlMantainence].DBMantainenceConfiguratiON WITH(NOLOCK)  WHERE configurationType='EmailRecipient'
   

Create table #tbl_LogShipping
	(
	 Row_No int  identity(1,1),
	 status int ,
	 is_primary BIT ,
	 server nVarChar(max),
	 database_name VarChar(2000),
	 time_since_last_backup int ,
	 last_backup_file nVarChar(max),
	 backup_threshold VarChar(500),
	 is_backup_Alert_enabled int,
	 time_since_last_copy datetime,
	 last_copied_file VarChar(2000),
	 time_since_last_restore datetime,
	 last_restored_file VarChar(200),
	 last_restored_latency VarChar(500),
	 restore_threshold VarChar(500),
	 is_restore_alert_enabled int 
	  
	)

Insert into #tbl_LogShipping Exec sp_help_log_shipping_monitor

SELECT @COUNT=COUNT(*) FROM #tbl_LogShipping

WHILE(@COUNTER >=@COUNT)
BEGIN
	SELECT @LogShippingStatus=status FROM #tbl_LogShipping WHERE ROW_NO=@COUNTER
	SELECT @DATABASENAME=database_name FROM #tbl_LogShipping WHERE ROW_NO=@COUNTER
	IF(@LogShippingStatus=1)
		BEGIN
		SET @HTML_BODY+='Log-Shipping fOR Database '+@DATABASENAME+' is in Bad State <br><br>'
		END
	SET @COUNTER=@COUNTER+ 1 
END
END
GO

--*******************************************************************************
--   ... CREATING STORED PROCEDURE TrackDBSpaceUsage
--*******************************************************************************
USE [SQL_ADMIN]
GO
/****** Object:  StoredProcedure [SQLMantainence].[TrackDBSpaceUsage]    Script Date: 4/2/2013 6:50:54 PM ******/
SET ANSI_NULLS ON

GO

SET QUOTED_IDENTIFIER ON
GO


-- CHECKS FOR DATA FILE SIZE AND ALERTS IF SPACE AVAILABLE IS LESSER THAN THE THRESHOLD VALUE SET....TO CONTROL AUTO GROWTH
CREATE PROCEDURE [SQLMantainence].[TrackDBSpaceUsage]
-- With Encryption
AS 
BEGIN 
SET NOCOUNT ON;

DECLARE @DATABASENAME NVarChar(2000)
DECLARE @BACKUPPATH NVarChar(2000)
DECLARE @COUNT SMALLINT
DECLARE @EMAILRECEPIENTS NVarChar(2000)
DECLARE @COUNTER SMALLINT
DECLARE @SUBJECT NVarChar(2000)
DECLARE @HTML_BODY NVarChar(MAX)
DECLARE @BACKUPTIME DATETIME
DECLARE @CURRENTTIME DATETIME
DECLARE @BackupCheckFlag BIT
DECLARE @SQL VarChar(max) = ''
DECLARE @Threshold_DBSpaceUsageAlert int 
DECLARE @ACTUAL_IP_ADDRESS VarChar(1000)  
DECLARE @DATABASE_SPACEBelowThreshold VarChar(1000) 
DECLARE @Percent_Space_Available int 
DECLARE @FileType_Database VarChar(100)
DECLARE @Database_FileName VarChar(MAX)


SET @COUNTER=1
SET @CURRENTTIME=GETDATE()


CREATE TABLE #temp1(SQL_IP VarChar(3000))
	INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 
	DECLARE @IPAddress VarChar(300) 
	SET @IPADDRESS = (SELECT TOP 1 SQL_IP FROM #TEMP1  WITH(NOLOCK)  WHERE SQL_IP LIKE '%IPV4%' ORDER BY SQL_IP DESC) 
	If @IPAddress IS NULL
		SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IP Address%' ORDER BY SQL_IP DESC) 	
	
	SET @IPAddress = IsNull(@IPAddress,'')

	DECLARE @len INT 
	SET @Len = CHARINDEX(':', @IPAddress) 
	SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPAddress, @Len+1, LEN(@IPAddress)))) 
	DROP TABLE #temp1 


SELECT @Threshold_DBSpaceUsageAlert= 100 - VALUE FROM [SQL_ADMIN].SQLMantainence.DBMantainenceConfiguratiON WHERE ConfigurationType='ThresholdValueToGenerateSpaceUsageInDB'  
SELECT TOP 1 @EMAILRECEPIENTS= value FROM [SQL_ADMIN].SQLMantainence.DBMantainenceConfiguratiON WHERE ConfigurationType='EmailRecipient'
 --SELECT @COUNT
 
 --SELECT @Threshold_DBSpaceUsageAlert
CREATE TABLE #tbl_tmp
(
	 id int identity(1,1) ,
	 dbname VarChar(2000)
);


CREATE TABLE #tbl_DBSpaceChart
(
 row_no int identity(1,1),
 name VarChar(5000),
 TotalSpaceInMB decimal(11,2),
 UsedSpaceInMB decimal(11,2),
 FreeSpaceInMB decimal(11,2) ,
 Percentage_SpaceAvailable decimal(11,2),
 FileType VarChar(500),
 FileName VarChar(max)
 
);


INSERT INTO #tbl_tmp(dbname) (SELECT (value) FROM  [SQL_ADMIN].SQLMantainence.DBMantainenceConfiguratiON 
WHERE configurationtype='DBNameForTrackingSpaceUsage')

SELECT  @COUNT=COUNT(*) FROM #tbl_tmp

WHILE(@COUNTER <= @COUNT)
   BEGIN
	   IF EXISTS(SELECT 1 FROM Sys.SysDatabases WHERE Name = @DATABASENAME) 
	   BEGIN 
		   SELECT @DATABASENAME=dbname FROM #tbl_tmp WHERE ID=@COUNTER
		   SELECT @SQL = 'USE  ' +@databasename +';  insert into #tbl_DBSpaceChart (name,TotalSpaceInMB,UsedSpaceInMB,FreeSpaceInMB,Percentage_SpaceAvailable,FileType,FileName) 
				SELECT a.name,
				cast((a.size/128.0) as decimal(11,2)) as TotalSpaceInMB,
				cast((cast(fileproperty(a.name, ''SpaceUsed'') as decimal(11,2))/128.0) as decimal(11,2)) as UsedSpaceInMB,
				cast((a.size/128.0 - cast(fileproperty(a.name, ''SpaceUsed'') AS decimal(11,2))/128.0) as decimal(11,2)) as FreeSpaceInMB,
				(cast((cast(fileproperty(a.name, ''SpaceUsed'') as decimal(11,2))/128.0) as decimal(11,2)) * (100) /  cast((a.size/128.0) as decimal(11,2)))  as Percentage_SpaceAvailable,
				Case B.GroupID When 0 Then ''LOG FILE'' ELSE ''DATA FILE'' END as ''FileType'',
				a.physical_name as Filename 
			FROM  ' + @DATABASENAME + '.sys.database_files a INNER JOIN   master.sys.sysaltfiles b ON a.name=b.name'

			Exec (@SQL)
		END	
		SET @COUNTER=@COUNTER + 1
END
   
DECLARE @Start int =1
DECLARE @db_count int 

SELECT @db_count=count (*) FROM #tbl_DBSpaceChart WHERE Percentage_SpaceAvailable  < = @Threshold_DBSpaceUsageAlert
   
IF(@db_count <> 0)
      SET @HTML_BODY= '<HTML><BODY>Hi SQL Support Team , <BR><br>'
      SET @SUBJECT= 'SQL Server Database Growth Alert ON '+@ACTUAL_IP_ADDRESS
      
      
   WHILE(@start < = @db_count )
     BEGIN
      SELECT @DATABASE_SPACEBelowThreshold= NAME FROM  #tbl_DBSpaceChart WHERE  row_no=@start AND   Percentage_SpaceAvailable < = @Threshold_DBSpaceUsageAlert
      SELECT @Percent_Space_Available=Percentage_SpaceAvailable FROM #tbl_DBSpaceChart WHERE  row_no=@start AND   Percentage_SpaceAvailable < = @Threshold_DBSpaceUsageAlert
      SELECT @Database_FileName=FILENAME FROM  #tbl_DBSpaceChart WHERE  row_no=@start AND   Percentage_SpaceAvailable < = @Threshold_DBSpaceUsageAlert
      SELECT @FileType_Database= filetype  FROM #tbl_DBSpaceChart WHERE  row_no=@start AND   Percentage_SpaceAvailable < = @Threshold_DBSpaceUsageAlert

      IF(@FileType_Database='DATA FILE')
		  BEGIN
			SET @HTML_BODY += '<li>The space of Data file('+@Database_FileName+') fOR Database '+@DATABASE_SPACEBelowThreshold+' is currently only '+cast(@Percent_Space_Available as VarChar (50))+'  percent free  <br>   '
		   END
	   ELSE
		 BEGIN
		   SET @HTML_BODY += '<li>The space of  Log file('+@Database_FileName+') fOR Database '+@DATABASE_SPACEBelowThreshold+' is currently only '+cast(@Percent_Space_Available as VarChar(50))+'  percent free <br> '
		 END     

		SET @start=@start + 1
		INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'Database_Space_Alert','This is database space alert for database: '+@DATABASE_SPACEBelowThreshold+ ' ( '+ @FileType_Database + ' ) AND the  space left is only '+cast(@Percent_Space_Available as VarChar (50))+' percent of the total available space ','I');
	        
	 END
	     
     
   IF(@db_count <> 0)  
     SET @HTML_BODY += '<br>Please take necessary actiON to avoid auto growth ON above database files.</body></html>'  
      
  IF(@db_count <> 0) 
  BEGIN  
	EXECUTE msdb..sp_send_dbmail 
					@Profile_Name  =  'DBMaintenance', 
					@Recipients  = @EMAILRECEPIENTS,
					@Subject  = @SUBJECT,
					@Body_format =  'HTML',
					@Body  = @HTML_BODY,
					@Execute_Query_Database  =  'SQL_ADMIN'
					
   END
END
GO



SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[Get_Job_Day]') AND TYPE IN (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'/*
=============================================
Description:Procedure to get the day of Job Execution

DECLARE @Days_Of_Run VarChar(500)
EXEC [SQLMantainence].[Get_Job_Day] ''SQLMantainence_DiffBackup'',@Days_Of_Run OUTPUT
SELECT @Days_Of_Run
=============================================
*/
CREATE PROCEDURE [SQLMantainence].[Get_Job_Day]
(
 @JobName VarChar(400),
 @Days_Of_Run VarChar(500) OUTPUT
)
-- With Encryption
AS
BEGIN
	DECLARE  @jobid UNIQUEIDENTIFIER
	DECLARE @i INT 
	DECLARE @j INT
	DECLARE @enabled INT,
	@freq_type INT,
	@freq_interval INT, 
	@freq_subday_type INT,
	@freq_subday_interval INT ,
	@freq_relative_interval INT,
	@freq_recurrence_factOR INT,
	@active_start_date INT,
	@active_end_date INT, 
	@active_start_time INT,
	@active_end_time INT

	SELECT @jobid= job_id FROM msdb.dbo.sysjobs WITH(NOLOCK) WHERE name =@JobName

	CREATE TABLE #job_details (row_no INT IDENTITY(1,1), schedule_id INT ,schedule_name VarChar(500),[enabled] INT,freq_type INT,freq_interval INT, freq_subday_type INT,freq_subday_interval INT ,freq_relative_interval INT,freq_recurrence_factOR INT,active_start_date INT,active_end_date INT,
active_start_time INT,active_end_time INT,date_created DATETIME,schedule_descriptiON VarChar(1000),next_run_date INT,next_run_time INT, schedule_uid UNIQUEIDENTIFIER,job_count INT)

	INSERT #job_details EXEC MSDB.dbo.sp_help_jobschedule @jobid

	SELECT @j=1
	SELECT @i=MAX(row_no) FROM #job_details

	WHILE (@j <= @i)
	BEGIN
		SELECT @enabled= enabled FROM #job_details WITH(NOLOCK) WHERE row_no =@j
		SELECT @freq_type= freq_type FROM #job_details  WITH(NOLOCK) WHERE row_no =@j
		SELECT @freq_interval= freq_interval FROM #job_details  WITH(NOLOCK) WHERE row_no =@j
		SELECT @freq_subday_type=freq_subday_type  FROM #job_details  WITH(NOLOCK) WHERE row_no =@j
		SELECT @freq_subday_interval=freq_subday_interval  FROM #job_details  WITH(NOLOCK) WHERE row_no =@j
		SELECT @freq_relative_interval=freq_relative_interval  FROM #job_details  WITH(NOLOCK) WHERE row_no =@j
		SELECT @freq_recurrence_factor=freq_recurrence_factOR  FROM #job_details  WITH(NOLOCK) WHERE row_no =@j
		SELECT @active_start_date=active_start_date  FROM #job_details  WITH(NOLOCK) WHERE row_no =@j
		SELECT @active_end_date=active_end_date  FROM #job_details  WITH(NOLOCK) WHERE row_no =@j
		SELECT @active_start_time=active_start_time  FROM #job_details  WITH(NOLOCK) WHERE row_no =@j
		SELECT @active_end_time=active_end_time  FROM #job_details  WITH(NOLOCK) WHERE row_no =@j

		IF (@freq_type <> 4 AND @enabled=1)
		BEGIN 
			SELECT @Days_Of_Run= [SQL_ADMIN].[SQLMantainence].[udf_GetSchedule_DescriptionOfJob](@freq_type,@freq_interval,@freq_subday_type,@freq_subday_interval,@freq_relative_interval,@freq_recurrence_factor, @active_start_date,@active_end_date,@active_start_time,@active_end_time) 
		END 
 
		SET @j=@j + 1
	END

	DROP TABLE #job_details
END
' 
END
GO

-- Start of stored procedure DatabaseRefresh_ScriptDatabaseUsersBeforeRestore
USE [SQL_ADMIN]
GO
/****** Object:  StoredProcedure [SQLMantainence].[ScriptDatabaseUsersAfterDatabaseRefresh]    Script Date: 07/30/2013 16:57:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- This script will capture script to Re-Create All Logins In a Database
-- This script need to be run before database refresh happens ON any database, so that the same script can be executed again 
-- to give the same permissiON to the user.  e.g. IF a productiON database is migrated to dev database instance, all users of Dev will loose 
-- their permission.  in such scenario this script need to be executed ON Dev before the refresh.
CREATE PROCEDURE [SQLMantainence].[DatabaseRefresh_ScriptDatabaseUsersBeforeRestore]
	
AS
BEGIN
	SET NOCOUNT ON;
	
 PRINT '-- Target Server Name = ' + @@ServerName + ', Database Name: ' + DB_NAME()
       PRINT ''
       
       DECLARE @UID SMALLINT,
                     @SID VARCHAR(MAX),
                     @IsSQLUser INT,
                     @UserName VARCHAR(MAX),
                     @iTotalUsers INT,
                     @iCurrentUser INT,
                     @I INT 
       DECLARE  @tblAllUsers TABLE (ID INT IDENTITY (1,1), Name VARCHAR(MAX),UID SMALLINT, SID VARCHAR(MAX), IsSQLUser INT)
       DECLARE
              @errStatement [varchar](8000),
              @msgStatement [varchar](8000),
              @DatabaseUserID [smallint],
              @ServerUserName [sysname],
              @RoleName [varchar](8000),
              @ObjectID [int],
              @ObjectName [varchar](261)

       INSERT INTO @tblAllUsers 
              SELECT Name, UID, SID, IsSQLUser FROM SYS.SYSUSERS WHERE IsLogin = 1 AND HasDBAccess = 1 AND name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys')

       SELECT @iCurrentUser = 1, @iTotalUsers = COUNT(*) FROM @tblAllUsers
       
       WHILE @iCurrentUser  <= @iTotalUsers
       BEGIN

              SELECT @UID = uid , @SID = sid, @IsSQLUser = IsSQLUser, @UserName = Name  FROM @tblAllUsers WHERE ID = @iCurrentUser   
              
              Print ''
              Print '----------------------------------------------------------------------------------------------------'
              Print  '-- ' + cast(@iCurrentUser as varchar(100)) + '/' + cast(@iTotalUsers as varchar(100)) + ', User Name = ' +  @UserName
              Print '----------------------------------------------------------------------------------------------------'
       
              SELECT @DatabaseUserID = [sysusers].[uid], @ServerUserName = [master].[dbo].[syslogins].[loginname] 
              FROM [dbo].[sysusers] INNER JOIN [master].[dbo].[syslogins] ON [sysusers].[sid] = [master].[dbo].[syslogins].[sid]
              WHERE [sysusers].[name] = @UserName      
                     
              IF @DatabaseUserID IS NULL
              BEGIN
                     Print '-- ERR: Login does not exists OR may be Orphan user i.e. ' + @UserName 
              END
              ELSE
              BEGIN
                     Print  '--  Add User script for  ' + @ServerUserName 
                     Print  'USE [' + DB_NAME() + ']' 
                   --  Print 'EXEC [sp_grantdbaccess] ' + '@loginame = ''' + @ServerUserName + ''',' + '@name_in_db = ''' + @UserName + '''' 
			PRINT 'CREATE USER ['+@UserName + '] FOR LOGIN ['+ @ServerUserName +']'
                     Print 'GO' 
                     
                     DECLARE _sysusers CURSOR LOCAL FORWARD_ONLY READ_ONLY
                     FOR
                     SELECT [name] FROM [dbo].[sysusers] WHERE [uid] IN (SELECT    [groupuid]    FROM [dbo].[sysmembers] WHERE [memberuid] = @DatabaseUserID )
                     
                     Set @I = 0
                     OPEN _sysusers
                     FETCH NEXT FROM _sysusers INTO @RoleName 
                     WHILE @@FETCH_STATUS = 0
                     BEGIN
                           If @I = 0
                                  Print '--Add User To Roles' 
                           Print 'EXEC [sp_addrolemember] '  + '@rolename = ''' + @RoleName + ''',' + '@membername = ''' + @UserName + ''''
                           
                           Set @I += 1
                           FETCH NEXT FROM _sysusers INTO @RoleName                                   
                     END
                     CLOSE _sysusers
                     DEALLOCATE  _sysusers
                     If @I > 0 
                           Print 'Go'    
                     DECLARE _sysobjects CURSOR LOCAL FORWARD_ONLY READ_ONLY 
                     FOR
                     SELECT DISTINCT([sysobjects].[id]),'[' + USER_NAME([sysobjects].[uid]) + '].[' + [sysobjects].[name] + ']' 
                     FROM [dbo].[sysprotects] INNER JOIN [dbo].[sysobjects] ON [sysprotects].[id] = [sysobjects].[id] 
                     WHERE [sysprotects].[uid] = @DatabaseUserID
                     

                     SET @msgStatement = ''
                     SET @I = 0    
                     OPEN _sysobjects
                     FETCH NEXT FROM _sysobjects INTO @ObjectID,@ObjectName 
                     WHILE @@FETCH_STATUS = 0
                     BEGIN
                           If @I = 0
                                  Print '--Set Object Specific Permissions'

                           IF EXISTS(SELECT * FROM [dbo].[sysprotects] WHERE [id] = @ObjectID AND [uid] = @DatabaseUserID AND [action] = 193 AND [protecttype] = 205)
                           SET @msgStatement = @msgStatement + 'SELECT,'
                           IF EXISTS(SELECT * FROM [dbo].[sysprotects] WHERE [id] = @ObjectID AND [uid] = @DatabaseUserID AND [action] = 195 AND [protecttype] = 205)
                           SET @msgStatement = @msgStatement + 'INSERT,'
                           IF EXISTS(SELECT * FROM [dbo].[sysprotects] WHERE [id] = @ObjectID AND [uid] = @DatabaseUserID AND [action] = 197 AND [protecttype] = 205)
                           SET @msgStatement = @msgStatement + 'UPDATE,'
                           IF EXISTS(SELECT * FROM [dbo].[sysprotects] WHERE [id] = @ObjectID AND [uid] = @DatabaseUserID AND [action] = 196 AND [protecttype] = 205)
                           SET @msgStatement = @msgStatement + 'DELETE,'
                           IF EXISTS(SELECT * FROM [dbo].[sysprotects] WHERE [id] = @ObjectID AND [uid] = @DatabaseUserID AND [action] = 224 AND [protecttype] = 205)
                           SET @msgStatement = @msgStatement + 'EXECUTE,'
                           IF EXISTS(SELECT * FROM [dbo].[sysprotects] WHERE [id] = @ObjectID AND [uid] = @DatabaseUserID AND [action] = 26 AND [protecttype] = 205)
                            SET @msgStatement = @msgStatement + 'REFERENCES,'
                           IF LEN(@msgStatement) > 0
                           BEGIN
                                  IF RIGHT(@msgStatement, 1) = ','
                                         SET @msgStatement = LEFT(@msgStatement, LEN(@msgStatement) - 1)
                                  SET @msgStatement = 'GRANT' + CHAR(13) +
                                  CHAR(9) + @msgStatement + CHAR(13) +
                                  CHAR(9) + 'ON ' + @ObjectName + CHAR(13) +
                                  CHAR(9) + 'TO [' + @UserName +']'
                                  PRINT @msgStatement
                           END

                           SET @msgStatement = ''
                           IF EXISTS(SELECT * FROM [dbo].[sysprotects] WHERE [id] = @ObjectID AND [uid] = @DatabaseUserID AND [action] = 193 AND [protecttype] = 206)
                                  SET @msgStatement = @msgStatement + 'SELECT,'
                           IF EXISTS(SELECT * FROM [dbo].[sysprotects] WHERE [id] = @ObjectID AND [uid] = @DatabaseUserID AND [action] = 195 AND [protecttype] = 206)
                                  SET @msgStatement = @msgStatement + 'INSERT,'
                           IF EXISTS(SELECT * FROM [dbo].[sysprotects] WHERE [id] = @ObjectID AND [uid] = @DatabaseUserID AND [action] = 197 AND [protecttype] = 206)
                                  SET @msgStatement = @msgStatement + 'UPDATE,'
                           IF EXISTS(SELECT * FROM [dbo].[sysprotects] WHERE [id] = @ObjectID AND [uid] = @DatabaseUserID AND [action] = 196 AND [protecttype] = 206)
                                  SET @msgStatement = @msgStatement + 'DELETE,'
                           IF EXISTS(SELECT * FROM [dbo].[sysprotects] WHERE [id] = @ObjectID AND [uid] = @DatabaseUserID AND [action] = 224 AND [protecttype] = 206)
                                  SET @msgStatement = @msgStatement + 'EXECUTE,'
                           IF EXISTS(SELECT * FROM [dbo].[sysprotects] WHERE [id] = @ObjectID AND [uid] = @DatabaseUserID AND [action] = 26 AND [protecttype] = 206)
                                  SET @msgStatement = @msgStatement + 'REFERENCES,'

                           IF LEN(@msgStatement) > 0
                           BEGIN
                                  IF RIGHT(@msgStatement, 1) = ','
                                  SET @msgStatement = LEFT(@msgStatement, LEN(@msgStatement) - 1)
                                  SET @msgStatement = 'DENY' + CHAR(13) +
                                  CHAR(9) + @msgStatement + CHAR(13) +
                                  CHAR(9) + 'ON ' + @ObjectName + CHAR(13) +
                                  CHAR(9) + 'TO [' + @UserName +']'
                                  PRINT @msgStatement
                           END

                           SET @I += 1
                           FETCH NEXT FROM _sysobjects INTO @ObjectID, @ObjectName 
                     END  -- End of cursor loop
                     
                     If @I > 0 
                           Print 'GO'
                     CLOSE _sysobjects
                     DEALLOCATE _sysobjects
              
              
                     
              END  -- end of else part of if condition 
   
              SET @iCurrentUser += 1
END  -- end of while 
END
GO
-- end of stored procedure DatabaseRefresh_ScriptDatabaseUsersBeforeRestore



/****** Object:  StoredProcedure [SQLMantainence].[CreateLinkedServer]    Script Date: 11/23/2012 19:32:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[CreateLinkedServer]') AND TYPE IN (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'
-- Exec Deployment.CreateLinkedServer ''172.20.0.7''
-- Exec master.dbo.sp_dropserver  ''ServerForDeployment'', ''droplogins''
Create PROCEDURE [SQLMantainence].[CreateLinkedServer]
	@ServerName VarChar(1000)
-- With Encryption


AS
BEGIN
	SET NOCOUNT ON;

	EXEC sp_addlinkedserver
	   @server=''ServerForDeployment'', --//Logical name given to the linked server.
	   @srvproduct=''Linked Server created fOR deploying SQL maintenance tool'', --//optional . Just fOR description
	   @provider=''SQLOLEDB'', --//OLEDB Provider name, check BOL fOR more providers
	   @datasrc=@ServerName, --//actual remote server name-Backup Server connection
	   @catalog=''SQL_ADMIN'' --//default database fOR this linked server--Backup Server database
	   
	EXEC sp_serveroptiON ''ServerForDeployment'', ''data access'', ''true'' --Enables AND disables a linked server fOR distributed query access
	EXEC sp_serveroptiON ''ServerForDeployment'', ''rpc'', ''true'' --//Enables RPC FROM the given server.
	EXEC sp_serveroptiON ''ServerForDeployment'', ''rpc out'', ''true'' --//Enables RPC to the given server (required to call SP using Linked Server).
	EXEC sp_serveroptiON ''ServerForDeployment'', ''collatiON compatible'', ''true''



	EXEC sp_addlinkedsrvlogin
	   @useself=''false'', --//false means we are going to USE remote login/password
						--//true means USE local login/password to connect to remote machine (IF local login/password does not match ON remote machine then will fail)                     
	   @rmtsrvname=''ServerForDeployment'', --//Exising Linked server name
	   @rmtuser=''SA'' , --//remote login
	   @rmtpassword=''n0S0up4U2day'' --//remote login''s password
END
' 
END
GO
/****** Object:  StoredProcedure [SQLMantainence].[CreateAllServerTrigger]    Script Date: 11/23/2012 19:32:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[CreateAllServerTrigger]') AND TYPE IN (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [SQLMantainence].[CreateAllServerTrigger]
-- With Encryption
AS
BEGIN
SET NoCount On
 /* 
Create table master.dbo.PermissionAudit (eventtime datetime default getdate(), eventtype nVarChar (100), serverLogin nVarChar(100) not null,DBUser nVarChar (100) not null,TSQLText VarChar (max), eventdata xml not null)

Create TRIGGER PermissionAudit
ON All Server
FOR CREATE_LOGIN,ALTER_LOGIN, DROP_LOGIN, ALTER_AUTHORIZATION_SERVER,
    GRANT_SERVER,DENY_SERVER, REVOKE_SERVER,
    GRANT_DATABASE, DENY_DATABASE, REVOKE_DATABASE, CREATE_ROLE, ALTER_ROLE, DROP_ROLE ,
    CREATE_DATABASE, ALTER_DATABASE, DROP_DATABASE,CREATE_SCHEMA, ALTER_SCHEMA, DROP_SCHEMA,
    CREATE_USER,  ALTER_USER, DROP_USER, ADD_ROLE_MEMBER, DROP_ROLE_MEMBER, ADD_SERVER_ROLE_MEMBER 
    
AS
Begin
      DECLARE @Eventdata XML
      SET @Eventdata = EVENTDATA()

      IF  EXISTS(SELECT 1 FROM master.information_schema.tables WHERE table_name = ''PermissionAudit'')
      Begin
		  INSERT into master.dbo.PermissionAudit
				(EventType,EventData, ServerLogin,DBUser,TSQLText)
				VALUES (@Eventdata.value(''(/EVENT_INSTANCE/EventType)[1]'', ''nVarChar(100)''),
					  @Eventdata, system_USER,CONVERT(nVarChar(100), CURRENT_USER),
					  @Eventdata.value(''(/EVENT_INSTANCE/TSQLCommand)[1]'', ''nVarChar(2000)'' ))
      End
END                  


Enable trigger PermissionAudit ON all server 
Disable trigger permissionAudit ON all server
drop trigger PermissionAudit ON all server
drop table  master.dbo.PermissionAudit

SELECT * FROM master.dbo.PermissionAudit ORDER BY 1 desc
*/ 
END
' 
END
GO


--- ****************************************
-- Start of MonitoringAlerts4_DailyOnce Stored Procedure
---*****************************************
USE [SQL_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
THIS STORED PROCEDURE CHECKS THE SERVER EVERY 1 hours AND REPORTS ANY ISSUES.  FOLLOWING CHECKS ARE DONE BY THIS JOB
- 1. Alert on critical error found in the Eventviewer of this server
- 2. IF Deadlock check in enabled then the system Gernerate alerts fOR any deadlocks ON this server in last 5 minutes

*/
CREATE  PROCEDURE [SQLMantainence].[MonitoringAlerts4_DailyOnce] 
-- With Encryption
AS
BEGIN
	SET NOCOUNT ON;	
	
	DECLARE @intErrOR INT
    DECLARE @strErrorMesssage VarChar(MAX) = ''
	DECLARE @cmd VarChar(8000) = ''	
	DECLARE @ACTUAL_IP_ADDRESS VarChar(1000) 
	DECLARE @StartDate DATETIME  = DATEADD(MINUTE,(-1 * (60*24)), GETDATE())    -- Last 24 Hours

	DECLARE @SQLcmd VarChar(1000)
	 DECLARE @queriesInvolved varchar(8000)
	 
	  -- THIS SCRIPT BELOW IS TO DETECT THE IP ADDRESS OF THIS MACHINE FOR REPORTING PURPOSE I.E. USED IN EMAIL SUBJECT
	CREATE TABLE #temp1(SQL_IP VarChar(3000))
	INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 	
	DECLARE @IPAddress VarChar(300) 
	SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IPv4%' ORDER BY SQL_IP DESC) 	
	DECLARE @len INT 
	SET @Len = CHARINDEX(':', @IPAddress) 
	SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPAddress, @Len+1, LEN(@IPAddress)))) 
	DROP TABLE #temp1
	
    DECLARE @ERRORMESSAGE VarChar(MAX) ,
		@FormattedErrorMessage  VarChar(MAX),
		@ErrorNumber VarChar(50),
		@ErrorSeverity VarChar(50),
		@ErrorState  VarChar(50),
		@ErrorLine  VarChar(50),
		@ErrorProcedure  VarChar(200)	
	DECLARE @Environment VarChar (50), @EnvironmentDesc VarChar (50)
	DECLARE @Subject VarChar(1000)
	DECLARE @Recipients VarChar(2000)
	DECLARE @Msg varchar(8000)
	DECLARE @Enable_TempDB_contention_alerts BIT

    
    BEGIN TRY 
 	
		SELECT TOP 1  @Environment = [VALUE]  FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='Environment'
		SELECT TOP 1 @EnvironmentDesc = CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END
		SELECT  @Subject = UPPER(@EnvironmentDesc) + ' - SQL Server monitoring alert ON server ' + @@SERVERNAME + '( IP Address: ' + @ACTUAL_IP_ADDRESS + ')'
		SELECT TOP 1  @Recipients = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='EmailRecipient'

		SELECT  TOP 1 @Enable_TempDB_contention_alerts = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='Enable_TempDB_contention_alerts'	
		IF  ISNUMERIC(@Enable_TempDB_contention_alerts) = 0 -- IF FALSE
			SELECT @Enable_TempDB_contention_alerts = '0'

		--******************************************************************************
			-- Checking for any critical error in EVentViewer since last monitoring
			-- ********************************************************************

			Declare @tblEventLogsForSQLApplication TABLE (Message varchar(2000))
			SELECT @SQLcmd = 'powershell -C "get-eventLog -logname application -Source "*" -Entrytype error  -After '''+CONVERT(VARCHAR,@StartDate,100) +''' | Format-Table -WRap -Auto TimeGenerated, message "'

			INSERT INTO @tblEventLogsForSQLApplication (message) Execute xp_cmdshell @SQLcmd
			DELETE FROM @tblEventLogsForSQLApplication WHERE (Message is NULL OR Left(Message,Len('TimeGenerated       Message')) = 'TimeGenerated       Message'  OR Left(Message,Len('-------------       ------- ')) = '-------------       ------- ')

				-- SEND EMAIL FOR WRITES ABOVE 20 MS
			IF EXISTS(SELECT TOP 1 1 FROM @tblEventLogsForSQLApplication) 
			BEGIN
				SET @strErrorMesssage += '<BR><HTML><BODY><B>Critical errors captured from Eventviewer on this server (since last monitoring):</B><TABLE border=1>'
				SET @strErrorMesssage += '<tr><td>Error Details</td></tr>' 

				SELECT @strErrorMesssage += '<tr><td>'  + IsNull(Message,'') + '</td></tr>'		
				FROM @tblEventLogsForSQLApplication 

				--select * FROM @tblEventLogsForSQLApplication 
			END	
			--print @strErrorMesssage


		--********************************************************************************************************************
		-- 2. IF Deadlock check in enabled then the system Gernerate alerts fOR any deadlocks ON this server in last 30 minutes
		-- DBCC TRACEON (3605,1204,1222,-1)  ...these 3 flags need to be enabled fOR deadlock detection
		-- *******************************************************************************************************************		


		DECLARE @Total int=0
        DECLARE @iRow INT  =1
		DECLARE @text nvarchar(max)
		DECLARE @CheckForDeadLocks	 VarChar(100)
		SELECT @CheckForDeadLocks	 = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='CheckDeadLocksOnServer'
		IF  ISNUMERIC(@CheckForDeadLocks) = 0 -- IF FALSE
			SELECT @CheckForDeadLocks = '0'
		
		IF (@CheckForDeadLocks ='1')
		 BEGIN		    
			SET @SQLcmd = 'master.dbo.xp_readerrorlog 0, 1, N''Deadlock encountered'',null, ''' + REPLACE(CONVERT(VarChar(100),@StartDate,126),'T',' ') + ''',  ''' + REPLACE(CONVERT(VarChar(100),GETDATE(),126),'T',' ')  + ''', N''asc''' 

			CREATE TABLE #tmp (LogDate DATETIME, ProcessInfo VarChar(100), TEXT VarChar(MAX)) 
			CREATE TABLE #tempDeadLockDetails (LogDate DATETIME, ProcessInfo VarChar(100), TEXT VarChar(MAX),row_no int  identity(1,1)) 
			INSERT INTO #tempDeadLockDetails  EXEC (@sqlcmd)

			--SELECT * FROM #tempDeadLockDetails   -- DEBUG CODE TO BE REMOVED LATER

			IF EXISTS(SELECT TOP 1 1 FROM #tempDeadLockDetails WITH(NOLOCK))
			BEGIN

				DECLARE @sDate DATETIME, @eDate DATETIME 
				DECLARE @sDateDesc VarChar(100), @eDateDesc VarChar(100) 
				
				SELECT @strErrorMesssage +=  '<br><li> Deadlock encountered on SQL Server: ' + @@SERVERNAME + ' at ' 
				+ CAST(@StartDate AS VarChar(100)) 
				
			SET @strErrorMesssage +='<br><br><li><font color=RED><u>The Details of this Dead-Lock are as below:</u></font><BR><br><table border=''1''><tr><td><b>Logdate</b></td><td><b>Text</b></td> </tr>'	
				Declare @URL varchar(1000)

			Declare @iTotalRow int
			SET @iTotalRow = (SELECT MAX(row_no) FROM #tempDeadLockDetails WITH(NOLOCK) )
			   WHILE (@iRow <= @iTotalRow)
			       BEGIN

				   	SELECT TOP 1 @sDate = LogDate, @eDate = DATEADD(MINUTE,2,LogDate) 
					FROM #tempDeadLockDetails WITH(NOLOCK) 
					WHERE row_no = @iRow

				    SELECT @sDateDesc = CAST(YEAR(@sDate) AS VarChar(10)) + '-' + RIGHT('0' + CAST(MONTH(@sDate) AS VarChar(10)),2) + '-' + RIGHT('0' + CAST(DAY(@sDate) AS VarChar(10)),2) + ' ' + RIGHT('0' + CAST(DATEPART(HOUR,@sDate) AS VarChar(10)),2) +':' + RIGHT('0' + CAST(DATEPART(MINUTE,@sDate) AS VarChar(10)),2) + ':' +RIGHT('0' + CAST(DATEPART(second,@sDate) AS VarChar(10)),2)
				    
					SELECT @eDateDesc = CAST(YEAR(@eDate) AS VarChar(10)) + '-' + RIGHT('0' + CAST(MONTH(@eDate) AS VarChar(10)),2) + '-' + RIGHT('0' + CAST(DAY(@eDate) AS VarChar(10)),2) + ' ' + RIGHT('0' + CAST(DATEPART(HOUR,@eDate) AS VarChar(10)),2) +':' + RIGHT('0' + CAST(DATEPART(MINUTE,@eDate) AS VarChar(10)),2) + ':00'

					Truncate Table #tmp
					SET @URL = 'master.dbo.xp_readerrorlog 0, 1,null,null,''' + @sDateDesc + ''',''' + @eDateDesc + ''',N''asc'' '
					INSERT INTO #tmp  Exec( @URL)

					SET @TEXT = ''
					
					Select @text += '<br>' + isnull([text],'') 
					FROM #TMP  WITH(NOLOCK)
					WHERE (IsNUll([TEXT],'') like '%INSERT INTO%' OR IsNUll([TEXT],'') like '%UPDATE %' or IsNUll([TEXT],'') like '%DELETE FROM%' OR IsNUll([TEXT],'') like '%select %')

					SELECT @strErrorMesssage +='<tr valign=''top''><td >' + IsNull(@sDateDesc,'') +'</td><td><small><i><small>'+@Text+'</small></i></small></td></tr>'  

						IF  OBJECT_ID('SQLMantainence.Deadlock Details on this SQL Server') IS NULL
						BEGIN
									CREATE TABLE [SQLMantainence].[Deadlock Details on this SQL Server](
								[Id] [int] IDENTITY(1,1) NOT NULL,
								[DeadlockEventTime] [datetime] NOT NULL,
								[TablesInvolved] [varchar](max) NULL,
								[QueryInvolved] [varchar](max) NULL,
								[Remarks] [varchar](max) NULL,
							 CONSTRAINT [PK_Deadlock Details on AX SQL Server] PRIMARY KEY CLUSTERED 
							(
								[Id] ASC
							)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
							) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
						END

						-- This table will capture all queries involved with deadlock
						select @queriesInvolved = ''
						Select @queriesInvolved += char(10) + char(13) + '=> ' + isnull([text],'') 
						FROM #TMP WITH(NOLOCK)
						WHERE (IsNUll([TEXT],'') like '%INSERT INTO%' OR IsNUll([TEXT],'') like '%UPDATE %' or IsNUll([TEXT],'') like '%DELETE FROM%' OR IsNUll([TEXT],'') like '%select %')

							
						INSERT INTO [SQLMantainence].[Deadlock Details on this SQL Server] 
							([DeadlockEventTime],[Remarks],[QueryInvolved]) 
							VALUES (@sDate,'deadlock encountered',@queriesInvolved)

					SELECT @iRow += 1
				END				

				INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'CheckDeadLocksOnServer','Deadlock encountered on SQL Server: ' + @@SERVERNAME + ' at ' + CAST(@sDate AS VarChar(100)),'I')
			END
			DROP TABLE #tempDeadLockDetails
			Drop Table #tmp
		 END	 

		--**************************************************************
		--END OF MONITORING SCRIPT
		--**************************************************************

	END TRY
 
	BEGIN CATCH
		INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'MONITORING-ALERTS','Monitoring Alerts job failed, ErrOR Message: ' + ERROR_MESSAGE() ,'C');
		EXEC [SQLMantainence].[Log_Error] 'MonitoringAlerts','MONITORING-ALERTS'
	END CATCH 


	IF @strErrorMesssage <> ''
	BEGIN
		DECLARE @Body VarChar(MAX)
		SET @Body  =  @strErrorMesssage + '</body></html>'
	
		EXECUTE msdb..sp_send_dbmail 
		@Profile_Name = 'DBMaintenance', 
		@Recipients = @Recipients ,    
		@Subject = @Subject,
		@Body_Format= 'HTML',
		@Body = @Body, 
		@Execute_Query_Database = 'SQL_ADMIN'	
	END         

END
go
-- ************************************* end of daily monitoring stored procedure

--- ****************************************
-- Start of MonitoringAlerts2_Hourly Stored Procedure
---*****************************************
USE [Sql_Admin]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
THIS STORED PROCEDURE CHECKS THE SERVER EVERY 1 hours AND REPORTS ANY ISSUES.  FOLLOWING CHECKS ARE DONE BY THIS JOB
- 1. Checks the TempDB Read/Write Statistics and stores in table SQLMantainence.TempDB_ReadWrite_HourlyStatistics
*/
CREATE PROCEDURE [SQLMantainence].[MonitoringAlerts3_Hourly] 
-- With Encryption
AS
BEGIN
	SET NOCOUNT ON;	
	
	DECLARE @intErrOR INT
    DECLARE @strErrorMesssage VarChar(MAX) = ''
	DECLARE @cmd VarChar(8000) = ''	
	DECLARE @ACTUAL_IP_ADDRESS VarChar(1000) 
	DECLARE @StartDate DATETIME  = DATEADD(MINUTE,-60, GETDATE())	
	DECLARE @SQLcmd VarChar(1000)
	 
	 
	  -- THIS SCRIPT BELOW IS TO DETECT THE IP ADDRESS OF THIS MACHINE FOR REPORTING PURPOSE I.E. USED IN EMAIL SUBJECT
	CREATE TABLE #temp1(SQL_IP VarChar(3000))
	INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 	
	DECLARE @IPAddress VarChar(300) 
	SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IPv4%' ORDER BY SQL_IP DESC) 	
	DECLARE @len INT 
	SET @Len = CHARINDEX(':', @IPAddress) 
	SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPAddress, @Len+1, LEN(@IPAddress)))) 
	DROP TABLE #temp1
	
    DECLARE @ERRORMESSAGE VarChar(MAX) ,
		@FormattedErrorMessage  VarChar(MAX),
		@ErrorNumber VarChar(50),
		@ErrorSeverity VarChar(50),
		@ErrorState  VarChar(50),
		@ErrorLine  VarChar(50),
		@ErrorProcedure  VarChar(200)	
	DECLARE @Environment VarChar (50), @EnvironmentDesc VarChar (50)
	DECLARE @Subject VarChar(1000)
	DECLARE @Recipients VarChar(2000)
	DECLARE @Msg varchar(8000)
	DECLARE @Enable_TempDB_contention_alerts BIT

    
    BEGIN TRY 
 	
		SELECT TOP 1  @Environment = [VALUE]  FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='Environment'
		SELECT TOP 1 @EnvironmentDesc = CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END
		SELECT  @Subject = UPPER(@EnvironmentDesc) + ' - SQL Server monitoring alert ON server ' + @@SERVERNAME + '( IP Address: ' + @ACTUAL_IP_ADDRESS + ')'
		SELECT TOP 1  @Recipients = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='EmailRecipient'

		SELECT  TOP 1 @Enable_TempDB_contention_alerts = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='Enable_TempDB_contention_alerts'	
		IF  ISNUMERIC(@Enable_TempDB_contention_alerts) = 0 -- IF FALSE
			SELECT @Enable_TempDB_contention_alerts = '0'

			IF OBJECT_ID('CalculateTempDBReadWriteForHour') IS NULL
			BEGIN
				EXECUTE ('
				CREATE FUNCTION [dbo].CalculateTempDBReadWriteForHour(@RW char(1), @ID INT, @CurrentValue BIGINT, @CurrentMonitoringTime DateTime, @physical_name nvarchar(260) )
				RETURNS NUMERIC(9,2)
				AS
				BEGIN
					DECLARE @Result NUMERIC(9,2)
					DECLARE @PreviousValue NUMERIC(9,2)
					DECLARE @PreviousID INT
					DECLARE @PreviousMonitoringTime DateTime

					SELECT TOP 1 @PreviousID = RefID  
					FROM  [SQLMantainence].[TempDB_ReadWrite_HourlyStatistics]  WITH(NOLOCK) 
					WHERE RefID < @ID AND physical_name = @physical_name
					ORDER BY RefID DESC

					IF @RW = ''R'' 
					BEGIN
						SELECT @PreviousValue = num_of_reads FROM  SQLMantainence.TempDB_ReadWrite_HourlyStatistics WITH(NOLOCK) WHERE RefID = @PreviousID  AND physical_name = @physical_name
						SET  @Result = IsNull(@CurrentValue,0) - IsNull( @PreviousValue,0)
					END
					ELSE IF @RW = ''W''  
						BEGIN
							SELECT @PreviousValue = num_of_writes FROM  SQLMantainence.TempDB_ReadWrite_HourlyStatistics WITH(NOLOCK)  WHERE RefID = @PreviousID AND physical_name = @physical_name
								SET  @Result = IsNull(@CurrentValue,0) - IsNull( @PreviousValue,0)
						END
					ELSE  -- IF TIME DIFFERENCE
						BEGIN
							SELECT @PreviousMonitoringTime = RefDate FROM  SQLMantainence.TempDB_ReadWrite_HourlyStatistics WITH(NOLOCK)  WHERE RefID = @PreviousID AND physical_name = @physical_name
							SET @Result = (Cast(DateDiff(MINUTE,@PreviousMonitoringTime, @CurrentMonitoringTime) as NUMERIC(9,2))) / 60
						END

					RETURN @Result
				 END;
	')
			END			
			
			IF OBJECT_ID('SQLMANTAINENCE.TEMPDB_READWRITE_HOURLYSTATISTICS') IS NULL
			BEGIN
				EXECUTE ('
						CREATE TABLE [SQLMantainence].[TempDB_ReadWrite_HourlyStatistics](
							[RefID] [int] IDENTITY(1,1) NOT NULL,
							[RefDate] [datetime] NOT NULL CONSTRAINT [DF_TempDB_ReadWrite_HourlyStatistics_RefDate]  DEFAULT (getdate()),
							[physical_name] [nvarchar](260) NOT NULL,
							[name] [sysname] NOT NULL,
							[num_of_writes] [bigint] NOT NULL,
							[avg_write_stall_ms] [numeric](38, 17) NULL,
							[num_of_reads] [bigint] NOT NULL,
							[avg_read_stall_ms] [numeric](38, 17) NULL,
							[TimeSinceLastCheck_InHrs]  AS ([dbo].[CalculateTempDBReadWriteForHour](''T'',[RefID],(0),[RefDate],[Physical_Name])),
							[NoOfReads_SinceLastCheck]  AS ([dbo].[CalculateTempDBReadWriteForHour](''R'',[RefID],[num_of_reads],[RefDate],[Physical_Name])),
							[NoOfWrites_SinceLastCheck]  AS ([dbo].[CalculateTempDBReadWriteForHour](''W'',[RefID],[num_of_writes],[RefDate],[Physical_Name])),
						 CONSTRAINT [PK_TempDB_ReadWrite_HourlyStatistics] PRIMARY KEY CLUSTERED 
						(
							[RefID] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY];
				
				
				')
			END


			SELECT FILES.PHYSICAL_NAME, FILES.NAME, STATS.NUM_OF_WRITES, (1.0 * STATS.IO_STALL_WRITE_MS / STATS.NUM_OF_WRITES) AS AVG_WRITE_STALL_MS,
				  STATS.NUM_OF_READS, (1.0 * STATS.IO_STALL_READ_MS / STATS.NUM_OF_READS) AS AVG_READ_STALL_MS
			INTO #tmpTempDB
			FROM SYS.DM_IO_VIRTUAL_FILE_STATS(2, NULL) AS STATS
			INNER JOIN MASTER.SYS.MASTER_FILES  AS FILES ON STATS.DATABASE_ID = FILES.DATABASE_ID   AND STATS.FILE_ID = FILES.FILE_ID
			WHERE FILES.TYPE_DESC = 'ROWS'

			ALTER TABLE #tmpTempDB Add ID int Identity(1,1)

			INSERT INTO [SQLMANTAINENCE].[TEMPDB_READWRITE_HOURLYSTATISTICS] ([physical_name],[name],[num_of_writes],[avg_write_stall_ms],[num_of_reads],[avg_read_stall_ms] )
				SELECT [physical_name],[name],[num_of_writes],[avg_write_stall_ms],[num_of_reads],[avg_read_stall_ms] 
				FROM #tmpTempDB WITH(NOLOCK)

			IF @Enable_TempDB_contention_alerts = 1
			BEGIN
					-- SEND EMAIL FOR WRITES ABOVE 20 MS
				IF EXISTS(SELECT TOP 1 1 FROM #tmpTempDB WITH(NOLOCK) WHERE avg_write_stall_ms >= 20) 
				BEGIN
					SET @strErrorMesssage = '<HTML><BODY><B>Problem: Average TempDB writes >= 20 MS</B><TABLE border=1>'
					SET @strErrorMesssage += '<tr><td>File Name (Logical)</td><td># of Writes</td><td>Avg. Write Stall (MS)</td><td># of Reads</td><td>Avg. Read Stall (MS)</td></tr>' 

						SELECT @strErrorMesssage += '<tr><td>'  + Cast(IsNull(Name,'') as varchar(1000)) + '</td><td align=right>' + Cast(IsNull(num_of_writes,0) 
						as varchar(1000)) + '</td><td align=right> ' + Case When IsNull(AVG_WRITE_STALL_MS,0) >= 20 Then ' <font color="red"> ' End  + Cast(Cast(IsNull(AVG_WRITE_STALL_MS,0) as numeric(9,2)) as varchar(100)) + '</td><td align=right>'  	+Cast(isNull(num_of_reads,0) as varchar(1000)) + '</td><td align=right>' + Cast(Cast(IsNull(AVG_READ_STALL_MS,0) as numeric(9,2)) as varchar(100)) + '</td></tr>'		
						FROM #tmpTempDB with(nolock)

				END
			END			
			DROP TABLE #tmpTempDB
			-- End of TempDB contention check above



		--**************************************************************
		--END OF MONITORING SCRIPT
		--**************************************************************

	END TRY
 
	BEGIN CATCH
		INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'MONITORING-ALERTS','Monitoring Alerts job failed, ErrOR Message: ' + ERROR_MESSAGE() ,'C');
		EXEC [SQLMantainence].[Log_Error] 'MonitoringAlerts','MONITORING-ALERTS'
		--SELECT 'ERROR : ' + ERROR_MESSAGE()  -- debug line
	END CATCH 

	
	--SELECT @strErrorMesssage   --- DEBUG LINE

	IF @strErrorMesssage <> ''
	BEGIN
		DECLARE @Body VarChar(MAX)
		SET @Body  =  @strErrorMesssage + '</body></html>'
	
		EXECUTE msdb..sp_send_dbmail 
		@Profile_Name = 'DBMaintenance', 
		@Recipients = @Recipients ,    
		@Subject = @Subject,
		@Body_Format= 'HTML',
		@Body = @Body, 
		@Execute_Query_Database = 'SQL_ADMIN'	

		--SELECT @Body --- DEBUG LINE
	END         

END
go

--- ****************************************
-- Start of MonitoringAlert1 Stored Procedure
---*****************************************
USE [SQL_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
THIS STORED PROCEDURE CHECKS THE SERVER EVERY 5 MINUTES AND REPORTS ANY ISSUES.  FOLLOWING CHECKS ARE DONE BY THIS JOB
- 1. Generates alert IF the SQL Server CPU utilizatiON goes above 90%  
-2. Check IF auto growth has occured fOR any databases in last 5 minutes.
- 3. Alerts for blockings over a specified threshold value on this server.
*/
CREATE PROCEDURE [SQLMantainence].[MonitoringAlerts2_5Minutes] 
 -- With Encryption
AS
BEGIN
	SET NOCOUNT ON;	
	
	DECLARE @intErrOR INT
    DECLARE @strErrorMesssage VarChar(MAX) = ''
	DECLARE @cmd VarChar(8000) = ''	
	DECLARE @ACTUAL_IP_ADDRESS VarChar(1000) 
	DECLARE @StartDate DATETIME  = DATEADD(MINUTE,-5, GETDATE())	
	DECLARE @SQLcmd VarChar(1000)
	 
	 
	  -- THIS SCRIPT BELOW IS TO DETECT THE IP ADDRESS OF THIS MACHINE FOR REPORTING PURPOSE I.E. USED IN EMAIL SUBJECT
	CREATE TABLE #temp1(SQL_IP VarChar(3000))
	INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 	
	DECLARE @IPAddress VarChar(300) 
	SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IPv4%' ORDER BY SQL_IP DESC) 	
	DECLARE @len INT 
	SET @Len = CHARINDEX(':', @IPAddress) 
	SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPAddress, @Len+1, LEN(@IPAddress)))) 
	DROP TABLE #temp1
	
    DECLARE @ERRORMESSAGE VarChar(MAX) ,
		@FormattedErrorMessage  VarChar(MAX),
		@ErrorNumber VarChar(50),
		@ErrorSeverity VarChar(50),
		@ErrorState  VarChar(50),
		@ErrorLine  VarChar(50),
		@ErrorProcedure  VarChar(200)	
	DECLARE @Environment VarChar (50), @EnvironmentDesc VarChar (50)
	DECLARE @Subject VarChar(1000)
	DECLARE @Recipients VarChar(2000)
	DECLARE @MinimumDiskSpaceForWarningInGB VarChar(100)

	DECLARE @MaximumLogSizeAllowedOnServerForEachDatabase VarChar(100)
	DECLARE @CheckDatabaseOnlineStatus VarChar(100)
	DECLARE @CheckForFailedJobs	 VarChar(100)
	DECLARE @ShrinkDBRequired BIT
	DECLARE @SQLServerServiceAccount VarChar(2000)
	DECLARE @SQLTeamMembers VarChar(2000)
	--DECLARE @CheckServerAuditLog  VarChar(100)
    DECLARE @CheckDatabaseAutoGrowth BIT
    DECLARE @Monitor_Mirroring_Status INT
    DECLARE @Monitor_LogShipping_Status int
	DECLARE @Monitor_Replication_Status int
	DECLARE @Msg varchar(8000)
	DECLARE @CheckBlocking INT
	

    
    BEGIN TRY 
 	
		SELECT TOP 1  @Environment = [VALUE]  FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='Environment'
		SELECT TOP 1 @EnvironmentDesc = CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END
		SELECT  @Subject = UPPER(@EnvironmentDesc) + ' - SQL Server monitoring alert ON server ' + @@SERVERNAME + '( IP Address: ' + @ACTUAL_IP_ADDRESS + ')'
		SELECT TOP 1  @Recipients = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='EmailRecipient'
		SELECT TOP 1 @SQLServerServiceAccount = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='SQL_SERVER_SERVICE_ACCOUNT'
		SELECT TOP 1 @SQLTeamMembers = VALUE  FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='SQLTeamMembers'
			
		SELECT  TOP 1 @CheckDatabaseAutoGrowth = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='LogDatabaseAutoGrowth'	
		IF  ISNUMERIC(@CheckDatabaseAutoGrowth) = 0 -- IF FALSE
			SELECT @CheckDatabaseAutoGrowth = '0'
			
	SELECT TOP 1 @CheckBlocking=VALUE FROM  [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK) WHERE configurationType='Enable_Blocking_Alerts'
 		IF  ISNUMERIC(@CheckBlocking) = 0 -- IF FALSE
			SELECT @CheckBlocking = '0'	
		--******************************************************************************
		-- 1. Generates alert IF the SQL Server CPU utilizatiON goes above 90%  
		--*******************************************************************************
		DECLARE @SQLProcessUtilizatiON FLOAT
		DECLARE @OtherProcessUtilizatiON FLOAT
		DECLARE @TotalUtilizatiON FLOAT

		DECLARE @ts_now BIGINT 
		SELECT @ts_now = ms_ticks FROM sys.dm_os_sys_info  WITH(NOLOCK) 
		
		SELECT TOP 1 @SQLProcessUtilizatiON = SQLProcessUtilization,  @OtherProcessUtilizatiON = 100 - SystemIdle - SQLProcessUtilizatiON  
		FROM (SELECT record.value('(./Record/@id)[1]', 'int') AS record_id, record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') 
		AS SystemIdle, record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS SQLProcessUtilization, TIMESTAMP 
		FROM ( SELECT TIMESTAMP, CONVERT(XML, record) AS record FROM sys.dm_os_ring_buffers WITH(NOLOCK) WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
		AND record LIKE '%<SystemHealth>%') AS x ) AS y 
		ORDER BY DATEADD (ms, (y.[timestamp] -@ts_now), GETDATE()) DESC
		
		SELECT @TotalUtilizatiON = (@SQLProcessUtilizatiON + @OtherProcessUtilization)
		IF @TotalUtilizatiON > 90 
		Begin
			SET @strErrorMesssage = @strErrorMesssage  + '<BR><BR><li>Total CPU Utilization is ' + CONVERT(VarChar(100),@TotalUtilization) + ' %' 
			INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'CPU Utilization','Total CPU Utilization is ' + CONVERT(VarChar(100),@TotalUtilization) + ' %','I');
		End
	
		
		 --- ********************************************************************************
		-- 2. CHECKS FOR AUTO GROWTHS SINCE THE LAST AUTO GROWTH RECORDED BY THIS TOOL
		--- ********************************************************************************
		IF (@CheckDatabaseAutoGrowth=1)
			Execute [SQLMantainence].[CheckDatabaseAutoGrowth] 
		
		--********************************************************************************
		--- 3. Check Process Blocking in last 5 minutes
		--- ********************************************************************************    
		IF (@CheckBlocking=1)
			BEGIN
			   DECLARE @Start_loop INT  = 1
	            DECLARE @END_loop  INT 
	            DECLARE @ServerName NVARCHAR(200)

	            DECLARE @Blocked_DatabaseName NVARCHAR(200)

	            DECLARE @Blockee_ID VARCHAR(100)
	            DECLARE @Blocker_ID VARCHAR(100)
	            DECLARE @Wait_Time_seconds INT
	            DECLARE @Wait_Type VARCHAR(100)
	            DECLARE @Resource_Type VARCHAR(100)
	            DECLARE @Requesting_Text NVARCHAR(MAX)
	            DECLARE @Blocking_Text NVARCHAR(MAX)
	            DECLARE @Blocking_DateTime DATETIME
	            
	            
		CREATE TABLE #TMP_PROCESS_BLOCKINGS(ROW_NO INT  IDENTITY(1,1),SERVERNAME NVARCHAR(200),BLOCKED_DATABASENAME NVARCHAR(200),BLOCKEE_ID VARCHAR(100),BLOCKER_ID VARCHAR(100),WAIT_TIME_SECONDS INT, WAIT_TYPE VARCHAR(100),RESOURCE_TYPE VARCHAR(100),REQUESTING_TEXT NVARCHAR(MAX),BLOCKING_TEXT NVARCHAR(MAX),BLOCKING_DATETIME DATETIME) 	
		
		INSERT INTO #tmp_process_blockings SELECT * from SQL_Admin.SQLMantainence.Blocking_History where Blocking_DateTime BETWEEN (@StartDate) AND (GETDATE()) 
		
		SELECT @END_loop= COUNT(*) FROM #tmp_process_blockings
		
		 IF EXISTS (select top 1 Blockee_ID from #tmp_process_blockings WITH(NOLOCK) where Blocking_DateTime BETWEEN (@StartDate) AND (GETDATE()))
		 BEGIN
			SELECT @strErrorMesssage += '<br><br><li><font color=RED>Below is the SQL Process-Blocking details  on this SQL server in last 15 seconds:</font><BR><TABLE Width="100%" Border="1"><TR><TD Width="10%"><b>Blocked_DatabaseName</TD><TD Width="5%"><b>Blockee ID</TD><TD Width="5%"><b>Blocker ID</TD><TD Width="5%"><b>Wait_Time_Seconds</TD><TD Width="5%"><b>Wait_Type</TD><TD Width="10%"><b>Resource_Type</TD><TD Width="30%"><b>Requesting Text</TD><TD Width="30%"><b>Blocking Text</TD></TR>' 
		   
		  
		WHILE(@Start_loop <= @END_loop)
		  BEGIN
		         -- select 'in blocking'
		         SELECT @SERVERNAME =SERVERNAME,  
				        @BLOCKED_DATABASENAME= BLOCKED_DATABASENAME, 
						@BLOCKEE_ID =BLOCKEE_ID, @BLOCKER_ID =BLOCKER_ID,
						@WAIT_TIME_SECONDS =WAIT_TIME_SECONDS, @WAIT_TYPE =WAIT_TYPE,
						@RESOURCE_TYPE =RESOURCE_TYPE, 
						@REQUESTING_TEXT =REQUESTING_TEXT,
						@BLOCKING_TEXT =BLOCKING_TEXT, 
						@BLOCKING_DATETIME =BLOCKING_DATETIME 
				  FROM #TMP_PROCESS_BLOCKINGS WITH(NOLOCK)
				  WHERE ROW_NO=@START_LOOP
	             
		         
		         SELECT @strErrorMesssage +='<tr><td>'+ IsNull(@Blocked_DatabaseName,'') +'</td> <td>'+ IsNull(@Blockee_ID,'')+'</td> <td>'+IsNull(@Blocker_ID,'')+'</td> <td>'+cast(IsNull(@Wait_Time_seconds,0) as varchar(10))+'</td> <td>'+IsNull(@Wait_Type,'')+'</td><td>'+IsNull(@Resource_Type,'')+'</td><td>'+IsNull(@Requesting_Text,'')+'</td><td>'+IsNull(@Blocking_Text,'')+'</td> </tr>'  
		         
		         SELECT @Start_loop += 1 
		  END  -- END OF WHILE LOOP

			SELECT @strErrorMesssage += '</table>'
		END	-- END OF IF

		DROP table #tmp_process_blockings
			
END
			  		  	
		--**************************************************************
		--END OF MONITORING SCRIPT
		--**************************************************************

	END TRY
 
	BEGIN CATCH
		INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'MONITORING-ALERTS','Monitoring Alerts job failed, ErrOR Message: ' + ERROR_MESSAGE() ,'C');
		EXEC [SQLMantainence].[Log_Error] 'MonitoringAlerts','MONITORING-ALERTS'
		--SELECT 'ERROR : ' + ERROR_MESSAGE()  -- debug line
	END CATCH 

	
	--SELECT @strErrorMesssage   --- DEBUG LINE

	IF @strErrorMesssage <> ''
	BEGIN
		DECLARE @Body VarChar(MAX)
		SET @Body  =  @strErrorMesssage + '</body></html>'
	
		EXECUTE msdb..sp_send_dbmail 
		@Profile_Name = 'DBMaintenance', 
		@Recipients = @Recipients ,    
		@Subject = @Subject,
		@Body_Format= 'HTML',
		@Body = @Body, 
		@Execute_Query_Database = 'SQL_ADMIN'	

		--SELECT @Body --- DEBUG LINE
	END         

END
--- ****************************************
-- END OF MonitoringAlert1 Stored Procedure
--- ****************************************
go


--- ****************************************
-- Start of MonitoringAlert Stored Procedure
---*****************************************
USE [SQL_ADMIN]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
THIS STORED PROCEDURE CHECKS THE SERVER EVERY 15 MINUTES AND REPORTS ANY ISSUES.  FOLLOWING CHECKS ARE DONE BY THIS JOB
- 1. Shrinking any database logs which are greater then specified acceptable size
- 2. Check fOR offline/suspect mode database, IF the feature is enabled ON this server.
- 3. Minimum Disk Space Check ON all drives except fOR drives which are marked as not required in configuratiON table
- 4. IF Failed Job Check is enabled ON this server, then generates alerts fOR any failed job since the last 15 minute
- 7. Check fOR any server level configuratiON changes made in the last 15 minutes
- 8. Check fOR Adhoc Backup AND RestoratiON done by non-SQL team Members 
-9. Check whether SQL Services was Restarted in last 15 minutes
- 10. CHECK fOR Critical Errors AND Warnings FROM DBMantainenceLOG Table every 15 Mins 
- 11. Check IF any new server login OR database user was created in last 15 minutes
- 13. Execute the Database space tracking procedure...which will sent alert fOR any database that is tracked  after 80% space usage is crossed
-14. Check Mirroring Status
- 15.  Check LogShipping  Status 
- 16. Check Replication Status
-- 17. Checks TempDB contention and if issue is found then records the details in a table and also sends alert 
*/
CREATE PROCEDURE [SQLMantainence].[MonitoringAlerts1_15Minutes] 
-- With Encryption
AS
BEGIN
	SET NOCOUNT ON;	
	
	DECLARE @intErrOR INT
    DECLARE @strErrorMesssage VarChar(MAX) = ''
	DECLARE @cmd VarChar(8000) = ''	
	DECLARE @ACTUAL_IP_ADDRESS VarChar(1000) 
	DECLARE @StartDate DATETIME  = DATEADD(MINUTE,-15, GETDATE())	
	DECLARE @SQLcmd VarChar(1000)
	 
	 
	  -- THIS SCRIPT BELOW IS TO DETECT THE IP ADDRESS OF THIS MACHINE FOR REPORTING PURPOSE I.E. USED IN EMAIL SUBJECT
	CREATE TABLE #temp1(SQL_IP VarChar(3000))
	INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 	
	DECLARE @IPAddress VarChar(300) 
	SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IPv4%' ORDER BY SQL_IP DESC) 	
	DECLARE @len INT 
	SET @Len = CHARINDEX(':', @IPAddress) 
	SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPAddress, @Len+1, LEN(@IPAddress)))) 
	DROP TABLE #temp1
	
    DECLARE @ERRORMESSAGE VarChar(MAX) ,
		@FormattedErrorMessage  VarChar(MAX),
		@ErrorNumber VarChar(50),
		@ErrorSeverity VarChar(50),
		@ErrorState  VarChar(50),
		@ErrorLine  VarChar(50),
		@ErrorProcedure  VarChar(200)	
	DECLARE @Environment VarChar (50), @EnvironmentDesc VarChar (50)
	DECLARE @Subject VarChar(1000)
	DECLARE @Recipients VarChar(2000)
	DECLARE @MinimumDiskSpaceForWarningInGB VarChar(100)
	DECLARE @MaximumLogSizeAllowedOnServerForEachDatabase VarChar(100)
	DECLARE @CheckDatabaseOnlineStatus VarChar(100)
	DECLARE @CheckForFailedJobs	 VarChar(100)
	DECLARE @ShrinkDBRequired BIT
	DECLARE @SQLServerServiceAccount VarChar(2000)
	DECLARE @SQLTeamMembers VarChar(2000)
	DECLARE @CheckServerAuditLog  VarChar(100)
    DECLARE @CheckDatabaseAutoGrowth BIT
    DECLARE @Monitor_Mirroring_Status INT
    DECLARE @Monitor_LogShipping_Status int
	DECLARE @Monitor_Replication_Status int
	DECLARE @Msg varchar(8000)
	DECLARE @CheckBlocking INT
	DECLARE @Full_BackupFolder VARCHAR(100)
	DECLARE @BACKUPDRIVE VARCHAR(100)
	DECLARE @SQL VARCHAR(4000)

    
    BEGIN TRY 
 	
		SELECT TOP 1  @Environment = [VALUE]  FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='Environment'
		SELECT TOP 1 @EnvironmentDesc = CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END
		SELECT  @Subject = UPPER(@EnvironmentDesc) + ' - SQL Server monitoring alert ON server ' + @@SERVERNAME + '( IP Address: ' + @ACTUAL_IP_ADDRESS + ')'
		SELECT TOP 1  @Recipients = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='EmailRecipient'
		SELECT TOP 1 @SQLServerServiceAccount = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='SQL_SERVER_SERVICE_ACCOUNT'

		SELECT TOP 1 @SQLTeamMembers = VALUE  FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='SQLTeamMembers'
		SELECT  TOP 1 @MinimumDiskSpaceForWarningInGB = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='MinimumDiskSpaceForWarningInGB'
		SELECT @Monitor_Mirroring_Status=VALUE FROM  [SqlMantainence].DBMantainenceConfiguratiON WITH(NOLOCK) WHERE configurationType='MonitorMirroringStatus'
        SELECT @Monitor_LogShipping_Status=VALUE FROM  [SqlMantainence].DBMantainenceConfiguratiON WITH(NOLOCK) WHERE configurationType='MonitorLogShiippingStatus'
		SELECT @Monitor_Replication_Status=VALUE FROM  [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK) WHERE configurationType='MonitorReplicationStatus'

		IF  ISNUMERIC(@MinimumDiskSpaceForWarningInGB) = 0 -- IF FALSE
			SELECT @MinimumDiskSpaceForWarningInGB = 20 -- Default 20 GB
	
		SELECT  TOP 1 @MaximumLogSizeAllowedOnServerForEachDatabase = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='MaximumLogSizeAllowedOnServerForEachDatabase'
		IF  ISNUMERIC(@MaximumLogSizeAllowedOnServerForEachDatabase) = 0 -- IF FALSE
			SELECT @MaximumLogSizeAllowedOnServerForEachDatabase = 2000

		SELECT  TOP 1 @CheckDatabaseOnlineStatus = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='CheckDatabaseOnlineStatus'
		IF  ISNUMERIC(@CheckDatabaseOnlineStatus) = 0 -- IF FALSE
			SELECT @CheckDatabaseOnlineStatus = '0'
		
	
		SELECT  TOP 1 @CheckForFailedJobs = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='CheckForFailedJobs'
		IF  ISNUMERIC(@CheckForFailedJobs) = 0 -- IF FALSE
			SELECT @CheckForFailedJobs = '0'		

		SELECT  TOP 1 @ShrinkDBRequired = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='ShrinkDBRequired'	
		IF  ISNUMERIC(@ShrinkDBRequired) = 0 -- IF FALSE
			SELECT @ShrinkDBRequired = '0'		

		SELECT  TOP 1 @CheckServerAuditLog = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='CheckServerAuditLog'	
		IF  ISNUMERIC(@CheckServerAuditLog) = 0 -- IF FALSE
			SELECT @CheckServerAuditLog = '0'
			
		SELECT  TOP 1 @CheckDatabaseAutoGrowth = [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='LogDatabaseAutoGrowth'	
		IF  ISNUMERIC(@CheckDatabaseAutoGrowth) = 0 -- IF FALSE
			SELECT @CheckServerAuditLog = '0'

--**********************************************************************
DECLARE @SQLTraceFlags TABLE (ID INT Identity(1,1), FLAGNo INT)
CREATE TABLE #TMP (TRACEFLAG INT, STATUS BIT, GLOBAL BIT, SESSION BIT)


INSERT INTO @SQLTraceFlags
SELECT VALUE FROM [SQLMANTAINENCE].[DBMANTAINENCECONFIGURATION]
WHERE CONFIGURATIONTYPE = 'ENABLE_SQL_TRACE_FLAG' AND ISNUMERIC(VALUE) = 1 AND Len(ltrim(rtrim(value))) <= 4

DECLARE @i INT = 0
DECLARE @Totali INT 
DECLARE @FlagNo INT 

SELECT @Totali = MAX(ID) FROM @SQLTraceFlags

WHILE @i <= @Totali
BEGIN
	SELECT @FlagNo  = FLAGNo FROM @SQLTraceFlags WHERE ID = @I
	
	TRUNCATE TABLE #TMP 
	INSERT INTO #TMP EXEC('DBCC TRACESTATUS (' + @FlagNo + ')')

	IF NOT EXISTS(SELECT * FROM #TMP WHERE GLOBAL = 1)
		EXECUTE('DBCC TRACEON (' + @FlagNo + ',-1)')

	SET @I += 1 
END 
DROP TABLE #TMP
--**********************************************************************
			
	SELECT TOP 1 @CheckBlocking=VALUE FROM  [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK) WHERE configurationType='Enable_Blocking_Alerts'
 		IF  ISNUMERIC(@CheckBlocking) = 0 -- IF FALSE
			SELECT @CheckBlocking = '0'	


		-- *******************************************************************************************************
		-- 1. Shrink Database, IF required
		-- Shrinking any database logs which are greater then specified acceptable size
		-- The @ShrinkDBRequired flag decides whether shrinking log file facility is enabled ON this server	
		-- *******************************************************************************************************
		--IF (@ShrinkDBRequired =1)  -- IF Flag is SET to True in configuratiON table 
		--BEGIN
		--	CREATE TABLE #logspace (DB SysName, LogSize_MB REAL, Used_LogSpacePercentage REAL, Status SMALLINT) 
		--	INSERT INTO #logspace  EXEC ('DBCC sqlperf (' + '''' +  'LOGSPACE' + '''' +') WITH NO_INFOMSGS ')
		  
		--	SELECT @intErrOR = COUNT(*) FROM #logspace  WITH(NOLOCK) WHERE LogSize_MB >= @MaximumLogSizeAllowedOnServerForEachDatabase 
		--	IF @intErrOR > 0 
		--	BEGIN
		--		DECLARE @DBName VarChar(100) = ''
		--		SELECT	@DBName = @DBName  + CAST(DB AS VarChar(2000)) + ' (' + CAST(LogSize_MB AS VarChar(100)) + ' MB), ' FROM #logspace  WITH(NOLOCK) WHERE LogSize_MB >= @MaximumLogSizeAllowedOnServerForEachDatabase
				
		--		SELECT	@cmd = @cmd  + 'Exec SQL_ADMIN.SQLMantainence.sp_ShrinkDatabase ''' + CAST(DB AS VarChar(2000)) + ''';' FROM #logspace WITH(NOLOCK) WHERE LogSize_MB >= @MaximumLogSizeAllowedOnServerForEachDatabase
		--		EXEC (@cmd)	

		--		SET @strErrorMesssage = @strErrorMesssage  + '<BR><BR><li>Log Size fOR database(s) ' + @DBName + ' has grown to more than ' + @MaximumLogSizeAllowedOnServerForEachDatabase + '  MB'
		--		INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'ShrinkDBRequired','Log Size fOR database(s) ' + @DBName + ' has grown to more than ' + @MaximumLogSizeAllowedOnServerForEachDatabase + '  MB','I');
		--	END 
			
		--	DROP TABLE #logspace 
		--END
    
    	-- ***************************************************************************************
		-- 2. Check fOR offline/suspect mode database, IF the feature is enabled ON this server. 
		-- **************************************************************************************		
		IF @CheckDatabaseOnlineStatus = 1 
		BEGIN
			SELECT @intErrOR = COUNT(*) FROM sys.databases  WITH(NOLOCK) WHERE state_desc NOT IN ('ONLINE','RESTORING')  AND NAME NOT IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM [SQLMANTAINENCE].[DBMANTAINENCECONFIGURATION]  WITH(NOLOCK) WHERE CONFIGURATIONTYPE = 'EXCLUDEDATABASE')
			IF @intErrOR > 0 
			BEGIN
				DECLARE @DBName1 VarChar(100) = ''
				SELECT	@DBName1  = @DBName1 + CAST(Name  AS VarChar(2000)) + ' , ' FROM sys.databases  WITH(NOLOCK) WHERE state_desc  NOT IN ('ONLINE','RESTORING') AND 	NAME NOT IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM [SQLMANTAINENCE].[DBMANTAINENCECONFIGURATION]  WITH(NOLOCK) WHERE CONFIGURATIONTYPE = 'EXCLUDEDATABASE')			
				
				SET @strErrorMesssage = @strErrorMesssage   + '<BR><BR><li>Database  ' + @DBName1   + ' is OFFLINE / SUSPECT mode.'
				INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'CheckDatabaseOnlineStatus','Database '+ @DBName1   + ' is OFFLINE / SUSPECT mode','I');
			END 
		END  
	
		-- ****************************************************************************************************************
		-- 3. Minimum Disk Space Check ON all drives except fOR drives which are marked as not required in configuratiON table
		-- ****************************************************************************************************************
		
		DECLARE @MinimumDiskSpaceForWarningFloat FLOAT
		DECLARE  @output TABLE (Line VARCHAR(1000))    -- Table Variable for storing disk information
		CREATE TABLE #drives (drive VARCHAR(100) PRIMARY KEY, FreeSpace VARCHAR(100) NULL) 

		SET @MinimumDiskSpaceForWarningFloat = @MinimumDiskSpaceForWarningInGB

			--Powershell command to get drive's  information
		SET @SQLcmd = 'powershell.exe -c "Get-WmiObject -Class Win32_Volume -Filter ''DriveType = 3'' | SELECT name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1048576+''%''+$_.freespace/1048576+''*''}"' 

			--Inserting disk name, total space and free space value INTo table variable 
		INSERT INTO @output (Line) EXECUTE xp_cmdshell @SQLcmd 

		INSERT #drives(drive,FreeSpace) 
			SELECT RTRIM(LTRIM(SUBSTRING(line,1,CHARINDEX('|',line) -1))) as BackupDrive,Convert(VARCHAR,ROUND(RTRIM(LTRIM(SUBSTRING(line,CHARINDEX('%',line)+1,(CHARINDEX('*',line) -1)-CHARINDEX('%',line)) )),2)) as 'freespaceGB'
			FROM @output where line is not null AND Left(IsNull(line,''),10) <> '\\?\Volume' 

	
		SELECT @INTError =  COUNT(1) FROM #drives  WITH(NOLOCK) 
			WHERE FreeSpace <= (@MinimumDiskSpaceForWarningFloat * 1024)  
			AND Drive NOT IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM SQLMantainence.DBMantainenceConfiguration  WITH(NOLOCK) WHERE ConfigurationType='ExcludeDiskSpaceCheckForDrive')

		IF @INTError > 0 
		BEGIN
			DECLARE @Drives VARCHAR(max) = ''
			SELECT	@Drives = @Drives + 'Drive  ' + CAST(drive AS VARCHAR(2000)) + ' (' + CAST(FreeSpace AS VARCHAR(1000)) + ' MB)' + ' , ' FROM #drives  WITH(NOLOCK) 
			WHERE FreeSpace <= (@MinimumDiskSpaceForWarningFloat * 1024) AND drive NOT IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM SQLMantainence.DBMantainenceConfiguration  WITH(NOLOCK) WHERE ConfigurationType='ExcludeDiskSpaceCheckForDrive')
			
			SET @strErrorMesssage = @strErrorMesssage  + '<BR><BR><li><FONT color=red>Insufficient Disk space on ' + @Drives + ' drive(s) i.e. less than ' + @MinimumDiskSpaceForWarningInGB + ' GB</font>'
			INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'MinimumDiskSpaceOnDrives','Insufficient Disk space on ' + @Drives + ' drive(s) i.e. less than ' + @MinimumDiskSpaceForWarningInGB + ' GB','I');
		END 
		DROP TABLE #drives

		-- *********************************************************************************************************************
		-- 4. IF Failed Job Check is enabled ON this server, then generates alerts fOR any failed job since the last 15 minute
		-- *********************************************************************************************************************
		set @CheckForFailedJobs = 0  -- debug line to remove the failed job check
		IF @CheckForFailedJobs = 1 -- IF True
		BEGIN
			CREATE TABLE #FailedJobs (JobName SysName) 
			INSERT INTO #FailedJobs  

			SELECT DISTINCT job_name = sj.name  
			FROM msdb.dbo.sysjobhistory sjh WITH(NOLOCK) , msdb.dbo.sysjobs sj WITH(NOLOCK) 
			WHERE sj.job_id = sjh.job_id AND sjh.step_id = 0 AND sjh.run_status = 0 AND 
			LEFT(CAST(sjh.run_date AS CHAR(10)),4) + '-' + SUBSTRING(CAST(sjh.run_date AS CHAR(10)),5,2) + '-' + SUBSTRING(CAST(sjh.run_date AS CHAR(10)),7,2) 
			+ ' ' + SUBSTRING (RIGHT (STUFF (' ', 1, 1, '000000') + CONVERT(VarChar(6),sjh.run_time), 6), 1, 2) + ':' + SUBSTRING (RIGHT (STUFF (' ', 1, 1, '000000') + CONVERT(VarChar(6), sjh.run_time), 6) ,3 ,2)
			+ ':' + SUBSTRING (RIGHT (STUFF (' ', 1, 1, '000000') + CONVERT(VarChar(6),sjh.run_time), 6) ,5 ,2) >= CONVERT(CHAR(19), (SELECT DATEADD (HOUR,(-1), GETDATE())), 121) 
			AND LEFT(CAST(sjh.run_date AS CHAR(10)),4) + '-' + SUBSTRING(CAST(sjh.run_date AS CHAR(10)),5,2)  + '-' + SUBSTRING(CAST(sjh.run_date AS CHAR(10)),7,2) = 
			CONVERT(VarChar(4),DATEPART(YEAR ,GETDATE())) + '-' + RIGHT('0' + CONVERT(VarChar(2),DATEPART(MONTH ,GETDATE())),2) + '-' + RIGHT('0' +CONVERT(VarChar(2),DATEPART(DAY  ,GETDATE())),2)
			AND ( SUBSTRING (RIGHT (STUFF (' ', 1, 1, '000000') + CONVERT(VarChar(6),sjh.run_time), 6), 1, 2) 
			+ ':' + SUBSTRING (RIGHT (STUFF (' ', 1, 1, '000000') + CONVERT(VarChar(6), sjh.run_time), 6) ,3 ,2)
			+ ':' + SUBSTRING (RIGHT (STUFF (' ', 1, 1, '000000') + CONVERT(VarChar(6),sjh.run_time), 6) ,5 ,2) ) >= RIGHT('0' + CONVERT(VarChar(2),DATEPART(HOUR,DATEADD(MINUTE ,-15,GETDATE()))),2) + ':' + RIGHT('0' + CONVERT(VarChar(2),DATEPART(MINUTE ,DATEADD(MINUTE ,-15,GETDATE()))),2) + ':00' 
		 
			SELECT @intErrOR = COUNT(*) FROM #FailedJobs  WITH(NOLOCK) 
			IF @intErrOR > 0 
			BEGIN
				DECLARE @JobName VarChar(100) = ''
				SELECT	@JobName  = @JobName  + '<br>&nbsp;-&nbsp;' + CAST(JobName  AS VarChar(2000))  FROM #FailedJobs  WITH(NOLOCK) 
						
				SET @strErrorMesssage = @strErrorMesssage  + '<BR><BR><li><u>Following Job(s) failed in last 15 minutes</u>:' + @JobName
				INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'CheckForFailedJobs','Following Job(s) failed in last 15 minutes:' + @JobName,'I');
			END 	
			
			DROP TABLE #FailedJobs 
		END

		-- **************************************************************************************************
		--7.  Check fOR any server level configuratiON changes made in the last 15 minutes
		-- **************************************************************************************************

		DECLARE @SQLcmd_ConfigChanges VarChar(1000)
        SET @SQLcmd_ConfigChanges = 'master.dbo.xp_readerrorlog 0, 1, N''Configuration Option'',null, ''' + REPLACE(CONVERT(VarChar(100),@StartDate,126),'T',' ') + ''',  ''' + REPLACE(CONVERT(VarChar(100),GETDATE(),126),'T',' ')  + ''', N''desc''' 

        CREATE TABLE #tempConfigurationChanges (LogDate DATETIME, ProcessInfo VarChar(100), TEXT VarChar(MAX)) 
		INSERT INTO #tempConfigurationChanges  EXEC (@SQLcmd_ConfigChanges)
		IF EXISTS(SELECT TOP 1 1 FROM #tempConfigurationChanges WITH(NOLOCK) )
		BEGIN
			SELECT @strErrorMesssage +=  '<BR><BR><li><u><font color=RED>Configuration Changes done ON this server in last 15 minutes are as below</U>:</font>'  
			SELECT @strErrorMesssage +=  '<br>' + 'DATE:'+ CAST([LogDate] AS NVarChar(200)) + '<br>'+'PROCESS ID:' + [ProcessInfo] + '<br>'+'CHANGE MADE:' + [TEXT]  + '<br>'  
			FROM #tempConfigurationChanges WITH(NOLOCK) 

			SELECT @MSG = ''
			SELECT @MSG +=  'DATE='+ CAST([LogDate] AS NVarChar(200)) + ', '+'PROCESS ID=' + [ProcessInfo] + ', '+'CHANGE MADE=' + [TEXT]  + ';  '  
			FROM #tempConfigurationChanges WITH(NOLOCK) 

			INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'ServerConfigurationChanges', @MSG ,'I');
        END
		DROP TABLE #tempConfigurationChanges
	 	 
	 
		--- ********************************************************************************
		--8. Check for Adhoc Backup AND Restoration done by non-SQL team Members 
		--- ********************************************************************************
	   DECLARE @Start INT  = 1
	   DECLARE @END  INT 
	   DECLARE @Database_Name VarChar(500)
	   DECLARE @UserName VarChar(500)
	   
	   
	   CREATE TABLE #tmp_adhocbckps(RowNo INT ,Dname VarChar(1000),UserName VarChar(1000),BRdate DATETIME ) 
	   
	   -- CHECKING DATABASE BACKUP HISTORY BELOW 
	   INSERT INTO  #tmp_adhocbckps
		   SELECT ROW_NUMBER() OVER (ORDER BY Backup_Finish_Date),Database_Name,[USER_NAME],Backup_Finish_Date 
		   FROM msdb.dbo.backupSET  WITH(NOLOCK) 
		   WHERE Backup_Finish_Date BETWEEN (@StartDate) AND (GETDATE()) 
		-- AND CHARINDEX ([USER_NAME], @SQLServerServiceAccount,1) = 0 AND 	CHARINDEX ([USER_NAME], @SQLTeamMembers,1) =  0
		 AND CHARINDEX (SubString([USER_NAME],(CharIndex('\',IsNull([USER_NAME],''),1)+1),2000) , @SQLServerServiceAccount,1) = 0 AND 	CHARINDEX (SubString([USER_NAME],(CharIndex('\',IsNull([USER_NAME],''),1)+1),2000) , @SQLTeamMembers,1) =  0
		    
		SELECT  @END = COUNT(*) FROM #tmp_adhocbckps  WITH(NOLOCK) 
		IF(@END <> 0)
		BEGIN
			SET @strErrorMesssage +='<BR><li><U>Adhoc Backups taken ON this server (by Non-SQL Team Member) in last 15 minutes. <u>:<BR><table border=''1'' width="100%"><tr><td><b>Database Name</b></td> <td><b>User Name</b></td> </tr>'
			--SET @strErrorMesssage +='<BR><li><U>Adhoc Backups taken ON this server (by Non-SQL Team Member) in last 15 minutes. As a precautionary measure, we have initiated backup chain with full backup. Please verify the same.<u>:<BR><table border=''1'' width="100%"><tr><td><b>Database Name</b></td> <td><b>User Name</b></td> </tr>'
			SET @msg = 'Adhoc Backups taken by non-SQL  team member for database (user name): '
			WHILE(@Start <= (SELECT MAX(RowNo) FROM #tmp_adhocbckps WITH(NOLOCK) ))
			BEGIN        
				SELECT  @Database_Name = Dname, @UserName=UserName FROM #tmp_adhocbckps  WITH(NOLOCK) WHERE RowNo = @Start           
				SELECT @strErrorMesssage += '<tr><td>' + @Database_Name + '</td><td>'+ @UserName + '</td> </tr>'
				SELECT @msg += @Database_Name + ' (' + @username + '), '

/*
-- This feature to auto correct the adhoc backup breaking the normal backup chain issue is switched off for CEX. 
				

				SELECT @Full_BackupFolder	=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Full_BackupFolder'

					IF @BACKUPDRIVE = 'http'   
					SET @SQL = 'BACKUP DATABASE [' + @Database_Name + '] TO URL = ''' +  @FULL_BACKUPFOLDER + '/' + @Database_Name + '@' +  
					CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR(4)) + RIGHT('0'+CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR(2)),2) + 
					RIGHT('0'+CAST(DATEPART(DAY,GETDATE()) AS VARCHAR(2)),2) + '_' + RIGHT('0'+CAST(DATEPART(HOUR,GETDATE()) AS VARCHAR(2)),2) + 
					RIGHT('0'+CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR(2)),2) + '.BAK'' 
					WITH CREDENTIAL = ''SQLBackupCreds'', CHECKSUM, INIT'
				ELSE
					SET @SQL = 'BACKUP DATABASE [' + @Database_Name + '] TO DISK = ''' +  @FULL_BACKUPFOLDER + '\' + @Database_Name + '@' +  
					CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR(4)) + RIGHT('0'+CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR(2)),2) + 
					RIGHT('0'+CAST(DATEPART(DAY,GETDATE()) AS VARCHAR(2)),2) + '_' + RIGHT('0'+CAST(DATEPART(HOUR,GETDATE()) AS VARCHAR(2)),2) + 
					RIGHT('0'+CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR(2)),2) + '.BAK'' WITH  CHECKSUM, INIT'
									

			--	PRINT @SQL
				EXEC(@SQL)
*/
				SELECT @Start += 1
			END     
			SELECT @strErrorMesssage += '</table><br>' 
			INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'AdhocBackups',@msg,'I');
		END    
		
     
		TRUNCATE TABLE  #tmp_adhocbckps 		
		SELECT @END = 0
		SELECT @Start = 1

		-- CHECKING DATA RESTORATION HISTORY BELOW
		INSERT INTO  #tmp_adhocbckps 
			SELECT ROW_NUMBER() OVER (ORDER BY Restore_Date),Destination_Database_Name,[USER_NAME],Restore_Date 
			FROM msdb.dbo.RestoreHistory  WITH(NOLOCK) 
			WHERE Restore_Date BETWEEN (@StartDate) AND (GETDATE()) 
			--AND CHARINDEX ([USER_NAME], @SQLServerServiceAccount,1) = 0 AND CHARINDEX ([USER_NAME], @SQLTeamMembers,1) =  0
  AND CHARINDEX (SubString([USER_NAME],(CharIndex('\',IsNull([USER_NAME],''),1)+1),2000) , @SQLServerServiceAccount,1) = 0 AND 	CHARINDEX (SubString([USER_NAME],(CharIndex('\',IsNull([USER_NAME],''),1)+1),2000) , @SQLTeamMembers,1) =  0
  
		SELECT  @END = COUNT(*) FROM #tmp_adhocbckps  WITH(NOLOCK) 
   
		IF(@END <> 0)
		BEGIN
			SET @strErrorMesssage +='<BR><li><u>Database restored ON this server (by Non-SQL Team Member) in last 15 minutes<u>:</B><BR></H4><table border=''1''><tr><td><b>Database Name</b></td> <td><b>User Name</b></td> </tr>'
			SET @msg = 'Database restored by non-SQL team member for database (user name):  '
			WHILE(@Start <= (SELECT MAX(RowNo) FROM #tmp_adhocbckps WITH(NOLOCK) ))
			BEGIN        
				SELECT @Database_Name = Dname, @UserName = UserName FROM #tmp_adhocbckps  WITH(NOLOCK) WHERE RowNo = @Start           
				SELECT @strErrorMesssage += '<tr><td>' + @Database_Name + '</td> <td>' + @UserName + '</td> </tr>'
				SELECT @msg += @Database_Name + ' (' + @UserName + '),  '
				SELECT @Start += 1
			END   
			
			SELECT @strErrorMesssage += '</table>'
			INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'DatabaseRestore',@msg,'I');
		END
				 
		DROP TABLE  #tmp_adhocbckps 


		--**************************************************************
		--9. Check whether SQL Services was Restarted in last 15 minutes
		--**************************************************************
		DECLARE @SQL_RESTART DATETIME
		IF EXISTS(SELECT SQLserver_Start_Time FROM sys.dm_os_sys_info  WITH(NOLOCK) WHERE SQLserver_Start_Time BETWEEN (@StartDate) AND (GETDATE()))
		BEGIN
			SELECT TOP 1 @SQL_RESTART = SQLserver_Start_Time FROM sys.dm_os_sys_info  WITH(NOLOCK) ORDER BY SQLserver_Start_Time DESC
			SELECT @strErrorMesssage += '<BR><BR><li><font color=Red><B>SQL services was restarted on this server at ' + CAST(@SQL_RESTART AS VarChar(100)) +'</font>'
			INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'SQLRestart', 'SQL services was restarted on this server at ' + CAST(@SQL_RESTART AS VarChar(100)),'I');
		END


	    --- ********************************************************************************
		--- 10. CHECK fOR Critical Errors AND Warnings FROM DBMantainenceLOG Table every 15 Mins 	 
		--- ********************************************************************************
		DECLARE @IROW SMALLINT
		SET @iRow  = 1

		DECLARE @TotalRows INT = 0
		DECLARE @Details VarChar(MAX)
		DECLARE @Type VarChar(300)
		DECLARE @Status CHAR(1)
	 
		CREATE TABLE #tmp_LogTabErrors(TYPE  VarChar(300),LogDetails VarChar(MAX),Status CHAR(1),row_no INT)
		INSERT INTO #tmp_LogTabErrors
			SELECT [TYPE],[LogDetails],[Status],ROW_NUMBER() OVER (ORDER BY LogDate) 
			FROM SQLMantainence.DBMantainenceLOG  WITH(NOLOCK) 
			WHERE status IN ('C','W') AND LogDate BETWEEN (@StartDate) AND (GETDATE()) 
			ORDER BY logdate DESC 
		
		SELECT @TotalRows = COUNT(*) FROM #tmp_LogTabErrors WITH(NOLOCK) 
		IF( @TotalRows <> 0)
		BEGIN
			SET @strErrorMesssage +='<br><br><li><font color=RED><u>Below are the problems logged in SQL Maintenance & Monitoring Tool in last 15 minutes:</u></font><BR><table border=''1''><tr><td><b>Details</b></td> <td><b>Status</b></td> <td><b>Type</b></td> </tr>  '
			WHILE (@iRow <= (SELECT MAX(row_no) FROM #tmp_LogTabErrors WITH(NOLOCK) ))
			BEGIN
				SELECT @Details=LogDetails FROM #tmp_LogTabErrors  WITH(NOLOCK) WHERE row_no = @iRow
				SELECT @Type=TYPE FROM #tmp_LogTabErrors  WITH(NOLOCK) WHERE row_no = @iRow
				SELECT @Status=Status FROM #tmp_LogTabErrors  WITH(NOLOCK) WHERE row_no = @iRow	
				SELECT @strErrorMesssage +='<tr><td>'+@Details+'</td> <td>'+@Type+'</td> <td>'+@Status+'</td></tr>'  
				SELECT @iRow += 1
			END
			SELECT @strErrorMesssage += '</table>'
		END
		
		DROP TABLE #tmp_LogTabErrors
		
		
	
	    --- ********************************************************************************
		--- 11. Check IF any new server login OR database user was created in last 15 minutes	 
		--- ********************************************************************************
		IF (@CheckServerAuditLog =1)  -- IF Flag is SET to True in configuratiON table 
		BEGIN		
			DECLARE @HTMLText VarChar(MAX) = '' 
			SET @msg = ''

			SELECT @HTMLText += '<TD>' + CAST(EventTime AS VarChar(100)) + '</TD><TD>' + EventType + '</TD><TD>' + ServerLogin + '</TD><TD>' + REPLACE(TSQLText,'''','"') + '</TD></TR>'

			FROM Master.dbo.PermissionAudit WITH(NOLOCK)
			WHERE EventTime BETWEEN @StartDate AND GETDATE() AND 
			      EventType IN ('ADD_SERVER_ROLE_MEMBER','DROP_LOGIN','ADD_ROLE_MEMBER','CREATE_USER','DROP_DATABASE', 'ALTER_DATABASE','CREATE_LOGIN')  	
				  AND CHARINDEX (SubString(ServerLogin,(CharIndex('\',IsNull(SErverLogin,''),1)+1),2000) , @SQLServerServiceAccount,1) = 0 AND 	CHARINDEX (SubString(ServerLogin,(CharIndex('\',IsNull(SErverLogin,''),1)+1),2000) , @SQLTeamMembers,1) =  0 AND		      
			      CHARINDEX('COMPATIBILITY_LEVEL',TSQLText,1) = 0  -- IGNORE THE COMPATIBILITY LEVEL CHANGES			
			ORDER BY EventTime DESC		

			IF @HTMLText <> '' 
			BEGIN


				SELECT @strErrorMesssage += '<br><br><li><font color=RED><u>Below are Permission/Database level changes done on this SQL server (by Non-SQL Team Members) in last 15 minutes:</u></font><BR><TABLE Width="100%" Border="1"><TR><TD Width="10%"><b>Event Time</TD><TD Width="15%"><b>Event Type</TD><TD Width="10%"><b>Modified By</TD><TD Width="65%"><b>SQL Command Executed</TD></TR>' + @HTMLText + '</TABLE><BR>'

				SET @MSG = 'Permission/Database level changes done (by Non-SQL Team Members) ='
				SELECT @msg +=  'Event Time='  + CAST(EventTime AS VarChar(100)) + ' Modified By= ' + ServerLogin + ' ' + REPLACE(TSQLText,'''','"') + ' ,   '
				FROM Master.dbo.PermissionAudit WITH(NOLOCK)
				WHERE EventTime BETWEEN @StartDate AND GETDATE() AND 
					  EventType IN ('ADD_SERVER_ROLE_MEMBER','DROP_LOGIN','ADD_ROLE_MEMBER','CREATE_USER','DROP_DATABASE', 'ALTER_DATABASE','CREATE_LOGIN')  	
					  AND CHARINDEX (SubString(ServerLogin,(CharIndex('\',IsNull(SErverLogin,''),1)+1),2000) , @SQLServerServiceAccount,1) = 0 AND 	CHARINDEX (SubString(ServerLogin,(CharIndex('\',IsNull(SErverLogin,''),1)+1),2000) , @SQLTeamMembers,1) =  0 AND		      
			      CHARINDEX('COMPATIBILITY_LEVEL',TSQLText,1) = 0  -- IGNORE THE COMPATIBILITY LEVEL CHANGES			
				ORDER BY EventTime DESC		

				INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'CheckServerAuditLog',@msg,'I');
			END 
		END
			
		--- ********************************************************************************
		--- 13. Execute the Database space tracking procedure...which will sent alert fOR any database that is tracked  after 80% space usage is crossed
		--- ********************************************************************************    

		IF EXISTS(SELECT 1 FROM  [SQL_ADMIN].SQLMantainence.DBMantainenceConfiguratiON WHERE ConfigurationType='DBNameForTrackingSpaceUsage' AND Value <> '?')
			Execute [SQLMantainence].[TrackDBSpaceUsage]
					
		--- ********************************************************************************
		--- 14. Check Mirroring Status 
		--- ********************************************************************************    
	--	IF (@Monitor_Mirroring_Status=1)
	--		Execute [SQLMantainence].[Monitor_MirroringStatus]
	  
	  		--- ********************************************************************************
		--- 15. Check LogShipping  Status 
		--- ********************************************************************************    
	--	IF (@Monitor_LogShipping_Status=1)
		--	Execute [SQLMantainence].[Monitor_LogShippingStatus]
	  
	  	--- ********************************************************************************
		--- 16. Check Replication  Status 
		--- ********************************************************************************    
	--	IF (@Monitor_Replication_Status=1)
	--		Execute [SQLMantainence].[Monitor_ReplicationStatus]
	  		  			  		 
	  	IF EXISTS(SELECT 1 FROM  tempdb.SYS.DATABASE_FILES A WITH(NOLOCK) where (A.SIZE/128.0) > 20480)
		BEGIN
			-- IF SIZE OF TEMPDB IS GREATER THAN 20 GB
			SELECT @STRERRORMESSSAGE += '<BR><BR><LI><FONT COLOR=RED><U>TEMPDB Data/Log file has grown huge i.e. > 20 GB</U></FONT>'
		END
  			  		 	  		  			  		  	
	END TRY
 
	BEGIN CATCH
		INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'MONITORING-ALERTS','Monitoring Alerts job failed, ErrOR Message: ' + ERROR_MESSAGE() ,'C');
		EXEC [SQLMantainence].[Log_Error] 'MonitoringAlerts','MONITORING-ALERTS'
		SELECT 'ERROR : ' + ERROR_MESSAGE()  -- debug line
	END CATCH 

	
	--SELECT @strErrorMesssage   --- DEBUG LINE

	IF @strErrorMesssage <> ''
	BEGIN
		DECLARE @Body VarChar(MAX)
		SET @Body  =  @strErrorMesssage + '</body></html>'
	
		EXECUTE msdb..sp_send_dbmail 
		@Profile_Name = 'DBMaintenance', 
		@Recipients = @Recipients ,    
		@Subject = @Subject,
		@Body_Format= 'HTML',
		@Body = @Body, 
		@Execute_Query_Database = 'SQL_ADMIN'	

		--SELECT @Body --- DEBUG LINE
	END         

END

GO

--******************************************
-- END of MonitoringAlert Stored Procedure 
--****************************************


/*
This SP captures database sizing details:
	SELECT * FROM SQL_ADMIN.[SqlMantainence].[DatabaseCatalogue] (NOLOCK) WHERE IsDeleted = 0

	SELECT TOP 50  * FROM  [SQL_ADMIN].[SQLMANTAINENCE].[HistoryOfDatabaseSize] (NOLOCK) 
	WHERE  DatabaseName = 'MDAR2'  
	ORDER BY AddedOn Desc, FileName ASC

	SELECT TOP 50  * FROM  [SQL_ADMIN].[SQLMANTAINENCE].[HistoryOfDatabaseTableSize] (NOLOCK) 
	WHERE  DatabaseName = 'MDAR2'  
	ORDER BY AddedOn Desc, FileName ASC

	SELECT * FROM SQL_ADMIN.SQLMantainence.SQLJobDetails_OnThisServer (NOLOCK)  WHERE IsDeleted = 0
 
*/
CREATE PROCEDURE [SQLMantainence].[UpdateDatabaseCatalogue]
-- With Encryption
AS

BEGIN
		SET NoCount On

		-- Update Database Creation date and owner name
			UPDATE [SqlMantainence].[DatabaseCatalogue] 
				SET  DatabaseName = dbs.name, [Owner] = usr.name, CreatedOn = dbs.create_date
				FROM sys.databases DBs WITH(NOLOCK) 
				Left Join [SqlMantainence].[DatabaseCatalogue] CTLG WITH(NOLOCK) ON dbs.database_id = ctlg.DatabaseID 
				INNER JOIN sys.syslogins usr WITH(NOLOCK) ON DBs.owner_sid = usr.sid
			WHERE IsDeleted = 0

			--	-- Update Deleted Database Flag
				UPDATE [SqlMantainence].[DatabaseCatalogue] 
				SET IsDeleted = 1, 
				DeletedOn = (Select Top 1 EventTime From master.dbo.PermissionAudit with(nolock) 
							Where EventType COLLATE DATABASE_DEFAULT  = 'Drop_Database' AND TSQLText COLLATE DATABASE_DEFAULT  Like '%' + DatabaseName + '%'
							Order By 1 Desc	
							),
				DeletedBy = (Select Top 1 ServerLogin From master.dbo.PermissionAudit with(nolock) 
							Where EventType COLLATE DATABASE_DEFAULT  = 'Drop_Database' AND TSQLText COLLATE DATABASE_DEFAULT  Like '%' + DatabaseName + '%'
							Order By 1 Desc	
							)
				WHERE DatabaseID  NOT IN (SELECT database_id FROM sys.databases WITH(NOLOCK)) AND IsDeleted = 0

				-- Add New Database added recently
			INSERT INTO [SqlMantainence].[DatabaseCatalogue] (DatabaseID, DatabaseName, Owner, IsDeleted, CreatedOn, CreatedBy)
				SELECT dbs.database_id,dbs.name, usr.name,0,dbs.create_date, 
				(
					Select Top 1 ServerLogin From master.dbo.PermissionAudit with(nolock) 
					Where EventType = 'Create_Database' AND TSQLText Like '%' + dbs.name + '%'
					Order By 1 Desc				
				)  
				FROM sys.databases DBs WITH(NOLOCK) Left Join sys.syslogins usr WITH(NOLOCK) ON DBs.owner_sid = usr.sid
				WHERE dbs.database_id NOT IN 
				(SELECT DatabaseID From [SqlMantainence].[DatabaseCatalogue] WITH(NOLOCK) Where IsDeleted = 0)
		-- End of Update Database Catalogue 


			-- Update SQL Job Catalogue
			-- Table [SQLMantainence].[SQLJobDetails_OnThisServer]
			UPDATE SQLMantainence.SQLJobDetails_OnThisServer
			SET JobName = JBS.NAME, Owner = USR.NAME, LastModifiedOn = JBS.date_modified, JobEnabled = enabled
			FROM SQLMantainence.SQLJobDetails_OnThisServer SQLJBS
			INNER JOIN MSDB.DBO.SYSJOBS jbs WITH(NOLOCK) ON JBS.JOB_ID = SQLJBS.JOBID
			Left Join sys.syslogins usr  WITH(NOLOCK) ON jBs.owner_sid = usr.sid
			WHERE IsDeleted = 0

			-- CHECK FOR DELETED JOBS
			UPDATE SQLMantainence.SQLJobDetails_OnThisServer
			SET IsDeleted = 1, DeletedOn = Cast(getdate() as Date) 
			WHERE JobID NOT IN (SELECT JOB_ID FROM MSDB.DBO.SYSJOBS WITH(NOLOCK))  AND IsDeleted = 0

			INSERT INTO SQLMantainence.SQLJobDetails_OnThisServer (JobID, JobName, Owner, CreatedOn, LastModifiedOn, IsDeleted ,JobEnabled)
				SELECT  job_id, jbs.NAME, usr.name, date_created,date_modified, 0, enabled 
				FROM MSDB.DBO.SYSJOBS jbs WITH(NOLOCK) Left Join sys.syslogins usr  WITH(NOLOCK) ON jBs.owner_sid = usr.sid
				WHERE job_id NOT IN (SELECT JobID From  SQLMantainence.SQLJobDetails_OnThisServer WITH(NOLOCK) WHERE IsDeleted = 0)
			-- End of  SQL Job Catalogue Update


			
			-- Start of Database Sizing Capture
			

			--run this for all database
			EXEC sp_MSforeachdb 'Use [?];
			INSERT INTO [SQL_ADMIN].[SQLMANTAINENCE].[HISTORYOFDATABASESIZE]
			SELECT  DB_ID(), DB_NAME(),GETDATE(),
				CASE B.GROUPID WHEN 0 THEN ''LOG FILE'' ELSE ''DATA FILE'' END AS ''FILETYPE'',
				A.NAME,	A.PHYSICAL_NAME AS FILENAME, CAST((A.SIZE/128.0) AS DECIMAL(11,2)) AS TOTALSPACEINMB,
				CAST((CAST(FILEPROPERTY(A.NAME, ''SPACEUSED'') AS DECIMAL(11,2))/128.0) AS DECIMAL(11,2)) AS USEDSPACEINMB,
				CAST((A.SIZE/128.0 - CAST(FILEPROPERTY(A.NAME, ''SPACEUSED'') AS DECIMAL(11,2))/128.0) AS DECIMAL(11,2)) AS FREESPACEINMB,
				(CAST((CAST(FILEPROPERTY(A.NAME, ''SPACEUSED'') AS DECIMAL(11,2))/128.0) AS DECIMAL(11,2)) * (100) /  CAST((A.SIZE/128.0) 
				AS DECIMAL(11,2)))  AS PERCENTAGE_SPACEAVAILABLE
			FROM  SYS.DATABASE_FILES A WITH(NOLOCK) INNER JOIN   MASTER.SYS.SYSALTFILES B WITH(NOLOCK) ON A.NAME=B.NAME COLLATE SQL_LATIN1_GENERAL_CP1_CI_AS'
			--Select * From sql_admin.[SQLMantainence].[HistoryOfDatabaseSize]


		-- ************************************************************************************
		 -- Last section is to capture daily Table Size for database that is marked as 
		 -- ************************************************************************************

		IF OBJECT_ID('SQLMANTAINENCE.HistoryOfDatabaseTableSize') IS NULL
		BEGIN
			CREATE TABLE SQLMANTAINENCE.HistoryOfDatabaseTableSize
			 (AddedOn DateTime, Databasename Varchar(200), TableName VARCHAR(200), NumberOfRows varchar(25), TotalTableSizeinKB varchar(25))
		END

			-- TEMPORARY TABLE CREATED FOR STORING INITIAL STATISTICS
		IF OBJECT_ID('TempDB.dbo.RowCountsAndSizes') IS NULL
			CREATE TABLE TempDB.dbo.RowCountsAndSizes (TableName NVARCHAR(128), Rows CHAR(11), 
			Reserved VARCHAR(18),Data VARCHAR(18),Index_Size VARCHAR(18), UnUsed VARCHAR(18))		
		ELSE
			TRUNCATE TABLE TempDB.dbo.RowCountsAndSizes

		DECLARE  @DBs Table(ID INT IDentity(1,1), DatabaseName varchar(200))
		INSERT INTO @DBs (DatabaseName)
		    SELECT a.Value FROM [SQL_ADMIN].SQLMantainence.DBMantainenceConfiguratiON a WITH(NOLOCK) 
			INNER JOIN sys.sysdatabases b WITH(NOLOCK) on a.Value COLLATE DATABASE_DEFAULT  = b.Name COLLATE DATABASE_DEFAULT 
		    WHERE a.ConfigurationType='DBNameForTrackingSpaceUsage' AND (a.VALUE NOT IN ('?','TempDB'))
		
		DECLARE @i int, @j int, @dbName varchar(200)
		SELECT @i = 1
		SELECT @j = count(*) FROM @DBs

		WHILE @i <= @j 
		 BEGIN
		    SELECT @dbName = DatabaseName From @DBs WHERE ID = @i

			Exec ('Use [' + @dbName + ']; EXEC sp_MSForEachTable ''INSERT INTO TempDB.dbo.RowCountsAndSizes EXEC sp_spaceused "?" ''
				;WITH TABLES_ROWS_AND_SIZE AS
				(
				SELECT TableName, NumberOfRows = CONVERT(bigint,rows), TotalTableSizeinKB = CONVERT(bigint,left(reserved,len(reserved)-3))
				FROM TempDB.dbo.RowCountsAndSizes WITH(NOLOCK)
				)
				INSERT INTO SQL_ADMIN.SQLMANTAINENCE.HistoryOfDatabaseTableSize 
				(AddedOn, DatabaseName, TableName, NumberOfRows, TotalTableSizeinKB)
				SELECT getDate(), DB_Name(), TableName,REPLACE(CONVERT(VARCHAR,CONVERT(MONEY,NumberOfRows),1), ''.00'','''')
					,REPLACE(CONVERT(VARCHAR,CONVERT(MONEY,TotalTableSizeinKB),1), ''.00'','''')
				FROM TABLES_ROWS_AND_SIZE WITH(NOLOCK)
				ORDER BY NumberOfRows DESC,TotalTableSizeinKB DESC,TableName')

			SET @i += 1
		 END  -- end of while loop
		 DROP TABLE TempDB.dbo.RowCountsAndSizes

		 --*******************************************************************
			-- End of Database Size Capturing
		--*******************************************************************
END
GO


--****************************************************************************************************
-- START PF STORED PROCEDURE [SQLMantainence].[MaintenanceLogCleanUp]
--****************************************************************************************************
 --****************************************************************************************************
-- The SP cleans up some of the SQL maintenance logs mentioned below
-- Table: MASTER.dbo.PermissionAudit (After 6 months)
-- Table: SQL_ADMIN.SQLMantainence.DBMantainenceLOG (After 6 months)
-- Log: MSDB.dbo.sp_delete_backuphistory (After 30 days)
-- Log: MSDB.dbo.sp_purge_jobhistory (After 30 days)
-- Log:  msdb.dbo.sysmail_delete_mailitems_sp (after 30 days)
-- Table: SQL_ADMIN.SQLMantainence.HistoryOfDatabaseSize (After 6 months)
-- Table: SQL_ADMIN.SQLMantainence.DatabaseCatalogue  (After 6 months)
-- Table: [Deadlock Details on this SQL Server] (After 6 months)
-- Table: [SQLMantainence].[Audit_DatabaseAutoGrowth] (after 3 months)
-- Table: [SQLMantainence].[Blocking_History] (after 1 months)
-- Table: [SQLMantainence].[TempDB_Contention_Details] (after 6 months) 
-- Table: [SQLMantainence].[TempDB_ReadWrite_HourlyStatistics] (after 3 months)
--****************************************************************************************************
CREATE PROCEDURE [SQLMantainence].[MaintenanceLogCleanUp]
-- With Encryption
AS
BEGIN
            SET NoCount On
                  -- DELETE ALL AUDIT CHANGES LOG ENTRIES OLDER THAN 6 MONTHS
            IF EXISTS(SELECT 1 FROM master.information_schema.tables WHERE table_name = 'PermissionAudit')
                 DELETE  FROM MASTER.dbo.PermissionAudit  WHERE EventTime < DateAdd(Month,-6, getdate())

            IF EXISTS(SELECT 1 FROM master.information_schema.tables WHERE table_name = 'EPOS2000Audit')
			BEGIN
                 DELETE  FROM MASTER.dbo.EPOS2000Audit  WHERE event_time < DateAdd(Month,-3, getdate())
				 DELETE  FROM MASTER.dbo.EPOS2000Audit  WHERE event_time < DateAdd(WEEK,-2, getdate()) AND table_name in ('StockTransferStatus','Banking')
			END
      
                  -- DELETE ALL MAINTENANCE LOG ENTRIES OLDER THAN 3 MONTHs
            DELETE  FROM SQL_ADMIN.SQLMantainence.DBMantainenceLOG  WHERE LogDate < DateAdd(Month,-3, getdate())

            DECLARE @DaysToKeepHistory DATETIME
            SET @DaysToKeepHistory = CONVERT(VarChar(10), DATEADD(dd, -30, GETDATE()), 101)
            
            DECLARE @DaysToKeepBackupHistoryInMSDB INT, @RetentionDateForBackupHistory DateTime
            
            IF EXISTS( SELECT 1 FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='DaysToKeepBackupHistoryInMSDB' )
                  SELECT @DaysToKeepBackupHistoryInMSDB=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  
                  WHERE configurationType='DaysToKeepBackupHistoryInMSDB'
            ELSE 
            BEGIN
                  INSERT [SqlMantainence].DBMantainenceConfiguration (configurationType, Value, IsDeleted)
                  values ('DaysToKeepBackupHistoryInMSDB', '365',0)
                  SELECT @DaysToKeepBackupHistoryInMSDB = 365
            END

            If ISNUMERIC(@DaysToKeepBackupHistoryInMSDB)= 0
                  SET @DaysToKeepBackupHistoryInMSDB = 365

            SET @RetentionDateForBackupHistory = CONVERT(VarChar(10), DATEADD(dd, -@DaysToKeepBackupHistoryInMSDB, GETDATE()), 101)

            -- This script below will remove the backup AND Restore history fOR all database 
            -- which are before the given date i.e. more than 30 days
            EXEC MSDB.dbo.sp_delete_backuphistory @RetentionDateForBackupHistory

            -- Delete SQL Job History
            Exec MSDB.dbo.sp_purge_jobhistory @oldest_date =  @DaysToKeepHistory

            -- Delete Mail Items sEND FROM SQL sever before ...
            --SELECT TOP 100 * FROM msdb.dbo.sysmail_mailitems
            Exec msdb.dbo.sysmail_delete_mailitems_sp @sent_before = @DaysToKeepHistory --,@sent_status ='sent'

                              -- DELETE ALL MAINTENANCE LOG ENTRIES OLDER THAN 6 MONTHs
            DELETE  FROM SQL_ADMIN.SQLMantainence.HistoryOfDatabaseSize  WHERE AddedOn < DateAdd(Month,-3, getdate())
            DELETE  FROM SQL_ADMIN.SQLMantainence.HistoryOfDatabaseTableSize  WHERE AddedOn < DateAdd(Month,-3, getdate())
            
            DELETE  FROM SQL_ADMIN.SQLMantainence.DatabaseCatalogue  WHERE IsDeleted = 1 AND DeletedOn < DateAdd(Month,-6, getdate())


      -- Table: [Deadlock Details on this SQL Server] (After 6 months)
            IF OBJECT_ID('SQLMantainence.Deadlock Details on this SQL Server') IS NOT NULL
                  DELETE  FROM SQLMantainence.[Deadlock Details on this SQL Server]  
                  WHERE DeadlockEventTime < DateAdd(Month,-6, getdate())

      -- Table: [SQLMantainence].[Audit_DatabaseAutoGrowth] (after 3 months)
            IF OBJECT_ID('SQLMantainence.Audit_DatabaseAutoGrowth') IS NOT NULL
                  DELETE  FROM [SQLMantainence].[Audit_DatabaseAutoGrowth]  
                  WHERE StartTime < DateAdd(Month,-3, getdate())

      -- Table: [SQLMantainence].[Blocking_History] (after 1 months)
            IF OBJECT_ID('SQLMantainence.Blocking_History') IS NOT NULL
                  DELETE  FROM [SQLMantainence].[Blocking_History]  
                  WHERE Blocking_DateTime < DateAdd(Month,-1, getdate())

      -- Table: [SQLMantainence].[TempDB_Contention_Details] (after 6 months) 
            IF OBJECT_ID('SQLMantainence.TempDB_Contention_Details') IS NOT NULL
                  DELETE  FROM [SQLMantainence].[TempDB_Contention_Details] 
                  WHERE TIMESTAMP < DateAdd(Month,-6, getdate())

      -- Table: [SQLMantainence].[TempDB_ReadWrite_HourlyStatistics] (after 3 months)
            IF OBJECT_ID('SQLMantainence.TempDB_ReadWrite_HourlyStatistics') IS NOT NULL            
                  DELETE  FROM [SQLMantainence].[TempDB_ReadWrite_HourlyStatistics] 
                  WHERE RefDate < DateAdd(Month,-3, getdate())

            -- ************************************************************************************
            -- SENDING EMAIL NOTIFICAITON FOR NEW SQL DATABASE OR JOBS CREATED IN THE CURRENT WEEK
            -- ************************************************************************************
            DECLARE @Database_Catalogue_Alert_Required int = 0
            SELECT @Database_Catalogue_Alert_Required  =  [VALUE]  
            FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) 
            WHERE configurationType = 'Database_Catalogue_Alert_Required'
            IF  ISNUMERIC(@Database_Catalogue_Alert_Required) = 0 -- IF FALSE
                  SELECT @Database_Catalogue_Alert_Required = '0' 

            IF @Database_Catalogue_Alert_Required = 1 
            BEGIN
                  Declare @HTML varchar(max) = ''  -- Used to capture new database created
                  Declare @HTML1 varchar(max) = ''  --Used to capture database deleted
                  Declare @HTML2 varchar(max) = ''  -- used to capture new sql jobs created
                  Declare @HTML3 varchar(max) = ''  -- used to capture sql jobs deleted

                  DECLARE @Body VarChar(MAX) = ''  -- Used to sent mail alert 

                  -- New Database created in last 7 days
                  IF EXISTS(SELECT 1 FROM [SQLMantainence].[DatabaseCatalogue] WITH(NOLOCK) WHERE DatabaseID > 4 AND CreatedOn >= dateadd(day,-7,getdate()))
                  BEGIN
                        SELECT @HTML = '<b>New Database created in last 7 days</b><table Width="100%" Border="1"><TR><TD><b>Database Name</TD><TD><b>Owner</TD><TD><b>Created By</TD><TD><b>Created On</TD></TR>'
      
                        SELECT @HTML += '<TR><TD>' + IsNull(DatabaseName,'') + '</TD><TD>' +  IsNull(Owner,'') + '</TD><TD>' + IsNull(CreatedBy,'')  + '</TD><TD>' + IsNull(Cast(CreatedOn as varchar(100)),'')  + '</TD></TR>'
                        FROM [SQLMantainence].[DatabaseCatalogue] WITH(NOLOCK) 
                        WHERE DatabaseID > 4 AND CreatedOn >= dateadd(day,-7,getdate()) 
                        ORDER BY DatabaseName

                        SELECT @HTML += '</TABLE>'
                  END

                  -- Database deleted in last 7 days
                  IF EXISTS(SELECT 1 FROM [SQLMantainence].[DatabaseCatalogue] WITH(NOLOCK) WHERE DatabaseID > 4 AND CreatedOn >= dateadd(day,-7,getdate()))
                  BEGIN
                        SELECT @HTML1 = '<b>Database deleted in last 7 days</b><table Width="100%" Border="1"><TR><TD>Database Name</TD><TD>Owner</TD><TD>Deleted By</TD><TD>Deleted On</TD><TD>Application</TD><TD>Other Details</TD></TR>'
      
                        SELECT @HTML1 += '<TR><TD>' + IsNull(DatabaseName,'') + '</TD><TD>' +  IsNull(Owner,'') + '</TD><TD>' + IsNull(DeletedBy,'')  + '</TD><TD>' + IsNull(Cast(DeletedOn as varchar(100)),'')  + '</TD><TD>' + IsNull(AppName,'') + '</TD><TD>' + IsNull(OtherDetails,'') + '</TD></TR>'
                        FROM [SQLMantainence].[DatabaseCatalogue] WITH(NOLOCK) 
                        WHERE DatabaseID > 4 AND IsDeleted = 1 AND DeletedOn >= dateadd(day,-7,getdate())
                        ORDER BY DatabaseName

                        SELECT @HTML1 += '</TABLE></HTML>'
                  END


            -- New SQL Jobs created in last 7 days
            IF EXISTS(SELECT 1 FROM [SQLMantainence].[SQLJobDetails_OnThisServer] WITH(NOLOCK) WHERE CreatedOn >= dateadd(day,-7,getdate()))
            BEGIN
                  SELECT @HTML2 = '<b>New SQL Jobs created in last 7 days</b><table Width="100%" Border="1"><TR><TD><b>Job Name</TD><TD><b>Owner</TD><TD><b>Created On</TD></TR>'
      
                  SELECT @HTML2 += '<TR><TD>' + IsNull(JobName,'') + '</TD><TD>' +  IsNull(Owner,'')   + '</TD><TD>' + IsNull(Cast(CreatedOn as varchar(100)),'')  + '</TD></TR>'
                  FROM [SQLMantainence].[SQLJobDetails_OnThisServer] WITH(NOLOCK) 
                  WHERE CreatedOn >= dateadd(day,-7,getdate()) 
                  ORDER BY JobName

                  SELECT @HTML2 += '</TABLE>'
            END

            -- SQL Jobs deleted in last 7 days
            IF EXISTS(SELECT 1 FROM [SQLMantainence].[SQLJobDetails_OnThisServer] WITH(NOLOCK) WHERE  CreatedOn >= dateadd(day,-7,getdate()))
            BEGIN
                  SELECT @HTML3 = '<b>SQL Jobs deleted in last 7 days</b><table Width="100%" Border="1"><TR><TD><b>Database Name</TD><TD><b>Owner</TD><TD><b>Deleted On</TD><TD><b>Application</TD><TD><b>Other Details</TD></TR>'
      
                  SELECT @HTML3 += '<TR><TD>' + IsNull(JobName,'') + '</TD><TD>' +  IsNull(Owner,'')  + '</TD><TD>' + IsNull(Cast(DeletedOn as varchar(100)),'')  + '</TD><TD>' + IsNull(AppName,'') + '</TD><TD>' + IsNull(OtherDetails,'') + '</TD></TR>'
                  FROM [SQLMantainence].[SQLJobDetails_OnThisServer] WITH(NOLOCK) 
                  WHERE  IsDeleted = 1 AND DeletedOn >= dateadd(day,-7,getdate())
                  ORDER BY JobName

                  SELECT @HTML3 += '</TABLE>'
            END

                  DECLARE @Environment VarChar (50), @EnvironmentDesc VarChar (50)
                  SELECT @Environment  =  [VALUE]  FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE configurationType = 'Environment'
                  SELECT @EnvironmentDesc  =  CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END

                  DECLARE @ACTUAL_IP_ADDRESS VarChar(1000)
                  CREATE TABLE #temp1(SQL_IP VarChar(3000))
                  INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 
                  DECLARE @IPAddress VarChar(300) 
                  SET @IPAddress  =  (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IPv4%' ORDER BY SQL_IP DESC)      
                  DECLARE @len INT 
                  SET @Len  =  CHARINDEX(':', @IPAddress) 
                  SELECT TOP 1  @ACTUAL_IP_ADDRESS =  LTRIM(RTRIM(SUBSTRING(@IPAddress, @Len+1, LEN(@IPAddress)))) 
                  DROP TABLE #temp1

                  DECLARE @SubJect varchar(1000) 
                  SELECT @Subject  =  UPPER(@EnvironmentDesc) + ' - Database Catalogue update on ' + @@SERVERNAME + ' (IP Address: ' + @ACTUAL_IP_ADDRESS + ')'
                  
                  DECLARE @Recipients varchar(1000) = 'SQL_ADMIN@ndsglobal.com'
                  --SELECT @Recipients  =  [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE configurationtype = 'EmailRecipient'

                  IF @HTML <> '' OR @HTML1 <> ''  OR @HTML2 <> ''  OR @HTML3 <> '' 
                  BEGIN
                        SET @BODY = '<HTML><BODY>' + @HTML +'<BR>' + @HTML1 +'<BR>' + @HTML2 +'<BR>' + @HTML3 + '</BODY></HTML>' 

                        EXECUTE msdb..sp_send_dbmail 
                              @Profile_Name  =  'DBMaintenance', 
                              @Recipients  =  @Recipients ,
                              @Subject  =  @Subject,
                              @Body_format =  'HTML',
                              @Body  =  @Body, 
                              @Execute_Query_Database  =  'SQL_ADMIN'   
                  END
            END  -- END OF IF @Database_Catalogue_Alert_Required = 1 
END
GO 
--****************************************************************************************************
-- END PF STORED PROCEDURE [SQLMantainence].[MaintenanceLogCleanUp]
--****************************************************************************************************



--****************************************************************************************************
-- Start of Check_DailyBackupFailures
--****************************************************************************************************

USE [SQL_ADMIN]
GO
/****** Object:  StoredProcedure [SQLMantainence].[Check_DailyBackupFailures]    Script Date: 11/27/2012 12:52:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
--  *******************************************************************************************************************************
-- Description: THIS PROCEDURE WILL CHECK WHETHER THERE IS ANY MISSING FULL / DIFF / TLOG BACKUP FOR THE DAY AND ALERT ACCORDINGLY.
1 = One time only
4 = Daily
8 = Weekly
16 = Monthly
32 = Monthly, relative to freq_interval
64 = Runs when the SQL Server Agent service starts

128 = Runs when the computer is idle 
--  *******************************************************************************************************************************
*/
CREATE PROCEDURE [SQLMantainence].[Check_DailyBackupFailures]
-- With Encryption
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Job_id_FullBackup UNIQUEIDENTIFIER
	DECLARE @Job_id_DifferentialBackup UNIQUEIDENTIFIER
	DECLARE @Job_id_TlogBackup UNIQUEIDENTIFIER
	DECLARE @Full_Backup_Day VarChar(100)
	DECLARE @Diff_Backup_Day VarChar(100)
	DECLARE @Tlog_Backup_Day VarChar(100)
	DECLARE @HTML VarChar (MAX)
	DECLARE @i INT 
	DECLARE @DBNAME VarChar(1000)
	DECLARE @Subject VarChar(1000)
	DECLARE @Freq_Interval INT
	DECLARE @Freq_SubDay_Type INT
	DECLARE @Freq_SubDay_Interval INT
	DECLARE @Freq_Relative_Interval INT
	DECLARE @Freq_Recurrence_FactOR INT
	DECLARE @Active_Start_Date INT 
	DECLARE @Active_End_Date INT 
	DECLARE @Active_StartTime INT 
	DECLARE @Active_EndTime INT
	DECLARE @Enabled INT, @JobEnabled INT  
	DECLARE @Freq_Type INT 
	DECLARE @ACTUAL_IP_ADDRESS VarChar(1000)
	DECLARE @Recipients VarChar(2000) 
	DECLARE @BackupMissedForDatabase VarChar(1000) = ''

	-- To detect the IP address of this machine fOR reporting purpose.
	CREATE TABLE #temp1(SQL_IP VarChar(3000))
	INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 	
	DECLARE @IPAddress VarChar(300) 
	SET @IPAddress  =  (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IPv4%' ORDER BY SQL_IP DESC) 	
	DECLARE @len INT 
	SET @Len  =  CHARINDEX(':', @IPAddress) 
	SELECT TOP 1  @ACTUAL_IP_ADDRESS =  LTRIM(RTRIM(SUBSTRING(@IPAddress, @Len+1, LEN(@IPAddress)))) 
	DROP TABLE #temp1
	
	DECLARE @Environment VarChar (50), @EnvironmentDesc VarChar (50)
	SELECT @Environment  =  [VALUE]  FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE configurationType = 'Environment'
	SELECT @EnvironmentDesc  =  CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END

	
	SELECT @HTML =  ''
	SELECT @Subject  =  UPPER(@EnvironmentDesc) + ' - SQL Server Backup failures on ' + @@SERVERNAME + ' (IP Address: ' + @ACTUAL_IP_ADDRESS + ')'
	SELECT @Recipients  =  [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE configurationtype = 'EmailRecipient'
	SELECT @Job_id_FullBackup =  job_id FROM msdb.dbo.sysjobs  WITH(NOLOCK) WHERE name = 'SQLMantainence_FullBackup'
	SELECT @Job_id_DifferentialBackup = job_id FROM msdb.dbo.sysjobs   WITH(NOLOCK) WHERE name = 'SQLMantainence_DiffBackup'
	SELECT @Job_id_TlogBackup = job_id  FROM msdb.dbo.sysjobs   WITH(NOLOCK) WHERE name = 'SQLMantainence_T-LogBackup'
	


	-- FOR DETECTING THE JOB SCHEDULE FOR FULL AND DIFFERENTIAL BACKUP
	    DECLARE @Tabl TABLE
		(schedule_id INT,schedulename VarChar(500),Enabled INT,Freqtype INT,Freqinterval INT,Freqsubday_type INT,
		Freq_subday_interval INT,Freq_rel_inetrvl INT,Freq_rec_fac INT ,Active_s_date INT ,Active_e_date INT ,Active_strt_time INT ,
		Active_end_time INT ,datecrted DATETIME,sched_desc VarChar(500),nxt_run_date INT ,nxt_run_time INT,scheduleid UNIQUEIDENTIFIER ,job_count INT )
	
	
	--*********************************************
	-- FOR DETECTING JOB SCHEDULE FOR FULL BACKUP
	--*********************************************
	SELECT @BackupMissedForDatabase = ''
	INSERT INTO @Tabl EXEC [msdb].[dbo].[sp_help_jobschedule] @Job_id_FullBackup
	
	SELECT @Freq_Interval = Freqinterval,@Freq_SubDay_Type = Freqsubday_type, @Freq_SubDay_Interval = Freq_subday_interval,@Freq_Relative_Interval = Freq_rel_inetrvl, @Freq_Recurrence_FactOR = Freq_rec_fac,@Active_Start_Date = Active_s_date,@Active_End_Date = Active_e_date, @Active_StartTime = Active_strt_time, @Active_EndTime = Active_end_time,@Freq_Type = Freqtype, @Enabled = Enabled  
	FROM @Tabl 
	WHERE UPPER(schedulename) LIKE '%MantainencePlanScriptForFullBackup%'
	
	SELECT @JobEnabled = Enabled 
	FROM msdb.dbo.sysjobs WITH(NOLOCK) 
	WHERE JOB_ID = @Job_id_FullBackup
	
	IF (@JobEnabled = 1 AND @Freq_Type<>4)
		SELECT @Full_Backup_Day = [SQL_ADMIN].[SQLMantainence].[udf_GetSchedule_DescriptionOfJob] (@Freq_Type,@Freq_Interval,@Freq_SubDay_Type,@Freq_SubDay_Interval,@Freq_Relative_Interval,@Freq_Recurrence_Factor,@Active_Start_Date,@Active_End_Date,@Active_StartTime,@Active_EndTime)	

	
	IF (@JobEnabled = 1 AND @Freq_Type = 4) OR ( @Full_Backup_Day IS NOT NULL AND @Full_Backup_Day LIKE + '%'+CAST(DATENAME(dw,CONVERT(VarChar(100),GETDATE(),101)) AS VarChar(400)) + '%')
	BEGIN	
		 DECLARE @Tab TABLE (RowNo INT  IDENTITY(1,1), dbname  VarChar(1000) COLLATE Database_DEFAULT )
		 INSERT INTO @Tab 
			SELECT Name FROM sys.Databases WITH(NOLOCK) WHERE NAME NOT IN  ('master','msdb','tempdb','model','distribution') AND source_database_id IS NULL AND Name NOT LIKE '%_TOBEDELETED%' AND  Name NOT IN (SELECT VALUE COLLATE Database_DEFAULT FROM [SQLMantainence].[DBMantainenceConfiguration]  WITH(NOLOCK) WHERE ConfigurationType = 'ExcludeDatabase')
			AND state_desc='ONLINE'

		SELECT  @i =  COUNT(*) FROM @Tab 

		WHILE (@i <> 0)
		BEGIN
			SELECT @DBNAME = dbname FROM @Tab  WHERE RowNo = @i
			IF NOT  EXISTS(SELECT TOP 1 TYPE FROM SQLMantainence.DBMantainenceLOG  WITH(NOLOCK) WHERE TYPE = 'FULL-BACKUP' AND CONVERT(VarChar(20),LogDate,101) = CONVERT(VarChar(20),GETDATE(),101) AND Status = 'I' AND LogDetails LIKE '%Full Backup Successfull%' AND UPPER(LTRIM(RTRIM(SUBSTRING(logdetails,CHARINDEX(':',logdetails,1)+1,LEN(logdetails))))) = UPPER(@DBNAME))
			  SET @BackupMissedForDatabase +=  '&nbsp;-&nbsp;' +  @DBNAME + '<BR>'

			SET @i = @i-1
		END	
		
		IF @BackupMissedForDatabase <> '' 
			SET @HTML += '<BR><LI><U>FULL Backup did not happen today on this server for below databases</U>:<BR>' + @BackupMissedForDatabase
    END
    
    
    --***************************************************
    -- FOR DETECTING JOB SCHEDULE FOR DIFFERENTIAL BACKUP
    --**************************************************	
    DELETE  FROM @Tabl
    SELECT @BackupMissedForDatabase = ''
    
    INSERT INTO @Tabl EXEC [msdb].[dbo].[sp_help_jobschedule] @Job_id_DifferentialBackup
	
	SELECT TOP 1 @Freq_Interval  =  Freqinterval,@Freq_SubDay_Type  =  Freqsubday_type, @Freq_SubDay_Interval = Freq_subday_interval,@Freq_Relative_Interval = Freq_rel_inetrvl, @Freq_Recurrence_FactOR = Freq_rec_fac,@Active_Start_Date = Active_s_date,@Active_End_Date = Active_e_date, @Active_StartTime = Active_strt_time, @Active_EndTime = Active_end_time,@Freq_Type = Freqtype, @Enabled = Enabled  
	FROM @Tabl 
	WHERE UPPER(schedulename) LIKE '%MantainencePlanScriptForDiffBackup%'
	
	SELECT @JobEnabled = Enabled 
	FROM msdb.dbo.sysjobs WITH(NOLOCK) 
	WHERE JOB_ID = @Job_id_DifferentialBackup
	
	IF (@JobEnabled = 1 AND @Freq_Type<>4)
		SELECT @Diff_Backup_Day = [SQL_ADMIN].[SQLMantainence].[udf_GetSchedule_DescriptionOfJob] (@Freq_Type,@Freq_Interval,@Freq_SubDay_Type,@Freq_SubDay_Interval,@Freq_Relative_Interval,@Freq_Recurrence_Factor,@Active_Start_Date,@Active_End_Date,@Active_StartTime,@Active_EndTime)	
	
	IF  (@JobEnabled = 1 AND @Freq_Type = 4) OR (@Diff_Backup_Day IS NOT NULL AND @Diff_Backup_Day LIKE + '%'+CAST(DATENAME(dw,CONVERT(VarChar(100),GETDATE(),101)) AS VarChar(400)) + '%')
	BEGIN
		DECLARE @Tab2 TABLE (RowNo INT  IDENTITY(1,1),dbname  VarChar(1000))
		INSERT INTO @Tab2 
		  SELECT Name FROM sys.Databases WITH(NOLOCK) WHERE NAME NOT IN  ('master','msdb','tempdb','model','distribution') AND source_database_id IS NULL AND Name NOT LIKE '%_TOBEDELETED%' AND Name NOT IN (SELECT VALUE COLLATE Database_DEFAULT FROM [SQLMantainence].[DBMantainenceConfiguration]  WITH(NOLOCK) WHERE ConfigurationType = 'ExcludeDatabase')
		  AND state_desc='ONLINE'

		SELECT  @i =  COUNT(*) FROM @Tab2

		WHILE (@i <> 0)
		BEGIN
			SELECT @DBNAME = dbname FROM @Tab2  WHERE RowNo = @i
			IF NOT  EXISTS(SELECT TOP 1 TYPE FROM SQLMantainence.DBMantainenceLOG  WITH(NOLOCK) WHERE TYPE = 'DIFFERENTIAL-BACKUP' AND CONVERT(VarChar(20),LogDate,101) = CONVERT(VarChar(20),GETDATE(),101) AND Status = 'I' AND LogDetails LIKE '%Differential Backup Successfull%'	 AND UPPER(LTRIM(RTRIM(SUBSTRING(logdetails,CHARINDEX(':',logdetails,1)+1,LEN(logdetails))))) = UPPER(@DBNAME))
			   SET @BackupMissedForDatabase +=  '&nbsp;-&nbsp;' +  @DBNAME + '<BR>'
			
			SET @i = @i-1
		END	
		
		IF @BackupMissedForDatabase <> '' 
			SET @HTML += '<BR><LI><U>DIFFERENTIAL Backup did not happen today ON this server fOR below databases</U>:<BR>' + @BackupMissedForDatabase
				
    END
    
     --***************************************************
    -- FOR DETECTING JOB SCHEDULE FOR TLOG BACKUP
     --***************************************************
    DELETE  FROM @Tabl
    SELECT @BackupMissedForDatabase = ''
    
    INSERT INTO @Tabl EXEC [msdb].[dbo].[sp_help_jobschedule] @Job_id_TlogBackup

	SELECT @Freq_Interval = Freqinterval,@Freq_SubDay_Type = Freqsubday_type, @Freq_SubDay_Interval = Freq_subday_interval,@Freq_Relative_Interval = Freq_rel_inetrvl,@Freq_Recurrence_FactOR = Freq_rec_fac,@Active_Start_Date = Active_s_date,@Active_End_Date = Active_e_date,@Active_StartTime = Active_strt_time,@Active_EndTime = Active_end_time,@Freq_Type = Freqtype, @Enabled = Enabled  
	FROM @Tabl 
	WHERE UPPER(schedulename) LIKE '%MantainencePlanScriptForTLogBackup%'

	SELECT @JobEnabled = Enabled 
	FROM msdb.dbo.sysjobs WITH(NOLOCK) 
	WHERE JOB_ID = @Job_id_TlogBackup

	
	IF (@JobEnabled = 1 AND @Freq_Type<>4)
		SELECT @Tlog_Backup_Day = [SQL_ADMIN].[SQLMantainence].[udf_GetSchedule_DescriptionOfJob] (@Freq_Type,@Freq_Interval,@Freq_SubDay_Type,@Freq_SubDay_Interval,@Freq_Relative_Interval,@Freq_Recurrence_Factor,@Active_Start_Date,@Active_End_Date,@Active_StartTime,@Active_EndTime)	

	IF (@JobEnabled = 1 AND @Freq_Type = 4) OR (@Tlog_Backup_Day IS NOT NULL AND @Tlog_Backup_Day LIKE + '%'+CAST(DATENAME(dw,CONVERT(VarChar(100),GETDATE(),101)) AS VarChar(400)) + '%')
	BEGIN
		DECLARE @Tab3 TABLE ( RowNo INT  IDENTITY(1,1), dbname  VarChar(1000))
		INSERT INTO @Tab3 
		    SELECT Name FROM sys.Databases WITH(NOLOCK) 
		    WHERE NAME NOT IN  ('master','msdb','tempdb','model','distribution') AND source_database_id IS NULL AND Name NOT LIKE '%_TOBEDELETED%' AND Recovery_Model_Desc  =  'FULL' AND Name NOT IN (SELECT VALUE COLLATE Database_DEFAULT FROM [SQLMantainence].[DBMantainenceConfiguration] WITH(NOLOCK) WHERE ConfigurationType = 'ExcludeDatabase')
		    AND state_desc='ONLINE'

		SELECT  @i =  COUNT(*) FROM @Tab3

		-- No need to check TLOG backup status between 12 am and 1 am ...since TLOG is stopped during that time
		IF DatePart(hour,GETDATE()) > 0 
		BEGIN
			WHILE (@i <> 0)
			BEGIN
				SELECT @DBNAME = dbname FROM @Tab3 WHERE RowNo = @i
				IF NOT  EXISTS(SELECT TOP 1  Database_Name FROM msdb.dbo.backupSET  WITH(NOLOCK) WHERE TYPE = 'L' AND CONVERT(VarChar(20),backup_finish_date,101) = CONVERT(VarChar(20),GETDATE(),101) AND Database_Name  =  @DBNAME)
				  SET @BackupMissedForDatabase +=  '&nbsp;-&nbsp;' +  @DBNAME  + '<BR>'

				SET @i = @i-1
			END		--END OF WHILE LOOP	
		END -- END OF IF CONDITION FOR TLOG TIME CHECK
				
		IF @BackupMissedForDatabase <> '' 
			SET @HTML += '<BR><LI><U>TLOG Backup did not happen today on this server for below databases</U>:<BR>' + @BackupMissedForDatabase
			
    END
    
    -- IF ANY BACKUP HAS NOT HAPPENED? THEN SENT EMAIL 
    IF @HTML <> ''
	BEGIN
		DECLARE @Body VarChar(MAX)
		SET @Body   =   '<HTML><BODY>' + @HTML + '</BODY></HTML>'
		
		EXECUTE msdb..sp_send_dbmail 
			@Profile_Name  =  'DBMaintenance', 
			@Recipients  =  @Recipients ,
			@Subject  =  @Subject,
			@Body_format =  'HTML',
			@Body  =  @Body, 
			@Execute_Query_Database  =  'SQL_ADMIN'		 
	END   
	ELSE
		PRINT 'ALL SCHEDULE BACKUPS TODAY WERE SUCCESSFULL'

END
GO


USE [SQL_ADMIN]
GO

/****** Object:  StoredProcedure [SQLMantainence].[UpdateStatisticsForAllDatabases]    Script Date: 9/16/2014 3:54:30 PM ******/

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [SQLMantainence].[UpdateStatisticsForAllDatabases]
   @IsDebug BIT = 1	
-- With Encryption
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @CurrentDBName VarChar(200)
	DECLARE @iRow INT
	DECLARE @TotalRows INT
	DECLARE @tblDatabasesToUpdateStats TABLE (ID INT, DBName VarChar(1000))

	BEGIN TRY		

			-- GETTING A LIST OF DATABASE WHICH NEED TO BE BACKED UP ...I.E. TLOG BACKUP
			-- ALL SYSTEM DATABASE, OFFLINE AND SIMPLE RECOVERY MODEL DATABASE AND ALSO DATABASE WHICH ARE MARKED AS "_TOBEDELETED" ARE IGNORED	
		INSERT INTO @tblDatabasesToUpdateStats
		   SELECT RowNum = ROW_NUMBER() OVER(ORDER BY Name), Name 
		   FROM SYS.databases  WITH(NOLOCK) 
		   WHERE  Is_Read_Only = 0 AND State_Desc = 'ONLINE' AND Is_In_StandBy = 0 AND Database_ID > 4 AND Name NOT LIKE '%_TOBEDELETED%'
		   AND Name NOT IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM SQL_ADMIN.SQLMantainence.DBMantainenceConfiguratiON WITH(NOLOCK) WHERE CONFIGURATIONTYPE = 'ExcludeDatabase' AND IsDeleted = 0)
				   	   
  		SELECT @iRow = 1, @TotalRows = Count(*) FROM @tblDatabasesToUpdateStats 
  		WHILE @iRow <= @TotalRows 
		BEGIN 
			SELECT @CurrentDBName = DBName FROM @tblDatabasesToUpdateStats WHERE ID = @iRow
			
			-- FIRST CHECKING WHETHER THE DATABASE IS BEING EXCLUDED FROM MABIGINTENANCE...E.G. ARCHIVE DATABASE WHICH NEED NOT BE BACKED UP
			IF NOT EXISTS(SELECT * FROM SQLMantainence.DBMantainenceConfiguratiON WITH(NOLOCK) WHERE ConfigurationType='ExcludeDatabase' AND VALUE=@CurrentDBName)
			BEGIN
				IF @IsDebug = 1 PRINT QuoteName(Cast(@iRow as VarChar(100)) + '/' +  Cast(@TotalRows as VarChar(100))) + 'Updating Statistics fOR Database ' + QuoteName(@CurrentDBName)	
				IF @IsDebug = 1 PRINT ' '	
				EXEC('USE [' + @CurrentDBName + ']; EXEC SP_UpdateStats @resample = ''resample''')			
			END
			
			SELECT @iRow += 1  -- i.e. to move to next row in the database list
		END   -- END of While Loop
				   
	END TRY
	
	BEGIN CATCH
		IF ERROR_NUMBER() > 0	
		BEGIN
			IF @IsDebug = 1 PRINT ERROR_MESSAGE()
		END	
	END CATCH

END
GO


USE [SQL_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- ==============================================================================================================
--  Exec [SQLMantainence].[proc_DeleteOldTLOGBackups]  '2','C:\Temp\Backups\TLOG',2
-- ==============================================================================================================

--******************************************************************************************************************************
-- This job will run every time TLOG backup runs and will delete all old TLOG backups which are older 
-- than retention days set for TLOG backups in configuration table.
--******************************************************************************************************************************
CREATE PROCEDURE [SQLMantainence].[proc_DeleteOldTLOGBackups]
(
@DatabaseName VarChar(1000),
@TLOGBackupFolder  VarChar(1000),
@RetentionPeriodForTLOGBackupsInDays INT
)
-- With Encryption
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @CmdStrSourceInfo VarChar(1000)

	DECLARE @CmdStrSource VarChar (2000)

	DECLARE @TLOGBackupFolderType VarChar (2000)

	DECLARE @i BIGINT

	DECLARE @j BIGINT  

	DECLARE @filedate VarChar(5000)

	DECLARE @filename VarChar(5000)

	DECLARE @filetype VarChar(100)

	DECLARE @fileRetentionDate DATETIME

	DECLARE @inpath VarChar(1000)

	DECLARE @filestatus VarChar(2000)

	DECLARE @total BIGINT



	CREATE TABLE #DirFileSourceInfo(DirFileInfo VarChar(2000))

	CREATE TABLE #DirFileSource(DirFile VarChar(2000))

	CREATE TABLE #FilesSource( [RowNo] BIGINT,[FileName] VarChar(2000),[FileType] VarChar(2000),[FileModIfiedDate] VarChar(50), [FileSize] BIGINT )



	BEGIN TRY

		SELECT @CmdStrSourceInfo = 'dir /O-S /-C /A-D "' + @TLOGBackupFolder + '"'        
		SELECT @CmdStrSource = 'dir /B "' + @TLOGBackupFolder + '"'  

		INSERT INTO #DirFileSourceInfo (DirFileInfo) EXEC xp_cmdshell @CmdStrSourceInfo  

		UPDATE [#DirFileSourceInfo] SET [DirFileInfo] = @TLOGBackupFolderType WHERE [DirFileInfo] IS NULL    

		INSERT INTO [#DirFileSource]([DirFile])  EXEC xp_cmdshell @CmdStrSource  

		INSERT INTO #FilesSource([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )      

			SELECT ROW_NUMBER() OVER (ORDER BY df.[DirFile]) AS RowNo , 

			REVERSE(RIGHT(REVERSE(df.[DirFile]),LEN(df.[DirFile])-CHARINDEX('.',REVERSE(df.[DirFile])))),

			REVERSE(SUBSTRING(REVERSE( df.[DirFile]), 1, CHARINDEX('.', REVERSE( df.[DirFile]))-1)),

			CONVERT(VarChar(50), LEFT([DirFileInfo], 17)),

			(RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 2, (CHARINDEX(' ', REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 2) - LEN(df.[DirFile]) + 2))))))    

			FROM #DirFileSourceInfo dfi WITH(NOLOCK) INNER JOIN [#DirFileSource] df  WITH(NOLOCK) ON LEFT(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile])) = REVERSE(df.DirFile)

			WHERE  SUBSTRING(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 1, 1) = ' '  

			AND LEFT((SUBSTRING(df.[DirFile],1,CHARINDEX('@',df.[DirFile])-1)),(LEN(@DatabaseName) + 1))=(@DatabaseName)

		Declare @UKDateFormatIssue BIT = 0
		If EXISTS (SELECT 1 FROM SQLMantainence.DBMantainenceConfiguration WITH(NOLOCK) WHERE configurationType = 'UKDateFormatIssueExists' AND (VALUE IN ('1','Y','True','T','Yes'))) 
			SET @UKDateFormatIssue = 1


		SET @total=0
		SELECT @i=  COUNT(*) FROM #FilesSource
		SET @j=1

		WHILE(@j  <= @i)
		BEGIN 

		  SELECT @filedate=[FileModIfiedDate] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		  
		  IF @UKDateFormatIssue = 1
			SELECT @FILEDATE=CONVERT(DATETIME, @FILEDATE,103)    -- UK DATE FORMAT
		  ELSE IF IsDate(@filedate) = 1  
			  SELECT @FILEDATE=CONVERT(DATETIME, @FILEDATE,101)   -- US DATE FORMAT
		  ELSE  -- ELSE IS NOT EXPECTED...
  		     SELECT @FILEDATE = SUBSTRING(@FILEDATE,7,4) + '/' + SUBSTRING(@FILEDATE,4,2) + '/' + LEFT(@FILEDATE,2)  
	 
		   SELECT @filename =[FileName] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j

		   SELECT @filetype= [FileType] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j

		   SELECT @fileRetentionDate = DATEADD (dd,@RetentionPeriodForTLOGBackupsInDays,CONVERT(DATETIME,@filedate,101)) 



		   IF(CONVERT(DATE,@fileRetentionDate,101) <= CONVERT(DATE,GETDATE(),101))

			BEGIN

			 BEGIN TRY

			   SET @inpath = 'del  /Q "'+@TLOGBackupFolder+'\'+@filename+'.'+@filetype+'"'

			   EXEC  master..xp_cmdshell @inpath, NO_OUTPUT

			   PRINT 'FULL- EXEC  master..xp_cmdshell ' + @inpath

			   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'DELETION-TLOG-BACKUP','Successfully deleted  TLOG BACKUP file for the database: '+@filename,'I');

			 END TRY

			 BEGIN CATCH

			   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'DELETION-TLOG-BACKUP','Could not delete TLOG BACKUP file for the database: '+@filename,'C');

			 END CATCH

			END   

		   SET @j=@j+1;

		END  -- end of while loop
	END TRY



	BEGIN CATCH
	   print error_message()
		EXEC [SQLMantainence].[Log_Error] 'proc_DeleteOldTLOGBackups','DELETE-TLOG-BACKUP'

	END CATCH  
	

		DROP TABLE  #DirFileSourceInfo

		DROP TABLE  #DirFileSource

		DROP TABLE #FilesSource 

END
GO

USE [SQL_ADMIN]
GO

/****** Object:  StoredProcedure [SQLMantainence].[proc_DeleteOldFullBackups]    Script Date: 11/25/2012 12:27:46 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


--******************************************************************************************************************************
--SECTION 1 = DELETE FULL BACKUP AFTER GIVEN RETENTION PERIOD
--SECTION 2 = DELETE DIFF BACKUP AFTER GIVEN RETENTION PERIOD AND also all diff backup associated with the deleted full backup
-- This job will run every time FULL backup runs and will delete all old FULL and DIFF backups which are older 
-- than retention days set for FULL and DIFF backups in configuration table.
-- FYI - TLOG backups are deleted using seperate job that runs every day
/* EXECUTE [SQLMANTAINENCE].[PROC_DELETEOLDFULLBACKUPS] 'sql_admin','H:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backups\FULL',				'H:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backups\DIFF', 15,14*/
--******************************************************************************************************************************
CREATE PROCEDURE [SQLMantainence].[proc_DeleteOldFullBackups]
(
@DatabaseName VarChar(1000),
@FullBackupFolder  VarChar(1000),
@DIffBackupFolder  VarChar(1000),
@RetentionPeriodForFullBackupsInDays INT,
@RetentionPeriodForDiffBackupsInDays INT

)
 -- With Encryption
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @CmdStrSourceInfo VarChar(1000)
	DECLARE @CmdStrSource VarChar (2000)
	DECLARE @FullBackupFolderType VarChar (2000)
	DECLARE @i BIGINT
	DECLARE @j BIGINT  
	DECLARE @filedate VarChar(5000)
	DECLARE @filename VarChar(5000)
	DECLARE @filetype VarChar(100)
	DECLARE @fileRetentionDate DATETIME
	DECLARE @inpath VarChar(1000)
	DECLARE @filestatus VarChar(2000)
	DECLARE @total BIGINT
	--******************************************************************************************************************************
	-- START OF SECTION 1 I.E. DELETE OF FULL BACKUP
	--******************************************************************************************************************************
	CREATE TABLE #DirFileSourceInfo(DirFileInfo VarChar(2000))
	CREATE TABLE #DirFileSource(DirFile VarChar(2000))
	CREATE TABLE #FilesSource( [RowNo] BIGINT,[FileName] VarChar(2000),[FileType] VarChar(2000),[FileModIfiedDate] VarChar(50), [FileSize] BIGINT )

	BEGIN TRY
		SELECT @CmdStrSourceInfo = 'dir /O-S /-C /A-D "' + @FullBackupFolder + '"'        
		SELECT @CmdStrSource = 'dir /B "' + @FullBackupFolder + '"'  

		INSERT INTO #DirFileSourceInfo (DirFileInfo) EXEC xp_cmdshell @CmdStrSourceInfo  
		UPDATE [#DirFileSourceInfo] SET [DirFileInfo] = @FullBackupFolderType WHERE [DirFileInfo] IS NULL    
		INSERT INTO [#DirFileSource]([DirFile])  EXEC xp_cmdshell @CmdStrSource  
		INSERT INTO #FilesSource([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )      
			SELECT ROW_NUMBER() OVER (ORDER BY df.[DirFile]) AS RowNo , 
			REVERSE(RIGHT(REVERSE(df.[DirFile]),LEN(df.[DirFile])-CHARINDEX('.',REVERSE(df.[DirFile])))),
			REVERSE(SUBSTRING(REVERSE( df.[DirFile]), 1, CHARINDEX('.', REVERSE( df.[DirFile]))-1)),
			CONVERT(VarChar(50), LEFT([DirFileInfo], 17)),
			(RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 2, (CHARINDEX(' ', REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 2) - LEN(df.[DirFile]) + 2))))))    
			FROM #DirFileSourceInfo dfi WITH(NOLOCK) INNER JOIN [#DirFileSource] df  WITH(NOLOCK) ON LEFT(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile])) = REVERSE(df.DirFile)
			WHERE  SUBSTRING(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 1, 1) = ' '  
			AND LEFT((SUBSTRING(df.[DirFile],1,CHARINDEX('@',df.[DirFile])-1)),(LEN(@DatabaseName) + 1))=(@DatabaseName)
		Declare @UKDateFormatIssue BIT = 0
		If EXISTS (SELECT 1 FROM SQLMantainence.DBMantainenceConfiguration WITH(NOLOCK) WHERE configurationType = 'UKDateFormatIssueExists' AND (VALUE IN ('1','Y','True','T','Yes'))) 
			SET @UKDateFormatIssue = 1

		SET @total=0		SELECT @i=  COUNT(*) FROM #FilesSource		SET @j=1
		WHILE(@j <= @i)
		BEGIN 
		  -- SELECT @filedate=CONVERT(DATETIME,[FileModIfiedDate],101) FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j		  
		  
		  SELECT @filedate=[FileModIfiedDate] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		  
		  IF @UKDateFormatIssue = 1
			SELECT @FILEDATE=CONVERT(DATETIME, @FILEDATE,103)    -- UK DATE FORMAT
		  ELSE IF IsDate(@filedate) = 1  
			  SELECT @FILEDATE=CONVERT(DATETIME, @FILEDATE,101)   -- US DATE FORMAT
		  ELSE  -- ELSE IS NOT EXPECTED...
  		     SELECT @FILEDATE = SUBSTRING(@FILEDATE,7,4) + '/' + SUBSTRING(@FILEDATE,4,2) + '/' + LEFT(@FILEDATE,2)  

		   SELECT @filename =[FileName] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @filetype= [FileType] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @fileRetentionDate = DATEADD (dd,@RetentionPeriodForFullBackupsInDays,CONVERT(DATETIME,@filedate,101)) 

		   IF(CONVERT(DATE,@fileRetentionDate,101) <= CONVERT(DATE,GETDATE(),101))
			BEGIN
			 BEGIN TRY
			   SET @inpath = 'del  /Q "'+@FullBackupFolder+'\'+@filename+'.'+@filetype+'"'
			   EXEC  master..xp_cmdshell @inpath, NO_OUTPUT
			   PRINT 'FULL- EXEC  master..xp_cmdshell ' + @inpath
			   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'DELETION-FULL-BACKUP','Successfully deleted  FULLBACKUP file fOR the database: '+@filename,'I');
			 END TRY
			 BEGIN CATCH
			   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'DELETION-FULL-BACKUP','Could not delete FULLBACKUP file fOR the database: '+@filename,'C');
			 END CATCH
			END   
		   SET @j=@j+1;
		END

		--******************************************************************************************************************************
		-- END Of SectiON 1
		--******************************************************************************************************************************

		TRUNCATE TABLE #DirFileSource
		TRUNCATE TABLE #DirFileSourceInfo
		TRUNCATE TABLE #FilesSource
		--******************************************************************************************************************************
		-- START OF SECTION 2 I.E. DELETE OF DIFF BACKUP
		--******************************************************************************************************************************


		SELECT @CmdStrSourceInfo = 'dir /O-S /-C /A-D "' + @DIffBackupFolder + '"'        
		SELECT @CmdStrSource = 'dir /B "' + @DIffBackupFolder + '"'  


		INSERT INTO #DirFileSourceInfo (DirFileInfo) EXEC xp_cmdshell @CmdStrSourceInfo  
		UPDATE [#DirFileSourceInfo] SET [DirFileInfo] = @FullBackupFolderType WHERE [DirFileInfo] IS NULL    
		INSERT INTO [#DirFileSource]([DirFile])  EXEC xp_cmdshell @CmdStrSource  
		INSERT INTO #FilesSource([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )      
			SELECT ROW_NUMBER() OVER (ORDER BY df.[DirFile]) AS RowNo , 
			REVERSE(RIGHT(REVERSE(df.[DirFile]),LEN(df.[DirFile])-CHARINDEX('.',REVERSE(df.[DirFile])))),
			REVERSE(SUBSTRING(REVERSE( df.[DirFile]), 1, CHARINDEX('.', REVERSE( df.[DirFile]))-1)),
			CONVERT(VarChar(50), LEFT([DirFileInfo], 17)),
			(RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 2, (CHARINDEX(' ', REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 2) - LEN(df.[DirFile]) + 2))))))    
			FROM #DirFileSourceInfo dfi  WITH(NOLOCK) INNER JOIN [#DirFileSource] df  WITH(NOLOCK) ON LEFT(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile])) = REVERSE(df.DirFile)
			WHERE  SUBSTRING(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 1, 1) = ' '  
			AND LEFT((SUBSTRING(df.[DirFile],1,CHARINDEX('@',df.[DirFile])-1)),(LEN(@DatabaseName) + 1))=(@DatabaseName)


		SET @total=0
		SELECT @i=  COUNT(*) FROM #FilesSource WITH(NOLOCK) 
		SET @j=1
		WHILE(@j <= @i)
		BEGIN 
--		   SELECT @filedate=CONVERT(DATETIME,[FileModIfiedDate],101) FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j		  


SELECT @filedate=[FileModIfiedDate] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		  
		  IF @UKDateFormatIssue = 1
			SELECT @FILEDATE=CONVERT(DATETIME, @FILEDATE,103)    -- UK DATE FORMAT
		  ELSE IF IsDate(@filedate) = 1  
			  SELECT @FILEDATE=CONVERT(DATETIME, @FILEDATE,101)   -- US DATE FORMAT
		  ELSE  -- ELSE IS NOT EXPECTED...
  		     SELECT @FILEDATE = SUBSTRING(@FILEDATE,7,4) + '/' + SUBSTRING(@FILEDATE,4,2) + '/' + LEFT(@FILEDATE,2)  

		   SELECT @filename =[FileName] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @filetype= [FileType] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @fileRetentionDate = DATEADD (dd,@RetentionPeriodForDiffBackupsInDays,CONVERT(DATETIME,@filedate,101)) 
		   
		   IF(CONVERT(DATE,@fileRetentionDate,101) <= CONVERT(DATE,GETDATE(),101))
			BEGIN
			 BEGIN TRY
			   SET @inpath = 'del  /Q "'+ @DIffBackupFolder +'\'+@filename+'.'+@filetype+'"'
			   EXEC master..xp_cmdshell @inpath, NO_OUTPUT
			   PRINT 'DIFF - EXEC master..xp_cmdshell ' + @inpath
			   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'DELETION-DIFFERENTIAL-BACKUP','Successfully deleted  DIFFERENTIAL Backup file fOR the database: '+@filename,'I');
			 END TRY
			 BEGIN CATCH
			   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'DELETION-DIFFERENTIAL-BACKUP','Could not delete  DIFFERENTIAL Backup file fOR the database: '+@filename,'C');
			 END CATCH
			END
		   
		   SET @j=@j+1;
		END
		
		-- END Of SectiON 2

	END TRY

	BEGIN CATCH        PRINT ERROR_MESSAGE()
		EXEC [SQLMantainence].[Log_Error] 'proc_DeleteOldFullBackups','DELETE-FULL-BACKUP'
	END CATCH  
		DROP TABLE  #DirFileSourceInfo
		DROP TABLE  #DirFileSource
		DROP TABLE #FilesSource 
END  -- END OF DELETE FULL BACKUP PROC

GO

-- END OF DELETE OLD BACKUP FILES I.E.AFTER RETENTION PERIOD
-- *****************************************************************************************************


-- ***************************************************************************************************
-- BEGIN OF FULL BACKUP SCRIPT BELOW
-- ***************************************************************************************************

USE [SQL_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
	Author: Suji Nair
	DETAILS: SECOND FULL BACKUP JOB WILL TAKE FULL BACKUP FOR HIGHLIGHTED DATABASES IN CONFIGURATION TABLE AS "DatabaseName_ForSecondBackupJob" 
*/
CREATE PROCEDURE  [SQLMantainence].[SP_MantainencePlanScriptForFullBackup_ForSecondBackupJob] 
 -- With Encryption
AS
BEGIN
	SET NOCOUNT ON;
	
	
    DECLARE @LAST_FULLBACKUP_DATE VARCHAR(100)
    DECLARE @FULL_BACKUPFOLDER VARCHAR(1000)
    DECLARE @DIFF_BACKUPFOLDER VARCHAR (1000)
    DECLARE @TLOG_BACKUPFOLDER VARCHAR(1000)
    DECLARE @EMAILRECIPIENT VARCHAR (2000)
    DECLARE @ENVIRONMENT VARCHAR(50), @ENVIRONMENTDESC VARCHAR (50)
    DECLARE @DBNAME VARCHAR(200)
    DECLARE @MINIMUMDISKSPACEFORBACKUP BIGINT
    DECLARE @SQL VARCHAR(1000)
    DECLARE @FREESPACE FLOAT =0
	DECLARE @TOTALSPACE FLOAT = 0
	DECLARE @FREESPACEINPERCENTAGE INT = 0
    DECLARE @RETENTIONPERIODFORFULLBACKUPINDAYS INT
	DECLARE @RETENTIONPERIODFORDIFFBACKUPINDAYS INT
    --DECLARE @FULLBACKUPSCHEDULEINDAYS INT
    DECLARE @FLAG_FORMSDB BIT    
	DECLARE @ACTUAL_IP_ADDRESS VARCHAR(1000)  
	DECLARE @BACKUPDRIVE VARCHAR(50)
    DECLARE @ERRORMESSAGE VARCHAR(MAX) ,
              @FORMATTEDERRORMESSAGE  VARCHAR(MAX),
              @ERRORNUMBER VARCHAR(50),
              @ERRORSEVERITY VARCHAR(50),
              @ERRORSTATE  VARCHAR(50),
              @ERRORLINE  VARCHAR(50),
              @ERRORPROCEDURE  VARCHAR(200)
    DECLARE @SUBJECT VARCHAR(1000)          
    DECLARE @IROW SMALLINT, @TOTALROWS SMALLINT
	Declare @iAllowBackupOnDatabase BIT   -- for database included for Always On
	--for backup at Azure storage
	DECLARE @Full_BackupFolderAzure VARCHAR(100) ,
			@Diff_BackupFolderAzure VARCHAR(100), 
			@AzureBackupContainer VARCHAR(1000)

	-- *****************************************************************************************************
             -- TO GET THE IP ADDRESS OF THE SERVER WHERE THE JOB IS BEING EXECUTED I.E. FOR REPORTING PURPOSE
	-- *****************************************************************************************************
	CREATE TABLE #TEMP1(SQL_IP VARCHAR(3000))
	INSERT INTO #TEMP1 EXECUTE XP_CMDSHELL 'IPCONFIG' 
	DECLARE @IPADDRESS VARCHAR(300) 
	SET @IPADDRESS = (SELECT TOP 1 SQL_IP FROM #TEMP1  WITH(NOLOCK)  WHERE SQL_IP LIKE '%IPV4%' ORDER BY SQL_IP DESC) 
	If @IPAddress IS NULL
		SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IP Address%' ORDER BY SQL_IP DESC) 	
	
	SET @IPAddress = IsNull(@IPAddress,'')

	DECLARE @LEN INT 
	SET @LEN = CHARINDEX(':', @IPADDRESS) 
	SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPADDRESS, @LEN+1, LEN(@IPADDRESS)))) 
	DROP TABLE #TEMP1 
	-- *****************************************************************************************************

   BEGIN TRY     
		SELECT @Full_BackupFolder					=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Full_BackupFolder_ForSecondBackupJob'
		SELECT @Diff_BackupFolder					=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Diff_BackupFolder'
		SELECT @Tlog_BackupFolder					=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='T-log_BackupFolder'
		SELECT @EmailRecipient						=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='EmailRecipient'
		SELECT @Environment							=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Environment'
		SELECT @MinimumDiskSpaceForBackup			=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='MinimumDiskSpaceForBackup'
		SELECT @RetentionPeriodForFullbackupInDays	=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='RetentionPeriodForFullbackupInDays'
		SELECT @RetentionPeriodForDIFFbackupInDays	=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='RetentionPeriodForDIFFbackupInDays'

		SELECT @BackupDrive							=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Full_BackupFolder_ForSecondBackupJob'
		IF Left(IsNull(@BackupDrive,''),1) = '\' OR  Left(IsNull(@BackupDrive,''),4) = 'http' --or substring(IsNull(@BackupDrive,''),2,1) <> ':'
			SET @BackupDrive = ''
			
		SELECT @RetentionPeriodForFullbackupInDays = ISNULL(@RetentionPeriodForFullbackupInDays,8)
		SELECT @RETENTIONPERIODFORDIFFBACKUPINDAYS = ISNULL(@RETENTIONPERIODFORDIFFBACKUPINDAYS,4)
				
		SELECT @MinimumDiskSpaceForBackup	= ISNULL(@MinimumDiskSpaceForBackup,10)	    		
		SELECT @LAST_FULLBACKUP_DATE=CONVERT(VARCHAR(20),GETDATE(),101)	    
	    SELECT @Environment = ISNULL(@Environment, 'Prod')
		SELECT @EnvironmentDesc = CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END
		SELECT @Subject = @EnvironmentDesc + ' - SQL Maintenance Job Failure For Server  ' + @@SERVERNAME + ' IP : ' +@ACTUAL_IP_ADDRESS

		-- *******************************************************************************************************
			-- Get List of database for which maintenance is required.  The query condition ignores Model, TempDB 
			-- and all database which is marked with "_TOBEDELETED".  Also any database name that is marked under
			-- "DatabaseName_ForSecondBackupJob" is ignored by this job; since that is backed up by another job
		-- *******************************************************************************************************
		Create Table #DatabaseNamesForFullBackup (RowNo SmallInt Identity(1,1), Name varchar(1000))	    
    
		INSERT INTO  #DATABASENAMESFORFULLBACKUP (NAME)
		  SELECT NAME FROM SYS.DATABASES  WITH(NOLOCK) 
		  WHERE STATE_DESC='ONLINE' AND
				NAME IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM [SQLMANTAINENCE].[DBMANTAINENCECONFIGURATION]  WITH(NOLOCK) 
				         WHERE CONFIGURATIONTYPE ='DatabaseName_ForSecondBackupJob')
	   

	   SELECT @IROW = 1, @TOTALROWS = COUNT(*) FROM #DATABASENAMESFORFULLBACKUP
	   
	   WHILE @IROW <= @TOTALROWS
	   BEGIN 
			SELECT @DBNAME  = NAME FROM #DATABASENAMESFORFULLBACKUP WHERE ROWNO = @IROW
	       

		   -- by default ON for all database ....only if backup preference is turned off for a database then do not take backup
		    Set  @iAllowBackupOnDatabase = 1 

			-- ***********************************************************************************************************************************
		    -- IF SQL 2012 or greater ie. used to check backup preference in AlwaysOn environment
            -- ***********************************************************************************************************************************
			IF cast(Left(cast(serverproperty('productversion') as varchar(100)),(charindex('.',cast(serverproperty('productversion') as varchar(100)))-1)) as int) >= 11 
			BEGIN
				SELECT @iAllowBackupOnDatabase = sys.fn_hadr_backup_is_preferred_replica(@DBNAME) 
				IF @iAllowBackupOnDatabase = 0
				BEGIN
										-- SCRIPT BELOW IS EXECUTED TO LOG THE ENTRY IN MAINTENANCE LOG FOR THE SUCESSFUL BACKUP OF THE CURRENT DATABASE
					INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'FULL-BACKUP','Due to current AG setup, full Backup was ignored for the database: '+@DBName,'I');
					EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackup_ForSecondBackupJob','FULL-BACKUP'	
				END
			END
			-- ***********************************************************************************************************************************


			IF  @iAllowBackupOnDatabase = 1
			BEGIN
				-- *****************************************************************************************
				-- IF NETWORK DRIVE or URL (Azure backup) IS USED FOR BACKUP THEN IGNORE THE DISK SPACE CHECK
				-- *****************************************************************************************
				IF Left(@BACKUPDRIVE,1) = '\' OR @BACKUPDRIVE = 'http'  OR Ltrim(@BACKUPDRIVE) = ''
					  SET @FREESPACEINPERCENTAGE = @MINIMUMDISKSPACEFORBACKUP  
				ELSE   -- IF NOT NETWORK or URL AZURE BACKUP DRIVE THEN DO THE MINIMUM DISK AVAILABILITY CHECK
				BEGIN
							-- THE CODE BELOW CHECK HOW MUCH TOTAL DISK SPACE IS AVAILABLE ON BACKUP DRIVE 
							--- JUST IN CASE BACKUP DRIVE IS MENTIONED WRONG IN CONFIG FILE; THEN NULL  VALUE IS RETURNED. IN SUCH
							-- A SCENARIO THE CODE BELOW WILL CALCULATE AS 100% FREE DISK SPACE
						EXECUTE  [SQLMANTAINENCE].GETTOTALSPACEOFDRIVE @BACKUPDRIVE, @TOTALSPACE OUTPUT 
						SELECT @TOTALSPACE = ISNULL(@TOTALSPACE,1)    


							-- THE CODE BELOW CHECKS HOW MUCH FREE SPACE IS AVAILABLE ON BACKUP DRIVE 
							--- JUST IN CASE BACKUP DRIVE IS MENTIONED WRONG IN CONFIG FILE; THEN NULL  VALUE IS RETURNED. IN SUCH
							-- A SCENARIO THE CODE BELOW WILL CALCULATE AS 100% FREE DISK SPACE
						EXECUTE  [SQLMANTAINENCE].GETFREESPACEOFDRIVE @BACKUPDRIVE, @FREESPACE OUTPUT  
						SELECT @FREESPACE = ISNULL(@FREESPACE,1)  

							-- CALCULATING THE PERCENTAGE OF FREE SPACE AVAILABLE
						IF  @TOTALSPACE <> 0
						SET @FREESPACEINPERCENTAGE = (@FREESPACE/@TOTALSPACE)*100	 
				END


				-- *****************************************************************************************
				-- IF FREESPACE IS MORE THAN THE MINIMUM SPACE RECOMMENDED FOR THIS SERVER THEN START TAKING BACKUP
				-- *****************************************************************************************
				IF CAST(@FREESPACEINPERCENTAGE AS INT) >= CAST(ISNULL(@MINIMUMDISKSPACEFORBACKUP,0) AS INT)
				BEGIN       
				BEGIN TRY 
						-- *****************************************************************************************	   
						 -- BEFORE TAKING BACKUP FOR A DATABASE, BELOW CONDITION WILL CHECK WHETHER BACKUP IS ALREADY 
						 -- DONE FOR THIS DATABASE ON THAT DAY...NECESSARY IF THE JOB HAD FAILED IN EARLIER EXECUTION
						 -- *****************************************************************************************
					   IF NOT EXISTS(SELECT 1 FROM SQLMantainence.DBMantainenceLOG  WITH(NOLOCK) WHERE TYPE='FULL-BACKUP' AND LTRIM(RTRIM(UPPER((SUBSTRING(LogDetails,CHARINDEX(':',LogDetails)+1,LEN(LogDetails)-1)))))= LTRIM(RTRIM(UPPER(@DBName))) AND (CONVERT(VARCHAR(10),LogDate,101)=CONVERT(VARCHAR(10),@LAST_FULLBACKUP_DATE,101) )  AND LogDetails Like 'Full Backup Successfull for the database%')
					   BEGIN
							 SET @FLAG_FORMSDB = 1
							 IF @DBNAME='MSDB' 
							 BEGIN
							  IF LEFT(@ENVIRONMENT,1) <> 'P'  -- I.E. IF NOT PRODUCTION ENVIORNMENT...TO ENSURE THAT MSDB IS BACKUPED UP ONLY IN PRODUCTION
								 SET @FLAG_FORMSDB = 0
							  END			  
						  
							  IF  @FLAG_FORMSDB = 1			
							  BEGIN			 
									 -- ****************************************************************	
									  -- SCRIPT BELOW IS EXECUTED TO TAKE BACKUP OF THE CURRENT DATABASE
									-- ****************************************************************
									IF @BACKUPDRIVE = 'http'   
										SET @SQL = 'BACKUP DATABASE [' + @DBNAME + '] TO URL = ''' +  @FULL_BACKUPFOLDER + '/' + @DBNAME + '@' +  
											CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR(4)) + RIGHT('0'+CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR(2)),2) + 
											RIGHT('0'+CAST(DATEPART(DAY,GETDATE()) AS VARCHAR(2)),2) + '_' + RIGHT('0'+CAST(DATEPART(HOUR,GETDATE()) AS VARCHAR(2)),2) + 
											RIGHT('0'+CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR(2)),2) + '.BAK'' 
											WITH CREDENTIAL = ''SQLBackupCreds'', CHECKSUM, INIT'
									ELSE
										SET @SQL = 'BACKUP DATABASE [' + @DBNAME + '] TO DISK = ''' +  @FULL_BACKUPFOLDER + '\' + @DBNAME + '@' +  
											CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR(4)) + RIGHT('0'+CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR(2)),2) + 
											RIGHT('0'+CAST(DATEPART(DAY,GETDATE()) AS VARCHAR(2)),2) + '_' + RIGHT('0'+CAST(DATEPART(HOUR,GETDATE()) AS VARCHAR(2)),2) + 
											RIGHT('0'+CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR(2)),2) + '.BAK'' WITH  CHECKSUM, INIT'
									
									PRINT @SQL   -- DEBUG CODE ...REMOVE LATER
									EXECUTE (@SQL)				      
								
									-- ************************************************************************************************
										-- SCRIPT BELOW IS EXECUTED TO DELETED ALL PREVIOUS BACKUP FILES FOR THE CURRENT DATABASE
									-- ************************************************************************************************
									IF @BACKUPDRIVE = 'http'   
									BEGIN

										SELECT @AzureBackupContainer = LTRIM(RTRIM(REVERSE(LEFT(REVERSE(LEFT(@Full_BackupFolder,LEN(@Full_BackupFolder)-CHARINDEX('/',REVERSE(@Full_BackupFolder),0))),CHARINDEX('/',REVERSE(LEFT(@Full_BackupFolder,LEN(@Full_BackupFolder)-CHARINDEX('/',REVERSE(@Full_BackupFolder),0))),0)-1))))
	 

										SELECT @Full_BackupFolderAzure = REVERSE(LEFT(REVERSE(@Full_BackupFolder),CHARINDEX('/',REVERSE(@Full_BackupFolder),0)-1))

										SELECT @Diff_BackupFolderAzure = REVERSE(LEFT(REVERSE(@Diff_BackupFolder),CHARINDEX('/',REVERSE(@Full_BackupFolder),0)-1))
										
										EXECUTE [SQLMANTAINENCE].[PROC_DELETEOLD_AzureFULLBACKUPS] 
										@DBNAME,@AzureBackupContainer,@Full_BackupFolderAzure,@Diff_BackupFolderAzure, @RETENTIONPERIODFORFULLBACKUPINDAYS,
										@RETENTIONPERIODFORDIFFBACKUPINDAYS
									END
									ELSE 					
										EXECUTE [SQLMANTAINENCE].[PROC_DELETEOLDFULLBACKUPS] 
										@DBNAME,@FULL_BACKUPFOLDER,@DIFF_BACKUPFOLDER, @RETENTIONPERIODFORFULLBACKUPINDAYS,
										@RETENTIONPERIODFORDIFFBACKUPINDAYS								
										-- SCRIPT BELOW IS EXECUTED TO LOG THE ENTRY IN MAINTENANCE LOG FOR THE SUCESSFUL BACKUP OF THE CURRENT DATABASE
									INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'FULL-BACKUP','Full Backup Successfull for the database: '+@DBName,'I');
									EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackup_ForSecondBackupJob','FULL-BACKUP'				
							  END			
							END
						END TRY
					
						BEGIN CATCH
								-- SCRIPT BELOW IS TO RECORD FAILED BACKUP ENTRY FOR THE CURRENT DATABASE
							INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'FULL-BACKUP','Full Backup failed for the database: '+@DBName + ' (' + ERROR_MESSAGE() + ')','C');
							EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackup_ForSecondBackupJob','FULL-BACKUP'
						END CATCH
					END
					ELSE   -- ELSE FOR THE IF ABOVE WHICH CHECKS WHETHER THERE ARE FREE SPACE AVAILABLE ON THE BACKUP DRIVE
					 BEGIN
							-- Sent Email Notification for insufficient disk space on backup drive
							SET @ERRORMESSAGE = @ERRORMESSAGE + '<br>=> Could not execute FULL backup for database ' + 
								 @DBName + ' due to insufficient disk space in ' + @Full_BackupFolder + '.'
							INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'FULL-BACKUP','No sufficient space available for Full-Backup: '+@DBName,'W');			 
							EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackup_ForSecondBackupJob','FULL-BACKUP'
					 END
				END -- END OF IF  @iAllowBackupOnDatabase = 1		  
		   
				SELECT @IROW += 1
		END  -- END OF WHILE LOOP
	   
		DROP TABLE #DATABASENAMESFORFULLBACKUP
	  	   
		IF @ERRORMESSAGE != ''
		BEGIN
			EXECUTE MSDB..SP_SEND_DBMAIL @PROFILE_NAME = 'DBMAINTENANCE', @RECIPIENTS = @EMAILRECIPIENT ,
				 @SUBJECT =@SUBJECT, 
				 @BODY_FORMAT= 'HTML',
				 @BODY = @ERRORMESSAGE, 
				 @EXECUTE_QUERY_DATABASE = 'SQL_ADMIN'
		END		 
		
	END TRY 

	BEGIN CATCH
		   EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackup_ForSecondBackupJob','FULL-BACKUP'
	END CATCH
  
END
go


USE [Sql_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
	Author: Suji Nair
*/
CREATE PROCEDURE  [SQLMantainence].[SP_MantainencePlanScriptForFullBackup] 
 -- With Encryption
AS
BEGIN


	SET NOCOUNT ON;
		
    DECLARE @LAST_FULLBACKUP_DATE VARCHAR(100)
    DECLARE @FULL_BACKUPFOLDER VARCHAR(1000)
    DECLARE @DIFF_BACKUPFOLDER VARCHAR (1000)
    DECLARE @FULL_BACKUPFOLDER1 VARCHAR(1000)
    DECLARE @DIFF_BACKUPFOLDER1 VARCHAR (1000)

    DECLARE @TLOG_BACKUPFOLDER VARCHAR(1000)
    DECLARE @EMAILRECIPIENT VARCHAR (2000)
    DECLARE @ENVIRONMENT VARCHAR(50), @ENVIRONMENTDESC VARCHAR (50)
    DECLARE @DBNAME VARCHAR(200)
    DECLARE @MINIMUMDISKSPACEFORBACKUP BIGINT
    DECLARE @SQL VARCHAR(1000)
    DECLARE @FREESPACE FLOAT =0
	DECLARE @TOTALSPACE FLOAT = 0
	DECLARE @FREESPACEINPERCENTAGE INT = 0
    DECLARE @RETENTIONPERIODFORFULLBACKUPINDAYS INT
	DECLARE @RETENTIONPERIODFORDIFFBACKUPINDAYS INT
    DECLARE @FLAG_FORMSDB BIT    
	DECLARE @ACTUAL_IP_ADDRESS VARCHAR(1000)  
	DECLARE @BACKUPDRIVE VARCHAR(50)
    DECLARE @ERRORMESSAGE VARCHAR(MAX) ,
              @FORMATTEDERRORMESSAGE  VARCHAR(MAX),
              @ERRORNUMBER VARCHAR(50),
              @ERRORSEVERITY VARCHAR(50),
              @ERRORSTATE  VARCHAR(50),
              @ERRORLINE  VARCHAR(50),
              @ERRORPROCEDURE  VARCHAR(200)
    DECLARE @SUBJECT VARCHAR(1000)          
    DECLARE @IROW SMALLINT, @TOTALROWS SMALLINT
	Declare @iAllowBackupOnDatabase BIT   -- for database included for Always On

	--for backup at Azure storage
	DECLARE @Full_BackupFolderAzure VARCHAR(100) ,
			@Diff_BackupFolderAzure VARCHAR(100), 
			@AzureBackupContainer VARCHAR(1000)
	DECLARE @FullBackupfilename varchar(200)
	DECLARE @AescryptforBackupfile varchar (1000) 
	

	-- *****************************************************************************************************
             -- TO GET THE IP ADDRESS OF THE SERVER WHERE THE JOB IS BEING EXECUTED I.E. FOR REPORTING PURPOSE
	-- *****************************************************************************************************
	CREATE TABLE #TEMP1(SQL_IP VARCHAR(3000))
	INSERT INTO #TEMP1 EXECUTE XP_CMDSHELL 'IPCONFIG' 
	DECLARE @IPADDRESS VARCHAR(300) 
	SET @IPADDRESS = (SELECT TOP 1 SQL_IP FROM #TEMP1  WITH(NOLOCK)  WHERE SQL_IP LIKE '%IPV4%' ORDER BY SQL_IP DESC) 
	If @IPAddress IS NULL
		SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IP Address%' ORDER BY SQL_IP DESC) 	
	
	SET @IPAddress = IsNull(@IPAddress,'')

	DECLARE @LEN INT 
	SET @LEN = CHARINDEX(':', @IPADDRESS) 
	SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPADDRESS, @LEN+1, LEN(@IPADDRESS)))) 
	DROP TABLE #TEMP1 
	-- *****************************************************************************************************

   BEGIN TRY     
		SELECT @Full_BackupFolder					=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Full_BackupFolder'
		SELECT @Diff_BackupFolder					=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Diff_BackupFolder'
		SELECT @Tlog_BackupFolder					=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='T-log_BackupFolder'
		SELECT @EmailRecipient						=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='EmailRecipient'
		SELECT @Environment							=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Environment'
		SELECT @MinimumDiskSpaceForBackup			=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='MinimumDiskSpaceForBackup'
		SELECT @RetentionPeriodForFullbackupInDays	=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='RetentionPeriodForFullbackupInDays'
		SELECT @RetentionPeriodForDIFFbackupInDays	=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='RetentionPeriodForDIFFbackupInDays'

		SELECT @BackupDrive							=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Full_BackupFolder'
		
		IF Left(IsNull(@BACKUPDRIVE,''),1) = '\'
			SELECT @BACKUPDRIVE = '\'
		ELSE IF Left(IsNull(@BACKUPDRIVE,''),4) = 'http'
			SELECT @BACKUPDRIVE = 'http'
		ELSE
			SELECT @BACKUPDRIVE = Left(IsNull(@BACKUPDRIVE,''),2)

		SELECT @RetentionPeriodForFullbackupInDays = ISNULL(@RetentionPeriodForFullbackupInDays,8)
		SELECT @RETENTIONPERIODFORDIFFBACKUPINDAYS = ISNULL(@RETENTIONPERIODFORDIFFBACKUPINDAYS,4)
				
		SELECT @MinimumDiskSpaceForBackup	= ISNULL(@MinimumDiskSpaceForBackup,10)	    		
		SELECT @LAST_FULLBACKUP_DATE=CONVERT(VARCHAR(20),GETDATE(),101)	    
	    SELECT @Environment = ISNULL(@Environment, 'Prod')
		SELECT @EnvironmentDesc = CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END
		SELECT @Subject = @EnvironmentDesc + ' - SQL Maintenance Job Failure For Server  ' + @@SERVERNAME + ' IP : ' +@ACTUAL_IP_ADDRESS

		-- *******************************************************************************************************
			-- Get List of database for which maintenance is required.  The query condition ignores Model, TempDB 
			-- and all database which is marked with "_TOBEDELETED".  Also any database name that is marked under
			-- "DatabaseName_ForSecondBackupJob" is ignored by this job; since that is backed up by another job
		-- *******************************************************************************************************
		Create Table #DatabaseNamesForFullBackup (RowNo SmallInt Identity(1,1), Name varchar(1000))	    
    
		INSERT INTO  #DATABASENAMESFORFULLBACKUP (NAME)
		  SELECT NAME FROM SYS.DATABASES  WITH(NOLOCK) 
		  WHERE STATE_DESC='ONLINE' AND NAME NOT LIKE '%_TOBEDELETED%' AND SOURCE_DATABASE_ID IS NULL AND  NAME NOT IN('MODEL','TEMPDB')AND
				NAME NOT IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM [SQLMANTAINENCE].[DBMANTAINENCECONFIGURATION]  WITH(NOLOCK) WHERE CONFIGURATIONTYPE IN ('EXCLUDEDATABASE','DatabaseName_ForSecondBackupJob'))
	   

	   SELECT @IROW = 1, @TOTALROWS = COUNT(*) FROM #DATABASENAMESFORFULLBACKUP
	   
	   WHILE @IROW <= @TOTALROWS
	   BEGIN 
			SELECT @DBNAME  = NAME FROM #DATABASENAMESFORFULLBACKUP WHERE ROWNO = @IROW
	       

		   -- by default ON for all database ....only if backup preference is turned off for a database then do not take backup
		    Set  @iAllowBackupOnDatabase = 1 

			-- ***********************************************************************************************************************************
		    -- IF SQL 2012 or greater ie. used to check backup preference in AlwaysOn environment
            -- ***********************************************************************************************************************************
			IF cast(Left(cast(serverproperty('productversion') as varchar(100)),(charindex('.',cast(serverproperty('productversion') as varchar(100)))-1)) as int) >= 11 
			BEGIN
				SELECT @iAllowBackupOnDatabase = sys.fn_hadr_backup_is_preferred_replica(@DBNAME) 
				IF @iAllowBackupOnDatabase = 0
				BEGIN
										-- SCRIPT BELOW IS EXECUTED TO LOG THE ENTRY IN MAINTENANCE LOG FOR THE SUCESSFUL BACKUP OF THE CURRENT DATABASE
					INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'FULL-BACKUP','Due to current AG setup, full Backup was ignored for the database: '+@DBName,'I');
					EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackup','FULL-BACKUP'	
				END
			END
			-- ***********************************************************************************************************************************


			IF  @iAllowBackupOnDatabase = 1
			BEGIN
				-- *****************************************************************************************
				-- IF NETWORK DRIVE or URL (Azure backup) IS USED FOR BACKUP THEN IGNORE THE DISK SPACE CHECK
				-- *****************************************************************************************
				IF @BACKUPDRIVE = '\' OR @BACKUPDRIVE = 'http'  OR Ltrim(@BACKUPDRIVE) = ''
					  SET @FREESPACEINPERCENTAGE = @MINIMUMDISKSPACEFORBACKUP  
				ELSE   -- IF NOT NETWORK or URL AZURE BACKUP DRIVE THEN DO THE MINIMUM DISK AVAILABILITY CHECK
				BEGIN
							-- THE CODE BELOW CHECK HOW MUCH TOTAL DISK SPACE IS AVAILABLE ON BACKUP DRIVE 
							--- JUST IN CASE BACKUP DRIVE IS MENTIONED WRONG IN CONFIG FILE; THEN NULL  VALUE IS RETURNED. IN SUCH
							-- A SCENARIO THE CODE BELOW WILL CALCULATE AS 100% FREE DISK SPACE
						EXECUTE  [SQLMANTAINENCE].GETTOTALSPACEOFDRIVE @BACKUPDRIVE, @TOTALSPACE OUTPUT 
						SELECT @TOTALSPACE = ISNULL(@TOTALSPACE,1)    


							-- THE CODE BELOW CHECKS HOW MUCH FREE SPACE IS AVAILABLE ON BACKUP DRIVE 
							--- JUST IN CASE BACKUP DRIVE IS MENTIONED WRONG IN CONFIG FILE; THEN NULL  VALUE IS RETURNED. IN SUCH
							-- A SCENARIO THE CODE BELOW WILL CALCULATE AS 100% FREE DISK SPACE
						EXECUTE  [SQLMANTAINENCE].GETFREESPACEOFDRIVE @BACKUPDRIVE, @FREESPACE OUTPUT  
						SELECT @FREESPACE = ISNULL(@FREESPACE,1)  

							-- CALCULATING THE PERCENTAGE OF FREE SPACE AVAILABLE
						IF  @TOTALSPACE <> 0
						SET @FREESPACEINPERCENTAGE = (@FREESPACE/@TOTALSPACE)*100	 
				END

				IF @BACKUPDRIVE = '\' 
				BEGIN
				    exec xp_cmdshell 'net use z: /delete'
					SET @Full_BackupFolder1 = 'net use z: ' +  @Full_BackupFolder
					exec xp_cmdshell @Full_BackupFolder1

					SET @Full_BackupFolder1 = 'z:'

				    exec xp_cmdshell 'net use y: /delete'
					SET @Diff_BackupFolder1 = 'net use y: ' +  @Diff_BackupFolder
					exec xp_cmdshell @Diff_BackupFolder1
					SET @Diff_BackupFolder1 = 'y:'

				END
				ELSE
				BEGIN
					SET @Full_BackupFolder1 = @Full_BackupFolder
					SET @Diff_BackupFolder1 = @Diff_BackupFolder
				END

				-- *****************************************************************************************
				-- IF FREESPACE IS MORE THAN THE MINIMUM SPACE RECOMMENDED FOR THIS SERVER THEN START TAKING BACKUP
				-- *****************************************************************************************
				IF CAST(@FREESPACEINPERCENTAGE AS INT) >= CAST(ISNULL(@MINIMUMDISKSPACEFORBACKUP,0) AS INT)
				BEGIN       
				BEGIN TRY 
						-- *****************************************************************************************	   
						 -- BEFORE TAKING BACKUP FOR A DATABASE, BELOW CONDITION WILL CHECK WHETHER BACKUP IS ALREADY 
						 -- DONE FOR THIS DATABASE ON THAT DAY...NECESSARY IF THE JOB HAD FAILED IN EARLIER EXECUTION
						 -- *****************************************************************************************
					   IF NOT EXISTS(SELECT 1 FROM SQLMantainence.DBMantainenceLOG  WITH(NOLOCK) WHERE TYPE='FULL-BACKUP' AND LTRIM(RTRIM(UPPER((SUBSTRING(LogDetails,CHARINDEX(':',LogDetails)+1,LEN(LogDetails)-1)))))= LTRIM(RTRIM(UPPER(@DBName))) AND (CONVERT(VARCHAR(10),LogDate,101)=CONVERT(VARCHAR(10),@LAST_FULLBACKUP_DATE,101) )  AND LogDetails Like 'Full Backup Successfull for the database%')
					   BEGIN
							 SET @FLAG_FORMSDB = 1
							 IF @DBNAME='MSDB' 
							 BEGIN
							  IF LEFT(@ENVIRONMENT,1) <> 'P'  -- I.E. IF NOT PRODUCTION ENVIORNMENT...TO ENSURE THAT MSDB IS BACKUPED UP ONLY IN PRODUCTION
								 SET @FLAG_FORMSDB = 1
							  END			  
						  
							  IF  @FLAG_FORMSDB = 1			
							  BEGIN			 
									 -- ****************************************************************	
									  -- SCRIPT BELOW IS EXECUTED TO TAKE BACKUP OF THE CURRENT DATABASE
									-- ****************************************************************

									set @FullBackupfilename =  @FULL_BACKUPFOLDER1 + '\' + @DBNAME + '@' +  
											CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR(4)) + RIGHT('0'+CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR(2)),2) + 
											RIGHT('0'+CAST(DATEPART(DAY,GETDATE()) AS VARCHAR(2)),2) + '_' + RIGHT('0'+CAST(DATEPART(HOUR,GETDATE()) AS VARCHAR(2)),2) + RIGHT('0'+CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR(2)),2) + '.BAK'


									IF @BACKUPDRIVE = 'http'   
									SET @SQL = 'BACKUP DATABASE [' + @DBNAME + '] TO URL = ''' +  @FullBackupfilename+ '''  
											WITH CREDENTIAL = ''SQLBackupCreds'', CHECKSUM, INIT'
									ELSE
								

											SET @SQL = 'BACKUP DATABASE [' + @DBNAME + '] TO DISK = ''' + @FullBackupfilename + ''' WITH  CHECKSUM, INIT'
									
									PRINT @SQL   -- DEBUG CODE ...REMOVE LATER
									EXECUTE (@SQL)				      
								

							-- This code below will encrypt the backup file using AESCrypt utility...only for stores.
			                set @AescryptforBackupfile = 'C:\AESCrypt\BackupfileEncryption.bat "SQLDBp@$$w0rd"   "' + @FullBackupfilename + '"'
							exec xp_cmdshell @AescryptforBackupfile 


									-- ************************************************************************************************
										-- SCRIPT BELOW IS EXECUTED TO DELETED ALL PREVIOUS BACKUP FILES FOR THE CURRENT DATABASE...past retention period
									-- ************************************************************************************************
									IF @BACKUPDRIVE = 'http'   
									BEGIN

										SELECT @AzureBackupContainer = LTRIM(RTRIM(REVERSE(LEFT(REVERSE(LEFT(@Full_BackupFolder,LEN(@Full_BackupFolder)-CHARINDEX('/',REVERSE(@Full_BackupFolder),0))),CHARINDEX('/',REVERSE(LEFT(@Full_BackupFolder,LEN(@Full_BackupFolder)-CHARINDEX('/',REVERSE(@Full_BackupFolder),0))),0)-1))))
	 

										SELECT @Full_BackupFolderAzure = REVERSE(LEFT(REVERSE(@Full_BackupFolder),CHARINDEX('/',REVERSE(@Full_BackupFolder),0)-1))

										SELECT @Diff_BackupFolderAzure = REVERSE(LEFT(REVERSE(@Diff_BackupFolder),CHARINDEX('/',REVERSE(@Full_BackupFolder),0)-1))
										
										EXECUTE [SQLMANTAINENCE].[PROC_DELETEOLD_AzureFULLBACKUPS] 
										@DBNAME,@AzureBackupContainer,@Full_BackupFolderAzure,@Diff_BackupFolderAzure, @RETENTIONPERIODFORFULLBACKUPINDAYS,
										@RETENTIONPERIODFORDIFFBACKUPINDAYS
									END
									ELSE IF Left(@BACKUPDRIVE,1) <> '\'    -- i.e. no delete if backup is happneing on network folder
									begin
										EXECUTE [SQLMANTAINENCE].[PROC_DELETEOLDFULLBACKUPS] 
										@DBNAME,@FULL_BACKUPFOLDER,@DIFF_BACKUPFOLDER, @RETENTIONPERIODFORFULLBACKUPINDAYS,
										@RETENTIONPERIODFORDIFFBACKUPINDAYS								
									end	
										
										-- SCRIPT BELOW IS EXECUTED TO LOG THE ENTRY IN MAINTENANCE LOG FOR THE SUCESSFUL BACKUP OF THE CURRENT DATABASE
									INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'FULL-BACKUP','Full Backup Successfull for the database: '+@DBName,'I');
									EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackup','FULL-BACKUP'				
							  END			
							END
						END TRY
					
						BEGIN CATCH
								-- SCRIPT BELOW IS TO RECORD FAILED BACKUP ENTRY FOR THE CURRENT DATABASE
							INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'FULL-BACKUP','Full Backup failed for the database: '+@DBName,'C');
							EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackup','FULL-BACKUP'
						END CATCH
					END
					ELSE   -- ELSE FOR THE IF ABOVE WHICH CHECKS WHETHER THERE ARE FREE SPACE AVAILABLE ON THE BACKUP DRIVE
					 BEGIN
							-- Sent Email Notification for insufficient disk space on backup drive
							SET @ERRORMESSAGE = @ERRORMESSAGE + '<br>=> Could not execute FULL backup for database ' + 
								 @DBName + ' due to insufficient disk space in ' + @Full_BackupFolder + '.'
							INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'FULL-BACKUP','No sufficient space available for Full-Backup: '+@DBName,'W');			 
							EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackup','FULL-BACKUP'
					 END
				END -- END OF IF  @iAllowBackupOnDatabase = 1		  
		   
				SELECT @IROW += 1
		END  -- END OF WHILE LOOP
	   
		DROP TABLE #DATABASENAMESFORFULLBACKUP
	  	   
		IF @ERRORMESSAGE != ''
		BEGIN
			EXECUTE MSDB..SP_SEND_DBMAIL @PROFILE_NAME = 'DBMAINTENANCE', @RECIPIENTS = @EMAILRECIPIENT ,
				 @SUBJECT =@SUBJECT, 
				 @BODY_FORMAT= 'HTML',
				 @BODY = @ERRORMESSAGE, 
				 @EXECUTE_QUERY_DATABASE = 'SQL_ADMIN'
		END		 
		
	END TRY 

	BEGIN CATCH
		   EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackup','FULL-BACKUP'
	END CATCH


END
GO


-- ***************************************************************************************************
-- END OF FULL BACKUP SCRIPT
-- ***************************************************************************************************


-- ***************************************************************************************************
-- BEGIN OF DIFFERENTIAL BACKUP SCRIPT BELOW
-- ***************************************************************************************************
USE [Sql_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE  [SQLMantainence].[SP_MantainencePlanScriptForDiffBackup]
@DataBaseName VARCHAR(1000) = NULL
-- With Encryption	

AS
BEGIN



SET NOCOUNT ON;

DECLARE @Full_BackupFolder varchar(1000)
DECLARE @Full_BackupFolder1 varchar(1000)

DECLARE @Diff_BackupFolder varchar (1000)
DECLARE @Diff_BackupFolder1 varchar (1000)

DECLARE @EmailRecipient varchar (2000)
DECLARE @Environment varchar(50), @EnvironmentDesc varchar (50)
DECLARE @DBName varchar(200)
DECLARE @MinimumDiskSpaceForBackup BIGINT
DECLARE @SQL varchar(1000)
DECLARE @FreeSpace FLOAT =0
DECLARE @TotalSpace FLOAT = 0
DECLARE @FreeSpaceInPercentage INT = 0
DECLARE @CMD1 varchar(1000)=''
DECLARE @BackupDrive varchar(50)
DECLARE @Subject varchar(1000)
DECLARE @iRow SmallInt, @TotalRows SmallInt
Declare @iAllowBackupOnDatabase BIT   -- for database included for Always On
DECLARE @FullBackupfilename varchar(200)
DECLARE @AescryptforFullBackupfile varchar (1000)

DECLARE @DiffBackupfilename varchar (200)
DECLARE @AescryptforDiffBackup varchar (1000)
 
-- *****************************************************************************************************	  
	-- The script below calculate the IP address of the current server for generating email alert
-- *****************************************************************************************************
DECLARE @ACTUAL_IP_ADDRESS VARCHAR(1000)  
CREATE TABLE #temp1(sql_ip VARCHAR(3000))
INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 
DECLARE @ipaddress varchar(300) 
SET @ipaddress = (SELECT TOP 1 sql_ip FROM #temp1 WHERE sql_ip like '%IPv4%' order by sql_ip DESC) 
DECLARE @len int 
SET @Len = CHARINDEX(':', @ipaddress) 
SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@ipaddress, @Len+1, LEN(@ipaddress)))) 
 -- *****************************************************************************************************
   
DECLARE @ERRORMESSAGE VARCHAR(MAX) ,
            @FormattedErrorMessage  VARCHAR(MAX),
            @ErrorNumber varchar(50),
            @ErrorSeverity varchar(50),
            @ErrorState  varchar(50),
            @ErrorLine  varchar(50),
            @ErrorProcedure  VARCHAR(200)
                 
 BEGIN TRY   

    SELECT @Full_BackupFolder			=value FROM SQLMantainence.DBMantainenceConfiguration WHERE configurationType='Full_BackupFolder'
    SELECT @Diff_BackupFolder			=value FROM SQLMantainence.DBMantainenceConfiguration WHERE configurationType='Diff_BackupFolder'
    SELECT @EmailRecipient				=value FROM SQLMantainence.DBMantainenceConfiguration WHERE configurationType='EmailRecipient'
    SELECT @Environment					=value FROM SQLMantainence.DBMantainenceConfiguration WHERE configurationType='Environment'
    SELECT @MinimumDiskSpaceForBackup	=value FROM SQLMantainence.DBMantainenceConfiguration WHERE configurationType='MinimumDiskSpaceForBackup'

    SELECT @BackupDrive					=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Diff_BackupFolder'    
	
	IF Left(IsNull(@BACKUPDRIVE,''),1) = '\'
		SELECT @BACKUPDRIVE = '\'
	ELSE IF Left(IsNull(@BACKUPDRIVE,''),4) = 'http'
		SELECT @BACKUPDRIVE = 'http'
	ELSE
		SELECT @BACKUPDRIVE = Left(IsNull(@BACKUPDRIVE,''),2)
    
	SELECT @Environment = IsNull(@Environment, 'Prod')
    SELECT @MinimumDiskSpaceForBackup = IsNull(@MinimumDiskSpaceForBackup,10)    
    SELECT @EnvironmentDesc = Case  Left(@Environment,3) When 'Dev' Then 'Development' When 'Prod' Then 'Production' Else  @Environment End
	SELECT @Subject = @EnvironmentDesc + ' - SQL Maintenance Job Failure For Server  ' + @@SERVERNAME + ' IP : ' +@ACTUAL_IP_ADDRESS

    CREATE TABLE #DatabaseNamesForDiffBackup (RowNo SmallInt Identity(1,1), Name varchar(1000))

	INSERT INTO  #DatabaseNamesForDiffBackup (Name)
	SELECT Name FROM SYS.databases
		WHERE (@DataBaseName IS NULL OR (@DataBaseName IS NOT NULL AND Name = @DataBaseName)) AND 
		(State_Desc='ONLINE' AND source_database_id IS NULL AND name NOT LIKE '%_TOBEDELETED%' AND  
		name NOT IN('master','msdb','Model','tempdb') AND 
		Name NOT IN (SELECT VALUE COLLATE Database_DEFAULT FROM [SQLMantainence].[DBMantainenceConfiguration]  WITH(NOLOCK) 
		WHERE ConfigurationType = 'ExcludeDatabase'))

   
   SELECT @iRow = 1, @TotalRows = COUNT(*) FROM #DatabaseNamesForDiffBackup
   
   WHILE @iRow <= @TotalRows
   BEGIN 
		SELECT @DBName  = Name FROM #DatabaseNamesForDiffBackup WHERE RowNo = @iRow
	
		Set  @iAllowBackupOnDatabase = 1 -- by default ON for all database ....only if backup preference is turned off for a database then do not take backup
		    
			-- *****************************************************************************************************
			-- IF SQL 2012 or greater then check for AlwaysOn backup preferences
			-- *****************************************************************************************************
            IF cast(Left(cast(serverproperty('productversion') as varchar(100)),(charindex('.',cast(serverproperty('productversion') as varchar(100)))-1)) as int) >= 11 
			BEGIN
				SELECT @iAllowBackupOnDatabase = sys.fn_hadr_backup_is_preferred_replica(@DBName) 
				IF @iAllowBackupOnDatabase = 0
				BEGIN
										-- SCRIPT BELOW IS EXECUTED TO LOG THE ENTRY IN MAINTENANCE LOG FOR THE SUCESSFUL BACKUP OF THE CURRENT DATABASE
					INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'DIFFERENTIAL-BACKUP','Due to current AG setup, Differential Backup was ignored for the database: '+@DBName,'I');
					EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForFullBackup','DIFFERENTIAL-BACKUP'	
				END
			END

			IF  @iAllowBackupOnDatabase = 1
			BEGIN	
	
				-- *****************************************************************************************************
				 -- IF NETWORK DRIVE OR URL DRIVE (AZURE SPECIFIC) IS USED FOR BACKUP THEN IGNORE THE DISK SPACE CHECK
				-- *****************************************************************************************************
				IF @BackupDrive = '\'  OR @BackupDrive = 'http'
					  SET @FreeSpaceInPercentage = @MinimumDiskSpaceForBackup  
				ELSE   -- IF NOT NETWORK DRIVE THEN 
				BEGIN
							-- *****************************************************************************************************
							-- the code below check how much total disk space is available on backup drive 
							--- JUST IN CASE BACKUP DRIVE IS MENTIONED WRONG IN CONFIG FILE; THEN NULL  VALUE IS RETURNED. IN SUCH
							-- A SCENARIO THE CODE BELOW WILL CALCULATE AS 100% FREE DISK SPACE
							-- *****************************************************************************************************
						EXECUTE  [SqlMantainence].GetTotalSpaceOfDrive @backupDrive, @TotalSpace OUTPUT 
						SELECT @TotalSpace = IsNull(@TotalSpace,1)    

						-- *****************************************************************************************************
							-- the code below checks how much free space is available on backup drive 
							--- JUST IN CASE BACKUP DRIVE IS MENTIONED WRONG IN CONFIG FILE; THEN NULL  VALUE IS RETURNED. IN SUCH
							-- A SCENARIO THE CODE BELOW WILL CALCULATE AS 100% FREE DISK SPACE
						-- *****************************************************************************************************
						EXECUTE  [SqlMantainence].GetFreeSpaceOfDrive @backupDrive, @FreeSpace OUTPUT  
						SELECT @FreeSpace = IsNull(@FreeSpace,1)  

						-- *****************************************************************************************************
							-- Calculating the percentage of free space available
						-- *****************************************************************************************************
						IF  @TOTALSPACE <> 0
						SET @FreeSpaceInPercentage = (@FreeSpace/@TotalSpace)*100	 
				END


				IF @BACKUPDRIVE = '\' 
				BEGIN
				    exec xp_cmdshell 'net use z: /delete'
					SET @Full_BackupFolder1 = 'net use z: ' +  @Full_BackupFolder
					exec xp_cmdshell @Full_BackupFolder1
					SET @Full_BackupFolder1 = 'z:'

				    exec xp_cmdshell 'net use y: /delete'
					SET @Diff_BackupFolder1 = 'net use y: ' +  @Diff_BackupFolder
					exec xp_cmdshell @Diff_BackupFolder1
					SET @Diff_BackupFolder1 = 'y:'

				END
				ELSE
				BEGIN
					SET @Full_BackupFolder1 = @Full_BackupFolder
					SET @Diff_BackupFolder1 = @Diff_BackupFolder
				END

				print @Diff_BackupFolder1

				-- *****************************************************************************************************
				-- If freespace is more than the minimum space recommended for this server then start taking backup
				-- *****************************************************************************************************
				IF Cast(@FreeSpaceInPercentage AS INT) >= @MinimumDiskSpaceForBackup
				BEGIN
					-- ***********************************************************************************************
					-- First Check if any FULL backup exist for this database
					-- if not then take the full backup first AND then differential backup
					-- This is required for any new database that was added since last full backup schedule
					-- Type  'D' THEN 'FULL', 'I' THEN 'DIFFERENTIAL', 'L' THEN 'TRANSACTION LOG',  ELSE 'UNKNOWN'
					--*************************************************************************************************
			
				
				If NOT  EXISTS(SELECT TOP 1 Type FROM msdb.dbo.backupSET WITH(NOLOCK) WHERE database_name =  @DBName AND Type = 'D' AND  Is_Copy_Only = 0)
					Begin

					set @FullBackupfilename = @Full_BackupFolder1 + '\' + @DBName + '@' +  
						Cast(DATEPART(YEAR,getdate()) as varchar(4)) + RIGHT('0'+Cast(DATEPART(MONTH,getdate()) as varchar(2)),2) + 
							RIGHT('0'+Cast(DATEPART(DAY,getdate()) as varchar(2)),2) + '_' + RIGHT('0'+Cast(DATEPART(HOUR,getdate()) as varchar(2)),2) + 
									RIGHT('0'+Cast(DATEPART(MINUTE,getdate()) as varchar(2)),2) + '.bak'
					 BEGIN TRY

								IF @BackupDrive = 'http'
								SET @SQL = 'BACKUP DATABASE [' + @DBName + '] 
									TO URL = ''' +  @FullBackupfilename + ''' 
									WITH  CREDENTIAL = ''SQLBackupCreds'', CHECKSUM, INIT'

							ELSE
									SET @SQL = 'BACKUP DATABASE [' + @DBName + '] to disk = ''' + @FullBackupfilename + ''' 
									WITH  CHECKSUM, INIT'

									print @sql
							EXECUTE (@SQL)


							-- This code below will encrypt the backup file using AESCrypt utility...only for stores.
							
							set @AescryptforFullBackupfile = 'C:\AESCrypt\BackupfileEncryption.bat "SQLDBp@$$w0rd"   "' + @FullBackupfilename + '"'
							exec xp_cmdshell @AescryptforFullBackupfile


							 

						   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'FULL-BACKUP','Full Backup Successfull for the database: '+@DBName,'I');
						 END TRY
						 BEGIN CATCH
							INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'DIFFERENTIAL-BACKUP','Full Backup failed for the database: '+ @DBName + ' (' + ERROR_MESSAGE() + ')','C');
							EXECUTE [SQLMantainence].[Log_Error] 'SP_MantainencePlanScriptForDiffBackup','DIFFERENTIAL-BACKUP'
						 END CATCH		     
					End
            
					-- *****************************************************************************************************
					-- Start Taking Differtential Backup
					-- *****************************************************************************************************
					
					SET @DiffBackupfilename = @Diff_BackupFolder1 + '\' + @DBName + '@' +  
						Cast(DATEPART(YEAR,getdate()) as varchar(4)) + RIGHT('0'+Cast(DATEPART(MONTH,getdate()) as varchar(2)),2) + 
						RIGHT('0'+Cast(DATEPART(DAY,getdate()) as varchar(2)),2) + '_' + RIGHT('0'+Cast(DATEPART(HOUR,getdate()) as varchar(2)),2) + 
									RIGHT('0'+Cast(DATEPART(MINUTE,getdate()) as varchar(2)),2) + '.bak'
					
					BEGIN TRY 
						IF @BackupDrive = 'http'
							SET @SQL = 'BACKUP DATABASE [' + @DBName + '] 
									TO URL = ''' + @DiffBackupfilename + ''' 
									WITH  CREDENTIAL = ''SQLBackupCreds'', DIFFERENTIAL, CHECKSUM, INIT '




						ELSE

									SET @SQL = 'BACKUP DATABASE [' + @DBName + '] 
									TO DISK = ''' +  @DiffBackupfilename + ''' 
									WITH  DIFFERENTIAL, CHECKSUM, INIT '

						print @sql
						EXECUTE (@SQL)


						-- This code below will encrypt the Diff backup file using AESCrypt utility...only for stores.
						
			                set @AescryptforDiffBackup = 'C:\AESCrypt\BackupfileEncryption.bat "SQLDBp@$$w0rd"   "' + @DiffBackupfilename + '"'
							exec xp_cmdshell @AescryptforDiffBackup


						INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'DIFFERENTIAL-BACKUP','Differential Backup Successfull for the database: '+@DBName,'I');
						EXECUTE [SQLMantainence].[Log_Error] 'SP_MantainencePlanScriptForDiffBackup','DIFFERENTIAL-BACKUP'
					END TRY
					BEGIN CATCH
						print error_message()
						INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'DIFFERENTIAL-BACKUP','Differential Backup failed for the database: '+@DBName + ' (' + ERROR_MESSAGE() + ')','C');
						EXECUTE  [SQLMantainence].[Log_Error] 'SP_MantainencePlanScriptForDiffBackup','DIFFERENTIAL-BACKUP'
					END CATCH
			
				   END --- End of  If available free space then
				 ELSE  -- Else if no free space is available
				 BEGIN
					-- *****************************************************************************************************
					-- Sent Email Notification 
					-- *****************************************************************************************************
					SET @ERRORMESSAGE = @ERRORMESSAGE + '<br>=> Could not execute Differntial backup for database ' + 
										@DBName + ' due to insufficient disk space in ' + @Diff_BackupFolder + '.'
					INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'DIFFERENTIAL-BACKUP','No sufficient space available for Differential-Backup: '+@DBName,'W');			 
					 EXECUTE [SQLMantainence].[Log_Error] 'SP_MantainencePlanScriptForDiffBackup','DIFFERENTIAL-BACKUP'			 
				 END
	     END -- END OF IF  @iAllowBackupOnDatabase = 1
	   
		 SELECT @iRow += 1
	END  -- End of While Loop
     
   Drop Table #DatabaseNamesForDiffBackup
    
    IF @ERRORMESSAGE != ''
    BEGIN
		Execute msdb..sp_send_dbmail @profile_name = 'DBMaintenance', @recipients = @EmailRecipient ,
			 @subject =@subject, 
			 @body_format= 'HTML',
			 @body = @ERRORMESSAGE, 
			 @execute_query_database = 'SQL_Admin'
	END		 
END TRY 

BEGIN CATCH
  EXECUTE [SQLMantainence].[Log_Error] 'SP_MantainencePlanScriptForDiffBackup','DIFFERENTIAL-BACKUP'
END CATCH  


END
GO

-- ***************************************************************************************************
-- END OF DIFFERENTIAL BACKUP SCRIPT
-- ***************************************************************************************************


-- ***************************************************************************************************
-- BEGIN OF TLOG BACKUP SCRIPT BELOW
-- ***************************************************************************************************
USE [Sql_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
	Author: Suji Nair
	Last Changes: 
*/
CREATE PROCEDURE  [SQLMantainence].[SP_MantainencePlanScriptForTLogBackup]	
-- With Encryption
AS
BEGIN
SET NOCOUNT ON;

DECLARE @Full_BackupFolder varchar(1000)
DECLARE @Full_BackupFolder1 varchar(1000)

DECLARE @TLOG_BackupFolder varchar (1000)
DECLARE @TLOG_BackupFolder1 varchar (1000)

DECLARE @EmailRecipient varchar (2000)
DECLARE @Environment varchar(50), @EnvironmentDesc varchar (50)
DECLARE @DBName varchar(200)
DECLARE @MinimumDiskSpaceForBackup BIGINT
DECLARE @SQL varchar(1000)
DECLARE @FreeSpace FLOAT =0
DECLARE @TotalSpace FLOAT = 0
DECLARE @FreeSpaceInPercentage INT = 0
DECLARE @CMD1 varchar(1000)=''
DECLARE @BackupDrive varchar(50)
DECLARE @Subject varchar(1000)
DECLARE @iRow SmallInt, @TotalRows SmallInt
Declare @iAllowBackupOnDatabase BIT   -- for database included for Always On 

DECLARE @FullBackupfilename varchar(200)
DECLARE @AescryptforFullBackupfile varchar (1000)

DECLARE @TlogBackupfilename varchar (200)
DECLARE @AescryptforTlogBackup varchar (1000)

 
-- *****************************************************************************************************	  
	-- The script below calculate the IP address of the current server for generating email alert
-- *****************************************************************************************************
DECLARE @ACTUAL_IP_ADDRESS VARCHAR(1000)  
CREATE TABLE #temp1(sql_ip VARCHAR(3000))
INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 
DECLARE @ipaddress varchar(300) 
SET @ipaddress = (SELECT TOP 1 sql_ip FROM #temp1 WHERE sql_ip like '%IPv4%' order by sql_ip DESC) 
DECLARE @len int 
SET @Len = CHARINDEX(':', @ipaddress) 
SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@ipaddress, @Len+1, LEN(@ipaddress)))) 
 -- *****************************************************************************************************
   
DECLARE @ERRORMESSAGE VARCHAR(MAX) ,
            @FormattedErrorMessage  VARCHAR(MAX),
            @ErrorNumber varchar(50),
            @ErrorSeverity varchar(50),
            @ErrorState  varchar(50),
            @ErrorLine  varchar(50),
            @ErrorProcedure  VARCHAR(200)
                 
 BEGIN TRY   

    SELECT @Full_BackupFolder			=value FROM SQLMantainence.DBMantainenceConfiguration WHERE configurationType='Full_BackupFolder'
    SELECT @TLOG_BackupFolder			=value FROM SQLMantainence.DBMantainenceConfiguration WHERE configurationType='T-LOG_BackupFolder'
    SELECT @EmailRecipient				=value FROM SQLMantainence.DBMantainenceConfiguration WHERE configurationType='EmailRecipient'
    SELECT @Environment					=value FROM SQLMantainence.DBMantainenceConfiguration WHERE configurationType='Environment'

    SELECT @MinimumDiskSpaceForBackup	=value FROM SQLMantainence.DBMantainenceConfiguration WHERE configurationType='MinimumDiskSpaceForBackup'

     SELECT @BackupDrive					=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='T-LOG_BackupFolder'    

		IF Left(IsNull(@BACKUPDRIVE,''),1) = '\'
			SELECT @BACKUPDRIVE = '\'
		ELSE IF Left(IsNull(@BACKUPDRIVE,''),4) = 'http'
			SELECT @BACKUPDRIVE = 'http'
		ELSE
			SELECT @BACKUPDRIVE = LEft(IsNull(@BACKUPDRIVE,''),2)
			
			    
	SELECT @Environment = IsNull(@Environment, 'Prod')
    SELECT @MinimumDiskSpaceForBackup = IsNull(@MinimumDiskSpaceForBackup,10)    
    SELECT @EnvironmentDesc = Case  Left(@Environment,3) When 'Dev' Then 'Development' When 'Prod' Then 'Production' Else  @Environment End
	SELECT @Subject = @EnvironmentDesc + ' - SQL Maintenance Job Failure For Server  ' + @@SERVERNAME + ' IP : ' +@ACTUAL_IP_ADDRESS

    CREATE TABLE #DatabaseNamesForDiffBackup (RowNo SmallInt Identity(1,1), Name varchar(1000))

	INSERT INTO  #DatabaseNamesForDiffBackup (Name)
	SELECT Name FROM SYS.databases
		WHERE  State_Desc='ONLINE' AND source_database_id IS NULL AND name NOT LIKE '%_TOBEDELETED%' AND  name NOT IN('Master','MSDB','Model','tempdb') AND Recovery_Model_Desc!='Simple' AND
			Name NOT IN (SELECT VALUE COLLATE Database_DEFAULT FROM [SQLMantainence].[DBMantainenceConfiguration]  WITH(NOLOCK) 
			WHERE ConfigurationType = 'ExcludeDatabase') AND Recovery_Model_Desc <> 'SIMPLE'

   
   SELECT @iRow = 1, @TotalRows = COUNT(*) FROM #DatabaseNamesForDiffBackup
   
   WHILE @iRow <= @TotalRows
   BEGIN 
		SELECT @DBName  = Name FROM #DatabaseNamesForDiffBackup WHERE RowNo = @iRow
	
		Set  @iAllowBackupOnDatabase = 1 -- by default ON for all database ....only if backup preference is turned off for a database then do not take backup
		    
			-- *****************************************************************************************************
			-- IF SQL 2012 or greater then check for AlwaysOn backup preferences
			-- *****************************************************************************************************
            IF cast(Left(cast(serverproperty('productversion') as varchar(100)),(charindex('.',cast(serverproperty('productversion') as varchar(100)))-1)) as int) >= 11 
			BEGIN
				SELECT @iAllowBackupOnDatabase = sys.fn_hadr_backup_is_preferred_replica(@DBName) 
				IF @iAllowBackupOnDatabase = 0
				BEGIN
										-- SCRIPT BELOW IS EXECUTED TO LOG THE ENTRY IN MAINTENANCE LOG FOR THE SUCESSFUL BACKUP OF THE CURRENT DATABASE
					INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'TLOG-BACKUP','Due to current AG setup, TLOG Backup was ignored for the database: '+@DBName,'I');
				END
			END

			IF  @iAllowBackupOnDatabase = 1
			BEGIN	
	
				-- *****************************************************************************************************
				 -- IF NETWORK DRIVE OR URL DRIVE (AZURE SPECIFIC) IS USED FOR BACKUP THEN IGNORE THE DISK SPACE CHECK
				-- *****************************************************************************************************
				IF @BackupDrive = '\'  OR @BackupDrive = 'http'
					  SET @FreeSpaceInPercentage = @MinimumDiskSpaceForBackup  
				ELSE   -- IF NOT NETWORK DRIVE THEN 
				BEGIN
							-- *****************************************************************************************************
							-- the code below check how much total disk space is available on backup drive 
							--- JUST IN CASE BACKUP DRIVE IS MENTIONED WRONG IN CONFIG FILE; THEN NULL  VALUE IS RETURNED. IN SUCH
							-- A SCENARIO THE CODE BELOW WILL CALCULATE AS 100% FREE DISK SPACE
							-- *****************************************************************************************************
						EXECUTE  [SqlMantainence].GetTotalSpaceOfDrive @backupDrive, @TotalSpace OUTPUT 
						SELECT @TotalSpace = IsNull(@TotalSpace,1)    

						-- *****************************************************************************************************
							-- the code below checks how much free space is available on backup drive 
							--- JUST IN CASE BACKUP DRIVE IS MENTIONED WRONG IN CONFIG FILE; THEN NULL  VALUE IS RETURNED. IN SUCH
							-- A SCENARIO THE CODE BELOW WILL CALCULATE AS 100% FREE DISK SPACE
						-- *****************************************************************************************************
						EXECUTE  [SqlMantainence].GetFreeSpaceOfDrive @backupDrive, @FreeSpace OUTPUT  
						SELECT @FreeSpace = IsNull(@FreeSpace,1)  

						-- *****************************************************************************************************
							-- Calculating the percentage of free space available
						-- *****************************************************************************************************
						IF  @TOTALSPACE <> 0
						SET @FreeSpaceInPercentage = (@FreeSpace/@TotalSpace)*100	 
				END

				IF Left(@Full_BackupFolder,1) = '\' 
				BEGIN
				    exec xp_cmdshell 'net use z: /delete'
					SET @Full_BackupFolder1 = 'net use z: ' +  @Full_BackupFolder
					exec xp_cmdshell @Full_BackupFolder1
					SET @Full_BackupFolder1 = 'z:'
				END
				ELSE
					SET @Full_BackupFolder1 = @Full_BackupFolder
					

				IF Left(@TLOG_BackupFolder,1) = '\' 
				BEGIN
				    exec xp_cmdshell 'net use y: /delete'
					SET @TLOG_BackupFolder1 = 'net use y: ' +  @TLOG_BackupFolder
					exec xp_cmdshell @TLOG_BackupFolder1
					SET @TLOG_BackupFolder1 = 'y:'
				END
				ELSE
					SET @TLOG_BackupFolder1 = @TLOG_BackupFolder


				-- *****************************************************************************************************
				-- If freespace is more than the minimum space recommended for this server then start taking backup
				-- *****************************************************************************************************
				IF Cast(@FreeSpaceInPercentage AS INT) >= @MinimumDiskSpaceForBackup
				BEGIN
					-- ***********************************************************************************************
					-- First Check if any FULL backup exist for this database
					-- if not then take the full backup first AND then TLOG backup
					-- This is required for any new database that was added since last full backup schedule
					-- Type  'D' THEN 'FULL', 'I' THEN 'TLOG', 'L' THEN 'TRANSACTION LOG',  ELSE 'UNKNOWN'
					--*************************************************************************************************
					If NOT  EXISTS(SELECT TOP 1 Type FROM msdb.dbo.backupSET WITH(NOLOCK) WHERE database_name =  @DBName AND Type = 'D' AND  Is_Copy_Only = 0)
					Begin

					SET @FullBackupfilename = +  @Full_BackupFolder1 + '\' + @DBName + '@' +  
									Cast(DATEPART(YEAR,getdate()) as varchar(4)) + RIGHT('0'+Cast(DATEPART(MONTH,getdate()) as varchar(2)),2) + 
									RIGHT('0'+Cast(DATEPART(DAY,getdate()) as varchar(2)),2) + '_' + RIGHT('0'+Cast(DATEPART(HOUR,getdate()) as varchar(2)),2) + 
									RIGHT('0'+Cast(DATEPART(MINUTE,getdate()) as varchar(2)),2) + '.bak'

					 BEGIN TRY
							
				 


							IF @BackupDrive = 'http'
								SET @SQL = 'BACKUP DATABASE [' + @DBName + '] 
									TO URL = ''' +  @FullBackupfilename + ''' 
									WITH  CREDENTIAL = ''SQLBackupCreds'', CHECKSUM, INIT'

							ELSE
				 
								SET @SQL = 'BACKUP DATABASE [' + @DBName + '] to disk = ''' +  @FullBackupfilename + ''' 
									WITH  CHECKSUM, INIT'
							EXECUTE (@SQL)


							-- This code below will encrypt the backup file using AESCrypt utility...only for stores.
							
			                set @AescryptforFullBackupfile = 'C:\AESCrypt\BackupfileEncryption.bat "SQLDBp@$$w0rd"   "' + @FullBackupfilename + '"'
							exec xp_cmdshell @AescryptforFullBackupfile



						   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'FULL-BACKUP','Full Backup (New Database) Successfull for the database: '+@DBName,'I');
						 END TRY
						 BEGIN CATCH

							INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'FULL-BACKUP','Full Backup (New Database) failed for the database: '+@DBName,'C');
							EXECUTE [SQLMantainence].[Log_Error] 'SP_MantainencePlanScriptForTLOGBackup','FULL-BACKUP'
						 END CATCH		     
					End
            
					-- *****************************************************************************************************
					-- Start Taking tlog Backup
					-- *****************************************************************************************************
					SET @TlogBackupfilename = @Tlog_BackupFolder1 + '\' + @DBName + '@' +  
								CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR(4)) + RIGHT('0'+CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR(2)),2) + 
							RIGHT('0'+CAST(DATEPART(DAY,GETDATE()) AS VARCHAR(2)),2) + '_' + RIGHT('0'+CAST(DATEPART(HOUR,GETDATE()) AS VARCHAR(2)),2) + 
								RIGHT('0'+CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR(2)),2) + '.TRN'
					
					BEGIN TRY 


							--IF @BACKUPDRIVE = 'http'   
							--SET @SQL = 'BACKUP LOG [' + @DBName + '] 
							--	TO URL = ''' +  @TLOG_BackupFolder1 + '/' + @DBName + '@' +  
							--	CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR(4)) + RIGHT('0'+CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR(2)),2) + 
							--	RIGHT('0'+CAST(DATEPART(DAY,GETDATE()) AS VARCHAR(2)),2) + '_' + RIGHT('0'+CAST(DATEPART(HOUR,GETDATE()) AS VARCHAR(2)),2) + 
							--	RIGHT('0'+CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR(2)),2) + '.TRN''
							--	WITH CREDENTIAL = ''SQLBackupCreds'''



								IF @BACKUPDRIVE = 'http'   
							SET @SQL = 'BACKUP LOG [' + @DBName + '] 
								TO URL = ''' +  @TlogBackupfilename + ''' 
								WITH CREDENTIAL = ''SQLBackupCreds'''


						ELSE
					 



								SET @SQL = 'BACKUP LOG [' + @DBName + '] TO DISK = ''' +  @TlogBackupfilename + ''''
						
						EXECUTE (@SQL)

						-- This code below will encrypt the backup file using AESCrypt utility...only for stores.

			                set @AescryptforTlogBackup = 'C:\AESCrypt\BackupfileEncryption.bat "SQLDBp@$$w0rd"   "' + @TlogBackupfilename + '"'
							exec xp_cmdshell @AescryptforTlogBackup




						INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'TLOG-BACKUP','TLOG Backup Successfull for the database: '+@DBName,'I');

					END TRY
					BEGIN CATCH
						INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'TLOG-BACKUP','TLOG Backup failed for the database: '+@DBName+ ' (' + ERROR_MESSAGE() + ')','C');
						EXECUTE  [SQLMantainence].[Log_Error] 'SP_MantainencePlanScriptForTLOGBackup','TLOG-BACKUP'
					END CATCH
			
				   END --- End of  If available free space then
				 ELSE  -- Else if no free space is available
				 BEGIN
					-- *****************************************************************************************************
					-- Sent Email Notification 
					-- *****************************************************************************************************
					SET @ERRORMESSAGE = @ERRORMESSAGE + '<br>=> Could not execute TLOG backup for database ' + 
										@DBName + ' due to insufficient disk space in ' + @TLOG_BackupFolder + '.'
					INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'TLOG-BACKUP','No sufficient space available for TLOG-BACKUP: '+@DBName,'W');			 
					 EXECUTE [SQLMantainence].[Log_Error] 'SP_MantainencePlanScriptForTLOGBackup','TLOG-BACKUP'			 
				 END
	     END -- END OF IF  @iAllowBackupOnDatabase = 1
	   
		 SELECT @iRow += 1
	END  -- End of While Loop
     
   Drop Table #DatabaseNamesForDiffBackup
    
    IF @ERRORMESSAGE != ''
    BEGIN
		Execute msdb..sp_send_dbmail @profile_name = 'DBMaintenance', @recipients = @EmailRecipient ,
			 @subject =@subject, 
			 @body_format= 'HTML',
			 @body = @ERRORMESSAGE, 
			 @execute_query_database = 'SQL_Admin'
	END		 
END TRY 

BEGIN CATCH
  EXECUTE [SQLMantainence].[Log_Error] 'SP_MantainencePlanScriptForTLOGBackup','TLOG-BACKUP'
END CATCH  


END

GO


-- ***************************************************************************************************
-- BEGIN OF MONTHLY BACKUP SCRIPT BELOW
-- ***************************************************************************************************
USE [SQL_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
	Author: Suji Nair
	Last Changes: New SP for creating special copy only backups for Monthly database images
*/
CREATE PROCEDURE  [SQLMantainence].[SP_MantainencePlanScriptForMonthlyBackup] 
 -- With Encryption
AS
BEGIN
	SET NOCOUNT ON;
	
    DECLARE @Monthly_BackupFolder VARCHAR(1000)
	DECLARE @Monthly_BackupFolder1 VARCHAR(1000)

    DECLARE @EMAILRECIPIENT VARCHAR (2000)
    DECLARE @ENVIRONMENT VARCHAR(50), @ENVIRONMENTDESC VARCHAR (50)
    DECLARE @DBNAME VARCHAR(200)
    DECLARE @MINIMUMDISKSPACEFORBACKUP BIGINT
    DECLARE @SQL VARCHAR(1000)
    DECLARE @FREESPACE FLOAT =0
	DECLARE @TOTALSPACE FLOAT = 0
	DECLARE @FREESPACEINPERCENTAGE INT = 0
    DECLARE @RetentionPeriodForMonthlybackupInDays INT
    DECLARE @FLAG_FORMSDB BIT    
	DECLARE @ACTUAL_IP_ADDRESS VARCHAR(1000)  
	DECLARE @BACKUPDRIVE VARCHAR(50)
    DECLARE @ERRORMESSAGE VARCHAR(MAX) ,
              @FORMATTEDERRORMESSAGE  VARCHAR(MAX),
              @ERRORNUMBER VARCHAR(50),
              @ERRORSEVERITY VARCHAR(50),
              @ERRORSTATE  VARCHAR(50),
              @ERRORLINE  VARCHAR(50),
              @ERRORPROCEDURE  VARCHAR(200)
    DECLARE @SUBJECT VARCHAR(1000)          
    DECLARE @IROW SMALLINT, @TOTALROWS SMALLINT
	Declare @iAllowBackupOnDatabase BIT   -- for database included for Always On

	-- *****************************************************************************************************
             -- TO GET THE IP ADDRESS OF THE SERVER WHERE THE JOB IS BEING EXECUTED I.E. FOR REPORTING PURPOSE
	-- *****************************************************************************************************
	CREATE TABLE #TEMP1(SQL_IP VARCHAR(3000))
	INSERT INTO #TEMP1 EXECUTE XP_CMDSHELL 'IPCONFIG' 
	DECLARE @IPADDRESS VARCHAR(300) 
	SET @IPADDRESS = (SELECT TOP 1 SQL_IP FROM #TEMP1  WITH(NOLOCK)  WHERE SQL_IP LIKE '%IPV4%' ORDER BY SQL_IP DESC) 
	If @IPAddress IS NULL
		SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IP Address%' ORDER BY SQL_IP DESC) 	
	
	SET @IPAddress = IsNull(@IPAddress,'')

	DECLARE @LEN INT 
	SET @LEN = CHARINDEX(':', @IPADDRESS) 
	SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPADDRESS, @LEN+1, LEN(@IPADDRESS)))) 
	DROP TABLE #TEMP1 
	-- *****************************************************************************************************

   BEGIN TRY     
		SELECT @Monthly_BackupFolder				=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Monthly_BackupFolder'
		SELECT @EmailRecipient						=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='EmailRecipient'
		SELECT @Environment							=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Environment'
		SELECT @MinimumDiskSpaceForBackup			=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='MinimumDiskSpaceForBackup'
		SELECT @RetentionPeriodForMonthlybackupInDays	=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='RetentionPeriodForMonthlybackupInDays'
		SELECT @BackupDrive							=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Monthly_BackupFolder'

		IF Left(IsNull(@BACKUPDRIVE,''),1) = '\'
			SELECT @BACKUPDRIVE = '\'
		ELSE IF Left(IsNull(@BACKUPDRIVE,''),4) = 'http'
			SELECT @BACKUPDRIVE = 'http'
		ELSE
			SELECT @BACKUPDRIVE = IsNull(@BACKUPDRIVE,'')


		SELECT @RetentionPeriodForMonthlybackupInDays = ISNULL(@RetentionPeriodForMonthlybackupInDays,8)
				
		SELECT @MinimumDiskSpaceForBackup	= ISNULL(@MinimumDiskSpaceForBackup,10)	    		
	    SELECT @Environment = ISNULL(@Environment, 'Prod')
		SELECT @EnvironmentDesc = CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END
		SELECT @Subject = @EnvironmentDesc + ' - SQL Maintenance Job Failure For Server  ' + @@SERVERNAME + ' IP : ' +@ACTUAL_IP_ADDRESS

		-- *******************************************************************************************************
			-- Get List of database for which maintenance is required.  The query condition ignores Model, TempDB 
			-- and all database which is marked with "_TOBEDELETED".  Also any database name that is marked under
			-- "DatabaseName_ForSecondBackupJob" is ignored by this job; since that is backed up by another job
		-- *******************************************************************************************************
		Create Table #DatabaseNamesForMonthlyBackup (RowNo SmallInt Identity(1,1), Name varchar(1000))	    
    
		INSERT INTO  #DATABASENAMESFORMonthlyBACKUP (NAME)
		  SELECT NAME FROM SYS.DATABASES  WITH(NOLOCK) 
		  WHERE STATE_DESC='ONLINE' AND NAME NOT LIKE '%_TOBEDELETED%' AND SOURCE_DATABASE_ID IS NULL AND  NAME NOT IN('MODEL','TEMPDB','MSDB','MASTER','DISTRIBUTION') AND
				NAME NOT IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM [SQLMANTAINENCE].[DBMANTAINENCECONFIGURATION]  WITH(NOLOCK) WHERE CONFIGURATIONTYPE IN ('EXCLUDEDATABASE','DatabaseName_ForSecondBackupJob'))
	   

	   SELECT @IROW = 1, @TOTALROWS = COUNT(*) FROM #DATABASENAMESFORMonthlyBACKUP
	   
	   WHILE @IROW <= @TOTALROWS
	   BEGIN 
			SELECT @DBNAME  = NAME FROM #DATABASENAMESFORMonthlyBACKUP WHERE ROWNO = @IROW
	       
				-- *****************************************************************************************
				-- IF NETWORK DRIVE or URL (Azure backup) IS USED FOR BACKUP THEN IGNORE THE DISK SPACE CHECK
				-- *****************************************************************************************
				IF Left(@BACKUPDRIVE,1) = '\' OR @BACKUPDRIVE = 'http'  OR Ltrim(@BACKUPDRIVE) = ''
					  SET @FREESPACEINPERCENTAGE = @MINIMUMDISKSPACEFORBACKUP  
				ELSE   -- IF NOT NETWORK or URL AZURE BACKUP DRIVE THEN DO THE MINIMUM DISK AVAILABILITY CHECK
				BEGIN
							-- THE CODE BELOW CHECK HOW MUCH TOTAL DISK SPACE IS AVAILABLE ON BACKUP DRIVE 
							--- JUST IN CASE BACKUP DRIVE IS MENTIONED WRONG IN CONFIG FILE; THEN NULL  VALUE IS RETURNED. IN SUCH
							-- A SCENARIO THE CODE BELOW WILL CALCULATE AS 100% FREE DISK SPACE
						EXECUTE  [SQLMANTAINENCE].GETTOTALSPACEOFDRIVE @BACKUPDRIVE, @TOTALSPACE OUTPUT 
						SELECT @TOTALSPACE = ISNULL(@TOTALSPACE,1)    


							-- THE CODE BELOW CHECKS HOW MUCH FREE SPACE IS AVAILABLE ON BACKUP DRIVE 
							--- JUST IN CASE BACKUP DRIVE IS MENTIONED WRONG IN CONFIG FILE; THEN NULL  VALUE IS RETURNED. IN SUCH
							-- A SCENARIO THE CODE BELOW WILL CALCULATE AS 100% FREE DISK SPACE
						EXECUTE  [SQLMANTAINENCE].GETFREESPACEOFDRIVE @BACKUPDRIVE, @FREESPACE OUTPUT  
						SELECT @FREESPACE = ISNULL(@FREESPACE,1)  

							-- CALCULATING THE PERCENTAGE OF FREE SPACE AVAILABLE
						IF  @TOTALSPACE <> 0
						SET @FREESPACEINPERCENTAGE = (@FREESPACE/@TOTALSPACE)*100	 
				END


				
				IF @BACKUPDRIVE = '\' 
				BEGIN
				    exec xp_cmdshell 'net use z: /delete'
					SET @Monthly_BackupFolder1 = 'net use z: ' +  @Monthly_BackupFolder
					exec xp_cmdshell @Monthly_BackupFolder1
					SET @Monthly_BackupFolder1 = 'z:'
				END
				ELSE
					SET @Monthly_BackupFolder1 = @Monthly_BackupFolder

				-- *****************************************************************************************
				-- IF FREESPACE IS MORE THAN THE MINIMUM SPACE RECOMMENDED FOR THIS SERVER THEN START TAKING BACKUP
				-- *****************************************************************************************
				IF CAST(@FREESPACEINPERCENTAGE AS INT) >= CAST(ISNULL(@MINIMUMDISKSPACEFORBACKUP,0) AS INT)
				BEGIN       
				BEGIN TRY 
						SET @SQL = 'BACKUP DATABASE [' + @DBNAME + '] TO DISK = ''' +  @Monthly_BackupFolder1 + '\' + @DBNAME + '_MonthlyBackup@' +  
							CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR(4)) + RIGHT('0'+CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR(2)),2) + 
							RIGHT('0'+CAST(DATEPART(DAY,GETDATE()) AS VARCHAR(2)),2) + '_' + RIGHT('0'+CAST(DATEPART(HOUR,GETDATE()) AS VARCHAR(2)),2) + 
							RIGHT('0'+CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR(2)),2) + '.BAK'' WITH  COPY_ONLY, CHECKSUM, INIT'
									
							PRINT @SQL   -- DEBUG CODE ...REMOVE LATER

							EXECUTE (@SQL)				      
								
							--EXECUTE [SQLMANTAINENCE].[PROC_DELETEOLDMonthlyBACKUPS] 
							--@DBNAME,@Monthly_BackupFolder,@DIFF_BACKUPFOLDER, @RetentionPeriodForMonthlybackupInDays,
							--@RETENTIONPERIODFORDIFFBACKUPINDAYS								
								-- SCRIPT BELOW IS EXECUTED TO LOG THE ENTRY IN MAINTENANCE LOG FOR THE SUCESSFUL BACKUP OF THE CURRENT DATABASE
							INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'Monthly-BACKUP','Monthly Backup SuccessMonthly for the database: '+@DBName,'I');
							EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForMonthlyBackup','Monthly-BACKUP'				
			     END TRY
					
				BEGIN CATCH
						-- SCRIPT BELOW IS TO RECORD FAILED BACKUP ENTRY FOR THE CURRENT DATABASE
					INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'Monthly-BACKUP','Monthly Backup failed for the database: '+@DBName,'C');
					EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForMonthlyBackup','Monthly-BACKUP'
				END CATCH
			END -- END OF IF  @iAllowBackupOnDatabase = 1		  
		   
				SELECT @IROW += 1
		END  -- END OF WHILE LOOP
	   
		DROP TABLE #DATABASENAMESFORMonthlyBACKUP
	  	   
		IF @ERRORMESSAGE != ''
		BEGIN
			EXECUTE MSDB..SP_SEND_DBMAIL @PROFILE_NAME = 'DBMAINTENANCE', @RECIPIENTS = @EMAILRECIPIENT ,
				 @SUBJECT =@SUBJECT, 
				 @BODY_FORMAT= 'HTML',
				 @BODY = @ERRORMESSAGE, 
				 @EXECUTE_QUERY_DATABASE = 'SQL_ADMIN'
		END		 
		
	END TRY 

	BEGIN CATCH
		   EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForMonthlyBackup','Monthly-BACKUP'
	END CATCH

END
GO
-- ***************************************************************************************************
-- END OF MONTHLY BACKUP SCRIPT BELOW
-- ***************************************************************************************************

-- ***************************************************************************************************
-- BEGIN OF YEARLY BACKUP SCRIPT BELOW
-- ***************************************************************************************************
USE [SQL_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
	Author: Suji Nair
	Last Changes: New SP for creating special copy only backups for Yearly database images
*/
CREATE PROCEDURE  [SQLMantainence].[SP_MantainencePlanScriptForYearlyBackup] 
 -- With Encryption
AS
BEGIN
	SET NOCOUNT ON;
	
    DECLARE @Yearly_BackupFolder VARCHAR(1000)
	DECLARE @Yearly_BackupFolder1 varchar(1000)

    DECLARE @EMAILRECIPIENT VARCHAR (2000)
    DECLARE @ENVIRONMENT VARCHAR(50), @ENVIRONMENTDESC VARCHAR (50)
    DECLARE @DBNAME VARCHAR(200)
    DECLARE @MINIMUMDISKSPACEFORBACKUP BIGINT
    DECLARE @SQL VARCHAR(1000)
    DECLARE @FREESPACE FLOAT =0
	DECLARE @TOTALSPACE FLOAT = 0
	DECLARE @FREESPACEINPERCENTAGE INT = 0
    DECLARE @RetentionPeriodForYearlybackupInDays INT
    DECLARE @FLAG_FORMSDB BIT    
	DECLARE @ACTUAL_IP_ADDRESS VARCHAR(1000)  
	DECLARE @BACKUPDRIVE VARCHAR(50)
    DECLARE @ERRORMESSAGE VARCHAR(MAX) ,
              @FORMATTEDERRORMESSAGE  VARCHAR(MAX),
              @ERRORNUMBER VARCHAR(50),
              @ERRORSEVERITY VARCHAR(50),
              @ERRORSTATE  VARCHAR(50),
              @ERRORLINE  VARCHAR(50),
              @ERRORPROCEDURE  VARCHAR(200)
    DECLARE @SUBJECT VARCHAR(1000)          
    DECLARE @IROW SMALLINT, @TOTALROWS SMALLINT
	Declare @iAllowBackupOnDatabase BIT   -- for database included for Always On
	


	-- *****************************************************************************************************
             -- TO GET THE IP ADDRESS OF THE SERVER WHERE THE JOB IS BEING EXECUTED I.E. FOR REPORTING PURPOSE
	-- *****************************************************************************************************
	CREATE TABLE #TEMP1(SQL_IP VARCHAR(3000))
	INSERT INTO #TEMP1 EXECUTE XP_CMDSHELL 'IPCONFIG' 
	DECLARE @IPADDRESS VARCHAR(300) 
	SET @IPADDRESS = (SELECT TOP 1 SQL_IP FROM #TEMP1  WITH(NOLOCK)  WHERE SQL_IP LIKE '%IPV4%' ORDER BY SQL_IP DESC) 
	If @IPAddress IS NULL
		SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IP Address%' ORDER BY SQL_IP DESC) 	
	
	SET @IPAddress = IsNull(@IPAddress,'')

	DECLARE @LEN INT 
	SET @LEN = CHARINDEX(':', @IPADDRESS) 
	SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPADDRESS, @LEN+1, LEN(@IPADDRESS)))) 
	DROP TABLE #TEMP1 
	-- *****************************************************************************************************

   BEGIN TRY     
		SELECT @Yearly_BackupFolder				=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Yearly_BackupFolder'
		SELECT @EmailRecipient						=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='EmailRecipient'
		SELECT @Environment							=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Environment'
		SELECT @MinimumDiskSpaceForBackup			=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='MinimumDiskSpaceForBackup'
		SELECT @RetentionPeriodForYearlybackupInDays	=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='RetentionPeriodForYearlybackupInDays'
		SELECT @BackupDrive							=VALUE FROM [SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType='Yearly_BackupFolder'

	IF Left(IsNull(@BACKUPDRIVE,''),1) = '\'
		SELECT @BACKUPDRIVE = '\'
	ELSE IF Left(IsNull(@BACKUPDRIVE,''),4) = 'http'
		SELECT @BACKUPDRIVE = 'http'
	ELSE
		SELECT @BACKUPDRIVE = IsNull(@BACKUPDRIVE,'')

		SELECT @RetentionPeriodForYearlybackupInDays = ISNULL(@RetentionPeriodForYearlybackupInDays,8)
				
		SELECT @MinimumDiskSpaceForBackup	= ISNULL(@MinimumDiskSpaceForBackup,10)	    		
	    SELECT @Environment = ISNULL(@Environment, 'Prod')
		SELECT @EnvironmentDesc = CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END
		SELECT @Subject = @EnvironmentDesc + ' - SQL Maintenance Job Failure For Server  ' + @@SERVERNAME + ' IP : ' +@ACTUAL_IP_ADDRESS

		-- *******************************************************************************************************
			-- Get List of database for which maintenance is required.  The query condition ignores Model, TempDB 
			-- and all database which is marked with "_TOBEDELETED".  Also any database name that is marked under
			-- "DatabaseName_ForSecondBackupJob" is ignored by this job; since that is backed up by another job
		-- *******************************************************************************************************
		Create Table #DatabaseNamesForYearlyBackup (RowNo SmallInt Identity(1,1), Name varchar(1000))	    
    
		INSERT INTO  #DATABASENAMESFORYearlyBACKUP (NAME)
		  SELECT NAME FROM SYS.DATABASES  WITH(NOLOCK) 
		  WHERE STATE_DESC='ONLINE' AND NAME NOT LIKE '%_TOBEDELETED%' AND SOURCE_DATABASE_ID IS NULL AND  NAME NOT IN('MODEL','TEMPDB','MSDB','MASTER','DISTRIBUTION') AND
				NAME NOT IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM [SQLMANTAINENCE].[DBMANTAINENCECONFIGURATION]  WITH(NOLOCK) WHERE CONFIGURATIONTYPE IN ('EXCLUDEDATABASE','DatabaseName_ForSecondBackupJob'))
	   

	   SELECT @IROW = 1, @TOTALROWS = COUNT(*) FROM #DATABASENAMESFORYearlyBACKUP
	   
	   WHILE @IROW <= @TOTALROWS
	   BEGIN 
			SELECT @DBNAME  = NAME FROM #DATABASENAMESFORYearlyBACKUP WHERE ROWNO = @IROW
	       
				-- *****************************************************************************************
				-- IF NETWORK DRIVE or URL (Azure backup) IS USED FOR BACKUP THEN IGNORE THE DISK SPACE CHECK
				-- *****************************************************************************************
				IF Left(@BACKUPDRIVE,1) = '\' OR @BACKUPDRIVE = 'http'  OR Ltrim(@BACKUPDRIVE) = ''
					  SET @FREESPACEINPERCENTAGE = @MINIMUMDISKSPACEFORBACKUP  
				ELSE   -- IF NOT NETWORK or URL AZURE BACKUP DRIVE THEN DO THE MINIMUM DISK AVAILABILITY CHECK
				BEGIN
							-- THE CODE BELOW CHECK HOW MUCH TOTAL DISK SPACE IS AVAILABLE ON BACKUP DRIVE 
							--- JUST IN CASE BACKUP DRIVE IS MENTIONED WRONG IN CONFIG FILE; THEN NULL  VALUE IS RETURNED. IN SUCH
							-- A SCENARIO THE CODE BELOW WILL CALCULATE AS 100% FREE DISK SPACE
						EXECUTE  [SQLMANTAINENCE].GETTOTALSPACEOFDRIVE @BACKUPDRIVE, @TOTALSPACE OUTPUT 
						SELECT @TOTALSPACE = ISNULL(@TOTALSPACE,1)    


							-- THE CODE BELOW CHECKS HOW MUCH FREE SPACE IS AVAILABLE ON BACKUP DRIVE 
							--- JUST IN CASE BACKUP DRIVE IS MENTIONED WRONG IN CONFIG FILE; THEN NULL  VALUE IS RETURNED. IN SUCH
							-- A SCENARIO THE CODE BELOW WILL CALCULATE AS 100% FREE DISK SPACE
						EXECUTE  [SQLMANTAINENCE].GETFREESPACEOFDRIVE @BACKUPDRIVE, @FREESPACE OUTPUT  
						SELECT @FREESPACE = ISNULL(@FREESPACE,1)  

							-- CALCULATING THE PERCENTAGE OF FREE SPACE AVAILABLE
						IF  @TOTALSPACE <> 0
						SET @FREESPACEINPERCENTAGE = (@FREESPACE/@TOTALSPACE)*100	 
				END

				
				IF @BACKUPDRIVE = '\' 
				BEGIN
				    exec xp_cmdshell 'net use z: /delete'
					SET @Yearly_BackupFolder1 = 'net use z: ' +  @Yearly_BackupFolder
					exec xp_cmdshell @Yearly_BackupFolder1
					SET @Yearly_BackupFolder1 = 'z:'
				END
				ELSE
					SET @Yearly_BackupFolder1 = @Yearly_BackupFolder
					



				-- *****************************************************************************************
				-- IF FREESPACE IS MORE THAN THE MINIMUM SPACE RECOMMENDED FOR THIS SERVER THEN START TAKING BACKUP
				-- *****************************************************************************************
				IF CAST(@FREESPACEINPERCENTAGE AS INT) >= CAST(ISNULL(@MINIMUMDISKSPACEFORBACKUP,0) AS INT)
				BEGIN       
				BEGIN TRY 
						SET @SQL = 'BACKUP DATABASE [' + @DBNAME + '] TO DISK = ''' +  @Yearly_BackupFolder1 + '\' + @DBNAME + '_YearlyBackup@' +  
							CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR(4)) + RIGHT('0'+CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR(2)),2) + 
							RIGHT('0'+CAST(DATEPART(DAY,GETDATE()) AS VARCHAR(2)),2) + '_' + RIGHT('0'+CAST(DATEPART(HOUR,GETDATE()) AS VARCHAR(2)),2) + 
							RIGHT('0'+CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR(2)),2) + '.BAK'' WITH  COPY_ONLY, CHECKSUM, INIT'
									
							PRINT @SQL   -- DEBUG CODE ...REMOVE LATER

							EXECUTE (@SQL)				      
								
							--EXECUTE [SQLMANTAINENCE].[PROC_DELETEOLDYearlyBACKUPS] 
							--@DBNAME,@Yearly_BackupFolder,@DIFF_BACKUPFOLDER, @RetentionPeriodForYearlybackupInDays,
							--@RETENTIONPERIODFORDIFFBACKUPINDAYS								
								-- SCRIPT BELOW IS EXECUTED TO LOG THE ENTRY IN MAINTENANCE LOG FOR THE SUCESSFUL BACKUP OF THE CURRENT DATABASE
							INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'Yearly-BACKUP','Yearly Backup SuccessYearly for the database: '+@DBName,'I');
							EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForYearlyBackup','Yearly-BACKUP'				
			     END TRY
					
				BEGIN CATCH
						-- SCRIPT BELOW IS TO RECORD FAILED BACKUP ENTRY FOR THE CURRENT DATABASE
					INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'Yearly-BACKUP','Yearly Backup failed for the database: '+@DBName,'C');
					EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForYearlyBackup','Yearly-BACKUP'
				END CATCH
			END -- END OF IF  @iAllowBackupOnDatabase = 1		  
		   
				SELECT @IROW += 1
		END  -- END OF WHILE LOOP
	   
		DROP TABLE #DATABASENAMESFORYearlyBACKUP
	  	   
		IF @ERRORMESSAGE != ''
		BEGIN
			EXECUTE MSDB..SP_SEND_DBMAIL @PROFILE_NAME = 'DBMAINTENANCE', @RECIPIENTS = @EMAILRECIPIENT ,
				 @SUBJECT =@SUBJECT, 
				 @BODY_FORMAT= 'HTML',
				 @BODY = @ERRORMESSAGE, 
				 @EXECUTE_QUERY_DATABASE = 'SQL_ADMIN'
		END		 
		
	END TRY 

	BEGIN CATCH
		   EXECUTE [SQLMANTAINENCE].[LOG_ERROR] 'SP_MantainencePlanScriptForYearlyBackup','Yearly-BACKUP'
	END CATCH

END
GO
-- ***************************************************************************************************
-- END OF YEARLY BACKUP SCRIPT BELOW
-- ***************************************************************************************************

-- ***************************************************************************************************
-- END OF TLOG BACKUP SCRIPT
-- ***************************************************************************************************


USE [Sql_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
THIS PROCEDURE IS DESIGNED FOR DEVELOPERS TO TAKE ADHOC DIFFERENTIAL BACKUP THEMSELVES
*/
CREATE PROC [DBO].[PROC_EXECUTEBACKUP]
@DATABASENAME VARCHAR(1000) = NULL
-- With Encryption
AS
BEGIN
	EXECUTE [SQLMANTAINENCE].[SP_MANTAINENCEPLANSCRIPTFORDIFFBACKUP] @DATABASENAME = @DATABASENAME
	
	DECLARE @BACKUPLOCATION VARCHAR(1000)
	SELECT @BACKUPLOCATION = VALUE FROM SQLMANTAINENCE.DBMANTAINENCECONFIGURATION WHERE CONFIGURATIONTYPE = 'DIFF_BACKUPFOLDER'
	SELECT 'DIFFERENTIAL BACKUP LOCATION = ' +  @BACKUPLOCATION
END
GO




/****** Object:  StoredProcedure [SQLMantainence].[ResolveOrphanUsers]    Script Date: 11/23/2012 19:32:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[ResolveOrphanUsers]') AND TYPE IN (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'
		-- **********************************************************************
		-- 1. CHANGE THE SOURCE SQL SERVER SERVER NAME BEFORE EXECUTING THIS SCRIPT
		-- 2. CHANGE THE FLAG BELOW TO SPECIFY WHETHER THE ORPHAN SQL USER NEED TO BE MAPPED TO EXISTING LOGIN
		-- **********************************************************************		
CREATE PROCEDURE [SQLMantainence].[ResolveOrphanUsers]	
	
AS
BEGIN
	SET NOCOUNT ON;

		-- **********************************************************************
		-- 1. CHANGE THE SOURCE SQL SERVER SERVER NAME BEFORE EXECUTING THIS SCRIPT
		-- 2. CHANGE THE FLAG BELOW TO SPECIFY WHETHER THE ORPHAN SQL USER NEED TO BE MAPPED TO EXISTING LOGIN
		-- **********************************************************************		
	DECLARE @SourceSQLServerName VarChar(1000) = ''?''
	DECLARE @Force_SQLLoginMapping_To_ExistingUser BIT = 0  -- 0/1 I.E. TRUE/FALSE
		-- **********************************************************************************
	
	PRINT ''Database is migrated FROM server i.e. Source SQL Server Name = '' + @SourceSQLServerName
	PRINT ''Target server name = '' + @@ServerName
	PRINT ''Attempting to correct the Orphan User Issue ON Database '' + DB_NAME()
	PRINT ''''
	
	DECLARE @UID SMALLINT,
			@SID VarChar(MAX),
			@IsSQLUser INT,
			@UserName VarChar(MAX),
			@iTotalUsers INT,
			@iCurrentUser INT,
			@IsLoginAlreadyEXISTSOnTargetServer BIT 
	DECLARE @PWD_varbinary  varbinary (256)
	DECLARE @PWD_string  VarChar (514)
	DECLARE  @tblAllUsers TABLE (ID INT IDENTITY (1,1), Name VarChar(MAX),UID SMALLINT, SID VarChar(MAX), IsSQLUser INT)
	DECLARE @SQLCMD VarChar(1000) = ''''	
	DECLARE @tblPWD Table (PWD nVarChar(1000))
	
	INSERT INTO @tblAllUsers 
		SELECT Name, UID, SID, IsSQLUser FROM SYS.SYSUSERS WHERE IsLogin = 1 AND HasDBAccess = 1 AND name NOT IN (''dbo'',''guest'',''INFORMATION_SCHEMA'',''sys'')

	SELECT @iCurrentUser = 1, @iTotalUsers = COUNT(*) FROM @tblAllUsers
	
	WHILE @iCurrentUser  <= @iTotalUsers
	BEGIN
		SELECT @UID = uid , @SID = sid, @IsSQLUser = IsSQLUser, @UserName = Name  
		FROM @tblAllUsers
		WHERE ID = @iCurrentUser
	
		IF EXISTS(SELECT 1 FROM sys.syslogins WHERE sid = CAST(@sid AS VARBINARY))
			PRINT ''INFO: '' + CAST(@iCurrentUser AS VarChar(5)) + '') User: '' + @UserName + '' is already present (i.e. Not Orphan)...No actiON done'' 
		ELSE
		BEGIN
		    IF EXISTS(SELECT 1 FROM sys.syslogins WHERE name = @UserName)
				SELECT @IsLoginAlreadyEXISTSOnTargetServer = 1
			ELSE
				SELECT @IsLoginAlreadyEXISTSOnTargetServer = 0
		    
		    
		
			IF @IsSQLUser = 1 -- IF SQL USER AND ORPHAN
			BEGIN
				IF @IsLoginAlreadyEXISTSOnTargetServer = 1
					BEGIN
					    IF @Force_SQLLoginMapping_To_ExistingUser = 1	
							BEGIN				
								BEGIN TRY
									EXEC sp_change_users_login  @ActiON = ''Update_One'',@UserNamePattern = @UserName, @LoginName= @UserName
									PRINT ''IMP: '' + CAST(@iCurrentUser AS VarChar(5)) + '') User: '' + @UserName + '' was SQL Orphan User.  The script has done the necessary correctiON successfully.''				
								END TRY
								BEGIN CATCH
								   PRINT ''ERR: '' + CAST(@iCurrentUser AS VarChar(5)) + '') User: '' + @UserName + '' is SQL Orphan User. Failed to do the correction; ErrOR Message: '' + ERROR_MESSAGE()
								END CATCH
							END
						ELSE
							PRINT ''Q?: '' + CAST(@iCurrentUser AS VarChar(5)) + '') User: '' + @UserName + '' is SQL Orphan User. But the login with similar name already EXISTS.  IF you want to USE Force mapping to the existing user then please rerun this script with flag i.e. @Force_SQLLoginMapping_To_ExistingUser = True''
					END
				ELSE  -- IF SQL user which does not EXISTS ON target server
					BEGIN
						BEGIN TRY
							-- This script below is to bring the password of the SQL user FROM source server
							SELECT @SQLCMD = ''SELECT    a.PWD
										FROM OPENROWSET(''''SQLNCLI'''', ''''Server='' + @SourceSQLServerName +  '';Trusted_Connection=yes;'''',
							''''SELECT CAST( LOGINPROPERTY( '''''''''' + @UserName + '''''''''', ''''''''PasswordHash'''''''' ) AS varbinary (256) ) As PWD'''') as a''

							Delete  FROM @tblPWD
							Insert INTO @tblPWD Exec( @sqlcmd )
							SELECT TOP 1  @PWD_varbinary = Cast(PWD as varbinary(256))FROM @tblPWD							 
								 
							EXEC sp_hexadecimal @PWD_varbinary, @PWD_string OUT
						
							EXEC (''CREATE LOGIN ['' + @UserName  + ''] WITH PASSWORD = '' + @PWD_string  + '' HASHED, CHECK_POLICY = OFF'')
							EXEC sp_change_users_login  @ActiON = ''Update_One'',@UserNamePattern = @UserName, @LoginName= @UserName

							PRINT ''IMP: '' + CAST(@iCurrentUser AS VarChar(5)) + '') User: '' + @UserName + '' was NON-Existent SQL Orphan User.  The script has done the necessary correctiON successfully.''				
						END TRY
						BEGIN CATCH
						   PRINT ''ERR: '' + CAST(@iCurrentUser AS VarChar(5)) + '') User: '' + @UserName + '' is NON-Existent SQL Orphan User. Failed to do the correction; ErrOR Message: '' + ERROR_MESSAGE()
						END CATCH						
					END				
			END
			  ELSE   -- I.E. IF NT USER AND ORPHAN
			BEGIN
				IF @IsLoginAlreadyEXISTSOnTargetServer = 1
					BEGIN					
						BEGIN TRY
							EXEC sp_change_users_login  @ActiON = ''Update_One'',@UserNamePattern = @UserName, @LoginName= @UserName
							PRINT ''IMP: '' + CAST(@iCurrentUser AS VarChar(5)) + '') User: '' + @UserName + '' was NT Orphan User/Group.  The script has done the necessary correctiON successfully.''				
						END TRY
						BEGIN CATCH
						   PRINT ''ERR: '' + CAST(@iCurrentUser AS VarChar(5)) + '') User: '' + @UserName + '' is NT Orphan User/Group. Failed to do the correction; ErrOR Message: '' + ERROR_MESSAGE()
						END CATCH
					END
				ELSE
					BEGIN
						BEGIN TRY
						    EXEC (''CREATE LOGIN ['' + @UserName + ''] FROM WINDOWS'')
							--EXEC sp_change_users_login  @ActiON = ''Update_One'',@UserNamePattern = @UserName, @LoginName= @UserName
							PRINT ''IMP: '' + CAST(@iCurrentUser AS VarChar(5)) + '') User: '' + @UserName + '' was NON-Existent NT Orphan User/Group.  The script has done the necessary correctiON successfully.''				
						END TRY
						BEGIN CATCH
						   PRINT ''ERR: '' + CAST(@iCurrentUser AS VarChar(5)) + '') User: '' + @UserName + '' is NON-Existent NT Orphan User/Group. Failed to do the correction; ErrOR Message: '' + ERROR_MESSAGE()
						END CATCH						
					END				
			END -- END of else		
	   END  -- END of ELSE part of IF conditiON 

	   SET @iCurrentUser += 1
	END  -- END of while 
END
' 
END
GO
/****** Object:  StoredProcedure [SQLMantainence].[proc_DeleteOldFullBackups]    Script Date: 11/23/2012 19:32:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[proc_DeleteOldFullBackups]') AND TYPE IN (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'
-- =============================================
--  Exec [SQLMantainence].[proc_DeleteOldFullBackups] ''Test'',''C:\Temp\Backup\Full'',''C:\Temp\Backup\Diff'',''C:\Temp\Backup\TLOG'',10
-- =============================================
CREATE PROCEDURE [SQLMantainence].[proc_DeleteOldFullBackups]
(
@DatabaseName VarChar(1000),
@FullBackupFolder  VarChar(1000),
@DIffBackupFolder  VarChar(1000),
@TLOGBackupFolder  VarChar(1000),
@RetentionPeriodInDays INT,
@FullBackupScheduleInDays INT
)
-- With Encryption
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @CmdStrSourceInfo VarChar(1000)
	DECLARE @CmdStrSource VarChar (2000)
	DECLARE @FullBackupFolderType VarChar (2000)
	DECLARE @i BIGINT
	DECLARE @j BIGINT  
	DECLARE @filedate VarChar(5000)
	DECLARE @filename VarChar(5000)
	DECLARE @filetype VarChar(100)
	DECLARE @fileRetentionDate DATETIME
	DECLARE @inpath VarChar(1000)
	DECLARE @filestatus VarChar(2000)
	DECLARE @total BIGINT

	--******************************************************************************************************************************
	-- TOTAL 3 SECTION I.E. 
	--SECTION 1 = DELETE FULL BACKUP AFTER GIVEN RETENTION PERIOD
	--SECTION 2 = DELETE DIFF BACKUP AFTER GIVEN RETENTION PERIOD AND also all diff backup associated with the deleted full backup
	--SECTION 3 = DELETE TOLOG BACKUP AFTER GIVEN RETENTION PERIOD  AND also all tlog backup associated with the deleted full backup
	--******************************************************************************************************************************

	--******************************************************************************************************************************
	-- START OF SECTION 1 I.E. DELETE OF FULL BACKUP
	--******************************************************************************************************************************
	CREATE TABLE #DirFileSourceInfo(DirFileInfo VarChar(2000))
	CREATE TABLE #DirFileSource(DirFile VarChar(2000))
	CREATE TABLE #FilesSource( [RowNo] BIGINT,[FileName] VarChar(2000),[FileType] VarChar(2000),[FileModIfiedDate] VarChar(50), [FileSize] BIGINT )

	BEGIN TRY
		SELECT @CmdStrSourceInfo = ''dir /O-S /-C /A-D "'' + @FullBackupFolder + ''"''        
		SELECT @CmdStrSource = ''dir /B "'' + @FullBackupFolder + ''"''  

		INSERT INTO #DirFileSourceInfo (DirFileInfo) EXEC xp_cmdshell @CmdStrSourceInfo  
	
		UPDATE [#DirFileSourceInfo] SET [DirFileInfo] = @FullBackupFolderType WHERE [DirFileInfo] IS NULL    

		INSERT INTO [#DirFileSource]([DirFile])  EXEC xp_cmdshell @CmdStrSource  
	
		INSERT INTO #FilesSource([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )      
			SELECT ROW_NUMBER() OVER (ORDER BY df.[DirFile]) AS RowNo , 
			REVERSE(RIGHT(REVERSE(df.[DirFile]),LEN(df.[DirFile])-CHARINDEX(''.'',REVERSE(df.[DirFile])))),
			REVERSE(SUBSTRING(REVERSE( df.[DirFile]), 1, CHARINDEX(''.'', REVERSE( df.[DirFile]))-1)),
			CONVERT(VarChar(50), LEFT([DirFileInfo], 17)),
			(RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 2, (CHARINDEX('' '', REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 2) - LEN(df.[DirFile]) + 2))))))    
			FROM #DirFileSourceInfo dfi WITH(NOLOCK) INNER JOIN [#DirFileSource] df  WITH(NOLOCK) ON LEFT(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile])) = REVERSE(df.DirFile)
			WHERE  SUBSTRING(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 1, 1) = '' ''  
			AND LEFT((SUBSTRING(df.[DirFile],1,CHARINDEX(''@'',df.[DirFile])-1)),(LEN(@DatabaseName) + 1))=(@DatabaseName)

		SET @total=0
		SELECT @i=  COUNT(*) FROM #FilesSource
		SET @j=1

		WHILE(@j <= @i)
		BEGIN 
		   SELECT @filedate=CONVERT(DATETIME,[FileModIfiedDate],101) FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @filename =[FileName] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @filetype= [FileType] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @fileRetentionDate = DATEADD (dd,@RetentionPeriodInDays,CONVERT(DATETIME,@filedate,101)) 

		   IF(CONVERT(DATE,@fileRetentionDate,101) <= CONVERT(DATE,GETDATE(),101))
			BEGIN
			 BEGIN TRY
			   SET @inpath = ''del  /Q "''+@FullBackupFolder+''\''+@filename+''.''+@filetype+''"''
			   EXEC  master..xp_cmdshell @inpath
			   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),''DELETION-FULL-BACKUP'',''Successfully deleted  FULLBACKUP file fOR the database: ''+@filename,''I'');
			 END TRY
			 BEGIN CATCH
			   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),''DELETION-FULL-BACKUP'',''Could not delete FULLBACKUP file fOR the database: ''+@filename,''C'');
			 END CATCH
			END   
		   SET @j=@j+1;
		END

		-- END Of SectiON 1

		DECLARE @NewRetentionPeriodInDays INT
		SET @NewRetentionPeriodInDays = @RetentionPeriodInDays - @FullBackupScheduleInDays + 1
		IF @NewRetentionPeriodInDays < 0 
		BEGIN
		  SET @NewRetentionPeriodInDays = @RetentionPeriodInDays
		END

		SET @RetentionPeriodInDays = @NewRetentionPeriodInDays

		--******************************************************************************************************************************
		-- START OF SECTION 2 I.E. DELETE OF DIFF BACKUP
		--******************************************************************************************************************************
		TRUNCATE TABLE #DirFileSource
		TRUNCATE TABLE #DirFileSourceInfo
		TRUNCATE TABLE #FilesSource

		SELECT @CmdStrSourceInfo = ''dir /O-S /-C /A-D "'' + @DIffBackupFolder + ''"''        
		SELECT @CmdStrSource = ''dir /B "'' + @DIffBackupFolder + ''"''  

		INSERT INTO #DirFileSourceInfo (DirFileInfo) EXEC xp_cmdshell @CmdStrSourceInfo  

		UPDATE [#DirFileSourceInfo] SET [DirFileInfo] = @FullBackupFolderType WHERE [DirFileInfo] IS NULL    

		INSERT INTO [#DirFileSource]([DirFile])  EXEC xp_cmdshell @CmdStrSource  

		INSERT INTO #FilesSource([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )      
			SELECT ROW_NUMBER() OVER (ORDER BY df.[DirFile]) AS RowNo , 
			REVERSE(RIGHT(REVERSE(df.[DirFile]),LEN(df.[DirFile])-CHARINDEX(''.'',REVERSE(df.[DirFile])))),
			REVERSE(SUBSTRING(REVERSE( df.[DirFile]), 1, CHARINDEX(''.'', REVERSE( df.[DirFile]))-1)),
			CONVERT(VarChar(50), LEFT([DirFileInfo], 17)),
			(RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 2, (CHARINDEX('' '', REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 2) - LEN(df.[DirFile]) + 2))))))    
			FROM #DirFileSourceInfo dfi  WITH(NOLOCK) INNER JOIN [#DirFileSource] df  WITH(NOLOCK) ON LEFT(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile])) = REVERSE(df.DirFile)
			WHERE  SUBSTRING(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 1, 1) = '' ''  
			AND LEFT((SUBSTRING(df.[DirFile],1,CHARINDEX(''@'',df.[DirFile])-1)),(LEN(@DatabaseName) + 1))=(@DatabaseName)


		SET @total=0
		SELECT @i=  COUNT(*) FROM #FilesSource WITH(NOLOCK) 
		SET @j=1


		WHILE(@j <= @i)
		BEGIN 
		   SELECT @filedate=CONVERT(DATETIME,[FileModIfiedDate],101) FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @filename =[FileName] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @filetype= [FileType] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @fileRetentionDate = DATEADD (dd,@RetentionPeriodInDays,CONVERT(DATETIME,@filedate,101)) 
		   
		   IF(CONVERT(DATE,@fileRetentionDate,101) <= CONVERT(DATE,GETDATE(),101))
			BEGIN
			 BEGIN TRY
			   SET @inpath = ''del  /Q "''+ @DIffBackupFolder +''\''+@filename+''.''+@filetype+''"''
			   EXEC master..xp_cmdshell @inpath

			   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),''DELETION-DIFFERENTIAL-BACKUP'',''Successfully deleted  DIFFERENTIAL Backup file fOR the database: ''+@filename,''I'');
			 END TRY
			 BEGIN CATCH
			   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),''DELETION-DIFFERENTIAL-BACKUP'',''Could not delete  DIFFERENTIAL Backup file fOR the database: ''+@filename,''C'');
			 END CATCH
			END
		   
		   SET @j=@j+1;
		END
		
		-- END Of SectiON 2

		--******************************************************************************************************************************
		-- START OF SECTION 3 I.E. DELETE OF TLOG BACKUP
		--******************************************************************************************************************************
		TRUNCATE TABLE #DirFileSource
		TRUNCATE TABLE #DirFileSourceInfo
		TRUNCATE TABLE #FilesSource

		SELECT @CmdStrSourceInfo = ''dir /O-S /-C /A-D "'' + @TLOGBackupFolder + ''"''        
		SELECT @CmdStrSource = ''dir /B "'' + @TLOGBackupFolder + ''"''  

		INSERT INTO #DirFileSourceInfo (DirFileInfo) EXEC xp_cmdshell @CmdStrSourceInfo  

		UPDATE [#DirFileSourceInfo] SET [DirFileInfo] = @FullBackupFolderType WHERE [DirFileInfo] IS NULL    

		INSERT INTO [#DirFileSource]([DirFile])  EXEC xp_cmdshell @CmdStrSource  

		INSERT INTO #FilesSource([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )      
			SELECT ROW_NUMBER() OVER (ORDER BY df.[DirFile]) AS RowNo ,
			REVERSE(RIGHT(REVERSE(df.[DirFile]),LEN(df.[DirFile])-CHARINDEX(''.'',REVERSE(df.[DirFile])))),
			REVERSE(SUBSTRING(REVERSE( df.[DirFile]), 1, CHARINDEX(''.'', REVERSE( df.[DirFile]))-1)),
			CONVERT(VarChar(50),LEFT([DirFileInfo], 17)),
			(RTRIM(LTRIM(REVERSE(SUBSTRING(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 2, (CHARINDEX('' '', REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 2) - LEN(df.[DirFile]) + 2))))))    
			FROM #DirFileSourceInfo dfi  WITH(NOLOCK) INNER JOIN [#DirFileSource] df  WITH(NOLOCK) ON LEFT(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile])) = REVERSE(df.DirFile)
			WHERE  SUBSTRING(REVERSE(dfi.[DirFileInfo]), LEN(df.[DirFile]) + 1, 1) = '' '' 
			AND LEFT((SUBSTRING(df.[DirFile],1,CHARINDEX(''@'',df.[DirFile])-1)),(LEN(@DatabaseName) + 1))=(@DatabaseName)


		SET @total=0
		SELECT @i=  COUNT(*) FROM #FilesSource WITH(NOLOCK) 
		SET @j=1

		WHILE(@j <= @i)
		BEGIN 
		   SELECT @filedate=CONVERT(DATETIME,[FileModIfiedDate],101) FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @filename =[FileName] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @filetype= [FileType] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j
		   SELECT @fileRetentionDate = DATEADD (dd,@RetentionPeriodInDays,CONVERT(DATETIME,@filedate,101)) 
		   
		   IF(CONVERT(DATE,@fileRetentionDate,101) <= CONVERT(DATE,GETDATE(),101))
			BEGIN
			BEGIN TRY
			   SET @inpath = ''del  /Q "''+ @TLOGBackupFolder +''\''+@filename+''.''+@filetype+''"''
			   EXEC  master..xp_cmdshell @inpath
			   INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),''DELETION-TLOG-BACKUP'',''Successfully deleted  TLOG file fOR the database: ''+@filename,''I'');
			END TRY
			BEGIN CATCH
				  INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),''DELETION-TLOG-BACKUP'',''Could not  delete  TLOG file fOR the database: ''+@filename,''C'');
			END CATCH
			END
		   
		   SET @j=@j+1;
		END

		-- END Of SectiON 3


		DROP TABLE  #DirFileSourceInfo
		DROP TABLE  #DirFileSource
		DROP TABLE #FilesSource 

	END TRY

	BEGIN CATCH
		EXEC [SQLMantainence].[Log_Error] ''proc_DeleteOldFullBackups'',''DELETE-FULL-BACKUP''
	END CATCH  
END

' 
END
GO
/****** Object:  StoredProcedure [SQLMantainence].[RunSQLMaintenanceDeployment]    Script Date: 11/23/2012 19:32:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[RunSQLMaintenanceDeployment]') AND TYPE IN (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'-- Exec [SQLMantainence].[RunSQLMaintenanceDeployment] 1 -- 1/0 as required
CREATE PROCEDURE [SQLMantainence].[RunSQLMaintenanceDeployment]
@DebugMode BIT = 0
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @TableServersToDeploy TABLE (SERVERNAME VarChar(100), ID INT IDENTITY(1,1))
	DECLARE @iCurrentRow INT, @iTotalRow INT
	DECLARE @ServerName VarChar(1000)
	DECLARE @CommandString VarChar(8000)
	DECLARE @Result INT
	
	BEGIN TRY	
		INSERT INTO @TableServersToDeploy (SERVERNAME)
		SELECT SERVERNAME FROM SQLMantainence.ServerDetails WITH(NOLOCK) 
		WHERE IsDeploymentRequired = 1 AND IsDeploymentCompleted = 0
		
		SELECT @iCurrentRow = 1, @iTotalRow = Count(*) FROM @TableServersToDeploy 
		WHILE @iCurrentRow <= @iTotalRow
		BEGIN
			SELECT @ServerName = SERVERNAME FROM @TableServersToDeploy WHERE ID = @iCurrentRow
			PRINT Cast(@iCurrentRow AS VarChar(100)) + ''/'' + Cast(@iTotalRow AS VarChar(100)) + '' - STARTED DEPLOYMENT ON SERVER: '' + @ServerName 
			
			Exec SQL_ADMIN.SQLMantainence.CreateLinkedServer @ServerName 
			
			SET @CommandString = ''sqlcmd -S '' + @ServerName + ''  -U sa -P n0S0up4U2day  -i "D:\SQL_ADMIN\SQLMaintenanceDeployment.sql"''            
			IF @DebugMode = 1
			Begin
				SELECT @CommandString
				EXEC @result = master.dbo.xp_cmdshell @CommandString --, NO_OUTPUT
				--PRINT @result
			End
			Else
			Begin
				EXEC @result = master.dbo.xp_cmdshell @CommandString , NO_OUTPUT
			End	
			IF EXISTS(SELECT 1 FROM sys.servers WHERE NAME = ''ServerForDeployment'')
				Exec master.dbo.sp_dropserver  ''ServerForDeployment'', ''droplogins''
					
			IF (@result = 1)  -- IF Error
			BEGIN
				PRINT ''Deployment Failed while executing server '' + @ServerName 
				PRINT Error_Message()
			END 
			Else
			BEGIN
				PRINT ''Sucessfully Deployed Maintenance Script ON server ''  + @ServerName  
				UPDATE SQLMantainence.ServerDetails SET IsDeploymentCompleted = 1 WHERE SERVERNAME = @ServerName				   
			END
			
			SELECT @iCurrentRow += 1
		END
	END TRY
	
	BEGIN CATCH
		IF EXISTS(SELECT 1 FROM sys.servers WHERE NAME = ''ServerForDeployment'')
			Exec master.dbo.sp_dropserver  ''ServerForDeployment'', ''droplogins''
		
		PRINT ''Deployment Failed while executing server '' + @ServerName 
		PRINT Error_Message()
	END CATCH	
	
END' 
END
GO
/****** Object:  StoredProcedure [SQLMantainence].[sp_ShrinkDatabase]    Script Date: 11/23/2012 19:32:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[SQLMantainence].[sp_ShrinkDatabase]') AND TYPE IN (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'



CREATE PROCEDURE [SQLMantainence].[sp_ShrinkDatabase] 
  @DBName VarChar(1000)
 -- With Encryption
AS
BEGIN
	SET NOCOUNT ON;

 DECLARE @BackupPath VarChar(1000)
 DECLARE @BackupFilename VarChar (1000)
 DECLARE @Environment VarChar(1000)
 DECLARE @FLAG BIT=0
 DECLARE @RECOVERY_MODEL VarChar(20)
 
 
   
 
 SELECT @BackupPath = value FROM SQLMantainence.DBMantainenceConfiguratiON WHERE configurationtype=''T-log_BackupFolder''
 SELECT @Environment= value FROM SQLMantainence.DBMantainenceConfiguratiON WHERE configurationtype=''Environment''  
 
 
 BEGIN TRY
 
		Exec (''USE ['' + @dbname + '']'')
		
		-- Backup Log is not required fOR System database AND SIMPLE recovery model database 
		-- Also it checks the environment i.e. IF ProductiON then takes TLog backup AND shrinks. ELSE changes the revoery model to simple AND shrinks the database.
		IF @dbName != ''master'' AND @dbName != ''msdb'' AND @dbName != ''model'' AND @dbName != ''tempdb''
		BEGIN   
				IF ''SIMPLE'' != (SELECT recovery_model_desc FROM sys.databases WHERE name = @dbname)
				Begin
					IF  left(@Environment,1)=''p''
					BEGIN
						SET @BackupFilename=@BackupPath + ''\'' + @DBName + ''@'' +  cast(Day(getdate()) as VarChar(100)) + ''_'' + cast(Month(getdate()) as VarChar(10)) +  + ''_'' + cast(year(getdate()) as VarChar(10))  + ''_'' + cast(datepart(hh,getdate()) as VarChar(10))  + ''_'' + cast(datepart(mi,getdate()) as VarChar(10))  + ''_'' + cast(datepart(ss,getdate()) as VarChar(10)) + ''.trn''
						Exec (''Backup  log ['' + @dbname + ''] To disk = '''''' + @backupfilename + '''''''')
					END
					ELSE
					BEGIN
						SELECT @RECOVERY_MODEL =recovery_model_desc FROM sys.databases WHERE name = @dbname
						Exec (  ''alter database ['' + @dbname +  ''] SET recovery SIMPLE'')
						SET @FLAG=1
					END
                End
			    Exec (''USE ['' + @dbname + '']; DBCC ShrinkFile(2) '')

				-- Shrinking is done 2 times. becaUSE sometimes it is found that shrinking does not work first time.
				IF ''SIMPLE'' != (SELECT recovery_model_desc FROM sys.databases WHERE name = @dbname)
				Begin
					IF  left (@Environment,1)=''p''
					BEGIN
						SET @BackupFilename=@BackupPath + ''\'' + @DBName + ''@'' +  cast(Day(getdate()) as VarChar(100)) + ''_'' + cast(Month(getdate()) as VarChar(10)) +  + ''_'' + cast(year(getdate()) as VarChar(10))  + ''_'' + cast(datepart(hh,getdate()) as VarChar(10))  + ''_'' + cast(datepart(mi,getdate()) as VarChar(10))  + ''_'' + cast(datepart(ss,getdate()) as VarChar(10)) + ''.trn''
						Exec (''Backup  log ['' + @dbname + ''] To disk = '''''' + @backupfilename + '''''''')
					END
	
                End		
		END
		
		Exec (''USE ['' + @dbname + '']; DBCC ShrinkFile(2) '')

		IF @FLAG=1   -- IF revoery model is changes to simple fOR shrinking purpose then the below script will change the revoery model back to what it was earlier
			Exec (  ''alter database ['' + @dbname +  ''] SET recovery '' + @RECOVERY_MODEL )

END TRY

 BEGIN CATCH   
   EXEC [SQLMantainence].[Log_Error] ''sp_ShrinkDatabase'',''SHRINK-DATABASE''
 END CATCH 


END

' 
END
GO


USE [SQL_Admin]
GO

--DECLARE @IsDebug Bit = 1
CREATE PROCEDURE  [SQLMantainence].[sp_Rebuild_OR_ReOrganize_ALLIndexInAllDatabases] 
 @IsDebug Bit = 1,
 @DBName varchar(100) = NULL
-- With Encryption
AS

BEGIN

-----------------------------------------------------
-- debug line below  ...remove later
--declare @IsDebug Bit = 1, @DBName varchar(100) = 'epos2000'
-----------------------------------------------------

SET NOCOUNT ON;

    /*

              THIS STORED PROCEDURE WILL DO EITHER REBUILD ONLINE OR REORGANIZE ALL INDEXES IN ALL DATABASES (WITH SOME EXCEPTIONS), DEPENDING

              ON INDEX TYPE AND FRAGMENTATION LEVEL

       */     

DECLARE @tblDatabasesToReOrganize TABLE (ID INT, DBName VARCHAR(1000))

DECLARE @tblTablesToReOrganizeORReBuild TABLE (rowDetails VARCHAR(1000))

DECLARE @iRow INT = 0, @TotalRows INT = 0

DECLARE @CurrentDBName VARCHAR(100) = ''

DECLARE @SQL VARCHAR(MAX) = ''

--DECLARE @IsDebug Bit = 1 

BEGIN TRY    

       

-- TO GET LIST OF DATABASE  NAME FOR WHICH REORGANIZE/ONLINE REBUILD INDEX NEED TO BE EXECUTED

INSERT INTO @tblDatabasesToReOrganize

       SELECT RowNum = ROW_NUMBER() OVER(ORDER BY Name), Name 

       FROM sys.databases WITH(NOLOCK) 

       WHERE  Is_Read_Only = 0 AND State_Desc = 'ONLINE' AND source_database_id IS NULL AND Is_In_StandBy = 0 AND Database_ID > 4 AND Name NOT LIKE '%_TOBEDELETED%'
       AND NAME NOT IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM [SQLMANTAINENCE].[DBMANTAINENCECONFIGURATION]  WITH(NOLOCK) WHERE CONFIGURATIONTYPE IN ('EXCLUDEDATABASE','DatabaseName_ForSecondBackupJob'))
       AND (@DBName IS NULL OR name  = @DBName)


SELECT @iRow = 1, @TotalRows = Count(*) FROM @tblDatabasesToReOrganize 

WHILE @iRow <= @TotalRows 
BEGIN
              SELECT @CurrentDBName = DBName FROM @tblDatabasesToReOrganize WHERE ID = @iRow

              -- This part will pick all the XML, BLOB fields information FROM all tables in the current database
              -- and insert into the temporary table created in SQL_ADmin; which will then be used for checking whether
              -- online indexing is possible for all indexes

              SELECT @SQL = 'Truncate Table SQL_Admin.SQLMantainence.tmpColumnsDetailsForDatabaseOnlineRebuild;
                                         Insert into SQL_Admin.SQLMantainence.tmpColumnsDetailsForDatabaseOnlineRebuild 
                                         SELECT  c.object_id , user_type_id, max_length,  i.name, i.type
                                         FROM [' + @CurrentDBName + '].[sys].[columns] c
                                         INNER JOIN [' + @CurrentDBName + '].[sys].[indexes] i ON c.object_id=i.object_id 
                                         WHERE I.type = 1 AND (TYPE_NAME(c.user_type_id) IN (''xml'',''text'', ''ntext'',''image'',''VarChar'',''nVarChar'',''varbinary'') or max_length = -1)'

              Execute (@SQL)

              SELECT @SQL =   
                     'Use [' + @CurrentDBName +  '];' +              
                     'SELECT DISTINCT 
                     CASE 
					 WHEN (Select count(*) from sys.partitions Where object_id = idx.object_id and index_id = idx.index_id and partition_number > 1) <> 0 
                     THEN
                           '';Alter Index ['' + IDX.Name +  ''] On ['' + SCH.NAME + ''].['' + OBJ.NAME + ''] REBUILD PARTITION = '' + cast(Iprt.partition_number  as varchar(100))
                     WHEN SQL_Admin.[SQLMantainence].[udf_IsOnlineIndexingPossible](ps.avg_fragmentation_in_percent,IDX.Name,IDX.type,IC.Key_Ordinal) = 1 
                     THEN 
                           '';Alter Index ['' + IDX.Name +  ''] On ['' + SCH.NAME + ''].['' + OBJ.NAME + ''] REBUILD WITH (FILLFACTOR = 95,PAD_INDEX=OFF,STATISTICS_NORECOMPUTE=OFF,ALLOW_ROW_LOCKS=ON,ALLOW_PAGE_LOCKS=ON,ONLINE=ON,SORT_IN_TEMPDB = ON,MAXDOP=2) ''
                      ELSE
                            '';Alter Index ['' + IDX.Name +  ''] On ['' + SCH.NAME + ''].['' + OBJ.NAME + ''] REBUILD WITH (FILLFACTOR = 95,PAD_INDEX=OFF,STATISTICS_NORECOMPUTE=OFF,ALLOW_ROW_LOCKS=ON,ALLOW_PAGE_LOCKS=ON,SORT_IN_TEMPDB = ON,MAXDOP=2)''                         
                     END

                     FROM [' + @CurrentDBName +  '].sys.indexes IDX WITH(NOLOCK)          
						 INNER JOIN [' + @CurrentDBName +  '].sys.index_columns as ic ON idx.object_id = ic.object_id AND idx.index_id = ic.index_id     
						 INNER JOIN [' + @CurrentDBName +  '].SYS.OBJECTS OBJ WITH(NOLOCK) ON IDX.OBJECT_ID = OBJ.OBJECT_ID 
						 INNER JOIN [' + @CurrentDBName +  '].SYS.SCHEMAS SCH ON OBJ.SCHEMA_ID = SCH.SCHEMA_ID
						 INNER JOIN  [' + @CurrentDBName +  '].sys.dm_db_index_physical_stats (DB_ID(''' + @CurrentDBName +  '''),NULL,NULL,NULL,NULL) ps on (IDX.OBJECT_ID=ps.OBJECT_ID and idx.index_id=ps.index_id  and ps.alloc_unit_type_desc = ''IN_ROW_DATA'')
						 INNER JOIN sys.partitions IPRT ON idx.object_id = iprt.object_id and idx.index_id = iprt.index_id  and ps.partition_number=IPRT.partition_number
                     WHERE ALLOW_PAGE_LOCKS = 1 AND OBJ.Type IN (''U'',''V'')  AND IDX.TYPE <> 0 AND IDX.Name IS NOT NULL AND ps.avg_fragmentation_in_percent > 30 '
					 + ' union all ' + 
					  
                    'SELECT DISTINCT 
                            '';Alter Index ['' + IDX.Name +  ''] On ['' + SCH.NAME + ''].['' + OBJ.NAME + ''] REORGANIZE ''                         

                     FROM [' + @CurrentDBName +  '].sys.indexes IDX WITH(NOLOCK)          
						 INNER JOIN [' + @CurrentDBName +  '].sys.index_columns as ic ON idx.object_id = ic.object_id AND idx.index_id = ic.index_id     
						 INNER JOIN [' + @CurrentDBName +  '].SYS.OBJECTS OBJ WITH(NOLOCK) ON IDX.OBJECT_ID = OBJ.OBJECT_ID 
						 INNER JOIN [' + @CurrentDBName +  '].SYS.SCHEMAS SCH ON OBJ.SCHEMA_ID = SCH.SCHEMA_ID
						 INNER JOIN  [' + @CurrentDBName +  '].sys.dm_db_index_physical_stats (DB_ID(''' + @CurrentDBName +  '''),NULL,NULL,NULL,NULL) ps on (IDX.OBJECT_ID=ps.OBJECT_ID and idx.index_id=ps.index_id  and ps.alloc_unit_type_desc = ''IN_ROW_DATA'')
						 INNER JOIN sys.partitions IPRT ON idx.object_id = iprt.object_id and idx.index_id = iprt.index_id  and ps.partition_number=IPRT.partition_number
                     WHERE ALLOW_PAGE_LOCKS = 1 AND OBJ.Type IN (''U'',''V'')  AND IDX.TYPE <> 0 AND IDX.Name IS NOT NULL AND ps.avg_fragmentation_in_percent <= 30 '
					 

--print @sql

              DELETE FROM @tblTablesToReOrganizeORReBuild -- TRUNCATING PREVIOUS DATABASE TABLES
             INSERT INTO @tblTablesToReOrganizeORReBuild EXEC(@SQL)

			  -------------------------------------------------------------------------
-- DEBUG LINE BELWO.  PLEASE REMOVE LATER
--select * from @tblTablesToReOrganizeORReBuild
-----------------------------------------------------------------------------

              SELECT @SQL = 'Use [' + @CurrentDBName + '];'
              SELECT @SQL += rowDetails FROM @tblTablesToReOrganizeORReBuild

              IF @IsDebug = 1 Print QuoteName(Cast(@iRow as varchar(100)) + '/' +  Cast(@TotalRows as varchar(100))) + ' - Started Rebuilding/ReOrganizing Database ' + QuoteName(@CurrentDBName)
              IF @IsDebug = 1 Print @SQL 

           
              EXECUTE( @SQL )   -- THIS WILL REORGANIZE ALL REQUIRED TABLE INDEXS FOR CURRENT DATABASE 

              IF @IsDebug = 1 Print ' '



              SELECT @iRow += 1  -- i.e. to move to next row in the database list

       END -- END OF WHILE LOOP

END TRY  

       

BEGIN CATCH

       IF ERROR_NUMBER() > 0      

       BEGIN

              IF @IsDebug = 1 PRINT ERROR_MESSAGE()



              INSERT INTO SQL_Admin.SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'ReBuild_ReOrganize-INDEX','ReBuild / ReOrganize Index failed for the database: '+ @CurrentDBName,'C');

              EXEC SQL_Admin.[SQLMantainence].[Log_Error] 'sp_Rebuild_OR_ReOrganize_ALLIndexInAllDatabases','ReBuild_ReOrganize-INDEX'                    

       END

END CATCH

     

END


GO





--******************************************************************
-- Step 11  ... CREATING ALL SQL JOBS FOR MAINTENANCE AND MONITORING

--******************************************************************* 

USE [msdb]
GO

------
DECLARE @Enabled BIT
DECLARE @JobName VarChar(1000) 

SET @Enabled = 0 -- By Default False
SET @JobName = 'SQLMantainence_DeleteOldTLOGBackups'
IF EXISTS(SELECT Name,Enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)
	SET @Enabled = 1
	

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLMantainence_DeleteOldTLOGBackups')
	EXEC msdb.dbo.sp_delete_job @job_Name=N'SQLMantainence_DeleteOldTLOGBackups', @delete_unused_schedule=1


BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 9/16/2014 3:56:31 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQLMantainence_DeleteOldTLOGBackups', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'SA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [step 1]    Script Date: 9/16/2014 3:56:32 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_name=N'SQLMantainence_DeleteOldTLOGBackups', @step_name=N'step 1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @Tlog_BackupFolder VARCHAR(1000)
DECLARE @RETENTIONPERIODFORTLOGBACKUPINDAYS INT
DECLARE @SQLCMD varchar(1000)


SELECT @Tlog_BackupFolder =VALUE FROM [SQL_Admin].[SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType=''T-log_BackupFolder''
SELECT @RetentionPeriodForTLOGbackupInDays	=VALUE FROM [SQL_Admin].[SqlMantainence].DBMantainenceConfiguration WITH(NOLOCK)  WHERE configurationType=''RetentionPeriodForTLOGbackupInDays''

SELECT @RETENTIONPERIODFORTLOGBACKUPINDAYS = ISNULL(@RETENTIONPERIODFORTLOGBACKUPINDAYS,2)

IF Len(IsNull(@Tlog_BackupFolder,'''')) >= 3
BEGIN

	IF (select top 1 value from SQLMantainence.DBMantainenceConfiguration (NOLOCK) where configurationType = ''BackupDrive'') = ''http''
		SELECT @SQLCMD = ''Exec [SQL_Admin].[SQLMantainence].[PROC_DELETEOLD_AzureTLogBACKUPS]  ''''?'''','''''' + @Tlog_BackupFolder + '''''','' + cast(@RETENTIONPERIODFORTLOGBACKUPINDAYS as varchar(100))
	ELSE
		SELECT @SQLCMD = ''Exec [SQL_Admin].[SQLMantainence].[proc_DeleteOldTLOGBackups]  ''''?'''','''''' + @Tlog_BackupFolder + '''''','' + cast(@RETENTIONPERIODFORTLOGBACKUPINDAYS as varchar(100))


	EXECUTE master.sys.sp_MSforeachdb @SQLCMD

END
', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'sch1', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20140523, 
		@active_end_date=99991231, 
		@active_start_time=500, 
		@active_end_time=235959, 
		@schedule_uid=N'3581cf67-e619-4714-a36c-aefb1c37c46b'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

EXEC msdb..sp_update_job @job_name = @JobName , @Enabled = 1 --@Enabled  


USE MSDB
GO
DECLARE @Enabled BIT
DECLARE @JobName VarChar(1000) 

SET @Enabled = 0 -- By Default False
SET @JobName = 'SQLMantainence_DailyMaintenanceActivity'
IF EXISTS(SELECT Name,Enabled FROM msdb.dbo.sysjobs WHERE name = 'SqlMantainence_UpdateStatisticsForAllDatabases' AND Enabled = 1)
	SET @Enabled = 1
IF EXISTS(SELECT Name,Enabled FROM msdb.dbo.sysjobs WHERE name = 'SQLMantainence_DailyMaintenanceActivity' AND Enabled = 1)
	SET @Enabled = 1
	

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SqlMantainence_UpdateStatisticsForAllDatabases')
	EXEC msdb.dbo.sp_delete_job @job_Name=N'SqlMantainence_UpdateStatisticsForAllDatabases', @delete_unused_schedule=1

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLMantainence_DailyMaintenanceActivity')
	EXEC msdb.dbo.sp_delete_job @job_Name=N'SQLMantainence_DailyMaintenanceActivity', @delete_unused_schedule=1



BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/6/2015 7:27:23 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQLMantainence_DailyMaintenanceActivity', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No descriptiON available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step1 - Daily Update Statistics]    Script Date: 4/6/2015 7:27:23 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step1 - Daily Update Statistics', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=2, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec [SqlMantainence].[UpdateStatisticsForAllDatabases] 0', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step 2 - Update Database Catalogue]    Script Date: 4/6/2015 7:27:23 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step 2 - Update Database Catalogue', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=3, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Execute [SQLMantainence].[UpdateDatabaseCatalogue]', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step 3 - Alert for databases where backup has not happend in last 24 hours]    Script Date: 4/6/2015 7:27:23 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step 3 - Alert for databases where backup has not happend in last 24 hours', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'

SET NOCOUNT ON
DECLARE @TMPBACKUPS TABLE(DATABASENAME VARCHAR(1000), LASTBACKUP DATETIME)

INSERT INTO @TMPBACKUPS 
EXEC SP_MSFOREACHDB ''
SELECT ''''?'''', MAX(A.LOGDATE) 
FROM SQL_ADMIN.SQLMANTAINENCE.DBMANTAINENCELOG A WITH(NOLOCK)
WHERE TYPE IN (''''FULL-BACKUP'''',''''DIFFERENTIAL-BACKUP'''',''''TLOG-BACKUP'''') AND LOGDETAILS LIKE ''''%DATABASE: ?'''' AND STATUS = ''''I'''' ''

Declare @BackupIssue varchar(2000) = ''''
SELECT @BackupIssue = @BackupIssue+IsNull(upper(b.DATABASENAME),'''')+ '' since ''+ Convert(varchar,IsNull(b.LASTBACKUP,a.crdate),101) + '', ''
FROM sys.SysDatabases A WITH(NOLOCK) LEFT JOIN  @TMPBACKUPS B  ON A.Name = B.DATABASENAME
Where  (b.LASTBACKUP is NULL OR b.LastBackup < Cast(getDate() as Date)) AND
     
 
 
   A.NAME NOT LIKE ''%_TOBEDELETED%''  AND  A.NAME NOT IN(''MSDB'',''MASTER'',''TEMPDB'',''Model'') AND
A.NAME NOT IN (SELECT VALUE COLLATE DATABASE_DEFAULT FROM [Sql_Admin].[SQLMANTAINENCE].[DBMANTAINENCECONFIGURATION]  WITH(NOLOCK) 
WHERE CONFIGURATIONTYPE = ''EXCLUDEDATABASE'') 

IF @BACKUPISSUE = ''''
INSERT INTO [SQL_ADMIN].[SQLMantainence].[DBMantainenceLOG_National] VALUES (GETDATE(), ''BACKUP-CHECK-STATUS'', ''ALL BACKUPS SUCCESSFUL'', ''I'',@@SERVERNAME, DEFAULT)
ELSE 
BEGIN
   SET @BACKUPISSUE = LEFT(@BACKUPISSUE,LEN(@BACKUPISSUE) - 1)
INSERT INTO [SQL_ADMIN].[SQLMantainence].[DBMantainenceLOG_National] VALUES (GETDATE(), ''BACKUP-CHECK-STATUS'', ''Backup did not happen today for {'' + @BACKUPISSUE + ''} database(s)'', ''C'',@@SERVERNAME, DEFAULT)
END


', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'[SqlMantainence].[UpdateStatisticsForAllDatabases]', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20111128, 
		@active_end_date=99991231, 
		@active_start_time=30000, 
		@active_end_time=235959, 
		@schedule_uid=N'4d5ea119-c767-4582-8c8b-d41fa5a56053'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

EXEC msdb..sp_update_job @job_name = @JobName , @Enabled = @Enabled  


-- Job - TLOG Backup  

USE [msdb]
GO

DECLARE @Enabled BIT
DECLARE @JobName VarChar(1000) 
SET @Enabled = 0 -- By Default False
SET @JobName = 'SQLMantainence_T-LogBackup'
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)
	SET @Enabled = 1
	
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLMantainence_T-LogBackup')
	EXEC msdb.dbo.sp_delete_job @job_Name=N'SQLMantainence_T-LogBackup', @delete_unused_schedule=1


BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 4/30/2015 7:14:51 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQLMantainence_T-LogBackup', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No descriptiON available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [step1]    Script Date: 4/30/2015 7:14:51 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'step1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec [SqlMantainence].[SP_MantainencePlanScriptForTLogBackup]', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'MantainencePlanScriptForTLogBackup_Hourly', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20111129, 
		@active_end_date=99991231, 
		@active_start_time=10000, 
		@active_end_time=235500, 
		@schedule_uid=N'9e170c36-2861-421d-8da2-775740c1839a'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

EXEC msdb..sp_update_job @job_name = @JobName , @Enabled = @Enabled  
GO
-- Job 3

USE [msdb]
GO

DECLARE @Enabled BIT
DECLARE @JobName VarChar(1000) 
SET @Enabled = 0 -- By Default False
SET @JobName = 'SQLMantainence_WeeklyMaintenanceActivity'
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = 'SQLMantainence_ReOrganizeALLIndexInaDatabase' AND Enabled = 1)
	SET @Enabled = 1

IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = 'SQLMantainence_WeeklyMaintenanceActivity' AND Enabled = 1)
	SET @Enabled = 1
	


IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLMantainence_ReOrganizeALLIndexInaDatabase')

	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_ReOrganizeALLIndexInaDatabase', @delete_unused_schedule=1

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLMantainence_WeeklyMaintenanceActivity')
	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_WeeklyMaintenanceActivity', @delete_unused_schedule=1

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 5/6/2015 6:12:26 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQLMantainence_WeeklyMaintenanceActivity', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No descriptiON available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step1 - ReBuild All Indexes for all databases]    Script Date: 5/6/2015 6:12:27 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step1 - ReBuild All Indexes for all databases', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=2, 
		@on_fail_action=2, 
		@on_fail_step_id=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec [SQLMantainence].[sp_Rebuild_OR_ReOrganize_ALLIndexInAllDatabases] 0', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step 2 - CheckDB For all databases]    Script Date: 5/6/2015 6:12:27 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step 2 - CheckDB For all databases', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec [SQLMantainence].[ExecuteCheckDBForAllDatabases] ', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'SQLMantainence_WeeklyMaintenanceActivity', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=4, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20120118, 
		@active_end_date=99991231, 
		@active_start_time=20000, 
		@active_end_time=235959, 
		@schedule_uid=N'e57132a2-6539-460e-9f6f-8b5be1eb448b'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:


EXEC msdb..sp_update_job @job_name = @JobName , @Enabled = @Enabled  	


-- Jobs

USE [msdb]
GO
DECLARE @Enabled BIT
DECLARE @JobName VarChar(1000) 
SET @Enabled = 0 -- By Default False

SET @JobName = 'SQLMantainence_MonitoringAlerts1_5Minutes'
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName)
BEGIN
		IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)
		SET @Enabled = 1

	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_MonitoringAlerts1_5Minutes', @delete_unused_schedule=1
END

SET @JobName = 'SQLMantainence_MonitoringAlerts2_5Minutes'
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName)
BEGIN			
	IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)			
		SET @Enabled = 1

	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_MonitoringAlerts2_5Minutes', @delete_unused_schedule=1
END
	

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 5/1/2015 10:32:35 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQLMantainence_MonitoringAlerts2_5Minutes', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No descriptiON available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step fOR SQL Mainteance Alerts]    Script Date: 5/1/2015 10:32:35 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step fOR SQL Mainteance Alerts', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Execute SQLMantainence.MonitoringAlerts2_5Minutes', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'sch for every 5 min monitoring job', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20150501, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'64b7a522-6704-4724-b568-d3d18c87dca7'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

EXEC msdb..sp_update_job @job_name = @JobName , @Enabled = @Enabled  
GO


-- next Job 
USE [msdb]
GO

DECLARE @Enabled BIT
DECLARE @JobName VarChar(1000) 
SET @Enabled = 0 -- By Default False


SET @JobName = 'SQLMantainence_MonitoringAlerts2_Hourly'	
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName)
BEGIN
	IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)
		SET @Enabled = 1

	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_MonitoringAlerts2_Hourly', @delete_unused_schedule=1
END

SET @JobName = 'SQLMantainence_MonitoringAlerts3_Hourly'
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName)		
BEGIN
	IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)				
		SET @Enabled = 1

	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_MonitoringAlerts3_Hourly', @delete_unused_schedule=1
END

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 5/1/2015 10:32:52 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQLMantainence_MonitoringAlerts3_Hourly', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No descriptiON available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step fOR SQL Mainteance Alerts]    Script Date: 5/1/2015 10:32:52 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step fOR SQL Mainteance Alerts', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Execute [SQLMantainence].[MonitoringAlerts3_Hourly]', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'sch for evey hour monitoring job', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20150501, 
		@active_end_date=99991231, 

		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'97d5fbef-cc2d-4ce1-918b-062256f47955'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

EXEC msdb..sp_update_job @job_name = @JobName , @Enabled = @Enabled  


-- next Job 
USE [msdb]
GO

DECLARE @Enabled BIT
DECLARE @JobName VarChar(1000) 
SET @Enabled = 0 -- By Default False

	
SET @JobName = 'SQLMantainence_MonitoringAlerts'
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName)
BEGIN
	IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)
		SET @Enabled = 1

	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_MonitoringAlerts', @delete_unused_schedule=1
END

SET @JobName = 'SQLMantainence_MonitoringAlerts1_15Minutes'
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName)
BEGIN
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)						
	SET @Enabled = 1

EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_MonitoringAlerts1_15Minutes', @delete_unused_schedule=1
END


BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 5/1/2015 10:32:09 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQLMantainence_MonitoringAlerts1_15Minutes', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No descriptiON available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step fOR SQL Mainteance Alerts]    Script Date: 5/1/2015 10:32:09 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step fOR SQL Mainteance Alerts', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Execute SQLMantainence.MonitoringAlerts1_15Minutes', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'sch for 15 min monitoring job', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20150501, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'073cf4a3-7a4d-45b2-a2fe-c5a286370cdd'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

EXEC msdb..sp_update_job @job_name = @JobName , @Enabled = @Enabled  

-- Job 5
USE [msdb]
GO

DECLARE @Enabled BIT
DECLARE @JobName VarChar(1000) 
SET @Enabled = 0 -- By Default False
SET @JobName = 'SQLMantainence_MaintenanceLogCleanUpActivity'
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)
	SET @Enabled = 1
	
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLMantainence_MaintenanceLogCleanUpActivity')
	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_MaintenanceLogCleanUpActivity', @delete_unused_schedule=1


BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 8/7/2013 7:59:41 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQLMantainence_MaintenanceLogCleanUpActivity', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This job removes old log entires FROM maintenance log AND audit log table.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'SA', 
		@job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [step 1]    Script Date: 8/7/2013 7:59:41 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'step 1', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec [SQLMantainence].MaintenanceLogCleanUp', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'schedule 1', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 

		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20121120, 
		@active_end_date=99991231, 
		@active_start_time=20100, 
		@active_end_time=235959, 
		@schedule_uid=N'5bbabec9-fdda-4560-9113-552678317547'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:


EXEC msdb..sp_update_job @job_name = @JobName , @Enabled = @Enabled  

-- Job  - Full Backup
USE [msdb]
GO

DECLARE @Enabled BIT
DECLARE @JobName VarChar(1000) 
SET @Enabled = 0 -- By Default False
SET @JobName = 'SQLMantainence_FullBackup'
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)
	SET @Enabled = 1

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLMantainence_FullBackup')
	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_FullBackup', @delete_unused_schedule=1

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 9/2/2015 12:44:33 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQLMantainence_FullBackup', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No descriptiON available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [step1 - Execute Full backup]    Script Date: 9/2/2015 12:44:33 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'step1 - Execute Full backup', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec [sqlMantainence].[SP_MantainencePlanScriptForFullBackup]', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step 2 - Check Backup Failure Status]    Script Date: 9/2/2015 12:44:33 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step 2 - Check Backup Failure Status', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=3, 
		@on_fail_action=4, 
		@on_fail_step_id=3, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec [SQLMantainence].[Check_DailyBackupFailures]', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step 3 - Copy Backup to S3 (Cloud folder)]    Script Date: 9/2/2015 12:44:33 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step 3 - Copy Backup to S3 (Cloud folder)', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'

Declare @sql varchar(1000)
DECLARE @result int;
DECLARE @error_tbl table(error_msg varchar(4000))
DECLARE @SecondaryBackupDestination varchar(3)
DECLARE @BackupFolder VARCHAR(1000)
DECLARE @BackupRootFolder VARCHAR(1000)


SELECT TOP 1 @SecondaryBackupDestination = VALUE 
FROM SQL_ADMIN.SQLMANTAINENCE.DBMANTAINENCECONFIGURATION WITH(NOLOCK) 
WHERE configurationType = ''SecondaryBackupDestination''

SELECT TOP 1 @BackupFolder = VALUE FROM SQL_ADMIN.SQLMANTAINENCE.DBMANTAINENCECONFIGURATION WITH(NOLOCK) WHERE configurationType = ''FULL_BackupFolder''
Select @BackupRootFolder = substring(@BackupFolder,1,(Len(@BackupFolder) - CharIndex(''\'',Reverse(@BackupFolder),1)))


IF IsNull(@SecondaryBackupDestination,'''') = ''SAN''
	SELECT @sql = ''powershell.exe -nologo -ExecutionPolicy Bypass -file "C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1" "'' + @BackupFolder + ''" "'' + @@ServerName + ''\mssql\FULL" "backups" "dyon5aEsQQ57" ''
ELSE IF IsNull(@SecondaryBackupDestination,'''') = ''AWS''
	SELECT @sql = ''powershell.exe -nologo -ExecutionPolicy Bypass -file "C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1" "mssql" "'' + @BackupRootFolder +''" "cYhabzAaXTxg9dZYzxK7Y/5w6Hm9B5j9akQk9Uku" ''
ELSE
    SELECT @sql = ''''

IF @sql <> ''''
BEGIN    	
BEGIN TRY	
	INSERT INTO @error_tbl
	EXEC @result = xp_cmdshell @sql

	IF EXISTS(SELECT 1 FROM @error_tbl WHERE error_msg like ''%exception%'' or @result = 1)
	BEGIN
		DECLARE @ErrorMessage NVARCHAR(4000);
		SELECT @ErrorMessage = COALESCE(REPLACE(REPLACE(@ErrorMessage,''+'',''''),''"'',''''),'''') + error_msg + '';'' FROM @error_tbl where error_msg is not null
		RAISERROR (@ErrorMessage, 16,1);
	END
END TRY
BEGIN CATCH
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;

    SELECT @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
	INSERT INTO SQL_ADMIN.SQLMANTAINENCE.DBMantainenceLOG 
	(LogDate, Type, LogDetails,Status) VALUES
	(GetDate(), ''SAN_CLOUD-BACKUP'', ''Error while copying backup to SAN/Cloud: '' + @ErrorMessage,''C'')

    RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH
END

', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'MantainencePlanScriptForFullBackup_Weekly', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20111129, 
		@active_end_date=99991231, 
		@active_start_time=100, 
		@active_end_time=235959, 
		@schedule_uid=N'b47d8c02-6f2f-4f2f-8c07-536a177c5d79'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

EXEC msdb..sp_update_job @job_name = @JobName , @Enabled = @Enabled  
go
-----------------------

-----------------------
USE [msdb]
GO

DECLARE @Enabled BIT
DECLARE @JobName VarChar(1000) 
SET @Enabled = 0 -- By Default False
SET @JobName = 'SQLMantainence_YearlyBackup'
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)
	SET @Enabled = 1

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLMantainence_YearlyBackup')
	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_YearlyBackup', @delete_unused_schedule=1


BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 9/2/2015 12:43:58 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQLMantainence_YearlyBackup', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No descriptiON available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step1- Execute Yearly backup]    Script Date: 9/2/2015 12:43:58 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step1- Execute Yearly backup', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec [SqlMantainence].[SP_MantainencePlanScriptForYearlyBackup]', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step 2 - Copy backups to S3 (cloud folder)]    Script Date: 9/2/2015 12:43:58 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step 2 - Copy backups to S3 (cloud folder)', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'

Declare @sql varchar(1000)
DECLARE @result int;
DECLARE @error_tbl table(error_msg varchar(4000))
DECLARE @SecondaryBackupDestination varchar(3)
DECLARE @BackupFolder VARCHAR(1000)
DECLARE @BackupRootFolder VARCHAR(1000)


SELECT TOP 1 @SecondaryBackupDestination = VALUE 
FROM SQL_ADMIN.SQLMANTAINENCE.DBMANTAINENCECONFIGURATION WITH(NOLOCK) 
WHERE configurationType = ''SecondaryBackupDestination''

SELECT TOP 1 @BackupFolder = VALUE FROM SQL_ADMIN.SQLMANTAINENCE.DBMANTAINENCECONFIGURATION WITH(NOLOCK) WHERE configurationType = ''Yearly_BackupFolder''
Select @BackupRootFolder = substring(@BackupFolder,1,(Len(@BackupFolder) - CharIndex(''\'',Reverse(@BackupFolder),1)))


IF IsNull(@SecondaryBackupDestination,'''') = ''SAN''
	SELECT @sql = ''powershell.exe -nologo -ExecutionPolicy Bypass -file "C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1" "'' + @BackupFolder + ''" "'' + @@ServerName + ''\mssql\Yearly" "backups" "dyon5aEsQQ57" ''
ELSE IF IsNull(@SecondaryBackupDestination,'''') = ''AWS''
	SELECT @sql = ''powershell.exe -nologo -ExecutionPolicy Bypass -file "C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1" "mssql" "'' + @BackupRootFolder +''" "cYhabzAaXTxg9dZYzxK7Y/5w6Hm9B5j9akQk9Uku" ''
ELSE
    SELECT @sql = ''''

IF @sql <> ''''
BEGIN    	
BEGIN TRY	
	INSERT INTO @error_tbl
	EXEC @result = xp_cmdshell @sql

	IF EXISTS(SELECT 1 FROM @error_tbl WHERE error_msg like ''%exception%'' or @result = 1)
	BEGIN
		DECLARE @ErrorMessage NVARCHAR(4000);
		SELECT @ErrorMessage = COALESCE(REPLACE(REPLACE(@ErrorMessage,''+'',''''),''"'',''''),'''') + error_msg + '';'' FROM @error_tbl where error_msg is not null
		RAISERROR (@ErrorMessage, 16,1);
	END
END TRY
BEGIN CATCH
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;

    SELECT @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
	INSERT INTO SQL_ADMIN.SQLMANTAINENCE.DBMantainenceLOG 
	(LogDate, Type, LogDetails,Status) VALUES
	(GetDate(), ''SAN_CLOUD-BACKUP'', ''Error while copying backup to SAN/Cloud: '' + @ErrorMessage,''C'')

    RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH
END
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'MantainencePlanScriptForBackup_Yearly', 
		@enabled=1, 
		@freq_type=32, 
		@freq_interval=8, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=16, 
		@freq_recurrence_factor=12, 
		@active_start_date=20151231, 
		@active_end_date=99991231, 
		@active_start_time=20100, 
		@active_end_time=235959, 
		@schedule_uid=N'ace7471d-86aa-47de-9d58-f41bff34bb04'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:


EXEC msdb..sp_update_job @job_name = @JobName , @Enabled = @Enabled  
go

-----------------------




--  Job  - Differential Backup Job
 
USE [msdb]
GO

DECLARE @Enabled BIT
DECLARE @JobName VarChar(1000) 
SET @Enabled = 0 -- By Default False
SET @JobName = 'SQLMantainence_DiffBackup'
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)
	SET @Enabled = 1
	
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLMantainence_DiffBackup')
	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_DiffBackup', @delete_unused_schedule=1

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 30/09/2015 10:51:10 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQLMantainence_DiffBackup', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No descriptiON available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step1- Execute Diff backup]    Script Date: 30/09/2015 10:51:10 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step1- Execute Diff backup', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=2, 
		@on_fail_action=4, 
		@on_fail_step_id=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec [SqlMantainence].[SP_MantainencePlanScriptForDiffBackup]', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step 2 - Check Backup Failure status]    Script Date: 30/09/2015 10:51:10 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step 2 - Check Backup Failure status', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=3, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec [SQLMantainence].[Check_DailyBackupFailures]', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Step 3 - Copy backups to S3 (cloud folder)]    Script Date: 30/09/2015 10:51:10 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Step 3 - Copy backups to S3 (cloud folder)', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'

Declare @sql varchar(1000)
DECLARE @result int;
DECLARE @error_tbl table(error_msg varchar(4000))
DECLARE @SecondaryBackupDestination varchar(3)
DECLARE @BackupFolder VARCHAR(1000)
DECLARE @BackupRootFolder VARCHAR(1000)


SELECT TOP 1 @SecondaryBackupDestination = VALUE 
FROM SQL_ADMIN.SQLMANTAINENCE.DBMANTAINENCECONFIGURATION WITH(NOLOCK) 
WHERE configurationType = ''SecondaryBackupDestination''

SELECT TOP 1 @BackupFolder = VALUE FROM SQL_ADMIN.SQLMANTAINENCE.DBMANTAINENCECONFIGURATION WITH(NOLOCK) WHERE configurationType = ''Diff_BackupFolder''
Select @BackupRootFolder = substring(@BackupFolder,1,(Len(@BackupFolder) - CharIndex(''\'',Reverse(@BackupFolder),1)))


IF IsNull(@SecondaryBackupDestination,'''') = ''SAN''
	SELECT @sql = ''powershell.exe -nologo -ExecutionPolicy Bypass -file "C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1" "'' + @BackupFolder + ''" "'' + @@ServerName + ''\mssql\DIFF" "backups" "dyon5aEsQQ57" ''
ELSE IF IsNull(@SecondaryBackupDestination,'''') = ''AWS''
	SELECT @sql = ''powershell.exe -nologo -ExecutionPolicy Bypass -file "C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1" "mssql" "'' + @BackupRootFolder +''" "cYhabzAaXTxg9dZYzxK7Y/5w6Hm9B5j9akQk9Uku" ''
ELSE
    SELECT @sql = ''''

IF @sql <> ''''
BEGIN    	
BEGIN TRY	
	INSERT INTO @error_tbl
	EXEC @result = xp_cmdshell @sql

	IF EXISTS(SELECT 1 FROM @error_tbl WHERE error_msg like ''%exception%'' or @result = 1)
	BEGIN
		DECLARE @ErrorMessage NVARCHAR(4000);
		SELECT @ErrorMessage = COALESCE(REPLACE(REPLACE(@ErrorMessage,''+'',''''),''"'',''''),'''') + error_msg + '';'' FROM @error_tbl where error_msg is not null
		RAISERROR (@ErrorMessage, 16,1);
	END
END TRY
BEGIN CATCH
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;

    SELECT @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
	INSERT INTO SQL_ADMIN.SQLMANTAINENCE.DBMantainenceLOG 
	(LogDate, Type, LogDetails,Status) VALUES
	(GetDate(), ''SAN_CLOUD-BACKUP'', ''Error while copying backup to SAN/Cloud: '' + @ErrorMessage,''C'')

    RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH
END
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'MantainencePlanScriptForDiffBackup_Daily', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=126, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20111129, 
		@active_end_date=99991231, 
		@active_start_time=100, 
		@active_end_time=235959, 
		@schedule_uid=N'43ed75c8-2999-4af7-9186-3ccef9914939'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:



EXEC msdb..sp_update_job @job_name = @JobName , @Enabled = @Enabled 
GO

-- Job 8
USE [msdb]

GO

DECLARE @Enabled BIT
DECLARE @JobName VarChar(1000) 
SET @Enabled = 0 -- By Default False
SET @JobName = 'SQLMantainence_CleanUpMaintenanceLogEntries'
IF EXISTS(SELECT Name,enabled FROM msdb.dbo.sysjobs WHERE name = @JobName AND Enabled = 1)
	SET @Enabled = 1
	
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLMantainence_CleanUpMaintenanceLogEntries')
	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_CleanUpMaintenanceLogEntries', @delete_unused_schedule=1


/****** Object:  Job [SQLMantainence_CleanUpMaintenanceLogEntries]    Script Date: 11/21/2012 15:48:01 ******/
BEGIN TRANSACTION
DECLARE @RETURNCode INT
SELECT @RETURNCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 11/21/2012 15:48:01 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @RETURNCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @RETURNCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @RETURNCode =  msdb.dbo.sp_add_job @job_name=N'SQLMantainence_CleanUpMaintenanceLogEntries', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This job removes any entries in the maintainence logs which are older than 30 days.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'SA', 
		@job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @RETURNCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [step1 of cleanup maintenance log entries job]    Script Date: 11/21/2012 15:48:01 ******/
EXEC @RETURNCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'step1 of cleanup maintenance log entries job', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE SQL_ADMIN

DELETE FROM SQLMantainence.DBMantainenceLOG
WHERE 
CAST(LogDate AS DATE) <  
CAST(DATEADD(DAY,-30,GETDATE()) AS DATE)', 
		@database_name=N'SQL_ADMIN', 
		@flags=0
IF (@@ERROR <> 0 OR @RETURNCode <> 0) GOTO QuitWithRollback
EXEC @RETURNCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @RETURNCode <> 0) GOTO QuitWithRollback
EXEC @RETURNCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'schedule fOR clean up maintainence log job', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20121005, 
		@active_end_date=99991231, 
		@active_start_time=120000, 
		@active_end_time=235959, 
		@schedule_uid=N'9c4608ed-cac6-492c-b62e-f345bc58cac4'
IF (@@ERROR <> 0 OR @RETURNCode <> 0) GOTO QuitWithRollback
EXEC @RETURNCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'

IF (@@ERROR <> 0 OR @RETURNCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:


EXEC msdb..sp_update_job @job_name = @JobName , @Enabled = @Enabled  

-- Job 9  -- Just fOR removing the old job i.e. check backup failure alert job IF it still EXISTS
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLMantainence_CheckForDailyBackupFailures')
	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_CheckForDailyBackupFailures', @delete_unused_schedule=1

-- Job 10  -- Just fOR removing the old job i.e. SQLMantainence_CleanUpMaintenanceLogEntries job IF it still EXISTS
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SQLMantainence_CleanUpMaintenanceLogEntries')
	EXEC msdb.dbo.sp_delete_job @job_name=N'SQLMantainence_CleanUpMaintenanceLogEntries', @delete_unused_schedule=1

-- Job 10  -- Just fOR removing the old job i.e. syspolicy_purge_history job IF it still EXISTS
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'syspolicy_purge_history')
	EXEC msdb.dbo.sp_delete_job @job_name=N'syspolicy_purge_history', @delete_unused_schedule=1



--*******************************************************************************
-- STEP 12  ...CREATING DATABASE MAIL PROFILE AND ACCOUNT FOR MONITORING ALERTS
--*******************************************************************************

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysmail_profile WHERE name = 'DBMaintenance')
BEGIN
	USE [master]

	EXEC sp_configure 'Database Mail XPs',1
	RECONFIGURE

	-- Create a New Mail Profile fOR Notifications
	EXECUTE msdb.dbo.sysmail_add_profile_sp
		   @profile_name = 'DBMaintenance',
		   @descriptiON = 'Profile for alerts FROM SQL maintenance AND monitoring'

	---- SET the New Profile as the Default
	EXECUTE msdb.dbo.sysmail_add_principalprofile_sp
		@profile_name = 'DBMaintenance',
		@principal_name = 'public',
		@is_default = 0 ;

	-- Create an Account fOR the Notifications
	EXECUTE msdb.dbo.sysmail_add_account_sp
		@account_name = 'SQL Maintenance Alerts',
		@descriptiON = 'SQL Maintenance Alerts',
		@email_address = 'no_reply@webuy.com', 
		@display_name = 'SQL Maintenance Alerts',
		@mailserver_name = '10.4.1.15',
		@port = '25'
		--,@enable_ssl = 0,
		--@username =  '?', 
		--@password = '?' 

	-- Add the Account to the Profile
	EXECUTE msdb.dbo.sysmail_add_profileaccount_sp
		@profile_name = 'DBMaintenance',
		@account_name = 'SQL Maintenance Alerts',
		@sequence_number = 1
END


--USE master
--GO
--IF OBJECT_ID ('sp_WhoIsActive') IS NOT NULL
--	DROP PROCEDURE sp_WhoIsActive
--GO


--*******************************************************************************
-- STEP 13  ... CREATING TABLE Audit_DatabaseAutoGrowth
--*******************************************************************************

USE [SQL_ADMIN]
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_id = OBJECT_ID(N'[SQLMantainence].[Audit_DatabaseAutoGrowth]') AND TYPE IN (N'U'))
BEGIN
	CREATE TABLE [SQLMantainence].[Audit_DatabaseAutoGrowth](
		[ID] [bigint] IDENTITY(1,1) NOT NULL,
		[StartTime] [datetime] NOT NULL,
		[DatabaseName] [nVarChar](max) NULL,
		[FileName] [nVarChar](max) NOT NULL,
		[GrowthInMB] [int] NULL,
		[Duration_in_seconds] [bigint] NULL,
		[FileType] [VarChar](5) NULL
	) ON [PRIMARY]
END
GO

CREATE TABLE #tmpTriggerDetails (IsTriggerEnabled BIT)
IF EXISTS(SELECT 1 FROM SQL_ADMIN.SYS.TRIGGERS WHERE NAME =  'SENDEMAILONEVERYAUTOGROWTHALERT' AND IS_DISABLED = 0)
	INSERT INTO #tmpTriggerDetails VALUES (1)

IF EXISTS(SELECT 1 FROM SQL_ADMIN.SYS.TRIGGERS WHERE NAME =  'SENDEMAILONEVERYAUTOGROWTHALERT')
	DROP TRIGGER [SQLMantainence].[SendEmailOnEveryAutogrowthAlert]

GO
-- =============================================
-- Author:           Suji
-- Create date: 2014-03-12
-- Description:      Send email on every autogrowth event
-- =============================================
CREATE TRIGGER [SQLMantainence].[SendEmailOnEveryAutogrowthAlert] 
   ON  [SQLMantainence].[Audit_DatabaseAutoGrowth]
   AFTER  INSERT
AS 
BEGIN
       SET NOCOUNT ON;
       DECLARE @Subject VARCHAR(2000) = NULL


SELECT @Subject = '***** Autogrowth has happened on '+i.databaseName+' database at '+CAST(i.StartTime AS VARCHAR(20))+' by '+ CAST(i.GrowthInMB AS VARCHAR(20)) + ' MB on '+@@servername
from inserted i where i.FileType = 'Rows'

IF @Subject IS NOT NULL
BEGIN
	  DECLARE @EMAILRECEPIENTS1 VARCHAR(2000)
	   SELECT Top 1 @EMAILRECEPIENTS1 =  [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='EmailRecipient'
		
       EXECUTE msdb..sp_send_dbmail 
                             @Profile_Name = 'DBMaintenance', 
                             @Recipients = @EMAILRECEPIENTS1 ,    
                             @Subject = @Subject,
                             @Subject = @Subject,
                             @Body_Format= 'HTML',
                             @Execute_Query_Database = 'SQL_ADMIN'    
END

END
GO

IF NOT EXISTS(SELECT * FROM #tmpTriggerDetails WHERE IsTriggerEnabled = 1)
	DISABLE TRIGGER [SQLMANTAINENCE].[SENDEMAILONEVERYAUTOGROWTHALERT] ON [SQLMANTAINENCE].[AUDIT_DATABASEAUTOGROWTH]

DROP TABLE #tmpTriggerDetails


--*******************************************************************************
-- STEP 14  ... CREATING TABLE AdhocBackupsDetails
--*******************************************************************************
USE [SQL_ADMIN]
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_id = OBJECT_ID(N'[SQLMantainence].[AdhocBackupsDetails]') AND TYPE IN (N'U'))
BEGIN
	CREATE TABLE [SQLMantainence].[AdhocBackupsDetails](
		[RequestID] [int] IDENTITY(1,1) NOT NULL,
		[DatabaseName] [nVarChar](1000) NOT NULL,
		[EmailRecepients] [nVarChar](1000) NOT NULL,
		[ServerDatetime] [datetime] NOT NULL,
		[BackupCompleted] [bit] NOT NULL,
		[RetentionInDays] [smallint] Default(7)
	) ON [PRIMARY]

	ALTER TABLE [SQLMantainence].[AdhocBackupsDetails] ADD  CONSTRAINT [DF__AdhocBack__Email__72910220]  DEFAULT ('') FOR [EmailRecepients]
	ALTER TABLE [SQLMantainence].[AdhocBackupsDetails] ADD  CONSTRAINT [DF__AdhocBack__Serve__73852659]  DEFAULT (getdate()) FOR [ServerDatetime]
	ALTER TABLE [SQLMantainence].[AdhocBackupsDetails] ADD  CONSTRAINT [DF__AdhocBack__Backu__74794A92]  DEFAULT ((1)) FOR [BackupCompleted]
END
ELSE
BEGIN
	IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'AdhocBackupsDetails' AND COLUMN_NAME = 'RetentionInDays')
		ALTER TABLE SQLMantainence.AdhocBackupsDetails ADD	[RetentionInDays] [smallint] Default(7)

END


GO

--*******************************************************************************
-- STEP   ...CREATING STORED PROCEDURE ExecuteAdhocBackupRequest 
--*******************************************************************************
USE [SQL_ADMIN]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [SQLMantainence].[ExecuteAdhocBackupRequest]
-- With Encryption
AS 
BEGIN 
SET NOCOUNT ON;

DECLARE @DATABASENAME NVarChar(2000)
DECLARE @BACKUPPATH NVarChar(2000)
DECLARE @BACKUPFILENAME NVarChar(2000)

DECLARE @TotalBackupRequests SMALLINT
DECLARE @EMAILRECEPIENTS NVarChar(2000) 
DECLARE @EMAILRECEPIENTS1 NVarChar(2000) 
DECLARE @intCurrentBackupRequest SMALLINT
DECLARE @SUBJECT NVarChar(2000)
DECLARE @HTML_BODY NVarChar(MAX)

DECLARE @BACKUPTIME DATETIME
DECLARE @CURRENTTIME DATETIME
DECLARE @BackupCheckFlag BIT
DECLARE @RequestID INT
DECLARE @ACTUAL_IP_ADDRESS VarChar(1000)
DECLARE @Environment VarChar (50), @EnvironmentDesc VarChar (50)
DECLARE @RetentionPeriodInDays SmallInt
DECLARE @RetainTillDate Date

CREATE TABLE #temp1(SQL_IP VarChar(3000))
INSERT INTO #temp1 EXEC xp_cmdshell 'ipconfig' 	
DECLARE @IPAddress VarChar(300) 
SET @IPAddress = (SELECT TOP 1 SQL_IP FROM #temp1  WITH(NOLOCK) WHERE SQL_IP LIKE '%IPv4%' ORDER BY SQL_IP DESC) 	
DECLARE @len INT 
SET @Len = CHARINDEX(':', @IPAddress) 
SELECT TOP 1  @ACTUAL_IP_ADDRESS= LTRIM(RTRIM(SUBSTRING(@IPAddress, @Len+1, LEN(@IPAddress)))) 
DROP TABLE #temp1



SET @CURRENTTIME=GETDATE()

SELECT TOP 1  @Environment = [VALUE]  FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='Environment'
SELECT TOP 1 @EnvironmentDesc = CASE  LEFT(@Environment,3) WHEN 'Dev' THEN 'Development' WHEN 'Prod' THEN 'Production' ELSE  @Environment END
SELECT Top 1 @EMAILRECEPIENTS1 =  [VALUE] FROM SQLMantainence.DBMantainenceConfiguratiON  WITH(NOLOCK) WHERE ConfigurationType='EmailRecipient'

SELECT @BACKUPPATH = Value  FROM [SQL_ADMIN].SQLMantainence.DBMantainenceConfiguratiON With(NoLock) WHERE configurationType = 'Adhoc_BackupFolder'
IF @BACKUPPATH IS NULL SET @BACKUPPATH = 'C:'  --  Just fOR precautiON IF backup folder is not defined

DECLARE  @TmpBackupRequests Table(ID INT Identity(1,1), RequestID Int, DatabaseName VarChar(1000), [EmailRecepients] VarChar(1000), RetentionInDays SmallInt)
Insert Into @TmpBackupRequests (RequestID, DatabaseName, [EmailRecepients], RetentionInDays) 
	SELECT  RequestID, DatabaseName, [EmailRecepients], RetentionInDays FROM SQLMantainence.AdhocBackupsDetails With(NoLock) 
	WHERE BackupCompleted = 0 AND  ServerDateTime  <= GETDATE() 
	ORDER BY 1 

SELECT  @TotalBackupRequests=COUNT(*) FROM @TmpBackupRequests

IF @TotalBackupRequests = 0 PRINT 'No Backup to execute'
SET @intCurrentBackupRequest=1
WHILE(@intCurrentBackupRequest <= @TotalBackupRequests)
   BEGIN   
	   SELECT @DATABASENAME=DATABASENAME FROM @tmpBackupRequests WHERE ID=@intCurrentBackupRequest
	   SELECT @RequestID = RequestID FROM @tmpBackupRequests WHERE ID=@intCurrentBackupRequest
	   SELECT @RetentionPeriodInDays = RetentionInDays FROM @tmpBackupRequests WHERE ID=@intCurrentBackupRequest
	   
	   
	   SELECT @EMAILRECEPIENTS = @EMAILRECEPIENTS1 + ';' + EmailRecepients FROM @tmpBackupRequests WHERE ID=@intCurrentBackupRequest

	   SELECT @RetainTillDate = DateAdd(Day, @RetentionPeriodInDays, getdate())

	   SELECT @BACKUPFILENAME = @BACKUPPATH +'\' + @DATABASENAME + '@' + 'DONOTDELETETILL@' + CAST(@RetainTillDate as varchar(100)) + '.BAK'
	   --+ replace(cast(@RetainTillDate as varchar(100)),'-','_') + '.BAK'

      BEGIN TRY
		BACKUP DATABASE @DATABASENAME 
		TO DISK = @BACKUPFILENAME 
		WITH  COPY_ONLY, CHECKSUM, INIT
			
        INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'ADHOC-FULL-BACKUP','ADHOC Full Backup Successfull fOR the database: 

'+@DATABASENAME,'I');
           
		SELECT  @Subject = UPPER(@EnvironmentDesc) + ' -Status of  Ad-hoc backup request  ON server ' + @@SERVERNAME + '( IP Address: ' + @ACTUAL_IP_ADDRESS + ')'
		SET @HTML_BODY= '<HTML><BODY>Hi<BR>'
		SELECT @HTML_BODY= @HTML_BODY + '<BR>Ad-hoc backup request fOR '+@DATABASENAME+' database is completed sucessfully.<BR>The backup file(s) 
are available ON locatiON <b>'+@BACKUPFILENAME+'</b><br>'
	    
	    
		
		SET @HTML_BODY=@HTML_BODY+'<br>Note: The backup was done by an automated script scheduled fOR this time.  Hence please confirm the backup 
files before proceeding with your activities.  Also please free to contact the SQL team fOR any issues/further assistance.<BR><BR>Regards<BR>SQL 
Team</BODY></HTML>'
		 
		EXECUTE msdb..sp_send_dbmail 
				@Profile_Name  =  'DBMaintenance', 
				@Recipients  = @EMAILRECEPIENTS,
				@Subject  = @SUBJECT,
				@Body_format =  'HTML',
				@Body  = @HTML_BODY,
				@Execute_Query_Database  =  'SQL_ADMIN'			
		
		
	  END TRY
	  BEGIN CATCH	  
		  SET @SUBJECT='Adhoc-Backup Request failed ON Server ' + @@SERVERNAME
		  SET @HTML_BODY = 'Adhoc backup failed fOR database ' + @DATABASENAME+ '<br>ErrOR Message: ' + ERROR_MESSAGE()
		  INSERT INTO SQLMantainence.DBMantainenceLOG VALUES (GETDATE(),'ADHOC-FULL-BACKUP','ADHOC Full Backup failed fOR the database: '+@DATABASENAME+', Exception: ' + ERROR_MESSAGE(),'C');
		  EXECUTE msdb..sp_send_dbmail 
					@Profile_Name  =  'DBMaintenance', 
					@Recipients  = @EMAILRECEPIENTS1,
					@Subject  = @SUBJECT ,
					@Body_format =  'HTML',
					@Body  = @HTML_BODY,
					@Execute_Query_Database  =  'SQL_ADMIN'
	  END CATCH
	  
	  UPDATE  [SQL_ADMIN].[SQLMantainence].[AdhocBackupsDetails] SET BackupCompleted=1 WHERE RequestID=@RequestID
	  SET @intCurrentBackupRequest=@intCurrentBackupRequest + 1	
   END		-- END of Loop
END
GO


USE [SQL_Admin]
GO
/****** Object:  StoredProcedure [SQLMantainence].[sp_DeleteAdhocBackupFilesAFterRetentionPeriod]    Script Date: 6/19/2014 3:20:08 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [SQLMantainence].[sp_DeleteAdhocBackupFilesAFterRetentionPeriod]
-- With Encryption
AS
BEGIN

	SET NOCOUNT ON 
	DECLARE @DatabaseName VARCHAR(4000)
	DECLARE @BackupFileName VARCHAR(4000)
	DECLARE @RetentionDate varchar(100)
	DECLARE @AdhocBackupFolder Varchar(1000)
	DECLARE @CmdStrSourceInfo VarChar(1000)
	DECLARE @CmdStrSource VarChar (2000)
	DECLARE @i BIGINT
	DECLARE @j BIGINT  
	DECLARE @filedate VarChar(5000)
	DECLARE @filename VarChar(5000)
	DECLARE @filetype VarChar(100)
	DECLARE @fileRetentionDate DATETIME
	DECLARE @inpath VarChar(1000)
	DECLARE @filestatus VarChar(2000)
	DECLARE @total BIGINT
	DECLARE @RetentionPeriodForTLOGBackupsInDays INT = 1

	-- ***********************************************************************************************************
	-- THE SCRIPT BELOW DETECTS ALL DRIVES IN THE SERVER AND CHECKS FOR "DBA" FOLDER ON THE ROOT.
	-- THE ADHOC BACKUP FILES ARE EXPECTED WITHIN DBA FOLDER ON ALL DRIVES E.G. C:\DBA, D:\DBA
	-- ***********************************************************************************************************
	DECLARE  @output TABLE (Line VARCHAR(1000),ROW INT IDENTITY (1,1)) 
	DECLARE @SQL varchar(4000)

	SET @sql = 'powershell.exe -c "Get-WmiObject -Class Win32_Volume -Filter ''DriveType = 3'' | SELECT name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1048576+''%''+$_.freespace/1048576+''*''}"' 
	INSERT INTO @output (Line) EXECUTE xp_cmdshell @sql 

	MERGE @OUTPUT AS TARGET
	USING (SELECT ROW,LINE FROM @OUTPUT) AS SOURCE (ROW,LINE) ON (SOURCE.ROW = TARGET.ROW)
	WHEN MATCHED AND SOURCE.LINE IS NULL THEN 
		DELETE
	WHEN MATCHED AND SOURCE.LINE IS NOT NULL THEN	
		UPDATE SET line = RTRIM(LTRIM(SUBSTRING(SOURCE.line,1,CHARINDEX('|',SOURCE.line) -1)))  + 'DBA'; 
	-- ***********************************************************************************************************

	-- ***********************************************************************************************************
	-- BELOW SCRIPT SCANS THROUGH EACH DRIVE DBA FOLDER TO CHECK FOR ANY ADHOC FILES TO DELETE
	-- ***********************************************************************************************************
	DECLARE curAdhocFolders CURSOR FOR SELECT LINE FROM @OUTPUT	
	OPEN curAdhocFolders
	FETCH NEXT FROM curAdhocFolders INTO @AdhocBackupFolder
	WHILE @@FETCH_STATUS = 0
	BEGIN	
			print 'Checking ' + @AdhocBackupFolder
				
			IF Len(ISNULL(@AdhocBackupFolder,'')) >= 3     -- IF Adhoc Folder is valid then proceed
			BEGIN
				CREATE TABLE #DirFileSourceInfo(DirFileInfo VarChar(2000))
				CREATE TABLE #DirFileSource(DirFile VarChar(2000))
				CREATE TABLE #FilesSource( [RowNo] BIGINT,[FileName] VarChar(2000),[FileType] VarChar(2000),[FileModIfiedDate] VarChar(50), [FileSize] BIGINT )

				SELECT @CmdStrSourceInfo = 'dir /O-S /-C /A-D "' + @AdhocBackupFolder + '"'        
				SELECT @CmdStrSource = 'dir /b /s ' + @AdhocBackupFolder + '\*.bak,' +  @AdhocBackupFolder + '\*.abf,'  +  @AdhocBackupFolder + '\*.zip'  

				INSERT INTO #DirFileSourceInfo (DirFileInfo) EXEC xp_cmdshell @CmdStrSourceInfo  
				INSERT INTO [#DirFileSource]([DirFile])  EXEC xp_cmdshell @CmdStrSource  

				INSERT INTO #FilesSource([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )      
					SELECT ROW_NUMBER() OVER (ORDER BY [DirFile]) AS RowNo,DIRFILE,'BAK',NULL,NULL
					FROM [#DirFileSource]
					WHERE RIGHT(IsNUll(DIRFILE,''),4) = '.BAK'

				INSERT INTO #FilesSource([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )      
					SELECT ROW_NUMBER() OVER (ORDER BY [DirFile]) AS RowNo,DIRFILE,'ABF',NULL,NULL
					FROM [#DirFileSource]
					WHERE RIGHT(IsNUll(DIRFILE,''),4) = '.ABF'
				
				INSERT INTO #FilesSource([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )      
					SELECT ROW_NUMBER() OVER (ORDER BY [DirFile]) AS RowNo,DIRFILE,'ZIP',NULL,NULL
					FROM [#DirFileSource]
					WHERE RIGHT(IsNUll(DIRFILE,''),4) = '.ZIP'	

				SET @total=0
				SELECT @i=  COUNT(*) FROM #FilesSource
				SET @j=1

				WHILE(@j <= @i)
				BEGIN 
				   SELECT @filename =[FileName] FROM #FilesSource  WITH(NOLOCK) WHERE RowNO=@j

				IF CHARINDEX('@',REVERSE(@filename)) > 0 
				BEGIN
					SELECT @RetentionDate =  RIGHT(@filename,(CHARINDEX('@',REVERSE(@filename),1)-1))
					SELECT @RetentionDate = SUBSTRING(@RETENTIONDATE,1,LEN(@RetentionDate)-4)
				END
				ELSE
					SELECT @RetentionDate =  ''

				IF ISDATE(@RetentionDate) = 1
				BEGIN
		
				IF CAST(@RetentionDate AS DATE) < CAST(GETDATE() AS DATE)
				BEGIN
					PRINT 'DELETED Adhoc Backup file i.e. "' + @filename + '"'
					--select @FileName, @RetentionDate
					SET @inpath = 'del  /Q "' + @filename + '"'
					Execute xp_cmdshell @inPath , no_output  

					INSERT INTO SQL_ADMIN.SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'CLEANUP-ACTIVITY','Deleted File "' + @filename + '"','I');
				END
				END

				   SET @j=@j+1;
				END


				DROP TABLE  #DirFileSourceInfo
				DROP TABLE  #DirFileSource
				DROP TABLE #FilesSource 

			END  -- END OF IF FOR ADHOC BACKUP FOLDER CHECK
		FETCH NEXT FROM curAdhocFolders INTO @AdhocBackupFolder
	END  -- END OF CURSOR WHILE FETCH LOOP
	CLOSE curAdhocFolders
	DEALLOCATE curAdhocFolders

-- **********************************
-- SCRIPT BELOW WILL REMOVE ALL MONTHLY BACKUP FILE AFTER ITS 45 DAYS RETENTION.
-- P.S. THESE MONTHLY BACKUPS ARE ALRADY STORED IN AWS S3 BUCKET FOR LONG TERM RETENTION
-- **********************************



DECLARE @RetentionDaysForMonthlyBackups INT 
SELECT  @RetentionDaysForMonthlyBackups = Value FROM  SQL_ADMIN.SQLMantainence.DBMantainenceConfiguration WITH(NOLOCK) WHERE configurationType = 'RetentionPeriodForMonthlybackupInDays'
SELECT  @RetentionDaysForMonthlyBackups = IsNull(@RetentionDaysForMonthlyBackups,15)
SELECT @RetentionDate = Cast(DateAdd(day,(-1 * @RetentionDaysForMonthlyBackups),cast(getdate() as DATE)) as varchar(15)) 

SELECT @AdhocBackupFolder = VALUE FROM SQL_ADMIN.SQLMantainence.DBMantainenceConfiguration WHERE configurationType = 'Monthly_BackupFolder' 
SELECT @AdhocBackupFolder = IsNull(@AdhocBackupFolder,'') 
IF @AdhocBackupFolder = '?'  
  SET @AdhocBackupFolder = '' 
 
print 'Checking ' + @AdhocBackupFolder 
 
IF Len(ISNULL(@AdhocBackupFolder,'')) >= 3     -- IF Adhoc Folder is valid then proceed 
BEGIN 
	CREATE TABLE #DirFileSourceInfo1(DirFileInfo VarChar(2000)) 
	CREATE TABLE #DirFileSource1(DirFile VarChar(2000)) 
	CREATE TABLE #FilesSource1( [RowNo] BIGINT,[FileName] VarChar(2000),[FileType] VarChar(2000),[FileModIfiedDate] VarChar(50), [FileSize] BIGINT ) 
	 
	SELECT @CmdStrSourceInfo = 'dir /O-S /-C /A-D "' + @AdhocBackupFolder + '"'         
	SELECT @CmdStrSource = 'dir /b /s "' + @AdhocBackupFolder + '\*.bak","' +  @AdhocBackupFolder + '\*.abf","'  +  @AdhocBackupFolder + '\*.zip"'   
	 
	INSERT INTO #DirFileSourceInfo1 (DirFileInfo) EXEC xp_cmdshell @CmdStrSourceInfo   
	INSERT INTO [#DirFileSource1]([DirFile])  EXEC xp_cmdshell @CmdStrSource   
	 
	INSERT INTO #FilesSource1([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )       
	SELECT ROW_NUMBER() OVER (ORDER BY [DirFile]) AS RowNo,DIRFILE,'BAK',NULL,NULL 
	FROM [#DirFileSource1] 
	WHERE RIGHT(IsNUll(DIRFILE,''),4) = '.BAK' 
	 
	INSERT INTO #FilesSource1([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )       
	SELECT ROW_NUMBER() OVER (ORDER BY [DirFile]) AS RowNo,DIRFILE,'ABF',NULL,NULL 
	FROM [#DirFileSource1] 
	WHERE RIGHT(IsNUll(DIRFILE,''),4) = '.ABF' 
	 
	INSERT INTO #FilesSource1([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )       
	SELECT ROW_NUMBER() OVER (ORDER BY [DirFile]) AS RowNo,DIRFILE,'ZIP',NULL,NULL 
	FROM [#DirFileSource1] 
	WHERE RIGHT(IsNUll(DIRFILE,''),4) = '.ZIP'	 
	 
	SET @total=0 
	SELECT @i=  COUNT(*) FROM #FilesSource1 
	SET @j=1 
 
 print 'checking total of files = ' + cast(@i as varchar)
 
	WHILE(@j <= @i) 
	BEGIN  
		SELECT @filename =[FileName] FROM #FilesSource1  WITH(NOLOCK) WHERE RowNO=@j 
		 
		IF CHARINDEX('@',REVERSE(@filename)) > 0  
 			SELECT @FileDate = SUBSTRING(@FileName,((CHARINDEX('@',@FileName,1))+1),8)
		ELSE 
			SELECT @FileDate =  '' 
		
		IF ISDATE(@FileDate) = 1 
		BEGIN 	
		
		-----------------------------------------------------------
		-- DEBUG CODE	
		--print '---------------------------------------------------------'
		--Print 'Checking File ' + @filename + ' with file date of ' + @FileDate
		--print 'RetentionDate = ' + @RetentionDate 
  --		print 'File DAte = ' + @FileDate 
  --		print 'Condition is FIle Date < Retention date'
  		-- [SQLMantainence].[sp_DeleteAdhocBackupFilesAFterRetentionPeriod]
		---------------------------------------------
		
			IF CAST(@FileDate AS DATE) < CAST(@RetentionDate AS DATE)  
			BEGIN 
				PRINT 'DELETED Monthly Backup file i.e. "' + @filename + '"' 
				SET @inpath = 'del  /Q "' + @filename + '"' 
				
				Execute xp_cmdshell @inPath , no_output  
				INSERT INTO SQL_ADMIN.SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'CLEANUP-ACTIVITY','Deleted File "' + @filename + '"','I'); 
			END 
		END 
	 
		SET @j=@j+1; 
END 
 
 
DROP TABLE  #DirFileSourceInfo1 
DROP TABLE  #DirFileSource1 
DROP TABLE #FilesSource1  
 
END  -- END OF IF FOR monthly BACKUP FOLDER CHECK 

-- **********************************
-- SCRIPT BELOW WILL REMOVE ALL YEARLY BACKUP FILE AFTER ITS 45 DAYS RETENTION.
-- P.S. THESE YEARLY BACKUPS ARE ALRADY STORED IN AWS S3 BUCKET FOR LONG TERM RETENTION
-- **********************************
 
DECLARE @RetentionDaysForYearlyBackups INT
SELECT  @RetentionDaysForYearlyBackups = Value FROM  SQL_ADMIN.SQLMantainence.DBMantainenceConfiguration WITH(NOLOCK) WHERE configurationType = 'RetentionPeriodForYearlybackupInDays'
SELECT  @RetentionDaysForYearlyBackups = IsNull(@RetentionDaysForYearlyBackups,15)
SELECT @RetentionDate = Cast(DateAdd(day,(-1 * @RetentionDaysForYearlyBackups),cast(getdate() as DATE)) as varchar(15)) 

SELECT @AdhocBackupFolder = VALUE FROM SQL_ADMIN.SQLMantainence.DBMantainenceConfiguration WHERE configurationType = 'Yearly_BackupFolder' 
SELECT @AdhocBackupFolder = IsNull(@AdhocBackupFolder,'') 
IF @AdhocBackupFolder = '?'  
  SET @AdhocBackupFolder = '' 
 
print 'Checking ' + @AdhocBackupFolder 
 
IF Len(ISNULL(@AdhocBackupFolder,'')) >= 3     -- IF Adhoc Folder is valid then proceed 
BEGIN 
	CREATE TABLE #DirFileSourceInfo2(DirFileInfo VarChar(2000)) 
	CREATE TABLE #DirFileSource2(DirFile VarChar(2000)) 
	CREATE TABLE #FilesSource2( [RowNo] BIGINT,[FileName] VarChar(2000),[FileType] VarChar(2000),[FileModIfiedDate] VarChar(50), [FileSize] BIGINT ) 
	 
	SELECT @CmdStrSourceInfo = 'dir /O-S /-C /A-D "' + @AdhocBackupFolder + '"'         
	SELECT @CmdStrSource = 'dir /b /s "' + @AdhocBackupFolder + '\*.bak","' +  @AdhocBackupFolder + '\*.abf","'  +  @AdhocBackupFolder + '\*.zip"'   
	 
	INSERT INTO #DirFileSourceInfo2 (DirFileInfo) EXEC xp_cmdshell @CmdStrSourceInfo   
	INSERT INTO [#DirFileSource2]([DirFile])  EXEC xp_cmdshell @CmdStrSource   
	 
	INSERT INTO #FilesSource2([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )       
	SELECT ROW_NUMBER() OVER (ORDER BY [DirFile]) AS RowNo,DIRFILE,'BAK',NULL,NULL 
	FROM [#DirFileSource2] 
	WHERE RIGHT(IsNUll(DIRFILE,''),4) = '.BAK' 
	 
	INSERT INTO #FilesSource2([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )       
	SELECT ROW_NUMBER() OVER (ORDER BY [DirFile]) AS RowNo,DIRFILE,'ABF',NULL,NULL 
	FROM [#DirFileSource2] 
	WHERE RIGHT(IsNUll(DIRFILE,''),4) = '.ABF' 
	 
	INSERT INTO #FilesSource2([RowNo],[FileName],[FileType],[FileModIfiedDate], [FileSize] )       
	SELECT ROW_NUMBER() OVER (ORDER BY [DirFile]) AS RowNo,DIRFILE,'ZIP',NULL,NULL 
	FROM [#DirFileSource2] 
	WHERE RIGHT(IsNUll(DIRFILE,''),4) = '.ZIP'	 
	 
	SET @total=0 
	SELECT @i=  COUNT(*) FROM #FilesSource2 
	SET @j=1 
 
 print 'checking total of files = ' + cast(@i as varchar)
 
	WHILE(@j <= @i) 
	BEGIN  
		SELECT @filename =[FileName] FROM #FilesSource2  WITH(NOLOCK) WHERE RowNO=@j 
		 
		IF CHARINDEX('@',REVERSE(@filename)) > 0  
			SELECT @FileDate = SUBSTRING(@FileName,((CHARINDEX('@',@FileName,1))+1),8)
		ELSE 
			SELECT @FileDate =  '' 
		 
		IF ISDATE(@FileDate) = 1 
		BEGIN 		 

			-----------------------------------------------------------
			-- DEBUG CODE	
			--print '---------------------------------------------------------'
			--Print 'Checking File ' + @filename + ' with file date of ' + @FileDate
			--print 'RetentionDate = ' + @RetentionDate 
  	--		print 'File DAte = ' + @FileDate 
  	--		print 'Condition is FIle Date < Retention date'
  			-- [SQLMantainence].[sp_DeleteAdhocBackupFilesAFterRetentionPeriod]
			---------------------------------------------
		
			IF CAST(@FileDate AS DATE) < CAST(@RetentionDate AS DATE)  
			BEGIN 
				PRINT 'DELETED yearly Backup file i.e. "' + @filename + '"' 
				SET @inpath = 'del  /Q "' + @filename + '"' 
				
				Execute xp_cmdshell @inPath , no_output   
				INSERT INTO SQL_ADMIN.SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'CLEANUP-ACTIVITY','Deleted yearly backup File "' + @filename + '"','I'); 
			END 
		END 
	 
		SET @j=@j+1; 
END 
 
 
DROP TABLE  #DirFileSourceInfo2 
DROP TABLE  #DirFileSource2 
DROP TABLE #FilesSource2  
 
END  -- END OF IF FOR YEARLY BACKUP FOLDER CHECK 

END  -- END OF PROCEDURE
GO


USE [SQL_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [SQLMantainence].[sp_DeleteTableBackupsAFterRetentionPeriod]
AS
BEGIN
	SET NOCOUNT ON 
	DECLARE @TABLENAME VARCHAR(1000)
	DECLARE @RetentionDate varchar(100)

	DECLARE  curTablesToBeDeleted CURSOR
	FOR
	SELECT TABLE_NAME FROM SQL_ADMIN.INFORMATION_SCHEMA.TABLES 
	WHERE TABLE_SCHEMA = 'TOBEDELETED' 


	OPEN curTablesToBeDeleted

	FETCH NEXT FROM curTablesToBeDeleted INTO @TABLENAME
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF CHARINDEX('@',REVERSE(@TABLENAME)) > 0 
			SELECT @RetentionDate =  RIGHT(@TABLENAME,(CHARINDEX('@',REVERSE(@TABLENAME),1)-1))
		ELSE
			SELECT @RetentionDate =  ''

		IF ISDATE(@RetentionDate) = 1
		BEGIN
			IF CAST(@RetentionDate AS DATE) < CAST(GETDATE() AS DATE)
			BEGIN
				PRINT 'DELETE TABLE' + @TABLENAME

				EXECUTE ('DROP TABLE TOBEDELETED.' + @TABLENAME)
				INSERT INTO SQLMANTAINENCE.DBMANTAINENCELOG VALUES (GETDATE(),'CLEANUP-ACTIVITY','DROPPED TABLE SQL_ADMIN.TOBEDELETED.' + @TABLENAME,'I');
			END
		END

		FETCH NEXT FROM curTablesToBeDeleted INTO @TABLENAME
	END
	CLOSE curTablesToBeDeleted
	DEALLOCATE curTablesToBeDeleted
END
GO


-- CREATING PS script for copying backups to S3 bucket FILE C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1
Execute master..xp_cmdshell 'MKDIR C:\DBA'
Execute master..xp_cmdshell 'MKDIR C:\DBA\CopyBackupToS3'
Execute master..xp_cmdshell 'DEL C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1'
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Staff Name: Turan Asikoglu / Suji Nair > C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Purpose: Sending MSSQL Backups to the Cloud or to another location. >> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Syntax: CopyBackupToS3.ps1 "{BackupType}" "{Local Backup Folder}" "{PWD for S3 bucket}" >> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.  >> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT

EXECUTE Master.dbo.xp_CmdShell 'ECHO $ErrorActionPreference = "Stop">> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # S3 vars>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO ################################################## >> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # >> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $backuptype = $Args[0]  >> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $backupDir = $Args[1]  >> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $pwd = $Args[2] >> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # >> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO ################################################## >> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO import-module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1">> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $awskey = "AKIAJBK5IBK4UX2BUQOA" # Add AWS key>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $awssecret = $pwd # Add AWS secret>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $s3bucket = "cex-backups" # Add bucket name>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # MSSQL SMO vars>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO [System.Reflection.Assembly]::LoadWithPartialName(''Microsoft.SqlServer.SMO'') ^| out-null>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $sqlSvr = New-Object (''Microsoft.SqlServer.Management.Smo.Server'') "." >> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO #$backupDir =  "D:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Backup" #$sqlSvr.Settings.BackupDirectory # Retrieve backup directory using SQLSMO>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $mssqldbs = @("DIFF","FULL","Monthly","TLOG","Yearly","SSAS") # Databases we want to backup>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO Set-DefaultAWSRegion -Region eu-west-1>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Misc vars>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $hostname = $env:COMPUTERNAME>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO #$backuptype = "mssql">> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $backupfilelst = @()>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # 1. Test we got the location of the backups>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # 2. Lets get a file list from S3>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # 3. Compare the S3 and backup directory file listing for differences>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # 4. Upload what isn''t present in S3>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Test backup directory>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO If ($backupDir -eq $null)>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO {>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO     Write-Host "SMO Backup Directory is empty or you do not have SQL Credentials.">> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO ^ ^ ^ ^ Exit^ ^6>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO ^}>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Get S3 file list>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $targetfilelst = get-s3object -BucketName $s3bucket -AccessKey $awskey -SecretKey $awssecret -Key $hostname\$backuptype\ ^| Select-Object ^@{Expression={Split-Path $_.Key -Leaf^};Label="Key"^}>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Get a list of files in the backup directories>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO foreach ($dir in $mssqldbs)>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO {>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO 	$backupfilelst += Get-Childitem "$backupDir\$dir" ^| Where-Object {$_.extension -ne ''.trn''^} ^| select-object Name, FullName, Length ,^@{Expression={$dir^};Label="DB"^}>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO ^}>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Do the comparison between the two lists. Output whats missing in S3.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $fileuploadlst = Compare-Object -ReferenceObject $targetfilelst.Key -DifferenceObject $backupfilelst.Name ^| Where-Object {$_.SideIndicator -eq ''^=^>''^} ^| Select-Object InputObject>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Print to console what we are uploading>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO Write-Host "Information - Uploading the following files:" $fileuploadlst.InputObject>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # For each file thats about to be uploaded, lookup it''s full path for uploading.>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Then upload to S3>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO foreach ($filename in $fileuploadlst.InputObject)>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO {>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO 	$idx = [array]::IndexOf($backupfilelst.Name, $filename)>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO 	Write-S3Object -BucketName $s3bucket -AccessKey $awskey -SecretKey $awssecret -File $backupfilelst[$idx].FullName -Key "$hostname\$backuptype\$($backupfilelst[$idx].DB)\$($backupfilelst[$idx].Name)">> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO ^}>> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT


EXECUTE Master.dbo.xp_CmdShell 'ECHO # END OF SCRIPT # >> C:\DBA\CopyBackupToS3\CopyBackupToS3.ps1', NO_OUTPUT

---- END of Copy script for S3

---- start of copy script for SAN
-- CREATING PS script for copying backups to SAN folder = C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1
Execute master..xp_cmdshell 'MKDIR C:\DBA\CopyBackupToSAN'
Execute master..xp_cmdshell 'DEL C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1'
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Staff Name: Turan Asikoglu / Suji Nair > C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT

EXECUTE Master.dbo.xp_CmdShell 'ECHO # Purpose: Sending MSSQL Backups to the SAN folder >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Syntax: CopyBackupToSAN.ps1 "^{^$sourcePath^}" "^{^$targetPath^}" "^$username" "^$password" >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Example: CopyBackupToSAN.ps1 "D:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\Backups\FULL" "INSUPDB01\mssql\FULL" "SAN UserName" "SAN Password" >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $ErrorActionPreference = "Stop" >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.  >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO # Run Time vars >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO ##################################################   >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $sourcePath = $Args[0] >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $targetPath = $Args[1]   >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $username  = $Args[2] >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $password = $Args[3] >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO ##################################################   >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.  >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO $destinationPath = "\\uksupsan01.cexuk.local\Backup_Pool\" + $targetPath >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO.  >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO net use $destinationPath /user:$username $password >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO Robocopy.exe $sourcePath $destinationPath *.bak /S /Z /NP  >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT
EXECUTE Master.dbo.xp_CmdShell 'ECHO net use $destinationPath /del >> C:\DBA\CopyBackupToSAN\CopyBackupToSAN.ps1', NO_OUTPUT

-- end of copy scripot for SAN

-----------------------------
--- END OF DEPLOYMENT SCRIPTS
-----------------------------
