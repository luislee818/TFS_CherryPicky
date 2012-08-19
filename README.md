A simple PowerShell script checking if a cherry-picking merge in TFS is safe.

###Intro
Check all changed file/folder in specified cherry-picking changeset, verify each file's history against the id of changeset which happened just after last "full merge" (changes in source branch overwrite all contents on target branch).

###Prerequisites
[Team Foundation Server 2010 Power Tools] (http://visualstudiogallery.msdn.microsoft.com/c255a1e4-04ba-4f68-8f4e-cd473d6b971f)

###Usage
*./cherry_picky.ps1 baselineChangesetId cherryChangesetId*

#####Accepted parameters
* *baselineChangesetId* {int} The ChangesetId which immediately follows the last "full merge"
* *cherryChangesetId* {int} The ChangesetId to check whether cherry-picking merge is safe

###Checking rules
 A cherry-picking merge is considered unsafe when one of the following changes is encountered:
* **folder-rename**: not safe to merge (changesets not yet merged might not be able to be merged); on TFS the change type is usually [Rename].
* **folder-delete**: not safe to merge (changesets not yet merged might not be able to be merged); on TFS the change type is usually [Delete].
* **file-edit**: check change history, if has previous changeset id >= baselineChangesetId, report unsafe; if all previous changeset id < baselineChangesetId, ok to merge; on TFS the change type is usually [Edit].
* **file-delete**: check change history, if has previous changeset id >= baselineChangesetId, report unsafe; if all previous changeset id < baselineChangesetId, ok to merge; on TFS the change type is usually [Delete].

The following change types are considered safe for a cherry-picking merge:
* **folder-add**: ok to merge; on TFS the change type is usually [Add, Encoding].
* **file-add**: ok to merge; on TFS the change type is usually [Add, Edit, Encoding].

A diagram about the checking rules can be found on [this Wiki page](https://github.com/luislee818/TFS_CherryPicky/wiki/Cherry-Picky-Rules).