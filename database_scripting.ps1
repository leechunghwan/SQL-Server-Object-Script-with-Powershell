<#
This simple PowerShell routine scripts out all the user-defined functions,
stored procedures, tables and views in all the databases on the server that
you specify, to the path that you specify.
SMO must be installed on the machine (it happens if SSMS is installed)
To run – set the servername and path
Open a command window and run powershell
Copy the below into the window and press enter – it should run
It will create the subfolders for the databases and objects if necessary.
#>

$path       = "C:\DEV\DB_SHEMA\DB_SHEMA\output\"
$ServerName = "."

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
$serverInstance = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName

$serverInstance.ConnectionContext.LoginSecure =$true;
#$serverInstance.ConnectionContext.LoginSecure=$false;
#$serverInstance.ConnectionContext.set_Login("");
#$serverInstance.ConnectionContext.set_Password("")

$IncludeTypes   = @("tables","StoredProcedures","Views","UserDefinedTypes","UserDefinedFunctions")
$ExcludeSchemas = @("sys","Information_Schema")
Test-Path C:\DEV\DB_SHEMA\DB_SHEMA\output\\* -exclude *master*,*msdb*,*tempdb*,*model*

$so = new-object ('Microsoft.SqlServer.Management.Smo.ScriptingOptions')

$so.AllowSystemObjects                    = 0
$so.AnsiPadding                           = 0
$so.Bindings                              = 1
$so.ClusteredIndexes                      = 1
$so.ContinueScriptingOnError              = 1
$so.ConvertUserDefinedDataTypesToBaseType = 0
$so.DdlBodyOnly                           = 0
$so.Default                               = 1
$so.DriAll                                = 1
$so.DriAllConstraints                     = 1
$so.DriAllKeys                            = 1
$so.DriChecks                             = 1
$so.DriClustered                          = 1
$so.DriDefaults                           = 1
$so.DriForeignKeys                        = 1
$so.DriIndexes                            = 1
$so.DriNonClustered                       = 1
$so.DriPrimaryKey                         = 1
$so.DriUniqueKeys                         = 1
$so.DriWithNoCheck                        = 1
$so.EnforceScriptingOptions               = 1
$so.ExtendedProperties                    = 1
$so.FullTextCatalogs                      = 1
$so.FullTextIndexes                       = 1
$so.FullTextStopLists                     = 1
$so.IncludeDatabaseContext                = 0
$so.IncludeDatabaseRoleMemberships        = 1
$so.IncludeHeaders                        = 0
$so.IncludeIfNotExists                    = 0
$so.Indexes                               = 1
$so.NoCommandTerminator                   = 0
$so.NoFileGroup                           = 0
$so.NoViewColumns                         = 1
$so.NonClusteredIndexes                   = 1
$so.SchemaQualify                         = 0
$so.SchemaQualifyForeignKeysReferences    = 1
$so.ScriptBatchTerminator                 = 1
$so.ScriptData                            = 0
$so.ScriptDrops                           = 0
$so.ScriptOwner                           = 0
$so.ToFileOnly                            = 1
$so.Triggers                              = 1

$dbs=$serverInstance.Databases

# DATABASE
foreach ($db in $dbs)
{
	$dbname = "$db".replace("[","").replace("]","")
	$dbpath = "$path"+"$dbname" + "\"
	if ($dbname -notin "AdventureWorks2014", "AdventureWorksDW2014" )
	{
		continue
	}

	if ( !(Test-Path $dbpath))
	{
		$null=new-item -type directory -name "$dbname"-path "$path"
	}

	# Object type
	foreach ($Type in $IncludeTypes)
	{
		$objpath = "$dbpath" + "$Type" + "\"
		if ( !(Test-Path $objpath))
		{
			$null=new-item -type directory -name "$Type"-path "$dbpath"
		}

		# Object
		foreach ($objs in $db.$Type)
		{
			If ($ExcludeSchemas -notcontains $objs.Schema )
			{
				$ObjName = "$objs".replace("[","").replace("]","")
				$OutFile = "$objpath" + "$ObjName" + ".sql"
				$TempFile = "$objpath" + ".TMP"
				$objs.Script($so)+"GO" | out-File $OutFile
				if ($Type -in "StoredProcedures", "UserDefinedFunctions", "tables", "Views")
				{
					$org = (Get-Content $OutFile)
					$so.Permissions = 1
					$so.AppendToFile = 1
					$so.NoCommandTerminator = 0
					$so.ScriptBatchTerminator = 1
					$objs.Script($so) | out-File $TempFile
					$addpermission = (Get-Content $TempFile)
					Compare-Object $addpermission $org -property $_.InputObject -passThru | Where-Object { $_.SideIndicator -eq '<=' } | out-File $OutFile -Append
					$so.Permissions = 0
					$so.AppendToFile = 0
					$so.NoCommandTerminator = 1
					$so.ScriptBatchTerminator = 0
					remove-item $TempFile
				}
			}
		}
	}
}
