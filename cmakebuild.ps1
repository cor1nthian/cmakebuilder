<#  .SYNOPSIS
    Builds and creates CMake-based projects

    .DESCRIPTION
    IMPORTANT NOTICE
    Psths to objects must be ascii-correct (latin symbols are a safe choice)

    Builds and creates CMake-based projects for specified platforms.
    Intended to create (at least) projects for Win64 and Win32 platforms and being run manually.
    Script creates and launches temporary bat file for CMake operations.
    Creates a folder at source directory, placing there created and built projects.
    Designed and tested for Windows with Visual Studio 2022 build tools.
    Minimum supported Powershell version - 4.
    Special thanks to Stackoverflow community, especially sakra

    .INPUTS
    Mandatory - project path and build tool name

    .OUTPUTS
    No outputs on success; error comment on failure

    .PARAMETER SourceDir
    Mandatorry. Path to project

    .PARAMETER BuildTool
    Mandatorry. Build tool name

    .PARAMETER BuildDir
    Optional. Default - "proj_build". Directory name for created projects. Created projects will reside within this folder,
    each in separate folder per platform/build tool. Script creates thia directory in case its missing

    .PARAMETER CMakeListsFName
    Optional. Default - "CMakeLists.txt". CMake lists file name.

    .PARAMETER CMakeEXEPath
    Optional. Default - "$env:PROGRAMFILES\CMake\bin\cmake.exe". CNake executable path

    .PARAMETER CMDEXEPath
    Optional. Default - "$env:SystemRoot\System32\cmd.exe". Path to cmd.exe

    .PARAMETER TargetBuilds
    Optional. Default - @{ 'Win32' = "build32"; 'x64' = "build64" }. Hashtable, describing used build tools (keya) and platform
    folder names (values). Intebded to be used with CMake 3.13+

    .PARAMETER TargetBuildsPre313
    Optional. Default - @{ 'Win32' = ""; 'x64' = "Win64" }. Parallel with TargetBuilds hashtable, describing used build tools
    for pre-3.13 CMake. For pre-3.13 CMake, build tool must be specified in one string with generator

    .PARAMETER TargetConfigs
    Optional. Default - @( "Debug", "Release" ). Target project configurations

    .PARAMETER BridgeCMakeVersion
    Optional. Default - "3.13". Version that requires build process change

    .PARAMETER BlockSplitter
    Optional. Default - "Generators". Generator liat seoarator mark

    .PARAMETER SplitStr
    Optional. Default - "=". Generator names separator mark

    .PARAMETER OperatorMark
    Optional. Default - "The following generators are available on this platform (* marks default):".
    Generator list filter mark
    
    .PARAMETER ValMark
    Optional. Default - "Supply values for the following parameters:". Generator list filter mark

    .PARAMETER ArchMark
    Optional. Default - "Use -A option to specify architecture". Generator list filter mark

    .PARAMETER PlatformMark
    Optional. Default - "Optional". Generator list filter mark

    .PARAMETER DeprecationMark
    Optional. Default - "(deprecated).". Generator list filter mark

    .PARAMETER ExperimentMark
    Optional. Default - "experimental". Generator list filter mark

    .PARAMETER Win64Mark
    Optional. Default - "Win64". Generator list filter mark

    .PARAMETER MingwMark
    Optional. Default - "mingw32-make.". Generator list filter mark

    .PARAMETER BATFName
    Optional. Default - "temp.bat". Temporary bat file name

    .EXAMPLE
    cmakebuild.ps1 -SourceDir "C:\source" -BuildTool "Visual Studio 17 2022"

    .EXAMPLE
    cmakebuild.ps1 -SourceDir "C:\source" -BuildTool "Visual Studio 12 2013" -BuildDir "build" #>

Param ( [Parameter(Position = 0, Mandatory = $true)]   [System.String]   $SourceDir,
        [Parameter(Position = 1, Mandatory = $true)]   [System.String]   $BuildTool,
        [Parameter(Position = 2, Mandatory = $false)]  [System.String]   $BuildDir = "proj_build",
        [Parameter(Position = 3, Mandatory = $false)]  [System.String]   $CMakeListsFName = "CMakeLists.txt",
        [Parameter(Position = 4, Mandatory = $false)]  [System.String]   $CMakeEXEPath = "$env:PROGRAMFILES\CMake\bin\cmake.exe",
        [Parameter(Position = 5, Mandatory = $false)]  [System.String]   $CMDEXEPath = "$env:SystemRoot\System32\cmd.exe",
        [Parameter(Position = 6, Mandatory = $false)]  [System.Collections.Hashtable] $TargetBuilds = @{ 'Win32' = "build32"; 'x64' = "build64" },
        [Parameter(Position = 7, Mandatory = $false)]  [System.Collections.Hashtable] $TargetBuildsPre313 = @{ 'Win32' = ""; 'x64' = "Win64" },
        [Parameter(Position = 8, Mandatory = $false)]  [System.String[]] $TargetConfigs = @( "Debug", "Release" ),
        [Parameter(Position = 9, Mandatory = $false)]  [System.String]   $BridgeCMakeVersion = "3.13",
        [Parameter(Position = 10, Mandatory = $false)] [System.String]   $BlockSplitter = "Generators",
        [Parameter(Position = 11, Mandatory = $false)] [System.String]   $SplitStr = "=",
        [Parameter(Position = 12, Mandatory = $false)] [System.String]   $OperatorMark = "The following generators are available on this platform (* marks default):",
        [Parameter(Position = 13, Mandatory = $false)] [System.String]   $ValMark = "Supply values for the following parameters:",
        [Parameter(Position = 14, Mandatory = $false)] [System.String]   $ArchMark = "Use -A option to specify architecture",
        [Parameter(Position = 15, Mandatory = $false)] [System.String]   $PlatformMark = "Optional",
        [Parameter(Position = 16, Mandatory = $false)] [System.String]   $DeprecationMark = "(deprecated).",
        [Parameter(Position = 17, Mandatory = $false)] [System.String]   $ExperimentMark = "experimental",
        [Parameter(Position = 18, Mandatory = $false)] [System.String]   $Win64Mark = "Win64",
        [Parameter(Position = 19, Mandatory = $false)] [System.String]   $MingwMark = "mingw32-make.",
        [Parameter(Position = 20, Mandatory = $false)] [System.String]   $BATFName = "temp.bat" )

# $ErrorActionPreference = 'Stop'
$ErrorActionPreference = 'SilentlyContinue'

[System.Int16]   $PSVERSIONMIN      = 4
[System.Version] $INCORRECTVERSION  = [System.Version] "999.999.999"
[System.String]  $SCRIPTPATH        = Split-Path $script:MyInvocation.MyCommand.Path
[System.String]  $FULLBUILDPATH     = "$SourceDir\$BuildDir"
[System.String]  $MSGCOLOR          = "Green"
[System.String]  $MSGERRORCOLOR     = "Red"

function RemoveFolderContent {

  Param ( [Parameter(Position = 0, Mandatory = $true)]  [System.String] $FolderPath )

  # Get-ChildItem -Path $FolderPath -Include * -Recurse | ForEach-Object { $_.Delete() }
  Remove-Item "$FolderPath\*" -Recurse -Force
}

function Remove-FileSystemItem {
    <#
    .SYNOPSIS
      Removes files or directories reliably and synchronously.
  
    .DESCRIPTION
      Removes files and directories, ensuring reliable and synchronous
      behavior across all supported platforms.
  
      The syntax is a subset of what Remove-Item supports; notably,
      -Include / -Exclude and -Force are NOT supported; -Force is implied.
      
      As with Remove-Item, passing -Recurse is required to avoid a prompt when 
      deleting a non-empty directory.
  
      IMPORTANT:
        * On Unix platforms, this function is merely a wrapper for Remove-Item, 
          where the latter works reliably and synchronously, but on Windows a 
          custom implementation must be used to ensure reliable and synchronous 
          behavior. See https://github.com/PowerShell/PowerShell/issues/8211
  
      * On Windows:
        * The *parent directory* of a directory being removed must be 
          *writable* for the synchronous custom implementation to work.
        * The custom implementation is also applied when deleting 
           directories on *network drives*.
  
      * If an indefinitely *locked* file or directory is encountered, removal is aborted.
        By contrast, files opened with FILE_SHARE_DELETE / 
        [System.IO.FileShare]::Delete on Windows do NOT prevent removal, 
        though they do live on under a temporary name in the parent directory 
        until the last handle to them is closed.
  
      * Hidden files and files with the read-only attribute:
        * These are *quietly removed*; in other words: this function invariably
          behaves like `Remove-Item -Force`.
        * Note, however, that in order to target hidden files / directories
          as *input*, you must specify them as a *literal* path, because they
          won't be found via a wildcard expression.
  
      * The reliable custom implementation on Windows comes at the cost of
        decreased performance.
  
    .EXAMPLE
      Remove-FileSystemItem C:\tmp -Recurse
  
      Synchronously removes directory C:\tmp and all its content.
    #>
      [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium', DefaultParameterSetName='Path', PositionalBinding=$false)]
      param(
        [Parameter(ParameterSetName='Path', Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [System.String[]] $Path,
        [Parameter(ParameterSetName='Literalpath', ValueFromPipelineByPropertyName)]
        [Alias('PSPath')]
        [System.String[]] $LiteralPath,
        [System.Management.Automation.SwitchParameter] $Recurse
      )
      begin {
        # !! Workaround for https://github.com/PowerShell/PowerShell/issues/1759
        if ($ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Ignore) { $ErrorActionPreference = 'Ignore'}
        $targetPath = ''
        $yesToAll = $noToAll = $false
        function trimTrailingPathSep([string] $itemPath) {
          if ($itemPath[-1] -in '\', '/') {
            # Trim the trailing separator, unless the path is a root path such as '/' or 'c:\'
            if ($itemPath.Length -gt 1 -and $itemPath -notmatch '^[^:\\/]+:.$') {
              $itemPath = $itemPath.Substring(0, $itemPath.Length - 1)
            }
          }
          $itemPath
        }
        function getTempPathOnSameVolume([string] $itemPath, [string] $tempDir) {
          if (-not $tempDir) { $tempDir = [IO.Path]::GetDirectoryName($itemPath) }
          [IO.Path]::Combine($tempDir, [IO.Path]::GetRandomFileName())
        }
        function syncRemoveFile([string] $filePath, [string] $tempDir) {
          # Clear the ReadOnly attribute, if present.
          if (($attribs = [IO.File]::GetAttributes($filePath)) -band [System.IO.FileAttributes]::ReadOnly) {
            [IO.File]::SetAttributes($filePath, $attribs -band -bnot [System.IO.FileAttributes]::ReadOnly)
          }
          $tempPath = getTempPathOnSameVolume $filePath $tempDir
          [IO.File]::Move($filePath, $tempPath)
          [IO.File]::Delete($tempPath)
        }
        function syncRemoveDir([string] $dirPath, [switch] $recursing) {
            if (-not $recursing) { $dirPathParent = [IO.Path]::GetDirectoryName($dirPath) }
            # Clear the ReadOnly attribute, if present.
            # Note: [IO.File]::*Attributes() is also used for *directories*; [IO.Directory] doesn't have attribute-related methods.
            if (($attribs = [IO.File]::GetAttributes($dirPath)) -band [System.IO.FileAttributes]::ReadOnly) {
              [IO.File]::SetAttributes($dirPath, $attribs -band -bnot [System.IO.FileAttributes]::ReadOnly)
            }
            # Remove all children synchronously.
            $isFirstChild = $true
            foreach ($item in [IO.directory]::EnumerateFileSystemEntries($dirPath)) {
              if (-not $recursing -and -not $Recurse -and $isFirstChild) { # If -Recurse wasn't specified, prompt for nonempty dirs.
                $isFirstChild = $false
                # Note: If -Confirm was also passed, this prompt is displayed *in addition*, after the standard $PSCmdlet.ShouldProcess() prompt.
                #       While Remove-Item also prompts twice in this scenario, it shows the has-children prompt *first*.
                if (-not $PSCmdlet.ShouldContinue("The item at '$dirPath' has children and the -Recurse switch was not specified. If you continue, all children will be removed with the item. Are you sure you want to continue?", 'Confirm', ([ref] $yesToAll), ([ref] $noToAll))) { return }
              }
              $itemPath = [IO.Path]::Combine($dirPath, $item)
              ([ref] $targetPath).Value = $itemPath
              if ([IO.Directory]::Exists($itemPath)) {
                syncremoveDir $itemPath -recursing
              } else {
                syncremoveFile $itemPath $dirPathParent
              }
            }
            # Finally, remove the directory itself synchronously.
            ([ref] $targetPath).Value = $dirPath
            $tempPath = getTempPathOnSameVolume $dirPath $dirPathParent
            [IO.Directory]::Move($dirPath, $tempPath)
            [IO.Directory]::Delete($tempPath)
        }
      }
  
      process {
        $isLiteral = $PSCmdlet.ParameterSetName -eq 'LiteralPath'
        if ($env:OS -ne 'Windows_NT') { # Unix: simply pass through to Remove-Item, which on Unix works reliably and synchronously
          Remove-Item @PSBoundParameters
        } else { # Windows: use synchronous custom implementation
          foreach ($rawPath in ($Path, $LiteralPath)[$isLiteral]) {
            # Resolve the paths to full, filesystem-native paths.
            try {
              # !! Convert-Path does find hidden items via *literal* paths, but not via *wildcards* - and it has no -Force switch (yet)
              # !! See https://github.com/PowerShell/PowerShell/issues/6501
              $resolvedPaths = if ($isLiteral) { Convert-Path -ErrorAction Stop -LiteralPath $rawPath } else { Convert-Path -ErrorAction Stop -path $rawPath}
            } catch {
              Write-Error $_ # relay error, but in the name of this function
              continue
            }
            try {
              $isDir = $false
              foreach ($resolvedPath in $resolvedPaths) {
                # -WhatIf and -Confirm support.
                if (-not $PSCmdlet.ShouldProcess($resolvedPath)) { continue }
                if ($isDir = [IO.Directory]::Exists($resolvedPath)) { # dir.
                  # !! A trailing '\' or '/' causes directory removal to fail ("in use"), so we trim it first.
                  syncRemoveDir (trimTrailingPathSep $resolvedPath)
                } elseif ([IO.File]::Exists($resolvedPath)) { # file
                  syncRemoveFile $resolvedPath
                } else {
                  Throw "Not a file-system path or no longer extant: $resolvedPath"
                }
              }
            } catch {
              if ($isDir) {
                $exc = $_.Exception
                if ($exc.InnerException) { $exc = $exc.InnerException }
                if ($targetPath -eq $resolvedPath) {
                  Write-Error "Removal of directory '$resolvedPath' failed: $exc"
                } else {
                  Write-Error "Removal of directory '$resolvedPath' failed, because its content could not be (fully) removed: $targetPath`: $exc"
                }
              } else {
                Write-Error $_  # relay error, but in the name of this function
              }
              continue
            }
          }
        }
      }
  }

function GetPSVersion {
    
    Param ( [Parameter(Position = 0, Mandatory = $false)] [System.Boolean] $GetMajorOnly = $false,
            [Parameter(Position = 1, Mandatory = $false)] [System.Boolean] $ReturnStrings = $true )

    if($GetMajorOnly) {
        if($ReturnStrings) {
            return [System.String] $PSVersionTable.PSVersion.Major
        } else {
            return [System.Int16] $PSVersionTable.PSVersion.Major
        }
    } else {
        if($ReturnStrings) {
            return [System.String] $PSVersionTable.PSVersion
        } else {
            return $PSVersionTable.PSVersion
        }
    }
}

function IsFile {

    Param ( [Parameter(Position = 0, Mandatory = $true)] [System.String] $filePath )

    return (Get-Item $filePath) -is [System.IO.FileInfo]
}

function IsDir {

    Param ( [Parameter(Position = 0, Mandatory = $true)] [System.String] $dirPath )

    return (Get-Item $dirPath) -is [System.IO.DirectoryInfo]
}

function CreateFolder {

    Param ( [Parameter(Position = 0, Mandatory = $true)] [System.String] $FolderPath )

    if(!(Test-Path $FolderPath)) {
        New-Item -Path $FolderPath -ItemType Directory | Out-Null
        if(Test-Path $FolderPath) {
            return $true
        } else {
            return $false
        }
    } else {
        return $true
    }
}

function RemoveEmptyLines {

    Param ( [Parameter(Position = 0, Mandatory = $true)][AllowEmptyString()] [System.String[]] $List )

    [System.String[]] $ListMod = $List |  Where-Object { $_ }
    return $ListMod
}

function CleanGenList {

    Param ( [Parameter(Position = 0, Mandatory = $true)][AllowEmptyString()] [System.String[]] $List )

    [System.Boolean] $addMark = $false
    [System.String] $linetrim = ""
    [System.String[]] $Gens = @()
    foreach($line in $cmakeOut) {
        $linetrim = $line.Trim()
        if($line.Length -gt 0) {
            if($addMark -and (!("" -eq $line.Trim())) -and (!($linetrim -match $script:ValMark)) -and
            (!($linetrim -contains $script:OperatorMark)) -and (!($linetrim -match $script:ArchMark)) -and
            (!($linetrim -match $script:PlatformMark)) -and (!($linetrim -match $script:ExperimentMark)) -and
            (!($linetrim -match $script:Win64Mark) -and (!($linetrim -match $script:MingwMark))))  {
                $Gens += $line.Split($script:SplitStr)[0].Trim().Trim("*").Replace("[arch]", "").Replace($script:DeprecationMark, "").Trim()
            }
        }
        if(!($addMark) -and ($BlockSplitter -eq $line)) {
            $addMark = $true
        }
    }
    return $Gens
}

function GetConsoleOutput {

    Param ( [Parameter(Position = 0, Mandatory = $true)]  [System.String] $Command,
            [Parameter(Position = 1, Mandatory = $false)] [System.String] $Parameters )
    
    if(($null -ne $Parameters) -and ($Parameters.Length -gt 0)) {
        $Out = & $Command $Parameters
    } else {
        $Out = & $Command
    }
    return $Out
}

function FSObjectExists {

    Param ( [Parameter(Position = 0, Mandatory = $true)] [System.String] $ObjectPath )

    if(Test-Path $ObjectPath) {
        return $true
    } else {
        return $false
    }
}

function GetVersion {

    Param ( [Parameter(Position = 0, Mandatory = $true)] [System.String] $FilePath )

    if(Test-Path $FilePath) {
        return (Get-Item $FilePath).VersionInfo.FileVersionRaw
    } else {
        return $script:INCORRECTVERSION
    }
}

function BAT2File {

    Param ( [Parameter(Position = 0, Mandatory = $true)]  [System.String[]] $BATContents,
            [Parameter(Position = 1, Mandatory = $false)] [System.String]   $BATFilename = $script:BATFName )

    [System.String] $BATPath = "$script:SCRIPTPATH\$BATFilename"
    $BATContents | Out-File $BATPath -Encoding ascii | Out-Null
    if(Test-Path $BATPath) {
        return $BATPath
    } else {
        return $null
    }
}

function CreateBAT {

    Param ( [Parameter(Position = 0, Mandatory = $true)]  [System.Version] $CMakeVersion,
            [Parameter(Position = 1, Mandatory = $false)] [System.Boolean] $FullBuildPaths = $true )
    
    [System.String] $line
    [System.String[]] $Cmds = @( "cd `"$script:FULLBUILDPATH`"" )
    if($CMakeVersion -ge [System.Version] $script:BridgeCMakeVersion) {
        foreach ($key in $script:TargetBuilds.Keys) {
            if($FullBuildPaths) {
                $Cmds += "`"$script:CMakeEXEPath`" -G `"$script:BuildTool`" -S `"$script:SourceDir`" -A $key -B " +
                "`"$script:FULLBUILDPATH\" + ($script:TargetBuilds.$key | Out-String -Stream) + "`""
            } else {
                $Cmds += "`"$script:CMakeEXEPath`" -G `"$script:BuildTool`" -S `"$script:SourceDir`" -A $key -B " +
                ($script:TargetBuilds.$key | Out-String -Stream)
            }
        }
        foreach($key in $script:TargetBuilds.Keys) {
            foreach ($rec in $script:TargetConfigs) {
                if($FullBuildPaths) {
                    $Cmds += "`"$script:CMakeEXEPath`" --build " +
                    "`"$script:FULLBUILDPATH\" + ($script:TargetBuilds.$key | Out-String -Stream) + "`"" + " --config $rec"
                } else {
                    $Cmds += "`"$script:CMakeEXEPath`" --build " +
                    ($script:TargetBuilds.$key | Out-String -Stream) + " --config $rec"
                }
            }
        }
    } else {
        [System.String[]] $pre313KeyArr = @($script:TargetBuilds.Keys)
        [System.String[]] $pre313ValArr = @($script:TargetBuildsPre313.Values)
        foreach ($key in $script:TargetBuilds.Keys) {
            if(!(CreateFolder ("$script:FULLBUILDPATH\" + $script:TargetBuilds.$key | Out-String -Stream))) {
                return $null
            }
            [System.Int16] $keyIdx = $pre313KeyArr.IndexOf($key)
            [System.String] $pre313Val = $pre313ValArr[$keyIdx]
            if($FullBuildPaths) {
                $Cmds += "pushd " + "`"$script:FULLBUILDPATH\" + ($script:TargetBuilds.$key | Out-String -Stream) + "`""
            } else {
                $Cmds += "pushd " + ($script:TargetBuilds.$key | Out-String -Stream)
            }
            if($null -ne $pre313Val -and ($pre313Val.Length -gt 0)) {
                $Cmds += "`"$script:CMakeEXEPath`" -G `"$script:BuildTool $pre313Val`" `"$script:SourceDir`""
            } else {
                $Cmds += "`"$script:CMakeEXEPath`" -G `"$script:BuildTool`" `"$script:SourceDir`""
            }
            $Cmds += "popd"
        }
        foreach ($key in $script:TargetBuilds.Keys) {
            foreach($rec in $script:TargetConfigs) {
                if($FullBuildPaths) {
                    $Cmds += "`"$script:CMakeEXEPath`" --build " + "`"$script:FULLBUILDPATH\" +
                    ($script:TargetBuilds.$key | Out-String -Stream) + "`" --config $rec"
                } else {
                    $Cmds += "`"$script:CMakeEXEPath`" --build " +
                    ($script:TargetBuilds.$key | Out-String -Stream) + " --config $rec"
                }
            }
        }
    }
    return (BAT2File $Cmds)
}

function WriteColored {

    Param ( [Parameter(Position = 0, Mandatory = $true)]  [System.String] $Message,
            [Parameter(Position = 1, Mandatory = $false)] [System.String] $Color = $dcript:MSGERRORCOLOR )

    [System.ConsoleColor] $conColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $Color
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $conColor
}

function EndScript {

    Param ( [Parameter(Position = 0, Mandatory = $false)][AllowEmptyString()] [System.String] $Message )

    if(($null -ne $Message) -and ($Message.Length -gt 0)) {
        WriteColored $Message
    }
    [System.Void][System.Console]::ReadKey($true)
    if(($null -ne $Message) -or ($Message.Length -gt 0)) {
        WriteColored "`nBUILD ERROR OCCURED; RESS ANY KEY TO CONTINUE" $script:MSGERRORCOLOR
        [Environment]::Exit(1)
    } else {
        WriteColored "`nPRESS ANY KEY TO CONTINUE" $script:MSGCOLOR
        [Environment]::Exit(0)
    }
}

######################################
############### SCRIPT ###############
######################################
if((GetPSVersion $true) -lt $PSVERSIONMIN) {
    EndScript "POWERSHELL VERSION LOWER THAN REQUIRED ($PSVERSIONMIN)"
}
if(!(FSObjectExists $SourceDir) -or !(IsDir $SourceDir)) {
    EndScript "INCORRECT BUILD FOLDER SPECIFIED"
}
if(!(FSObjectExists "$SourceDir\$CMakeListsFName") -or !(IsFile "$SourceDir\$CMakeListsFName")) {
    EndScript "CMAKELISTS.TXT FILE NOT FOUND IN SOURCE DIR"
}
if(!(CreateFolder $FULLBUILDPATH)) {
    EndScript "FAILED TO CREATE BUILD FOLDER"
}
if(!(FSObjectExists $CMakeEXEPath) -or !(IsFile $CMakeEXEPath)) {
    EndScript "CMAKE EXECUTABLE NOT FOUND"
}
if(!(FSObjectExists $CMDEXEPath) -or !(IsFile $CMDEXEPath)) {
    EndScript "CMD EXECUTABLE NOT FOUND"
}
[System.String[]] $cmakeOut = GetConsoleOutput $CMakeEXEPath "--help"
$cmakeOut = CleanGenList $cmakeOut
$cmakeOut = RemoveEmptyLines $cmakeOut
if(!($BuildTool -in $cmakeOut)) {
    EndScript "INCORRECT BUILD TOOL SPECIFIED"
}
[System.Version] $CMakeVer = GetVersion $CMakeEXEPath
if($INCORRECTVERSION -eq $CMakeVer) {
    EndScript "COULDNT GET CMAKE VERSION"
}
[System.String] $BPath = CreateBAT $CMakeVer
if($null -eq $BPath) {
    CleanupFiles
    EndScript "COULDNT CREATE BAT FILE"
}
$BPath = $BPath.Trim()
RemoveFolderContent $FULLBUILDPATH
& $CMDEXEPath "/c `"$BPath`""
Remove-FileSystemItem $BPath
EndScript

# Add-Type -AssemblyName System.Windows.Forms
# [System.Void] [System.Reflection.Assembly]::LoadWithPartialName("System.Version")

<# $MethodDefinition = @"
[DllImport("kernel32")] public static extern UInt64 GetTickCount64();
"@
$Kernel32 = Add-Type -MemberDefinition $MethodDefinition -Name 'Kernel32' -Namespace 'Win32' -PassThru
[System.Int64] $oldTicks = $Kernel32::GetTickCount64() #>