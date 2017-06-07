[CmdletBinding()]
param()

Function _ApplyTransform
{
    param(
        [string] $SourceFile,
        [string] $TransformFile,
        [string] $OutputFile
    )

    # validate inputs
    if (!(Test-Path $SourceFile))
    {
        Write-Error "File '${SourceFile}' not found."
        
        return
    }

    if (!(Test-Path $TransformFile))
    {
        Write-Error "File '${TransformFile}' not found."
        
        return
    }

    # apply transformations
    Write-Host "Applying transformations '${TransformFile}' on file '${SourceFile}'..."
    
    $source = New-Object Microsoft.Web.XmlTransform.XmlTransformableDocument
    $source.PreserveWhitespace = $true
    $source.Load($SourceFile)

    $transform = [System.IO.File]::ReadAllText($TransformFile)
    $transformation = New-Object Microsoft.Web.XmlTransform.XmlTransformation $transform, $false, $null
    if (!$transformation.Apply($source))
    {
        Write-Error "Error while applying transformations '${TransformFile}'."

        return
    }

    # save output
    $outputParent = Split-Path $OutputFile -Parent
    if (!(Test-Path $outputParent))
    {
        Write-Verbose "Creating folder '${outputParent}'."

        New-Item -Path $outputParent -ItemType Directory -Force > $null
    }

    $source.Save($OutputFile)
}

Trace-VstsEnteringInvocation $MyInvocation
try
{
    # get inputs
    [string] $workingFolder = Get-VstsInput -Name 'workingFolder'
    [string] $transforms = Get-VstsInput -Name 'transforms' -Require

    if (!$workingFolder)
    {
        $workingFolder = $env:SYSTEM_DEFAULTWORKINGDIRECTORY
    }

    $workingFolder = $workingFolder.Trim()

    # import assemblies
    Add-Type -Path "${PSScriptRoot}\Microsoft.Web.XmlTransform.dll"

    # apply transforms
    $transforms -split " *(?:`n`r?)|, *" | % {
        $rule = $_
        if (!$rule)
        {
            Write-Warning "Found empty rule."

            return
        }

        $ruleParts = $rule -split " *=> *"
        if ($ruleParts.Length -lt 2)
        {
            Write-Error "Invalid rule '${rule}'."

            return
        }

        $transformFile = $ruleParts[0].Trim()
        if (![System.IO.Path]::IsPathRooted($transformFile))
        {
            $transformFile = Join-Path $workingFolder $transformFile
        }

        $sourceFile = $ruleParts[1].Trim()
        if (![System.IO.Path]::IsPathRooted($sourceFile))
        {
            $sourceFile = Join-Path $workingFolder $sourceFile
        }

        $outputFile = $sourceFile
        if ($ruleParts.Length -eq 3)
        {
            $outputFile = $ruleParts[2].Trim()
            if (![System.IO.Path]::IsPathRooted($outputFile))
            {
                $outputFile = Join-Path $workingFolder $outputFile
            }
        }

        _ApplyTransform -SourceFile $sourceFile -TransformFile $transformFile -OutputFile $outputFile
    }
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}