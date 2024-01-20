Param( `
    [parameter(Mandatory=$true, HelpMessage="Database")] $Database, `
    [parameter(Mandatory=$true, HelpMessage="Environment")] $Environment, `
    [parameter(Mandatory=$true, HelpMessage="ServerName")] $ServerName, `
    [parameter(Mandatory=$true, HelpMessage="DatabaseName")] $DatabaseName
);

$rootPath = (Split-Path $MyInvocation.MyCommand.Path -Parent) + "\$Database";

function DeployScript([String] $path)
{
    Write-Host "$path";
    try
    {
        Invoke-Sqlcmd `
            -InputFile $path `
            -ServerInstance $ServerName `
            -Database $DatabaseName `
            -ErrorAction Stop;
    }
    catch
    {
        Write-Host("Error:{0},File:{1},Line:{2},Message:{3}" -f `
            $_.Exception.InnerException.Number, `
            $path, `
            $_.Exception.InnerException.LineNumber, `
            $_.Exception.InnerException.Message) `
            -ForegroundColor Red
        Exit 1;
    }
}

function DeployFolder([String] $schemaPath, [String] $folderName)
{
    Write-Host "Folder: $schemaPath\$folderName";
    Get-ChildItem "$schemaPath\$folderName" -Filter "*.sql" -Recurse `
        | Foreach-Object { DeployScript $_.FullName };
}

Get-ChildItem $rootPath -Filter "_*.sql" -Recurse `
    | Foreach-Object { DeployScript $_.FullName };

Get-ChildItem $rootPath -Directory `
    | Foreach-Object { DeployFolder $_.FullName "table" };

Get-ChildItem $rootPath -Directory `
    | Foreach-Object { DeployFolder $_.FullName "data" };

Get-ChildItem $rootPath -Directory `
    | Foreach-Object { DeployFolder $_.FullName "procedure" };

If ($Environment -in "dev", "test")
{
    Get-ChildItem $rootPath -Directory `
        | Foreach-Object { DeployFolder $_.FullName "test" };
}
