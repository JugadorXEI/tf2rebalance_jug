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
#define MAXIMUM_ADDITIONS 255
#define MAXIMUM_ATTRIBUTES 20
#define MAXIMUM_DESCRIPTIONLIMIT 1000
#define MAXIMUM_WEAPONSPERATTRIBUTESET 52
//////////////////

// 1.50: Added `sm_tfrebalance_changetimer` ConVar
// If higher than zero, changes will apply to weapons after a set timer.

#define PLUGIN_VERSION "v1.43"

enum HelpType
{
	HelpType_Weapon = 1,
	HelpType_Class,
	HelpType_Wearable
};

public Plugin myinfo =
{
	name = "Rebalanced Fortress 2",
	author = "JugadorXEI",
	description = "Rebalance all of TF2's weapons based on your own changes!",
	version = PLUGIN_VERSION,
	url = "https://github.com/JugadorXEI",
}

ConVar g_bEnablePlugin; // Convar that enables plugin
ConVar g_bLogMissingDependencies; // Convar that, if enabled, will log if dependencies are missing.
ConVar g_bFirstTimeInfoOnSpawn; // Convar that displays info to the players on their first spawn that their weapons are modified.
ConVar g_bItemPreserveAttributesDefault; // Convar that controls if the attributes should be preserved by default or not.
ConVar g_bChangeWeaponOnTimer; // Convar that will change weapons or wearables after a set timer.
bool g_bFirstSpawn[MAXPLAYERS+1] = false; // Bool that indicates the player's first spawn.

// Keyvalues file for attributes
Handle g_hKeyvaluesAttributesFile = INVALID_HANDLE;

// Plugin dependencies: are they enabled or not?
bool g_bIsTF2AttributesEnabled = false;

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
	"Enables/Disables the plugin. Default = 1, 0 to disable.", FCVAR_DONTRECORD|FCVAR_PROTECTED);
	g_bLogMissingDependencies = CreateConVar("sm_tfrebalance_logdependencies", "1",
	"If any dependencies are missing from the plugin, log them on SourceMod logs. Default = 1, 0 to disable.", FCVAR_DONTRECORD|FCVAR_PROTECTED);
	g_bFirstTimeInfoOnSpawn = CreateConVar("sm_tfrebalance_firsttimeinfo", "1",
	"Displays on the first player's spawn information about the modifications done to the weapons. Default = 1, 0 to disable.", FCVAR_DONTRECORD|FCVAR_PROTECTED);
	g_bItemPreserveAttributesDefault = CreateConVar("sm_tfrebalance_preserveattribsbydefault", "0",
	"Should the weapons set on the tf2rebalance_attributes.txt file preserve attributes by default? Default = 0, 1 to enable. "
	... "This is always overriden if the weapon has a \"keepattribs\" value set on the configuration file.", FCVAR_DONTRECORD|FCVAR_PROTECTED);
	g_bChangeWeaponOnTimer = CreateConVar("sm_tfrebalance_changetimer", "0",
	"If higher than zero, the changes will be applied to weapons after a set timer (example: 0.25). Use this to increase compatibility with other plugins.", FCVAR_DONTRECORD|FCVAR_PROTECTED);
	
	// Admin command that refreshses the tf2rebalance_attributes file.
	RegAdminCmd("sm_tfrebalance_refresh", Rebalance_RefreshFile, ADMFLAG_ROOT,
	"Refreshes the attributes gotten through the file without needing to change maps. Depending on file size, it might cause a lag spike, so be careful.");
	
	// Let's hook the spawns and such.
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PlayerSpawn);
	
	// Commands for the players.
	// Weapon information command:
	RegConsoleCmd("sm_weapon_info", WeaponHelp, "Displays info for the rebalanced weapon the player is holding");
	RegConsoleCmd("sm_weapon_information", WeaponHelp, "Displays info for the rebalanced weapon the player is holding");
	RegConsoleCmd("sm_weapon_changes", WeaponHelp, "Displays info for the rebalanced weapon the player is holding");
	
	// Class information command:
	RegConsoleCmd("sm_class_info", ClassHelp, "Displays info for the rebalanced class");
	RegConsoleCmd("sm_class_information", ClassHelp, "Displays info for the rebalanced class");
	RegConsoleCmd("sm_class_changes", ClassHelp, "Displays info for the rebalanced class");
	
	// Wearable information command:
	RegConsoleCmd("sm_wearable_info", WearableHelp, "Displays info for the rebalanced wearables");
	RegConsoleCmd("sm_wearable_information", WearableHelp, "Displays info for the rebalanced wearables");
	RegConsoleCmd("sm_wearable_changes", WearableHelp, "Displays info for the rebalanced wearables");
}

public void OnMapStart()
{
	WipeStoredAttributes(); // Function that sets every Rebalance_* variable and the Handle to 0/INVALID_HANDLE;
	if (GetAndStoreWeaponAttributes()) // Function that stores the weapon changes on the variables.
	{
		PrintToServer("[TFRebalance %s] Stored %i weapons and %i classes in total to change.", PLUGIN_VERSION,
		g_iRebalance_ItemIndexChangesNumber, g_iRebalance_ClassChangesNumber);
	}
	
	// If any of the (optional) requirements aren't loaded, we log that in just in case.
	if (g_bLogMissingDependencies.BoolValue) // That is, if this convar is set to true.
	{
		if (!g_bIsTF2AttributesEnabled)
			LogMessage("[TFRebalance %s] tf2attributes is not loaded. "
			... "This will prevent the plugin from adding attributes on classes.", PLUGIN_VERSION);
	}
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
		PrintToServer("[TFRebalance %s] Stored %i weapons and %i classes in total to change.", PLUGIN_VERSION,
		g_iRebalance_ItemIndexChangesNumber, g_iRebalance_ClassChangesNumber);
	}
	
	return Plugin_Handled;
}

// Command that displays info about the choosen weapons.
public Action WeaponHelp(int iClient, int iArgs)
{
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) &&
	g_bEnablePlugin.BoolValue)
		CreateBalanceMenu(iClient, HelpType_Weapon);
}

// Command that displays info about the choosen class.
public Action ClassHelp(int iClient, int iArgs)
{
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) &&
	g_bEnablePlugin.BoolValue)
		CreateBalanceMenu(iClient, HelpType_Class);
}

// Command that displays info about the choosen wearables.
public Action WearableHelp(int iClient, int iArgs)
{
	if (IsValidClient(iClient) && IsPlayerAlive(iClient) &&
	g_bEnablePlugin.BoolValue)
		CreateBalanceMenu(iClient, HelpType_Wearable);
}

public Action Event_PlayerSpawn(Handle hEvent, const char[] cName, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (IsValidClient(iClient) && g_bEnablePlugin.BoolValue)
	{	
		// We tell the player, only on their first spawn, that their weapons and class are modified.
		if (!g_bFirstSpawn[iClient] && g_bFirstTimeInfoOnSpawn.BoolValue)
		{
			CPrintToChat(iClient,
			"{unique}The weapons you'll play with have been modified and balanced by this server.\n"
			... "Type /weapon_info, /class_info or /wearable_info to learn more about what changed.");
			g_bFirstSpawn[iClient] = true;
		}
	
		// This is the part where we give the player the attributes.
		TF2Attrib_RemoveAll(iClient); // We remove all of the client's attributes so they don't stack or mesh together.
		TFClassType tfClassModified = TF2_GetPlayerClass(iClient); // We fet the client's class
		
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
		
		// If the changetimer convar is non-zero, we create a timer that changes the weapons
		// after such time.
		if (g_bChangeWeaponOnTimer.FloatValue > 0)
		{
			// The timer is non-repeating, and we pass the client as the value.
			CreateTimer(g_bChangeWeaponOnTimer.FloatValue, Timer_ChangeWeapons, iClient, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

// Timer function that will give weapons to a player if sm_tfrebalance_changetimer is higher than zero.
// A bit dirty, but compatibility is compatibility.
public Action Timer_ChangeWeapons(Handle hTimer, int iClient)
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
		for (int i = 0; i <= g_iRebalance_ItemIndexChangesNumber; i++)
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
				
				// PrintToServer("Timer_ChangeWeapons: Parsing %N's weapon with id %i...",
				// iClient, g_iRebalance_ItemIndexDef[i]);
				
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
					
					TF2Items_SetQuality(hWeaponReplacement, 10); // Customized Quality
					TF2Items_SetLevel(hWeaponReplacement, GetRandomInt(1, 100)); // Random Level
					
					if (g_bRebalance_ShouldItemPreserveAttributes[i]) // If we preserve attributes.
					{
						// We get the static attributes of the weapon we're parsing through tf2attributes.
						// Since we're creating a whole new weapon, this is sort of required.
						if (g_bIsTF2AttributesEnabled)
						{
							// We create a bunch of variables meant to declare the number of static and total attributes,
							// and the attributes and their values gotten through TF2Attrib_GetStaticAttribs.
							int iNumOfStaticAttributes = -1, iNumOfTotalAttributes = -1, iAttribIndexes[16];
							float fAttribValues[16];
							iNumOfStaticAttributes = TF2Attrib_GetStaticAttribs(g_iRebalance_ItemIndexDef[i], iAttribIndexes, fAttribValues) - 1;
							
							// We set the total attributes to be the static ones + the ones we wanna add.
							iNumOfTotalAttributes = iNumOfStaticAttributes + g_iRebalance_ItemAttribute_AddNumber[i];
							TF2Items_SetNumAttributes(hWeaponReplacement, iNumOfTotalAttributes);
							
							// Attribute additions:
							// We'll add the static attributes first.
							// PrintToServer("Static attribute total: %i", iNumOfStaticAttributes);
							
							while (iAdded <= iNumOfStaticAttributes)
							{
								// Attribute debug stuff.
								// PrintToServer("Added static attribute %i with value %f to weapon (iAdded: %i)",
								// iAttribIndexes[iAdded], fAttribValues[iAdded], iAdded);
								// Then we'll add one attribute in.
								TF2Items_SetAttribute(hWeaponReplacement, iAdded - 1,
								iAttribIndexes[iAdded], fAttribValues[iAdded]);
								
								iAdded++; // We increase one on this int.
							}
							
							// Afterwards, we'll add the attributes from the keyvalues file.
							int iAddedKv = 1; 
							while (iAddedKv <= g_iRebalance_ItemAttribute_AddNumber[i])
							{
								// PrintToServer("Added keyvalues attribute %i to weapon (iAdded: %i)", g_iRebalance_ItemAttribute_Add[i][iAddedKv], iAdded);
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
							//PrintToServer("Added %i to weapon", g_iRebalance_ItemAttribute_Add[i][iAdded]);
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
	
	return Plugin_Continue;
}

// This TF2Items forward changes the item after it's initialized.
public Action TF2Items_OnGiveNamedItem(int iClient, char[] cClassname, int iItemDefinitionIndex, Handle &hWeaponReplacement)
{	
	// If the client's valid, the plugin's enabled
	if (IsValidClient(iClient) && g_bEnablePlugin.BoolValue) 
	{		
		// PrintToServer("TF2Items_OnGiveNamedItem: Parsing %N's %s (%i)...", iClient, cClassname, iItemDefinitionIndex);
		
		// We go through all the weapons we've modified to see if we can replace the player's weapon
		// with another one.
		for (int i = 0; i <= g_iRebalance_ItemIndexChangesNumber; i++)
		{			
			// If a weapon's definition index matches with the one stored...
			if (iItemDefinitionIndex == g_iRebalance_ItemIndexDef[i])
			{		
				// If the changetimer is higher than zero (aka enabled)...
				if (g_bChangeWeaponOnTimer.FloatValue > 0.0)
				{
					// If the weapon isn't a wearable, we keep it intact.
					// This makes it so wearables are changed using the typical method
					// while the changetimer timer function changes the weapons.
					if (StrContains(cClassname, "tf_wearable", false)) return Plugin_Continue;
				}
				
				// We will add as many attributes as put on the attributes file.
				int iAdded = 1;
					
				if (g_bRebalance_ShouldItemPreserveAttributes[i]) // If we preserve attributes.
				{
					hWeaponReplacement = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES);
					
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
						//PrintToServer("Added %i to weapon", g_iRebalance_ItemAttribute_Add[i][iAdded]);
						// Then we'll add one attribute in.
						TF2Items_SetAttribute(hWeaponReplacement, iAdded - 1,
						g_iRebalance_ItemAttribute_Add[i][iAdded], view_as<float>(g_fRebalance_ItemAttribute_AddValue[i][iAdded]));
						
						iAdded++; // We increase one on this int.
					}					
				}	
				else // If we *don't* preverse attributes.
				{
					// TF2Items: we'll create a handle here that'll store the item we'll replace.
					hWeaponReplacement = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES);
				
					// We add as many attributes as we put on the keyvalues file.
					TF2Items_SetNumAttributes(hWeaponReplacement, g_iRebalance_ItemAttribute_AddNumber[i]);
					// Attribute additions:
					// As long as iAdded is less than the attributes we'll stored...
					
					while (iAdded <= g_iRebalance_ItemAttribute_AddNumber[i])
					{
						//PrintToServer("Added %i to weapon", g_iRebalance_ItemAttribute_Add[i][iAdded]);
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

public Action CreateBalanceMenu(int iClient, HelpType htTypeOfHelp)
{
	Handle hMenu = CreatePanel(); // We create a panel.
	// The char that contains the descriptions we'll add.
	char cChanges[MAXIMUM_DESCRIPTIONLIMIT] = "Here's the changes:\n";
	int iWeapon = -1, iWeaponIndex = -1, iActiveWeapon = -1;
	bool bChanged = false;
	
	// If the client is valid and he's alive...
	if (IsValidClient(iClient) && IsPlayerAlive(iClient))
	{
		// We get the client's class
		TFClassType tfClass = TF2_GetPlayerClass(iClient);
	
		switch (htTypeOfHelp)
		{
			case HelpType_Weapon: // We get the descriptions of the current weapon.
			{
				// We get the active weapon and we see if it exists.
				iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
				if (iActiveWeapon != -1)
				{
					// We get the item index ID and we see if it's valid.
					iWeaponIndex = GetEntProp(iActiveWeapon, Prop_Send, "m_iItemDefinitionIndex");
					if (iWeaponIndex != -1)
					{
						// We cycle through the stored weapon IDs.
						for (int i = 0; i <= g_iRebalance_ItemIndexChangesNumber; i++)
						{			
							//PrintToServer("Cycling through weapons to find description for %i", iWeaponIndex);
							// If a weapon's definition index matches with the one stored...
							if (iWeaponIndex == g_iRebalance_ItemIndexDef[i])
							{				
								// We add the information in.
								StrCat(cChanges, sizeof(cChanges),
								g_cRebalance_ItemDescription[i]);
								// New line for each weapon.
								StrCat(cChanges, sizeof(cChanges), "\n");
								//PrintToServer("Found description for %i: %s)", iWeaponIndex,
								//g_cRebalance_ItemDescription[g_iRebalance_ItemIndexChangesNumber]);
								if (g_bRebalance_DoesItemHaveDescription[i]) bChanged = true;
							}
						}				
					}
				}
			}
			case HelpType_Class: // We get the description of class.
			{
				if (g_bRebalance_ClassChanged[tfClass])
				{
					//PrintToServer("Class info (%i): %s)", tfClass,
					//g_cRebalance_ClassDescription[tfClass]);
					
					StrCat(cChanges, sizeof(cChanges),
					g_cRebalance_ClassDescription[tfClass]);
					// New line after class.			
					StrCat(cChanges, sizeof(cChanges), "\n");
					
					if (g_bRebalance_DoesClassHaveDescription[tfClass]) bChanged = true;
				}
			}
			case HelpType_Wearable: // We get the descriptions of wearables.
			{
				int WearableItem = -1;
				
				// These are the kinds of wearable entities we check:
				#define WEARABLELIST_INDEX 2
				static const char cWearableTypes[WEARABLELIST_INDEX][] =
				{
					"tf_wearable",
					"tf_wearable_demoshield"
				};
				
				for (int i = 0; i <= WEARABLELIST_INDEX - 1; i++)
				{
					while ((WearableItem = FindEntityByClassname(WearableItem, cWearableTypes[i])) != -1) // Regular hats.
					{
						int WearableIndex = GetEntProp(WearableItem, Prop_Send, "m_iItemDefinitionIndex");
						int WearableOwner = GetEntPropEnt(WearableItem, Prop_Send, "m_hOwnerEntity");
						
						if (WearableOwner == iClient)
						{
							// Going through all items.
							for (int k = 0; k <= g_iRebalance_ItemIndexChangesNumber; k++)
							{			
								//PrintToServer("Cycling through weapons to find description for %i", iWeaponIndex);
								// If a weapon's definition index matches with the one stored...
								if (WearableIndex == g_iRebalance_ItemIndexDef[k])
								{				
									StrCat(cChanges, sizeof(cChanges),
									g_cRebalance_ItemDescription[k]);
									// New line for each weapon.
									StrCat(cChanges, sizeof(cChanges), "\n");
									//PrintToServer("Found description for %i: %s (i: %i)", iWeaponIndex,
									//g_cRebalance_ItemDescription[g_iRebalance_ItemIndexChangesNumber]);
									
									if (g_bRebalance_DoesItemHaveDescription[k]) bChanged = true;
								}
							}
						}
					}
				}
				
				// We get the parachute, which is technically a weapon, but the player can't hold it.
				if (tfClass == TFClass_DemoMan || tfClass == TFClass_Soldier)
				{
					iWeapon = -1, iWeaponIndex = -1;
					
					switch (tfClass)
					{
						case TFClass_DemoMan: iWeapon = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Primary);
						case TFClass_Soldier: iWeapon = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Secondary);
					}
					
					if (iWeapon != -1)
					{
						// We get the item index ID and we see if it's valid.
						iWeaponIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
						if (iWeaponIndex != -1 && iWeaponIndex == 1101)
						{
							// We cycle through the stored weapon IDs.
							for (int i = 0; i <= g_iRebalance_ItemIndexChangesNumber; i++)
							{			
								//PrintToServer("Cycling through weapons to find description for %i", iWeaponIndex);
								// If a weapon's definition index matches with the one stored...
								if (iWeaponIndex == g_iRebalance_ItemIndexDef[i])
								{				
									// We add the information in.
									StrCat(cChanges, sizeof(cChanges),
									g_cRebalance_ItemDescription[i]);
									// New line for each weapon.
									StrCat(cChanges, sizeof(cChanges), "\n");
									//PrintToServer("Found description for %i: %s)", iWeaponIndex,
									//g_cRebalance_ItemDescription[g_iRebalance_ItemIndexChangesNumber]);
									
									if (!bChanged && g_bRebalance_DoesItemHaveDescription[i])
										bChanged = true;
								}
							}				
						}
					}
				}
			}
		}
	}

	// If there's any changes to show, we'll show 'em.
	if (bChanged)
	{
		// Turns newlines on the keyvalues file into REAL newlines
		ReplaceString(cChanges, sizeof(cChanges), "\\n", "\n");
		DrawPanelText(hMenu, cChanges); // Draw description.
		cChanges = "Got it";
		DrawPanelItem(hMenu, cChanges); // Draw "accept" button.
		
		// We send the panel to the client.
		SendPanelToClient(hMenu, iClient, BalancePanel, 60);	
	}
	else
	{
		switch (htTypeOfHelp)
		{
			case HelpType_Weapon: CPrintToChat(iClient, "{darkred}Your active weapon doesn't have a description we can give you.");
			case HelpType_Class: CPrintToChat(iClient, "{darkred}Your class doesn't have a description we can give you.");
			case HelpType_Wearable: CPrintToChat(iClient, "{darkred}Your wearable(s) don't or doesn't have (a) descriptions we can give you.");
		}
	}
	
	// We close the panel.
	CloseHandle(hMenu);
	return Plugin_Continue;
}

public int BalancePanel(Handle hMenu, MenuAction maAction, int param1, int param2)
{
	if (!IsValidClient(param1)) return;
	if (maAction == MenuAction_Select || (maAction == MenuAction_Cancel && param2 == MenuCancel_Exit)) return;
	return;
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
						//PrintToServer("Added attribute to class: %i with value %f",
						//Rebalance_ClassAttribute_Add[tfClassModified][Rebalance_ClassAttribute_AddNumber[tfClassModified]], 
						//Rebalance_ClassAttribute_AddValue[tfClassModified][Rebalance_ClassAttribute_AddNumber[tfClassModified]]);
						//PrintToServer("%i - %i", g_iRebalance_ItemIndexChangesNumber, Rebalance_ItemAttribute_AddNumber[g_iRebalance_ItemIndexChangesNumber]);
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
					//PrintToServer("TF2 Rebalance: there's attributes for %i, analyzing and storing...", iIDWeaponIndex);
					
					// We say that the weapon on this index was changed and we store the definition ID of such.
					g_bRebalance_ItemIndexChanged[g_iRebalance_ItemIndexChangesNumber] = true;
					g_iRebalance_ItemIndexDef[g_iRebalance_ItemIndexChangesNumber] = iIDWeaponIndex;
					
					// We get the information about the weapon.
					KvGetString(g_hKeyvaluesAttributesFile, "info",
					g_cRebalance_ItemDescription[g_iRebalance_ItemIndexChangesNumber],
					MAXIMUM_DESCRIPTIONLIMIT);
					
					if (!StrEqual(g_cRebalance_ItemDescription[g_iRebalance_ItemIndexChangesNumber], "", false))
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