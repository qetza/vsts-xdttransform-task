[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation
try
{
    # get inputs
    [string] $sourceFile = Get-VstsInput -Name 'sourceFile' -Require
    [string] $transformFile = Get-VstsInput -Name 'transformFile' -Require
    [string] $outputFile = Get-VstsInput -Name 'outputFile' -Default ''

    if (!$outputFile)
    {
        $outputFile = $sourceFile
    }

    if (![System.IO.Path]::IsPathRooted($outputFile))
    {
        $outputFile = Join-Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY $outputFile
    }

    # validate inputs
    if (!(Test-Path $sourceFile))
    {
        Write-Error "File '${sourceFile}' not found."
        
        return
    }

    if (!(Test-Path $transformFile))
    {
        Write-Error "File '${transformFile}' not found."
        
        return
    }

    # import assemblies
    Add-Type -Path "${PSScriptRoot}\Microsoft.Web.XmlTransform.dll"

    # apply transformations
    Write-Host "Applying transformations '${transformFile}' on file '${sourceFile}'..."
    
    $source = New-Object Microsoft.Web.XmlTransform.XmlTransformableDocument
    $source.PreserveWhitespace = $true
    $source.Load($sourceFile)

    # apply transformations
    $transform = [System.IO.File]::ReadAllText($transformFile)
    $transformation = New-Object Microsoft.Web.XmlTransform.XmlTransformation $transform, $false, $null
    if (!$transformation.Apply($source))
    {
        Write-Error "Error while applying transformations '${transformFile}'."

        return
    }

    # save output
    $outputParent = Split-Path $outputFile -Parent
    if (!(Test-Path $outputParent))
    {
        Write-Verbose "Creating folder '${outputParent}'."

        New-Item -Path $outputParent -ItemType Directory -Force > $null
    }

    $source.Save($outputFile)
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}