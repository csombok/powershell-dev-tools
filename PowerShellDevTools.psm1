function Get-Parent
{
    param
    (
        [ValidateScript({ (Test-Path -Path $_ -PathType Leaf) })]
        [string] $FilePath,
        [ValidateSet('sln', 'csproj')]
        [string] $Extension
    )
    
    $fileName = Get-ChildItem -Path $FilePath | Select -ExpandProperty Name
    $targetFolder = Split-Path -Path $FilePath
    $folderPath = $targetFolder
    while(-not [string]::IsNullOrWhiteSpace($folderPath) -and (Test-Path -Path $folderPath -PathType Container))
    {
        $cotainers = Get-ChildItem -Path $folderPath -Filter "*.$Extension"
        $cotainers | ForEach-Object {
            $content = Get-Content -Path $_.FullName
            if(($content | Select-String -Pattern $fileName | Measure-Object).Count -gt 0)
            {
                return $_.FullName
            }
        }

        $folderPath = Split-Path $folderPath -ErrorAction SilentlyContinue        
    }
}

function Get-MatchingSources
{
    param
    (         
         [string] $Path = (Get-Location).Path,
         [array] $Patterns,
         [array] $Extension = ('*.cs', '*.h', '*.cpp')
    )

    $files = Get-ChildItem -Path $Path -Include $Extension -Recurse -File
    $files | ForEach-Object {
        $filePath = $_.FullName
        $content = Get-Content -Path $filePath

        $mismatch = $Patterns | 
            Where-Object {
                ($content | Select-String -Pattern $_ | Measure-Object).Count -eq 0
            } |
            Measure-Object |
            Select-Object -ExpandProperty Count
            

        if($mismatch -eq 0)
        {   
            $project = Get-Parent -FilePath $filePath -Extension csproj
            $solutions = if([string]::IsNullOrEmpty($project)) { '' } else { (Get-Parent -FilePath $project -Extension sln)}
                                   
            New-Object PSObject -Property @{ 
                    File = $_.Name; 
                    Path = $filePath; 
                    Project = $project;
                    Solutions = $solutions -join '; '
                }                        
        }
    }    
}

function Get-NugetPackageInformation
{
    param
    (
        [string] $Path = (Get-Location).Path,
        [string] $Id,
        [string] $Version        
    )

   $packagesFiles = Get-ChildItem -Path $Path -Filter 'packages.config' -Recurse

   $matches = $packagesFiles | ForEach-Object {
        $fileName = $_.FullName
        $doc = [xml](Get-Content -Path $fileName)
        $doc.packages.package | 
        Where-Object { $Id -eq $null -or $_.id -like "*$Id*"} |
        Where-Object { $Version -eq $null -or $_.version -like "*$Version*"} |        
        Select-Object id, version, targetFramework, @{Label="File"; Expression={$fileName}}
   }

   $matches | Sort-Object -Unique -Property id, version
}

function Get-PackageInformation
{
    param
    (        
        [ValidateScript({Test-Path $_ -PathType Container})]
        $Path = (Get-Location).Path,
        $Dependency        
    )

    $packages = @{}

    $projectJsonFiles = Get-ChildItem -Path $Path -Filter 'project.json' -Recurse
    $projectJsonFiles | ForEach-Object {  
              
        $filePath = $_.FullName        

        try
        {
            $projectJSON = (Get-Content -Path $filePath) | Out-String | ConvertFrom-Json

            $matchingDependencies = $projectJSON.dependencies.psobject.Properties | Where-Object {
                    return [string]::IsNullOrEmpty($Dependency) -or $_.Name -like $Dependency
            }
            
            if($matchingDependencies.Count -gt 0) {
                Write-Host $filePath -ForegroundColor Cyan
                $matchingDependencies | foreach {                    
                    if($packages.ContainsKey($_.Name)) {
                        $expectedVersion = $packages.Get_Item($_.Name)
                        if($expectedVersion -ne $_.Value) {
                            Write-Host "--> $($_.Name) - $($_.Value) (version mismatch, expected: $expectedVersion)" -ForegroundColor Red
                        }
                        else {
                            Write-Host "--> $($_.Name) - $($_.Value)" -ForegroundColor Yellow
                        }
                    }
                    else {
                        Write-Host "--> $($_.Name) - $($_.Value)" -ForegroundColor Yellow
                        $packages.Add($_.Name, $_.Value)
                    }
                }
            }      
        }
        catch 
        {
            Write-Host "Invalid JSON file: $filePath" -ForegroundColor Red  
        }  
    }                
}


function Compare-DirectoryAssembly
{
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_ -PathType Container})]
        $SourceDirectory,
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_ -PathType Container})]
        $DestinationDirectory,
        $Filter,
        [switch]
        $CompareVersion,
        [switch]
        $IncludeEqual
    )

    $sourceAssemblies = Get-ChildItem -Path "$SourceDirectory*" -Recurse  -Filter "*$Filter*.dll"  | Select Name, @{Label="FileVersion"; Expression={[System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName).FileVersion}} -Unique
    $destinationAssemblies = Get-ChildItem -Path "$DestinationDirectory*" -Recurse -Filter "*$Filter*.dll" | Select Name, @{Label="FileVersion"; Expression={[System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName).FileVersion}} -Unique

    if($sourceAssemblies -eq $null) { $sourceAssemblies = @() }
    if($destinationAssemblies -eq $null) { $destinationAssemblies = @() }

    $compareProperties = @('Name')
    if($CompareVersion.IsPresent) {$compareProperties+='FileVersion'}

    Compare-Object -ReferenceObject $sourceAssemblies -DifferenceObject $destinationAssemblies -IncludeEqual:($IncludeEqual.IsPresent) -Property $compareProperties
}

function Compare-Npm
{
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        $SourceNpm,
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        $DestinationNpm,
        $Filter,
        [switch]
        $IncludeEqual,
        [switch]
        $IncludeDevDeps,
        [switch]
        $ShowMismatchOnly

    )

    $sourcePackages = Get-Content -Path $SourceNpm | ConvertFrom-Json

    $destinationPackages = Get-Content -Path $DestinationNpm | ConvertFrom-Json

    $result = @()

    if($sourcePackages.dependencies) {
        $sourcePackages.dependencies.PSObject.Properties | foreach {
            $packageItem = New-Object PSObject -Property @{            
                Name       = $_.Name
                Type       = 'dependencies'     
                SourceVersion = $_.Value
                DestinationVersion  = $null }

            $result += $packageItem
        }   
    }

    if($sourcePackages.devDependencies) {
        $sourcePackages.dependencies.PSObject.Properties | foreach {
            $packageItem = New-Object PSObject -Property @{            
                Name       = $_.Name
                Type       = 'devDependencies'     
                SourceVersion = $_.Value
                DestinationVersion  = $null }

            $result += $packageItem
        }   
    }
    

    if($destinationPackages.dependencies) {
        $destinationPackages.dependencies.PSObject.Properties | foreach {
            $dependency = $_
        
            $existing = $result | Where-Object {$_.Name -eq $dependency.Name -and $_.Type -eq 'dependencies'} | Select -First 1

            if($existing) {
                $existing.DestinationVersion = $dependency.Value
            } else {        
                $packageItem = New-Object PSObject -Property @{            
                    Name       = $_.Name
                    Type       = 'dependencies'     
                    SourceVersion = $null
                    DestinationVersion  = $dependency.Value }

                $result += $packageItem
            }
        }   
    }

        if($destinationPackages.devDependencies) {
        $destinationPackages.devDependencies.PSObject.Properties | foreach {
            $dependency = $_
        
            $existing = $result | Where-Object {$_.Name -eq $dependency.Name -and $_.Type -eq 'devDependencies'} | Select -First 1

            if($existing) {
                $existing.DestinationVersion = $dependency.Value
            } else {        
                $packageItem = New-Object PSObject -Property @{            
                    Name       = $_.Name
                    Type       = 'devDependencies'     
                    SourceVersion = $null
                    DestinationVersion  = $dependency.Value }

                $result += $packageItem
            }
        }   
    }

    if(-not [string]::IsNullOrWhiteSpace($Filter)) {
        $result = $result | Where-Object { $_.Name -like "*$Filter*" }
    }

    if($ShowMismatchOnly.IsPresent) {
        $result = $result | Where-Object { (-not [string]::IsNullOrWhiteSpace($_.SourceVersion)) -and  (-not [string]::IsNullOrWhiteSpace($_.DestinationVersion))  }
    }

    if($IncludeEqual.IsPresent -and $IncludeDevDeps.IsPresent) {
        $result | ft Name, Type, SourceVersion, DestinationVersion
    } elseif($IncludeEqual.IsPresent -and -not $IncludeDevDeps.IsPresent) {
        $result | Where-Object {$_.Type -eq 'dependencies'} | ft Name, Type, SourceVersion, DestinationVersion
    } elseif(-not $IncludeEqual.IsPresent -and $IncludeDevDeps.IsPresent) {
        $result | Where-Object {$_.SourceVersion -ne $_.DestinationVersion} | ft Name, Type, SourceVersion, DestinationVersion
    } elseif(-not $IncludeEqual.IsPresent -and -not $IncludeDevDeps.IsPresent) { 
        $result | Where-Object {$_.SourceVersion -ne $_.DestinationVersion -and $_.Type -eq 'dependencies'} | ft Name, Type, SourceVersion, DestinationVersion
    }

    
}


Set-Alias -Name matchSources -Value Get-MatchingSources
Set-Alias -Name listNuget -Value Get-NugetPackageInformation
Set-Alias -Name listPackages -Value Get-PackageInformation
Set-Alias -Name dllCompare -Value Compare-DirectoryAssembly
Set-Alias -Name npmCompare -Value Compare-Npm


Export-ModuleMember -Function * -Alias *

