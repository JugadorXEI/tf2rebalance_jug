<a href='https://ko-fi.com/jugadorxei' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://az743702.vo.msecnd.net/cdn/kofi3.png?v=0' border='0' alt='Donate for more awesome plugins!' /></a>

# Rebalanced Fortress 2
This plugin allows you, through a file, to modify the attributes of (almost) every item in Team Fortress 2, including weapons, shields or even hats! If you think an item deserves more of the spotlight, or if you think a weapon is horribly broken, you will be able to change the attributes of such weapon to your heart's content. In addition, it's possible to add information related to those changes to let everyone know about what was changed. 

## Dependencies
- TF2Items: https://forums.alliedmods.net/showthread.php?t=115100
- TF2Attributes (optional, for classes): https://forums.alliedmods.net/showthread.php?t=210221
- Morecolors (only to compile the plugin): https://forums.alliedmods.net/showthread.php?t=185016

## Installation
This assumes you have SourceMod installed on your dedicated server. If not, go here: https://wiki.alliedmods.net/Installing_SourceMod

1. Please install TF2Items (and optionally TF2Attributes) and follow their respective installation instructions in order to use the plugin. 
2. Get the latest release from the releases tab.
3. Drag'n'drop the addons folder to your addons folder which contains SourceMod in it.
4. Load the plugin manually (`sm plugins load tf2rebalance_jug` on the server console) or change the map on your server so the plugin loads.
5. Done!

## Console variables and commands

> **Warning**: Due to certain HUDs, setting __sm_tfrebalance_changetimer__ to be higher than zero can crash clients after a weapon is given. You are suggested to use __sm_tfrebalance_changetimer__ alongside __sm_tfrebalance_timer_onlybots__ being set to 1.  Enable at your own risk.

```
* sm_tfrebalance_enable (Default: "1"): Enables (1) or disables (0) the plugin.
* sm_tfrebalance_logdependencies (Default: "1"): Should the lack of TF2Attributes be logged? 1 enables this, whereas 0 disables it instead.
* sm_tfrebalance_firsttimeinfo (Default: "1"): Should the players, on their first spawn, be notified of the possibility of modified weapons and the commands to see such information? 1 enables this, whereas 0 disables it instead.
* sm_tfrebalance_infoonspawn (Default: "0"): Every other spawn after the initial one, the player is notified if their weapons have changes. 0 is fully disabled, 1 enables it by default but can be toggled off by the player, 2 makes it toggleable, but disabled at first.
* sm_tfrebalance_preserveattribsbydefault (Default: "0"): On file parsing, should the lack of a "keepattribs" key default to preserve (1) or not preserve (0) the attributes of the item?
* sm_tfrebalance_changetimer (Default: "0"): If higher than zero, the weapon changes will apply after the time specified on the ConVar (example: "0.2"). This can be used to increase compatibility between plugins.
* sm_tfrebalance_timer_onlybots (Default: "0"): Indicates if sm_tfrebalance_changetimer should only affect bots.
* sm_tfrebalance_bots_giveweapons (Default: "1"): Indicates if bots should be given changes to their weapons.
* sm_tfrebalance_bots_applyclassattribs (Default: "1"): Should class changes apply to Bots?
* sm_tfrebalance_botsmvm_giveweapons (Default: "0"): Indicates if MvM bots should have their weapons changed.
* sm_tfrebalance_botsmvm_applyclassattribs (Default: "0"): Should class changes apply to MvM Bots?
* sm_tfrebalance_debug_giveweapons (Default: "0"): Verbose debug mode that throws messages on the server console about what function is being used to give weapons, whose weapon is being parsed, if attributes are being kept, the index ID of the weapon, the ID of the attribute and the value of the attribute given.
* sm_tfrebalance_debug_configfile (Default: "0"): Very verbose debug mode that displays on the server console what class or weapon is having attributes stored to for later usage for when a player spawns with such weapon or as such class.

* /tfrebalance_refresh (Root admin only): Parses tf2rebalance_attributes.txt again in case an item is in need of a hotfix, or for testing purposes.
* /refreshweapon (Cheat flag): Can target players. Turns their currently-equipped weapons into the ones defined on the tf2rebalance_attributes.txt file (so if a player holds a Brass Beast without changes somehow, the command will give them the version that the plugin would give them by default).
* /official (or /changes, or /change, or /o): Displays a menu that allows the player to see the information about their changed items and their class, if any.
* /cantsee:  Makes all of the player's held weapons transparent for ease of use and to help visibility.
* /toggleinfo: if `sm_tfrebalance_infoonspawn` is enabled, then this toggles on and off the notification of how many weapons were modified by the plugin to the player.
```

Enjoy!

