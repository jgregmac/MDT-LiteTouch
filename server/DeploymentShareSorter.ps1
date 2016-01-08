    # ***************************************************************************
    #
    # File:      DeploymentShareSorter.ps1
    #
    # Author:    Michael Niehaus
    #
    # Purpose:   This PowerShell script will sort the existing files and folders
    #            in a deployment share.
    #
    #            Note that there should be no one actively adding items to the
    #            deployment share while running this script, as some of the
    #            operations performed could cause these items to be lost.
    #
    #            This requires PowerShell 2.0 CTP3 or later.
    #
    # Usage:     Copy this file to an appropriate location.  Edit the file to
    #            change the $rootPath variable below, pointing to your
    #            deployment share. (This can be a local path or a UNC path.)
    #
    # ------------- DISCLAIMER --------------------------------------------------
    # This script code is provided as is with no guarantee or warranty concerning
    # the usability or impact on systems and may be used, distributed, and
    # modified in any way provided the parties agree and acknowledge the
    # Microsoft or Microsoft Partners have neither accountability or
    # responsibility for results produced by use of this script.
    #
    # Microsoft will not provide any support through any means.
    # ------------- DISCLAIMER --------------------------------------------------
    #
    # ***************************************************************************

    # Constants

    $rootPath = "\\sysimg3.campus.ad.uvm.edu\distribution$"

    # Conect to the deployment share

    Add-PSSnapIn Microsoft.BDD.PSSnapIn -ErrorAction SilentlyContinue
    New-PSDrive -Name DeploymentPointSorter -PSProvider MDTProvider -Root "$rootPath"

    # Functions

    function Sort-MDTFolderItems {

        [CmdletBinding()]
        PARAM
        (
            [Parameter(Position=1, ValueFromPipeline=$true)] $folder
        )
        Process
        {
            Write-Host "Sort-MDTFolderItems: Processing folder $($folder.Name)"
            # Initialize the sorted array
            $sorted = @()
            # Get the list of immediate subfolders, sort by name, and add to the array
            $folderPath = $folder.PSPath.Substring($folder.PSPath.IndexOf("::")+2)
            Get-ChildItem $folderPath | ? {-not $_.PSIsContainer} | Sort Name | % { $sorted += $_.Guid }
            # If there were any items found, process them.
            if ($sorted.Count -gt 0)
            {
                # See if the list is already sorted.  If it is, we don't need to make any updates.
                $compareResults = compare-object $sorted $folder.Item("Member") -SyncWindow 0
                if ($compareResults -eq $null)
                {
                    Write-Host "Already sorted."
                }
                else
                {
                    Write-Host "Saving sorted list."
                    # First remove all members of the list because the PowerShell provider will "optimize" the change by seeing there
                    # were no items added or removed.  Then put all the members back in the sorted order.  (This is actually quite
                    # dangerous to do as it could orphan the items, so we need to immediately put them back.)
                    $folder.Item("Member") = @()
                    $folder.Item("Member") = $sorted
                }
            }
        }
    }

    function Sort-MDTFolderSubfolders {

        [CmdletBinding()]
        PARAM
        (
            [Parameter(Position=1, ValueFromPipeline=$true)] $folder
        )
        Process
        {
            Write-Host "Sort-MDTFolderSubfolders: Processing folder $($folder.Name)"
            # Initialize the arrays
            $sorted = @()
            $unsorted = @()
            # Get the list of immediate child folders, sorted and unsorted
            $folderPath = $folder.PSPath.Substring($folder.PSPath.IndexOf("::")+2)
            $folderList = Get-ChildItem $folderPath | ? {$_.PSIsContainer}
            $folderList | % { $unsorted += $_.Name }
            $folderList | Sort Name | % { $sorted += $_.Name }
            # If there were any subfolders found, process them.
            if ($sorted.Count -gt 0)
            {
                # See if the list is already sorted.  If it is, we don't need to make any updates.
                $compareResults = compare-object $sorted $unsorted -SyncWindow 0
                if ($compareResults -eq $null)
                {
                    Write-Host "Already sorted."
                }
                else
                {
                    Write-Host "Sorting folders."
                    # Create the temporary folder
                    $null = New-Item "$folderPath\__TEMP__" -ItemType Folder
                    # Move the folders into the temporary folder
                    $sorted | % { Move-Item "$folderPath\$_" "$folderPath\__TEMP__" }
                    # Move the folders back
                    $sorted | % { Move-Item "$folderPath\__TEMP__\$_" "$folderPath" }

                    # Remove the temporary folder
                    Remove-Item "$folderPath\__TEMP__"
                }
            }
        }
    }

    # Enumerate the folders and call the functions above to process each one

    Get-ChildItem DeploymentPointSorter: -Recurse | ? {$_.PSIsContainer} | Sort-MDTFolderItems

    Get-ChildItem DeploymentPointSorter: -Recurse | ? {$_.PSIsContainer} | Sort-MDTFolderSubfolders