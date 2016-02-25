store-advancedskins
============

### Description
This is a sourcemod Store module that is based on Alon Gubkin's [skin plugin](https://forums.alliedmods.net/showthread.php?t=208129).
Its main improvement's over Alon's plugin is that it also supports custom first person arms models.

### Requirements

* [Store](https://forums.alliedmods.net/showthread.php?t=207157)
* [SMJansson](https://forums.alliedmods.net/showthread.php?t=184604)

### How to Install

Download the zip file from the thread, or press Download Zip in this github page, then unpack the downloaded zip into your sourcemod folder. If you download it from github, get rid of the README.md and LISENCE file as it is just clutter.

### How to add skins?

On your webpanel, add a new item with the type and loadout_slot as "skin", without the "". The attributes field is what matters, here is an example:

	{
		"model": "models/player/custom_player/kuristaja/deadpool/deadpool.mdl",
		"arms": "models/player/custom_player/kuristaja/deadpool/deadpool_arms.mdl",
		"teams": [
			2,
			3
		]
	}

I don't know how well the plugin works with different teams or in Team Fortress 2 because I never tested those things.
