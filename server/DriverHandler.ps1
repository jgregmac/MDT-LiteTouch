$root = "E:\staging\drivers\cabs\win8"
$dirs = gci $root -Directory | gci -Directory | gci -Directory
foreach ($dir in $dirs) {
    if ($dir.name -match "x86") {
        #Copy-Item -LiteralPath $dir.FullName -Destination "E:\staging\drivers\import\Win8-x86\Dell" -Recurse -Confirm:$false -Force
        [string] $source = $dir.FullName
        [string] $dest = "E:\staging\drivers\import\Win8-x86\Dell"
        [string] $roboCom = "robocopy /E /copyall /R:0 /NP /NFL /MT:4 " + $Source + " " + $Dest
        invoke-expression -command $roboCom
    }
    if ($dir.name -match "x64") {
        #Copy-Item -LiteralPath $dir.FullName -Destination "E:\staging\drivers\import\Win8-x64\Dell" -Recurse -Confirm:$false -Force
        [string] $source = $dir.FullName
        [string] $dest = "E:\staging\drivers\import\Win8-x64\Dell"
        [string] $roboCom = "robocopy /E /copyall /R:0 /NP /NFL /MT:4 " + $Source + " " + $Dest
        invoke-expression -command $roboCom
    }
}
