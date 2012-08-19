###############################################################
# This is a script with a simplified algorithm intended for personal use, there is no warrant for this software.
#
# Check if a proposed cherry-picking merge is safe on Team Foundation Server.
#
# Check all changed file/folder in specified cherry-picking changeset, verify each file's history against the id of changeset which happened just after last "full merge" (changes in source branch overwrite all contents on target branch).
#
# Accepted parameters
# baselineChangesetId {int} The ChangesetId which immediately follows the last "full merge"
# cherryChangesetId {int} The ChangesetId to check whether cherry-picking merge is safe
#
# A cherry-picking merge is considered unsafe when one of the following changes is encountered:
# folder-rename: not safe to merge (changesets not yet merged might not be able to be merged); on TFS the change type is usually [Rename].
# folder-delete: not safe to merge (changesets not yet merged might not be able to be merged); on TFS the change type is usually [Delete].
# file-edit: check change history, if has previous changeset id >= baselineChangesetId, report unsafe; if all previous changeset id < baselineChangesetId, ok to merge; on TFS the change type is usually [Edit].
# file-delete: check change history, if has previous changeset id >= baselineChangesetId, report unsafe; if all previous changeset id < baselineChangesetId, ok to merge; on TFS the change type is usually [Delete].

# The following change types are considered safe for a cherry-picking merge:
# folder-add: ok to merge; on TFS the change type is usually [Add, Encoding].
# file-add: ok to merge; on TFS the change type is usually [Add, Edit, Encoding]. file-add: ok to merge
#
#
# Author: Dapeng Li
# Created: 2012-08-19
#
###############################################################
param([int] $baselineChangesetId, [int] $cherryChangesetId)
$tfsServerAddress = "http://MyTFSServer/tfs/CollectionName"  # Enter your TFS server address here

# $baselineChangesetId = 1197  # for test
# $cherryChangesetId = 1207  # for test
if ($baselineChangesetId -ge $cherryChangesetId) {
	Write-Output "baselineChangesetId ($baselineChangesetId) should be less than cherryChangesetId ($cherryChangesetId)"
	return
}

# Helper functions
function GetHistoryForItemBetweenChangesets ([Microsoft.TeamFoundation.Client.TfsTeamProjectCollection] $tfs, [string] $itemServerPath, [int] $beginChangesetId, [int] $endChangesetId)
{
	$history = Get-TfsItemHistory $itemServerPath -server $tfs | Where-Object { $_.ChangesetId -ge $beginChangesetId -and $_.ChangesetId -lt $endChangesetId }

	return $history
}

function WriteCustomOutput($message, [System.ConsoleColor] $foregroundcolor)
{
  $currentColor = $Host.UI.RawUI.ForegroundColor
  $Host.UI.RawUI.ForegroundColor = $foregroundcolor
  if ($message)
  {
    Write-Output $message
  }
  $Host.UI.RawUI.ForegroundColor = $currentColor
}

function WriteSafe([string] $message) {
	WriteCustomOutput $message "darkgreen"
}

function WriteUnsafe([string] $message) {
	WriteCustomOutput $message "darkred"
}

function WriteInfo([string] $message) {
	WriteCustomOutput $message "yellow"
}

function WritePlain([string] $message) {
	WriteCustomOutput $message "white"
}

function WriteCustomOutput($message, [System.ConsoleColor] $foregroundcolor)
{
  $currentColor = $Host.UI.RawUI.ForegroundColor
  $Host.UI.RawUI.ForegroundColor = $foregroundcolor
  if ($message)
  {
    Write-Output $message
  }
  $Host.UI.RawUI.ForegroundColor = $currentColor
}

# Clear Output Pane
clear

# Loads Windows PowerShell snap-in if not already loaded
if ( (Get-PSSnapin -Name Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue) -eq $null )
{
    Add-PSSnapin Microsoft.TeamFoundation.PowerShell
}

# initialize reference to TFS server and changesets
WritePlain "Connecting to TFS $tfsServerAddress"
$tfs = Get-TfsServer -name $tfsServerAddress

WritePlain "Retrieving baseline changeset $baselineChangesetId"
$baselineChangeset = Get-TfsChangeset $baselineChangesetId -Server $tfs

WritePlain "Retrieving cherry changeset $cherryChangesetId"
$cherryChangeset = Get-TfsChangeset $cherryChangesetId -Server $tfs

# get changed files
$changes = $cherryChangeset.Changes

# initialize counters
$folderOkCounter = 0
$folderUnsafecounter = 0
$fileOkCounter = 0
$fileUnsafecounter = 0
$fileOrFolderUnknownCounter = 0

# for each changed folder/file, check change type
foreach ($change in $changes)
{
	$changeType = $change.ChangeType
	$itemType = $change.Item.ItemType  # folder or file
	$itemServerPath = $change.Item.ServerItem

	WriteInfo "$itemType | $changeType | $itemServerPath"

	if ($itemType -eq "Folder") {
		# TODO: to use enum is a better option?
		if ($changeType.ToString().IndexOf("Add") -ge 0) {  # Add, Encoding (usually)
			$folderOkCounter++
			WriteSafe "OK [Folder-Add]"
		}
		elseif ($changeType -eq "Rename") {  # Rename
			$folderUnsafecounter++
			WriteUnsafe "Unsafe [Folder-Rename]"
		}
		elseif ($changeType -eq "Delete") {  # Delete
			$folderUnsafecounter++
			WriteUnsafe "Unsafe [Folder-Delete]"
		}
		else {
			$fileOrFolderUnknownCounter++
			WriteUnsafe "Don't know how to process change type (for folder): $changeType"
		}
	}

	if ($itemType -eq "File") {
		if ($changeType.ToString().IndexOf("Add") -ge 0) {  # Add, Edit, Encoding (usually)
			$fileOkCounter++
			WriteSafe "OK [File-Add]"
		}
		elseif ($changeType.ToString().IndexOf("Edit") -ge 0) {  # Edit
			$sandwichChangesets = GetHistoryForItemBetweenChangesets $tfs $itemServerPath $baselineChangesetId $cherryChangesetId | select ChangesetId, Committer, CreationDate

			if (([Array] $sandwichChangesets).Length -gt 0)  # $sand* is an object of pSCustomObject
			{
				$fileUnsafecounter++
				WriteUnsafe "Unsafe [File-Edit, found sandwich changesets:]"
				$sandwichChangesets | Format-List
			}
			else
			{
				$fileOkCounter++
				WriteSafe "OK [File-Edit, no sandwich changesets]"
			}
		}
		elseif ($changeType -eq "Delete") {  # Delete
			$sandwichChangesets = GetHistoryForItemBetweenChangesets $tfs $itemServerPath $baselineChangesetId $cherryChangesetId | select ChangesetId, Committer, CreationDate

			if (([Array] $sandwichChangesets).Length -gt 0)  # $sand* is an object of pSCustomObject
			{
				$fileUnsafecounter++
				WriteUnsafe "Unsafe [File-Delete, found sandwich changesets:]"
				$sandwichChangesets | Format-List
			}
			else
			{
				$fileOkCounter++
				WriteSafe "OK [File-Delete, no sandwich changesets]"
			}
		}
		else {
			$fileOrFolderUnknownCounter++
			WriteUnsafe "Don't know how to process change type (for file): $changeType"
		}
	}
}

# Output analysis result
WritePlain "Total files checked: $($changes.Count)"

if ($folderOkCounter -gt 0)
{
	WriteSafe "Folder OK to merge: $folderOkCounter"
}
if ($folderUnsafecounter -gt 0)
{
	WriteUnsafe "Folder unsafe to merge: $folderUnsafecounter"
}
if ($fileOkCounter -gt 0)
{
	WriteSafe "File OK to merge: $fileOkCounter"
}
if ($fileUnsafecounter -gt 0)
{
	WriteUnsafe "File unsafe to merge: $fileUnsafecounter"
}
if ($fileOrFolderUnknownCounter -gt 0)
{
	WriteUnsafe "File or folder with unknown edit type: $fileOrFolderUnknownCounter"
}

# Output verdict
WritePlain "==============================================="
if ($folderUnsafecounter + $fileUnsafecounter + $fileOrFolderUnknownCounter -gt 0)
{
	WriteUnsafe "UNSAFE to merge"
}
else
{
	WriteSafe "SAFE to merge"
}
