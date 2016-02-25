#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <store>
#include <smjansson>
#include <smartdm>

enum Skin
{
    String:SkinName[STORE_MAX_NAME_LENGTH],
    String:SkinModelPath[PLATFORM_MAX_PATH], 
    String:SkinArmsPath[PLATFORM_MAX_PATH], 
    SkinTeams[5]
}

new g_skins[1024][Skin];
new g_skinCount = 0;

new Handle:g_skinNameIndex;

new String:g_game[32];

new Handle:playercachedinfo;

public Plugin:myinfo =
{
    name        = "[Store] Advanced Skins",
    author      = "Snowcrash",
    description = "An Advanced Skins component for [Store]",
    version     = "1.0",
    url         = ""
};


//Plugin Initialization
public OnPluginStart()
{
    LoadTranslations("store.phrases");
    
    //Hook Events
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerRefreshSkins);
    
    //Hook this plugin to store plujgin
    Store_RegisterItemType("skin", OnEquip, LoadItem);
    
    //Get game folder path
    GetGameFolderName(g_game, sizeof(g_game));
    
    //and create our keypair structure to cache our info
    playercachedinfo = CreateKeyValues("ModelInfo");
}

//Called when plugin ends
public OnPluginEnd()
{
    CloseHandle(playercachedinfo);
}

//Called when map starts
public OnMapStart()
{
    //Iterate over all the skins we found at LoadItem() and precache them, and add them to the downloads table.
    for (new skin = 0; skin < g_skinCount; skin++)
    {
        if (strcmp(g_skins[skin][SkinModelPath], "") != 0 && (FileExists(g_skins[skin][SkinModelPath]) || FileExists(g_skins[skin][SkinModelPath], true)))
        {
            PrecacheModel(g_skins[skin][SkinModelPath]);
            Downloader_AddFileToDownloadsTable(g_skins[skin][SkinModelPath]);
        }
        
        if (strcmp(g_skins[skin][SkinArmsPath], "") != 0 && (FileExists(g_skins[skin][SkinArmsPath]) || FileExists(g_skins[skin][SkinArmsPath], true)))
        {
            PrecacheModel(g_skins[skin][SkinArmsPath]);
            Downloader_AddFileToDownloadsTable(g_skins[skin][SkinArmsPath]);
        }
    }
}

//Called when a new API Library is loaded.
public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "store-inventory"))
    {
        Store_RegisterItemType("skin", OnEquip, LoadItem);
    }
}

//Called when a new client is put in server.
public void OnClientPutInServer(int client)
{
    //Refresh this clients skin cache
    Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "skin", Store_GetClientLoadout(client), OnGetPlayerSkin, GetClientSerial(client));
}

public void OnClientDisconnect(int client)
{
    //get client steamid
    new String:steamid[64];
    GetClientAuthId(client, AuthId_Engine, steamid, true);
    
    //delete clients records from our keypair structure, because client has left.
    KvDeleteKey(playercachedinfo, steamid);
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    //get our client id
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    //if it is a fake client, do not do anything, just return.
    if (IsFakeClient(client))
        return Plugin_Continue;
    
    //get steamid, simillar to to OnClientDisconnect()
    new String:steamid[64];
    GetClientAuthId(client, AuthId_Engine, steamid, true);
    
    //if for some reason our struct cant jump to the key provided (the clients steamid) just stop execution. This should not happen as the third parameter on it is TRUE, 
    //that means it will create a new record if one does not exist.
    if(!KvJumpToKey(playercachedinfo, steamid, true))
    {
        return Plugin_Continue;
    }
    
    //get our cached model and arms path
    new String:ModelPath[PLATFORM_MAX_PATH];
    new String:ArmsPath[PLATFORM_MAX_PATH];
    
    KvGetString(playercachedinfo, "ModelPath", ModelPath, sizeof(ModelPath), "");
    KvGetString(playercachedinfo, "ArmsPath", ArmsPath, sizeof(ModelPath), "");
    
    
    //if its not empty, apply is to the character. This is the THIRD PERSON model
    //TODO check if entity model is not already the same. I dont know if its nessecary (how expensive is it to change models every spawn? do models stay after death?) and frankly im too lazy to do it.
    if (strcmp(ModelPath, "") != 0 && (FileExists(ModelPath) || FileExists(ModelPath, true)))
    {
        SetEntityModel(client, ModelPath);
    }
    
    //same for the first person model (arms). This has to be called on the PlayerSpawn function, NO DELAYS, otherwise it wont work.
    if (strcmp(ArmsPath, "") != 0 && (FileExists(ArmsPath) || FileExists(ArmsPath, true)))
    {
        SetEntPropString(client, Prop_Send, "m_szArmsModel", ArmsPath);
    }

    //Rewind our struct to its initial position.
    KvRewind(playercachedinfo);

    return Plugin_Continue;
}

//Hooked function to player_death. Called when player dies
public Action:Event_PlayerRefreshSkins(Handle:event, const String:name[], bool:dontBroadcast)
{
    //This function simply calls the function that refreshes the cache. This is done on death.
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "skin", Store_GetClientLoadout(client), OnGetPlayerSkin, GetClientSerial(client));
}

public Store_OnClientLoadoutChanged(client)
{
    //Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "skin", Store_GetClientLoadout(client), OnGetPlayerSkin, GetClientSerial(client));
}

public OnGetPlayerSkin(ids[], count, any:serial)
{
    //Get client and make sure its valid.
    new client = GetClientFromSerial(serial);
    
    if (client == 0)
        return;
        
    if (!IsClientInGame(client))
        return;
    
    //Code that I did not write, props to alongub and his skins plugin which ive mostly based my own on it.
    new team = GetClientTeam(client);
    for (new index = 0; index < count; index++)
    {
        decl String:itemName[STORE_MAX_NAME_LENGTH];
        Store_GetItemName(ids[index], itemName, sizeof(itemName));
        
        new skin = -1;
        if (!GetTrieValue(g_skinNameIndex, itemName, skin))
        {
            PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
            continue;
        }

        new bool:teamAllowed = false;
        for (new teamIndex = 0; teamIndex < 5; teamIndex++)
        {
            if (g_skins[skin][SkinTeams][teamIndex] == team)
            {
                teamAllowed = true;
                break;
            }
        }


        if (!teamAllowed)
        {
            continue;
        }

        if (StrEqual(g_game, "tf"))
        {
            SetVariantString(g_skins[skin][SkinModelPath]);
            AcceptEntityInput(client, "SetCustomModel");
            SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
        }
        else
        {
            //set cached model info
            new String:steamid[64];
            GetClientAuthId(client, AuthId_Engine, steamid, true);
            
            if(!KvJumpToKey(playercachedinfo, steamid, true))
            {
                return;
            }
    
    
            KvSetString(playercachedinfo, "ModelPath", g_skins[skin][SkinModelPath]);
            KvSetString(playercachedinfo, "ArmsPath", g_skins[skin][SkinArmsPath]);
   
            KvRewind(playercachedinfo);
        }
    }
}

public Store_OnReloadItems() 
{
    if (g_skinNameIndex != INVALID_HANDLE)
        CloseHandle(g_skinNameIndex);
        
    g_skinNameIndex = CreateTrie();
    g_skinCount = 0;
}

public LoadItem(const String:itemName[], const String:attrs[])
{
    strcopy(g_skins[g_skinCount][SkinName], STORE_MAX_NAME_LENGTH, itemName);

    SetTrieValue(g_skinNameIndex, g_skins[g_skinCount][SkinName], g_skinCount);

    new Handle:json = json_load(attrs);
    json_object_get_string(json, "model", g_skins[g_skinCount][SkinModelPath], PLATFORM_MAX_PATH);
    //get arms
    json_object_get_string(json, "arms", g_skins[g_skinCount][SkinArmsPath], PLATFORM_MAX_PATH);

    if (strcmp(g_skins[g_skinCount][SkinModelPath], "") != 0 && (FileExists(g_skins[g_skinCount][SkinModelPath]) || FileExists(g_skins[g_skinCount][SkinModelPath], true)))
    {
        PrecacheModel(g_skins[g_skinCount][SkinModelPath]);
        Downloader_AddFileToDownloadsTable(g_skins[g_skinCount][SkinModelPath]);
    }
    
    if (strcmp(g_skins[g_skinCount][SkinArmsPath], "") != 0 && (FileExists(g_skins[g_skinCount][SkinArmsPath]) || FileExists(g_skins[g_skinCount][SkinArmsPath], true)))
    {
        PrecacheModel(g_skins[g_skinCount][SkinArmsPath]);
        Downloader_AddFileToDownloadsTable(g_skins[g_skinCount][SkinArmsPath]);
    }

    new Handle:teams = json_object_get(json, "teams");

    for (new i = 0, size = json_array_size(teams); i < size; i++)
        g_skins[g_skinCount][SkinTeams][i] = json_array_get_int(teams, i);

    CloseHandle(json);

    g_skinCount++;
}

public Store_ItemUseAction:OnEquip(client, itemId, bool:equipped)
{
    if (equipped)
        return Store_UnequipItem;
    
    PrintToChat(client, "%s%t", STORE_PREFIX, "Equipped item apply next spawn");
    return Store_EquipItem;
}











