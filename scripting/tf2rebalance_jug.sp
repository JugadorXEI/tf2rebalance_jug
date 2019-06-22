#include <sourcemod>
#include <tf2_stocks>
#include <tf2items>
#include <clientprefs>
#include <morecolors>

// Used to add attributes on classes, optional.
#undef REQUIRE_PLUGIN
#tryinclude <tf2attributes>            
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

// MAXIMUM STUFF WE CAN ADD [NOTE: DON'T GO OVERBOARD WITH THIS OR THE PLUGIN WILL GO SLOW]
#define MAXIMUM_ADDITIONS 1024
#define MAXIMUM_ATTRIBUTES 20
#define MAXIMUM_DESCRIPTIONLIMIT 475
#define MAXIMUM_WEAPONSPERATTRIBUTESET 52
//////////////////

// Command descriptions.
#define REBALANCEDHELP_DESC "Displays info for rebalanced weapons."
#define TRANSPARENCYHELP_DESC "Makes your weapons transparent."
#define WEAPONINFO_DESC "Toggles info on if your weapons have changes or not."

/* 1.9.0 checklist
 * (Done) Make it so different cosmetics show separate in the weapon info menu.
 * (Won't bother with it) ConVar that allows to preserve skins if available or regardless of if there's space or not.
 * (Done) Notification on spawn that tells the player how many weapons have been customized
 (0 = disable, 1 = enabled (can be disabled per player), 2 = disabled (but can be toggled off by player))
 * (I guess) uhh fixes and optimization???
*/

/* Changelog:
 * Now cosmetics will show separately on the balance menu.
 * Added new notification system per spawn (sans the first spawn) that
 tells the player how many weapons (and if their class) changed: 
 `sm_tfrebalance_infoonspawn` (disabled by default).
	- 0 = Always disabled (default).
	- 1 = Enabled, can be toggled on and off by the player.
	- 2 = Disabled, can be toggled on and off by the player.
 * Fixed a bug where the balance menu would show descriptionless
 items as a selectable choice, causing a blank menu.
 * Fixed a bug where descriptions would sometimes not show in various
 edge cases.
 * Changed wording in various localization strings.
 * Minor optimizations.
*/

// Certain shorthands for common definitions.
#define PLUGIN_VERSION "v1.9.0"
#define COSMETIC_MENUCHOICE "#cosmetic"

public Plugin myinfo =
{
	name = "Rebalanced Fortress 2",
	author = "JugadorXEI",
	description = "Rebalance all of TF2's weapons based on your own changes!",
	version = PLUGIN_VERSION,
	url = "https://github.com/JugadorXEI",
}

// Convars
ConVar g_bEnablePlugin; // Convar that enables plugin
ConVar g_bLogMissingDependencies; // Convar that, if enabled, will log if dependencies are missing.
ConVar g_bFirstTimeInfoOnSpawn; // Convar that displays info to the players on their first spawn that their weapons are modified.
ConVar g_bInfoEverySpawn; // Convar that display info to the respawning player about their modified weapons if any.
ConVar g_bItemPreserveAttributesDefault; // Convar that controls if the attributes should be preserved by default or not.
ConVar g_fChangeWeaponOnTimer; // Convar that will change weapons or wearables after a set timer.
ConVar g_bTimerOnlyAffectsBots; // Convar that'll make it so the timer function only affects bots.
ConVar g_bGiveWeaponsToBots; // Convar that changes the weapons of bots.
ConVar g_bApplyClassChangesToBots; // Convar that decides if class attributes should apply to bots.
ConVar g_bGiveWeaponsToMvMBots; // Convar that changes the weapons of MvM bots.
ConVar g_bApplyClassChangesToMvMBots; // Convar that decides if class attributes should apply to MvM bots.
ConVar g_iWepTransparencyValue; // The value that the server can set the clients' weapons transparent to.
ConVar g_bDebugGiveWeapons; // Convar that throws debug messages about given weapons on the server console.
ConVar g_bDebugKeyvaluesFile; // Convar that throws debug messages about keyvalues parsing on the server console.

// Cookies
Handle g_CookieWeaponVis = INVALID_HANDLE;
bool g_bWeaponVis[MAXPLAYERS+1] = false;

Handle g_CookieWeaponSpawnInfo = INVALID_HANDLE;
bool g_bInfoOnSpawn[MAXPLAYERS+1] = false;

// Keyvalues file for attributes
Handle g_hKeyvaluesAttributesFile = INVALID_HANDLE;

// Plugin dependencies: are they enabled or not?
bool g_bIsTF2AttributesEnabled = false;
// Bool that indicates the player's first spawn.
bool g_bFirstSpawn[MAXPLAYERS+1] = false; 
// Is the mode MvM?
bool g_bIsMVM = false;

// Bool that indicates if that item has been changed.
bool g_bRebalance_ItemIndexChanged[MAXIMUM_ADDITIONS] = false;
// Int that indicates the ID of the changed item.
int g_iRebalance_ItemIndexDef[MAXIMUM_ADDITIONS] = -1;
// Int that indicates how many items have been changed.
int g_iRebalance_ItemIndexChangesNumber = 0;
// Int that indicates which attribute(s) to add to a weapon.
// MAXIMUM_ADDITIONS is the max items that can be edited. MAXIMUM_ATTRIBUTES is the maximum attributes you can add on a weapon. 
int g_iRebalance_ItemAttribute_Add[MAXIMUM_ADDITIONS][MAXIMUM_ATTRIBUTES];
// float that indicates the value of the attribute(s) to add to a weapon.
float g_fRebalance_ItemAttribute_AddValue[MAXIMUM_ADDITIONS][MAXIMUM_ATTRIBUTES]; 
// int that indicates how many attributes were added on a weapon.
int g_iRebalance_ItemAttribute_AddNumber[MAXIMUM_ADDITIONS] = 0;
// char that indicates the description of the item.
char g_cRebalance_ItemDescription[MAXIMUM_ADDITIONS][MAXIMUM_DESCRIPTIONLIMIT];
// bool that indicates if the item has a description.
bool g_bRebalance_DoesItemHaveDescription[MAXIMUM_ADDITIONS] = false;
// bool that indicates if the item should preserve attributes.
bool g_bRebalance_ShouldItemPreserveAttributes[MAXIMUM_ADDITIONS] = false;

// Class things:
// Bool that indicates if that class was changed.
bool g_bRebalance_ClassChanged[TFClassType] = false;
// int that indicates which attributes we'll add into the class.
int g_iRebalance_ClassAttribute_Add[TFClassType][MAXIMUM_ATTRIBUTES]; 
// float that indicates the value of the attributes we'll add.
float g_fRebalance_ClassAttribute_AddValue[TFClassType][MAXIMUM_ATTRIBUTES];
// int that indicates how many attributes were added on a class.
int g_iRebalance_ClassAttribute_AddNumber[TFClassType] = 0;
// int that indicates how many classes were modified
int g_iRebalance_ClassChangesNumber = 0;
// char that indicates the description of the class.
char g_cRebalance_ClassDescription[TFClassType][MAXIMUM_DESCRIPTIONLIMIT];
// bool that indicates if the class has a description.
bool g_bRebalance_DoesClassHaveDescription[TFClassType] = false;

public void OnPluginStart()
{
	// Convars, they do what they say on the tin.
	g_bEnablePlugin = CreateConVar("sm_tfrebalance_enable", "1",
	"Enables/Disables the plugin. Default = 1, 0 to disable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	g_bLogMissingDependencies = CreateConVar("sm_tfrebalance_logdependencies", "1",
	"If any dependencies are missing from the plugin, log them on SourceMod log files. Default = 1, 0 to disable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	g_bFirstTimeInfoOnSpawn = CreateConVar("sm_tfrebalance_firsttimeinfo", "1",
	"Displays on the player's first spawn information about the modifications done to the weapons. Default = 1, 0 to disable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	g_bInfoEverySpawn = CreateConVar("sm_tfrebalance_infoonspawn", "0",
	"Every other spawn after the initial one, the player is notified if their weapons have changes. " ...
	"0 is fully disabled, 1 enables it by default but can be toggled off by the player, 2 makes it toggleable, "
	... "but disabled at first.",
	FCVAR_PROTECTED, true, 0.0, true, 2.0);
	
	g_bItemPreserveAttributesDefault = CreateConVar("sm_tfrebalance_preserveattribsbydefault", "0",
	"Should the weapons set on the tf2rebalance_attributes.txt file preserve attributes by default? Default = 0, 1 to enable. "
	... "This is always overriden if the weapon has a \"keepattribs\" value set on the configuration file.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	g_fChangeWeaponOnTimer = CreateConVar("sm_tfrebalance_changetimer", "0",
	"If higher than zero, the changes will be applied to weapons after a set timer (example: 0.25). "
	... "Use this to increase compatibility with other plugins.", FCVAR_PROTECTED, true, 0.0);

	g_bTimerOnlyAffectsBots = CreateConVar("sm_tfrebalance_timer_onlybots", "0",
	"If enabled, sm_tfrebalance_changetimer will only affect to bots only. Default = 1, 0 to disable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	g_bGiveWeaponsToBots = CreateConVar("sm_tfrebalance_bots_giveweapons", "1",
	"Should Bots' weapons be changed by the plugin? Default = 1, 0 to disable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	g_bApplyClassChangesToBots = CreateConVar("sm_tfrebalance_bots_applyclassattribs", "1",
	"Should class changes apply to Bots? Default = 1, 0 to disable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	g_bGiveWeaponsToMvMBots = CreateConVar("sm_tfrebalance_botsmvm_giveweapons", "0",
	"Should MvM Bots' weapons be changed by the plugin? Enabling this could cause issues. Default = 0, 1 to enable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	g_bApplyClassChangesToMvMBots = CreateConVar("sm_tfrebalance_botsmvm_applyclassattribs", "0",
	"Should class changes apply to MvM Bots? Enabling this could cause issues. Default = 0, 1 to enable.",
	FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	g_iWepTransparencyValue = CreateConVar("sm_tfrebalance_transparency_value", "200",
	"Transparency value that the weapons will have when the players use /cantsee. Default = 200.",
	FCVAR_PROTECTED, true, 50.0, true, 225.0);
	
	g_bDebugGiveWeapons = CreateConVar("sm_tfrebalance_debug_giveweapons", "0",
	"Enables a verbose debug mode that shows which function is adding attributes into what weapon and displays it on the server console. "
	... "Default = 0, 1 to enable.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	g_bDebugKeyvaluesFile = CreateConVar("sm_tfrebalance_debug_configfile", "0",
	"Enables a VERY verbose debug mode that shows what the plugin is parsing within the keyvalues (configuration) file and displays it on the server console. "
	... "Default = 0, 1 to enable.", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	
	// We create a config file that generates the ConVars that this plugin has.
	AutoExecConfig(true, "tf2rebalance_commands");
	
	// The weapon transparency cookie:
	g_CookieWeaponVis = RegClientCookie("tfrebalance_weaponvis", "Cookie that contains if weapons should be transparent for the user.", CookieAccess_Public);
	g_CookieWeaponSpawnInfo = RegClientCookie("tfrebalance_weaponinfo", "Cookie that contains if the player should be told if their " ...
	"weapons have changes or not", CookieAccess_Public);
	
	// Admin commands
	RegAdminCmd("sm_tfrebalance_refresh", Rebalance_RefreshFile, ADMFLAG_ROOT,
	"Refreshes the attributes gotten through the file without needing to change maps. "
	...	"Depending on file size, it might cause a lag spike, so be careful.");
	RegAdminCmd("sm_refreshweapon", Rebalance_RefreshWeapon, ADMFLAG_CHEATS,
	"Refreshes the held weapon(s) of the selected players, giving them their appropriate stats "
	... "based on the item definition index of their weapon and the balance set for them.");
	
	// Let's hook the spawns and such.
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PlayerSpawn);
	
	// Commands for the players.
	RegConsoleCmd("sm_official", RebalancedHelp, REBALANCEDHELP_DESC);
	RegConsoleCmd("sm_changes", RebalancedHelp, REBALANCEDHELP_DESC);
	RegConsoleCmd("sm_change", RebalancedHelp, REBALANCEDHELP_DESC);
	RegConsoleCmd("sm_o", RebalancedHelp, REBALANCEDHELP_DESC);
	
	// Can't see command:
	RegConsoleCmd("sm_transparent", WeaponTransparency, TRANSPARENCYHELP_DESC);
	RegConsoleCmd("sm_transparency", WeaponTransparency, TRANSPARENCYHELP_DESC);
	RegConsoleCmd("sm_cantsee", WeaponTransparency, TRANSPARENCYHELP_DESC);
	
	// Constant notification command:
	RegConsoleCmd("sm_toggleinfo", WeaponInfoToggle, WEAPONINFO_DESC);
	RegConsoleCmd("sm_infotoggle", WeaponInfoToggle, WEAPONINFO_DESC);
	
	// Translations:
	LoadTranslations("tf2rebalance.phrases");
	LoadTranslations("common.phrases");
	
	// We account for reloads in the plugin by checking if the already-connected players
	// have cookies cached and setting them.
	for	(int i = 0; i < MAXPLAYERS+1; i++)
	{
		if (IsValidClient(i))
		{
			if (AreClientCookiesCached(i))
			{
				char cCookie[3];
			
				GetClientCookie(i, g_CookieWeaponVis, cCookie, sizeof(cCookie));
				g_bWeaponVis[i] = view_as<bool>(StringToInt(cCookie));

				GetClientCookie(i, g_CookieWeaponSpawnInfo, cCookie, sizeof(cCookie));
				g_bInfoOnSpawn[i] = view_as<bool>(StringToInt(cCookie));
			}
		}
	}
}

public void OnMapStart()
{
	WipeStoredAttributes(); // Function that sets every Rebalance_* variable and the Handle to 0/INVALID_HANDLE;
	if (GetAndStoreWeaponAttributes()) // Function that stores the weapon changes on the variables.
	{
		// Stored %i weapons and %i classes in total to change.
		PrintToServer("[TFRebalance] %T", "TFRebalance_StoredItems",
		LANG_SERVER, g_iRebalance_ItemIndexChangesNumber, g_iRebalance_ClassChangesNumber);
	}
	
	// We try to see if the current map is an MvM one.
	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
		g_bIsMVM = true;
	
	// If any of the (optional) requirements aren't loaded, we log that in just in case.
	if (g_bLogMissingDependencies.BoolValue) // That is, if this convar is set to true.
	{
		// tf2attributes is not loaded. This will prevent the plugin from adding attributes on classes.
		if (!g_bIsTF2AttributesEnabled)
			LogMessage("[TFRebalance] %T", "TFRebalance_TF2Attributes_NoLoad", LANG_SERVER);
	}
}

public void OnClientCookiesCached(int iClient)
{
	char cIsEnabledValue[3];
	
	// Visibility weapon cookie setup
	GetClientCookie(iClient, g_CookieWeaponVis, cIsEnabledValue, sizeof(cIsEnabledValue));
	
	int iValue = StringToInt(cIsEnabledValue);
	g_bWeaponVis[iClient] = view_as<bool>(iValue);
	
	// Weapon info on spawn cookie setup
	GetClientCookie(iClient, g_CookieWeaponSpawnInfo, cIsEnabledValue, sizeof(cIsEnabledValue));
	
	// If no value is stored, we'll store a default one.
	if (StrEqual(cIsEnabledValue, "") && g_bInfoEverySpawn.IntValue != 0)
	{
		if (g_bInfoEverySpawn.IntValue == 1)
			cIsEnabledValue = "1";
		else if (g_bInfoEverySpawn.IntValue == 2)
			cIsEnabledValue = "0";
			
		SetClientCookie(iClient, g_CookieWeaponSpawnInfo, cIsEnabledValue);
	}
	
	iValue = StringToInt(cIsEnabledValue);
	g_bInfoOnSpawn[iClient] = view_as<bool>(iValue);
}

// We check if tf2attributes exist or not.
public void OnLibraryAdded(const char[] cName)
{
	if (StrEqual(cName, "tf2attributes", true)) g_bIsTF2AttributesEnabled = true;
}

public void OnLibraryRemoved(const char[] cName)
{
	if (StrEqual(cName, "tf2attributes", true)) g_bIsTF2AttributesEnabled = false;
}
// End of checking that.

public Action Rebalance_RefreshFile(int iClient, int iArgs)
{
	WipeStoredAttributes(); // Function that sets every Rebalance_* variable and the Handle to 0/INVALID_HANDLE;
	if (GetAndStoreWeaponAttributes()) // Function that stores the weapon changes on the variables.
	{
		// Stored %i weapons and %i classes in total to change.
		PrintToServer("[TFRebalance] %T", "TFRebalance_StoredItems",
		LANG_SERVER, g_iRebalance_ItemIndexChangesNumber, g_iRebalance_ClassChangesNumber);
	}
	
	return Plugin_Handled;
}

public Action Rebalance_RefreshWeapon(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "[TFRebalance] Usage: sm_refreshweapon <#userid|name>");
		return Plugin_Handled;
	}

	char cArgs[65];
	GetCmdArg(1, cArgs, sizeof(cArgs));
	
	char cTargetName[MAX_TARGET_LENGTH];
	int iTargetList[MAXPLAYERS], iTargetCount;
	bool bTargetNameIsMultiLang;
	
	if ((iTargetCount = ProcessTargetString(
			cArgs,
			iClient,
			iTargetList,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			cTargetName,
			sizeof(cTargetName),
			bTargetNameIsMultiLang)) <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < iTargetCount; i++)
		PerformRebalanceWeaponChange(iClient, iTargetList[i]);
	
	if (bTargetNameIsMultiLang)
		ShowActivity2(iClient, "[TFRebalance] ", "%t", "TFRebalance_RefreshedWeapon", cTargetName);
	else
		ShowActivity2(iClient, "[TFRebalance] ", "%t", "TFRebalance_RefreshedWeapon", "_s", cTargetName);
	
	return Plugin_Handled;
}

void PerformRebalanceWeaponChange(int iClient, int iTarget)
{
	ChangeWeaponsToBalancedState(iTarget);
	LogAction(iClient, iTarget, "\"%L\" changed weapons to rebalanced equivalens on \"%L\"", iClient, iTarget);
}

// Command that makes weapon transparent (this is basically ripped from randomizer, so credit to Flaminsarge)
public Action WeaponTransparency(int iClient, int iArgs)
{
	if (!g_bEnablePlugin.BoolValue)
	{
		//  The plugin is not enabled. We can not make your weapons transparent.
		ReplyToCommand(iClient, "[TFRebalance] %t", "TFRebalance_Disabled_NoTransparency");
		return Plugin_Handled;
	}
	else if (!IsValidClient(iClient))
	{
		// You're not a valid player (are you rcon? the console?)
		ReplyToCommand(iClient, "[TFRebalance] %t", "TFRebalance_InvalidPlayer");
		return Plugin_Handled;
	}
	else if (TF2_GetPlayerClass(iClient) == TFClass_Unknown)
	{
		// We can only make your weapons transparent if you spawn in as a class.
		ReplyToCommand(iClient, "[TFRebalance] %t", "TFRebalance_InvalidClass_NoTransparency");
		return Plugin_Handled;
	}

	char cPreference[32];
	if (g_bWeaponVis[iClient])
	{
		for	(int i = 0; i <= TFWeaponSlot_Melee; i++)
		{
			int iWeaponFromSlot = GetPlayerWeaponSlot(iClient, i);
		
			if (IsValidEntity(iWeaponFromSlot))
			{
				SetEntityRenderMode(iWeaponFromSlot, RENDER_NORMAL);
				SetEntityRenderColor(iWeaponFromSlot, 255, 255, 255, 255);
			}
		}
		
		g_bWeaponVis[iClient] = false;
		// Your weapons have returned to normal.
		ReplyToCommand(iClient, "[TFRebalance] %t", "TFRebalance_NormalWeapon");
	}
	else
	{
		SetWeaponsAsTransparent(iClient);
		
		g_bWeaponVis[iClient] = true;
		// Your weapons are now transparent.
		ReplyToCommand(iClient, "[TFRebalance] %t", "TFRebalance_TransparentWeapon");
	}
	
	Format(cPreference, sizeof(cPreference), "%i", g_bWeaponVis[iClient]);
	SetClientCookie(iClient, g_CookieWeaponVis, cPreference);

	return Plugin_Handled;
}

// 
public Action WeaponInfoToggle(int iClient, int iArgs)
{
	if (!g_bEnablePlugin.BoolValue)
	{
		//  The plugin is not enabled.
		ReplyToCommand(iClient, "[TFRebalance] %t", "TFRebalance_Disabled");
		return Plugin_Handled;
	}
	else if (!IsValidClient(iClient))
	{
		// You're not a valid player (are you rcon? the console?)
		ReplyToCommand(iClient, "[TFRebalance] %t", "TFRebalance_InvalidPlayer");
		return Plugin_Handled;
	}

	char cPreference[32];
	g_bInfoOnSpawn[iClient] = !g_bInfoOnSpawn[iClient];
	
	if (g_bInfoOnSpawn[iClient]) ReplyToCommand(iClient, "[TFRebalance] %t", "TFRebalance_SpawnInfoToggledOn");
	else ReplyToCommand(iClient, "[TFRebalance] %t", "TFRebalance_SpawnInfoToggledOff");
	
	Format(cPreference, sizeof(cPreference), "%i", g_bInfoOnSpawn[iClient]);
	SetClientCookie(iClient, g_CookieWeaponSpawnInfo, cPreference);

	return Plugin_Handled;
}

public void SetWeaponsAsTransparent(int iClient)
{
	for	(int i = 0; i <= TFWeaponSlot_Melee; i++)
	{
		int iWeaponFromSlot = GetPlayerWeaponSlot(iClient, i);

		if (IsValidEntity(iWeaponFromSlot))
		{
			SetEntityRenderMode(iWeaponFromSlot, RENDER_TRANSCOLOR);
			SetEntityRenderColor(iWeaponFromSlot, 255, 255, 255, g_iWepTransparencyValue.IntValue);
		}
	}
}

public Action Event_PlayerSpawn(Handle hEvent, const char[] cName, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (IsValidClient(iClient) && g_bEnablePlugin.BoolValue)
	{	
		// We tell the player, only on their first spawn, that their weapons and class are modified.
		if (!g_bFirstSpawn[iClient] && g_bFirstTimeInfoOnSpawn.BoolValue)
		{
			// The weapons you'll play with have been modified and balanced by this server.\nType /changes to learn more about what changed.
			CPrintToChat(iClient, "{unique}%t", "TFRebalance_CustomWarning");
			g_bFirstSpawn[iClient] = true;
		}
		// We only do this whenever we get a new set of weapons.
		else if (g_bInfoEverySpawn.IntValue > 0 && g_bInfoOnSpawn[iClient] &&
		StrEqual("post_inventory_application", cName))
		{
			int iWeaponCountChanged = GetChangedWeaponsCount(iClient);
		
			if (iWeaponCountChanged > 0)
			{
				// PrintToServer("total: %i", iWeaponCountChanged);
				CPrintToChat(iClient, "%t", "TFRebalance_SpawnInfo",
				iWeaponCountChanged);
			}
		}
		
		// This is the part where we give the player the attributes.
		TFClassType tfClassModified = TF2_GetPlayerClass(iClient); // We fetch the client's class
		
		if (g_bIsTF2AttributesEnabled)
		{		
			// Extra validation to make sure CharacterAttributes don't get wiped off
			// MvM giants and such.
			if (CanClientReceiveClassAttributes(iClient))
			{
				// We wipe class attributes if they can receive them.
				TF2Attrib_RemoveAll(iClient);
				
				// If a weapon's definition index matches with the one stored...
				if (g_bRebalance_ClassChanged[tfClassModified] == true)
				{
					int iAdded = 1;
					
					// Attribute additions:
					// As long as iAdded is less than the attributes we'll stored...
					while (iAdded <= g_iRebalance_ClassAttribute_AddNumber[tfClassModified])
					{
						//PrintToServer("Added %i to class", Rebalance_ClassAttribute_Add[tfClassModified][iAdded]);
						// Then we'll add one attribute in.
						TF2Attrib_SetByDefIndex(iClient, 
						g_iRebalance_ClassAttribute_Add[tfClassModified][iAdded],
						view_as<float>(g_fRebalance_ClassAttribute_AddValue[tfClassModified][iAdded]));
						
						iAdded++; // We increase one on this int.
					}
				}
			}
		}

		
		// If the changetimer convar is non-zero, we create a timer that changes the weapons
		// after such time.
		if (g_fChangeWeaponOnTimer.FloatValue > 0)
		{	
			// If the client is not eligible for a changed weapon, we stop this part of the plugin.
			if (!IsClientEligibleForWeapon(iClient)) return Plugin_Handled;
			else if (g_bTimerOnlyAffectsBots.BoolValue && !IsFakeClient(iClient)) return Plugin_Handled;
			
			CreateTimer(g_fChangeWeaponOnTimer.FloatValue, Timer_ChangeWeapons, iClient, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		if (g_bWeaponVis[iClient] == true)
		{
			if (g_fChangeWeaponOnTimer.FloatValue > 0 && !g_bTimerOnlyAffectsBots.BoolValue)
				CreateTimer(g_fChangeWeaponOnTimer.FloatValue, Timer_ChangeWeapons, iClient, TIMER_FLAG_NO_MAPCHANGE);
			else
				SetWeaponsAsTransparent(iClient);
		}
	}
	
	return Plugin_Continue;
}

// This timer function will make weapons transparent after some time.
public Action Timer_MakeWeaponsTransparent(Handle hTimer, int iClient)
{
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && g_bEnablePlugin.BoolValue)
		SetWeaponsAsTransparent(iClient);
		
	return Plugin_Continue;
}

// Timer function that will give weapons to a player if sm_tfrebalance_changetimer is higher than zero.
public Action Timer_ChangeWeapons(Handle hTimer, int iClient)
{
	ChangeWeaponsToBalancedState(iClient);
	return Plugin_Continue;
}

public void ChangeWeaponsToBalancedState(int iClient)
{
	// Is the client valid, are they alive and is the plugin enabled?
	// We check if the client is alive in case they suicided or died really quickly.
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) && g_bEnablePlugin.BoolValue)
	{
		// Various ints related to the client's weapons and their definition indexes.
		int iPrimary, iPrimaryIndex, iSecondary, iSecondaryIndex, iMelee, iMeleeIndex, iBuilding, iBuildingIndex;
		TFClassType iClass;
		
		// We get the client's class.
		iClass = TF2_GetPlayerClass(iClient);
		
		// primary weapon and def index:
		iPrimary = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Primary);
		if (iPrimary != -1) iPrimaryIndex = GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex");
		
		// secondary weapon and def index:
		iSecondary = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Secondary);
		if (iSecondary != -1) iSecondaryIndex = GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex");
		
		// melee weapon and def index:
		iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
		if (iMelee != -1) iMeleeIndex = GetEntProp(iMelee, Prop_Send, "m_iItemDefinitionIndex");

		// building weapon and def index:
		if (iClass == TFClass_Spy)
		{
			iBuilding = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Building);
			if (iBuilding != -1) iBuildingIndex = GetEntProp(iBuilding, Prop_Send, "m_iItemDefinitionIndex");
		}

		// Debug stuff:
		// PrintToConsole(iClient, "iPrimary: %i (Index: %i)\niSecondary: %i (Index: %i)\niMelee: %i (Index: %i)", iPrimary, iPrimaryIndex, iSecondary, iSecondaryIndex, iMelee, iMeleeIndex);
		
		// Int where we'll store which slot we'll remove.
		int iWeaponSlotToRemove = -1;
		
		// We go through all the weapons we've modified to see if we can replace the player's weapon
		// with another one that matches the index id.
		for (int i = 0; i < g_iRebalance_ItemIndexChangesNumber; i++)
		{			
			// If a weapon's definition index matches with the one stored...
			if (iPrimaryIndex == g_iRebalance_ItemIndexDef[i] ||
			iSecondaryIndex == g_iRebalance_ItemIndexDef[i] ||
			iMeleeIndex == g_iRebalance_ItemIndexDef[i] ||
			iBuildingIndex == g_iRebalance_ItemIndexDef[i])
			{
				// Here we'll store the weapon entity we'll replace.
				int iWeaponToChange = -1;
				
				if (iPrimaryIndex == g_iRebalance_ItemIndexDef[i]) // If primary...
				{
					iWeaponSlotToRemove = TFWeaponSlot_Primary; // We'll remove the primary...
					iWeaponToChange = iPrimary; // And use the primary as a reference for the weapon we'll change.
				}
				else if (iSecondaryIndex == g_iRebalance_ItemIndexDef[i]) // If secondary...
				{
					iWeaponSlotToRemove = TFWeaponSlot_Secondary; // We'll remove the secondary...
					iWeaponToChange = iSecondary; // And use the secondary as a reference for the weapon we'll change.
				}
				else if (iMeleeIndex == g_iRebalance_ItemIndexDef[i]) // If melee...
				{
					iWeaponSlotToRemove = TFWeaponSlot_Melee; // We'll remove the melee...
					iWeaponToChange = iMelee; // And use the melee as a reference for the weapon we'll change.
				}
				else if (iBuildingIndex == g_iRebalance_ItemIndexDef[i]) // If watch...
				{
					iWeaponSlotToRemove = TFWeaponSlot_Building; // We'll remove the watch...
					iWeaponToChange = iBuilding; // And use the watch as a reference for the weapon we'll change.
				}
				
				if (g_bDebugGiveWeapons.BoolValue)
				{
					PrintToServer("Timer_ChangeWeapons: Parsing %N's weapon with id %i...",
					iClient, g_iRebalance_ItemIndexDef[i]);
				}
				
				// We will add as many attributes as put on the attributes file.
				int iAdded = 1;
				
				// If the weapon we want to change is valid...
				if (IsValidEntity(iWeaponToChange) && iWeaponToChange > 0)
				{				
					// TF2Items: we'll create a handle here that'll store the item we'll replace.
					Handle hWeaponReplacement = TF2Items_CreateItem(OVERRIDE_ALL);
					
					// We set a char variable with fists as a fallback (this should never happen).
					char cWeaponClassname[64] = "tf_weapon_fists"; // Fists as fallback.
					
					// We'll get the classname from the entity we're basing it from, then set it as the classname we'll use.
					GetEntityClassname(iWeaponToChange, cWeaponClassname, sizeof(cWeaponClassname));
					TF2Items_SetClassname(hWeaponReplacement, cWeaponClassname);
					
					// We'll use the stored item definition index as the weapon index we'll create. 
					TF2Items_SetItemIndex(hWeaponReplacement, g_iRebalance_ItemIndexDef[i]);			
					
					// We get the quality and level of the item we're trying to re-recreate.
					// Quality 10 is "Customized" and the default level is random as fallbacks.
					int iItemQuality = 10, iItemLevel = GetRandomInt(1, 100);
					iItemQuality = GetEntProp(iWeaponToChange, Prop_Send, "m_iEntityQuality");
					iItemLevel = GetEntProp(iWeaponToChange, Prop_Send, "m_iEntityLevel");
					
					TF2Items_SetQuality(hWeaponReplacement, iItemQuality);
					TF2Items_SetLevel(hWeaponReplacement, iItemLevel);
					
					if (g_bRebalance_ShouldItemPreserveAttributes[i]) // If we preserve attributes.
					{
						// We get the static attributes of the weapon we're parsing through tf2attributes.
						// Since we're creating a whole new weapon, this is sort of required.
						if (g_bIsTF2AttributesEnabled)
						{
							// We create a bunch of variables meant to declare the number of static and total attributes,
							// and the attributes and their values gotten through TF2Attrib_GetStaticAttribs.
							int iNumOfStaticAttributes = 0, iNumOfTotalAttributes = -1, iAttribIndexes[16];
							float fAttribValues[16];
							iNumOfStaticAttributes = TF2Attrib_GetStaticAttribs(g_iRebalance_ItemIndexDef[i], iAttribIndexes, fAttribValues) - 1;
							
							// Attribute additions:
							// We'll add the static attributes first.
							if (g_bDebugGiveWeapons.BoolValue)
							{
								PrintToServer("Keepattribs is enabled. Static attribute total: %i", iNumOfStaticAttributes);
							}
							
							// We set the total attributes to be the static ones + the ones we wanna add.
							iNumOfTotalAttributes = iNumOfStaticAttributes + g_iRebalance_ItemAttribute_AddNumber[i];
							TF2Items_SetNumAttributes(hWeaponReplacement, iNumOfTotalAttributes);
							
							while (iAdded <= iNumOfStaticAttributes)
							{
								// Attribute debug stuff.
								if (g_bDebugGiveWeapons.BoolValue)
								{
									PrintToServer("Added static attribute %i with value %f to weapon (iAdded: %i)",
									iAttribIndexes[iAdded-1], fAttribValues[iAdded-1], iAdded);
								}
								// Then we'll add one attribute in.
								if (iAttribIndexes[iAdded-1] != 0)
								{
									TF2Items_SetAttribute(hWeaponReplacement, iAdded - 1,
									iAttribIndexes[iAdded-1], fAttribValues[iAdded-1]);
									iAdded++; // We increase one on this int.
								}
								else
								{
									LogAction(-1, -1, "[TFRebalance %s] Weapon with ID %i was attempted to be given 0 as an static attribute (iAdded: %i).",
									PLUGIN_VERSION, g_iRebalance_ItemIndexDef[i], iAdded);
									
									if (g_bDebugGiveWeapons.BoolValue)
									{
										PrintToServer("Weapon with ID %i was attempted to be given an invalid static attribute (iAdded: %i).",
										PLUGIN_VERSION, g_iRebalance_ItemIndexDef[i], iAdded);
									}
									
									break;
								}
											
							}
							
							// Afterwards, we'll add the attributes from the keyvalues file.
							int iAddedKv = 1; 
							while (iAddedKv <= g_iRebalance_ItemAttribute_AddNumber[i])
							{
								if (g_bDebugGiveWeapons.BoolValue)
								{
									PrintToServer("Added keyvalues attribute %i with value %f to weapon (iAdded: %i)",
									g_iRebalance_ItemAttribute_Add[i][iAddedKv],
									view_as<float>(g_fRebalance_ItemAttribute_AddValue[i][iAddedKv]), iAdded);
								}
								// Then we'll add one attribute in.
								TF2Items_SetAttribute(hWeaponReplacement, iAdded - 1,
								g_iRebalance_ItemAttribute_Add[i][iAddedKv], view_as<float>(g_fRebalance_ItemAttribute_AddValue[i][iAddedKv]));
								
								iAddedKv++; // We increase one on this int.
								iAdded++; // Another one in this one too.
							}
						}
						else
						{
							PrintToServer("[TFRebalance %s] tf2attributes is required in order to preserve attributes alongside tf_rebalance_changetimer. "
							... "Please install tf2attributes for this to work.", PLUGIN_VERSION);
							LogMessage("[TFRebalance %s] tf2attributes is required for tf_rebalance_changetimer and the \"keepattribs\" keyvalue to work in unison. "
							... "Please install tf2attributes for this to work.", PLUGIN_VERSION);
						}

					}
					else // If we *don't* preserve attributes.
					{					
						// We add as many attributes as we put on the keyvalues file.
						TF2Items_SetNumAttributes(hWeaponReplacement, g_iRebalance_ItemAttribute_AddNumber[i]);
						
						// Attribute additions:
						// As long as iAdded is less than the attributes we'll stored...
						while (iAdded <= g_iRebalance_ItemAttribute_AddNumber[i])
						{
							if (g_bDebugGiveWeapons.BoolValue)
							{
								PrintToServer("Added keyvalues attribute %i with value %f to weapon (iAdded: %i)",
								g_iRebalance_ItemAttribute_Add[i][iAdded],
								view_as<float>(g_fRebalance_ItemAttribute_AddValue[i][iAdded]), iAdded);
							}
							// Then we'll add one attribute in.
							TF2Items_SetAttribute(hWeaponReplacement, iAdded - 1,
							g_iRebalance_ItemAttribute_Add[i][iAdded], view_as<float>(g_fRebalance_ItemAttribute_AddValue[i][iAdded]));
							
							iAdded++; // We increase one on this int.
						}						
					}
					
					// We'll remove the player's current weapon.
					TF2_RemoveWeaponSlot(iClient, iWeaponSlotToRemove);					

					// We create a int variable for the weapon we've created.
					int iNewIndex = TF2Items_GiveNamedItem(iClient, hWeaponReplacement);
					
					// Then we'll close the handle that was the weapon in question and then we'll equip it to the player.
					CloseHandle(hWeaponReplacement);
					EquipPlayerWeapon(iClient, iNewIndex);
				}
			}
		}
	}
}

// This TF2Items forward changes the item after it's initialized.
public Action TF2Items_OnGiveNamedItem(int iClient, char[] cClassname, int iItemDefinitionIndex, Handle &hWeaponReplacement)
{	
	// If the client's valid, the plugin's enabled
	if (IsValidClient(iClient) && g_bEnablePlugin.BoolValue) 
	{		
		// If the client is not eligible for a changed weapon, we stop this part of the plugin.
		if (!IsClientEligibleForWeapon(iClient)) return Plugin_Continue;
		
		// We go through all the weapons we've modified to see if we can replace the player's weapon
		// with another one.
		for (int i = 0; i < g_iRebalance_ItemIndexChangesNumber; i++)
		{			
			// If a weapon's definition index matches with the one stored...
			if (iItemDefinitionIndex == g_iRebalance_ItemIndexDef[i])
			{		
				// We will add as many attributes as put on the attributes file.
				int iAdded = 1;
				
				hWeaponReplacement = TF2Items_CreateItem(0);
				
				if (g_bRebalance_ShouldItemPreserveAttributes[i]) // If we preserve attributes.
				{
					TF2Items_SetFlags(hWeaponReplacement, OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES);
					
					if (g_bDebugGiveWeapons.BoolValue)
					{
						PrintToServer("Attributes will be preserved on %i",
						iItemDefinitionIndex);
					}
					
					// We get the current attributes the item has.
					int iCurrentAttributeNumber = TF2Items_GetNumAttributes(hWeaponReplacement);
					// iAdded will start where the new attributes will be.
					iAdded = iCurrentAttributeNumber + 1;
					// We set the old number of attributes + the new ones we'll add.
					TF2Items_SetNumAttributes(hWeaponReplacement, iCurrentAttributeNumber + g_iRebalance_ItemAttribute_AddNumber[i]);
					
					// Attribute additions:
					// As long as iAdded is less than the attributes we'll stored...
					while (iAdded <= g_iRebalance_ItemAttribute_AddNumber[i] + iCurrentAttributeNumber)
					{
						if (g_bDebugGiveWeapons.BoolValue)
						{
							PrintToServer("Added keyvalues attribute %i with value %f to weapon (iAdded: %i)",
							g_iRebalance_ItemAttribute_Add[i][iAdded],
							view_as<float>(g_fRebalance_ItemAttribute_AddValue[i][iAdded]), iAdded);
						}
						// Then we'll add one attribute in.
						TF2Items_SetAttribute(hWeaponReplacement, iAdded - 1,
						g_iRebalance_ItemAttribute_Add[i][iAdded], view_as<float>(g_fRebalance_ItemAttribute_AddValue[i][iAdded]));
						
						iAdded++; // We increase one on this int.
					}					
				}	
				else // If we *don't* preserve attributes.
				{
					// TF2Items: we'll create a handle here that'll store the item we'll replace.
					TF2Items_SetFlags(hWeaponReplacement, OVERRIDE_ATTRIBUTES);
				
					// We add as many attributes as we put on the keyvalues file.
					TF2Items_SetNumAttributes(hWeaponReplacement, g_iRebalance_ItemAttribute_AddNumber[i]);
					// Attribute additions:
					// As long as iAdded is less than the attributes we'll stored...
					
					while (iAdded <= g_iRebalance_ItemAttribute_AddNumber[i])
					{
						if (g_bDebugGiveWeapons.BoolValue)
						{
							PrintToServer("Added keyvalues attribute %i with value %f to weapon (iAdded: %i)",
							g_iRebalance_ItemAttribute_Add[i][iAdded],
							view_as<float>(g_fRebalance_ItemAttribute_AddValue[i][iAdded]), iAdded);
						}
						// Then we'll add one attribute in.
						TF2Items_SetAttribute(hWeaponReplacement, iAdded - 1,
						g_iRebalance_ItemAttribute_Add[i][iAdded], view_as<float>(g_fRebalance_ItemAttribute_AddValue[i][iAdded]));
						
						iAdded++; // We increase one on this int.
					}
				}
				
				return Plugin_Changed;
			}
		}
	}
	
	
	return Plugin_Continue;
}

public Action RebalancedHelp(int iClient, int iArgs)
{
	// We check over here if the client is valid.
	if (!IsValidClient(iClient))
	{
		ReplyToCommand(iClient, "[TFRebalance] %t", "TFRebalance_InvalidPlayer");
		return Plugin_Handled;
	}
	
	// We create the handle for the menu we wish to create.
	Handle hRebalanceMenu = INVALID_HANDLE;
	hRebalanceMenu = CreateMenu(RebalancePanel);

	bool bWasAChangeMade = false;
	
	// We get the class of the player.
	TFClassType iClientClass = TF2_GetPlayerClass(iClient);
	// Int that indicates if the selection should show.
	int iClassStyle = ITEMDRAW_IGNORE;
	
	// If changes were made to the class and if it has a description, then we set the item
	// style to default (it will show).
	if (g_bRebalance_ClassChanged[iClientClass] && g_bRebalance_DoesClassHaveDescription[iClientClass])
	{
		iClassStyle = ITEMDRAW_DEFAULT;
		bWasAChangeMade = true;
	}
	// We add the class menu item. It will or will not show depending if there's a change in the class.
	char cCurrentClass[64]; // Localizable string.
	Format(cCurrentClass, sizeof(cCurrentClass), "%T", "TFRebalance_CurrentClass", iClient);
	AddMenuItem(hRebalanceMenu, "#class", cCurrentClass, iClassStyle);
	
	// Weapon Items
	// We check through all of the player's slots, and make a item menu
	// for each slot that has changes.
	for (int i = 0; i <= TFWeaponSlot_PDA; i++)
	{
		// cInfoString will contain the info for the menu item.
		// cSlotName is the string with the slot name meant for the item display.
		char cInfoString[16] = "#slot", cSlotName[64];
		// Ints for menu item style and the entity in the weapon slot, if any.
		int iWeaponStyle = ITEMDRAW_IGNORE, iWeaponSlotEntity = -1;
		
		// Switch statement that modifies the slotname string to be
		// the adequate one to display.
		switch (i)
		{
			case TFWeaponSlot_Primary: 		Format(cSlotName, sizeof(cSlotName), "%T", "TFRebalance_Primary", iClient);
			case TFWeaponSlot_Secondary: 	Format(cSlotName, sizeof(cSlotName), "%T", "TFRebalance_Secondary", iClient);
			case TFWeaponSlot_Melee: 		Format(cSlotName, sizeof(cSlotName), "%T", "TFRebalance_Melee", iClient);
			case TFWeaponSlot_Grenade: 		Format(cSlotName, sizeof(cSlotName), "%T", "TFRebalance_Grenade", iClient);
			case TFWeaponSlot_Building: 	Format(cSlotName, sizeof(cSlotName), "%T", "TFRebalance_Building", iClient);
			case TFWeaponSlot_PDA: 			Format(cSlotName, sizeof(cSlotName), "%T", "TFRebalance_PDA", iClient);
		}
		
		// We turn the slot int into a string to put it on the infostring
		// meant for the menu item.
		char cItemSlot[2];
		IntToString(i, cItemSlot, sizeof(cItemSlot));
		StrCat(cInfoString, sizeof(cInfoString), cItemSlot);
		
		// We get the weapon entity from the slot if any.
		iWeaponSlotEntity = GetPlayerWeaponSlot(iClient, i);
		// We make sure the entity exists here before we proceed.
		if (iWeaponSlotEntity != -1 && IsValidEntity(iWeaponSlotEntity))
		{
			// We get the weapon's def index, if it's valid we'll cycle through all the weapons
			// that have changes.
			int iWeaponIndex = GetEntProp(iWeaponSlotEntity, Prop_Send, "m_iItemDefinitionIndex");
			if (iWeaponIndex != -1)
			{
				// We cycle through the stored weapon IDs.
				for (int j = 0; j < g_iRebalance_ItemIndexChangesNumber; j++)
				{			
					// If a weapon's definition index matches with the one stored...
					if (iWeaponIndex == g_iRebalance_ItemIndexDef[j])
					{			
						if (g_bRebalance_DoesItemHaveDescription[j])
						{	
							// Then we'll display the item, as it is a weapon with changes.
							iWeaponStyle = ITEMDRAW_DEFAULT;
							bWasAChangeMade = true;
							// We don't need to cycle through the rest.
							break;
						}
					}
				}				
			}
		}
		
		// We add the menu item for the slot we processed.
		AddMenuItem(hRebalanceMenu, cInfoString, cSlotName, iWeaponStyle);
	}
	
	// Cosmetic items
	// Ints for the wearable entity and the itemdraw style.
	int iWearableItem = -1, iWearableStyle = ITEMDRAW_IGNORE, iNumberOfCosmetics = 0;
	
	// We cycle through the wearables
	// We try to find wearable items that belong to the client.
	while ((iWearableItem = FindEntityByClassname(iWearableItem, "tf_wearable*")) != -1) // Regular hats.
	{	
		// We check for the wearable's item def index and its owner.
		int iWearableIndex = GetEntProp(iWearableItem, Prop_Send, "m_iItemDefinitionIndex");
		int iWearableOwner = GetEntPropEnt(iWearableItem, Prop_Send, "m_hOwnerEntity");
		
		// If the owners match.
		if (iWearableOwner == iClient)
		{
			// Going through all items.
			for (int i = 0; i < g_iRebalance_ItemIndexChangesNumber; i++)
			{			
				// If a weapon's definition index matches with the one stored...
				if (iWearableIndex == g_iRebalance_ItemIndexDef[i])
				{
					if (g_bRebalance_DoesItemHaveDescription[i])
					{
						// We'll display the item, as it is a weapon with changes.
						iWearableStyle = ITEMDRAW_DEFAULT;
						bWasAChangeMade = true;
					
						// We'll concatenate the string with the ID of the item.
						char cCosmeticString[16] = COSMETIC_MENUCHOICE, cItemIndex[7];
						IntToString(i, cItemIndex, sizeof(cItemIndex));
						StrCat(cCosmeticString, sizeof(cCosmeticString), cItemIndex);
						
						// PrintToServer("%s", cCosmeticString);
						
						// We'll add as many items as there are edited cosmetics.
						char cCosmetics[64]; // Localizable string
						Format(cCosmetics, sizeof(cCosmetics), "%T", "TFRebalance_Cosmetics", iClient, iNumberOfCosmetics + 1);
						AddMenuItem(hRebalanceMenu, cCosmeticString, cCosmetics, iWearableStyle);
					
						// We'll add one item per cosmetic changed.
						iNumberOfCosmetics++;
					}
				}
			}
		}
	}
	
	char cTitle[128]; // Localizable string;
	if (!bWasAChangeMade)
		CPrintToChat(iClient, "{red}%t", "TFRebalance_NoChange");
	else
		Format(cTitle, sizeof(cTitle), "%T", "TFRebalance_InfoChoose", iClient);
		
	SetMenuTitle(hRebalanceMenu, cTitle);
	
	// We finally display the menu.
	DisplayMenu(hRebalanceMenu, iClient, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public int RebalancePanel(Handle hMenu, MenuAction maAction, int iParam1, int iParam2)
{
	// Switch will all menuactions (we're really only using Select, though...)
	switch(maAction)
	{
		// If someone selects an action (iParam1 = client, iParam2 = item)
		case MenuAction_Select:
		{
			// We create a char with the menu item info and another
			// char that will contain the item description
			char cInfo[32], cThingInformation[MAXIMUM_DESCRIPTIONLIMIT];
			// We get a bool that makes sure if our item exists, also
			// cInfo gets the item info string.
			bool bFound = GetMenuItem(hMenu, iParam2, cInfo, sizeof(cInfo));
			// Debug string
			// PrintToConsole(iParam1, "You selected item: %d (found? %d info: %s)", iParam2, bFound, cInfo);
			
			// If the menu item exists.
			if (bFound)
			{
				// We create a handle and a menu for the handle.
				Handle hRebalanceInfo = INVALID_HANDLE;
				hRebalanceInfo = CreateMenu(RebalanceInformation);
			
				// Has the user selected a class?
				if (StrEqual(cInfo, "#class"))
				{
					// PrintToConsole(iParam1, "Class was selected");
					// We concatenate the class info string.
					char cClassInfo[64]; // Localizable string
					Format(cClassInfo, sizeof(cClassInfo), "%T", "TFRebalance_ClassInfo", iParam1);
					StrCat(cThingInformation, sizeof(cThingInformation), cClassInfo);
					StrCat(cThingInformation, sizeof(cThingInformation), "\n");
					
					// We get the class of the client.
					TFClassType iClass = TF2_GetPlayerClass(iParam1);
					// If the class had changes and has a description, then we 
					// concatenate the description to the title.
					if (g_bRebalance_ClassChanged[iClass] && g_bRebalance_DoesClassHaveDescription[iClass])
						StrCat(cThingInformation, sizeof(cThingInformation),
							g_cRebalance_ClassDescription[iClass]);
				}
				// Has the user selected an item slot.
				else if (StrContains(cInfo, "#slot") != -1)
				{
					// We get the slot int directly from the sixth character
					// of the cInfo char.
					int iSlot = StringToInt(cInfo[5]);
					
					// Chars that will contain the slot name string and the info bit.
					char cSlotName[64], cInformation[128];
					switch (iSlot)
					{
						case TFWeaponSlot_Primary: 		Format(cSlotName, sizeof(cSlotName), "%T", "TFRebalance_Primary", iParam1);
						case TFWeaponSlot_Secondary: 	Format(cSlotName, sizeof(cSlotName), "%T", "TFRebalance_Secondary", iParam1);
						case TFWeaponSlot_Melee: 		Format(cSlotName, sizeof(cSlotName), "%T", "TFRebalance_Melee", iParam1);
						case TFWeaponSlot_Grenade: 		Format(cSlotName, sizeof(cSlotName), "%T", "TFRebalance_Grenade", iParam1);
						case TFWeaponSlot_Building: 	Format(cSlotName, sizeof(cSlotName), "%T", "TFRebalance_Building", iParam1);
						case TFWeaponSlot_PDA: 			Format(cSlotName, sizeof(cSlotName), "%T", "TFRebalance_PDA", iParam1);
					}
					
					// We format and concatenate these two strings into the main one.
					Format(cInformation, sizeof(cInformation), "%T", "TFRebalance_WeaponInfo", iParam1, cSlotName);
					StrCat(cThingInformation, sizeof(cThingInformation), cInformation);
					StrCat(cThingInformation, sizeof(cThingInformation), "\n");
					
					// We get the player's weapon entity from the weapon slot
					// which they selected on the previous menu.
					int iWeaponInSlot = GetPlayerWeaponSlot(iParam1, iSlot);
					
					// If the weapon entity is valid...
					if (IsValidEntity(iWeaponInSlot))
					{
						// We get the item's item def index.
						int iWeaponDefinitionIndex = GetEntProp(iWeaponInSlot, Prop_Send, "m_iItemDefinitionIndex");
						
						// If it has one...
						if (iWeaponDefinitionIndex != -1)
						{
							// We cycle through the stored weapon IDs.
							for (int i = 0; i < g_iRebalance_ItemIndexChangesNumber; i++)
							{	
								// If a weapon's definition index matches with the one stored...
								if (iWeaponDefinitionIndex == g_iRebalance_ItemIndexDef[i])
								{				
									// We concatenate the item's description onto the menu's title
									// if it has any description at all.
									if (g_bRebalance_DoesItemHaveDescription[i])
									{
										StrCat(cThingInformation, sizeof(cThingInformation),
										g_cRebalance_ItemDescription[i]);
		
										// We break the loop, there's no need to cycle through more.
										break;
									}
								}
							}				
						}
					}
				}
				// Has the user selected the cosmetic slot.
				else if (StrContains(cInfo, COSMETIC_MENUCHOICE) != -1)
				{
					// PrintToConsole(iParam1, "Cosmetic selected");
					// We'll get the ID of the item that we're getting info from.
					char cCosmeticIndex[8];
					for	(int i = strlen(COSMETIC_MENUCHOICE), iNumericChars = 0; i < strlen(cInfo); i++)
					{
						cCosmeticIndex[iNumericChars] = cInfo[i];
						iNumericChars++;
					}
					
					int iCosmeticIndex = StringToInt(cCosmeticIndex);
					
					// PrintToServer("%s - %i (%s)", cCosmeticIndex, iCosmeticIndex, cInfo);
					
					// We concatenate the info string onto the main string.
					char cCosmeticInfo[64]; // Localizable string
					Format(cCosmeticInfo, sizeof(cCosmeticInfo), "%T", "TFRebalance_CosmeticInfo", iParam1);
					StrCat(cThingInformation, sizeof(cThingInformation), cCosmeticInfo);
					StrCat(cThingInformation, sizeof(cThingInformation), "\n");
					
					// We concatenate the item's description onto the menu's title
					// if it has any description at all.
					if (g_bRebalance_DoesItemHaveDescription[iCosmeticIndex])
					{
						StrCat(cThingInformation, sizeof(cThingInformation),
						g_cRebalance_ItemDescription[iCosmeticIndex]);
						StrCat(cThingInformation, sizeof(cThingInformation),
						"\n");
						// We don't break the loop this time, as there could be
						// multiple cosmetic items. Also we concatenate a new line.
					}									
				}
				
				// We fix new lines and percentages here.
				ReplaceString(cThingInformation, sizeof(cThingInformation), "\\n", "\n");
				ReplaceString(cThingInformation, sizeof(cThingInformation), "%", "%%");
				// We set the title here, which contains the descriptions
				// for whatever that was selected.
				SetMenuTitle(hRebalanceInfo, cThingInformation);
				
				// We add a back button.
				char cBack[64]; // Localizable string
				Format(cBack, sizeof(cBack), "%T", "TFRebalance_Back", iParam1);
				AddMenuItem(hRebalanceInfo, "#back", cBack);
				// We finally display the menu to the client.
				DisplayMenu(hRebalanceInfo, iParam1, MENU_TIME_FOREVER);
			}
		}
	}
 
	return 0;
}

public int RebalanceInformation(Handle hMenu, MenuAction maAction, int iParam1, int iParam2)
{
	// Switch will all menuactions (we're really only using Select, though...)
	switch(maAction)
	{
		// If someone selects an action (iParam1 = client, iParam2 = item)
		case MenuAction_Select:
		{
			char cInfo[32]; // We create a char with the menu item info
			// We get a bool that makes sure if our item exists, also
			// cInfo gets the item info string.
			bool bFound = GetMenuItem(hMenu, iParam2, cInfo, sizeof(cInfo));
			
			if (bFound)
			{
				// We display the previous menu if the
				// player wants to go back.
				if (StrEqual(cInfo, "#back"))
					RebalancedHelp(iParam1, 0);
			}
		}
	}

	return 0;
}

public bool GetAndStoreWeaponAttributes()
{
	// We create a kv list file.
	g_hKeyvaluesAttributesFile = CreateAttributeListFile(g_hKeyvaluesAttributesFile);
	if (g_hKeyvaluesAttributesFile == INVALID_HANDLE) return false;

	// char cDebugSectionName[32] = "123";
	
	int iIDWeaponIndex = -1; // Default weapon index is -1;
	char cIDWeaponIndex[255]; // Because section names are chars even if they're numbers, we need to create a char.
	char cIDsOfWeapons[MAXIMUM_WEAPONSPERATTRIBUTESET][7]; // The IDs of weapons if multiple are put in the same attribute set.
	
	KvRewind(g_hKeyvaluesAttributesFile); // We go to the top node, woo.
	KvGotoFirstSubKey(g_hKeyvaluesAttributesFile, false); // We go to the first subkey (which should be a definition id)

	do
	{
		KvGetSectionName(g_hKeyvaluesAttributesFile, cIDWeaponIndex, sizeof(cIDWeaponIndex)); // We get the section name (either id or classes sect.)
		//iIDWeaponIndex = StringToInt(cIDWeaponIndex); // We turn the definition id string into an int for future usage, if possible.
		
		if (StrEqual("classes", cIDWeaponIndex, false)) // Classes section.
		{
			KvGotoFirstSubKey(g_hKeyvaluesAttributesFile, false); // This should be a class subkey.		
			
			do
			{
				KvGetSectionName(g_hKeyvaluesAttributesFile, cIDWeaponIndex, sizeof(cIDWeaponIndex)); // We get the class name
				
				// We get the class from the section name and we say that yes, it's a modified class.
				TFClassType tfClassModified = GetTFClassTypeFromName(cIDWeaponIndex);
				g_bRebalance_ClassChanged[tfClassModified] = true;
				g_iRebalance_ClassChangesNumber++; // One extra class we modified.
				
				// We get the information about the class.
				KvGetString(g_hKeyvaluesAttributesFile, "info",
				g_cRebalance_ClassDescription[tfClassModified],
				MAXIMUM_DESCRIPTIONLIMIT);
				
				// We set the bool to true if we set a description.
				if (!StrEqual(g_cRebalance_ClassDescription[tfClassModified], "", false))
					g_bRebalance_DoesClassHaveDescription[tfClassModified] = true;
				
				// We setup a search int for the setup attributes
				int iSearchAttributesInFile = 1;
				
				// This should be an attribute[number] subkey.
				KvGotoFirstSubKey(g_hKeyvaluesAttributesFile, false);
				
				do // LET'S PROCESS CLASS ATTRIBUTES BOY
				{
					char cAttributeAddition[16];
					// The name of the section (should be attribute[number])
					KvGetSectionName(g_hKeyvaluesAttributesFile, cAttributeAddition, sizeof(cAttributeAddition));
					
					// We setup a char variable and then we fuse it with the setup int together.
					char cAttributeString[26] = "attribute";
					Format(cAttributeString, sizeof(cAttributeString), "%s%i", cAttributeString, iSearchAttributesInFile);
				
					if (StrEqual(cAttributeAddition, cAttributeString, false)) // Adding an attribute - gets the id and value inside the attribute section.
					{
						g_iRebalance_ClassAttribute_AddNumber[tfClassModified]++; // We add one into the attribute count int we have.
						// Here we store the attribute id.
						g_iRebalance_ClassAttribute_Add[tfClassModified][g_iRebalance_ClassAttribute_AddNumber[tfClassModified]] =
						KvGetNum(g_hKeyvaluesAttributesFile, "id", 0);
						
						// Here we store the attribute value.
						g_fRebalance_ClassAttribute_AddValue[tfClassModified][g_iRebalance_ClassAttribute_AddNumber[tfClassModified]] =
						KvGetFloat(g_hKeyvaluesAttributesFile, "value", 0.0);
						
						// We increase the search int value to look for more attributes.
						iSearchAttributesInFile++;
						
						// Debug stuff:
						if (g_bDebugKeyvaluesFile.BoolValue)
						{
							PrintToServer("[TFRebalance %s] KvFileDebug: Added attribute to class %s: %i with value %f",
							PLUGIN_VERSION, cIDWeaponIndex,
							g_iRebalance_ClassAttribute_Add[tfClassModified][g_iRebalance_ClassAttribute_AddNumber[tfClassModified]],
							g_fRebalance_ClassAttribute_AddValue[tfClassModified][g_iRebalance_ClassAttribute_AddNumber[tfClassModified]]);
							//PrintToServer("%i - %i", g_iRebalance_ItemIndexChangesNumber, Rebalance_ItemAttribute_AddNumber[g_iRebalance_ItemIndexChangesNumber]);						
						}
						

					}
				}
				while (KvGotoNextKey(g_hKeyvaluesAttributesFile, false)); // Moves between attributes.
				KvGoBack(g_hKeyvaluesAttributesFile); // Into away from attributes and into another class.
			}
			while (KvGotoNextKey(g_hKeyvaluesAttributesFile, false)); // Moves between class sections.
			
			KvGoBack(g_hKeyvaluesAttributesFile); // We go back to classes
			KvGotoNextKey(g_hKeyvaluesAttributesFile, false); // Should be a weapon section.
			// We get the weapon section string.
			KvGetSectionName(g_hKeyvaluesAttributesFile, cIDWeaponIndex, sizeof(cIDWeaponIndex));
			
			// Debugging section: should be attribute[number] or something
			// KvGetSectionName(g_hKeyvaluesAttributesFile, cDebugSectionName, sizeof(cDebugSectionName));
			// PrintToServer("Now in: %s", cDebugSectionName);
		}
		
		// We get the section name (either id or classes sect.)
		ExplodeString(cIDWeaponIndex, " ; ", cIDsOfWeapons,
		MAXIMUM_WEAPONSPERATTRIBUTESET, 7, false);
		int iWeaponCountWithinString = 0;
		
		for (;;) // Don't worry! We'll break the loop after there's no more attributes left.
		{
			if (!StrEqual(cIDsOfWeapons[iWeaponCountWithinString], "", false)) // If the char is empty, then we'll stop. But if not...
			{
				//PrintToServer("Attribute %s in string", cIDsOfWeapons[iWeaponCountWithinString]); // debug string
				iIDWeaponIndex = StringToInt(cIDsOfWeapons[iWeaponCountWithinString]); // We turn the definition id string into an int for future usage, if possible.
				
				if (iIDWeaponIndex != -1) // If a weapon ID is defined
				{
					// Debug stuff:
					if (g_bDebugKeyvaluesFile.BoolValue)
					{
						PrintToServer("[TFRebalance %s] KvFileDebug: there's attributes for weapon %i, analyzing and storing...", PLUGIN_VERSION, iIDWeaponIndex);
					}
					
					// We say that the weapon on this index was changed and we store the definition ID of such.
					g_bRebalance_ItemIndexChanged[g_iRebalance_ItemIndexChangesNumber] = true;
					g_iRebalance_ItemIndexDef[g_iRebalance_ItemIndexChangesNumber] = iIDWeaponIndex;
					
					// We get the information about the weapon.
					KvGetString(g_hKeyvaluesAttributesFile, "info",
					g_cRebalance_ItemDescription[g_iRebalance_ItemIndexChangesNumber],
					MAXIMUM_DESCRIPTIONLIMIT);
					
					if (strlen(g_cRebalance_ItemDescription[g_iRebalance_ItemIndexChangesNumber]) > 0)
						g_bRebalance_DoesItemHaveDescription[g_iRebalance_ItemIndexChangesNumber] = true;
					
					// We get if the item should preserve attributes
					if (KvGetNum(g_hKeyvaluesAttributesFile, "keepattribs", g_bItemPreserveAttributesDefault.IntValue) > 0)
						g_bRebalance_ShouldItemPreserveAttributes[g_iRebalance_ItemIndexChangesNumber] = true;
					
					// We setup a search int for the setup attributes
					int iSearchAttributesInFile = 1;
					
					KvGotoFirstSubKey(g_hKeyvaluesAttributesFile, false); // This should be an attribute[number] subkey.
					
					do
					{
						char cAttributeAddition[16];
						// The name of the section (should be attribute[number])
						KvGetSectionName(g_hKeyvaluesAttributesFile, cAttributeAddition, sizeof(cAttributeAddition));
						
						// We setup a char variable and then we fuse it with the setup int together.
						char cAttributeString[26] = "attribute";
						Format(cAttributeString, sizeof(cAttributeString), "%s%i", cAttributeString, iSearchAttributesInFile);
						
						// Debugging section: should be attribute[number] or something
						// KvGetSectionName(g_hKeyvaluesAttributesFile, cDebugSectionName, sizeof(cDebugSectionName));
						// PrintToServer("Now in: %s", cDebugSectionName);
						
						if (StrEqual(cAttributeAddition, cAttributeString, false)) // Adding an attribute - gets the id and value inside the attribute section.
						{
							g_iRebalance_ItemAttribute_AddNumber[g_iRebalance_ItemIndexChangesNumber]++; // We add one into the attribute count int we have.
							// Here we store the attribute id.
							g_iRebalance_ItemAttribute_Add[g_iRebalance_ItemIndexChangesNumber][g_iRebalance_ItemAttribute_AddNumber[g_iRebalance_ItemIndexChangesNumber]] =
							KvGetNum(g_hKeyvaluesAttributesFile, "id", 0);
							
							// Here we store the attribute value.
							g_fRebalance_ItemAttribute_AddValue[g_iRebalance_ItemIndexChangesNumber][g_iRebalance_ItemAttribute_AddNumber[g_iRebalance_ItemIndexChangesNumber]] =
							KvGetFloat(g_hKeyvaluesAttributesFile, "value", 0.0);
							
							// Debug stuff:
							if (g_bDebugKeyvaluesFile.BoolValue)
							{
								PrintToServer("[TFRebalance %s] KvFileDebug: Added attribute to weapon %i: %i with value %f",
								PLUGIN_VERSION, iIDWeaponIndex,
								g_iRebalance_ItemAttribute_Add[g_iRebalance_ItemIndexChangesNumber][g_iRebalance_ItemAttribute_AddNumber[g_iRebalance_ItemIndexChangesNumber]], 
								g_fRebalance_ItemAttribute_AddValue[g_iRebalance_ItemIndexChangesNumber][g_iRebalance_ItemAttribute_AddNumber[g_iRebalance_ItemIndexChangesNumber]]);
							}
							
							// We increase the search int value to look for more attributes.
							iSearchAttributesInFile++;
						}
					}
					while (KvGotoNextKey(g_hKeyvaluesAttributesFile, false)); // Moves between attributes.
					KvGoBack(g_hKeyvaluesAttributesFile); // We go back to process the next weapon.
						
					g_iRebalance_ItemIndexChangesNumber++; // We count as many weapons as we've modified
					cIDsOfWeapons[iWeaponCountWithinString] = ""; // We blank out the string that has the weapon ID.
					iWeaponCountWithinString++; // Let's give it another attribute count.
				}
			}
			else break; // We break the loop.
		}
	}
	while (KvGotoNextKey(g_hKeyvaluesAttributesFile, true)); // Goes through weapon definition indexes.
	
	return true; // Returning true stops this.
}

public Handle CreateAttributeListFile(Handle hFile)
{
	if (hFile == INVALID_HANDLE) 
	{	
		// We create a keyvalues file for the kv list containing attributes
		hFile = CreateKeyValues("tf2rebalance_attributes"); // Keyvalues bois
		
		// We save the file.
		char cData[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, cData, PLATFORM_MAX_PATH, "data/tf2rebalance_attributes.txt"); // tf/addons/sourcemod/data/tf2rebalance_attributes.txt
		
		// We create the keyvalues
		FileToKeyValues(hFile, cData);
	}
	return hFile;
}

public TFClassType GetTFClassTypeFromName(const char[] cName)
{
	// Are you ready for this long if?
	
	if (StrEqual(cName, "scout", false)) return TFClass_Scout;
	else if (StrEqual(cName, "sniper", false)) return TFClass_Sniper;
	else if (StrEqual(cName, "soldier", false)) return TFClass_Soldier;
	else if (StrEqual(cName, "demoman", false)) return TFClass_DemoMan;
	else if (StrEqual(cName, "medic", false)) return TFClass_Medic;
	else if (StrEqual(cName, "heavy", false)) return TFClass_Heavy;
	else if (StrEqual(cName, "pyro", false)) return TFClass_Pyro;
	else if (StrEqual(cName, "spy", false)) return TFClass_Spy;
	else if (StrEqual(cName, "engineer", false)) return TFClass_Engineer;

	return TFClass_Unknown;
}

public bool CanClientReceiveClassAttributes(int iClient)
{
	if (IsFakeClient(iClient))
	{
		if (!g_bApplyClassChangesToBots.BoolValue) return false;
		else
		{
			if (g_bIsMVM
			&& TF2_GetClientTeam(iClient) == TFTeam_Blue
			&& !g_bApplyClassChangesToMvMBots.BoolValue)
			{
				return false;
			}
		}
	}
	
	return true;
}

public bool IsClientEligibleForWeapon(int iClient)
{
	if (IsFakeClient(iClient))
	{	
		if (!g_bGiveWeaponsToBots.BoolValue) return false;
		else
		{
			if (g_bIsMVM
			&& TF2_GetClientTeam(iClient) == TFTeam_Blue
			&& !g_bGiveWeaponsToMvMBots.BoolValue)
			{
				return false;
			}
		}
	}
	
	return true;
}

// Function that wipes stored attributes.
stock bool WipeStoredAttributes()
{
	// We close the keyvalues file handle.
	CloseHandle(g_hKeyvaluesAttributesFile);
	g_hKeyvaluesAttributesFile = INVALID_HANDLE;
	
	// We'll now set it to 0 items changed.
	g_iRebalance_ItemIndexChangesNumber = 0;
	
	// We set ourselves some ints to help wipe off what the variables stored.
	int i = 0, j = 0, k = 1, l = 0;
	
	while (i <= MAXIMUM_ADDITIONS - 1)
	{
		g_bRebalance_ItemIndexChanged[i] = false; // Everything to false.
		g_iRebalance_ItemIndexDef[i] = -1; // Everything to -1
		g_cRebalance_ItemDescription[i] = "";
		g_bRebalance_DoesItemHaveDescription[i] = false;
		g_bRebalance_ShouldItemPreserveAttributes[i] = false;
		
		while (j <= MAXIMUM_ATTRIBUTES - 1)
		{
			g_iRebalance_ItemAttribute_Add[i][j] = 0; // We set the attribute ids to 0 alongside the weapon correspondant to it
			g_fRebalance_ItemAttribute_AddValue[i][j] = 0.0; // We set the attribute values to 0 alongside the weapon correspondant to it
			
			j++;
		}
		
		// We set all the attributes added number to zero.
		g_iRebalance_ItemAttribute_AddNumber[i] = 0;
		
		i++;
	}
	
	while (k <= view_as<int>(TFClass_Engineer)) // the last class
	{
		g_bRebalance_ClassChanged[k] = false; // Everything to false.
		g_iRebalance_ClassAttribute_AddNumber[k] = 0; // Everything to 0 attributes.
		g_cRebalance_ClassDescription[k] = "";
		g_bRebalance_DoesClassHaveDescription[k] = false;
		
		while (l <= MAXIMUM_ATTRIBUTES - 1)
		{
			g_iRebalance_ClassAttribute_Add[k][l] = 0; // Everything set to zero attributes.
			g_fRebalance_ClassAttribute_AddValue[k][l] = 0.0; // Everything set to zero values.
			
			l++;
		}
		
		g_iRebalance_ClassChangesNumber = 0;
		
		k++;
	}
}

stock int GetChangedWeaponsCount(int iClient)
{
	int iChangedWeapons = 0;
	
	int iPrimary = -1, iSecondary = -1, iMelee = -1, iBuilding = -1;
	int iPrimaryIndex = -1, iSecondaryIndex = -1, iMeleeIndex = -1, iBuildingIndex = -1;
	
	// primary weapon and def index:
	iPrimary = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Primary);
	if (iPrimary != -1) iPrimaryIndex = GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex");
	
	// secondary weapon and def index:
	iSecondary = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Secondary);
	if (iSecondary != -1) iSecondaryIndex = GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex");
	
	// melee weapon and def index:
	iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	if (iMelee != -1) iMeleeIndex = GetEntProp(iMelee, Prop_Send, "m_iItemDefinitionIndex");

	// building weapon and def index:
	if (TF2_GetPlayerClass(iClient) == TFClass_Spy)
	{
		iBuilding = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Building);
		if (iBuilding != -1) iBuildingIndex = GetEntProp(iBuilding, Prop_Send, "m_iItemDefinitionIndex");
	}

	// Debug stuff:
	// PrintToConsole(iClient, "iPrimary: %i (Index: %i)\niSecondary: %i (Index: %i)\niMelee: %i (Index: %i)", iPrimary, iPrimaryIndex, iSecondary, iSecondaryIndex, iMelee, iMeleeIndex);
		
	// We go through all the weapons we've modified to see if we can replace the player's weapon
	// with another one that matches the index id.
	for (int i = 0; i < g_iRebalance_ItemIndexChangesNumber; i++)
	{			
		// If a weapon's definition index matches with the one stored...
		if (iPrimaryIndex == g_iRebalance_ItemIndexDef[i] ||
		iSecondaryIndex == g_iRebalance_ItemIndexDef[i] ||
		iMeleeIndex == g_iRebalance_ItemIndexDef[i] ||
		iBuildingIndex == g_iRebalance_ItemIndexDef[i])
		{
			iChangedWeapons++;
			// PrintToServer("Adding weapon (%i)...", g_iRebalance_ItemIndexDef[i]);
		}
	}
	
	// Cosmetic items
	// Ints for the wearable entity and the itemdraw style.
	int iWearableItem = -1;
	
	// We cycle through the wearables
	// We try to find wearable items that belong to the client.
	while ((iWearableItem = FindEntityByClassname(iWearableItem, "tf_wearable*")) != -1) // Regular hats.
	{	
		// We check for the wearable's item def index and its owner.
		int iWearableIndex = GetEntProp(iWearableItem, Prop_Send, "m_iItemDefinitionIndex");
		int iWearableOwner = GetEntPropEnt(iWearableItem, Prop_Send, "m_hOwnerEntity");
		
		// If the owners match.
		if (iWearableOwner == iClient)
		{
			// Going through all items.
			for (int i = 0; i < g_iRebalance_ItemIndexChangesNumber; i++)
			{			
				// If a weapon's definition index matches with the one stored...
				if (iWearableIndex == g_iRebalance_ItemIndexDef[i])
				{
					// PrintToServer("Adding cosmetic (%i)...", g_iRebalance_ItemIndexDef[i]);
					iChangedWeapons++;
				}
					
			}
		}
	}
	
	if (g_bRebalance_ClassChanged[TF2_GetPlayerClass(iClient)])
	{
		// PrintToServer("Adding class...");
		iChangedWeapons++;
	}
	
	return iChangedWeapons;
}

// Helps us know if the player counts as valid of not.
stock bool IsValidClient(int client, bool replaycheck = true)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	}
	return true;
}