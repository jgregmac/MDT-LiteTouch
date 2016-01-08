################################################################################
#
#  Create-MDTDriverStructure.ps1
#  J. Greg Mackinnon, University of Vermont, 2013-11-11
#  Creates a folder structure in the "Out of Box Drivers" branch of a MDT 2013
#    deployment share.  The structure matches the first two subdirectories of 
#    the source filesystem defined in $srcRoot.  All drivers contained within
#    $srcRoot are imported into the deployment share.
#
#  Requires: 
#    $srcDir - A driver source directory, 
#    $MDTRoot - a MDT 2013 deployment share
#    - MDT 2013 must be installed in the path noted in $modDir!!!
#
#  Parameters:
#    $reImport - A boolean which determines if existing driver directories 
#        will be imported.  Default value is $false.
#
################################################################################
[cmdletBinding()]
param (
	[string]$srcRoot = 'O:\staging\drivers\import',
	[validateSet('E:\DevRoot','F:\Deploy2012','G:\BizDeploy2012')]
		[string]$MDTRoot = 'E:\DevRoot',
	[string]$modelOutFile = '\\files.uvm.edu\shared\software\deploy\LiteTouch\SupportedModels.txt',
	[switch]$reImport = $false
)
Set-PSDebug -Strict
$prodShare = 'F:\Deploy2012'

[string[]] $sources = gci -Attributes D $srcRoot | `
    Select-Object -Property name | % {$_.name.tostring()}

#Initialize the Supported Models report file, if this is a production update:
if ($MDTRoot -eq $prodShare) {
	if (test-path $modelOutFile) {Remove-Item $modelOutFile -Force -Confirm:$false}
	[string]$('List of hardware models currently supported for LiteTouch deployments') `
		| out-file -LiteralPath $modelOutFile -Append
	[string]$('Last Updated on: '+ [datetime]::Now) `
		| out-file -LiteralPath $modelOutFile -Append
	[string]$('') | out-file -LiteralPath $modelOutFile -Append
	[string]$('Model names discovered by running the command "wmic computersystem get model"') `
		| out-file -LiteralPath $modelOutFile -Append
	[string]$('If drivers are detected for an earlier OS than the OS selected ' `
		+ 'for deployment, and no current drivers are available, the older drivers '`
		+ 'will be used.') `
		| out-file -LiteralPath $modelOutFile -Append
	[string]$('') | out-file -LiteralPath $modelOutFile -Append
}

# Initialize MDT Working Environment:
[string] $PSDriveName = 'MDTShare'
[string] $oobRoot = $PSDriveName + ":\Out-Of-Box Drivers"
[string] $modDir = 'C:\Program Files\Microsoft Deployment Toolkit\Bin' `
	+ '\MicrosoftDeploymentToolkit.psd1'
Import-Module $modDir
if (test-path ($PSDriveName + ':\')) {Remove-PSDrive -Name "$PSDriveName" -Force}
New-PSDrive -Name "$PSDriveName" -PSProvider MDTProvider -Root $MDTRoot

################################################################################
# Define Script Functions:
function cleanDriverDir {
    param ([string]$dir)
	# Clean up "cruft" files that lead to duplicate drivers in the share:
	Write-Host "Cleaning extraneous files from $dir" -ForegroundColor Cyan
	$delItems = gci -recurse -Include version.txt,release.dat,cachescrubbed.txt,btpmwin.inf $dir
	Write-Host "Found " $delItems.count " files to delete..." -ForegroundColor Yellow
	if ($delItems.count -ne 0) {
		$delItems | remove-Item -force -confirm:$false
		$delItems = gci -recurse -Include version.txt,release.dat,cachescrubbed.txt,btpmwin.inf $dir
		Write-Host "New count for extraneous files: " $delItems.count -ForegroundColor Yellow
	}
	
}

function createMdtDir {
    param ([string]$dir)
    Write-Host "Creating MDT Directory: $dir"
    if (Test-Path -Path $dir) {
        Write-Host 'Directory already exists.' -ForegroundColor Yellow
    } else {
        [string] $leaf = Split-Path -Path $dir -Leaf
        [string] $parent = Split-Path -Path $dir -Parent
        new-item -path $parent -name $leaf -itemType "directory" -Verbose
    }
}

function importDriverDir {
    param ([string]$srcDir,[string]$dstDir)
    [bool]$newDir = $false

	# Create the target directory:
    if (-not (test-path -path $dstDir)) {
        createMdtDir $dstDir
        $newDir = $true
    }
	
	# Import all drivers from the source to the new target:
    if ($newDir -or $reImport) {
		cleanDriverDir $srcDir
	    Write-Host "Importing Drivers from $dstDir" -ForegroundColor Cyan
	    Import-MDTDriver -Path $dstDir -SourcePath $srcDir 
	}
    Write-Host "Moving to next directory..." -ForegroundColor Green
}
#
# End script functions
################################################################################


foreach ($source in $sources){
    Write-Host "Working with source: " $source -ForegroundColor Magenta
   
    # Create the OOB Top-level folders:
    $oobDir1 = $oobRoot + "\" + $source
    createMdtDir $oobDir1
    # Define a variable for the current working directory:
    $sub1 = $srcRoot + "\" + $source
    # Create an array containing the folders to be imported:
    $items = gci -Attributes D $sub1 | Select-Object -Property name | % {$_.name.tostring()}

    foreach ($item in $items) {
        # Define source and target directories for driver import
        [string] $dstDir1 = $oobDir1 + "\" + $item
	    [string] $srcDir1 = $sub1 + "\" + $item
        
        if ($source -eq 'Models') {
            #If we are in "Models", we need to create another subdirectory level:
            # Create an array containing the folders to be imported:
            $items2 = gci -Attributes D $srcDir1 | Select-Object -Property name | % {$_.name.tostring()}
            $oobDir2 = $oobDir1 + "\" + $item
            createMdtDir $oobDir2
            foreach ($item2 in $items2) {
                [string] $dstDir2 = $dstDir1 + "\" + $item2
                [string] $srcDir2 = $srcDir1 + "\" + $item2
                if ($MDTRoot -eq $prodShare) { #suppress logging if not production update
					$dstDir2.Remove(0,($dstDir2.IndexOf('\Win')+1)) | Out-File -LiteralPath $modelOutFile -Append
				}
                importDriverDir $srcDir2 $dstDir2
            }
        } else {
            importDriverDir $srcDir1 $dstDir1
        } 
		
    }
}

Remove-PSDrive -Name "$PSDriveName"