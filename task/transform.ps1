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

    if (Test-Path $TransformFile -PathType Leaf)
    {
        # apply transformations
        Write-Host "Applying transformations '${TransformFile}' on '${SourceFile}' to '${OutputFile}'..."
        
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
    else 
    {
        Write-Host "File '${TransformFile}' not found. Skipping Transform."
    }
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
    $transformsCount = 0

    $transforms -split "(?:`n`r?)|," | ForEach-Object {
        $rule = $_.Trim()

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

        $defs = [PSCustomObject]@{
            IsTransformWildcard = $false
            IsTransformRelative = $false
            TransformPattern = $ruleParts[0].Trim()
            IsSourceRelative = $false
            SourcePattern = $ruleParts[1].Trim()
            IsOutputRelative = $false
            OutputPattern = $null
        }

        if ($defs.TransformPattern.StartsWith('*'))
        {
            $defs.IsTransformWildcard = $true
            $defs.IsTransformRelative = $true
            $defs.TransformPattern = $defs.TransformPattern.Substring(1)
        }
        else
        {
            $defs.IsTransformRelative = ![System.IO.Path]::IsPathRooted($defs.TransformPattern)
            if ($defs.IsTransformRelative)
            {
                $defs.TransformPattern = Join-Path $workingFolder $defs.TransformPattern
            }
        }

        $defs.IsSourceRelative = ![System.IO.Path]::IsPathRooted($defs.SourcePattern)
        if ($defs.IsSourceRelative -and !$defs.IsTransformWildcard)
        {
            $defs.SourcePattern = Join-Path $workingFolder $defs.SourcePattern
        }

        $defs.IsOutputRelative = $defs.IsSourceRelative
        $defs.OutputPattern = $defs.SourcePattern

        if ($ruleParts.Length -eq 3)
        {
            $defs.OutputPattern = $ruleParts[2].Trim()
            $defs.IsOutputRelative = ![System.IO.Path]::IsPathRooted($defs.OutputPattern)

            if ($defs.IsOutputRelative -and !$defs.IsTransformWildcard)
            {
                $defs.OutputPattern = Join-Path $workingFolder $defs.OutputPattern
            }
        }

        if ($defs.IsTransformWildcard)
        {
            Get-ChildItem -Path $workingFolder -Filter "*$($defs.TransformPattern)" -Recurse | % {
                $transformFile = $_
                $token = $transformFile.Name.Substring(0, $transformFile.Name.Length - $defs.TransformPattern.Length)

                $sourceFile = $defs.SourcePattern.Replace('*', $token)
                if ($defs.IsSourceRelative)
                {
                    $sourceFile = Join-Path $transformFile.DirectoryName $sourceFile
                }

                $outputFile = $defs.OutputPattern.Replace('*', $token)
                if ($defs.IsOutputRelative)
                {
                    $outputFile = Join-Path $transformFile.DirectoryName $outputFile
                }

                _ApplyTransform -TransformFile $transformFile.FullName -SourceFile $sourceFile -OutputFile $outputFile
                ++$transformsCount
            }
        }
        else
        {
            _ApplyTransform -SourceFile $defs.SourcePattern -TransformFile $defs.TransformPattern -OutputFile $defs.OutputPattern
            ++$transformsCount
        }
    }

    Write-Host "transformed ${transformsCount} file(s)."
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}