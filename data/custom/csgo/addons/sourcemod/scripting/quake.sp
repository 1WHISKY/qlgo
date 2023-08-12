#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <cstrike>
#include <clientprefs>

#define print PrintToServer

#define PLAYERMODEL "models/player/custom_player/legacy/quake/keel/keel.mdl"
#define maxGameTime 9999999999.9
#define LIGHTNING_LENGTH 768.0

public Plugin:myinfo = {
    name= "Quake Mod",
    author= "WHISKY",
    description= "Quake Gamemode for CS:GO",
    version= "0.8",
    url= "https://steamcommunity.com/id/1WHISKY/"
}

enum WEAPON{
    WEAPON_NONE = 0,
    WEAPON_GAUNTLET,
    WEAPON_MACHINEGUN,
    WEAPON_SHOTGUN,
    WEAPON_GRENADELAUNCHER,
    WEAPON_ROCKETLAUNCHER,
    WEAPON_LIGHTNING,
    WEAPON_RAILGUN,
    WEAPON_PLASMAGUN,
    WEAPON_HMG,

    WEAPON_NUM_WEAPONS
}

enum GAMEMODE{
    GM_NONE = 0,
    GM_IFFA,
    GM_FFA,
    GM_TDM,
    GM_DUEL,
    GM_FT,
    GM_CA,
    GM_CTF,
    GM_TEST,

    GM_NUM_GAMEMODES
}

enum GAMESTATE{
    GS_NONE,
    GS_WARMUP,
    GS_WARMUPEND,
    GS_ROUNDSTARTING,
    GS_PLAYING,
    GS_ROUNDEND,
    GS_INTERMISSION,
}

enum TEAMSOUND{
    TS_PAIN100,
    TS_PAIN75,
    TS_PAIN50,
    TS_PAIN25,

    TS_DEATH1,
    TS_DEATH2,
    TS_DEATH3,

    TS_JUMP,
    TS_FALL,
    TS_FALLING,
    TS_DROWN,
    TS_GASP,
    TS_TAUNT,
}

enum POWERUP{
    PW_NONE,

    PW_QUAD,
    PW_BATTLESUIT,
    PW_HASTE,
    PW_INVIS,
    PW_REGEN,
    PW_FLIGHT,

    PW_REDFLAG,
    PW_BLUEFLAG,
    PW_NEUTRALFLAG,

    PW_SCOUT,
    PW_GUARD,
    PW_DOUBLER,
    PW_AMMOREGEN,
    PW_INVULNERABILITY,

    PW_NUM_POWERUPS
}

enum ENTTYPE{
    ET_NONE,
    ET_ITEM_AMMO,
    ET_ITEM_WEAPON,
    ET_ITEM_POWERUP,
    ET_ITEM_HEALTH,
    ET_ITEM_ARMOR,
    ET_ITEM_KEY,
    ET_SPAWN,
    ET_LOCATION,
    ET_INTERMISSIONCAMERA,
    ET_FAKEPROP,
}

enum ITEM{
    IT_NONE,

    IT_AMMO_MG,
    IT_AMMO_SG,
    IT_AMMO_GL,
    IT_AMMO_RL,
    IT_AMMO_LG,
    IT_AMMO_RG,
    IT_AMMO_PG,
    IT_AMMO_HMG,
    IT_AMMO_ALL,

    IT_WEAPON_GA,
    IT_WEAPON_MG,
    IT_WEAPON_SG,
    IT_WEAPON_GL,
    IT_WEAPON_RL,
    IT_WEAPON_LG,
    IT_WEAPON_RG,
    IT_WEAPON_PG,
    IT_WEAPON_HMG,

    IT_HEALTH_5,
    IT_HEALTH_25,
    IT_HEALTH_50,
    IT_HEALTH_MEGA,

    IT_ARMOR_5,
    IT_ARMOR_25,
    IT_ARMOR_50,
    IT_ARMOR_100,

    IT_KEY_SILVER,
    IT_KEY_GOLD,
    IT_KEY_MASTER,

    IT_QUAD,
    IT_BATTLESUIT,
    IT_HASTE,
    IT_INVIS,
    IT_REGEN,
    IT_FLIGHT,
    IT_REDFLAG,
    IT_BLUEFLAG,
    IT_NEUTRALFLAG,
    IT_SCOUT,
    IT_GUARD,
    IT_DOUBLER,
    IT_AMMOREGEN,
    IT_INVULNERABILITY,

    IT_NUM_ITEMS
}

enum struct SlotData{ //data for each playerslot
    int wpnAttachmentTarget
    int wpnVMTarget
    int wpnAimTarget

    int activeWeapon
    int desiredWeapon
    int lastDesiredWeapon
    int lastProjectileDamageTaken
    float nextPrimaryAttack

    Handle wpnSoundHumTimer
    float lastDmgTime
    float lastDmgTakenTime
    float lastPainTime
    float lastJumpSound
    int crosshairColor    //0 = white, 1 = blue, 2 = yellow, 3 = red
    bool lastSpecMode
    int lastSpecTarget

    int lastbuttons
    int lastbuttons2    //buttons pressed 2 ticks ago, jank workaround

    int armor
    float powerups[PW_NUM_POWERUPS]
    float lastQuadSound

    int lg_fakeground
    float lg_oldspeed[3]

    //cookies
    bool cookiesLoaded
    int fov
    int fovZoom
    bool fovSmooth
    int railColor
    char voice[64]
    bool locationEnabled
    
    float nextVoice
    
    int menuOpen
    bool ready
    int mapVote
    float lastMapVote
    float queueTime
    char name[64]
    int numKeys[3] //0 = silver, 1 = gold, 2 = master

    int wpnAmmo[WEAPON_NUM_WEAPONS]
    bool wpnAvailable[WEAPON_NUM_WEAPONS]
}

enum struct WeaponPreset{
    char name[64]
    int maxAmmo
    int lowAmmo
    int startingAmmo
    float reload
    float damage
    float splashDamage
    float radius
    float velocity
    float prestep
    char viewmodel[64]
    char worldmodel[64]
    char sound[64]
    char decal[64]
    bool projectile
    int anim_idle
    int anim_attack
    int anim_equip
    int anim_holster
    bool holdFireAnim
}

enum struct GamemodePreset{
    bool teams    //team based or ffa like?
    bool respawn
    bool selfdamage
    bool instagib
    bool ctf    //spawn points for ctf dom ad
    bool items    //spawn ammo/weapons/powerups?
    bool roundbased
    bool killsscore    //kills contribute to your teams score
    int scorelimit
    int timelimit
    char type[16]
    char name[64]
    int health
    int maxHealth
    int startHealth
    int startArmor
    int startingWeapons
    int overtime //0 = none (draw) 1=overtime 120s 2=sudden death
    int maxPlayers
}

enum struct SEnt{
    char classname[64]
    float origin[3]
    float angle[3]
    char targetname[64]
    char target[64]
    int spawnflags
    int wait
    int count
    int identifier //only used for domination? (point a,b,c...)
    char message[64] //e.g. location string for target_location

    int senttype

    //mostly used for items
    int ent
    int phys
    int item
    bool valid
    bool active
    bool respawn
    float respawnTime
    bool dropped
}

enum struct ItemPreset{
    char model[64]
    int skin
    int type
    int wait
    int count

    //powerups
    char name[64]
    char sound[64]
    char voice[64]
    char icon[64]
}

enum struct ReliableSound{
    char path[PLATFORM_MAX_PATH]
    int client
    int entity
    int channel
    float volume
    float soundtime
    bool valid
}

enum struct Map{
    char name[64]
    char nice_name[64]
    int gamemodes[GM_NUM_GAMEMODES]
    int maxplayers
}

ConVar h_cvarTeammatesAreEnemies
ConVar h_cvarCheats
ConVar h_cvarForceAssignTeams
ConVar h_cvarLimitTeams
ConVar h_cvarRespawnT
ConVar h_cvarRespawnCT
ConVar h_cvarMaxRounds
ConVar h_cvarQNoBots
ConVar h_cvarYourTeam
ConVar h_cvarHud
ConVar h_cvarCrosshair
ConVar h_cvarTeamRedColorR
ConVar h_cvarTeamRedColorG
ConVar h_cvarTeamRedColorB
ConVar h_cvarTeamBlueColorR
ConVar h_cvarTeamBlueColorG
ConVar h_cvarTeamBlueColorB
ConVar h_cvarTeamEnemyColorR
ConVar h_cvarTeamEnemyColorG
ConVar h_cvarTeamEnemyColorB
ConVar h_cvarRailR
ConVar h_cvarRailG
ConVar h_cvarRailB

Cookie h_cookieFov
Cookie h_cookieFovZoom
Cookie h_cookieFovSmooth
Cookie h_cookieVoice
Cookie h_cookieColorEnemies
Cookie h_cookieColorTeamRed
Cookie h_cookieColorTeamBlue
Cookie h_cookieColorRailgun
Cookie h_cookieLocation

Handle h_getPlayerMaxSpeed
UserMsg usermsg_textmsg
Panel weaponSelectionPanel
Menu menuMain
Menu menuFOVSub
Menu menuFOVSelect
Menu menuFOVZoom
Menu menuFOVSmooth
Menu menuVoice
Menu menuColor
Menu menuColorEnemies
Menu menuColorRed
Menu menuColorBlue
Menu menuColorRailgun
Menu menuMisc
Menu menuLocation

int effectDispatchTable
int decalPrecacheTable
int particleTable

int csbloodEffectIndex
int particleEffectIndex

int lightningSprite
int railLaserSprite
//int debugLaserSprite
//TE_SetupBeamPoints( start, end, debugLaserSprite, 0, 0, 0, 0.0, 1.0, 1.0, 1, 0.0, {255,0,0,255}, 0 );
//TE_SendToAll();

int activePops = 0
float gravity = 800.0

int gamemode
int gamestate
int mapVoteWon
float lastMaxRounds
bool overtimeAnnounced
int fragsLeftAnnounced
float roundStart
char currentMap[128]
int intermissioncamera
int last_client_shot
bool lightning_smooth_beam = true            //update lightning beam endpos every tick, this lags the server if many people are using lg
int lightning_smooth_beam_limit = 2            //if smooth is enabled, how many simultaneous beams before no longer being smooth?
int lightning_activebeams
bool lg_enabled = true    //ledgegrab
int newest_ent_idx
bool locationsPresent
bool lateLoad
bool hide_namechange

int pPlayerPops[ (MAXPLAYERS + 1) * 2]
int trRailHits[MAXPLAYERS + 1] //railgun hits, global for use in trace filter function
int trEnumerateEnts[64]
bool dontReconnect[MAXPLAYERS + 1]

int hitnums_white[10]
int hitnums_pink[10]
int hitnums_red[10]
int particle_rlboom
int particle_hit

SlotData SD[MAXPLAYERS + 1]
WeaponPreset WPN[WEAPON_NUM_WEAPONS]
GamemodePreset GM[GM_NUM_GAMEMODES]
ItemPreset IT[IT_NUM_ITEMS]
Map MAPS[256]
Map mapvote[4]
ReliableSound reliableSounds[1024]
SEnt sents[512]
SEnt sents_dropped[256]
int sents_count
int num_maps

int decals[50]
int decals_lg[50]
int decals_rail[50]
int decals_i
int decals_lg_i
int decals_rail_i
int decals_rail_active

int railColors[][] =     {{254,0,0}, {254,68,0}, {254,126,0}, {254,186,0}, {254,254,0}, {186,254,0}, {126,254,0}, {68,254,0}, {0,254,0}, {0,254,68}, {0,254,126}, {0,254,186}, {0,254,254}, {0,186,254}, {0,126,254}, {0,68,254}, {0,0,254}, {68,0,254}, {126,0,254}, {186,0,254}, {254,0,254}, {254,0,186}, {254,0,126}, {254,0,68}, {254,254,254}, {126,126,126} }
int railColorsWpn[][] = {{254,0,0}, {254,18,0}, {254,64,0}, {254,142,0}, {254,254,0}, {124,254,0}, {64,254,0}, {16,254,0}, {0,254,0}, {0,254,16}, {0,254,42}, {0,254,96}, {0,254,254}, {0,162,254}, {0,68,254}, {0,21,254}, {0,0,254}, {12,0,254}, {40,0,254}, {108,0,254}, {254,0,254}, {254,0,126}, {254,0,56}, {254,0,18}, {200,200,200}, {48,48,48} }

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max){
    lateLoad = late
    return APLRes_Success
}

public void OnPluginStart(){
    setupWeaponPresets()
    setupGamemodePresets()
    setupMaps()
    setupItemPresets()
    setupWeaponSelectionPanel()
    setupSettingsMenus()
    setupRunspeed()
    setupCookies()

    AddCommandListener(command_say, "say")
    AddCommandListener(command_sayTeam, "say_team")
    AddCommandListener(command_qslot,"qslot")
    AddCommandListener(command_qinvprev,"qinvprev")
    AddCommandListener(command_qinvnext,"qinvnext")
    AddCommandListener(command_qlastinv,"qlastinv")
    AddCommandListener(command_ready,"autobuy")
    AddCommandListener(command_menu,"rebuy")
    AddCommandListener(command_suicide, "kill")
    AddCommandListener(command_suicide, "explode")
    AddCommandListener(command_jointeam, "jointeam")
    AddCommandListener(command_qgive, "qgive")
    //AddCommandListener(command_dev, "dev")

    //cookies
    AddCommandListener(command_qfov, "qfov")
    AddCommandListener(command_qfovzoom, "qzoomfov")
    AddCommandListener(command_qcolorenemies, "qcolorenemies")
    AddCommandListener(command_qcolorteamred, "qcolorteamred")
    AddCommandListener(command_qcolorteamblue, "qcolorteamblue")
    
    RegServerCmd("qallready", command_qallready)
    RegServerCmd("qmap", command_qmap)
    RegServerCmd("qspec", command_qspec)

    HookEvent("player_spawn", event_playerSpawn, EventHookMode_Post)
    HookEvent("player_connect_full", event_clientConnectFull,EventHookMode_Post)
    HookEvent("round_start", event_roundStart, EventHookMode_PostNoCopy)
    HookEvent("player_team", event_playerTeam, EventHookMode_Post)

    HookEvent("player_death", event_playerDeath, EventHookMode_Pre)
    HookEvent("weapon_fire", event_weaponFire,EventHookMode_Pre)
    HookEvent("player_jump", event_playerJump,EventHookMode_Post)
    
    HookEvent("cs_win_panel_round", event_disable,EventHookMode_Pre)
    HookEvent("round_announce_match_start", event_disable,EventHookMode_Pre)

    HookUserMessage(GetUserMessageId("SayText2"), hook_sayText2, true)
    AddNormalSoundHook(hook_normalSound)

    AddTempEntHook("Shotgun Shot",te_Shotgun_shot)
    AddTempEntHook("EffectDispatch", te_EffectDispatch)
    AddTempEntHook("World Decal", te_OnDecal)

    CreateTimer(1.0, t_1s, 0, TIMER_REPEAT)

    h_cvarTeammatesAreEnemies = FindConVar("mp_teammates_are_enemies")
    h_cvarCheats = FindConVar("sv_cheats")
    h_cvarForceAssignTeams = FindConVar("mp_force_assign_teams")
    h_cvarLimitTeams = FindConVar("mp_limitteams")
    h_cvarRespawnT = FindConVar("mp_respawn_on_death_t")
    h_cvarRespawnCT = FindConVar("mp_respawn_on_death_ct")
    h_cvarMaxRounds = FindConVar("mp_maxrounds")
    h_cvarQNoBots = CreateConVar("qnobots", "1", "Prevent bots from joining, will not kick active bots")

    //"client convars"
    h_cvarYourTeam = FindConVar("ammo_556mm_small_max") 
    h_cvarHud = FindConVar("ammo_9mm_max")
    h_cvarCrosshair = FindConVar("ammo_556mm_max")
    h_cvarTeamRedColorR = FindConVar("ammo_556mm_box_max")
    h_cvarTeamRedColorG = FindConVar("ammo_338mag_max")
    h_cvarTeamRedColorB = FindConVar("ammo_357sig_max")
    h_cvarTeamBlueColorR = FindConVar("ammo_45acp_max")
    h_cvarTeamBlueColorG = FindConVar("ammo_357sig_min_max")
    h_cvarTeamBlueColorB = FindConVar("ammo_357sig_p250_max")
    h_cvarTeamEnemyColorR = FindConVar("ammo_762mm_max")
    h_cvarTeamEnemyColorG = FindConVar("ammo_357sig_small_max")
    h_cvarTeamEnemyColorB = FindConVar("ammo_50AE_max")
    h_cvarRailR = FindConVar("ammo_57mm_max")
    h_cvarRailG = FindConVar("ammo_buckshot_max")
    h_cvarRailB = FindConVar("mp_ggtr_always_upgrade")

    usermsg_textmsg = GetUserMessageId("TextMsg")

    setGamemode(GM_TDM)

    if( lateLoad ){
        for( int i = 1; i <= MaxClients; i++ ){
            if( IsClientInGame(i) ){
                OnClientPutInServer(i)
                displayWeaponSelectionPanel(i)    //do this here for lateload, as it usually is done in clientConnectFull
            }
        }

        //event_roundStart(null,"",true)
    }


}

public void OnPluginEnd(){
    clearDecals()

    for(int i = 0;i<sents_count;i++){
        if(sents[i].phys != 0 && IsValidEntity(sents[i].phys)){
            RemoveEntity(sents[i].phys)
        }else if(sents[i].ent != 0 && IsValidEntity(sents[i].ent)){
            RemoveEntity(sents[i].ent)
        }
    }
}

Action command_suicide(int client, const char[] name, int argc){
    if(gamestate == GS_INTERMISSION){
        return Plugin_Handled
    }
    
    return Plugin_Continue
}

Action command_jointeam(int client, const char[] name, int argc){
    static char arg1[128]
    GetCmdArg(1,arg1,sizeof(arg1))
    int team = StringToInt(arg1)

    if(team == CS_TEAM_SPECTATOR){    //always allow
        SD[client].queueTime = 0.0
        return Plugin_Continue
    }
    
    if(gamestate == GS_INTERMISSION){
        closeTeamMenu(client)
        return Plugin_Handled
    }
    
    int players
    int in_queue
    
    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i)){
            continue
        }
        
        if(GetClientTeam(i) > CS_TEAM_SPECTATOR){
            players++
        }else{
            if(SD[i].queueTime != 0.0){
                in_queue++
            }
        }
    }
    
    if(players >= GM[gamemode].maxPlayers){
        if(GetClientTeam(client) > CS_TEAM_SPECTATOR){
            showStatus(client,"<font class='fontSize-l'>Teams are full!</font>",5)
            closeTeamMenu(client)
            return Plugin_Handled
        }else if(SD[client].queueTime == 0.0){
            showStatus(client,"<font class='fontSize-l'>Teams are full!<br>You are in the queue to play.</font>",5)
            SD[client].queueTime = GetGameTime()
            closeTeamMenu(client)
            static char newname[64]
            Format(newname, sizeof(newname), "(%d) %s",in_queue + 1,SD[client].name)
            
            setNameSilent(client,newname)
            return Plugin_Handled
        }else{    //already in queue
            showStatus(client,"<font class='fontSize-l'>Teams are full!<br>You are in the queue to play.</font>",5)
            closeTeamMenu(client)
            return Plugin_Handled
        }
    }
    
    if(!GM[gamemode].teams && (team == CS_TEAM_T || team == CS_TEAM_NONE)){
        if(GetClientTeam(client) != CS_TEAM_CT){
            FakeClientCommand(client, "jointeam 3 1")    //join ct
        }
        closeTeamMenu(client)
        return Plugin_Handled
    }
    
    return Plugin_Continue
}

void closeTeamMenu(int client){
    if(IsFakeClient(client)){
        return
    }
    
    Event e = CreateEvent("player_team",true)
    e.SetInt("userid",GetClientUserId(client))
    e.SetInt("team",0)
    e.SetBool("silent",true)
    e.FireToClient(client)
    e.Cancel()
}

Action command_qallready(int argc){
    if(gamestate != GS_WARMUP){
        return Plugin_Handled
    }
    
    for(int i = 1;i<=MaxClients;i++){
        SD[i].ready = true
    }
    
    checkReady()
    return Plugin_Handled
}

Action command_qmap(int argc){
    static char gamemodes[256]
    
    if(gamemodes[0] == 0){
        for(int i = 0;i<GM_NUM_GAMEMODES;i++){
            if(GM[i].type[0] == 0){
                continue
            }
            Format(gamemodes,sizeof(gamemodes),"%s %s",gamemodes, GM[i].type)
        }
    }
    
    if(argc < 2){
        print("Usage: qmap <map> <gamemode>, valid gamemodes: %s", gamemodes)
        return Plugin_Handled
    }

    static char map[64]
    GetCmdArg(1, map, sizeof(map))
    
    if(!IsMapValid(map)){
        print("Map not found!")
        return Plugin_Handled
    }
    
    static char gm[64]
    GetCmdArg(2, gm, sizeof(gm))
    
    for(int i = 0;i<GM_NUM_GAMEMODES;i++){
        if(StrEqual(gm, GM[i].type)){
            setGamemode(i)
            ServerCommand("changelevel %s",map)
            return Plugin_Handled
        }
    }
    
    print("Gamemode not found!")
    return Plugin_Handled
}

Action command_qspec(int argc){
    if(argc < 1){    
        print("Usage: qspec <id>, Player list:")
        for(int i = 1;i<=MaxClients;i++){
            if(IsClientInGame(i)){
                print("%d %N",i,i)
            }
        }
        return Plugin_Handled
    }
    
    static char arg[16]
    GetCmdArg(1,arg,sizeof(arg))
    
    int p = StringToInt(arg)
    if(p <= 0 || p >= MAXPLAYERS || !IsClientInGame(p)){
        print("Invalid player!")
        return Plugin_Handled
    }
    
    SD[p].queueTime = 0.0
    ChangeClientTeam(p, CS_TEAM_SPECTATOR)
    updateQueueNames()
    
    return Plugin_Handled
}

Action command_menu(int client, const char[] name, int argc){
    displayMainMenu(client)
    return Plugin_Handled
}

Action command_ready(int client, const char[] name, int argc){
    if(gamestate != GS_WARMUP || GetClientTeam(client) <= CS_TEAM_SPECTATOR){
        return Plugin_Handled
    }

    static int count
    count = 0
    for(int i = 1;i<=MaxClients;i++){
        if(IsClientInGame(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR){
            count++
        }
    }
    
    if(count == 1){
        return Plugin_Handled
    }

    SD[client].ready = !SD[client].ready

    static char buf[64]
    if(SD[client].ready){
        showFunfact(client,"<br><br><font class='fontSize-xl'>The match will begin<br>when more players are ready.</font><br><font color='#00ff00' class='fontSize-xl fontWeight-Bold'>Press F3 to unready yourself</font>")
        Format(buf,sizeof(buf),"%N is Ready",client)
        showStatusAll(buf,5)
        checkReady()
    }else{
        showFunfact(client,"<br><br><font class='fontSize-xl'>The match will begin<br>when more players are ready.</font><br><font color='#ff0000' class='fontSize-xl fontWeight-Bold'>Press F3 to ready yourself</font>")
        Format(buf,sizeof(buf),"%N is Not Ready",client)
        showStatusAll(buf,5)
    }

    return Plugin_Handled
}

Action command_qslot(int client, const char[] name, int argc){
    static char buf[4]
    GetCmdArg(1,buf,sizeof(buf))

    setDesiredWeapon(client,StringToInt(buf))
    return Plugin_Handled
}

Action command_qlastinv(int client, const char[] name, int argc){
    setDesiredWeapon(client,SD[client].lastDesiredWeapon)
    return Plugin_Handled
}

Action command_qinvnext(int client, const char[] name, int argc){
    int a = SD[client].desiredWeapon

    for(int i = 1;i<sizeof(WPN);i++){
        int slot = (a + i) % sizeof(WPN)
        if(SD[client].wpnAvailable[slot] && SD[client].wpnAmmo[slot] > 0){
            setDesiredWeapon(client,slot)
            return Plugin_Handled
        }
    }

    if(SD[client].wpnAmmo[SD[client].activeWeapon] <= 0){    //all weapons are out of ammo
        setDesiredWeapon(client,WEAPON_GAUNTLET)
    }

    return Plugin_Handled
}

Action command_qinvprev(int client, const char[] name, int argc){
    int a = SD[client].desiredWeapon

    for(int i = 1;i<sizeof(WPN);i++){
        int slot = (a - i) % sizeof(WPN)
        slot = slot < 0 ? slot + sizeof(WPN) : slot

        if(SD[client].wpnAvailable[slot] && SD[client].wpnAmmo[slot] > 0){
            setDesiredWeapon(client,slot)
            return Plugin_Handled
        }
    }

    if(SD[client].wpnAmmo[SD[client].activeWeapon] <= 0){    //all weapons are out of ammo
        setDesiredWeapon(client,WEAPON_GAUNTLET)
    }

    return Plugin_Handled
}

Action command_qfov(int client, const char[] name, int argc){
    static char buf[8]
    GetCmdArg(1,buf,sizeof(buf))

    qfov(client,buf)
    return Plugin_Handled
}

void qfov(int client,const char[] buf){
    static int num
    num = StringToInt(buf)
    if(num > 130){
        num = 130
    }

    if(num < 10){
        num = 10
    }

    SetClientCookie(client,h_cookieFov,buf)
    SD[client].fov = num

    SetEntProp(client, Prop_Send, "m_iFOV",SD[client].fov)
    SetEntProp(client, Prop_Send, "m_iDefaultFOV",SD[client].fov)
}

Action command_qfovzoom(int client, const char[] name, int argc){
    static char buf[8]
    GetCmdArg(1,buf,sizeof(buf))

    qfovzoom(client,buf)
    return Plugin_Handled
}

void qfovzoom(int client,const char[] buf){
    static int num
    num = StringToInt(buf)

    if(num > 130){
        num = 130
    }

    if(num < 10){
        num = 10
    }

    SetClientCookie(client,h_cookieFovZoom,buf)
    SD[client].fovZoom = num
}

Action command_qcolorenemies(int client, const char[] name, int argc){
    static char buf[16]
    GetCmdArgString(buf,sizeof(buf))

    qcolorenemies(client,buf)
    return Plugin_Handled
}

void qcolorenemies(int client, const char[] buf){
    if(IsFakeClient(client)){
        return
    }

    static char out[16]
    char col[3][8]
    ExplodeString(buf," ",col,sizeof(col),sizeof(col[]))

    if(col[0][0] == 0 || col[1][0] == 0 || col[2][0] == 0){
        PrintToConsole(client,"Missing Parameter")
        return
    }

    static int r,g,b
    static char rs[8]
    static char gs[8]
    static char bs[8]
    r = StringToInt(col[0])
    g = StringToInt(col[1])
    b = StringToInt(col[2])

    r = r < 0 ? 0 : (r > 255 ? 255 : r)
    g = g < 0 ? 0 : (g > 255 ? 255 : g)
    b = b < 0 ? 0 : (b > 255 ? 255 : b)

    Format(out,sizeof(out),"%d %d %d",r,g,b)
    FloatToString(r / 255.0,rs,sizeof(rs))
    FloatToString(g / 255.0,gs,sizeof(gs))
    FloatToString(b / 255.0,bs,sizeof(bs))


    SetClientCookie(client,h_cookieColorEnemies,out)
    SendConVarValue(client,h_cvarTeamEnemyColorR,rs)
    SendConVarValue(client,h_cvarTeamEnemyColorG,gs)
    SendConVarValue(client,h_cvarTeamEnemyColorB,bs)
}

Action command_qcolorteamred(int client, const char[] name, int argc){
    static char buf[16]
    GetCmdArgString(buf,sizeof(buf))

    qcolorteamred(client,buf)
    return Plugin_Handled
}

void qcolorteamred(int client, const char[] buf){
    if(IsFakeClient(client)){
        return
    }

    static char out[16]
    char col[3][8]
    ExplodeString(buf," ",col,sizeof(col),sizeof(col[]))

    if(col[0][0] == 0 || col[1][0] == 0 || col[2][0] == 0){
        PrintToConsole(client,"Missing Parameter")
        return
    }

    static int r,g,b
    static char rs[8]
    static char gs[8]
    static char bs[8]
    r = StringToInt(col[0])
    g = StringToInt(col[1])
    b = StringToInt(col[2])

    r = r < 0 ? 0 : (r > 255 ? 255 : r)
    g = g < 0 ? 0 : (g > 255 ? 255 : g)
    b = b < 0 ? 0 : (b > 255 ? 255 : b)

    Format(out,sizeof(out),"%d %d %d",r,g,b)
    FloatToString(r / 255.0,rs,sizeof(rs))
    FloatToString(g / 255.0,gs,sizeof(gs))
    FloatToString(b / 255.0,bs,sizeof(bs))


    SetClientCookie(client,h_cookieColorTeamRed,out)
    SendConVarValue(client,h_cvarTeamRedColorR,rs)
    SendConVarValue(client,h_cvarTeamRedColorG,gs)
    SendConVarValue(client,h_cvarTeamRedColorB,bs)
}

Action command_qcolorteamblue(int client, const char[] name, int argc){
    static char buf[16]
    GetCmdArgString(buf,sizeof(buf))

    qcolorteamblue(client,buf)
    return Plugin_Handled
}

void qcolorteamblue(int client, const char[] buf){
    if(IsFakeClient(client)){
        return
    }

    static char out[16]
    char col[3][8]
    ExplodeString(buf," ",col,sizeof(col),sizeof(col[]))

    if(col[0][0] == 0 || col[1][0] == 0 || col[2][0] == 0){
        PrintToConsole(client,"Missing Parameter")
        return
    }

    static int r,g,b
    static char rs[8]
    static char gs[8]
    static char bs[8]
    r = StringToInt(col[0])
    g = StringToInt(col[1])
    b = StringToInt(col[2])

    r = r < 0 ? 0 : (r > 255 ? 255 : r)
    g = g < 0 ? 0 : (g > 255 ? 255 : g)
    b = b < 0 ? 0 : (b > 255 ? 255 : b)

    Format(out,sizeof(out),"%d %d %d",r,g,b)
    FloatToString(r / 255.0,rs,sizeof(rs))
    FloatToString(g / 255.0,gs,sizeof(gs))
    FloatToString(b / 255.0,bs,sizeof(bs))


    SetClientCookie(client,h_cookieColorTeamBlue,out)
    SendConVarValue(client,h_cvarTeamBlueColorR,rs)
    SendConVarValue(client,h_cvarTeamBlueColorG,gs)
    SendConVarValue(client,h_cvarTeamBlueColorB,bs)
}

Action event_playerJump(Event event, const char[] name, bool dontBroadcast){
    int client = GetClientOfUserId(GetEventInt(event, "userid"))
    playTeamSound(client,TS_JUMP)

    return Plugin_Continue
}

Action event_disable(Event event, const char[] name, bool dontBroadcast){
    event.BroadcastDisabled = true
    return Plugin_Handled
}

Action event_playerDeath(Event event, const char[] name, bool dontBroadcast){
    int victim_id = GetEventInt(event, "userid")
    int attacker_id = GetEventInt(event, "attacker")

    int victim = GetClientOfUserId(victim_id)
    int attacker = GetClientOfUserId(attacker_id)


    int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll")
    if(ragdoll > 0){
        static float vel[3]
        GetEntPropVector(victim, Prop_Data, "m_vecAbsVelocity", vel)

        ScaleVector(vel,200.0)
        SetEntPropVector(ragdoll, Prop_Send, "m_vecForce", vel)
    }



    dropItems(victim)

    switchWeapon(victim,WEAPON_NONE,true)
    SD[victim].desiredWeapon = WEAPON_NONE

    clearOverlay(victim)
    ShowHudText(victim,3,"")
    ShowHudText(victim,4,"")
    ShowHudText(victim,5,"")
    ShowHudText(victim,6,"")

    playTeamSound(victim,TS_DEATH1 + GetRandomInt(0,2))

    //custom killicon
    event.BroadcastDisabled = true
    Event event_fake = CreateEvent("player_death", true)

    static char wpn[64]
    GetEventString(event,"weapon",wpn,sizeof(wpn))

    if(attacker < MAXPLAYERS && attacker > 0 && attacker != victim && !StrEqual(wpn,"worldspawn",false)){    //worldspawn (0) is telefrag or suicide
        event_fake.SetString("weapon", WPN[SD[attacker].activeWeapon].name)
    }else{
        event_fake.SetString("weapon", "World")
        if(!StrEqual(wpn,"worldspawn",false) || attacker == 0){    //only hide attacker if its a suicide and not a telefrag
            attacker_id = 99999
        }
    }

    if(StrEqual(wpn,"default",false)){    //default is a projectile like rocket or nade
        event_fake.SetString("weapon", WPN[SD[victim].lastProjectileDamageTaken].name)
    }

    event_fake.SetInt("userid", victim_id)
    event_fake.SetInt("attacker", attacker_id)
    event_fake.SetInt("assister", event.GetInt("assister"))
    event_fake.SetBool("headshot", false)
    event_fake.SetBool("penetrated", event.GetBool("penetrated"))
    event_fake.SetBool("revenge", false)
    event_fake.SetBool("dominated", false)

    for(int i = 1; i <= MaxClients; i++){
        if(IsClientInGame(i) && !IsFakeClient(i)){
            event_fake.FireToClient(i)
        }
    }

    event_fake.Cancel()


    //score
    if(gamestate == GS_PLAYING){
        if(GM[gamemode].killsscore){
            if(attacker > 0 && attacker < MAXPLAYERS && attacker != victim && !isTeammate(attacker,victim)){

                if(GM[gamemode].teams){
                    int team = GetClientTeam(attacker)
                    int score = CS_GetTeamScore(team) + 1

                    CS_SetTeamScore(team,score)
                    SetTeamScore(team,score)
                    checkRoundEnd()

                    checkLead(attacker)
                }
            }else{
                if(GM[gamemode].teams){
                    int team = GetClientTeam(victim)
                    int score = CS_GetTeamScore(team) - 1

                    CS_SetTeamScore(team,score)
                    SetTeamScore(team,score)

                    checkLead(victim)
                }
                
                checkRoundEnd()
            }

            if(!GM[gamemode].teams){
                int highest = -9999
                for(int i = 1;i <= MaxClients;i++){
                    if(!IsClientInGame(i)){
                        continue
                    }

                    if(GetClientFrags(i) > highest){
                        highest = GetClientFrags(i)
                    }
                }

                CS_SetTeamScore(CS_TEAM_T,highest)
                SetTeamScore(CS_TEAM_T,highest)
                checkRoundEnd()

                checkLead(attacker <= 0 || attacker >= MAXPLAYERS || isTeammate(victim,attacker) ? victim : attacker)

                if(highest == GM[gamemode].scorelimit - 3 + fragsLeftAnnounced){
                    if(fragsLeftAnnounced == 0){
                        playVoiceAll("3_frags.wav")
                    }else if(fragsLeftAnnounced == 1){
                        playVoiceAll("2_frags.wav")
                    }else if(fragsLeftAnnounced == 2){
                        playVoiceAll("1_frag.wav")
                    }

                    fragsLeftAnnounced++
                }
            }else{
                int highest = CS_GetTeamScore(CS_TEAM_CT)
                if(CS_GetTeamScore(CS_TEAM_T) > highest){
                    highest = CS_GetTeamScore(CS_TEAM_T)
                }

                if(highest == GM[gamemode].scorelimit - 3 + fragsLeftAnnounced){
                    if(fragsLeftAnnounced == 0){
                        playVoiceAll("3_frags.wav")
                    }else if(fragsLeftAnnounced == 1){
                        playVoiceAll("2_frags.wav")
                    }else if(fragsLeftAnnounced == 2){
                        playVoiceAll("1_frag.wav")
                    }

                    fragsLeftAnnounced++
                }
            }
            
            for(int i = 1;i<=MaxClients;i++){
                updateMaxRounds(i)
            }
        }else if(GM[gamemode].roundbased){
            checkRoundEnd()
        }
    }

    return Plugin_Changed
}

void checkLead(int client_scored = 0){
    if(gamestate != GS_PLAYING || !GM[gamemode].killsscore){
        return
    }

    if(GM[gamemode].teams){
        int blue = CS_GetTeamScore(CS_TEAM_CT)
        int red = CS_GetTeamScore(CS_TEAM_T)

        if(red == blue){
            playVoiceAll("lead_tied.wav")
        }else if(red == blue - 1 && ((GetClientTeam(client_scored) == CS_TEAM_CT && IsPlayerAlive(client_scored)) || (GetClientTeam(client_scored) == CS_TEAM_T && !IsPlayerAlive(client_scored))) ){
            for(int i = 1;i<=MaxClients;i++){
                if(!IsClientInGame(i)){
                    continue
                }

                if(GetClientTeam(i) == CS_TEAM_CT){
                    playVoice(i,"lead_taken.wav")
                }else if(GetClientTeam(i) == CS_TEAM_T){
                    playVoice(i,"lead_lost.wav")
                }
            }
        }else if(red - 1 == blue && ((GetClientTeam(client_scored) == CS_TEAM_T && IsPlayerAlive(client_scored)) || (GetClientTeam(client_scored) == CS_TEAM_CT && !IsPlayerAlive(client_scored))) ){
            for(int i = 1;i<=MaxClients;i++){
                if(!IsClientInGame(i)){
                    continue
                }

                if(GetClientTeam(i) == CS_TEAM_CT){
                    playVoice(i,"lead_lost.wav")
                }else if(GetClientTeam(i) == CS_TEAM_T){
                    playVoice(i,"lead_taken.wav")
                }
            }
        }
    }

    if(!GM[gamemode].teams && client_scored != 0){
        int first = -9999
        int second = -9999
        int client_score = GetClientFrags(client_scored)
        int count_first = 0


        for(int i = 1;i <= MaxClients;i++){
            if(!IsClientInGame(i)){
                continue
            }

            if(GetClientFrags(i) > first){
                first = GetClientFrags(i)
            }
        }

        for(int i = 1;i <= MaxClients;i++){
            if(!IsClientInGame(i)){
                continue
            }

            if(GetClientFrags(i) == first){
                count_first++
            }

            if(i != client_scored && GetClientFrags(i) > second){
                second = GetClientFrags(i)
            }
        }

        if(client_score == first - 1){
            if(!IsPlayerAlive(client_scored)){
                playVoice(client_scored,"lead_lost.wav")

                for(int i = 1;i <= MaxClients;i++){
                    if(!IsClientInGame(i) || i == client_scored){
                        continue
                    }

                    if(GetClientFrags(i) == first){
                        if(count_first == 1){
                            playVoice(i,"lead_taken.wav")
                        }
                    }
                }
            }
        }else if(client_score == first){
            if(count_first == 1){
                if(client_score - 1 == second && IsPlayerAlive(client_scored)){
                    playVoice(client_scored,"lead_taken.wav")

                    for(int i = 1;i <= MaxClients;i++){
                        if(!IsClientInGame(i) || i == client_scored){
                            continue
                        }

                        if(GetClientFrags(i) == first - 1){
                            playVoice(i,"lead_lost.wav")
                        }
                    }
                }
            }else{
                playVoice(client_scored,"lead_tied.wav")

                if(count_first == 2){
                    for(int i = 1;i <= MaxClients;i++){
                        if(!IsClientInGame(i) || i == client_scored || GetClientFrags(i) != first){
                            continue
                        }

                        playVoice(i,"lead_tied.wav")
                    }
                }
            }

        }
    }

}

void winRoundTeam(int team){
    if(!GM[gamemode].roundbased){
        return
    }

    if(team == CS_TEAM_NONE){
        playVoiceAll("round_draw.wav",0,GetGameTime() + 0.1)
        showStatusAll("Round Draw!")
        setGameState(GS_ROUNDEND)
        return
    }

    playVoiceAll(team == CS_TEAM_CT ? "blue_wins_round.wav" : "red_wins_round.wav",0,GetGameTime() + 0.1)
    showStatusAll(team == CS_TEAM_CT ? "Blue wins the round" : "Red wins the round",3)

    int score = CS_GetTeamScore(team) + 1

    CS_SetTeamScore(team,score)
    SetTeamScore(team,score)

    int red,blue,red_hp,blue_hp
    for(int i=1;i<=MaxClients;i++){
        updateMaxRounds(i)
        if(!IsClientInGame(i) || !IsPlayerAlive(i) || isPlayerFrozen(i)){
            continue
        }

        if(GetClientTeam(i) == CS_TEAM_T){
            red++
            red_hp += GetClientHealth(i)
        }else if(GetClientTeam(i) == CS_TEAM_CT){
            blue++
            blue_hp += GetClientHealth(i)
        }
    }

    static char desc[128]
    if(red == blue){
        Format(desc,sizeof(desc),"\x02%d\x01 hp vs \x0c%d\x01 hp", red_hp, blue_hp)
    }else if(red + blue == 1){
        Format(desc,sizeof(desc),"%d hp remaining", red_hp + blue_hp)
    }else{
        Format(desc,sizeof(desc),"%d players remaining", red+blue)
    }

    PrintToChatAll(" %s \x09WINS the round! \x01(%s)", team == CS_TEAM_T ? "\x02RED TEAM" : "\x0cBLUE TEAM",desc)
    setGameState(GS_ROUNDEND)
}

void winRoundPlayer(int client){
    //placeholder for elimination like ffa games
    //which gamemode would be ffa without respawning?
    if(!GM[gamemode].roundbased){
        return
    }

    if(client == 0){
        playVoiceAll("round_draw.wav",0,GetGameTime() + 0.1)
        restartRound()
        return
    }

    PrintToChatAll("%N \x09 WINS the round! \x01(\x09%d \x01hp)",client,GetClientHealth(client))
    CS_SetClientContributionScore(client,CS_GetClientContributionScore(client) + 1)
    restartRound()
}

void winGameTeam(int team){
    playVoiceAll(team == CS_TEAM_CT ? "blue_wins.wav" : "red_wins.wav",0,GetGameTime() + 0.1)
    playLocalSoundAll("world/buzzer.wav")
    setGameState(GS_INTERMISSION)
    
    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i)){
            continue
        }
        
        if(team == CS_TEAM_CT){
            SetHudTextParams(0.252,0.17,maxGameTime,50,100,255,255,0,0.0,0.0,0.0)
            ShowHudText(i ,3, "Blue Team WINS")
        }else if (team == CS_TEAM_T){
            SetHudTextParams(0.252,0.17,maxGameTime,255,0,0,255,0,0.0,0.0,0.0)
            ShowHudText(i ,3, "Red Team WINS")
        }    
    }
}

void winGamePlayer(int client){
    playLocalSoundAll("world/buzzer.wav")
    playVoice(client,"you_win.wav")

    setGameState(GS_INTERMISSION)

    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i)){
            continue
        }
        
        SetHudTextParams(0.252,0.17,maxGameTime,255,100,0,255,0,0.0,0.0,0.0)
        ShowHudText(i ,3, "%N WINS", client)
        
        if(i != client){
            playVoice(i,"you_lose.wav")
        }
    }
}

void checkRoundEnd(){    //this function is kind of messy since there are many edgecases
    if(!GM[gamemode].roundbased || gamestate != GS_PLAYING){
        checkGameEnd()
        return
    }

    int red = 0
    int red_hp = 0
    int blue = 0
    int blue_hp = 0
    int alive = 0

    for(int i = 1;i <= MaxClients;i++){
        if(!IsClientInGame(i) || !IsPlayerAlive(i) || isPlayerFrozen(i)){
            continue
        }

        alive = i
        if(GetClientTeam(i) == CS_TEAM_T){
            red += 1
            red_hp += GetClientHealth(i)
        }else if(GetClientTeam(i) == CS_TEAM_CT){
            blue += 1
            blue_hp += GetClientHealth(i)
        }
    }




    if(!GM[gamemode].teams){
        if(red+blue <= 1){
            if(alive != 0){
                winRoundPlayer(alive)
                return
            }else{    //shouldnt happen, but if it does, the round wouldnt restart
                print("[Q] checkRoundEnd: somehow two players died simultaneously (ffa)")
                winRoundTeam(CS_TEAM_NONE)
                return
            }
        }

        if(GM[gamemode].timelimit > 0 && GetGameTime() - GameRules_GetPropFloat("m_fRoundStartTime") > GameRules_GetProp("m_iRoundTime")){
            if(GM[gamemode].overtime == 0){
                int highest_hp = -9999
                int highest2nd_hp = -9999
                int highest_cl = 0


                for(int i = 1;i <= MaxClients;i++){
                    if(!IsClientInGame(i) || !IsPlayerAlive(i) || isPlayerFrozen(i)){
                        continue
                    }

                    if(GetClientHealth(i) > highest_hp){
                        highest_hp = GetClientHealth(i)
                        highest_cl = i
                    }
                }

                for(int i = 1;i <= MaxClients;i++){
                    if(!IsClientInGame(i) || !IsPlayerAlive(i) || isPlayerFrozen(i)){
                        continue
                    }

                    if(i != highest_cl && GetClientHealth(i) > highest2nd_hp){
                        highest2nd_hp = GetClientHealth(i)
                    }
                }

                if(highest_hp != highest2nd_hp){
                    winRoundPlayer(highest_cl)
                    return
                }else{
                    winRoundPlayer(0)
                    return
                }
            }else if(GM[gamemode].overtime == 1){    //overtime 120s
                if(!overtimeAnnounced){
                    playVoiceAll("overtime.wav",0,GetGameTime())
                    overtimeAnnounced = true
                }

                playLocalSoundAll("world/klaxon2.wav")
                showStatusAll("Overtime! 120 seconds added",3)
                GameRules_SetProp("m_iRoundTime",GameRules_GetProp("m_iRoundTime") + 120)
            }else if(GM[gamemode].overtime == 2){    //sudden death
                if(!overtimeAnnounced){
                    playVoiceAll("sudden_death.wav",0,GetGameTime())
                    overtimeAnnounced = true
                }
            }
        }




        return
    }




    if(GM[gamemode].teams){
        if(red == 0 && blue > 0){
            winRoundTeam(CS_TEAM_CT)
            return
        }else if(blue == 0 && red > 0){
            winRoundTeam(CS_TEAM_T)
            return
        }else if(blue == 0 && red == 0){
            print("[Q] checkRoundEnd: somehow two players died simultaneously")
            winRoundTeam(CS_TEAM_NONE)
            return
        }

        if(GM[gamemode].timelimit > 0 && GetGameTime() - GameRules_GetPropFloat("m_fRoundStartTime") > GameRules_GetProp("m_iRoundTime")){
            if(blue > red){
                winRoundTeam(CS_TEAM_CT)
                return
            }else if(red > blue){
                winRoundTeam(CS_TEAM_T)
                return
            }

            if(GM[gamemode].overtime == 0){
                if(red_hp > blue_hp){
                    winRoundTeam(CS_TEAM_T)
                }else if(blue_hp > red_hp){
                    winRoundTeam(CS_TEAM_CT)
                }else{
                    winRoundTeam(CS_TEAM_NONE)
                }

                return
            }else if(GM[gamemode].overtime == 1){    //overtime 120s
                if(!overtimeAnnounced){
                    playVoiceAll("overtime.wav",0,GetGameTime())
                    overtimeAnnounced = true
                }
                playLocalSoundAll("world/klaxon2.wav")
                showStatusAll("Overtime! 120 seconds added",3)
                GameRules_SetProp("m_iRoundTime",GameRules_GetProp("m_iRoundTime") + 120)
            }else if(GM[gamemode].overtime == 2){    //sudden death
                if(!overtimeAnnounced){
                    playVoiceAll("sudden_death.wav",0,GetGameTime())
                    overtimeAnnounced = true
                }
            }
        }

        return
    }
}

void checkGameEnd(){
    if(gamestate == GS_WARMUP || gamestate == GS_WARMUPEND || gamestate == GS_INTERMISSION){
        return
    }

    if(GM[gamemode].teams){
        if(gamestate == GS_PLAYING){    //forfeit
            int red = 0
            int blue = 0
            for(int i = 1;i<=MaxClients;i++){
                if(!IsClientInGame(i)){
                    continue
                }

                if(GetClientTeam(i) == CS_TEAM_T){
                    red += 1
                }

                if(GetClientTeam(i) == CS_TEAM_CT){
                    blue += 1
                }
            }

            if(red == 0){
                winGameTeam(CS_TEAM_CT)
                PrintToChatAll("Game has been forfeited.")
                return
            }

            if(blue == 0){
                winGameTeam(CS_TEAM_T)
                PrintToChatAll("Game has been forfeited.")
                return
            }
        }

        //score limit
        int score_red = GetTeamScore(CS_TEAM_T)
        int score_blue = GetTeamScore(CS_TEAM_CT)

        if(GM[gamemode].scorelimit > 0){
            if(score_red >= GM[gamemode].scorelimit){
                PrintToChatAll("Red hit the %s.",GM[gamemode].killsscore ? "fraglimit" : "roundlimit")
                winGameTeam(CS_TEAM_T)
                return
            }else if(score_blue >= GM[gamemode].scorelimit){
                PrintToChatAll("Blue hit the %s.",GM[gamemode].killsscore ? "fraglimit" : "roundlimit")
                winGameTeam(CS_TEAM_CT)
                return
            }
        }

        //time limit
        if(!GM[gamemode].roundbased && GM[gamemode].timelimit > 0 && GetGameTime() - GameRules_GetPropFloat("m_fRoundStartTime") > GameRules_GetProp("m_iRoundTime")){
            if(GM[gamemode].overtime == 0){
                PrintToChatAll("Timelimit hit.")
            }

            if(score_red > score_blue){
                winGameTeam(CS_TEAM_T)
                return
            }

            if(score_blue > score_red){
                winGameTeam(CS_TEAM_CT)
                return
            }

            if(score_red == score_blue){
                if(GM[gamemode].overtime == 1){
                    if(!overtimeAnnounced){
                        playVoiceAll("overtime.wav",0,GetGameTime())
                        overtimeAnnounced = true
                    }
                    playLocalSoundAll("world/klaxon2.wav")
                    showStatusAll("Overtime! 120 seconds added",3)
                    GameRules_SetProp("m_iRoundTime",GameRules_GetProp("m_iRoundTime") + 120)
                    return
                }else if(GM[gamemode].overtime == 2){
                    if(!overtimeAnnounced){
                        playVoiceAll("sudden_death.wav",0,GetGameTime())
                        overtimeAnnounced = true
                    }
                    return
                }

                winGameTeam(CS_TEAM_NONE)
                return
            }
        }
    }


    if(!GM[gamemode].teams){
        //forfeit/score limit
        int ingame = 0
        int ingame_cl = 0

        for(int i = 1;i<=MaxClients;i++){
            if(!IsClientInGame(i)){
                continue
            }

            if(GM[gamemode].scorelimit > 0 && GetClientFrags(i) >= GM[gamemode].scorelimit){
                winGamePlayer(i)
                PrintToChatAll("%N hit the %s.", i, GM[gamemode].killsscore ? "fraglimit" : "roundlimit")
                return
            }

            if(GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT){
                ingame += 1
                ingame_cl = i
            }
        }

        if(ingame <= 1 && gamestate == GS_PLAYING){
            winGamePlayer(ingame_cl)
            PrintToChatAll("Game has been forfeited.")
            return
        }

        //time limit
        if(!GM[gamemode].roundbased && GM[gamemode].timelimit > 0 && GetGameTime() - GameRules_GetPropFloat("m_fRoundStartTime") > GameRules_GetProp("m_iRoundTime")){
            int highest = -9999
            int highest2nd = -9999
            int highest_cl = 0

            if(GM[gamemode].overtime == 0){
                PrintToChatAll("Timelimit hit.")
            }

            for(int i = 1;i <= MaxClients;i++){
                if(!IsClientInGame(i)){
                    continue
                }

                if(GetClientFrags(i) > highest){
                    highest = GetClientFrags(i)
                    highest_cl = i
                }
            }

            for(int i = 1;i <= MaxClients;i++){
                if(!IsClientInGame(i)){
                    continue
                }

                if(i != highest_cl && GetClientFrags(i) > highest2nd){
                    highest2nd = GetClientFrags(i)
                }
            }

            if(highest != highest2nd){
                winGamePlayer(highest_cl)
                return
            }

            if(GM[gamemode].overtime == 0){
                    winGamePlayer(0)
                    return
            }else if(GM[gamemode].overtime == 1){    //overtime 120s
                if(!overtimeAnnounced){
                    playVoiceAll("overtime.wav",0,GetGameTime())
                    overtimeAnnounced = true
                }
                playLocalSoundAll("world/klaxon2.wav")
                showStatusAll("Overtime! 120 seconds added",3)
                GameRules_SetProp("m_iRoundTime",GameRules_GetProp("m_iRoundTime") + 120)
                return
            }else if(GM[gamemode].overtime == 2){    //sudden death
                if(!overtimeAnnounced){
                    playVoiceAll("sudden_death.wav",0,GetGameTime())
                    overtimeAnnounced = true
                }
                return
            }
        }
    }

}

bool isPlayerFrozen(int client){    //todo: implement with freezetag
    return false
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2]){
    static int flags
    static bool onground
    static int waterlevel
    static bool alive
    static int wpn

    static int lastbuttons
    static bool rmb
    static bool lmb
    static bool w
    static bool a
    static bool s
    static bool d

    flags = GetEntityFlags(client)
    rmb = buttons & IN_ATTACK2 != 0
    lmb = buttons & IN_ATTACK != 0
    w = buttons & IN_FORWARD != 0
    a = buttons & IN_MOVELEFT != 0
    s = buttons & IN_BACK != 0
    d = buttons & IN_MOVERIGHT != 0
    onground = flags & FL_ONGROUND != 0
    waterlevel = GetEntProp(client,Prop_Send,"m_nWaterLevel")
    alive = IsPlayerAlive(client)
    wpn = SD[client].activeWeapon

    //lastbuttons
    lastbuttons = SD[client].lastbuttons
    SD[client].lastbuttons2 = lastbuttons
    SD[client].lastbuttons = buttons

    //fast crouching, this may break with updates
    if(onground && alive){
        buttons |= IN_BULLRUSH
    }

    //cant jump while crouching
    if(buttons & IN_DUCK != 0 && (buttons & IN_JUMP != 0)){
        //buttons &= ~IN_DUCK
        buttons &= ~IN_JUMP
    }

    //fov
    if(!rmb && lastbuttons & IN_ATTACK2 != 0){
        SetEntPropFloat(client,Prop_Send,"m_flFOVTime",GetGameTime())
        SetEntProp(client, Prop_Send, "m_iFOV",SD[client].fov)
        SetEntProp(client, Prop_Send, "m_iDefaultFOV",SD[client].fov)
        SetEntProp(client,Prop_Send,"m_iFOVStart",SD[client].fovZoom)
        SetEntPropFloat(client,Prop_Send,"m_flFOVRate",SD[client].fovSmooth ? 0.2 : 0.0)
        SetEntProp(client,Prop_Send,"m_bDrawViewmodel",1)
    }

    if(rmb && lastbuttons & IN_ATTACK2 == 0){
        SetEntPropFloat(client,Prop_Send,"m_flFOVTime",GetGameTime())
        SetEntProp(client, Prop_Send, "m_iFOV",SD[client].fovZoom)
        SetEntProp(client, Prop_Send, "m_iDefaultFOV",SD[client].fov)
        SetEntProp(client,Prop_Send,"m_iFOVStart",SD[client].fov)
        SetEntPropFloat(client,Prop_Send,"m_flFOVRate",SD[client].fovSmooth ? 0.2 : 0.0)
        SetEntProp(client,Prop_Send,"m_bDrawViewmodel",0)
    }

    //movement
    if(!onground && waterlevel == 0 && GetEntityMoveType(client) == MOVETYPE_WALK){
        static float vel2[3]
        static float eyeang[3]
        static float fwd[3]
        static float right[3]
        static float newvel[3]
        static float currentspeed
        static float addspeed
        static float wishdir[3]
        static float wishspeed

        GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vel2)
        GetClientEyeAngles(client,eyeang)
        GetAngleVectors(eyeang,fwd,right,NULL_VECTOR)
        newvel = vel2
        wishspeed = hasPowerup(client,PW_HASTE) ? 416.0 : 320.0

        wishdir[0] = 0.0
        wishdir[1] = 0.0
        wishdir[2] = 0.0

        if(w){
            wishdir[0] += fwd[0]
            wishdir[1] += fwd[1]
        }

        if(s){
            wishdir[0] -= fwd[0]
            wishdir[1] -= fwd[1]
        }

        if(d){
            wishdir[0] += right[0]
            wishdir[1] += right[1]
        }

        if(a){
            wishdir[0] -= right[0]
            wishdir[1] -= right[1]
        }

        NormalizeVector(wishdir,wishdir)

        currentspeed = GetVectorDotProduct(vel2,wishdir)
        addspeed = wishspeed - currentspeed
        addspeed = addspeed < 0 ? 0 : addspeed
        addspeed = addspeed > (wishspeed * GetTickInterval()) ? (wishspeed * GetTickInterval()) : addspeed
        addspeed *= 0.8

        newvel[0] += wishdir[0] * addspeed
        newvel[1] += wishdir[1] * addspeed


        SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", newvel)
    
        //ledgegrab
        if(lg_enabled){        //allow players to "step" onto ledges while in air
            //this is a weird way to detect if the player is up against a wall. kinda jank but i dont wanna fire one trace per player per tick
            if( ((vel2[0] == 0.0 && wishdir[0] != 0.0) || (vel2[1] == 0.0 && wishdir[1] != 0.0)) && SD[client].lg_fakeground < 3){
                static bool grab
                grab = 0

                if(waterlevel == 0 && vel2[2] > 0.0 && SD[client].lg_fakeground & 1 == 0){    //you get one grab while falling and one while moving upwards
                    SD[client].lg_fakeground |= 1
                    grab = 1
                }

                if(waterlevel == 0 && vel2[2] < 0.0 && SD[client].lg_fakeground & 2 == 0){
                    SD[client].lg_fakeground |= 2
                    grab = 1
                }

                if(grab){
                    //set the client to be "onground" so he can step onto the ledge if the distance is below "m_flStepSize"
                    SetEntPropFloat(client,Prop_Send,"m_flStamina",0.0)
                    SetEntPropEnt(client,Prop_Send,"m_hGroundEntity",0)
                    SetEntityFlags(client,flags | FL_ONGROUND)

                    SD[client].lg_oldspeed = newvel
                    RequestFrame(rf_lgRestoreSpeed,client)
                }



            }

            if(SD[client].lg_fakeground != 0){
                buttons &= ~IN_JUMP        //prevent jumping if the player is not actually on the ground
            }
        }
    }


   //attack stuff
    if(wpn == WEAPON_GAUNTLET){
        if(!lmb && (lastbuttons & IN_ATTACK != 0)){    //lmb was held last tick, but released this tick
            //StopSound(client,SNDCHAN_AUTO,"weapons/melee/fstrun.wav")
            TriggerTimer(SD[client].wpnSoundHumTimer,true)
        }
    }

    if(wpn == WEAPON_LIGHTNING){    //lightninggun stuff
        if(lmb && lastbuttons & IN_ATTACK == 0 && SD[client].wpnAmmo[WEAPON_LIGHTNING] > 0){    //lmb not pressed last tick, but now pressed
            TriggerTimer(SD[client].wpnSoundHumTimer,true)
        }

        //stop lightning sound
        if(!lmb && (lastbuttons & IN_ATTACK != 0)){    //lmb was held last tick, but released this tick
            StopSound(client,SNDCHAN_AUTO,"weapons/lightning/lg_hum.wav")
            TriggerTimer(SD[client].wpnSoundHumTimer,true)
        }

        //lightning smooth laser
        static float pos[3]
        static float ang[3]
        static float endpos[3]
        static float fwd[3]
        static Handle trace

        if(lightning_smooth_beam && lmb){
            lightning_activebeams += 1

            if(lightning_activebeams <= lightning_smooth_beam_limit){
                GetClientEyePosition(client,pos)
                GetClientEyeAngles(client,ang)
                GetAngleVectors(ang,fwd,NULL_VECTOR,NULL_VECTOR)

                endpos[0] = pos[0] + fwd[0] * LIGHTNING_LENGTH
                endpos[1] = pos[1] + fwd[1] * LIGHTNING_LENGTH
                endpos[2] = pos[2] + fwd[2] * LIGHTNING_LENGTH

                trace = TR_TraceRayFilterEx(pos,endpos,MASK_SHOT,RayType_EndPoint,trFilterSelf,client )
                if( TR_DidHit(trace) ){
                    TR_GetEndPosition(endpos,trace)
                }
                CloseHandle(trace)

                updateWpnTargets(client,endpos,true)
            }
        }
    }

    //weapon switching         not sure if this is the best place to do it, but why not since the players are already being looped here.
    static int desired
    desired = SD[client].desiredWeapon

    if(desired != WEAPON_NONE && desired != wpn){
        if(SD[client].nextPrimaryAttack < GetGameTime()){
            switchWeapon(client,desired)
        }
    }

    return Plugin_Continue
}

void rf_lgRestoreSpeed(int client){
    static float v[3]
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", v)    //this is their speed while they are "on ground"

    if(v[2] != 0.0){    //if they are affected by gravity after one tick they did not walk onto a ledge
        SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", SD[client].lg_oldspeed)        //restore their old speed so they cant cancel falldamage
    }else{    //0.0 means they successfully stepped onto a ledge
        if(SD[client].lg_oldspeed[2] <= -800.0){    //make sure they still get falldamage after walking onto a ledge
            playTeamSound(client,TS_FALL)
            damagePlayer(client,0,0, 10.0,DMG_FALL)
        }else if(SD[client].lg_oldspeed[2] <= -650.0){
            playTeamSound(client,TS_PAIN100)
            damagePlayer(client,0,0, 5.0,DMG_FALL)
        }else{
            playWeaponSound("player/land1.wav",client,_,_,_,0.2)
        }
    }
}

public void OnClientPutInServer(int client){
    SDKHook(client, SDKHook_OnTakeDamage, hook_onTakeDamage)
    SDKHook(client, SDKHook_ShouldCollide, hook_lagcompShouldCollide)
    SDKHook(client, SDKHook_GroundEntChangedPost, hook_onClientGroundChange)
    SDKHook(client, SDKHook_PreThinkPost, hook_preThinkPost)
    DHookEntity(h_getPlayerMaxSpeed, true, client)
    
    if(SD[client].wpnAimTarget >= MAXPLAYERS){
        RemoveEntity(SD[client].wpnAimTarget)
    }
    
    if(SD[client].wpnAttachmentTarget >= MAXPLAYERS){
        RemoveEntity(SD[client].wpnAttachmentTarget)
    }
    
    if(SD[client].wpnVMTarget >= MAXPLAYERS){
        RemoveEntity(SD[client].wpnVMTarget)
    }
    
    if(IsValidHandle(SD[client].wpnSoundHumTimer)){
        delete SD[client].wpnSoundHumTimer
    }
    
    SlotData s
    SD[client] = s
    initPlayerData(client)
    
    if(IsFakeClient(client)){
        ChangeClientTeam(client, CS_TEAM_SPECTATOR)
        FakeClientCommand(client, "jointeam 0 1")
    }
    
    SetEntProp(client, Prop_Send, "m_iFOV",SD[client].fov)
    SetEntProp(client, Prop_Send, "m_iDefaultFOV",SD[client].fov)
    
    for(int i = 1;i <= MaxClients;i++){    //for some reason when one client joins all other clients lose their overlay?
        if(IsClientInGame(i) && !IsFakeClient(i)){
            showOverlay(i)
        }
    }
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen){
    if(h_cvarQNoBots.BoolValue && IsFakeClient(client)){
        ServerCommand("bot_kick %N",client)
        return false
    }
    
    RequestFrame(updateMaxRounds,client)
    return true
}

void updateMaxRounds(int client){
    if(!IsClientConnected(client) || IsClientInGame(client) || IsFakeClient(client)){
        return
    }
    
    static char buf[230] //using SendConVarValue with more than 230 characters crashes the server :/
    
    if(lastMaxRounds + 1.0 > GetGameTime()){
        SendConVarValue(client, h_cvarMaxRounds, buf)
    }else{
        static float f_timeleft
        static int i_timeleft
        static int players
        static char score2[64]
        
        players = 0
        for(int i = 1;i<MaxClients;i++){
            if(IsClientInGame(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR){
                players++
            }
        }
        
        if(GM[gamemode].teams){
            Format(score2,sizeof(score2),"- <font color='#00f'>%d</font> /", GetTeamScore(CS_TEAM_CT))
        }else{
            score2 = "/"
        }
        
        f_timeleft = (GameRules_GetProp("m_iRoundTime") * 1.0 - (GetGameTime() - GameRules_GetPropFloat("m_fRoundStartTime"))) / 60.0
        i_timeleft = RoundFloat(f_timeleft)
        i_timeleft = i_timeleft > 0 ? i_timeleft : 0
        
        Format(buf,sizeof(buf),
            "\n\n\n\n<font class='fontSize-l'>%s\n%d / %d %s\nScore: <font%s>%d</font> %s %d\n%s: %dm / %dm</font>\n<img src='https://i.imgur.com/BjRosYH.png'>\n\n\n\n\n\n\n\n\n\n",
            GM[gamemode].name,
            players, GM[gamemode].maxPlayers, gamestate == GS_WARMUP ? "in warmup" : "playing",
            GM[gamemode].teams ? " color='#f00'" : "",GetTeamScore(CS_TEAM_T), score2, GM[gamemode].scorelimit,
            GM[gamemode].roundbased ? "Roundtime left" : "Time left", i_timeleft, GM[gamemode].timelimit / 60
        )
        
        SendConVarValue(client,h_cvarMaxRounds,buf)
        lastMaxRounds = GetGameTime()
    }
}


public void OnMapStart(){
    clearData()

    GetCurrentMap(currentMap,sizeof(currentMap))
    addMapcontentToDownloadTable()

    precacheCustomAssets()
    setupStringtableIndexes()

    mapVoteWon = 0
    lastMaxRounds = 0.0
    
      RequestFrame(rf_onMapStart)
}

void rf_onMapStart(){
    event_roundStart(null,"",true)
    setGamemode(gamemode)
}

Action te_Shotgun_shot(const char[] te_name, const int[] Players, int numClients, float delay){
    return Plugin_Handled
}

Action te_EffectDispatch(const char[] te_name, const int[] Players,int  numClients, float delay){
    int iEffectIndex = TE_ReadNum("m_iEffectName")

    if(csbloodEffectIndex == iEffectIndex)
        return Plugin_Handled

    return Plugin_Continue
}

Action te_OnDecal(const char[] te_name, const int[] Players, int numClients, float delay){
    int nIndex = TE_ReadNum("m_nIndex")
    char sDecalName[64]

    ReadStringTable(decalPrecacheTable, nIndex, sDecalName, sizeof(sDecalName))

    if(StrContains(sDecalName, "decals/blood") == 0){
        return Plugin_Handled
    }

    return Plugin_Continue
}

Action command_qgive(int client, const char[] name, int argc){
    if(!h_cvarCheats.BoolValue){
        PrintToConsole(client,"Cheats are disabled")
        return Plugin_Handled
    }
    
    static char args[256]
    GetCmdArgString(args,sizeof(args))
    
    if(args[0] == 0){
        return Plugin_Handled
    }
    
    int item = 0
    for(int i = 0;i<IT_NUM_ITEMS;i++){
        if(IT[i].name[0] == 0){
            continue
        }
        
        if(!strcmp(IT[i].name, args,false)){
            item = i
            break
        }
    }
    
    if(item == 0){
        return Plugin_Handled
    }

    static float pos[3]
    GetEntPropVector(client,Prop_Data,"m_vecAbsOrigin",pos)
    
    SEnt s
    s.item = item
    s.senttype = IT[item].type
    s.valid = true
    s.dropped = true

    s.origin = pos
    s.respawn = false
    s.respawnTime = GetGameTime() + 30.0
    s.count = IT[item].count

    spawnItem(s,true)
    checkItemPickup(s)
    
    return Plugin_Handled
}


// Action command_dev(int client, const char[] name, int argc){
//     char arg[128]
//     GetCmdArg(1,arg,128)
//     char args[2048]
//     GetCmdArgString(args,2048)
//     int num = StringToInt(arg)
//     float numf = StringToFloat(arg)
    
//      return Plugin_Handled
// }

Action command_say(int sender, const char[] command, int argc){
    static char msg[64]
    GetCmdArgString(msg,sizeof(msg))
    StripQuotes(msg)
    TrimString(msg)

    if(msg[0] == 0){
        return Plugin_Continue
    }

    if(strncmp("!bots",msg,5) == 0){    //todo: do this properly
        ServerCommand("bot_kick")
        return Plugin_Handled
    }

    if(strncmp("!menu",msg,5) == 0){
        displayMainMenu(sender)
        return Plugin_Handled
    }

    if(strncmp("!ready",msg,6) == 0){
        command_ready(sender,"",0)
        return Plugin_Handled
    }

    for(int client = 1; client<=MaxClients; client++){
        if(IsClientInGame(client) /*&& (IsPlayerAlive(client) == IsPlayerAlive(sender) || !IsPlayerAlive(client))*/ && !IsClientMuted(client,sender) ){
            playLocalSound(client, "player/talk.wav")
        }
    }

    return Plugin_Continue
}

Action command_sayTeam(int sender, const char[] command, int argc){
    static char msg[64]
    GetCmdArgString(msg,sizeof(msg))
    StripQuotes(msg)
    TrimString(msg)

    if(msg[0] == 0){
        return Plugin_Continue
    }

    for(int client = 1; client<=MaxClients; client++){
        if(IsClientInGame(client)){
            bool play = true

            if(!IsPlayerAlive(sender) && IsPlayerAlive(client)){
                play = false
             }

            if(GetClientTeam(sender)!= GetClientTeam(client)){
                play = false
            }

            if(IsClientMuted(client,sender)){
                play = false
            }

            if(play)
                playLocalSound(client, "player/talk.wav")
            }
    }

    return Plugin_Continue
}

Action event_weaponFire(Handle event, const char[] name, bool dontBroadcast){
    static int client
    static int alive
    static int i
    client = GetClientOfUserId(GetEventInt(event, "userid"))
    alive = 0

    for(i = 1;i<=MaxClients;i++){
        if(IsClientInGame(i) && IsPlayerAlive(i)){
            alive++
            if(alive > 1){
                break
            }
        }
    }

    if(alive < 2){    //nothing to lagcompensate, onlagcompensate wont be called
        onPlayerAttack(client)
    }else{
        last_client_shot = client
    }

    RequestFrame(rf_updateNextPrimaryAttack,client)

    return Plugin_Continue
}

void showRailLaser(int client){
    int vis_tp[MAXPLAYERS + 1]
    int vis_fp[MAXPLAYERS + 1]
    int count_tp = 0
    int count_fp = 0

    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || IsFakeClient(i)){
            continue
        }

        if(i == client || (GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client && GetEntProp(i, Prop_Send, "m_iObserverMode") == 4)){
            vis_fp[count_fp++] = i
        }else{
            vis_tp[count_tp++] = i
        }

    }

    static int alpha = 0
    for(float i = 0.0;i<0.3;i += 0.051){
        alpha = RoundToZero((0.333-i) * (1/0.333) * 220.0)

        if(count_fp > 0){
            TE_Start("BeamEntPoint")
            TE_WriteEncodedEnt("m_nStartEntity", SD[client].wpnVMTarget)
            TE_WriteEncodedEnt("m_nEndEntity", SD[client].wpnAimTarget)
            TE_WriteNum("m_nModelIndex", railLaserSprite);
            TE_WriteNum("m_nHaloIndex", 0)
            TE_WriteNum("m_nStartFrame", 0)
            TE_WriteNum("m_nFrameRate", 0)
            TE_WriteFloat("m_fLife", 0.051)
            TE_WriteFloat("m_fWidth", 5.0)
            TE_WriteFloat("m_fEndWidth", 5.0)
            TE_WriteFloat("m_fAmplitude", 0.0)
            TE_WriteNum("r", railColors[SD[client].railColor][0])
            TE_WriteNum("g", railColors[SD[client].railColor][1])
            TE_WriteNum("b", railColors[SD[client].railColor][2])
            TE_WriteNum("a", alpha)
            TE_WriteNum("m_nSpeed", 0)
            TE_WriteNum("m_nFadeLength", -1)

            TE_Send(vis_fp,count_fp,i)
        }

        if(count_tp > 0){
            TE_Start("BeamEntPoint")
            TE_WriteEncodedEnt("m_nStartEntity", SD[client].wpnAttachmentTarget)
            TE_WriteEncodedEnt("m_nEndEntity", SD[client].wpnAimTarget)
            TE_WriteNum("m_nModelIndex", railLaserSprite)
            TE_WriteNum("m_nHaloIndex", 0)
            TE_WriteNum("m_nStartFrame", 0)
            TE_WriteNum("m_nFrameRate", 0)
            TE_WriteFloat("m_fLife",0.051)
            TE_WriteFloat("m_fWidth", 5.0)
            TE_WriteFloat("m_fEndWidth", 5.0)
            TE_WriteFloat("m_fAmplitude", 0.0)
            TE_WriteNum("r", railColors[SD[client].railColor][0])
            TE_WriteNum("g", railColors[SD[client].railColor][1])
            TE_WriteNum("b", railColors[SD[client].railColor][2])
            TE_WriteNum("a", alpha)
            TE_WriteNum("m_nSpeed", 0)
            TE_WriteNum("m_nFadeLength", -1)

            TE_Send(vis_tp,count_tp,i)
        }


    }
}

void showLightningLaser(int client){
    int vis_tp[MAXPLAYERS + 1]
    int vis_fp[MAXPLAYERS + 1]
    int count_tp = 0
    int count_fp = 0

    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || IsFakeClient(i)){
            continue
        }

        if(i == client || (GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client && GetEntProp(i, Prop_Send, "m_iObserverMode") == 4)){
            vis_fp[count_fp++] = i
        }else{
            vis_tp[count_tp++] = i
        }

    }

    if(count_fp > 0){
        TE_Start("BeamEntPoint");
        TE_WriteEncodedEnt("m_nStartEntity", SD[client].wpnAimTarget)
        TE_WriteEncodedEnt("m_nEndEntity", SD[client].wpnVMTarget)
        TE_WriteNum("m_nModelIndex", lightningSprite)
        TE_WriteNum("m_nHaloIndex", 0)
        TE_WriteNum("m_nStartFrame", 0)
        TE_WriteNum("m_nFrameRate", 45)
        TE_WriteFloat("m_fLife", 0.051)
        TE_WriteFloat("m_fWidth", 5.0)
        TE_WriteFloat("m_fEndWidth", 5.0)
        TE_WriteFloat("m_fAmplitude", 0.0)
        TE_WriteNum("r", 255)
        TE_WriteNum("g", 255)
        TE_WriteNum("b", 255)
        TE_WriteNum("a", 255)
        TE_WriteNum("m_nSpeed", 20)
        TE_WriteNum("m_nFadeLength", -1)

        TE_Send(vis_fp,count_fp)
    }

    if(count_tp > 0){
        TE_Start("BeamEntPoint")
        TE_WriteEncodedEnt("m_nStartEntity",  SD[client].wpnAimTarget)
        TE_WriteEncodedEnt("m_nEndEntity", SD[client].wpnAttachmentTarget)
        TE_WriteNum("m_nModelIndex", lightningSprite)
        TE_WriteNum("m_nHaloIndex", 0)
        TE_WriteNum("m_nStartFrame", 0)
        TE_WriteNum("m_nFrameRate", 0)
        TE_WriteFloat("m_fLife",0.051)
        TE_WriteFloat("m_fWidth", 5.0)
        TE_WriteFloat("m_fEndWidth", 5.0)
        TE_WriteFloat("m_fAmplitude", 0.0)
        TE_WriteNum("r", 255)
        TE_WriteNum("g", 255)
        TE_WriteNum("b", 255)
        TE_WriteNum("a", 255)
        TE_WriteNum("m_nSpeed", 20)
        TE_WriteNum("m_nFadeLength", -1)

        TE_Send(vis_tp,count_tp)
    }

}

void createBulletHit(int weapon, Handle trace){
    static float pos[3]
    static float ang[3]
    static float plane[3]

    if(newest_ent_idx > 1850){    //rough safeguard since we dont track these entities
        print("[Q] skip createBulletHit due to entity limit")
        return
    }

    if(trHitSky(trace)){
        return
    }

    TR_GetPlaneNormal(trace,plane)
    TR_GetEndPosition(pos,trace)
    GetVectorAngles(plane,ang)

    static int prop
    prop = CreateEntityByName("prop_dynamic")

    if(weapon == WEAPON_PLASMAGUN || weapon == WEAPON_RAILGUN){
        DispatchKeyValue(prop, "model", "models/weaphits/ring02.mdl")
        DispatchKeyValue(prop, "modelscale", weapon == WEAPON_PLASMAGUN ? "0.85" : "1.0")
        DispatchKeyValue(prop, "renderamt",  weapon == WEAPON_PLASMAGUN ? "128" : "64")
    }else{
        DispatchKeyValue(prop, "model", "models/weaphits/bullet.mdl")
    }

    DispatchKeyValue(prop, "classname", "prop_dynamic")
    DispatchKeyValue(prop, "solid", "0")
    DispatchKeyValue(prop, "rendermode", "3")

    TeleportEntity(prop,pos,ang,NULL_VECTOR)
    DispatchSpawn(prop)


    //we do this so we dont have to keep track of these entities and clean them up
    if(weapon == WEAPON_RAILGUN){
        SetVariantString("OnUser1 !self:Skin:1:0.1375:1")
        AcceptEntityInput(prop,"AddOutput")
        AcceptEntityInput(prop,"FireUser1")

        SetVariantString("OnUser2 !self:Skin:2:0.275:1")
        AcceptEntityInput(prop,"AddOutput")
        AcceptEntityInput(prop,"FireUser2")

        SetVariantString("OnUser3 !self:Skin:3:0.4125:1")
        AcceptEntityInput(prop,"AddOutput")
        AcceptEntityInput(prop,"FireUser3")

        SetVariantString("OnUser4 !self:Kill::0.55:1")
        AcceptEntityInput(prop,"AddOutput")
        AcceptEntityInput(prop,"FireUser4")
        return
    }

    if(weapon == WEAPON_PLASMAGUN){
        SetVariantString("4")
        AcceptEntityInput(prop,"Skin")

        SetVariantString("OnUser1 !self:Alpha:96:0.125:1")
        AcceptEntityInput(prop,"AddOutput")
        AcceptEntityInput(prop,"FireUser1")

        SetVariantString("OnUser2 !self:Alpha:64:0.25:1")
        AcceptEntityInput(prop,"AddOutput")
        AcceptEntityInput(prop,"FireUser2")

        SetVariantString("OnUser3 !self:Alpha:32:0.375:1")
        AcceptEntityInput(prop,"AddOutput")
        AcceptEntityInput(prop,"FireUser3")

        SetVariantString("OnUser4 !self:Kill::0.5:1")
        AcceptEntityInput(prop,"AddOutput")
        AcceptEntityInput(prop,"FireUser4")

        return
    }

    SetVariantString("OnUser1 !self:Skin:1:0.1:1")
    AcceptEntityInput(prop,"AddOutput")
    AcceptEntityInput(prop,"FireUser1")

    SetVariantString("OnUser2 !self:Skin:2:0.2:1")
    AcceptEntityInput(prop,"AddOutput")
    AcceptEntityInput(prop,"FireUser2")

    SetVariantString("OnUser3 !self:Kill::0.3:1")
    AcceptEntityInput(prop,"AddOutput")
    AcceptEntityInput(prop,"FireUser3")

}

void showMuzzleFlash(int client,int weapon){
    int vis_tp[MAXPLAYERS + 1]
    int vis_fp[MAXPLAYERS + 1]
    int count_tp = 0
    int count_fp = 0

    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || IsFakeClient(i)){
            continue
        }

        if(i == client || (GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client && GetEntProp(i, Prop_Send, "m_iObserverMode") == 4)){
            vis_fp[count_fp++] = i
        }else{
            vis_tp[count_tp++] = i
        }

    }

        if(count_fp > 0){
            static float pos[3]
            static float ang[3]

            GetEntPropVector(SD[client].wpnVMTarget, Prop_Data, "m_vecAbsOrigin", pos)
            GetClientEyeAngles(client,ang)

            TE_Start("MuzzleFlash")
            TE_WriteVector("m_vecOrigin", pos)
            TE_WriteVector("m_vecAngles", ang)
            TE_WriteFloat("m_flScale", 0.5)
            TE_WriteNum("m_nType", 1)

            TE_Send(vis_fp,count_fp)
        }

        if(count_tp > 0){
            static float pos[3]
            static float ang[3]

            GetEntPropVector(SD[client].wpnAttachmentTarget, Prop_Data, "m_vecAbsOrigin", pos)
            GetClientEyeAngles(client,ang)

            TE_Start("MuzzleFlash")
            TE_WriteVector("m_vecOrigin", pos)
            TE_WriteVector("m_vecAngles", ang)
            TE_WriteFloat("m_flScale", 0.5)
            TE_WriteNum("m_nType", 1)

            TE_Send(vis_tp,count_tp)
        }
}

bool trWriteArray(int ent){
    for(int i = 0; i < sizeof(trEnumerateEnts);i++){
        if(trEnumerateEnts[i] == 0){
            trEnumerateEnts[i] = ent        
            return true
        }
    }

    return false
}

bool trFilterPlayers(int entity, int mask, any data){ //filter out all players, except data player
    return (data != 0 && entity == data) || (entity >= MAXPLAYERS)
}

bool trFilterAllowPlayers(int entity, int mask, any data){ //filter out everything except players
    return entity < MAXPLAYERS && entity > 0
}

bool trFilterAll(int entity, int mask, any data){ //filter out every ent
    return false
}

bool trFilterRailAlreadyHit(int entity, int mask,any data){
    if(data == entity){
        return false
    }

    for(int i = 0;i<=MaxClients;i++){
        if(trRailHits[i] == entity){
            return false
        }
    }


    if(entity < MAXPLAYERS){ //if its another player we dont need to check for sents
        return true
    }

    //also filter out pickups
    for(int i = 0;i<sents_count;i++){
        if(!sents[i].valid){
            continue
        }
        
        if(entity == sents[i].ent || entity == sents[i].phys){
            return false
        }
    }

    for(int i = 0;i<sizeof(sents_dropped);i++){
        if(!sents_dropped[i].valid){
            continue
        }
        
        if(entity == sents_dropped[i].ent || entity == sents_dropped[i].phys){
            return false
        }
    }

    return true
}

bool trFilterSelf(int entity, int mask, any data){
    if(entity == data){
        return false
    }


    if(entity < MAXPLAYERS){ //if its another player we dont need to check for sents
        return true
    }

    //also filter out pickups
    for(int i = 0;i<sents_count;i++){
        if(!sents[i].valid){
            continue
        }
        
        if(entity == sents[i].ent || entity == sents[i].phys){
            return false
        }
    }

    for(int i = 0;i<sizeof(sents_dropped);i++){
        if(!sents_dropped[i].valid){
            continue
        }
        
        if(entity == sents_dropped[i].ent || entity == sents_dropped[i].phys){
            return false
        }
    }

    return true
}

bool trFilterSelfAndPlayers(int entity, int mask, any data){
    if(entity == data){
        return false
    }


    if(entity < MAXPLAYERS){ //if its another player we dont need to check for sents
        return false
    }

    //also filter out pickups
    for(int i = 0;i<sents_count;i++){
        if(!sents[i].valid){
            continue
        }
        
        if(entity == sents[i].ent || entity == sents[i].phys){
            return false
        }
    }

    for(int i = 0;i<sizeof(sents_dropped);i++){
        if(!sents_dropped[i].valid){
            continue
        }
        
        if(entity == sents_dropped[i].ent || entity == sents_dropped[i].phys){
            return false
        }
    }

    return true
}

public void OnClientDisconnect_Post(int client){
    dontReconnect[client] = false
}

void event_clientConnectFull(Handle event, const char[] name, bool dontBroadcast){
    int client = GetClientOfUserId(GetEventInt(event, "userid"))

    if( !(IsFakeClient(client) || dontReconnect[client]) ){
        ReconnectClient(client)
        dontReconnect[client] = true
        return
    }
    
    RequestFrame(rf_assignTeam,client)
    displayWeaponSelectionPanel(client)
    SendConVarValue(client, h_cvarMaxRounds, "10000")

     static char sid[32]
     GetClientAuthId(client, AuthId_SteamID64, sid, sizeof(sid))
    print("Player \"%N\" (%s) fully connected",client,sid)
}

void rf_assignTeam(int client){    //prevent teamselect timeout on inital connect
    ChangeClientTeam(client, CS_TEAM_SPECTATOR)
    ClientCommand(client,"teammenu")
}

void event_playerTeam(Handle event, const char[] name, bool dontBroadcast){
    int client = GetClientOfUserId(GetEventInt(event, "userid"))
    int team = GetEventInt(event, "team")
    bool disconnected = GetEventBool(event,"disconnect")

    RequestFrame(rf_playerTeamPost,client)
    
    if(gamestate == GS_WARMUP){
        SD[client].ready = false
        CreateTimer(0.1, t_updateReadyText,client)
    }
    
    if(SD[client].queueTime != 0.0){
        SD[client].queueTime = 0.0
        setNameSilent(client,SD[client].name)
        updateQueueNames()
    }

    if(disconnected){
        returnKeys(client)
        return
    }

    if(!IsFakeClient(client)){
        static char t[8]
        IntToString(team,t,sizeof(t))
        SendConVarValue(client,h_cvarYourTeam,t)
    }
}

Action t_updateReadyText(Handle timer, int client){
    if(gamestate != GS_WARMUP || (client != 0 && !IsClientInGame(client))){
        return Plugin_Stop
    }
    
    static int count
    count = 0
    
    for(int i = 1;i<=MaxClients;i++){
        if(IsClientInGame(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR){
            count++
        }
    }

    if(count == 1){
        for(int i=1;i<=MaxClients;i++){
            if(!IsClientInGame(i) || GetClientTeam(i) <= CS_TEAM_SPECTATOR){
                continue
            }
            
            showFunfact(i,"<br><br><font class='fontSize-xl'>The match will begin<br>when more players join.</font>")
        }
    }else if(count == 2){    //second player just joined
        for(int i=1;i<=MaxClients;i++){
            if(!IsClientInGame(i) || GetClientTeam(i) <= CS_TEAM_SPECTATOR){
                continue
            }
            
            SD[i].ready = false
            showFunfact(i,"<br><br><font class='fontSize-xl'>The match will begin<br>when more players are ready.</font><br><font color='#ff0000' class='fontSize-xl fontWeight-Bold'>Press F3 to ready yourself</font>")
        }
    }else {
        if(client == 0){
            for(int i=1;i<=MaxClients;i++){
                if(!IsClientInGame(i) || GetClientTeam(i) <= CS_TEAM_SPECTATOR){
                    continue
                }
                
                showFunfact(i,"<br><br><font class='fontSize-xl'>The match will begin<br>when more players are ready.</font><br><font color='#ff0000' class='fontSize-xl fontWeight-Bold'>Press F3 to ready yourself</font>")
            }
        }else{
            if(GetClientTeam(client) > CS_TEAM_SPECTATOR){
                showFunfact(client,"<br><br><font class='fontSize-xl'>The match will begin<br>when more players are ready.</font><br><font color='#ff0000' class='fontSize-xl fontWeight-Bold'>Press F3 to ready yourself</font>")
            }else{
                showFunfact(client,"")
            }
        }
    }

    if(client > 0 && IsClientInGame(client) && GetClientTeam(client) > CS_TEAM_SPECTATOR){
        static char buf[128]
        Format(buf,sizeof(buf),"%N joined%s",client,GM[gamemode].teams ? (GetClientTeam(client) == CS_TEAM_CT ? " the Blue Team." : " the Red Team.") : ".")
        showStatusAll(buf,5)
    }

    return Plugin_Stop
}

void rf_playerTeamPost(int data){
    checkGameEnd()
    checkRoundEnd()
    checkReady()
    
    if(gamestate == GS_INTERMISSION){
        return
    }
    
    int players
    float q_lowest = maxGameTime
    int q_cl
    
    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i)){
            continue
        }
        
        if(GetClientTeam(i) > CS_TEAM_SPECTATOR){
            players++
        }
        
        if(GetClientTeam(i) == CS_TEAM_SPECTATOR && SD[i].queueTime != 0.0){
            if(SD[i].queueTime < q_lowest){
                q_lowest = SD[i].queueTime
                q_cl = i
            }
        }
    }
    
    if(players < GM[gamemode].maxPlayers && q_cl != 0){
        FakeClientCommand(q_cl, "jointeam 0 1") //join autoselect
    }
}

void updateQueueNames(){
    float times[MAXPLAYERS + 1]
    int num
    
    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || SD[i].queueTime == 0.0 || GetClientTeam(i) > CS_TEAM_SPECTATOR){
            continue
        }
        
        times[num++] = SD[i].queueTime
    }
    
    SortFloats(times,sizeof(times),Sort_Ascending)
    num = 0
    
    for(int i = 0;i<sizeof(times);i++){
        if(times[i] == 0.0){
            continue
        }
        
        int cl
        for(int c = 1;c <= MaxClients;c++){
            if(!IsClientInGame(c)){
                continue
            }
            
            if(times[i] == SD[c].queueTime){
                cl = c
                break
            }
        }
        
        if(cl == 0){
            continue
        }
        
        num++
        static char newname[64]
        Format(newname, sizeof(newname), "(%d) %s", num, SD[cl].name)
        setNameSilent(cl, newname)
    }
}

void checkReady(){
    if(gamestate != GS_WARMUP){
        return
    }

    int count = 0
    int count_a = 0
    int ready = 0

    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || GetClientTeam(i) <= CS_TEAM_SPECTATOR){
            continue
        }

        count_a++
        count += !IsFakeClient(i)
        ready += SD[i].ready
    }

    if(count_a < 2){
        return
    }

    if((ready * 1.0) / (count * 1.0) > 0.5){
        setGameState(GS_WARMUPEND)
    }
}

void restartRound(){
    checkGameEnd()

    if(gamestate == GS_INTERMISSION){
        return
    }

    for (int i=1; i<=MaxClients; i++){
        if (!IsClientInGame(i)){
            continue
        }

        if(gamemode == GM_FT && !isPlayerFrozen(i) && IsPlayerAlive(i) ){
            onPlayerSpawn(i)
            continue
        }

        returnKeys(i)
        CS_RespawnPlayer(i)
    }

    if(GM[gamemode].items){
        //not sure if items are reset after round restart
        // for(int i = 0; i < sents_count; i++){
        //     switch(sents[i].senttype){
        //         case ET_ITEM_AMMO, ET_ITEM_ARMOR, ET_ITEM_WEAPON, ET_ITEM_HEALTH: {
        //             if(!sents[i].active){
        //                 activateItem(sents[i])
        //             }
        //         }

        //         case ET_ITEM_POWERUP: {
        //             deactivateItem(sents[i])
        //             sents[i].respawnTime = GetGameTime() + 45.0 + GetRandomFloat(0.0,15.0)
        //         }
        //     }
        // }

    
        for(int i = 0;i<sizeof(sents_dropped);i++){
            if(sents_dropped[i].valid && sents_dropped[i].phys != 0 && IsValidEntity(sents_dropped[i].phys)){
                RemoveEntity(sents_dropped[i].phys)
                sents_dropped[i].valid = false
            }
        }
    }

}

void event_playerSpawn(Handle event, const char[] name, bool dontBroadcast){
    int client = GetClientOfUserId(GetEventInt(event, "userid"))
    onPlayerSpawn(client)
}

void onPlayerSpawn(int client){
    //strip weapons
    for (int i = 0; i < 6; i++) {
        int wp = GetPlayerWeaponSlot(client, i)
        if(wp > 0 && IsValidEntity(wp)) {
            RemovePlayerItem(client,wp)
        }
    }

    for(int i = 0;i<PW_NUM_POWERUPS;i++){
        SD[client].powerups[i] = 0.0
    }
    updatePlayerSkin(client)

    //set model/skin
    SetEntityModel(client,PLAYERMODEL)
    SetEntProp(client,Prop_Send,"m_nSkin",!GM[gamemode].teams)

    int gloves = GetEntPropEnt(client, Prop_Send, "m_hMyWearables")
    if(gloves != -1 && gloves >= MAXPLAYERS && IsValidEntity(gloves)){
        RemoveEntity(gloves)
    }


    //weapon stuff
    static int weapon
    if(GetClientTeam(client) == 2){
        weapon = GivePlayerItem(client,"weapon_m4a1")
    }

    if(GetClientTeam(client) == 3){
        weapon = GivePlayerItem(client,"weapon_ak47")
    }

    if(weapon < 1 || !IsValidEntity(weapon)){
        return
    }

    SDKHook(weapon,SDKHook_SetTransmit,hook_weaponTransmit)


    int wpn_start = 0
    for(int i = WEAPON_GAUNTLET;i<WEAPON_NUM_WEAPONS;i++){
        SD[client].wpnAvailable[i] = GM[gamemode].startingWeapons & (1<<i - 1) != 0
        SD[client].wpnAmmo[i] = WPN[i].startingAmmo
        
        if(gamemode == GM_CA){
            SD[client].wpnAmmo[i] = WPN[i].maxAmmo
        }
        
        if(GM[gamemode].instagib && i != WEAPON_GAUNTLET){
            SD[client].wpnAmmo[i] = 9999
        }
        
        if(!SD[client].wpnAvailable[i]){
            SD[client].wpnAmmo[i] = 0
        }
        
        wpn_start = SD[client].wpnAvailable[i] ? i : wpn_start
    }

    if(SD[client].wpnAvailable[WEAPON_MACHINEGUN]){
        wpn_start = WEAPON_MACHINEGUN
    }

       switchWeapon(client,wpn_start,true) //force initial weaponswitch because otherwise it will cause problems with the models not being set properly
    updateRailColors(client,SD[client].railColor)

     SD[client].desiredWeapon = SD[client].activeWeapon
     setViewmodelIdleSequence(null,client)



     updateOverlay(client)
     CreateTimer(0.3,t_spawnText,client,TIMER_FLAG_NO_MAPCHANGE)

     SetEntityHealth(client,GM[gamemode].startHealth)
     SD[client].armor = GM[gamemode].startArmor

     SetEntPropFloat(client,Prop_Send,"m_flStepSize",22.0)

    //spawn effects
    static float clientpos[3]
    GetClientEyePosition(client, clientpos)
    EmitAmbientSound("world/telein.wav",clientpos,_,_,_,0.2)
    clientpos[2] -= 12.0

    if(pPlayerPops[client] < 1){
        int pop = CreateEntityByName("prop_dynamic")
        TeleportEntity(pop,clientpos,NULL_VECTOR,NULL_VECTOR)
        SetEntityModel(pop,"models/powerups/pop.mdl")
        SetEntityRenderMode(pop,RENDER_TRANSALPHA)
        DispatchSpawn(pop)
        pPlayerPops[client] = pop
        activePops++
    }
    
    showOverlay(client)
    checkTelefrag(client)
}

Action hook_weaponTransmit(int entity, int client){
    if(!HasEntProp(entity, Prop_Send, "m_hOwner")){
        return Plugin_Continue
    }

    if(GetEntPropEnt(entity, Prop_Send, "m_hOwner") == client){
         return Plugin_Handled
    }

    return Plugin_Continue
}

void hook_onTouchTeleporter(int tele,int client){
    if(client < 1 || client >= MAXPLAYERS){
        return
    }

    static char target_name[32]
    GetEntPropString(tele,Prop_Data,"m_target",target_name,sizeof(target_name))

    int target = -1
    int ent = -1
    char ent_name[32]
    while ((ent = FindEntityByClassname(ent, "info_target")) != -1){
        GetEntPropString(ent, Prop_Data, "m_iName", ent_name, sizeof(ent_name))
        if (StrEqual(target_name, ent_name)){
            target = ent
            break
        }
    }

    if(target == -1){
        while ((ent = FindEntityByClassname(ent, "info_teleport_destination")) != -1){
            GetEntPropString(ent, Prop_Data, "m_iName", ent_name, sizeof(ent_name))
            if (StrEqual(target_name, ent_name)){
                target = ent
                break
            }
        }
    }

    if(target == -1)
        return

    static float target_origin[3]
    static float target_ang[3]
    static float target_vel[3]
    static float clientpos[3]
    static float newclientpos[3]

    GetEntPropVector(target, Prop_Send, "m_vecOrigin", target_origin)
    GetEntPropVector(target, Prop_Send, "m_angRotation", target_ang)
    GetClientEyePosition(client, clientpos)

    GetAngleVectors(target_ang,target_vel,NULL_VECTOR,NULL_VECTOR)
    ScaleVector(target_vel,400.0)

    SD[client].lg_fakeground = 3
    TeleportEntity(client,target_origin,target_ang,target_vel)

    //fx
    GetClientEyePosition(client, newclientpos)
    EmitAmbientSound("world/teleout.wav",clientpos,_,_,_,0.2)
    EmitAmbientSound("world/telein.wav",target_origin,_,_,_,0.2)
    clientpos[2] -= 15.0
    newclientpos[2] -= 15.0

    if(pPlayerPops[client] < 1){
        int pop = CreateEntityByName("prop_dynamic")
        TeleportEntity(pop,clientpos,NULL_VECTOR,NULL_VECTOR)
        SetEntityModel(pop,"models/powerups/pop.mdl")
        SetEntityRenderMode(pop,RENDER_TRANSALPHA)
        DispatchSpawn(pop)
        pPlayerPops[client] = pop
        activePops++
    }

    if(pPlayerPops[client + 1] < 1){
        int pop = CreateEntityByName("prop_dynamic")
        TeleportEntity(pop,newclientpos,NULL_VECTOR,NULL_VECTOR)
        SetEntityModel(pop,"models/powerups/pop.mdl")
        SetEntityRenderMode(pop,RENDER_TRANSALPHA)
        DispatchSpawn(pop)
        pPlayerPops[client + 1] = pop
        activePops++
    }

    checkTelefrag(client)
}

void checkTelefrag(int client){
    static float pos[3]
    static float mins[3]
    static float maxs[3]
    static float boxmin[3]
    static float boxmax[3]

    
    GetEntPropVector(client,Prop_Send,"m_vecMaxs",mins)
    GetEntPropVector(client,Prop_Send,"m_vecMins",maxs)
    GetEntPropVector(client,Prop_Data,"m_vecAbsOrigin",pos)

    AddVectors(pos,mins,boxmin)
    AddVectors(pos,maxs,boxmax)
    
    for(int i = 0; i < sizeof(trEnumerateEnts);i++){
        trEnumerateEnts[i] = 0
    }

    TR_EnumerateEntitiesBox(boxmax, boxmin, 0, trWriteArray)
    
    for(int i = 0; i < sizeof(trEnumerateEnts);i++){
        if(trEnumerateEnts[i] == 0){
            break
        }
        
        if(trEnumerateEnts[i] < 1 || trEnumerateEnts[i] >= MAXPLAYERS || trEnumerateEnts[i] == client){
            continue
        }
        
        if(!isTeammate(client,trEnumerateEnts[i])){
            damagePlayer(trEnumerateEnts[i],0,client,1000.0,DMG_CRUSH)
        }else{
            damagePlayer(trEnumerateEnts[i],trEnumerateEnts[i],trEnumerateEnts[i],1000.0,DMG_CRUSH)
        }
    }
}

Action hook_normalSound (int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed){
    //print("client[0] %d, int &numClients %d, char sample[PLATFORM_MAX_PATH] %s,int &entity %d, int &channel %d, float &volume %f, int &level %d, int &pitch %d, int &flags %d,char soundEntry[PLATFORM_MAX_PATH] %s, int &seed %d",clients[0], numClients,  sample,entity, channel, volume,level, pitch, flags, soundEntry,seed)
    //print(sample)

    static char sound_blacklist[][PLATFORM_MAX_PATH] = {
        ")weapons/flashbang/",    //grenade hit
        "~player/damage",    //falldamage
        "~)player/land",
        "~player/death",
        "~player/kevlar",
        "+player\\vo",    //radio/round start
        "~physics/flesh/flesh_impact_bullet",
    }

    for(int i = 0;i<sizeof(sound_blacklist);i++){
        static int len
        len = strlen(sound_blacklist[i])

        if(strncmp(sound_blacklist[i],sample,len) == 0){    //basically StringStartsWith, probably faster than StringContains
            return Plugin_Handled
        }
    }

    return Plugin_Continue
}

Action hook_sayText2(UserMsg msg_id, any msg, const int[] players, int playersNum, bool reliable, bool init){
    static char message[64]
    PbReadString(msg, "msg_name", message, sizeof(message))
    
    if(!StrEqual(message,"#Cstrike_Name_Change")){
        return Plugin_Continue
    }

    if(hide_namechange){
        return Plugin_Handled
    }

    //actually changed his name
    int client = PbReadInt(msg, "ent_idx")
    GetClientName(client, SD[client].name, sizeof(SD[].name))
    updateQueueNames()
    
    return Plugin_Continue
}

Action hook_silverKey(int ent,int client){
    if(client <= 0 || client >= MAXPLAYERS || (SD[client].numKeys[0] <= 0 && SD[client].numKeys[2] <= 0)){
        return Plugin_Handled
    }
    
    return Plugin_Continue
}

Action hook_goldKey(int ent,int client){
    if(client <= 0 || client >= MAXPLAYERS || (SD[client].numKeys[1] <= 0 && SD[client].numKeys[2] <= 0)){
        return Plugin_Handled
    }
    
    return Plugin_Continue
}

Action hook_onTouchLaunchpad(int launchpad,int client){
    int parent = GetEntPropEnt(launchpad, Prop_Data, "m_hMoveParent")

    if(parent < 1 || client < 1 || client >= MAXPLAYERS){
        return Plugin_Continue
    }

    static float launchpad_pos[3]
    static float target_pos[3]
    static float vel[3]

    GetEntPropVector(launchpad, Prop_Data, "m_vecAbsOrigin", launchpad_pos);
    GetEntPropVector(parent, Prop_Send, "m_vecOrigin", target_pos);

    SubtractVectors(target_pos,launchpad_pos,vel)
    float time = SquareRoot(vel[2] / (gravity * 0.5))

    vel[2] = 0.0
    float dist = NormalizeVector(vel,vel)
    float fwd = dist / time

    ScaleVector(vel,fwd)
    vel[2] = time * gravity

    SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vel)
    EmitAmbientSound("world/jumppad.wav",launchpad_pos,_,_,_,0.5)
    playTeamSound(client,TS_JUMP)

    SD[client].lg_fakeground = 4 //no ledgegrab after launching because it can cause players losing all their speed after landing

    return Plugin_Continue
}

bool hook_lagcompShouldCollide(int entity, int collisiongroup, int contentsmask, bool originalResult){    //this happens to be called during lag compensation, how convenient...
    if(contentsmask != (MASK_SHOT | CONTENTS_GRATE) || last_client_shot == 0){
        return true
    }

    //print("entity %i, collisiongroup %i, contentsmask %i, originalResult %b",entity, collisiongroup,  contentsmask,  originalResult)
    onLagCompensation(last_client_shot)
    last_client_shot = 0

    return true
}

void onLagCompensation(int attacker){
    onPlayerAttack(attacker)
}

bool isEntityInBrushentity(int player, int entity){
    static float mins[3]
    static float maxs[3]
    static float pl[3]
    static float entpos[3]

    GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", entpos);
    GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
    GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
    GetEntPropVector(player, Prop_Send, "m_vecOrigin", pl);

    AddVectors(mins,entpos,mins)
    AddVectors(maxs,entpos,maxs)
    maxs[2] += 10 //expand upwards a bit

    return (pl[0] > mins[0] && pl[0] < maxs[0]   &&   pl[1] > mins[1] && pl[1] < maxs[1]   &&   pl[2] > mins[2] && pl[2] < maxs[2])
}

bool isTeammate(int player1, int player2){
    if(player1 <= 0 || player1 >= MAXPLAYERS || player2 <= 0 || player2 >= MAXPLAYERS || !IsClientInGame(player1) || !IsClientInGame(player2)){
        return false
    }

    //if(h_cvarTeammatesAreEnemies.IntValue > 0){
    if(!GM[gamemode].teams){
        return player1 == player2
    }

    return (GetClientTeam(player1) == GetClientTeam(player2))
}

public void OnGameFrame(){
    //playerspawn fade/delete
    static int i
    if(activePops > 0){
        //PrintToServer("activepops %i",activePops)
        for(i = 0;i< sizeof(pPlayerPops);i++){
            if( pPlayerPops[i] >= MAXPLAYERS && IsValidEntity( pPlayerPops[i])){
                static int alpha
                alpha = ((GetEntProp( pPlayerPops[i],Prop_Send,"m_clrRender") & 0xFF000000) >> 24) & 0xFF    //not sure if this is better but whatever...

                if(alpha > 237){
                    alpha--
                }else{
                    alpha -= 30
                }


                if(alpha < 1){
                    RemoveEntity( pPlayerPops[i] )
                    continue
                }
                SetEntProp(pPlayerPops[i],Prop_Send,"m_clrRender",(alpha << 24) | 0x00FFFFFF)
            }
        }
    }

    //railgun impact color
    if(decals_rail_active > 0){
        static int active
        active = 0

        for(i = 0;i< sizeof(decals_rail);i++){
            if(decals_rail[i] == 0 || !IsValidEntity(decals_rail[i])){
                continue
            }

            static int r,g,b,a
            GetEntityRenderColor(decals_rail[i],r,g,b,a)

            if(r+g+b == 0){
                continue
            }

            active++

            if(r > 0){
                r--
            }

            if(g > 0){
                g--
            }

            if(b > 0){
                b--
            }

            SetEntityRenderColor(decals_rail[i],r,g,b,a)

            if(r+g+b == 0){
                decals_rail_active--
            }
        }

        if(active == 0){    //decals_rail_active is off
            decals_rail_active = 0
        }
    }

    //lg smooth beam limit
    lightning_activebeams = 0
}

public void OnEntityCreated(int entity, const char[] classname){
    newest_ent_idx = entity

    #if 0
    int edicts = 0    //server seems to crash at 1994 edicts
    int ents = 0    //crash at ~6000 ents
    for(int i = 0;i<10000;i++){
        if(IsValidEdict(i)){
            edicts++
        }

        if(IsValidEntity(i)){
            ents++
        }
    }
    print("new ent: %s idx %d, total edicts: %d ents: %d",classname,entity,edicts,ents)
    #endif
}


public void OnClientCookiesCached(int client){
    if(!SD[client].cookiesLoaded){
        initPlayerData(client)
    }
}

public void OnEntityDestroyed(int entity){
    if(entity < MAXPLAYERS){
        return
    }

    #if 0
        static char classname[32]
        GetEntityClassname(entity,classname,sizeof(classname))
        print("removed ent: %s, num: %d",classname,entity)
    #endif

    //pops and wpnTargets
    for(int i = 0;i<sizeof(pPlayerPops);i++){
        if(pPlayerPops[i] == entity){
            pPlayerPops[i] = 0
            activePops--
            return
        }


        if(i < sizeof(SD) ){
            if(SD[i].wpnAimTarget == entity){
                SD[i].wpnAimTarget = 0
                return
            }

            if(SD[i].wpnAttachmentTarget == entity){
                SD[i].wpnAttachmentTarget = 0
                return
            }

            if(SD[i].wpnVMTarget == entity){
                SD[i].wpnVMTarget = 0
                return
            }
        }
    }
}

Action hook_onTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype){
    //print("int victim %d, int &attacker %d, int &inflictor %d, float &damage %f, int &damagetype %d", victim,  attacker,  inflictor,  damage,  damagetype )

    if( (damagetype & DMG_BULLET) == DMG_BULLET && attacker != 0 && attacker < MAXPLAYERS){
        print("[Q] A actual csgo bullet hit someone. this shouldn't happen")
        damage = 0.0
        return Plugin_Changed
    }

    if(attacker == 0 ){ //world
        if(damagetype == DMG_FALL){
            int entity = -1;
            while ((entity = FindEntityByClassname(entity, "trigger_push")) != -1){ //check if we landed on a launchpad
                if(isEntityInBrushentity(victim,entity)){
                    damage = 0.0
                    return Plugin_Changed
                }
            }

            if(damage > 50.0){
                playTeamSound(victim,TS_FALL)

                if(GM[gamemode].selfdamage){
                    damagePlayer(victim,inflictor,attacker, 10.0,damagetype)
                }
            }else if(damage > 18.0){
                playTeamSound(victim,TS_PAIN100)

                if(GM[gamemode].selfdamage){
                    damagePlayer(victim,inflictor,attacker, 5.0,damagetype)
                }
            }

            damage = 0.0
            return Plugin_Changed
        }
    }
    
    if(attacker == 0 || attacker >= MAXPLAYERS){
        damagePlayer(victim,inflictor,attacker, damage,damagetype)
        damage = 0.0
        return Plugin_Changed
    }

    return Plugin_Continue
}

void onPlayerTakeDamage(int attacker,int victim, float damage ){
    if(damage < 1.0){
        return
    }

    updateHealthText(victim)

    static int health
    health = GetClientHealth(victim)

    if(health > 0 && hasPowerup(victim,PW_BATTLESUIT) && GetGameTime() - SD[victim].lastDmgTakenTime < 0.5 ){
        playWeaponSound("items/protect3.wav",victim,SNDCHAN_AUTO,_,_,0.5)
    }
    SD[victim].lastDmgTakenTime = GetGameTime()

    if(health > 0 && attacker > 0 && (!isTeammate(attacker,victim) || attacker == victim) && SD[victim].lastPainTime + 0.5 < GetGameTime()){
        SD[victim].lastPainTime = GetGameTime()
        SetEntPropVector(victim,Prop_Send,"m_viewPunchAngle",{1.5,0.0,0.0})

        if(health < 25){
            playTeamSound(victim,TS_PAIN25)
        }else if(health < 50){
            playTeamSound(victim,TS_PAIN50)
        }else if(health < 75){
            playTeamSound(victim,TS_PAIN75)
        }else{
            playTeamSound(victim,TS_PAIN100)
        }
    }

    if(attacker <= 0 || attacker >= MAXPLAYERS){
        return
    }

    if(damage < 1.0){
        return
    }

    showDamageNumbers(attacker,victim,RoundToFloor(damage) )

    if(!isTeammate(attacker,victim)){

        //crosshair
        int col = damage > 74.0 ? 3 :    damage > 24.0 ? 2 : 1
        if(SD[attacker].crosshairColor != col){
            SD[attacker].crosshairColor = col
            updateOverlay(attacker)
        }

        SD[attacker].lastDmgTime = GetGameTime()
        CreateTimer(0.2,showWhiteCrosshair,attacker,TIMER_FLAG_NO_MAPCHANGE )

        //hitsound
        if(!IsPlayerAlive(victim)){
            playLocalSound(attacker, "world/bell_01.wav")
        }else{
            int file = RoundToFloor(damage * 4 / 100.0)
            file = file < 0 ? 0 : (file > 3 ? 3 : file)

            static char sound[] = "feedback/hit0.wav"
            sound[12] = '0' + file

            playLocalSound(attacker, sound);
        }
    }
}

void onPlayerAttack(client){
    static int weapon

    weapon = SD[client].activeWeapon

    if(WPN[weapon].reload <= 0.1){    //workaround for fast firing weapons
        if((gamestate != GS_PLAYING && gamestate != GS_WARMUP) || GetGameTime() < SD[client].nextPrimaryAttack - GetTickInterval()){
            return
        }
    }

    //if(client==1){
    //    static float last
    //    float t = GetGameTime()
    //    print("%f    %d",t - last,GetGameTickCount())
    //    last = t
    //}

    //don't fire if the client wants to change weapons
    if(weapon != SD[client].desiredWeapon && SD[client].desiredWeapon != WEAPON_NONE){
        return
    }

    //ammo
    if(weapon != WEAPON_GAUNTLET && SD[client].wpnAmmo[weapon] < 1){
        for(int i = WEAPON_NUM_WEAPONS - 1;i>=WEAPON_GAUNTLET;i--){
            if(i == WEAPON_GAUNTLET){
                setDesiredWeapon(client,i)
                break
            }

            if(SD[client].wpnAvailable[i] && SD[client].wpnAmmo[i] > 0){
                setDesiredWeapon(client,i)
                break
            }
        }

        return
    }

    if(weapon != WEAPON_GAUNTLET && SD[client].wpnAmmo[weapon] < 9999){
        SD[client].wpnAmmo[weapon] -= 1
        updateAmmoText(client)
        updateAmmoTextCenter(client)

        if(SD[client].wpnAmmo[weapon] == 0){
            playLocalSound(client,"weapons/noammo.wav")
        }
    }

    //sounds
    bool lmb = SD[client].lastbuttons2 & IN_ATTACK != 0
    if(weapon == WEAPON_LIGHTNING && (!lmb /*|| SD[client].nextPrimaryAttack == GetGameTime()*/ )){
        //lightning sound is played in playWpnHum and stopped in OnPlayerRunCmd
        playWeaponSound("weapons/lightning/lg_fire.wav",client,SNDCHAN_WEAPON,_,_,0.3)
    }else{
        if(strlen(WPN[weapon].sound) > 0){
            playWeaponSound(WPN[weapon].sound,client,SNDCHAN_WEAPON,_,_,0.3)
        }
    }

    if( (weapon == WEAPON_LIGHTNING && !lmb) || (weapon != WEAPON_GAUNTLET && weapon != WEAPON_LIGHTNING) ){
        if(hasPowerup(client,PW_QUAD)){
            playQuadSound(client,WPN[weapon].reload > 0.5)
        }
    }

    if(weapon == WEAPON_GAUNTLET && (!lmb || SD[client].nextPrimaryAttack == GetGameTime() )){
        TriggerTimer(SD[client].wpnSoundHumTimer,true)
    }

    //viewmodel/animations
    static int vm
    vm = GetEntPropEnt(client,Prop_Send, "m_hViewModel")

    SetEntProp(vm,Prop_Send,"m_nSequence",WPN[weapon].anim_attack)
    SetEntPropFloat(vm,Prop_Data,"m_flCycle",0.0)


    static float delay
    if(WPN[weapon].holdFireAnim){
        delay = 0.0165
    }else{
        delay = -0.165
    }

    static float addtime
    addtime = WPN[weapon].reload
    if(hasPowerup(client,PW_HASTE)){
        addtime /= 1.3
    }

    SD[client].nextPrimaryAttack = GetGameTime() + addtime
    CreateTimer(addtime + delay,setViewmodelIdleSequence,client,TIMER_FLAG_NO_MAPCHANGE)







    //fire weapon
    int hits = 0
    int lastHit = client

    static float pos[3]
    static float ang[3]
    static float fwd[3]
    static float right[3]
    static float up[3]
    static float endpos[3]
    static Handle trace
    GetClientEyePosition(client,pos)
    GetClientEyeAngles(client,ang)
    GetAngleVectors(ang,fwd,right,up)
    endpos = pos

    if(weapon == WEAPON_RAILGUN){
            for(int i = 0;i<sizeof(trRailHits);i++){
                trRailHits[i] = 0
            }

            for(int i = 0;i<1000;i++){

                trace = TR_TraceRayFilterEx(endpos,ang,MASK_SHOT,RayType_Infinite,trFilterRailAlreadyHit,client )
                if( !TR_DidHit(trace) ){ 
                    CloseHandle(trace)
                    break
                }

                TR_GetEndPosition(endpos,trace)
                lastHit = TR_GetEntityIndex(trace)
                if(lastHit < 1 || lastHit >= MAXPLAYERS){ //hit world, draw decal here
                    createDecal(weapon,trace,client)
                    createBulletHit(weapon, trace)
                    EmitAmbientSound("weapons/plasma/plasmx1a.wav",endpos,_,_,_,0.3)
                    
                    if(lastHit != 0){    //could be a button
                        damagePlayer(lastHit,client,client,WPN[weapon].damage)
                    }
                    
                    CloseHandle(trace)
                    break
                }

                trRailHits[hits++] = lastHit
                showHitParticle(endpos, lastHit)
                CloseHandle(trace)
            }

            for(int i = 0;i<hits;i++){
                damagePlayer(trRailHits[i],client,client,WPN[weapon].damage, DMG_GENERIC)
            }

            AcceptEntityInput(SD[client].wpnVMTarget,"ClearParent")
            updateWpnTargets(client,endpos)
            updateVMTargetPos(client)
            AcceptEntityInput(SD[client].wpnAttachmentTarget,"ClearParent") //do this for railgun        not sure if this is necessary
            showRailLaser(client)
        }

        if(weapon == WEAPON_LIGHTNING){
            endpos[0] = pos[0] + fwd[0] * LIGHTNING_LENGTH
            endpos[1] = pos[1] + fwd[1] * LIGHTNING_LENGTH
            endpos[2] = pos[2] + fwd[2] * LIGHTNING_LENGTH

            trace = TR_TraceRayFilterEx(pos,endpos,MASK_SHOT,RayType_EndPoint,trFilterSelf,client )

            if( TR_DidHit(trace) ){
                TR_GetEndPosition(endpos,trace)
                createDecal(weapon,trace)

                EmitAmbientSound("weapons/nailgun/wnalimpd.wav",endpos,_,_,_,0.35)
            }

            lastHit = TR_GetEntityIndex(trace)

            if(lastHit > 0){
                damagePlayer(lastHit,client,client,WPN[weapon].damage, DMG_GENERIC)
                //TR_GetEndPosition(endpos,trace)
                if(lastHit < MAXPLAYERS){
                    showHitParticle(endpos, lastHit)
                }
            }

            updateWpnTargets(client,endpos,true)
            updateVMTargetPos(client)
            showLightningLaser(client)


            CloseHandle(trace)
        }

        if(weapon == WEAPON_MACHINEGUN){
            static char snd[] = "weapons/machinegun/machgf1b.wav"
            snd[25] = '1' + GetRandomInt(0,3)

            playWeaponSound(snd,client,SNDCHAN_WEAPON,_,_,0.3)

            //effects, kinda annoying
            //AcceptEntityInput(SD[client].wpnVMTarget,"ClearParent")
            //updateVMTargetPos(client)
            //updateWpnTargets(client,NULL_VECTOR,true)
            //AcceptEntityInput(SD[client].wpnAttachmentTarget,"ClearParent")
            //showMuzzleFlash(client,WEAPON_MACHINEGUN)

            // TE_Start("Dynamic Light");
            // TE_WriteNum("r", 255);
            // TE_WriteNum("g", 255);
            // TE_WriteNum("b", 0);
            // TE_WriteNum("exponent", 7);
            // TE_WriteFloat("m_fRadius", 200.0);
            // TE_WriteFloat("m_fTime", 0.05);
            // TE_WriteFloat("m_fDecay", 1.0);
            // TE_WriteVector("m_vecOrigin",pos)
            // TE_SendToAll()


            //spread     https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_weapon.c#L173
            static int r
            static int u
            r = GetRandomFloat(0.0,1.0) * FLOAT_PI * 2.0
            u = Sine(r) * GetRandomFloat(-1.0,1.0) * 200.0 * 16.0
            r = Cosine(r) * GetRandomFloat(-1.0,1.0) * 200.0 * 16.0
            qVectorMA(pos,8192.0*16.0,fwd,endpos)
            qVectorMA(endpos, r, right, endpos)
            qVectorMA (endpos, u, up, endpos)

            trace = TR_TraceRayFilterEx(pos,endpos,MASK_SHOT,RayType_EndPoint,trFilterSelf,client )
            if( !TR_DidHit(trace) ){
                CloseHandle(trace)
                return
            }

            lastHit = TR_GetEntityIndex(trace)
            if(lastHit > 0){
                damagePlayer(lastHit,client,client,WPN[weapon].damage, DMG_GENERIC)
                TR_GetEndPosition(endpos,trace)
                if(lastHit < MAXPLAYERS){
                    showHitParticle(endpos, lastHit)
                }
            }

            if(!trHitSky(trace)){
                static char s[] = "weapons/machinegun/ric1.wav"
                static float hit[3]

                s[22] = '1' + GetRandomInt(0,2)
                TR_GetEndPosition(hit,trace)

                EmitSoundToAll(s,SOUND_FROM_WORLD,_,_,_,0.4,_,_,hit)
            }

            if(lastHit == 0){
                createDecal(weapon,trace)
            }

            if(lastHit == 0 || lastHit >= MAXPLAYERS){
                createBulletHit(weapon, trace)
            }

            CloseHandle(trace)


        }

        if(weapon == WEAPON_SHOTGUN){
            //distance from previous bullet
            static float dn[] = {0.0, 0.0, 0.0, 0.0, 0.089565, -0.179998, 0.154780, -0.127824, 0.0, 0.126956, -0.037391, 0.0, -0.052172, 0.0, 0.047825, -0.042608, 0.059128, -0.075651, -0.021739, 0.119130}
            static float lf[] = {-0.0315, -0.059999, 0.119998, 0.060869, -0.091303, 0.0, 0.063478, 0.0, -0.127825, 0.0, 0.049565, 0.029564, -0.029564, 0.029564, 0.041739, -0.113041, 0.009564, 0.093912, -0.056521, 0.019130}

            float damage[MAXPLAYERS]

            for(int i = 0;i < sizeof(dn);i++){
                fwd[0] += up[0] * dn[i] + right[0] * lf[i]
                fwd[1] += up[1] * dn[i] + right[1] * lf[i]
                fwd[2] += up[2] * dn[i] + right[2] * lf[i]

                GetVectorAngles(fwd,ang)

                trace = TR_TraceRayFilterEx(pos,ang,MASK_SHOT,RayType_Infinite,trFilterSelf,client )
                if( !TR_DidHit(trace) ){
                    CloseHandle(trace)
                    continue
                }

                lastHit = TR_GetEntityIndex(trace)
                if(lastHit > 0 && lastHit < MAXPLAYERS){
                    //damagePlayer(lastHit,client,client,WPN[weapon].damage, DMG_GENERIC)
                    damage[lastHit] += WPN[weapon].damage    //batch damage

                    TR_GetEndPosition(endpos,trace)
                    showHitParticle(endpos, lastHit)
                }

                if(lastHit == 0){
                    createDecal(weapon,trace)
                }

                if(lastHit == 0 || lastHit >= MAXPLAYERS){
                    createBulletHit(weapon, trace)
                }
                
                
                if(lastHit >= MAXPLAYERS){
                    damagePlayer(lastHit,client,client,WPN[weapon].damage, DMG_GENERIC)
                }

                CloseHandle(trace)
            }

            for(int i = 0;i<sizeof(damage);i++){
                if(damage[i] >= 1.0){
                    damagePlayer(i,client,client,damage[i], DMG_GENERIC)
                }
            }
        }

        if(weapon == WEAPON_GAUNTLET){
            qVectorMA(pos,48.0,fwd,endpos)

            trace = TR_TraceRayFilterEx(pos,endpos,MASK_SHOT,RayType_EndPoint,trFilterSelf,client )
            if( !TR_DidHit(trace) ){
                CloseHandle(trace)
                return
            }

            lastHit = TR_GetEntityIndex(trace)
            if(lastHit > 0){
                SD[client].nextPrimaryAttack = GetGameTime() + (hasPowerup(client,PW_HASTE) ? 0.4 / 1.3 : 0.4)
                setViewmodelSequence(client,4)
                CreateTimer(0.2,t_gauntletSequence,client,TIMER_FLAG_NO_MAPCHANGE)

                playWeaponSound("weapons/melee/fstatck.wav",client,SNDCHAN_AUTO,_,_,0.3)
                if(hasPowerup(client,PW_QUAD)){
                    playQuadSound(client,true)
                }

                damagePlayer(lastHit,client,client,WPN[weapon].damage, DMG_GENERIC)
                TR_GetEndPosition(endpos,trace)
                if(lastHit < MAXPLAYERS){
                    showHitParticle(endpos, lastHit)
                }
            }
        }

        if(weapon == WEAPON_HMG){
            static char snd[] = "weapons/hmg/machgf1b.wav"
            snd[18] = '1' + GetRandomInt(0,3)

            playWeaponSound(snd,client,SNDCHAN_AUTO,_,_,0.3)

            //spread     https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_weapon.c#L173
            static int r
            static int u
            r = GetRandomFloat(0.0,1.0) * FLOAT_PI * 2.0
            u = Sine(r) * GetRandomFloat(-1.0,1.0) * 400.0 * 16.0
            r = Cosine(r) * GetRandomFloat(-1.0,1.0) * 400.0 * 16.0
            qVectorMA(pos,8192.0*16.0,fwd,endpos)
            qVectorMA(endpos, r, right, endpos)
            qVectorMA (endpos, u, up, endpos)

            trace = TR_TraceRayFilterEx(pos,endpos,MASK_SHOT,RayType_EndPoint,trFilterSelf,client )
            if( !TR_DidHit(trace) ){
                CloseHandle(trace)
                return
            }

            lastHit = TR_GetEntityIndex(trace)
            if(lastHit > 0){
                damagePlayer(lastHit,client,client,WPN[weapon].damage, DMG_GENERIC)
                TR_GetEndPosition(endpos,trace)
                if(lastHit < MAXPLAYERS){
                    showHitParticle(endpos, lastHit)
                }
            }

            if(!trHitSky(trace)){
                static char s[] = "weapons/machinegun/ric1.wav"
                static float hit[3]

                s[22] = '1' + GetRandomInt(0,2)
                TR_GetEndPosition(hit,trace)

                EmitSoundToAll(s,SOUND_FROM_WORLD,_,_,_,0.4,_,_,hit)
            }

            if(lastHit == 0){
                createDecal(weapon,trace)
            }

            if(lastHit == 0 || lastHit >= MAXPLAYERS){
                createBulletHit(weapon, trace)
            }

            CloseHandle(trace)


        }

        if(WPN[weapon].projectile){
            shootProjectile(client,weapon)
        }

}

bool trHitSky(Handle trace){
    return TR_GetSurfaceFlags(trace) & SURF_SKY != 0
}

bool trGetSurfaceAng(Handle trace, float ang[3], float pos[3] = NULL_VECTOR, float recenter = 32.0){
    if(!TR_DidHit(trace)){
        pos = NULL_VECTOR
        ang = NULL_VECTOR
        return false
    }

    if(TR_GetEntityIndex(trace) != 0){
        pos = NULL_VECTOR
        ang = NULL_VECTOR
        return false
    }

    static float plane[3]
    static float vvr[3]
    static float vvu[3]

    TR_GetPlaneNormal(trace,plane)

    if(!IsNullVector(pos)){
        TR_GetEndPosition(pos,trace)
        GetVectorVectors(plane,vvr,vvu)
        pos[0] += (vvu[0] * recenter) + (plane[0] * 0.01) //move away a bit from the surface to prevent z-fighting
        pos[1] += (vvu[1] * recenter) + (plane[1] * 0.01)
        pos[2] += (vvu[2] * recenter) + (plane[2] * 0.01)

        pos[0] += vvr[0] * recenter
        pos[1] += vvr[1] * recenter
        pos[2] += vvr[2] * recenter
    }

      plane[2] = plane[2] * - 1.0
    GetVectorAngles(plane,ang)

    return true
}

void createDecal(int weapon, Handle trace, int client = 0){    //client is only required for railgun color
    static float pos[3]
    static float ang[3]
    static float offset

    offset = 32.0

    if(weapon == WEAPON_SHOTGUN){
        offset = 4.0
    }

    if(weapon == WEAPON_MACHINEGUN || weapon == WEAPON_HMG){
        offset = 8.0
    }

    if(weapon == WEAPON_LIGHTNING || weapon == WEAPON_PLASMAGUN){
        offset = 16.0
    }

    if(weapon == WEAPON_RAILGUN){
        offset = 24.0
    }

    if(weapon == WEAPON_ROCKETLAUNCHER || weapon == WEAPON_GRENADELAUNCHER){
        offset = 48.0
    }


    if(!trGetSurfaceAng(trace,ang,pos,offset) || trHitSky(trace) || TR_GetSurfaceFlags(trace) & SURF_NODRAW != 0){
        return
    }

    int sprite = CreateEntityByName("env_sprite_oriented")
    DispatchKeyValue(sprite, "model", WPN[weapon].decal)
    DispatchKeyValue(sprite, "classname", "env_sprite_oriented")
    DispatchKeyValue(sprite, "spawnflags", "1")
    DispatchKeyValue(sprite, "scale", "1.0")
    DispatchKeyValue(sprite, "rendermode", "1")
    DispatchKeyValueVector(sprite, "Angles", ang)


    if(weapon == WEAPON_LIGHTNING || weapon == WEAPON_SHOTGUN){    //add shotguns to the lg pool since they are pretty spammy
        DispatchKeyValue(sprite, "rendercolor", "0 0 0")

        if(weapon == WEAPON_SHOTGUN){
            DispatchKeyValue(sprite, "scale", "0.5")
        }else{
            DispatchKeyValue(sprite, "scale", "0.4")
            //DispatchKeyValue(sprite, "renderamt", "200")
        }

        decals_lg_i = (decals_lg_i + 1) % sizeof(decals_lg)

        if(decals_lg[decals_lg_i] != 0 && IsValidEntity(decals_lg[decals_lg_i])){
            RemoveEntity(decals_lg[decals_lg_i])
        }
        decals_lg[decals_lg_i] = sprite

    }else if(weapon == WEAPON_RAILGUN || weapon == WEAPON_PLASMAGUN){
        if(weapon == WEAPON_RAILGUN){
            static char col[16]
            Format(col,sizeof(col),"%d %d %d",railColors[SD[client].railColor][0],railColors[SD[client].railColor][1],railColors[SD[client].railColor][2])

            DispatchKeyValue(sprite, "rendercolor", col)
            DispatchKeyValue(sprite, "scale", "0.75")
        }else{
            DispatchKeyValue(sprite, "rendercolor", "255 255 255")
            DispatchKeyValue(sprite, "scale", "0.5")
        }

        decals_rail_i = (decals_rail_i + 1) % sizeof(decals_rail)

        if(decals_rail[decals_rail_i] != 0 && IsValidEntity(decals_rail[decals_rail_i])){
            RemoveEntity(decals_rail[decals_rail_i])
        }

        decals_rail[decals_rail_i] = sprite
        decals_rail_active++
    }else{
        DispatchKeyValue(sprite, "rendercolor", "0 0 0")
        if(weapon == WEAPON_ROCKETLAUNCHER || weapon == WEAPON_GRENADELAUNCHER){
            DispatchKeyValue(sprite, "scale", "1.5")
        }

        decals_i = (decals_i + 1) % sizeof(decals)

        if(decals[decals_i] != 0 && IsValidEntity(decals[decals_i])){
            RemoveEntity(decals[decals_i])
        }

        decals[decals_i] = sprite
    }

    TeleportEntity(sprite, pos, NULL_VECTOR, NULL_VECTOR)
    DispatchSpawn(sprite)
}

void event_roundStart(Handle event, const char[] name, bool dontBroadcast){
    int entity = -1
    while ((entity=FindEntityByClassname(entity,"trigger_push")) != -1){
        SDKHook(entity, SDKHook_StartTouch, hook_onTouchLaunchpad)
    }

    entity = -1
    while ((entity=FindEntityByClassname(entity,"trigger_teleport")) != -1){
        SDKHook(entity, SDKHook_StartTouch, hook_onTouchTeleporter)
    }
    
    entity = -1
    while ((entity=FindEntityByClassname(entity,"trigger_multiple")) != -1){
        if(GetEntProp(entity,Prop_Data,"m_spawnflags") & 16 == 16){
            SDKHook(entity, SDKHook_StartTouch, hook_silverKey)
        }
        
        if(GetEntProp(entity,Prop_Data,"m_spawnflags") & 512 == 512){
            SDKHook(entity, SDKHook_StartTouch, hook_goldKey)
        }
    }
    
    entity = -1
    while ((entity=FindEntityByClassname(entity,"trigger_once")) != -1){
        if(GetEntProp(entity,Prop_Data,"m_spawnflags") & 16 == 16){
            SDKHook(entity, SDKHook_StartTouch, hook_silverKey)
        }
        
        if(GetEntProp(entity,Prop_Data,"m_spawnflags") & 512 == 512){
            SDKHook(entity, SDKHook_StartTouch, hook_goldKey)
        }
    }

    setupScriptedEntities()

    for(int i = 0;i < sizeof(decals);i++){
        decals[i] = 0
        decals_lg[i] = 0
        decals_rail[i] = 0
    }

    decals_i = 0
    decals_lg_i = 0
    decals_rail_i = 0
    decals_rail_active = 0
    
    CreateTimer(0.1, t_updateReadyText,0, TIMER_FLAG_NO_MAPCHANGE)
    GameRules_SetProp("m_iRoundTime", 0)

    SetTeamScore(CS_TEAM_CT,0)
    CS_SetTeamScore(CS_TEAM_CT,0)

    SetTeamScore(CS_TEAM_T,0)
    CS_SetTeamScore(CS_TEAM_T,0)
    GameRules_SetProp("m_gamePhase",1)
}

void initPlayerData(int client){
    if(client > 0 && client < MAXPLAYERS && IsClientInGame(client)){
        GetClientName(client, SD[client].name, sizeof(SD[].name))
        
        //cookies
        if(SD[client].cookiesLoaded || !AreClientCookiesCached(client)){
            //load defaults in case cookies are never loaded (e.g. no steam logon)
            SD[client].fov = 100
            SD[client].fovZoom = 60
            SD[client].fovSmooth = true
            SD[client].voice = "vo"
            SD[client].railColor = 8
            SD[client].locationEnabled = 1

            qcolorenemies(client,"102 255 64")
            qcolorteamred(client,"204 51 51")
            qcolorteamblue(client,"0 102 255")

            return
        }else{
            static char cookie[64]

            //fov
            GetClientCookie(client,h_cookieFov,cookie,sizeof(cookie))

            if(cookie[0] == 0){
                SetClientCookie(client,h_cookieFov,"100")
                SD[client].fov = 100
            }else{
                SD[client].fov = StringToInt(cookie)
            }

            //fovzoom
            GetClientCookie(client,h_cookieFovZoom,cookie,sizeof(cookie))

            if(cookie[0] == 0){
                SetClientCookie(client,h_cookieFovZoom,"60")
                SD[client].fovZoom = 60
            }else{
                SD[client].fovZoom = StringToInt(cookie)
            }

            //fovsmooth
            GetClientCookie(client,h_cookieFovSmooth,cookie,sizeof(cookie))

            if(cookie[0] == 0){
                SetClientCookie(client,h_cookieFovSmooth,"1")
                SD[client].fovSmooth = true
            }else{
                SD[client].fovSmooth = StringToInt(cookie)
            }

            //voice
            GetClientCookie(client,h_cookieVoice,cookie,sizeof(cookie))

            if(cookie[0] == 0){
                SetClientCookie(client,h_cookieVoice,"vo")
                SD[client].voice = "vo"
            }else{
                SD[client].voice = cookie
            }

            //color enemies
            GetClientCookie(client,h_cookieColorEnemies,cookie,sizeof(cookie))

            if(cookie[0] == 0){
                SetClientCookie(client,h_cookieColorEnemies,"102 255 64")
                qcolorenemies(client,"102 255 64")
            }else{
                qcolorenemies(client,cookie)
            }

            //color team red
            GetClientCookie(client,h_cookieColorTeamRed,cookie,sizeof(cookie))

            if(cookie[0] == 0){
                SetClientCookie(client,h_cookieColorTeamRed,"204 51 51")
                qcolorteamred(client,"204 51 51")
            }else{
                qcolorteamred(client,cookie)
            }

            //color team blue
            GetClientCookie(client,h_cookieColorTeamBlue,cookie,sizeof(cookie))

            if(cookie[0] == 0){
                SetClientCookie(client,h_cookieColorTeamBlue,"0 102 255")
                qcolorteamblue(client,"0 102 255")
            }else{
                qcolorteamblue(client,cookie)
            }

            //color railgun
            GetClientCookie(client,h_cookieColorRailgun,cookie,sizeof(cookie))

            if(cookie[0] == 0){
                SetClientCookie(client,h_cookieColorRailgun,"8")
                SD[client].railColor = 8
            }else{
                SD[client].railColor = StringToInt(cookie)
            }

            //location
            GetClientCookie(client,h_cookieLocation,cookie,sizeof(cookie))

            if(cookie[0] == 0){
                SetClientCookie(client,h_cookieLocation,"1")
                SD[client].locationEnabled = true
            }else{
                SD[client].locationEnabled = StringToInt(cookie)
            }

            SD[client].cookiesLoaded = true
        }
    }

}

void clearData(){
    //clear sents
    SEnt e
    for(int i = 0;i < sizeof(sents);i++){
        sents[i] = e
    }
    sents_count = 0;

    for(int i = 0;i < sizeof(sents_dropped);i++){
        sents_dropped[i] = e
    }

    //clear pd
    for(int i = 0;i < sizeof(SD);i++){
        SlotData d
        SD[i] = d
        initPlayerData(i)
    }

    //Pop effects
    for(int i = 0;i < sizeof(pPlayerPops);i++){
        pPlayerPops[i] = 0
    }
    activePops = 0

    //decals
    for(int i = 0;i < sizeof(decals);i++){
        decals[i] = 0
        decals_lg[i] = 0
        decals_rail[i] = 0
    }

    decals_i = 0
    decals_lg_i = 0
    decals_rail_i = 0
    decals_rail_active = 0

    //sounds
    ReliableSound s
    for(int i = 0;i < sizeof(reliableSounds);i++){
        reliableSounds[i] = s
    }
}

void clearDecals(){
    for(int i = 0;i < sizeof(decals);i++){
        if(IsValidEntity(decals[i]) && decals[i] != 0){
            RemoveEntity(decals[i])
        }

        if(IsValidEntity(decals_lg[i]) && decals_lg[i] != 0){
            RemoveEntity(decals_lg[i])
        }

        if(IsValidEntity(decals_rail[i]) && decals_rail[i] != 0){
            RemoveEntity(decals_rail[i])
        }

        decals[i] = 0
        decals_lg[i] = 0
        decals_rail[i] = 0
    }

    decals_i = 0
    decals_lg_i = 0
    decals_rail_i = 0
    decals_rail_active = 0
}

void setupScriptedEntities(){
    //clear old entries
    SEnt empty
    for(int i = 0;i<sizeof(sents);i++){
        sents[i] = empty
    }
    sents_count = 0
    intermissioncamera = 0
    locationsPresent = false
    
    if(GM[gamemode].items){    //we have to replace every prop_dynamic on the map because they will no longer have collision if we use SDKHook_ShouldCollide
        for(int i = MAXPLAYERS;i<3000;i++){
            if(!IsValidEntity(i)){
                continue
            }
            
            static char classname[32]
               GetEntityClassname(i,classname,sizeof(classname))

               if(!StrEqual(classname,"prop_dynamic",false) && !StrEqual(classname,"prop_dynamic_override",false)){
                   continue
               }

               if(GetEntProp(i,Prop_Send,"m_nSolidType") == 0 || GetEntProp(i,Prop_Data,"m_spawnflags") & 256 == 256){
                   continue
               }

               static float pos[3]
               static float ang[3]
               static char mdl[PLATFORM_MAX_PATH]
               
               GetEntPropVector(i,Prop_Data,"m_vecAbsOrigin",pos)
               GetEntPropVector(i,Prop_Send,"m_angRotation",ang)
               GetEntPropString(i, Prop_Data, "m_ModelName", mdl, sizeof(mdl))

            int p = CreateEntityByName("prop_door_rotating")    //this will basically only be used for collision
            DispatchKeyValue(p, "model", mdl)
            DispatchKeyValue(p, "solid", "6")
            DispatchKeyValue(p, "rendermode", "10")
            DispatchKeyValue(p, "spawnflags", "36864")
            TeleportEntity(p,pos,ang,NULL_VECTOR)
            DispatchSpawn(p)
            ActivateEntity(p)
            
            SetEntProp(p, Prop_Send, "m_nSolidType", GetEntProp(i,Prop_Send,"m_nSolidType"))
            
            SetVariantString("!activator")
            AcceptEntityInput(p, "SetParent", i)
            
            SEnt e
            e.ent = p
            e.valid = true
            e.senttype = ET_FAKEPROP
            e.origin = pos
            e.angle = ang
            e.classname = "prop_door_rotating"
            
            sents[sents_count++] = e            
        }
    }

    char path[128]
    Format(path,sizeof(path),"maps/info/%s_ents.txt",currentMap)

    File file = OpenFile(path,"r",true,"GAME")
    if(!file){
        delete file
        return
    }

    bool spawns_added = false
    char buf[512]
    while(ReadFileLine(file,buf,sizeof(buf))){
        TrimString(buf)

        if(buf[0] == ';' || buf[0] == '\0' || buf[0] == '\r' || buf[0] == '\n'){
            continue
        }

        char ent[32][64]
        ExplodeString(buf,";",ent,sizeof(ent),sizeof(ent[]))
        //0 classname;1 originX;2 originY;3 originZ;4 anglesX;5 anglesY;6 anglesZ;7 targetname;8 target;
        //9 spawnflags;10 wait;11 gametype;12 not_gametype;13 count;14 identifier;15 message

        if(ent[11][0] != 0){
            char gametypes[32][32]
            ExplodeString(ent[11]," ",gametypes,sizeof(gametypes),sizeof(gametypes[]))

            bool found
            for(int i = 0; i<sizeof(gametypes);i++){
                if(gametypes[i][0] != 0 && StrEqual(gametypes[i], GM[gamemode].type, false)){
                    found = true
                    break
                }
            }
            
            if(!found){
                continue
            }
        }

        if(ent[12][0] != 0){
            char gametypes[32][32]
            ExplodeString(ent[12]," ",gametypes,sizeof(gametypes),sizeof(gametypes[]))

            bool found
            for(int i = 0; i<sizeof(gametypes);i++){
                if(gametypes[i][0] != 0 && StrEqual(gametypes[i], GM[gamemode].type, false)){
                    found = true
                    break
                }
            }
            
            if(found){
                continue
            }
        }

        SEnt e;
        e.classname = ent[0]

        e.origin[0] = StringToFloat(ent[1])
        e.origin[1] = StringToFloat(ent[2])
        e.origin[2] = StringToFloat(ent[3])

        if(ent[1][0] == 0 && ent[2][0] == 0 && ent[3][0] == 0){
            e.origin = NULL_VECTOR
        }

        e.angle[0] = StringToFloat(ent[4])
        e.angle[1] = StringToFloat(ent[5])
        e.angle[2] = StringToFloat(ent[6])

        if(ent[4][0] == 0 && ent[5][0] == 0 && ent[6][0] == 0){
            e.angle = NULL_VECTOR
        }

        e.targetname = ent[7]
        e.target = ent[8]
        e.spawnflags = StringToInt(ent[9])
        e.wait = StringToInt(ent[10])
        e.count = StringToInt(ent[13])
        e.identifier = StringToInt(ent[14])
        e.message = ent[15]

        e.valid = true
        e.respawn = e.wait != -1






        //initialize ents

        //spawns
        if((StrEqual(e.classname,"info_player_deathmatch", false) && !GM[gamemode].ctf) || (StrEqual(e.classname,"team_CTF_blueplayer", false) && GM[gamemode].ctf) || (StrEqual(e.classname,"team_CTF_redplayer", false) && GM[gamemode].ctf)){
            e.senttype = ET_SPAWN
            sents[sents_count++] = e
            spawns_added = true
            
            continue
        }

        //intermission camera
        if(StrEqual(e.classname,"info_player_intermission", false)){
            if(intermissioncamera != 0){
                continue
            }

            float ang[3]

            if(e.target[0] != 0){
                int target = -1
                static char ent_name[32]
                    static float target_origin[3]
                
                //todo: check if target exists as sent before checking game entities
                
                while ((target = FindEntityByClassname(target, "info_target")) != -1){
                    GetEntPropString(target, Prop_Data, "m_iName", ent_name, sizeof(ent_name))

                    if (StrEqual(e.target, ent_name)){
                        GetEntPropVector(target, Prop_Send, "m_vecOrigin", target_origin)

                        ang[0] = target_origin[0] - e.origin[0]
                        ang[1] = target_origin[1] - e.origin[1]
                        ang[2] = target_origin[2] - e.origin[2]
                        GetVectorAngles(ang,e.angle)

                        break
                    }
                }
            }

            int t = CreateEntityByName("prop_dynamic");
            DispatchKeyValue(t, "model", "models/error.mdl")
            DispatchKeyValue(t, "disablereceiveshadows", "1")
            DispatchKeyValue(t, "disableshadows", "1")
            DispatchKeyValue(t, "solid", "0")
            DispatchKeyValue(t, "spawnflags", "256")
            DispatchKeyValue(t, "rendermode", "10")
            TeleportEntity(t,e.origin,e.angle,NULL_VECTOR)
            DispatchSpawn(t)

            e.senttype = ET_INTERMISSIONCAMERA
            sents[sents_count++] = e
            intermissioncamera = t

            continue
        }
        
        //location
        if(StrEqual(e.classname,"target_location", false)){
            locationsPresent = true
            static int colors[][] = {{0,0,0},{255,0,0},{0,255,0},{255,255,0},{50,100,255},{0,255,255},{255,0,255}}
            
            e.angle[0] = 255
            e.angle[1] = 255
            e.angle[2] = 255
            
            if(strlen(e.message) > 1 && e.message[0] == '^'){
                for(int i = 0;i<sizeof(colors);i++){
                    if(e.message[1] == '0' + i){
                        e.angle[0] = colors[i][0]
                        e.angle[1] = colors[i][1]
                        e.angle[2] = colors[i][2]
                    }
                }
            }
            
            for(int i = 0;i<8;i++){
                char str[4] = "^0"
                str[1] = '0' + i
                ReplaceString(e.message,sizeof(e.message),str,"")
            }
            
            e.senttype = ET_LOCATION
            sents[sents_count++] = e
        }
        
        //pickups
        int item = IT_NONE

        //map the classnames to our item enums
        static char items_name[][] = {"ammo_pack",  "ammo_bullets", "ammo_shells", "ammo_grenades", "ammo_rockets", "ammo_lightning", "ammo_slugs", "ammo_cells", "ammo_hmg", "weapon_machinegun", "weapon_shotgun", "weapon_grenadelauncher", "weapon_rocketlauncher", "weapon_lightning", "weapon_railgun", "weapon_plasmagun", "weapon_hmg",   "item_health_small", "item_health", "item_health_large", "item_health_mega", "item_armor_shard", "item_armor_jacket", "item_armor_combat", "item_armor_body", "item_quad", "item_enviro", "item_haste", "item_invis", "item_regen", "item_flight", "team_ctf_redflag", "team_ctf_blueflag", "team_ctf_neutralflag", "item_scout", "item_guard", "item_doubler", "item_ammoregen", "holdable_invulnerability", "item_key_silver", "item_key_gold", "item_key_master"}
        static int  items_id[]        = { IT_AMMO_ALL, IT_AMMO_MG,      IT_AMMO_SG,    IT_AMMO_GL,     IT_AMMO_RL,      IT_AMMO_LG,      IT_AMMO_RG,   IT_AMMO_PG,   IT_AMMO_HMG, IT_WEAPON_MG,        IT_WEAPON_SG,     IT_WEAPON_GL,             IT_WEAPON_RL,           IT_WEAPON_LG,        IT_WEAPON_RG,     IT_WEAPON_PG,       IT_WEAPON_HMG, IT_HEALTH_5,          IT_HEALTH_25, IT_HEALTH_50,         IT_HEALTH_MEGA,     IT_ARMOR_5,         IT_ARMOR_25,         IT_ARMOR_50,        IT_ARMOR_100,      IT_QUAD,      IT_BATTLESUIT, IT_HASTE,    IT_INVIS,     IT_REGEN,     IT_FLIGHT,     IT_REDFLAG,         IT_BLUEFLAG,         IT_NEUTRALFLAG,          IT_SCOUT,     IT_GUARD,     IT_DOUBLER,     IT_AMMOREGEN,     IT_INVULNERABILITY,        IT_KEY_SILVER,         IT_KEY_GOLD,     IT_KEY_MASTER}

        for(int i = 0; i < sizeof(items_id); i++){
            if(StrEqual(e.classname,items_name[i], false)){
                item = items_id[i]
                break
            }
        }

        if(item != IT_NONE){
            e.item = item

            if(spawnItem(e)){
                sents[sents_count++] = e
                continue
            }
        }

    }

    print("[Q] prepared %i sents",sents_count)
    delete file
    
    if(spawns_added){
        for(int i = MAXPLAYERS;i<10000;i++){//disable default map spawns if we create our own
            if(!IsValidEntity(i)){
                continue
            }
            
            static char classname[64]
            GetEntityClassname(i,classname,sizeof(classname))
            
            if(StrEqual(classname, "info_player_terrorist", false) || StrEqual(classname, "info_player_counterterrorist", false)){
                AcceptEntityInput(i, "SetDisabled")
            }
        }
        
        int spawns = 0
        while(spawns <= GM[gamemode].maxPlayers){
            for(int i = 0;i<sizeof(sents);i++){
                if(!sents[i].valid || sents[i].senttype != ET_SPAWN){
                    continue
                }
                
                if(StrEqual(sents[i].classname,"info_player_deathmatch", false) || StrEqual(sents[i].classname,"team_CTF_blueplayer", false)){
                    int p = CreateEntityByName("info_player_counterterrorist")
                    TeleportEntity(p,sents[i].origin,sents[i].angle,NULL_VECTOR)
                    DispatchSpawn(p)
                    sents[i].ent = p
                    spawns++
                }
                
                if(StrEqual(sents[i].classname,"info_player_deathmatch", false) || StrEqual(sents[i].classname,"team_CTF_redplayer", false)){
                    int p = CreateEntityByName("info_player_terrorist")
                    TeleportEntity(p,sents[i].origin,sents[i].angle,NULL_VECTOR)
                    DispatchSpawn(p)
                    sents[i].phys = p
                    spawns++
                }
                
            }
        }
    }

}

bool spawnItem(SEnt e,bool cheat = false){
    if(!GM[gamemode].items && !cheat){
        return false
    }

    if(e.item == IT_AMMO_ALL){ //disabled for now, spawns only in ctf?
        return false
    }

    int drop_idx = -1
    if(e.dropped){
        for(int i = 0; i<sizeof(sents_dropped); i++){
            if(!sents_dropped[i].valid){
                drop_idx = i
                break
            }
        }

        if(drop_idx == -1){
            return false
        }
    }

    static char model[PLATFORM_MAX_PATH]
    static int skin
    static float height_offset

    height_offset = 12.0
    skin = IT[e.item].skin
    model = IT[e.item].model

    e.senttype = IT[e.item].type
    e.active = true

    if(e.senttype == ET_NONE){
        //print("pickup %s not implemented, skipping...", e.classname)
        return false
    }

    if(e.wait == 0){
        e.wait = IT[e.item].wait
    }

    if(e.count == 0){
        e.count = IT[e.item].count
    }

    //spawn the model
    bool suspend = e.spawnflags & 1
    int phys

    if(!suspend){
        phys = CreateEntityByName("prop_physics")
        DispatchKeyValue(phys, "model", "models/items/item_q3_phys.mdl")
        DispatchKeyValue(phys, "classname", "prop_physics")
        DispatchKeyValue(phys, "spawnflags", "642")    // 2 | 128 | 512
        DispatchKeyValue(phys, "physdamagescale", "0")
        DispatchKeyValue(phys, "nodamageforces", "1")
        TeleportEntity(phys,e.origin,NULL_VECTOR,NULL_VECTOR)
        DispatchSpawn(phys)

        SetEntProp(phys,Prop_Send,"m_CollisionGroup",1)
        e.phys = phys

        if(e.dropped){
            int upright = CreateEntityByName("phys_keepupright")
            DispatchKeyValue(upright, "angularlimit", "9999")
            DispatchSpawn(upright)

            SetEntPropEnt(upright, Prop_Data, "m_attachedObject",phys)
            SetEntProp(upright, Prop_Data, "m_bDampAllRotation",1)

            SetVariantString("!activator")
            AcceptEntityInput(upright, "SetParent",phys)    //parent it to the physics so we dont have to manually remove it later

            ActivateEntity(upright)
        }
    }

    float prop_pos[3]
    prop_pos[0] = e.origin[0]
    prop_pos[1] = e.origin[1]
    prop_pos[2] = e.origin[2] + (suspend ? -8.0 : height_offset)

    int prop = CreateEntityByName("prop_dynamic")
    DispatchKeyValue(prop, "model", model)
    DispatchKeyValue(prop, "classname", "prop_dynamic")
    DispatchKeyValue(prop, "solid", "2")
    DispatchKeyValue(prop, "disableshadows", "1")
    DispatchKeyValue(prop, "disablereceiveshadows", "1")
    DispatchKeyValue(prop, "rendermode", "3")
    TeleportEntity(prop,prop_pos,NULL_VECTOR,NULL_VECTOR)
    DispatchSpawn(prop)

    e.ent = prop
    SDKHook(prop,SDKHook_ShouldCollide,hook_itemShouldCollide)
    //SetEntProp(prop,Prop_Send,"m_nSolidType",2)

    if(!suspend){
        SetVariantString("!activator")
        AcceptEntityInput(prop, "SetParent",phys)
    }


    SetVariantString("rotate")
    AcceptEntityInput(prop, "SetAnimation")

    SetEntProp(prop,Prop_Send,"m_CollisionGroup",1)

    SetEntPropVector(prop, Prop_Send, "m_vecMins", {-40.0, -40.0, -45.0})
    SetEntPropVector(prop, Prop_Send, "m_vecMaxs", {40.0, 40.0, 55.0})
    SetEntProp(prop,Prop_Send,"m_nSkin",skin)

    if(e.senttype == ET_ITEM_WEAPON){
        SetEntPropFloat(prop, Prop_Send, "m_flModelScale", 1.5)
    }

    if(e.senttype == ET_ITEM_POWERUP && !e.dropped){
        deactivateItem(e)
        e.respawnTime = GetGameTime() + 45.0 + GetRandomFloat(0.0,15.0)
    }
    
    if(e.senttype == ET_ITEM_KEY && !e.dropped){ //dropped = spawned with cheats
        deactivateItem(e)
        e.respawnTime = GetGameTime() + 30.0
    }

    if(e.dropped){
        sents_dropped[drop_idx] = e
        RequestFrame(rf_applyItemVel,drop_idx)
    }

    return true
}

void rf_applyItemVel(int i){
    if(sents_dropped[i].valid){
        TeleportEntity(sents_dropped[i].phys,NULL_VECTOR,NULL_VECTOR,sents_dropped[i].angle)
    }
}

void deactivateItem(SEnt e){    //item has been picked up, disable until it respawns
    if(!e.valid || e.ent < MAXPLAYERS || (e.senttype != ET_ITEM_AMMO && e.senttype != ET_ITEM_ARMOR && e.senttype != ET_ITEM_WEAPON && e.senttype != ET_ITEM_HEALTH && e.senttype != ET_ITEM_POWERUP && e.senttype != ET_ITEM_KEY)){
        return
    }

    e.active = false
    AcceptEntityInput(e.ent,"DisableCollision")
    //SetEntProp(e.ent, Prop_Send, "m_nRenderMode",10)    //this can cause items to stay invisible when not in range
    SetEntityRenderColor(e.ent,0,0,0,0)
}

void activateItem(SEnt e){
    if(!e.valid || e.ent < MAXPLAYERS || (e.senttype != ET_ITEM_AMMO && e.senttype != ET_ITEM_ARMOR && e.senttype != ET_ITEM_WEAPON && e.senttype != ET_ITEM_HEALTH && e.senttype != ET_ITEM_POWERUP && e.senttype != ET_ITEM_KEY)){
        return
    }

    e.active = true
    AcceptEntityInput(e.ent,"EnableCollision")
    //SetEntProp(e.ent, Prop_Send, "m_nRenderMode",0)
    SetEntityRenderColor(e.ent,255,255,255,255)
    EmitSoundToAll("items/respawn1.wav",e.ent,SNDCHAN_AUTO,_,0.5)
}

bool checkItemPickup(SEnt e){
    if(e.ent < MAXPLAYERS || !e.active || !e.valid || (gamestate != GS_PLAYING && gamestate != GS_WARMUP && gamestate != GS_ROUNDEND)){
        return false
    }

    for (int i=1; i<=MaxClients; i++){
        if(!IsClientInGame(i) || !IsPlayerAlive(i)){
            continue
        }

        static float ppos[3]
        static float epos[3]

        GetEntPropVector(e.ent,Prop_Data,"m_vecAbsOrigin",epos)
        GetEntPropVector(i,Prop_Data,"m_vecAbsOrigin",ppos)

        //https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/bg_misc.c#L1017
        if (ppos[0] - epos[0] > 36.0        //in range?
            ||ppos[0] - epos[0] < -36.0
            ||ppos[1] - epos[1] > 36.0
            ||ppos[1] - epos[1] < -36.0
            ||ppos[2] - epos[2] > 44.0
            ||ppos[2] - epos[2] < -64.0 ) //-50
        {
            continue
        }

        if(pickupItem(i,e)){
            deactivateItem(e)

            if(e.dropped){
                e.valid = false
                if(e.phys != 0 && IsValidEntity(e.phys)){
                    RemoveEntity(e.phys)
                }

                return true
            }

            if(e.respawn){
                e.respawnTime = GetGameTime() + (e.wait * 1.0)
            }

            return true
        }
    }

    return false
}

bool pickupItem(int client, SEnt e){
    static int i

    if(e.senttype == ET_ITEM_AMMO){
        static int weapon
        weapon = e.item == IT_AMMO_ALL ? 0 : e.item - IT_AMMO_MG + 2

        if(SD[client].wpnAmmo[weapon] >= WPN[weapon].maxAmmo && weapon != 0){
            return false
        }

        if(weapon == 0){
            static bool added
            added = false

            for(i = WEAPON_MACHINEGUN; i < WEAPON_NUM_WEAPONS; i++){
                if(!SD[client].wpnAvailable[i]){
                    continue
                }

                if(SD[client].wpnAmmo[i] < WPN[i].maxAmmo){
                    added = true
                    SD[client].wpnAmmo[i] += IT[IT_AMMO_MG - 2 + i].count

                    if(SD[client].wpnAmmo[i] > WPN[i].maxAmmo){
                        SD[client].wpnAmmo[i] = WPN[i].maxAmmo
                    }
                }
            }

            if(!added){
                return false
            }
        }else{
            SD[client].wpnAmmo[weapon] = SD[client].wpnAmmo[weapon] + e.count

            if(SD[client].wpnAmmo[weapon] > WPN[weapon].maxAmmo){
                SD[client].wpnAmmo[weapon] = WPN[weapon].maxAmmo
            }
        }

        playWeaponSound("misc/am_pkup.wav", client, SNDCHAN_AUTO,_, _, 0.3)

        updateAmmoText(client)
        if(SD[client].activeWeapon == weapon || weapon == 0){
            updateAmmoTextCenter(client)
        }

        return true
    }

    if(e.senttype == ET_ITEM_HEALTH){
        static int health
        health = GetClientHealth(client)

        if((e.item == IT_HEALTH_25 || e.item == IT_HEALTH_50) && health < GM[gamemode].health){
            health += e.count

            if(health > GM[gamemode].health){
                health = GM[gamemode].health
            }

            SetEntityHealth(client,health)
            playWeaponSound(e.item == IT_HEALTH_25 ? "items/n_health.wav" : "items/l_health.wav", client, SNDCHAN_AUTO,_, _, 0.3)
            updateHealthText(client)

            return true
        }

        if((e.item == IT_HEALTH_5 || e.item == IT_HEALTH_MEGA) && health < GM[gamemode].maxHealth){
            health += e.count

            if(health > GM[gamemode].maxHealth){
                health = GM[gamemode].maxHealth
            }

            SetEntityHealth(client,health)
            playWeaponSound(e.item == IT_HEALTH_5 ? "items/s_health.wav" : "items/m_health.wav", client, SNDCHAN_AUTO,_, _, 0.3)
            updateHealthText(client)

            return true
        }

        return false
    }

    if(e.senttype == ET_ITEM_ARMOR){
        static int armor
        armor = SD[client].armor

        if(armor >= GM[gamemode].maxHealth){
            return false
        }

        armor += e.count

        if(armor > GM[gamemode].maxHealth){
            armor = GM[gamemode].maxHealth
        }

        SD[client].armor = armor
        playWeaponSound(e.item == IT_ARMOR_5 ? "misc/ar1_pkup.wav" : "misc/ar2_pkup.wav", client, SNDCHAN_AUTO,_, _, 0.25)
        updateArmorText(client)

        return true
    }

    if(e.senttype == ET_ITEM_WEAPON){
        int weapon = e.item - IT_WEAPON_GA + 1

        SD[client].wpnAvailable[weapon] = true
        SD[client].wpnAmmo[weapon] += e.count

        if(SD[client].wpnAmmo[weapon] < 9999 && SD[client].wpnAmmo[weapon] > WPN[weapon].maxAmmo){
            SD[client].wpnAmmo[weapon] = WPN[weapon].maxAmmo
        }

        playWeaponSound("misc/w_pkup.wav", client, SNDCHAN_AUTO,_, _, 0.3)
        updateAmmoText(client)
        updateAmmoTextCenter(client)
        return true
    }

    if(e.senttype == ET_ITEM_POWERUP){
        static int pw
        pw = e.item - IT_QUAD + 1

        if(pw <= PW_REGEN){    //the other powerups dont have duration
            if(SD[client].powerups[pw] < GetGameTime()){
                SD[client].powerups[pw] = GetGameTime()
            }

            SD[client].powerups[pw] += e.count * 1.0
            updatePlayerSkin(client)
            CreateTimer((e.count * 1.0) + GetTickInterval() * 2,t_updatePlayerSkin,client,TIMER_FLAG_NO_MAPCHANGE)

            playVoiceAll(IT[e.item].voice)
            playLocalSoundAll(IT[e.item].sound)
            PrintToChatAll("%N\x09 got the %s!",client,IT[e.item].name)

            return true
        }

    }
    
    if(e.senttype == ET_ITEM_KEY){
        static int key
        key = e.item - IT_KEY_SILVER
        
        SD[client].numKeys[key]++
        playWeaponSound(IT[e.item].sound, client, SNDCHAN_AUTO,_, _, 0.3)
        PrintToChat(client, "You got the %s!",IT[e.item].name)
        
        return true
    }

    return false
}

void returnKeys(int client){
    for(int key = 0; key < sizeof(SD[].numKeys); key++){
        for(int i = 0; i < sents_count; i++){
            if(SD[client].numKeys[key] <= 0){
                break
            }
            
            if(sents[i].valid && sents[i].item == IT_KEY_SILVER + key && !sents[i].active){
                activateItem(sents[i])
                SD[client].numKeys[key]--
            }
        }
        
        SD[client].numKeys[key] = 0
    }
}

void dropItems(int client){    //drop items on death
    returnKeys(client)
    dropItem(client,SD[client].activeWeapon + IT_WEAPON_GA - 1)

    float angle = 45.0
    for(int i = 1; i<PW_NUM_POWERUPS; i++){
        if(hasPowerup(client,i)){
            dropItem(client,IT_QUAD + i - 1,angle)
            angle += 45.0
        }
    }
}

void dropItem(int client, int item, float angle = 0.0){
    static float pos[3]
    static float ang[3]
    static float fwd[3]
    SEnt s

    if(IT[item].type == ET_ITEM_WEAPON){
        int weapon = item - IT_WEAPON_GA + 1

        if(weapon <= WEAPON_MACHINEGUN || weapon >= WEAPON_NUM_WEAPONS || !SD[client].wpnAvailable[weapon] || SD[client].wpnAmmo[weapon] <= 0){
            return
        }

        s.count = IT[item].count    //set to ammocount of player if he manually dropped the weapon
        SD[client].wpnAvailable[weapon] = false
        SD[client].wpnAmmo[weapon] = 0

        for(int i = WEAPON_NUM_WEAPONS - 1;i>=WEAPON_GAUNTLET;i--){
            if(i == WEAPON_GAUNTLET){
                setDesiredWeapon(client,i)
                break
            }

            if(SD[client].wpnAvailable[i] && SD[client].wpnAmmo[i] > 0){
                setDesiredWeapon(client,i)
                break
            }
        }

        updateAmmoText(client)
        updateAmmoTextCenter(client)

    }else if(IT[item].type == ET_ITEM_POWERUP){
        int pw = item - IT_QUAD + 1
        if(!hasPowerup(client,pw)){
            return
        }

        s.count = RoundToFloor(SD[client].powerups[pw] - GetGameTime())
        if(s.count == 0){
            return
        }

        SD[client].powerups[pw] = 0.0
        updatePlayerSkin(client)
    }else{
        return
    }

    GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", pos)
    GetClientEyeAngles(client,ang)
    ang[0] = 0.0
    ang[1] += angle

    GetAngleVectors(ang,fwd,NULL_VECTOR,NULL_VECTOR)
    ScaleVector(fwd,150.0)
    fwd[2] += 200.0


    s.item = item
    s.senttype = IT[item].type
    s.valid = true
    s.dropped = true

    s.origin = pos
    s.angle = fwd
    s.respawn = false
    s.respawnTime = GetGameTime() + 30.0

    spawnItem(s)
}

Action t_updatePlayerSkin(Handle timer, int data){
    if(IsClientInGame(data)){
        updatePlayerSkin(data)
    }
    return Plugin_Handled
}

void updatePlayerSkin(int client){    //playermodel + weapon vm skin according to powerup
    int skin_pm = 0
    int skin_wpn = 0
    if(hasPowerup(client,PW_INVIS)){    //prioritize invisibility over other powerup skins
        skin_pm = 6
        skin_wpn = 3
    }else if(hasPowerup(client,PW_QUAD)){
        skin_pm = 2
        skin_wpn = 1
    }else if(hasPowerup(client,PW_BATTLESUIT)){
        skin_pm = 4
        skin_wpn = 2
    }else if(hasPowerup(client,PW_REGEN)){
        skin_pm = 8
    }

    skin_pm += !GM[gamemode].teams

    SetEntProp(client,Prop_Send,"m_nSkin",skin_pm)
    SetEntProp(GetEntPropEnt(client,Prop_Send, "m_hViewModel") ,Prop_Send,"m_nSkin",skin_wpn)

    if(skin_wpn == 3){    //invis effects
        int wpn = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")
        if(wpn >= MAXPLAYERS){
            SetEntityModel(GetEntPropEnt(wpn,Prop_Send,"m_hWeaponWorldModel"), "models/items/item_q3_phys.mdl")    //use this model as it is invisible anyways
        }
    }else{
        int wpn = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")
        if(wpn >= MAXPLAYERS){
            SetEntityModel(GetEntPropEnt(wpn,Prop_Send,"m_hWeaponWorldModel"), WPN[SD[client].activeWeapon].worldmodel)
        }
    }

    //clear hud text once all powerups wear off
    for(int i = 1;i<PW_REGEN;i++){
        if(hasPowerup(client,i)){
            return
        }
    }

    PrintHintText(client,"")
}

Action setViewmodelIdleSequence(Handle timer,int client){
    if(!WPN[SD[client].activeWeapon].holdFireAnim || !(SD[client].lastbuttons & IN_ATTACK != 0)){
        setViewmodelSequence(client,WPN[SD[client].activeWeapon].anim_idle)
    }

    return Plugin_Stop
}

Action setViewmodelEquipSequence(Handle timer,int client){
    if(!WPN[SD[client].activeWeapon].holdFireAnim || !(SD[client].lastbuttons & IN_ATTACK != 0)){
        setViewmodelSequence(client,WPN[SD[client].activeWeapon].anim_equip)
    }

    return Plugin_Stop
}

void setViewmodelSequence(int client,int sequence){
    if(!IsClientInGame(client) || !IsPlayerAlive(client)){
        return
    }

    int vm = GetEntPropEnt(client,Prop_Send, "m_hViewModel")
    if(!IsValidEntity(vm)){
        return
    }

    SetEntProp(vm,Prop_Send,"m_nSequence",sequence)
    SetEntPropFloat(vm,Prop_Data,"m_flCycle",0.0)
}

void rf_updateNextPrimaryAttack(int client){
    if(!IsClientInGame(client)){
        return
    }

    static int wpn_ent
    wpn_ent = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")

    if(!IsValidEntity(wpn_ent)){
        return
    }

    //for some reason csgo weapons may fire 1-5 ticks slower. this is really noticeable with fast firing guns. so we just make them shoot every tick and check later if they should actually fire
    //not sure how bad this is for performance considering we will be lagcompensating on every tick
    static float reload
    reload = WPN[SD[client].activeWeapon].reload

    if(hasPowerup(client,PW_HASTE)){
        reload /= 1.3
    }

    if(reload <= 0.1){
        reload = 0.0
    }

    SetEntPropFloat(wpn_ent,Prop_Send, "m_flNextPrimaryAttack",GetGameTime() + reload )
}

void setViewModel(int client, const char[] path){
    if(!IsClientInGame(client) || !IsPlayerAlive(client)){
        return
    }

    int vm = GetEntPropEnt(client,Prop_Send, "m_hViewModel")
    int weapon = GetEntPropEnt(vm,Prop_Send,"m_hWeapon")

    if(weapon == -1)
        return

    SetEntityModel(vm,path)
    SetEntProp(weapon,Prop_Send,"m_nViewModelIndex",GetEntProp(vm,Prop_Send,"m_nModelIndex") )    //todo: is this required?
}

Action t_endWarmup(Handle timer, int data){
    CS_TerminateRound(0.0, CSRoundEnd_Draw, false)
    
    for(int i=1;i<=MaxClients;i++){
        if(!IsClientInGame(i)){
            continue
        }

         SetEntProp(i, Prop_Data, "m_iDeaths", 0)
         CS_SetClientAssists(i,0)
         SetEntProp(i, Prop_Data, "m_iFrags", 0)
    }
    
    if(GM[gamemode].roundbased){
        CreateTimer(0.05, t_setGameState, GS_ROUNDSTARTING, TIMER_FLAG_NO_MAPCHANGE)
    }else{
        CreateTimer(0.05, t_setGameState, GS_PLAYING, TIMER_FLAG_NO_MAPCHANGE)
        //RequestFrame(setGameState, GS_PLAYING)
    }

    return Plugin_Stop
}

Action t_setGameState(Handle timer, int data){
    setGameState(data)
    return Plugin_Stop
}

Action t_endRoundEnd(Handle timer, int data){
    checkGameEnd()
    if(gamestate != GS_INTERMISSION){
        setGameState(GS_ROUNDSTARTING)
    }
    return Plugin_Stop
}

Action t_startRound(Handle timer, int data){
    setGameState(GS_PLAYING)
    return Plugin_Stop
}

Action t_showWarmupEnd(Handle timer, int data){
    static char buf[64]

    if(data == 0){
        if(!GM[gamemode].roundbased){
            showStatusAll("FIGHT!",3)
        }

        return Plugin_Stop
    }

    Format(buf,sizeof(buf),"<font class='fontSize-l'>%s<br>Starts in: %d</font>",GM[gamemode].name, data)
    showStatusAll(buf,2)
    return Plugin_Stop
}

Action t_showRoundStart(Handle timer, int data){
    static char buf[64]

    if(data == 0){
        showStatusAll("FIGHT!",3)
        return Plugin_Stop
    }

    Format(buf,sizeof(buf),"<font class='fontSize-l'>Round Begins in<br>%d</font>", data)
    showStatusAll(buf,2)
    return Plugin_Stop
}

void setGameState(int gs){
    if( gamestate == gs){
        return
    }

    gamestate = gs

    if(gs == GS_WARMUP || gs == GS_WARMUPEND || gs == GS_ROUNDSTARTING){
        h_cvarRespawnT.SetBool(true,true)
        h_cvarRespawnCT.SetBool(true,true)
    }

    if(gs == GS_WARMUPEND){
        roundStart = GetGameTime() + 10.0 + (GM[gamemode].roundbased ? 10.0 : 0.0)
        playVoiceAll(GM[gamemode].teams ? "prepare_your_team.wav" : "prepare_to_fight.wav",0,GetGameTime())

        showFunfactAll("")
        for(int i=0;i<=10;i++){
            CreateTimer(i * 1.0, t_showWarmupEnd,10 - i,TIMER_FLAG_NO_MAPCHANGE)
        }

        CreateTimer(10.0, t_endWarmup,0,TIMER_FLAG_NO_MAPCHANGE)


        if(!GM[gamemode].roundbased){
            GameRules_SetPropFloat("m_fRoundStartTime",GetGameTime())
            GameRules_SetProp("m_iRoundTime", GM[gamemode].timelimit + 10)

            playVoiceAll("three.wav",0,roundStart - 3.0)
            playVoiceAll("two.wav",0,roundStart - 2.0)
            playVoiceAll("one.wav",0,roundStart - 1.0)
        }
    }

    if(gs == GS_ROUNDSTARTING){    
        roundStart = GetGameTime() + 10.0
        restartRound()

        GameRules_SetPropFloat("m_fRoundStartTime",GetGameTime())
        GameRules_SetProp("m_iRoundTime", GM[gamemode].timelimit + 10)

        playVoiceAll("round_begins_in.wav",0,roundStart - 5.0)
        playVoiceAll("three.wav",0,roundStart - 3.0)
        playVoiceAll("two.wav",0,roundStart - 2.0)
        playVoiceAll("one.wav",0,roundStart - 1.0)
        playVoiceAll("fight.wav",0,roundStart)

        for(int i=0;i<=10;i++){
            CreateTimer(i * 1.0, t_showRoundStart,10 - i,TIMER_FLAG_NO_MAPCHANGE)
        }

        CreateTimer(10.0, t_startRound,0,TIMER_FLAG_NO_MAPCHANGE)
    }

    if(gs == GS_PLAYING){    
        h_cvarRespawnT.SetBool(GM[gamemode].respawn,true)
        h_cvarRespawnCT.SetBool(GM[gamemode].respawn,true)
        
        if(!GM[gamemode].roundbased){
            playVoiceAll("fight.wav",0,GetGameTime())
            GameRules_SetPropFloat("m_fRoundStartTime",GetGameTime())
            GameRules_SetProp("m_iRoundTime", GM[gamemode].timelimit)
            
            restartRound()
            
            for(int i = 0;i<sents_count;i++){
                if(sents[i].valid && sents[i].senttype == ET_ITEM_KEY && sents[i].active){
                    deactivateItem(sents[i])
                    sents[i].respawnTime = GetGameTime() + 30.0
                }
            }
        }
    }

    if(gs == GS_ROUNDEND){
        roundStart = GetGameTime() + 13.5
        CreateTimer(3.5, t_endRoundEnd,0,TIMER_FLAG_NO_MAPCHANGE)
    }

    if(gs != GS_PLAYING && gs != GS_WARMUP && gs != GS_INTERMISSION){
        RequestFrame(rf_disableWeaponsUntilNextRound)
    }

    if(gs == GS_INTERMISSION){        
        for(int i = 1;i<=MaxClients;i++){
            if(!IsClientInGame(i)){
                continue
            }
            
            if(intermissioncamera != 0){
                SetEntProp(i, Prop_Send, "m_iFOV",90)
                SetEntProp(i, Prop_Send, "m_iDefaultFOV",90)
                
                
                if(IsPlayerAlive(i)){
                    SetEntPropEnt(i, Prop_Send, "m_hObserverTarget", 0)
                    SetEntProp(i, Prop_Send, "m_iObserverMode", 1)
                }
                
                SetClientViewEntity(i,intermissioncamera)
            }
            
            if(IsPlayerAlive(i)){
                SD[i].nextPrimaryAttack = maxGameTime
                int wpn_ent = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon")
            
                if(IsValidEntity(wpn_ent)){
                    SDKUnhook(wpn_ent,SDKHook_SetTransmit,hook_weaponTransmit)
                    SetEntPropFloat(wpn_ent,Prop_Send, "m_flNextPrimaryAttack", maxGameTime)
                }
                
                SetEntityFlags(i,GetEntityFlags(i) | FL_FROZEN)
            }
            
            updateOverlay(i)            
            ShowHudText(i,2,"")
            ShowHudText(i,3,"")
            ShowHudText(i,4,"")
            ShowHudText(i,5,"")
            ShowHudText(i,6,"")
        }
        
        h_cvarRespawnT.SetBool(false)
        h_cvarRespawnCT.SetBool(false)

        setupMapVote()
        PrintToChatAll("Press 1 to vote for %s (%s).", mapvote[1].nice_name, GM[mapvote[1].gamemodes[0]].name)
        PrintToChatAll("Press 2 to vote for %s (%s).", mapvote[2].nice_name, GM[mapvote[2].gamemodes[0]].name)
        PrintToChatAll("Press 3 to vote for %s (%s).", mapvote[3].nice_name, GM[mapvote[3].gamemodes[0]].name)

        GameRules_SetProp("m_gamePhase",4)    //GAMEPHASE_HALFTIME
        CreateTimer(0.1,t_announcePhaseEnd,0, TIMER_FLAG_NO_MAPCHANGE)
        
        showMapVote()
        GameRules_SetPropFloat("m_fRoundStartTime",GetGameTime())
        GameRules_SetProp("m_iRoundTime",20)
        
        CreateTimer(20.0, t_endMapVote,0,TIMER_FLAG_NO_MAPCHANGE)
    }

}

Action t_endMapVote(Handle timer, int data){
    int votes[4]
    
    for(int i=1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || IsFakeClient(i)){
            continue
        }
        
        if(SD[i].mapVote > 0 && SD[i].mapVote < sizeof(votes)){
            votes[SD[i].mapVote]++
        }
    }
    
    int max
    int num
    for(int i = 1;i<sizeof(votes);i++){
        if(votes[i] > max){
            max = votes[i]
        }
    }
    
    for(int i = 1;i<sizeof(votes);i++){
        if(votes[i] == max){
            num++
        }
    }
    
    int choice = 0
    for(int x = 0;x<1000;x++){
        for(int i = 1;i<sizeof(votes);i++){
            if(votes[i] == max && GetRandomInt(1,num) == 1){
                choice = i
            }
        }
    }
    
    mapVoteWon = choice == 0 ? 2 : choice
    
    showMapVote()
    GameRules_SetPropFloat("m_fRoundStartTime",GetGameTime())
    GameRules_SetProp("m_iRoundTime",5)
    
    CreateTimer(5.0, t_changeMap,0,TIMER_FLAG_NO_MAPCHANGE)
    return Plugin_Stop
}

Action t_changeMap(Handle timer, int data){
    if(mapVoteWon == 0){
        mapVoteWon = 1
    }
    
    setGamemode(mapvote[mapVoteWon].gamemodes[0])
    ServerCommand("changelevel %s", mapvote[mapVoteWon].name)
    return Plugin_Stop
}

Action t_announcePhaseEnd(Handle timer, int data){
    Event e = CreateEvent("announce_phase_end",true)
    e.Fire()
    GameRules_SetProp("m_gamePhase",1)    //GAMEPHASE_PLAYING_STANDARD
    //GameRules_SetProp("m_gamePhase",5)    //GAMEPHASE_MATCH_ENDED    somehow players cant vote for maps with this on some servers, while on others it works completely fine?????
    return Plugin_Stop
}

void rf_disableWeaponsUntilNextRound(){
    for(int i=1; i<=MaxClients;i++){
        if(!IsClientInGame(i) || !IsPlayerAlive(i)){
            continue
        }

        int wpn_ent = GetEntPropEnt(i,Prop_Send,"m_hActiveWeapon")
        if(wpn_ent > 0){
            SetEntPropFloat(wpn_ent,Prop_Send, "m_flNextPrimaryAttack",roundStart)
        }
    }
}

void setGamemode(int gm){
    h_cvarForceAssignTeams.SetBool(!GM[gm].teams,true)
    h_cvarLimitTeams.SetInt(GM[gm].teams,true)
    h_cvarTeammatesAreEnemies.SetBool(!GM[gm].teams,true)

    overtimeAnnounced = false
    fragsLeftAnnounced = 0
    roundStart = 0.0

    gamemode = gm
    setGameState(GS_WARMUP)
}

void clearOverlay(int client){
    if(IsFakeClient(client)){
        return
    }

    SendConVarValue(client,h_cvarHud,"0")
    SendConVarValue(client,h_cvarCrosshair,"0")
}

void setNameSilent(int client,const char[] name){
    hide_namechange = true
    SetClientName(client,name)
    hide_namechange = false
}

void setDesiredWeapon(int client, int weapon){
    if(!IsClientInGame(client) || !IsPlayerAlive(client) || weapon < 0 || weapon >= WEAPON_NUM_WEAPONS || !SD[client].wpnAvailable[weapon]){
        return
    }

    SD[client].lastDesiredWeapon = SD[client].desiredWeapon
    SD[client].desiredWeapon = weapon

    updateOverlay(client)
    updateAmmoTextCenter(client)
}

void switchWeapon(int client, int weapon,bool force = false){
    if((!SD[client].wpnAvailable[weapon] || SD[client].activeWeapon == weapon) && weapon != WEAPON_NONE && !force){
        return
    }

    int wpn_ent = GetEntPropEnt(client,Prop_Send,"m_hActiveWeapon")

    if(wpn_ent > 0){
        if(gamestate != GS_PLAYING && gamestate != GS_WARMUP && roundStart != 0.0){
            SetEntPropFloat(wpn_ent,Prop_Send, "m_flNextPrimaryAttack",roundStart)
        }else{
            SetEntPropFloat(wpn_ent,Prop_Send,"m_flNextPrimaryAttack",GetGameTime() + 0.25)
            SD[client].nextPrimaryAttack = GetGameTime() + 0.25
        }
    }



    SD[client].activeWeapon = weapon

    if(IsValidHandle(SD[client].wpnSoundHumTimer)){
        delete SD[client].wpnSoundHumTimer
    }
    StopSound(client,SNDCHAN_AUTO,"weapons/railgun/rg_hum.wav")
    StopSound(client,SNDCHAN_AUTO,"weapons/melee/fsthum.wav") //lightninggun
    StopSound(client,SNDCHAN_AUTO,"weapons/lightning/lg_hum.wav")
    StopSound(client,SNDCHAN_AUTO,"weapons/melee/fstrun.wav")

    if(wpn_ent > 0){
        if(!hasPowerup(client,PW_INVIS)){
            int worldmodel = GetEntPropEnt(wpn_ent,Prop_Send,"m_hWeaponWorldModel")
            SetEntityModel(worldmodel,WPN[weapon].worldmodel)
        }
        setViewModel(client,WPN[weapon].viewmodel)
        updateWpnTargets(client)
    }

    setViewmodelSequence(client,WPN[weapon].anim_holster)
    CreateTimer(0.0,setViewmodelEquipSequence,client,TIMER_FLAG_NO_MAPCHANGE)

    if(weapon != WEAPON_NONE && !force){
        EmitSoundToAll("weapons/change.wav", client, SNDCHAN_AUTO,_, _, 0.3)
    }

    if(weapon == WEAPON_RAILGUN){
        playWpnHum(INVALID_HANDLE,client)
        SD[client].wpnSoundHumTimer = CreateTimer(1.1,playWpnHum,client,TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE )
    }

    if(weapon == WEAPON_LIGHTNING){
        playWpnHum(INVALID_HANDLE,client)
        SD[client].wpnSoundHumTimer = CreateTimer(0.85,playWpnHum,client,TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE )
    }

    if(weapon == WEAPON_GAUNTLET){
        playWpnHum(INVALID_HANDLE,client)
        SD[client].wpnSoundHumTimer = CreateTimer(1.9,playWpnHum,client,TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE )
    }
}

Action t_gauntletSequence(Handle timer, int client){
    if(!IsClientInGame(client) || !IsPlayerAlive(client)){
        return Plugin_Stop
    }
    bool lmb = SD[client].lastbuttons & IN_ATTACK != 0
    if(lmb){
        setViewmodelSequence(client,WPN[WEAPON_GAUNTLET].anim_attack)
    }else{
        setViewmodelSequence(client,WPN[WEAPON_GAUNTLET].anim_idle)
    }

    return Plugin_Stop
}

Action t_spawnText(Handle timer, int client){
    if(!IsClientInGame(client) || IsFakeClient(client)){
        return Plugin_Stop
    }

    updateAmmoText(client)
    updateAmmoTextCenter(client)
    updateHealthText(client)
    updateArmorText(client)

    return Plugin_Stop
}

void updateLocationText(int client,int location = -1){
    if(!IsClientInGame(client)){
        return
    }
    
    if(!IsPlayerAlive(client)){
        ShowHudText(client,2,"")
        return
    }
    
    if(location < 0 || sents[location].senttype != ET_LOCATION){
        ShowHudText(client,2,"")
        SetEntPropString(client, Prop_Send, "m_szLastPlaceName", "")
        return
    }
    
    SetEntPropString(client, Prop_Send, "m_szLastPlaceName", sents[location].message)
    SetHudTextParams(0.0,0.0,maxGameTime,sents[location].angle[0],sents[location].angle[1],sents[location].angle[2],255,0,0.0,0.0,0.0)
    ShowHudText(client,2,sents[location].message)
}

void updateAmmoText(int client){
    static char ammo[256]
    ammo[0] = 0
    
    if(gamestate == GS_INTERMISSION){
        return
    }

    if(!IsPlayerAlive(client)){
        if(IsFakeClient(client)){
            return
        }

        if(GetEntProp(client, Prop_Send, "m_iObserverMode") == 6){
            SetHudTextParams(0.0059,0.2,maxGameTime,255,255,255,255,0,0.0,0.0,0.0)
            ShowHudText(client,6,"")
        }else{
            if(SD[client].menuOpen != 0){
                ShowHudText(client,6,"")
                return
            }

            int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget")

            if(target < 1 || (GetClientTeam(client) != CS_TEAM_SPECTATOR && !isTeammate(target,client))){
                return
            }

            for(int i = WEAPON_MACHINEGUN;i < WEAPON_NUM_WEAPONS;i++){
                StrCat(ammo,sizeof(ammo), SD[target].wpnAvailable[i] ? "   " : {0x20B8A6E2,' ',0x0} )

                static char num[8]
                IntToString(SD[target].wpnAmmo[i],num,sizeof(num))

                StrCat(ammo,sizeof(ammo), SD[target].wpnAvailable[i] ? SD[target].wpnAmmo[i] < 9999 ? num : {0x9e88e2, 0} : "" )
                StrCat(ammo,sizeof(ammo), "\n")
            }

            SetHudTextParams(0.0059,0.2,maxGameTime,255,255,255,255,0,0.0,0.0,0.0)
            ShowHudText(client,6,ammo)
        }

        return
    }


    for(int i = WEAPON_MACHINEGUN;i < WEAPON_NUM_WEAPONS;i++){
        //StrCat(ammo,sizeof(ammo), SD[client].wpnAvailable[i] ? "   " : "⦸  " )
        StrCat(ammo,sizeof(ammo), SD[client].wpnAvailable[i] ? "   " : {0x20B8A6E2,' ',0x0} )

        static char num[8]
        IntToString(SD[client].wpnAmmo[i],num,sizeof(num))

        StrCat(ammo,sizeof(ammo), SD[client].wpnAvailable[i] ? SD[client].wpnAmmo[i] < 9999 ? num : {0x9e88e2, 0} : "" )
        StrCat(ammo,sizeof(ammo), "\n")
    }


    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || IsFakeClient(i)){
            continue
        }

        if(SD[i].menuOpen != 0){
            ShowHudText(i,6,"")
            continue
        }

        if(i==client){
            SetHudTextParams(0.0059,0.2,maxGameTime,255,255,255,255,0,0.0,0.0,0.0)
            ShowHudText(client,6,ammo)
            continue
        }else{
            if(!IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_iObserverMode") != 6 && GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client && (GetClientTeam(i) == CS_TEAM_SPECTATOR || isTeammate(i,client))){
                SetHudTextParams(0.0059,0.2,maxGameTime,255,255,255,255,0,0.0,0.0,0.0)
                ShowHudText(i,6,ammo)
            }
        }

    }
}

void updateAmmoTextCenter(int client){
    static char ammo_str[8]
    static int ammo_num
    static int r
    static int g
    static int b

    if(gamestate == GS_INTERMISSION){
        return
    }

    if(!IsPlayerAlive(client)){
        if(IsFakeClient(client)){
            return
        }

        if(GetEntProp(client, Prop_Send, "m_iObserverMode") == 6){
            SetHudTextParams(0.495,0.923,maxGameTime,r,g,b,255,0,0.0,0.0,0.0)
            ShowHudText(client,5,"")
        }else{
            int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget")

            if(target < 1 || (GetClientTeam(client) != CS_TEAM_SPECTATOR && !isTeammate(target,client))){
                return
            }

            ammo_num = SD[target].wpnAmmo[SD[target].desiredWeapon]
            IntToString(ammo_num,ammo_str,sizeof(ammo_str))

            if(ammo_num <= 5){
                r = 255
                g = 0
                b = 0
            }else{
                r = 255
                g = 255
                b = 255
            }

            if(ammo_num < 0){    //gauntlet
                strcopy(ammo_str,sizeof(ammo_str),"")
            }
            
            if(ammo_num >= 9999){
                static char inf[16] = {0x9e88e2, 0}
                strcopy(ammo_str,sizeof(ammo_str),inf)
            }

            SetHudTextParams(0.495,0.923,maxGameTime,r,g,b,255,0,0.0,0.0,0.0)
            ShowHudText(client,5,ammo_str)
        }

        return
    }

    ammo_num = SD[client].wpnAmmo[SD[client].desiredWeapon]
    IntToString(ammo_num,ammo_str,sizeof(ammo_str))

    if(ammo_num <= 5){
        r = 255
        g = 0
        b = 0
    }else{
        r = 255
        g = 255
        b = 255
    }

    if(ammo_num < 0){    //gauntlet
        strcopy(ammo_str,sizeof(ammo_str),"")
    }
    
    if(ammo_num >= 9999){
        static char inf[16] = {0x9e88e2, 0}
        strcopy(ammo_str,sizeof(ammo_str),inf)
    }

    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || IsFakeClient(i)){
            continue
        }

        if(i==client){
            SetHudTextParams(0.495,0.923,maxGameTime,r,g,b,255,0,0.0,0.0,0.0)
            ShowHudText(i,5,ammo_str)
            continue
        }else{
            if(!IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_iObserverMode") != 6 && GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client && (GetClientTeam(i) == CS_TEAM_SPECTATOR || isTeammate(i,client))){
                SetHudTextParams(0.495,0.923,maxGameTime,r,g,b,255,0,0.0,0.0,0.0)
                ShowHudText(i,5,ammo_str)
            }
        }

    }

}

void updateHealthText(int client){
    static char ammo_str[8]
    static int ammo_num
    static int r
    static int g
    static int b

    if(gamestate == GS_INTERMISSION){
        return
    }

    if(!IsPlayerAlive(client)){
        if(IsFakeClient(client)){
            return
        }

        if(GetEntProp(client, Prop_Send, "m_iObserverMode") == 6){
            SetHudTextParams(0.33,0.923,maxGameTime,r,g,b,255,0,0.0,0.0,0.0)
            ShowHudText(client,4,"")
        }else{
            int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget")

            if(target < 1 || (GetClientTeam(client) != CS_TEAM_SPECTATOR && !isTeammate(target,client))){
                return
            }

            ammo_num = GetClientHealth(target)
            IntToString(ammo_num,ammo_str,sizeof(ammo_str))

            if(ammo_num <= 25){
                r = 255
                g = 0
                b = 0
            }else{
                r = 255
                g = 255
                b = 255
            }

            SetHudTextParams(0.33,0.923,maxGameTime,r,g,b,255,0,0.0,0.0,0.0)
            ShowHudText(client,4,ammo_str)
        }

        return
    }

    ammo_num = GetClientHealth(client)
    IntToString(ammo_num,ammo_str,sizeof(ammo_str))

    if(ammo_num <= 25){
        r = 255
        g = 0
        b = 0
    }else{
        r = 255
        g = 255
        b = 255
    }


    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || IsFakeClient(i)){
            continue
        }

        if(i==client){
            SetHudTextParams(0.33,0.923,maxGameTime,r,g,b,255,0,0.0,0.0,0.0)
            ShowHudText(i,4,ammo_str)
            continue
        }else{
            if(!IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_iObserverMode") != 6 && GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client && (GetClientTeam(i) == CS_TEAM_SPECTATOR || isTeammate(i,client))){
                SetHudTextParams(0.33,0.923,maxGameTime,r,g,b,255,0,0.0,0.0,0.0)
                ShowHudText(i,4,ammo_str)
            }
        }

    }
}

void updateArmorText(int client){
    static char ammo_str[8]    
    static int ammo_num
    static int r
    static int g
    static int b

    if(gamestate == GS_INTERMISSION){
        return
    }

    if(!IsPlayerAlive(client)){
        if(IsFakeClient(client)){
            return
        }

        if(GetEntProp(client, Prop_Send, "m_iObserverMode") == 6){
            SetHudTextParams(0.64,0.923,maxGameTime,r,g,b,255,0,0.0,0.0,0.0)
            ShowHudText(client,3,"")
        }else{
            int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget")

            if(target < 1 || (GetClientTeam(client) != CS_TEAM_SPECTATOR && !isTeammate(target,client))){
                return
            }

            ammo_num = SD[target].armor
            IntToString(ammo_num,ammo_str,sizeof(ammo_str))

            if(ammo_num <= 25){
                r = 255
                g = 0
                b = 0
            }else{
                r = 255
                g = 255
                b = 255
            }

            SetHudTextParams(0.64,0.923,maxGameTime,r,g,b,255,0,0.0,0.0,0.0)
            ShowHudText(client,3,ammo_str)
        }

        return
    }

    ammo_num = SD[client].armor
    IntToString(ammo_num,ammo_str,sizeof(ammo_str))

    if(ammo_num <= 25){
        r = 255
        g = 0
        b = 0
    }else{
        r = 255
        g = 255
        b = 255
    }


    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || IsFakeClient(i)){
            continue
        }

        if(i==client){
            SetHudTextParams(0.64,0.923,maxGameTime,r,g,b,255,0,0.0,0.0,0.0)
            ShowHudText(i,3,ammo_str)
            continue
        }else{
            if(!IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_iObserverMode") != 6 && GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client && (GetClientTeam(i) == CS_TEAM_SPECTATOR || isTeammate(i,client))){
                SetHudTextParams(0.64,0.923,maxGameTime,r,g,b,255,0,0.0,0.0,0.0)
                ShowHudText(i,3,ammo_str)
            }
        }

    }
}

void showOverlay(int client){
    if(!IsClientInGame(client) || IsFakeClient(client)){
        return
    }

    ClientCommand(client,"r_screenoverlay \"quake/overlays/hud\"")
    updateOverlay(client)
}

void updateOverlay(int client){
    static char frame[8]
    static char ch[8]

    if(gamestate == GS_INTERMISSION && !IsFakeClient(client)){
        SendConVarValue(client,h_cvarHud,"0")
        SendConVarValue(client,h_cvarCrosshair,"0")
        return
    }

    if(!IsPlayerAlive(client)){
        if(IsFakeClient(client)){
            return
        }

        if(GetEntProp(client, Prop_Send, "m_iObserverMode") == 6){
            SendConVarValue(client,h_cvarHud,"0")
            SendConVarValue(client,h_cvarCrosshair,"0")
        }else{
            int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget")

            if(target < 1 || (GetClientTeam(client) != CS_TEAM_SPECTATOR && !isTeammate(target,client))){
                return
            }

            IntToString(SD[target].desiredWeapon,frame,sizeof(frame) )
            SendConVarValue(client,h_cvarHud,frame)

            SendConVarValue(client,h_cvarCrosshair,"0")        //hide crosshair for spectators since they see their csgo crosshair
        }

        return
    }

    IntToString(SD[client].desiredWeapon,frame,sizeof(frame) )
    IntToString(SD[client].crosshairColor + 1,ch,sizeof(ch) )

    for(int i = 1;i<=MaxClients;i++){    //update the hud of your spectators. kinda ugly...
        if(!IsClientInGame(i) || IsFakeClient(i)){
            continue
        }

        if(i==client){
            SendConVarValue(client,h_cvarHud,SD[client].menuOpen != 0 ? "10" : frame)
            SendConVarValue(client,h_cvarCrosshair,ch)
        }else{
            if(!IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_iObserverMode") != 6 && GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client && (GetClientTeam(i) == CS_TEAM_SPECTATOR || isTeammate(i,client))){
                SendConVarValue(i,h_cvarHud,SD[i].menuOpen != 0 ? "10" : frame)
                SendConVarValue(i,h_cvarCrosshair,"0")    //hide crosshair for spectators since they see their csgo crosshair
            }
        }

    }

}

Action t_1s(Handle timer, int data){    //executed every second
    //spectator hud
    for(int i = 1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || IsFakeClient(i) || IsPlayerAlive(i)){
            continue
        }

        bool isfreecam = GetEntProp(i, Prop_Send, "m_iObserverMode") == 6
        int target = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget")

        if(target > 0 && (SD[i].lastSpecMode != isfreecam || SD[i].lastSpecTarget != target)){
            updateOverlay(i)
            updateAmmoText(i)
            updateAmmoTextCenter(i)
            updateHealthText(i)
            updateArmorText(i)

            SD[i].lastSpecMode = isfreecam
            SD[i].lastSpecTarget = target

            updateRailColors(i,SD[target].railColor)
        }
    }


    for(int i = 1;i<=MaxClients;i++){
        if(IsClientInGame(i)){
            //menus
            if(SD[i].menuOpen == menuColorRailgun){
                printHintTextHTML(i,"<img src='file://{images}/ql/rail_colors.png'/>")
            }else if(SD[i].menuOpen == menuLocation){
                printHintTextHTML(i,"<img src='file://{images}/ql/location_help.png'/>")
            }
        }

        if(!IsClientInGame(i) || !IsPlayerAlive(i)){
            continue
        }

        //health/armor decay
        static int health
        static int armor
        static int regen

        if(gamestate == GS_PLAYING || gamestate == GS_WARMUP){
            health = GetClientHealth(i)
            armor = SD[i].armor
            regen = hasPowerup(i,PW_REGEN)

            if(health > GM[gamemode].health && !regen){
                SetEntityHealth(i,health - 1)
                updateHealthText(i)
            }

            if(regen){
                int newhealth = health

                if(health < GM[gamemode].health && health > GM[gamemode].health - 5){
                    newhealth = GM[gamemode].health + 10
                }else if(health < GM[gamemode].health){
                    newhealth += 15
                }else{
                    newhealth += 5
                }

                if(newhealth > GM[gamemode].maxHealth){
                    newhealth = GM[gamemode].maxHealth
                }

                if(newhealth != health){
                    SetEntityHealth(i,newhealth)
                    updateHealthText(i)
                    playWeaponSound("items/regen.wav",i,SNDCHAN_AUTO,_,_,0.5)
                }
            }

            if(armor > GM[gamemode].health){
                SD[i].armor = armor - 1
                updateArmorText(i)
            }
        }


        //powerup text and wearoff
        static bool pw_active
        static char pw_text[2048]

        pw_text[0] = '<'
        pw_text[1] = 'b'
        pw_text[2] = 'r'
        pw_text[3] = '>'
        pw_text[4] = 0

        pw_active = false

        for(int p = 1; p<= PW_REGEN;p++){
            static float timeleft
            timeleft = SD[i].powerups[p] - GetGameTime()

            if(timeleft > 0.0){
                pw_active = true
                Format(pw_text,sizeof(pw_text),"%s<img src='%s'/> %d\n",pw_text, IT[IT_QUAD - 1 + p].icon, RoundToCeil(timeleft))

                if(timeleft < 5.0){
                    playLocalSound(i,"items/wearoff.wav")
                }
            }
        }

        if(pw_active){
            TrimString(pw_text)
            printHintTextHTML(i,pw_text)
        }

    }

    //respawn or delete item pickups
    for(int i = 0;i<sents_count;i++){
        if(!sents[i].valid || sents[i].active || sents[i].respawnTime > GetGameTime()){
            continue
        }

        if(sents[i].senttype == ET_ITEM_POWERUP){
            playLocalSoundAll("items/poweruprespawn.wav")
        }

        activateItem(sents[i])
    }

    for(int i = 0;i<sizeof(sents_dropped);i++){
        if(!sents_dropped[i].valid || sents_dropped[i].phys == 0 || sents_dropped[i].respawnTime > GetGameTime()){
            continue
        }

        if(sents_dropped[i].phys != 0 && IsValidEntity(sents_dropped[i].phys)){
            RemoveEntity(sents_dropped[i].phys)
        }

        sents_dropped[i].valid = false
    }

    //round timelimit
    if(GM[gamemode].timelimit > 0 && gamestate == GS_PLAYING){
        static float f_timeleft
        static int i_timeleft
        f_timeleft = GameRules_GetProp("m_iRoundTime") * 1.0 - (GetGameTime() - GameRules_GetPropFloat("m_fRoundStartTime"))
        i_timeleft = RoundToCeil(f_timeleft)

        if(i_timeleft == 300){
            playVoiceAll("5_minute.wav")
        }

        if(i_timeleft == 60 && !GM[gamemode].roundbased){
            playVoiceAll("1_minute.wav")
        }

        if(f_timeleft <= 0.0){
            if(GM[gamemode].overtime != 2 || (GM[gamemode].overtime == 2 && !overtimeAnnounced)){
                checkRoundEnd()
            }
        }
    }

    //reliable sounds
    for(int i = 0;i<sizeof(reliableSounds);i++){
        if(!reliableSounds[i].valid){
            continue
        }

        if(!IsClientInGame(reliableSounds[i].client)){
            reliableSounds[i].valid = false
            continue
        }

        if(reliableSounds[i].soundtime - GetGameTime() <= 1.0){
            EmitSoundToClient(reliableSounds[i].client,reliableSounds[i].path,reliableSounds[i].entity,reliableSounds[i].channel,_,_,reliableSounds[i].volume ,_,_,_,_,_,reliableSounds[i].soundtime)
            reliableSounds[i].valid = false
        }
    }
    
    //mapvote
    if(gamestate == GS_INTERMISSION){
        showMapVote()
    }
    
    //location
    if(locationsPresent){
        static int location[MAXPLAYERS + 1]
        static float distance[MAXPLAYERS + 1]
        
        for(int i = 0;i<sizeof(location);i++){
            location[i] = -1
            distance[i] = 0.0
        }
        
        for(int i = 0;i<sents_count;i++){
            if(!sents[i].valid || sents[i].senttype != ET_LOCATION){
                continue
            }
            
            static int clients[MAXPLAYERS]
            for(int x = 0;x<sizeof(clients);x++){
                clients[x] = 0
            }
            
            int num = GetClientsInRange(sents[i].origin,RangeType_Visibility,clients,sizeof(clients))
            
            for(int x = 0;x < num; x++){
                if(!SD[clients[x]].locationEnabled){
                    continue
                }
                
                static float pos[3]
                static float dist
                
                GetEntPropVector(clients[x],Prop_Data,"m_vecAbsOrigin",pos)
                dist = GetVectorDistance(pos,sents[i].origin,true)
                
                if(distance[clients[x]] == 0.0 || distance[clients[x]] > dist){
                    distance[clients[x]] = dist
                    location[clients[x]] = i
                }
            }
        }
    
        for(int i = 1;i<=MaxClients;i++){
            updateLocationText(i,location[i])
        }
    }

    return Plugin_Continue
}

void updateRailColors(int client,int color){
    if(IsFakeClient(client)){
        return
    }

    static char r[8]
    static char g[8]
    static char b[8]

    IntToString(railColorsWpn[color][0],r,sizeof(r))
    IntToString(railColorsWpn[color][1],g,sizeof(g))
    IntToString(railColorsWpn[color][2],b,sizeof(b))

    SendConVarValue(client,h_cvarRailR,r)
    SendConVarValue(client,h_cvarRailG,g)
    SendConVarValue(client,h_cvarRailB,b)
}

Action showWhiteCrosshair(Handle timer, int client){
    if(IsClientInGame(client) && SD[client].lastDmgTime + 0.165 < GetGameTime()){
        if(SD[client].crosshairColor != 0){
            SD[client].crosshairColor = 0
            updateOverlay(client)
        }
    }
    return Plugin_Stop
}

void playTeamSound(int client,int sound){
    int[] team = new int[MaxClients]
    int teamcount = 0

    int[] enemy = new int[MaxClients]
    int enemycount = 0

    for (int i=1; i<=MaxClients; i++){
        if (!IsClientInGame(i)){
            continue
        }

        if(GetClientTeam(i) == CS_TEAM_SPECTATOR){
            if(SD[i].lastSpecTarget > 0 && isTeammate(client,SD[i].lastSpecTarget)){
                team[teamcount++] = i
            }else{
                enemy[enemycount++] = i
            }

            continue
        }


        if(isTeammate(i,client)){
            team[teamcount++] = i
        }else{
            enemy[enemycount++] = i
        }
    }

    switch(sound){    //not pretty but hopefully faster than juggling around strings
        case TS_PAIN100: {
            EmitSound(team, teamcount, "player/sarge/pain100_1.wav", client, SNDCHAN_VOICE,_, _, 0.3,_,_,_,_,_,GetGameTime() + GetTickInterval())
            EmitSound(enemy, enemycount, "player/keel/pain100_1.wav", client, SNDCHAN_VOICE,_, _, 0.6,_,_,_,_,_,GetGameTime() + GetTickInterval())
        }
        case TS_PAIN75: {
            EmitSound(team, teamcount, "player/sarge/pain75_1.wav", client, SNDCHAN_VOICE,_, _, 0.3)
            EmitSound(enemy, enemycount, "player/keel/pain75_1.wav", client, SNDCHAN_VOICE,_, _, 0.6)
        }

        case TS_PAIN50: {
            EmitSound(team, teamcount, "player/sarge/pain50_1.wav", client, SNDCHAN_VOICE,_, _, 0.3)
            EmitSound(enemy, enemycount, "player/keel/pain50_1.wav", client, SNDCHAN_VOICE,_, _, 0.6)
        }

        case TS_PAIN25: {
            EmitSound(team, teamcount, "player/sarge/pain25_1.wav", client, SNDCHAN_VOICE,_, _, 0.3)
            EmitSound(enemy, enemycount, "player/keel/pain25_1.wav", client, SNDCHAN_VOICE,_, _, 0.6)
        }

        case TS_DEATH1: {
            EmitSound(team, teamcount, "player/sarge/death1.wav", client, SNDCHAN_BODY,_, _, 0.3,_,_,_,_,_,GetGameTime() + GetTickInterval())
            EmitSound(enemy, enemycount, "player/keel/death1.wav", client, SNDCHAN_BODY,_, _, 0.6,_,_,_,_,_,GetGameTime() + GetTickInterval())
        }

        case TS_DEATH2: {
            EmitSound(team, teamcount, "player/sarge/death2.wav", client, SNDCHAN_BODY,_, _, 0.3,_,_,_,_,_,GetGameTime() + GetTickInterval())
            EmitSound(enemy, enemycount, "player/keel/death2.wav", client, SNDCHAN_BODY,_, _, 0.6,_,_,_,_,_,GetGameTime() + GetTickInterval())
        }

        case TS_DEATH3: {
            EmitSound(team, teamcount, "player/sarge/death3.wav", client, SNDCHAN_BODY,_, _, 0.3,_,_,_,_,_,GetGameTime() + GetTickInterval())
            EmitSound(enemy, enemycount, "player/keel/death3.wav", client, SNDCHAN_BODY,_, _, 0.6,_,_,_,_,_,GetGameTime() + GetTickInterval())
        }

        case TS_JUMP: {
            if(SD[client].lastJumpSound + 0.1 < GetGameTime()){
                EmitSound(team, teamcount, "player/sarge/jump1.wav", client, SNDCHAN_AUTO,_, _, 0.3)
                EmitSound(enemy, enemycount, "player/keel/jump1.wav", client, SNDCHAN_AUTO,_, _, 0.6)
                SD[client].lastJumpSound = GetGameTime()
            }
        }

        case TS_FALL: {
            EmitSound(team, teamcount, "player/sarge/fall1.wav", client, SNDCHAN_VOICE,_, _, 0.3,_,_,_,_,_,GetGameTime() + GetTickInterval())
            EmitSound(enemy, enemycount, "player/keel/fall1.wav", client, SNDCHAN_VOICE,_, _, 0.6,_,_,_,_,_,GetGameTime() + GetTickInterval())
        }

        case TS_FALLING: {
            EmitSound(team, teamcount, "player/sarge/falling1.wav", client, SNDCHAN_VOICE,_, _, 0.3)
            EmitSound(enemy, enemycount, "player/keel/falling1.wav", client, SNDCHAN_VOICE,_, _, 0.6)
        }

        case TS_DROWN: {
            EmitSound(team, teamcount, "player/sarge/drown.wav", client, SNDCHAN_VOICE,_, _, 0.3)
            EmitSound(enemy, enemycount, "player/keel/drown.wav", client, SNDCHAN_VOICE,_, _, 0.6)
        }

        case TS_GASP: {
            EmitSound(team, teamcount, "player/sarge/gasp.wav", client, SNDCHAN_VOICE,_, _, 0.3)
            EmitSound(enemy, enemycount, "player/keel/gasp.wav", client, SNDCHAN_VOICE,_, _, 0.6)
        }

        case TS_TAUNT: {
            EmitSound(team, teamcount, "player/sarge/taunt.wav", client, SNDCHAN_VOICE,_, _, 0.3)
            EmitSound(enemy, enemycount, "player/keel/taunt.wav", client, SNDCHAN_VOICE,_, _, 0.6)
        }


        default:{
            print("[Q] playTeamSound unknown sound: %d", sound)
        }
    }
}

//play sound to everyone, but not as loud for the target entity
void playWeaponSound(const char[] sample, int entity = SOUND_FROM_PLAYER, int channel = SNDCHAN_AUTO, int level = SNDLEVEL_NORMAL, int flags = SND_NOFLAGS, float volume = SNDVOL_NORMAL, int pitch = SNDPITCH_NORMAL, int speakerentity = -1, const float origin[3] = NULL_VECTOR, const float dir[3] = NULL_VECTOR, bool updatePos = true, float soundtime = 0.0, float addition = 0.3){
    int[] clients = new int[MaxClients]
    int total = 0

    for (int i=1; i<=MaxClients; i++){
        if (IsClientInGame(i) && i != entity){
            clients[total++] = i
        }
    }

    if (total){
        EmitSound(clients, total, sample, entity, channel,
            level, flags, volume + addition, pitch, speakerentity,
            origin, dir, updatePos, soundtime)
    }


    EmitSoundToClient(entity, sample, entity, channel,
            level, flags, volume, pitch, speakerentity,
            origin, dir, updatePos, soundtime)
}

Action playWpnHum(Handle timer, int client){
    if(!IsClientInGame(client)){
        return Plugin_Stop
    }

    if(SD[client].activeWeapon == WEAPON_RAILGUN){
        StopSound(client,SNDCHAN_AUTO,"weapons/railgun/rg_hum.wav")
        EmitSoundToAll("weapons/railgun/rg_hum.wav",client,SNDCHAN_AUTO,_,_,0.1)
    }else if(SD[client].activeWeapon == WEAPON_LIGHTNING){
        bool lmb = SD[client].lastbuttons & IN_ATTACK != 0


        if(!lmb || SD[client].wpnAmmo[WEAPON_LIGHTNING] < 1){
            StopSound(client,SNDCHAN_AUTO,"weapons/melee/fsthum.wav")
            EmitSoundToAll("weapons/melee/fsthum.wav",client,SNDCHAN_AUTO,_,_,0.1)
        }else{
            //StopSound(client,SNDCHAN_AUTO,"weapons/lightning/lg_hum.wav")
            EmitSoundToAll("weapons/lightning/lg_hum.wav",client,SNDCHAN_AUTO,_,_,0.3)
        }
    }else if(SD[client].activeWeapon == WEAPON_GAUNTLET){
        bool lmb = SD[client].lastbuttons & IN_ATTACK != 0

        if(lmb){
            //StopSound(client,SNDCHAN_AUTO,"weapons/melee/fstrun.wav")
            playWeaponSound("weapons/melee/fstrun.wav",client,SNDCHAN_AUTO,_,_,0.3)
        }else{
            StopSound(client,SNDCHAN_AUTO,"weapons/melee/fstrun.wav")
        }
    }

    return Plugin_Continue
}

bool hasPowerup(int client, int powerup){
    if(client < 1 || client >= MAXPLAYERS){
        return false
    }

    return (GetGameTime() < SD[client].powerups[powerup])
}

void qVectorMA(float va[3], float scale, float vb[3], float vc[3]){
    vc[0] = va[0] + scale*vb[0]
    vc[1] = va[1] + scale*vb[1]
    vc[2] = va[2] + scale*vb[2]
}

//https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_combat.c#L1078
bool qCanDamage(int ent, float origin[3], int rocket = 0){
    static Handle trace
    static float midpoint[3] //dest

    static float pos[3]
    static float absmin[3]
    static float absmax[3]

    GetEntPropVector(ent,Prop_Data,"m_vecAbsOrigin",pos)
    GetEntPropVector(ent,Prop_Send,"m_vecMins",absmin)
    GetEntPropVector(ent,Prop_Send,"m_vecMaxs",absmax)

    AddVectors(absmin,absmax,midpoint)
    ScaleVector(midpoint,0.5)
    AddVectors(pos,midpoint,midpoint)

    trace = TR_TraceRayFilterEx(origin,midpoint,MASK_SOLID,RayType_EndPoint,trFilterSelfAndPlayers,rocket)
    if(!TR_DidHit(trace) || TR_GetEntityIndex(trace) == ent){
        CloseHandle(trace)
        return true
    }
    CloseHandle(trace)

    midpoint[0] += 15.0
    midpoint[1] += 15.0

    trace = TR_TraceRayFilterEx(origin,midpoint,MASK_SOLID,RayType_EndPoint,trFilterSelfAndPlayers,rocket)
    if(!TR_DidHit(trace) || TR_GetEntityIndex(trace) == ent){
        CloseHandle(trace)
        return true
    }
    CloseHandle(trace)

    midpoint[1] -= 30.0

    trace = TR_TraceRayFilterEx(origin,midpoint,MASK_SOLID,RayType_EndPoint,trFilterSelfAndPlayers,rocket)
    if(!TR_DidHit(trace) || TR_GetEntityIndex(trace) == ent){
        CloseHandle(trace)
        return true
    }
    CloseHandle(trace)

    midpoint[0] -= 30.0
    midpoint[1] += 30.0

    trace = TR_TraceRayFilterEx(origin,midpoint,MASK_SOLID,RayType_EndPoint,trFilterSelfAndPlayers,rocket)
    if(!TR_DidHit(trace) || TR_GetEntityIndex(trace) == ent){
        CloseHandle(trace)
        return true
    }
    CloseHandle(trace)


    midpoint[1] -= 30.0

    trace = TR_TraceRayFilterEx(origin,midpoint,MASK_SOLID,RayType_EndPoint,trFilterSelfAndPlayers,rocket)
    if(!TR_DidHit(trace) || TR_GetEntityIndex(trace) == ent){
        CloseHandle(trace)
        return true
    }
    CloseHandle(trace)


    return false
}

void explodeProjectile(int attacker,float endpos[3],int enthit,bool quaddamage,int rocket,int weapon){
    static Handle trace
    static float plane[3]

    if(enthit == 0){
        trace = getClosestWallTracer(endpos,MASK_SHOT_HULL,rocket)

        if(weapon != WEAPON_GRENADELAUNCHER && trHitSky(trace)){    //dont explode on sky, gl is taken care of in hook_grenadeTouch
            CloseHandle(trace)
            return
        }

        static float dist[3]
        TR_GetEndPosition(dist,trace)
        SubtractVectors(dist,endpos,dist)

        TR_GetPlaneNormal(trace,plane)

        if(GetVectorLength(dist) < 100.0){
            createDecal(weapon,trace)

            if(weapon == WEAPON_PLASMAGUN){
                createBulletHit(weapon, trace)
            }
        }
        CloseHandle(trace)
    }

    if(weapon == WEAPON_ROCKETLAUNCHER || weapon == WEAPON_GRENADELAUNCHER){
        EmitSoundToAll("weapons/rocket/rocklx1a.wav",SOUND_FROM_WORLD,_,_,_,0.7,_,_,endpos)

        static float boom[3]
        boom = endpos

        if(enthit == 0){  //move away from the wall
            ScaleVector(plane,10.0)
            AddVectors(boom,plane,boom)
        }

        TE_Start("EffectDispatch");
        TE_WriteFloat("m_vOrigin.x", boom[0])
        TE_WriteFloat("m_vOrigin.y", boom[1])
        TE_WriteFloat("m_vOrigin.z", boom[2])
        TE_WriteVector("m_vAngles",{0.0,0.0,0.0})
        TE_WriteNum("m_iEffectName",particleEffectIndex)
        TE_WriteNum("m_nHitBox", particle_rlboom)
        TE_SendToAll()
    }

    if(weapon == WEAPON_PLASMAGUN){
        EmitSoundToAll("weapons/plasma/plasmx1a.wav",SOUND_FROM_WORLD,_,_,_,0.3,_,_,endpos)
    }

    static float pos[3]
    static float dir[3]
    static float absmin[3]
    static float absmax[3]
    static float boxmin[3]
    static float boxmax[3]
    static float vel[3]
    
    boxmin[0] = endpos[0] - WPN[weapon].radius
    boxmin[1] = endpos[1] - WPN[weapon].radius
    boxmin[2] = endpos[2] - WPN[weapon].radius
    
    boxmax[0] = endpos[0] + WPN[weapon].radius
    boxmax[1] = endpos[1] + WPN[weapon].radius
    boxmax[2] = endpos[2] + WPN[weapon].radius
    
    for(int i = 0; i < sizeof(trEnumerateEnts);i++){
        trEnumerateEnts[i] = 0
    }
    
    TR_EnumerateEntitiesBox(boxmin, boxmax, PARTITION_SOLID_EDICTS, trWriteArray)
    
    for(int i = 0;i<sizeof(trEnumerateEnts);i++){
        static int ent 
        ent = trEnumerateEnts[i]
    
        if(ent == 0){
            break
        }
        
        if(ent < 0 || !IsValidEntity(ent)){
            continue
        }
        
        if(rocket >= MAXPLAYERS && ent == rocket){
            continue
        }

        if(enthit == ent){
            
            static float rocket_vel[3]
            if(ent < MAXPLAYERS){
                if(rocket == attacker){
                    GetClientEyeAngles(attacker,rocket_vel)
                    GetAngleVectors(rocket_vel,rocket_vel,NULL_VECTOR,NULL_VECTOR)
                    ScaleVector(rocket_vel,WPN[weapon].velocity)
                }else{
                    GetEntPropVector(rocket,Prop_Data,"m_vecAbsVelocity",rocket_vel)
                }
    
                if(GetVectorLength(rocket_vel) < 100.0){    //stepped on a nade
                    rocket_vel[2] = WPN[weapon].velocity * 0.5
                }else{
                    ScaleVector(rocket_vel,weapon == WEAPON_PLASMAGUN ? 0.0625 : 0.5)
                }
    
                
                    GetEntPropVector(ent, Prop_Data, "m_vecAbsVelocity", vel)
                    AddVectors(vel,rocket_vel,vel)
        
                    //TeleportEntity(ent,NULL_VECTOR,NULL_VECTOR,vel)
                    SetEntPropVector(ent, Prop_Data, "m_vecAbsVelocity", vel)
            }
            
            damagePlayer(ent,rocket,attacker,quaddamage ? WPN[weapon].damage * 3.0 : WPN[weapon].damage,DMG_PREVENT_PHYSICS_FORCE,weapon,rocket_vel,endpos)
            showHitParticle(endpos, ent)
            continue
        }

        GetEntPropVector(ent,Prop_Data,"m_vecAbsOrigin",pos)

        if(qCanDamage(ent,endpos,rocket)){
            GetEntPropVector(ent,Prop_Send,"m_vecMins",absmin)
            GetEntPropVector(ent,Prop_Send,"m_vecMaxs",absmax)
            AddVectors(absmin,pos,absmin)
            AddVectors(absmax,pos,absmax)



            // find the distance from the edge of the bounding box
            float v[3]
            for ( int x = 0 ; x < 3 ; x++ ) {
                if ( endpos[x] < absmin[x] ) {
                    v[x] = absmin[x] - endpos[x]
                } else if ( endpos[x] > absmax[x] ) {
                    v[x] = endpos[x] - absmax[x]
                } else {
                    v[x] = 0.0
                }
            }

            float dst = GetVectorLength(v)
            if(dst > WPN[weapon].radius){
                continue
            }

            float dmg = WPN[weapon].splashDamage * (1.0 - dst / WPN[weapon].radius)

            SubtractVectors(pos,endpos,dir)
            dir[2] += 24.0 + 38.0 //add 38 because origin of players in q3 is 24u above the ground which is about half the player size

            damagePlayer(ent,rocket,attacker,quaddamage ? dmg * 3.0 : dmg,_,weapon,dir,endpos)
        }
    }
    
}

void shootProjectile(int client,int weapon){
    static float pos[3]
    static float ang[3]
    static float fwd[3]
    static float vel[3]
    static float spawn[3]
    static Handle trace

    GetClientEyePosition(client,pos)
    GetClientEyeAngles(client,ang)
    GetAngleVectors(ang,fwd,NULL_VECTOR,NULL_VECTOR)

    spawn[0] = pos[0] + fwd[0] * WPN[weapon].prestep
    spawn[1] = pos[1] + fwd[1] * WPN[weapon].prestep
    spawn[2] = pos[2] + fwd[2] * WPN[weapon].prestep

    trace = TR_TraceRayFilterEx(pos,spawn,MASK_SHOT,RayType_EndPoint,trFilterSelf,client) //if there is something x units in front of the player the rocket is basically hitscan
    if(TR_DidHit(trace)){
        TR_GetEndPosition(spawn,trace)

        if(weapon != WEAPON_GRENADELAUNCHER){
            explodeProjectile(client,spawn,TR_GetEntityIndex(trace),hasPowerup(client,PW_QUAD),client,weapon)
            CloseHandle(trace)
            return
        }
    }
    CloseHandle(trace)

    vel = fwd
    if(weapon == WEAPON_GRENADELAUNCHER){
        vel[2] += 0.2
        NormalizeVector(vel,vel)
    }

    ScaleVector(vel,WPN[weapon].velocity)

    int rocket = CreateEntityByName("decoy_projectile")
    TeleportEntity(rocket,spawn,ang,vel)
    DispatchSpawn(rocket)

    SetEntityMoveType(rocket,MOVETYPE_FLY)
    SetEntProp(rocket, Prop_Send, "m_bIsAutoaimTarget",hasPowerup(client,PW_QUAD)) //we abuse this (hopefully) unused netprop to store data
    SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", client)

    if(weapon == WEAPON_ROCKETLAUNCHER){
        SDKHook(rocket, SDKHook_StartTouch, hook_rocketTouch)
        SetEntityModel(rocket,"models/items/q3_rocket.mdl")
        SetEntPropVector(rocket,Prop_Data,"m_vecAngVelocity",{0.0,0.0,360.0})
        EmitSoundToAll("weapons/rocket/rockfly.wav",rocket,SNDCHAN_WEAPON,_,_,0.3)

        int particles = CreateEntityByName("info_particle_system")
        DispatchKeyValue(particles, "classname", "info_particle_system")
        DispatchKeyValue(particles, "effect_name", "smokepuff3")
        DispatchKeyValue(particles, "start_active", "1")
        TeleportEntity(particles,spawn,NULL_VECTOR,NULL_VECTOR)
        DispatchSpawn(particles)

        SetVariantString("!activator")
        AcceptEntityInput(particles, "SetParent",rocket,particles)
        ActivateEntity(particles)
    }

    if(weapon == WEAPON_GRENADELAUNCHER){
        SetEntityMoveType(rocket,MOVETYPE_FLYGRAVITY)
        SDKHook(rocket, SDKHook_StartTouch, hook_grenadeTouch)
        SetEntityModel(rocket,"models/items/item_q3_grenade.mdl")

        static float r[3]
        r[0] = GetRandomFloat(60.0,360.0)
        r[1] = GetRandomFloat(60.0,360.0)
        r[2] = GetRandomFloat(60.0,360.0)

        SetEntPropVector(rocket,Prop_Data,"m_vecAngVelocity",r)

        SetEntPropFloat(rocket,Prop_Data,"m_flWarnAITime",GetGameTime() + 2.45)    //2.45 because timers are tickbased and inaccurate
        CreateTimer(2.5,t_grenadeTimeout,rocket,TIMER_FLAG_NO_MAPCHANGE)

        int particles = CreateEntityByName("info_particle_system")
        DispatchKeyValue(particles, "classname", "info_particle_system")
        DispatchKeyValue(particles, "effect_name", "smokepuff3_gl")
        DispatchKeyValue(particles, "start_active", "1")
        TeleportEntity(particles,spawn,NULL_VECTOR,NULL_VECTOR)
        DispatchSpawn(particles)

        SetVariantString("!activator")
        AcceptEntityInput(particles, "SetParent",rocket,particles)
        ActivateEntity(particles)
    }

    if(weapon == WEAPON_PLASMAGUN){
        SDKHook(rocket, SDKHook_StartTouch, hook_plasmaTouch)
        SetEntityRenderMode(rocket,RENDER_NONE)
        EmitSoundToAll("weapons/plasma/lasfly.wav",rocket,SNDCHAN_WEAPON,_,_,0.6)


        int sprite = CreateEntityByName("env_sprite")
        DispatchKeyValue(sprite, "model", "sprites/q3/plasmaa.vmt")
        DispatchKeyValue(sprite, "classname", "env_sprite")
        DispatchKeyValue(sprite, "scale", "0.75")
        DispatchKeyValue(sprite, "rendermode", "9")

        TeleportEntity(sprite,spawn,NULL_VECTOR,NULL_VECTOR)
        DispatchSpawn(sprite)

        SetVariantString("!activator")
        AcceptEntityInput(sprite, "SetParent",rocket,sprite)
    }

    SetEntPropVector(rocket,Prop_Send,"m_vecMaxs",{0.0,0.0,0.0})
    SetEntPropVector(rocket,Prop_Send,"m_vecMins",{0.0,0.0,0.0})
}

Action t_grenadeTimeout(Handle timer, int rocket){
    if(!IsValidEntity(rocket) || !HasEntProp(rocket,Prop_Data,"m_flWarnAITime") || GetEntPropFloat(rocket,Prop_Data,"m_flWarnAITime") == 0.0 || GetEntPropFloat(rocket,Prop_Data,"m_flWarnAITime") > GetGameTime()){
        return Plugin_Stop //the grenade has already exploded and a new entity is now in its place
    }


    static float endpos[3]
    static int attacker
    static bool quad

    attacker = GetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity")
    quad = GetEntProp(rocket, Prop_Send, "m_bIsAutoaimTarget")
    GetEntPropVector(rocket, Prop_Send, "m_vecOrigin", endpos)

    //char classname[32]
    //GetEntityClassname( rocket,classname,32)
    //print("del %s",classname)

    RemoveEntity(rocket)

    explodeProjectile(attacker,endpos,0,quad,rocket,WEAPON_GRENADELAUNCHER)
    return Plugin_Stop
}

void hook_rocketTouch(int rocket,int other){
    static float endpos[3]
    static int attacker
    static bool quad

    attacker = GetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity")
    quad = GetEntProp(rocket, Prop_Send, "m_bIsAutoaimTarget")
    GetEntPropVector(rocket, Prop_Send, "m_vecOrigin", endpos)
    StopSound(rocket,SNDCHAN_WEAPON,"weapons/rocket/rockfly.wav")
    RemoveEntity(rocket)

    explodeProjectile(attacker,endpos,other,quad,rocket,WEAPON_ROCKETLAUNCHER)
}

void hook_plasmaTouch(int rocket,int other){
    static float endpos[3]
    static int attacker
    static bool quad

    attacker = GetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity")
    quad = GetEntProp(rocket, Prop_Send, "m_bIsAutoaimTarget")
    GetEntPropVector(rocket, Prop_Send, "m_vecOrigin", endpos)
    StopSound(rocket,SNDCHAN_WEAPON,"weapons/plasma/lasfly.wav")
    RemoveEntity(rocket)

    explodeProjectile(attacker,endpos,other,quad,rocket,WEAPON_PLASMAGUN)
}

void hook_preThinkPost(int client){        //https://forums.alliedmods.net/showpost.php?s=ce0165541fe0064e8204bd8e0925f79b&p=2800790&postcount=5
    //hide  health/armor(8) + weapon ammo (1), 256 would hide crosshair but also teamnames and enemy id
    SetEntProp(client,Prop_Send,"m_iHideHUD",9)
}

void hook_onClientGroundChange(int client){
    //print("groundent %d",GetEntPropEnt(client, Prop_Send, "m_hGroundEntity"))

    if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1){
        playWeaponSound("player/land1.wav",client,_,_,_,0.2)

        if(SD[client].lg_fakeground != 4){
            SD[client].lg_fakeground = 0
        }else{
            SD[client].lg_fakeground = 3    //player just used a launchpad
        }
    }
}

bool hook_itemShouldCollide(int entity, int collisiongroup, int contentsmask, bool originalResult){
    if(collisiongroup != 8){
        return true
    }

    //print("touch %d %d %d %d",entity,collisiongroup,contentsmask,originalResult)

    static int i
    for(i = 0;i<sents_count;i++){
        if(sents[i].ent == entity){
            checkItemPickup(sents[i])
            return false
        }
    }

    for(i = 0;i<sizeof(sents_dropped);i++){
        if(sents_dropped[i].ent == entity){
            checkItemPickup(sents_dropped[i])
            return false
        }
    }

    return false
}

void hook_grenadeTouch(int rocket,int other){
    static Handle trace
    static float endpos[3]
    static float vel[3]

    GetEntPropVector(rocket, Prop_Send, "m_vecOrigin", endpos)
    GetEntPropVector(rocket, Prop_Send, "m_vecVelocity", vel)

    if(other >= MAXPLAYERS){
        if(HasEntProp(other, Prop_Data, "m_iHealth") && GetEntProp(other,Prop_Data,"m_iHealth") > 0){
            static int attacker
            static bool quad
        
            attacker = GetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity")
            quad = GetEntProp(rocket, Prop_Send, "m_bIsAutoaimTarget")
            GetEntPropVector(rocket, Prop_Send, "m_vecOrigin", endpos)
            RemoveEntity(rocket)
        
            explodeProjectile(attacker,endpos,other,quad,rocket,WEAPON_GRENADELAUNCHER)
            return            
        }
    }

    if(other == 0 || other >= MAXPLAYERS){    //bounce off the world
        static float plane_normal[3]
        static float newvel[3]
        static float dot

        trace = getClosestWallTracer(endpos,MASK_SHOT_HULL, rocket)

        if(trHitSky(trace)){
            RemoveEntity(rocket)
            CloseHandle(trace)
            return
        }

        TR_GetPlaneNormal(trace,plane_normal)
        CloseHandle(trace)

        dot = GetVectorDotProduct(vel,plane_normal)

        qVectorMA(vel,-2.0 * dot,plane_normal,newvel)
        ScaleVector(newvel,0.65)

        if( plane_normal[2] > 0.2 && GetVectorLength( newvel ) < 40 ){    //too slow, stop the nade
            SetEntityMoveType(rocket, MOVETYPE_FLY)        //stupid hacks to make sure collisions are still checked

            static float ang[3]
            GetEntPropVector(rocket,Prop_Send,"m_angRotation",ang)

            ang[0] = 90.0
            endpos[2] += 4.0
            TeleportEntity(rocket,endpos,ang,NULL_VECTOR)
            SetEntPropVector(rocket,Prop_Data,"m_vecAngVelocity",{0.0,0.0,0.0})

            DataPack dp = new DataPack()
            dp.WriteCell(rocket)
            dp.WriteFloat(newvel[0])
            dp.WriteFloat(newvel[1])
            dp.WriteFloat(0.0)

            RequestFrame(rf_grenadeApplyVelocity,dp)
        }else{
            DataPack dp = new DataPack()
            dp.WriteCell(rocket)
            dp.WriteFloat(newvel[0])
            dp.WriteFloat(newvel[1])
            dp.WriteFloat(newvel[2])

            RequestFrame(rf_grenadeApplyVelocity,dp)
        }

        char snd[] = "weapons/grenade/hgrenb1a.wav"
        snd[22] = '0' + GetRandomInt(1,2)
        EmitSoundToAll(snd,SOUND_FROM_WORLD,_,_,_,0.5,_,_,endpos)

        return    //its not gonna explode if it hit the wall
    }

    static int attacker
    static bool quad

    attacker = GetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity")
    quad = GetEntProp(rocket, Prop_Send, "m_bIsAutoaimTarget")
    GetEntPropVector(rocket, Prop_Send, "m_vecOrigin", endpos)
    RemoveEntity(rocket)

    explodeProjectile(attacker,endpos,other,quad,rocket,WEAPON_GRENADELAUNCHER)
}

void rf_grenadeApplyVelocity(Handle dp){
    static float newvel[3]
    static int rocket

    ResetPack(dp)
    rocket = ReadPackCell(dp)
    newvel[0] = ReadPackFloat(dp)
    newvel[1] = ReadPackFloat(dp)
    newvel[2] = ReadPackFloat(dp)

    if(!IsValidEntity(rocket)){
        CloseHandle(dp)
        return
    }

    TeleportEntity(rocket,NULL_VECTOR,NULL_VECTOR,newvel)
    CloseHandle(dp)
}


                             //down            up                    +x            -x                +y                -y
float dir_angles[][] = { {90.0,0.0,0.0},{-90.0,0.0,0.0},{0.0,0.0,0.0},{0.0,180.0,0.0},{0.0,90.0,0.0},{0.0,-90.0,0.0} }
Handle getClosestWallTracer(float pos[3],int mask = MASK_SHOT,int ent = 0){        //returns the wall or ground closest to pos
    static Handle trace
    static float wall[3]
    float dist[6]

    for(int i = 0;i<sizeof(dist);i++){
        trace = TR_TraceRayFilterEx(pos,dir_angles[i],mask,RayType_Infinite,trFilterSelfAndPlayers, ent)
        TR_GetEndPosition(wall,trace)
        dist[i] = GetVectorDistance(pos,wall)

        CloseHandle(trace)
    }

    int lowest = 0
    for(int i = 1;i<sizeof(dist);i++){
        if(dist[i] < dist[lowest]){
            lowest = i
        }
    }

    return TR_TraceRayFilterEx(pos,dir_angles[lowest],mask,RayType_Infinite,trFilterSelfAndPlayers, ent)
}

void showHitParticle(float pos[3], int victim){
    TE_Start("EffectDispatch");
    TE_WriteFloat("m_vOrigin.x", pos[0])
    TE_WriteFloat("m_vOrigin.y", pos[1])
    TE_WriteFloat("m_vOrigin.z", pos[2])
    TE_WriteVector("m_vAngles",{0.0,0.0,0.0})
    TE_WriteNum("m_iEffectName",particleEffectIndex)
    TE_WriteNum("m_nHitBox", particle_hit)

    int total = 0
    int[] clients = new int[MaxClients]
    for (int i=1; i<=MaxClients; i++){
        if (IsClientInGame(i) && i != victim && GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") != victim){
            clients[total++] = i
        }
    }
    TE_Send(clients, total)
}

void showDamageNumbers(int attacker,int victim,int damage){
    if(GM[gamemode].instagib || damage < 1 || victim > MaxClients || victim < 1 || attacker > MaxClients || attacker < 1 || isTeammate(attacker,victim) || !IsClientInGame(attacker) || !IsClientInGame(victim)){
        return
    }

    int visible_check[MAXPLAYERS + 1]
    int vis_count = 0

    for(int i = 1;i <= MaxClients; i++){
        if(i == attacker || (IsClientInGame(i) && !IsFakeClient(i) && GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == attacker && (GetEntProp(i, Prop_Send, "m_iObserverMode") == 4)) ){
            visible_check[vis_count++] = i

        }
    }

    if(vis_count == 0){
        return
    }

    //spawn the numbers!
    static float pos[3]
    static float right[3]
    static float ang_att[3]
    static float pos_att[3]
    static float newang[3]
    static float scale
    static float dist

    GetClientEyePosition(victim,pos)
    GetClientEyePosition(attacker,pos_att)
    GetClientEyeAngles(attacker,ang_att)
    GetAngleVectors(ang_att,NULL_VECTOR,right,NULL_VECTOR)
    dist = GetVectorDistance(pos_att,pos)

    newang[0] = GetRandomFloat(0.0,-20.0)
    newang[1] = ang_att[1] + (GetRandomInt(0,1) == 0 ? -90.0 : 90.0)


    scale = (dist/40.0)    //some trial and error numbers
    scale = scale > 30.0 ? 30.0 : (scale < 5.0 ? 5.0 : scale)

    pos[0] += GetRandomFloat(-20.0,20.0)
    pos[1] += GetRandomFloat(-20.0,20.0)
    pos[2] += GetRandomFloat(0.0,25.0)

    static int arr
    arr = damage < 36 ? 0 : (damage >= 80 ? 1 : 2 )

    for(int i = 0; i < 10 && damage > 0; i++){ //max num length: 10 digits
        static int num
        num = damage % 10
        damage /= 10

        pos[0] -= right[0] * scale
        pos[1] -= right[1] * scale

        TE_Start("EffectDispatch")
        TE_WriteFloat("m_vOrigin.x", pos[0] )
        TE_WriteFloat("m_vOrigin.y", pos[1] )
        TE_WriteFloat("m_vOrigin.z", pos[2] )
        TE_WriteVector("m_vAngles",newang)
        TE_WriteNum("m_iEffectName",particleEffectIndex)
        TE_WriteNum("m_nHitBox", arr == 0 ? hitnums_white[num] : arr == 1 ? hitnums_red[num] : hitnums_pink[num])
        TE_Send(visible_check,vis_count)

    }
}

void setupMapVote(){
    int maps[3]
    
    int players = 0
    for(int p = 1; p <= MaxClients;p++){
        if(IsClientInGame(p)){
            players++
        }
    }

    for(int m = 0;m<sizeof(maps);m++){
        for(int i=0;i<1000;i++){    //reroll map until we find something
            maps[m] = GetRandomInt(0,num_maps - 1)
            
            if(num_maps > 3 && StrEqual(MAPS[maps[m]].name, currentMap, false)){
                continue
            }
            
            if(MAPS[maps[m]].maxplayers != 0 && players > MAPS[maps[m]].maxplayers){
                continue
            }
            
            if(players > 2 && MAPS[maps[m]].gamemodes[0] == GM_DUEL && MAPS[maps[m]].gamemodes[1] == GM_NONE){
                continue    //skip duel only maps if more than 2 players are present
            }
            
            if(m == 0){
                break
            }
            
            bool found = false
            for(int x = 0; x < sizeof(maps);x++){
                if(x == m){
                    continue
                }
                
                if(maps[x] == maps[m]){
                    found = true
                    break
                }
            }
            
            if(!found){
                break
            }
        }
    }
    
    mapvote[1] = MAPS[maps[0]]
    mapvote[2] = MAPS[maps[1]]
    mapvote[3] = MAPS[maps[2]]
    
    for(int i = 1;i<sizeof(mapvote);i++){
        for(int x = 0;x<1000;x++){
            int gm = mapvote[i].gamemodes[GetRandomInt(0,sizeof(mapvote[].gamemodes) - 1)]
            if( gm != 0){
                mapvote[i].gamemodes[0] = gm
                
                if(gm == GM_DUEL && players > 2 ){
                    continue    //lets see if there is something else if more than 2 players are present
                }
                
                break
            }
        }
    }
}

void showMapVote(){
    if(gamestate != GS_INTERMISSION){
        return
    }
    
    static char buf[256]
    int votes[4]
    
    for(int i=1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || IsFakeClient(i)){
            continue
        }
        
        if(SD[i].mapVote > 0 && SD[i].mapVote < sizeof(votes)){
            votes[SD[i].mapVote]++
        }
    }
    
    for(int i=1;i<=MaxClients;i++){
        if(!IsClientInGame(i) || IsFakeClient(i)){
            continue
        }
        
        static char class[3][64]        
        for(int x = 0;x<sizeof(class);x++){
            if((mapVoteWon != 0 && mapVoteWon != x+1) || SD[i].mapVote == x+1){
                Format(class[x],sizeof(class[]),"class='%s%s' ",mapVoteWon != 0 && mapVoteWon != x+1 ? "negativeColor" : "",SD[i].mapVote == x+1 ? " debug-border" : "")
            }else{
                class[x][0] = 0
            }
        }

        char path[PLATFORM_MAX_PATH]
        
        Format(path, sizeof(path),"materials/panorama/images/ql/%s.png",mapvote[1].name)
        bool f1 = FileExists(path,true,"GAME")
        Format(path, sizeof(path),"materials/panorama/images/ql/%s.png",mapvote[2].name)
        bool f2 = FileExists(path,true,"GAME")
        Format(path, sizeof(path),"materials/panorama/images/ql/%s.png",mapvote[3].name)
        bool f3 = FileExists(path,true,"GAME")
    
        Format(buf,sizeof(buf),"<br><br><br><img %ssrc='file://{images}/ql/%s.png'>[%d]&#9;<img %ssrc='file://{images}/ql/%s.png'>[%d]&#9;<img %ssrc='file://{images}/ql/%s.png'>[%d]"
        ,class[0], f1 ? mapvote[1].name : "default", votes[1]        ,class[1], f2 ? mapvote[2].name : "default", votes[2]        ,class[2], f3? mapvote[3].name : "default", votes[3])

        printHintTextHTML(i,buf)
        SetHudTextParams(0.368,0.93,maxGameTime,255,255,255,255,0,0.0,0.0,0.0)
        ShowHudText(i ,6, GM[mapvote[1].gamemodes[0]].type)
        
        SetHudTextParams(0.465,0.93,maxGameTime,255,255,255,255,0,0.0,0.0,0.0)
        ShowHudText(i ,5, GM[mapvote[2].gamemodes[0]].type)
        
        SetHudTextParams(0.558,0.93,maxGameTime,255,255,255,255,0,0.0,0.0,0.0)
        ShowHudText(i ,4, GM[mapvote[3].gamemodes[0]].type)
    }
}

void damagePlayer(int victim, int inflictor, int attacker, float damage, int damageType=DMG_GENERIC, int weapon=0,const float damageForce[3]=NULL_VECTOR, const float damagePosition[3]=NULL_VECTOR){
    static int armor
    static int save
    
    
    if(attacker != 0 && attacker < MAXPLAYERS && (attacker == -1 || !IsClientInGame(attacker) || GetClientTeam(attacker) == CS_TEAM_SPECTATOR)){    //no funny business allowed
        return
    }

    if(attacker != 0 && victim != 0 && victim >= MAXPLAYERS){    //buttons, chickens etc.
        SDKHooks_TakeDamage(victim,attacker,attacker,damage)    //doesnt account for damage multipliers but whatever
        return
    }

    bool victim_battlesuit = hasPowerup(victim,PW_BATTLESUIT)

    if(victim_battlesuit && (damageType == DMG_FALL || damageType == DMG_BURN || damageType == DMG_RADIATION) ){
        playWeaponSound("items/protect3.wav",victim,SNDCHAN_AUTO,_,_,0.5)
        return
    }

    if(attacker == 0 || attacker >= MAXPLAYERS){
        if(victim_battlesuit){
            damage *= 0.25
        }
        
        if(damage != 0.0 && damage < 1.0){
            damage = 1.0
        }
        
        armor = SD[victim].armor
        save = RoundToCeil(damage * 0.66)    //armor absorbs 66% damage
        save = save >= armor ? armor : save
    
        SDKHooks_TakeDamage(victim, inflictor, attacker, damage - save, damageType,_,damageForce,damagePosition)
        onPlayerTakeDamage(attacker, victim, damage)

        if(save > 0){
            SD[victim].armor -= save
            updateArmorText(victim)
        }
        return
    }

    if(WPN[weapon].projectile){
        SD[victim].lastProjectileDamageTaken = weapon
    }else{
        damage = hasPowerup(attacker,PW_QUAD) ? damage * 3.0 : damage    //projectile weapons pass their damage with quad damage already factored in
        if(weapon == 0){
            weapon = SD[attacker].activeWeapon
        }
    }

    //knockback        https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_combat.c#L821-L822
    if(damageType & DMG_PREVENT_PHYSICS_FORCE == 0){
        static float dir[3]
        static float vel[3]
        static float kvel[3]
        static float max_knockback = 120.0 //g_max_knockback
        float knockback = damage
        float mass = 168.0    //168 in ql, 200 in q3
        float knockback_value = 1000.0    //g_knockback

        if(weapon == WEAPON_ROCKETLAUNCHER){
            knockback_value *= attacker == victim ? 1.1 : 0.9    //g_knockback_rl (_self)
        }

        if(weapon == WEAPON_PLASMAGUN){
            knockback_value *= attacker == victim ? 1.30 : 1.10
        }

        if(weapon == WEAPON_LIGHTNING){
            knockback_value *= 1.75
        }

        if(weapon == WEAPON_GRENADELAUNCHER){
            knockback_value *= 1.10
        }

        if(weapon == WEAPON_RAILGUN){
            knockback_value *= 0.85
        }

        GetEntPropVector(victim, Prop_Data, "m_vecAbsVelocity", vel)

        if(IsNullVector(damageForce) && attacker > 0 && attacker < MAXPLAYERS){
            GetClientEyeAngles(attacker,dir)
            GetAngleVectors(dir,dir,NULL_VECTOR,NULL_VECTOR)
        }else{
            dir = damageForce
        }

        if(attacker == victim){
            if(GM[gamemode].selfdamage){
                damage *= 0.5
            }else{
                damage = 0.0
            }
        }

        if ( knockback > max_knockback ) {
            knockback = max_knockback
        }

        NormalizeVector(dir,dir)
        kvel = dir
        float scale = knockback_value * knockback / mass
        if(scale > max_knockback * 5.0){
            scale = max_knockback * 5.0
        }

        ScaleVector(kvel,scale)
        AddVectors(vel,kvel,kvel)

        SetEntPropVector(victim, Prop_Data, "m_vecAbsVelocity", kvel)
    }

    if(victim_battlesuit){
        damage *= 0.25
        
    }
    
    if(damage != 0.0 && damage < 1.0){
        damage = 1.0
    }

    if(GM[gamemode].instagib){
        damage = 1000.0
    }

    armor = SD[victim].armor
    save = RoundToCeil(damage * 0.66)    //armor absorbs 66% damage
    save = save >= armor ? armor : save

    if(save > 0){
        SD[victim].armor -= save
        updateArmorText(victim)
    }

    SDKHooks_TakeDamage(victim, inflictor, attacker, damage - save, damageType,_,_,damagePosition)
    onPlayerTakeDamage(attacker, victim, damage)
}

void playVoiceAll(const char[] path, float length = 2.0,float forceAt = 0.0){
    if(!path[0]){
        return
    }

    for(int i = 1;i <= MaxClients;i++){
        if(IsClientInGame(i) && (IsPlayerAlive(i) || GetEntProp(i, Prop_Send, "m_iObserverMode") == 6 || GetEntProp(i, Prop_Send, "m_iObserverMode") == 1)){    //if they spectate someone they will hear it from them anyways
            playVoice(i,path,length,forceAt)
        }
    }
}

void playVoice(int client, const char[] path, float length = 2.0,float forceAt = 0.0){
    if(!path[0] || !IsClientInGame(client)){
        return
    }

    static char p[PLATFORM_MAX_PATH]
    Format(p,sizeof(p),"%s/%s",SD[client].voice,path)

    if(forceAt == 0.0 && SD[client].nextVoice < GetGameTime()){
        SD[client].nextVoice = GetGameTime()
    }

    playLocalSound(client,p,p[2] == '/' ? 3.0 : 1.0,forceAt == 0.0 ? SD[client].nextVoice : forceAt)    //default voice "vo/" is more quiet for some reason

    if(forceAt == 0.0){
        SD[client].nextVoice += length
    }
}

void playLocalSoundAll(const char[] path, float volume = 0.3){
    if(!path[0]){
        return
    }

    for(int i = 1;i <= MaxClients;i++){
        if(IsClientInGame(i) && (IsPlayerAlive(i) || GetEntProp(i, Prop_Send, "m_iObserverMode") == 6 || GetEntProp(i, Prop_Send, "m_iObserverMode") == 1)){    //if they spectate someone they will hear it from them anyways
            playLocalSound(i,path,volume)
        }
    }
}

void playQuadSound(int client, bool force = false){
    if(SD[client].lastQuadSound + 1.0 > GetGameTime() && !force){
        return
    }

    playWeaponSound("items/damage3.wav",client,SNDCHAN_AUTO,_,_,0.3)

    if(!force){
        SD[client].lastQuadSound = GetGameTime()
    }
}

void playLocalSound(int client,const char[] path,float volume = 0.3, float time = 0.0){
    if(!path[0] || !IsClientInGame(client)){
        return
    }

    if(IsPlayerAlive(client)){
        for(int cl = 1; cl<=MaxClients; cl++){
            if (!IsClientInGame(cl) || !IsClientObserver(cl)) {
                continue
            }

            //m_iObserverMode: 4 = first person 5 = third person 6 = free roam
            if(client == GetEntPropEnt(cl, Prop_Send, "m_hObserverTarget") && GetEntProp(cl, Prop_Send, "m_iObserverMode") < 6){

                //make sure spectators hear the voice they selected
                static char path_spec[PLATFORM_MAX_PATH]
                static bool vo
                static float vol_spec
                vo = 0
                vol_spec = 1.0

                if(path[0] == 'v' && path[1] == 'o' && strcmp(SD[client].voice,SD[cl].voice) != 0 ){
                    int slash = FindCharInString(path,'/') + 1
                    if(slash == -1){
                        slash = 0
                        vo = 0
                    }

                    Format(path_spec,sizeof(path_spec),"%s/%s",SD[cl].voice,path[slash])
                    vo = 1
                    if(path_spec[2] == '/'){
                        vol_spec = 3.0
                    }
                }

                for(float v = vo ? vol_spec : volume; v > 0.0; v -= 1.0){
                    playReliableSound(cl,vo ? path_spec : path,client,SNDCHAN_STATIC,_,_,v > 1.0 ? 1.0 : v ,_,_,_,_,_,time)
                }
            }
        }
    }else{    //if the sound is exclusively played to a spectator, we have to play it on the entity he is spectating, otherwise he won't hear it
        for(float v = volume; v > 0.0; v -= 1.0){
            playReliableSound(client,path,GetEntProp(client, Prop_Send, "m_iObserverMode") == 4 ? GetEntPropEnt(client, Prop_Send, "m_hObserverTarget") : SOUND_FROM_PLAYER,SNDCHAN_STATIC,_,_,v > 1.0 ? 1.0 : v,_,_,_,_,_,time)
        }
        return
    }

    for(float v = volume; v > 0.0; v -= 1.0){    //play sounds multiple times to bypass volume limit of 1.0
        playReliableSound(client,path,client,SNDCHAN_STATIC,_,_,v > 1.0 ? 1.0 : v ,_,_,_,_,_,time)
    }
}

//queueing too many sounds results in some of them not being played, so we queue them ourself
void playReliableSound(int client, const char[] sample, int entity = SOUND_FROM_PLAYER, int channel = SNDCHAN_AUTO, int level = SNDLEVEL_NORMAL, int flags = SND_NOFLAGS, float volume = SNDVOL_NORMAL, int pitch = SNDPITCH_NORMAL, int speakerentity = -1, const float origin[3] = NULL_VECTOR, const float dir[3] = NULL_VECTOR, bool updatePos = true, float soundtime = 0.0){
    if(soundtime == 0.0 || soundtime - GetGameTime() <= 1.0){    //play right away
        EmitSoundToClient(client,sample,entity,channel,level,flags,volume ,pitch,speakerentity,origin,dir,updatePos,soundtime)
        return
    }

    ReliableSound s
    strcopy(s.path,sizeof(s.path),sample)
    s.client = client
    s.entity = entity
    s.channel = channel
    s.volume = volume
    s.soundtime = soundtime
    s.valid = true

    for(int i = 0;i<sizeof(reliableSounds);i++){
        if(!reliableSounds[i].valid){
            reliableSounds[i] = s
            return
        }
    }

    //no more free slots, try playing it anyways
    EmitSoundToClient(client,sample,entity,channel,level,flags,volume ,pitch,speakerentity,origin,dir,updatePos,soundtime)
}

void updateWpnTargets(int client,float endpos[3] = NULL_VECTOR,bool updateOnly = false){
    if(!updateOnly){
        if(SD[client].wpnAimTarget < 1 || !IsValidEntity(SD[client].wpnAimTarget)){

            int a = CreateEntityByName("prop_dynamic");
            DispatchKeyValue(a, "model", "models/error.mdl")
            DispatchKeyValue(a, "disablereceiveshadows", "1")
            DispatchKeyValue(a, "disableshadows", "1")
            DispatchKeyValue(a, "solid", "0")
            DispatchKeyValue(a, "spawnflags", "256")
            DispatchKeyValue(a, "rendermode", "10")
            DispatchSpawn(a)

            SD[client].wpnAimTarget = a
        }

        if(SD[client].wpnAttachmentTarget < 1 || !IsValidEntity(SD[client].wpnAttachmentTarget)){
            int a = CreateEntityByName("prop_dynamic")
            DispatchKeyValue(a, "model", "models/error.mdl")
            DispatchKeyValue(a, "disablereceiveshadows", "1")
            DispatchKeyValue(a, "disableshadows", "1")
            DispatchKeyValue(a, "solid", "0")
            DispatchKeyValue(a, "spawnflags", "256")
            DispatchKeyValue(a, "rendermode", "10")
            DispatchSpawn(a)

            SD[client].wpnAttachmentTarget = a
        }

        if(SD[client].wpnVMTarget < 1 || !IsValidEntity(SD[client].wpnVMTarget)){
            int a = CreateEntityByName("prop_dynamic")
            DispatchKeyValue(a, "model", "models/error.mdl")
            DispatchKeyValue(a, "disablereceiveshadows", "1")
            DispatchKeyValue(a, "disableshadows", "1")
            DispatchKeyValue(a, "solid", "0")
            DispatchKeyValue(a, "spawnflags", "256")
            DispatchKeyValue(a, "rendermode", "10")
            DispatchSpawn(a)

            SD[client].wpnVMTarget = a
        }
    }


    if(!updateOnly && IsValidEntity(SD[client].wpnAttachmentTarget)){
        SetVariantString("!activator")
        AcceptEntityInput(SD[client].wpnAttachmentTarget, "SetParent", GetEntPropEnt(GetEntPropEnt(client,Prop_Send,"m_hActiveWeapon"),Prop_Send,"m_hWeaponWorldModel") , SD[client].wpnAttachmentTarget)

        if(!hasPowerup(client,PW_INVIS)){
            SetVariantString("1")
            AcceptEntityInput(SD[client].wpnAttachmentTarget,"SetParentAttachment")
        }
    }

    if( !IsNullVector(endpos) ){
         TeleportEntity(SD[client].wpnAimTarget,endpos,NULL_VECTOR,NULL_VECTOR)
    }
}

void updateVMTargetPos(int client){
    static float eyepos[3]
    static float eyeang[3]

    static float fwd[3]
    static float right[3]
    static float up[3]
    static int weapon


    GetClientEyePosition(client,eyepos)
    GetClientEyeAngles(client,eyeang)
    GetAngleVectors(eyeang,fwd,right,up)
    weapon = SD[client].activeWeapon

    if(weapon == WEAPON_RAILGUN){
        eyepos[0] += fwd[0] * 9 - up[0] * 9 + right[0] * 3
        eyepos[1] += fwd[1] * 9 - up[1] * 9 + right[1] * 3
        eyepos[2] += fwd[2] * 9 - up[2] * 9 + right[2] * 3
    }

    if(weapon == WEAPON_MACHINEGUN){
        eyepos[0] += fwd[0] * 30 - up[0] * 25 + right[0] * 6
        eyepos[1] += fwd[1] * 30 - up[1] * 25 + right[1] * 6
        eyepos[2] += fwd[2] * 30 - up[2] * 25 + right[2] * 6
    }


    TeleportEntity(SD[client].wpnVMTarget,eyepos,NULL_VECTOR,NULL_VECTOR)

    if(IsValidEntity(SD[client].wpnVMTarget) && weapon == WEAPON_LIGHTNING){
        SetVariantString("!activator")
        AcceptEntityInput(SD[client].wpnVMTarget, "SetParent", GetEntPropEnt(client,Prop_Send, "m_hViewModel") , SD[client].wpnVMTarget)

        SetVariantString("1")
        AcceptEntityInput(SD[client].wpnVMTarget,"SetParentAttachment")
    }

}

void setupWeaponPresets(){
    WPN[WEAPON_NONE].name = ""
    WPN[WEAPON_NONE].maxAmmo = -1
    WPN[WEAPON_NONE].startingAmmo = -1
    WPN[WEAPON_NONE].damage = 0.0
    WPN[WEAPON_NONE].reload = 99999999.0
    WPN[WEAPON_NONE].viewmodel = "models/items/item_q3_phys.mdl"    //invisible
    WPN[WEAPON_NONE].worldmodel = "models/items/item_q3_phys.mdl"
    WPN[WEAPON_NONE].sound = ""
    WPN[WEAPON_NONE].decal = ""

    WPN[WEAPON_GAUNTLET].name = "Gauntlet"
    WPN[WEAPON_GAUNTLET].maxAmmo = -1
    WPN[WEAPON_GAUNTLET].startingAmmo = -1
    WPN[WEAPON_GAUNTLET].damage = 50.0
    WPN[WEAPON_GAUNTLET].reload = 0.05    //0.4 on hit
    WPN[WEAPON_GAUNTLET].viewmodel = "models/weapons/v_q3_gauntlet.mdl"
    WPN[WEAPON_GAUNTLET].worldmodel = "models/weapons/w_q3_gauntlet.mdl"
    WPN[WEAPON_GAUNTLET].sound = ""
    WPN[WEAPON_GAUNTLET].decal = ""
    WPN[WEAPON_GAUNTLET].anim_idle = 0
    WPN[WEAPON_GAUNTLET].anim_attack = 1    //hit = 4
    WPN[WEAPON_GAUNTLET].anim_equip = 2
    WPN[WEAPON_GAUNTLET].anim_holster = 3
    WPN[WEAPON_GAUNTLET].holdFireAnim = true


    WPN[WEAPON_MACHINEGUN].name = "Machine Gun"
    WPN[WEAPON_MACHINEGUN].maxAmmo = 150
    WPN[WEAPON_MACHINEGUN].startingAmmo = 100
    WPN[WEAPON_MACHINEGUN].damage = 5.0 //4.0 in tdm
    WPN[WEAPON_MACHINEGUN].reload = 0.1
    WPN[WEAPON_MACHINEGUN].viewmodel = "models/weapons/v_q3_machinegun.mdl"
    WPN[WEAPON_MACHINEGUN].worldmodel = "models/weapons/w_q3_machinegun.mdl"
    WPN[WEAPON_MACHINEGUN].sound = ""    //random sound, see onPlayerAttack
    WPN[WEAPON_MACHINEGUN].decal = "materials/gfx/damage/bullet_mrk.vmt"
    WPN[WEAPON_MACHINEGUN].anim_idle = 0
    WPN[WEAPON_MACHINEGUN].anim_attack = 1
    WPN[WEAPON_MACHINEGUN].anim_equip = 2
    WPN[WEAPON_MACHINEGUN].anim_holster = 3
    WPN[WEAPON_MACHINEGUN].holdFireAnim = true

    WPN[WEAPON_SHOTGUN].name = "Shotgun"
    WPN[WEAPON_SHOTGUN].maxAmmo = 25
    WPN[WEAPON_SHOTGUN].startingAmmo = 10
    WPN[WEAPON_SHOTGUN].damage = 5.0
    WPN[WEAPON_SHOTGUN].reload = 1.0
    WPN[WEAPON_SHOTGUN].viewmodel = "models/weapons/v_q3_shotgun.mdl"
    WPN[WEAPON_SHOTGUN].worldmodel = "models/weapons/w_q3_shotgun.mdl"
    WPN[WEAPON_SHOTGUN].sound = "weapons/shotgun/sshotf1b.wav"
    WPN[WEAPON_SHOTGUN].decal = "materials/gfx/damage/bullet_mrk.vmt"
    WPN[WEAPON_SHOTGUN].anim_idle = 3
    WPN[WEAPON_SHOTGUN].anim_attack = 0
    WPN[WEAPON_SHOTGUN].anim_equip = 1
    WPN[WEAPON_SHOTGUN].anim_holster = 2

    WPN[WEAPON_GRENADELAUNCHER].name = "Grenade Launcher"
    WPN[WEAPON_GRENADELAUNCHER].maxAmmo = 25
    WPN[WEAPON_GRENADELAUNCHER].startingAmmo = 10
    WPN[WEAPON_GRENADELAUNCHER].damage = 100.0
    WPN[WEAPON_GRENADELAUNCHER].reload = 0.8
    WPN[WEAPON_GRENADELAUNCHER].radius = 150.0
    WPN[WEAPON_GRENADELAUNCHER].splashDamage = 100.0
    WPN[WEAPON_GRENADELAUNCHER].prestep = 65.0
    WPN[WEAPON_GRENADELAUNCHER].velocity = 700.0
    WPN[WEAPON_GRENADELAUNCHER].viewmodel = "models/weapons/v_q3_grenadel.mdl"
    WPN[WEAPON_GRENADELAUNCHER].worldmodel = "models/weapons/w_q3_grenadelauncher.mdl"
    WPN[WEAPON_GRENADELAUNCHER].projectile = true
    WPN[WEAPON_GRENADELAUNCHER].sound = "weapons/grenade/grenlf1a.wav"
    WPN[WEAPON_GRENADELAUNCHER].decal = "materials/gfx/damage/burn_med_mrk.vmt"
    WPN[WEAPON_GRENADELAUNCHER].anim_idle = 3
    WPN[WEAPON_GRENADELAUNCHER].anim_attack = 0
    WPN[WEAPON_GRENADELAUNCHER].anim_equip = 1
    WPN[WEAPON_GRENADELAUNCHER].anim_holster = 2

    WPN[WEAPON_ROCKETLAUNCHER].name = "Rocket Launcher"
    WPN[WEAPON_ROCKETLAUNCHER].maxAmmo = 25
    WPN[WEAPON_ROCKETLAUNCHER].startingAmmo = 5
    WPN[WEAPON_ROCKETLAUNCHER].damage = 100.0
    WPN[WEAPON_ROCKETLAUNCHER].reload = 0.8
    WPN[WEAPON_ROCKETLAUNCHER].radius = 120.0
    WPN[WEAPON_ROCKETLAUNCHER].velocity = 1000.0
    WPN[WEAPON_ROCKETLAUNCHER].splashDamage = 84.0
    WPN[WEAPON_ROCKETLAUNCHER].prestep = 65.0
    WPN[WEAPON_ROCKETLAUNCHER].viewmodel = "models/weapons/v_q3_rocketl.mdl"
    WPN[WEAPON_ROCKETLAUNCHER].worldmodel = "models/weapons/w_q3_rocketlauncher.mdl"
    WPN[WEAPON_ROCKETLAUNCHER].projectile = true
    WPN[WEAPON_ROCKETLAUNCHER].sound = "weapons/rocket/rocklf1a.wav"
    WPN[WEAPON_ROCKETLAUNCHER].decal = "materials/gfx/damage/burn_med_mrk.vmt"
    WPN[WEAPON_ROCKETLAUNCHER].anim_idle = 3
    WPN[WEAPON_ROCKETLAUNCHER].anim_attack = 0
    WPN[WEAPON_ROCKETLAUNCHER].anim_equip = 1
    WPN[WEAPON_ROCKETLAUNCHER].anim_holster = 2

    WPN[WEAPON_LIGHTNING].name = "Lightning Gun"
    WPN[WEAPON_LIGHTNING].maxAmmo = 150
    WPN[WEAPON_LIGHTNING].startingAmmo = 100
    WPN[WEAPON_LIGHTNING].damage = 6.0
    WPN[WEAPON_LIGHTNING].reload = 0.05
    WPN[WEAPON_LIGHTNING].viewmodel = "models/weapons/v_q3_lightninggun.mdl"
    WPN[WEAPON_LIGHTNING].worldmodel = "models/weapons/w_q3_lightninggun.mdl"
    WPN[WEAPON_LIGHTNING].sound = ""
    WPN[WEAPON_LIGHTNING].decal = "materials/gfx/damage/hole_lg_mrk.vmt"
    WPN[WEAPON_LIGHTNING].anim_idle = 0
    WPN[WEAPON_LIGHTNING].anim_attack = 3
    WPN[WEAPON_LIGHTNING].anim_equip = 1
    WPN[WEAPON_LIGHTNING].anim_holster = 2
    WPN[WEAPON_LIGHTNING].holdFireAnim = true

    WPN[WEAPON_RAILGUN].name = "Railgun"
    WPN[WEAPON_RAILGUN].maxAmmo = 25
    WPN[WEAPON_RAILGUN].startingAmmo = 5
    WPN[WEAPON_RAILGUN].damage = 80.0
    WPN[WEAPON_RAILGUN].reload = 1.5
    WPN[WEAPON_RAILGUN].viewmodel = "models/weapons/v_q3_railgun.mdl"
    WPN[WEAPON_RAILGUN].worldmodel = "models/weapons/w_q3_railgun.mdl"
    WPN[WEAPON_RAILGUN].sound = "weapons/railgun/railgf1a.wav"
    WPN[WEAPON_RAILGUN].decal = "materials/gfx/damage/plasma_mrk.vmt"
    WPN[WEAPON_RAILGUN].anim_idle = 3
    WPN[WEAPON_RAILGUN].anim_attack = 0
    WPN[WEAPON_RAILGUN].anim_equip = 1
    WPN[WEAPON_RAILGUN].anim_holster = 2

    WPN[WEAPON_PLASMAGUN].name = "Plasma Gun"
    WPN[WEAPON_PLASMAGUN].maxAmmo = 150
    WPN[WEAPON_PLASMAGUN].startingAmmo = 50
    WPN[WEAPON_PLASMAGUN].damage = 20.0
    WPN[WEAPON_PLASMAGUN].reload = 0.1
    WPN[WEAPON_PLASMAGUN].radius = 20.0
    WPN[WEAPON_PLASMAGUN].velocity = 2000.0
    WPN[WEAPON_PLASMAGUN].splashDamage = 15.0
    WPN[WEAPON_PLASMAGUN].prestep = 320.0
    WPN[WEAPON_PLASMAGUN].viewmodel = "models/weapons/v_q3_plasmagun.mdl"
    WPN[WEAPON_PLASMAGUN].worldmodel = "models/weapons/w_q3_plasmagun.mdl"
    WPN[WEAPON_PLASMAGUN].projectile = true
    WPN[WEAPON_PLASMAGUN].sound = "weapons/plasma/hyprbf1a.wav"
    WPN[WEAPON_PLASMAGUN].decal = "materials/gfx/damage/plasma_mrk.vmt"
    WPN[WEAPON_PLASMAGUN].anim_idle = 3
    WPN[WEAPON_PLASMAGUN].anim_attack = 0
    WPN[WEAPON_PLASMAGUN].anim_equip = 1
    WPN[WEAPON_PLASMAGUN].anim_holster = 2
    WPN[WEAPON_PLASMAGUN].holdFireAnim = true

    WPN[WEAPON_HMG].name = "Heavy Machine Gun"
    WPN[WEAPON_HMG].maxAmmo = 150
    WPN[WEAPON_HMG].startingAmmo = 50
    WPN[WEAPON_HMG].damage = 8.0
    WPN[WEAPON_HMG].reload = 0.075
    WPN[WEAPON_HMG].viewmodel = "models/weapons/v_q3_hmg.mdl"
    WPN[WEAPON_HMG].worldmodel = "models/weapons/w_q3_hmg.mdl"
    WPN[WEAPON_HMG].sound = ""
    WPN[WEAPON_HMG].decal = "materials/gfx/damage/bullet_mrk.vmt"
    WPN[WEAPON_HMG].anim_idle = 3
    WPN[WEAPON_HMG].anim_attack = 0
    WPN[WEAPON_HMG].anim_equip = 1
    WPN[WEAPON_HMG].anim_holster = 2
    WPN[WEAPON_HMG].holdFireAnim = true

}

void setupMaps(){
    
    File file = OpenFile("maps/info/maplist.txt","r",true,"GAME")
    
    if(!file){
        delete file
        return
    }

    char buf[512]
    int num = 0
    while(ReadFileLine(file,buf,sizeof(buf))){
        TrimString(buf)

        if(buf[0] == ';' || buf[0] == '\0' || buf[0] == '\r' || buf[0] == '\n'){
            continue
        }

        char map[32][sizeof(MAPS[].name)]
        ExplodeString(buf,";",map,sizeof(map),sizeof(map[]))
        
        if(map[0][0] == 0){
            continue
        }
        
        MAPS[num].name = map[0]
        
        if(map[1][0] == 0){
            MAPS[num].nice_name = map[0]
        }else{
            MAPS[num].nice_name = map[1]
        }
        
        if(map[2][0] == 0){
            MAPS[num].gamemodes[0] = GM_FFA
            MAPS[num].gamemodes[1] = GM_TDM
        }else{
            char gamemodes[32][64]
            ExplodeString(map[2]," ",gamemodes,sizeof(gamemodes),sizeof(gamemodes[]))
            
            for(int i = 0;i<GM_NUM_GAMEMODES;i++){
                if(gamemodes[i][0] == 0){
                    break
                }
                
                for(int x = 0;x < GM_NUM_GAMEMODES;x++){
                    if(StrEqual(gamemodes[i],GM[x].type,false)){
                        MAPS[num].gamemodes[i] = x
                        break
                    }
                }
            }
        }
        
        if(map[3][0] != 0){
            MAPS[num].maxplayers = StringToInt(map[3])
        }
    
        num++
    }

    for(int i = 0;i<sizeof(MAPS);i++){
        if(MAPS[i].name[0] == 0){
            num_maps = i
            break
        }
    }
}

void setupGamemodePresets(){
    int all_weapons = (1<<WEAPON_NUM_WEAPONS - 1) - 1

    GM[GM_TDM].teams = true
    GM[GM_TDM].respawn = true
    GM[GM_TDM].selfdamage = true
    GM[GM_TDM].instagib = false
    GM[GM_TDM].scorelimit = 150
    GM[GM_TDM].timelimit = 900
    GM[GM_TDM].items = true
    GM[GM_TDM].roundbased = false
    GM[GM_TDM].killsscore = true
    GM[GM_TDM].type = "tdm"
    GM[GM_TDM].name = "Team Deathmatch"
    GM[GM_TDM].health = 100
    GM[GM_TDM].maxHealth = 200
    GM[GM_TDM].startHealth = 125
    GM[GM_TDM].startArmor = 0
    GM[GM_TDM].startingWeapons = 3
    GM[GM_TDM].overtime = 2
    GM[GM_TDM].maxPlayers = 32
    
    GM[GM_IFFA].teams = false
    GM[GM_IFFA].respawn = true
    GM[GM_IFFA].selfdamage = false
    GM[GM_IFFA].instagib = true
    GM[GM_IFFA].scorelimit = 50
    GM[GM_IFFA].timelimit = 900
    GM[GM_IFFA].items = false
    GM[GM_IFFA].roundbased = false
    GM[GM_IFFA].killsscore = true
    GM[GM_IFFA].type = "iffa"
    GM[GM_IFFA].name = "InstaGib Free For All"
    GM[GM_IFFA].health = 100
    GM[GM_IFFA].maxHealth = 200
    GM[GM_IFFA].startHealth = 125
    GM[GM_IFFA].startArmor = 0
    GM[GM_IFFA].startingWeapons = (1<<WEAPON_GAUNTLET - 1) | (1<<WEAPON_RAILGUN - 1)
    GM[GM_IFFA].overtime = 2
    GM[GM_IFFA].maxPlayers = 32

    GM[GM_FFA].teams = false
    GM[GM_FFA].respawn = true
    GM[GM_FFA].selfdamage = true
    GM[GM_FFA].instagib = false
    GM[GM_FFA].scorelimit = 50
    GM[GM_FFA].timelimit = 900
    GM[GM_FFA].items = true
    GM[GM_FFA].roundbased = false
    GM[GM_FFA].killsscore = true
    GM[GM_FFA].type = "ffa"
    GM[GM_FFA].name = "Free For All"
    GM[GM_FFA].health = 100
    GM[GM_FFA].maxHealth = 200
    GM[GM_FFA].startHealth = 125
    GM[GM_FFA].startArmor = 0
    GM[GM_FFA].startingWeapons = 3
    GM[GM_FFA].overtime = 2
    GM[GM_FFA].maxPlayers = 32
    
    GM[GM_DUEL].teams = false
    GM[GM_DUEL].respawn = true
    GM[GM_DUEL].selfdamage = true
    GM[GM_DUEL].instagib = false
    GM[GM_DUEL].scorelimit = 0
    GM[GM_DUEL].timelimit = 600
    GM[GM_DUEL].items = true
    GM[GM_DUEL].roundbased = false
    GM[GM_DUEL].killsscore = true
    GM[GM_DUEL].type = "duel"
    GM[GM_DUEL].name = "Duel"
    GM[GM_DUEL].health = 100
    GM[GM_DUEL].maxHealth = 200
    GM[GM_DUEL].startHealth = 125
    GM[GM_DUEL].startArmor = 0
    GM[GM_DUEL].startingWeapons = 3
    GM[GM_DUEL].overtime = 1
    GM[GM_DUEL].maxPlayers = 2
    
    GM[GM_CA].teams = true
    GM[GM_CA].respawn = false
    GM[GM_CA].selfdamage = false
    GM[GM_CA].instagib = false
    GM[GM_CA].scorelimit = 10
    GM[GM_CA].timelimit = 190
    GM[GM_CA].items = false
    GM[GM_CA].roundbased = true
    GM[GM_CA].killsscore = false
    GM[GM_CA].type = "ca"
    GM[GM_CA].name = "Clan Arena"
    GM[GM_CA].health = 200
    GM[GM_CA].maxHealth = 200
    GM[GM_CA].startHealth = 200
    GM[GM_CA].startArmor = 100
    GM[GM_CA].startingWeapons = all_weapons
    GM[GM_CA].overtime = 0
    GM[GM_CA].maxPlayers = 32

    GM[GM_TEST].teams = true
    GM[GM_TEST].respawn = false
    GM[GM_TEST].selfdamage = true
    GM[GM_TEST].instagib = false
    GM[GM_TEST].scorelimit = 10
    GM[GM_TEST].timelimit = 900
    GM[GM_TEST].items = true
    GM[GM_TEST].roundbased = true
    GM[GM_TEST].killsscore = false
    GM[GM_TEST].type = "test"
    GM[GM_TEST].name = "Testing"
    GM[GM_TEST].health = 100
    GM[GM_TEST].maxHealth = 200
    GM[GM_TEST].startHealth = 125
    GM[GM_TEST].startArmor = 125
    GM[GM_TEST].startingWeapons = all_weapons
    GM[GM_TEST].overtime = 0
    GM[GM_TEST].maxPlayers = 32
}

void setupItemPresets(){
    IT[IT_NONE].model = ""
    IT[IT_NONE].skin = 0
    IT[IT_NONE].type = ET_NONE
    IT[IT_NONE].wait = 0
    IT[IT_NONE].count = 0

    for(int i = IT_AMMO_MG; i<=IT_AMMO_ALL;i++){
        IT[i].model = "models/items/item_q3_ammo.mdl"
        IT[i].skin = i == IT_AMMO_ALL ? 0 : i - IT_AMMO_MG + 1
        IT[i].type = ET_ITEM_AMMO
        IT[i].wait = 40

        switch(i){
            case IT_AMMO_MG, IT_AMMO_LG, IT_AMMO_PG, IT_AMMO_HMG:{
                IT[i].count = 50
            }

            default: {
                IT[i].count = 5
            }
        }
    }
    
    for(int i = IT_HEALTH_5;i<=IT_HEALTH_50;i++){
        IT[i].model = "models/items/item_q3_health.mdl"
        IT[i].skin = i - IT_HEALTH_5
        IT[i].type = ET_ITEM_HEALTH
        IT[i].wait = 35
        IT[i].count = i == IT_HEALTH_5 ? 5 : (i == IT_HEALTH_25 ? 25 : 50)
    }

    for(int i = IT_ARMOR_25;i<=IT_ARMOR_100;i++){
        IT[i].model = "models/items/item_q3_armor.mdl"
        IT[i].skin = i - IT_ARMOR_25
        IT[i].type = ET_ITEM_ARMOR
        IT[i].wait = 25
        IT[i].count = i == IT_ARMOR_25 ? 25 : i == IT_ARMOR_50 ? 50 : 100
    }
    
    //only used for qgive command
    IT[IT_AMMO_MG].name = "Bullets"
    IT[IT_AMMO_SG].name = "Shells"
    IT[IT_AMMO_GL].name = "Grenades"
    IT[IT_AMMO_RL].name = "Rockets"
    IT[IT_AMMO_LG].name = "Lightning"
    IT[IT_AMMO_RG].name = "Slugs"
    IT[IT_AMMO_PG].name = "Cells"
    IT[IT_AMMO_HMG].name = "Heavy Bullets"
    
    IT[IT_HEALTH_5].name = "5 Health"
    IT[IT_HEALTH_25].name = "25 Health"
    IT[IT_HEALTH_50].name = "50 Health"
    
    IT[IT_ARMOR_25].name = "Green Armor"
    IT[IT_ARMOR_50].name = "Yellow Armor"
    IT[IT_ARMOR_100].name = "Red Armor"
    

    IT[IT_WEAPON_GA].name = "Gauntlet"
    IT[IT_WEAPON_GA].model = "models/items/item_q3_gauntlet.mdl"
    IT[IT_WEAPON_GA].type = ET_ITEM_WEAPON
    IT[IT_WEAPON_GA].wait = 5
    IT[IT_WEAPON_GA].count = 0

    IT[IT_WEAPON_MG].name = "Machine Gun"
    IT[IT_WEAPON_MG].model = "models/items/item_q3_machinegun.mdl"
    IT[IT_WEAPON_MG].type = ET_ITEM_WEAPON
    IT[IT_WEAPON_MG].wait = 5
    IT[IT_WEAPON_MG].count = 100

    IT[IT_WEAPON_SG].name = "Shotgun"
    IT[IT_WEAPON_SG].model = "models/items/item_q3_shotgun.mdl"
    IT[IT_WEAPON_SG].type = ET_ITEM_WEAPON
    IT[IT_WEAPON_SG].wait = 5
    IT[IT_WEAPON_SG].count = 10

    IT[IT_WEAPON_GL].name = "Grenade Launcher"
    IT[IT_WEAPON_GL].model = "models/items/item_q3_grenadelauncher.mdl"
    IT[IT_WEAPON_GL].type = ET_ITEM_WEAPON
    IT[IT_WEAPON_GL].wait = 5
    IT[IT_WEAPON_GL].count = 10

    IT[IT_WEAPON_RL].name = "Rocket Launcher"
    IT[IT_WEAPON_RL].model = "models/items/item_q3_rocketlauncher.mdl"
    IT[IT_WEAPON_RL].type = ET_ITEM_WEAPON
    IT[IT_WEAPON_RL].wait = 5
    IT[IT_WEAPON_RL].count = 10

    IT[IT_WEAPON_LG].name = "Lightning Gun"
    IT[IT_WEAPON_LG].model = "models/items/item_q3_lightninggun.mdl"
    IT[IT_WEAPON_LG].type = ET_ITEM_WEAPON
    IT[IT_WEAPON_LG].wait = 5
    IT[IT_WEAPON_LG].count = 100

    IT[IT_WEAPON_RG].name = "Railgun"
    IT[IT_WEAPON_RG].model = "models/items/item_q3_railgun.mdl"
    IT[IT_WEAPON_RG].type = ET_ITEM_WEAPON
    IT[IT_WEAPON_RG].wait = 5
    IT[IT_WEAPON_RG].count = 10

    IT[IT_WEAPON_PG].name = "Plasma Gun"
    IT[IT_WEAPON_PG].model = "models/items/item_q3_plasmagun.mdl"
    IT[IT_WEAPON_PG].type = ET_ITEM_WEAPON
    IT[IT_WEAPON_PG].wait = 5
    IT[IT_WEAPON_PG].count = 50

    IT[IT_WEAPON_HMG].name = "Heavy Machinegun"
    IT[IT_WEAPON_HMG].model = "models/items/item_q3_hmg.mdl"
    IT[IT_WEAPON_HMG].type = ET_ITEM_WEAPON
    IT[IT_WEAPON_HMG].wait = 5
    IT[IT_WEAPON_HMG].count = 100

    IT[IT_HEALTH_MEGA].name = "Mega Health"
    IT[IT_HEALTH_MEGA].model = "models/items/item_q3_healthmega.mdl"
    IT[IT_HEALTH_MEGA].type = ET_ITEM_HEALTH
    IT[IT_HEALTH_MEGA].wait = 35
    IT[IT_HEALTH_MEGA].count = 100

    IT[IT_ARMOR_5].name = "Armor Shard"
    IT[IT_ARMOR_5].model = "models/items/item_q3_armorshard.mdl"
    IT[IT_ARMOR_5].type = ET_ITEM_ARMOR
    IT[IT_ARMOR_5].wait = 25
    IT[IT_ARMOR_5].count = 5
    
    IT[IT_KEY_SILVER].name = "Silver Key"
    IT[IT_KEY_SILVER].sound = "items/key_silver.wav"
    IT[IT_KEY_SILVER].model = "models/items/item_q3_key_silver.mdl"
    IT[IT_KEY_SILVER].type = ET_ITEM_KEY
    IT[IT_KEY_SILVER].wait = maxGameTime
    
    IT[IT_KEY_GOLD].name = "Gold Key"
    IT[IT_KEY_GOLD].sound = "items/key_gold.wav"
    IT[IT_KEY_GOLD].model = "models/items/item_q3_key_gold.mdl"
    IT[IT_KEY_GOLD].type = ET_ITEM_KEY
    IT[IT_KEY_GOLD].wait = maxGameTime
    
    IT[IT_KEY_MASTER].name = "Master Key"
    IT[IT_KEY_MASTER].sound = "items/key_gold.wav"
    IT[IT_KEY_MASTER].model = "models/items/item_q3_key_gold.mdl"
    IT[IT_KEY_MASTER].type = ET_ITEM_KEY
    IT[IT_KEY_MASTER].wait = maxGameTime

    IT[IT_QUAD].name = "Quad Damage"
    IT[IT_QUAD].sound = "items/damage3.wav"
    IT[IT_QUAD].voice = "quad_damage.wav"
    IT[IT_QUAD].model = "models/items/item_q3_quaddamage.mdl"
    IT[IT_QUAD].type = ET_ITEM_POWERUP
    IT[IT_QUAD].wait = 120
    IT[IT_QUAD].count = 30
    IT[IT_QUAD].icon = "file://{images}/ql/q.png"

    IT[IT_BATTLESUIT].name = "Battle Suit"
    IT[IT_BATTLESUIT].sound = "items/protect.wav"
    IT[IT_BATTLESUIT].voice = "battlesuit.wav"
    IT[IT_BATTLESUIT].model = "models/items/item_q3_battlesuit.mdl"
    IT[IT_BATTLESUIT].type = ET_ITEM_POWERUP
    IT[IT_BATTLESUIT].wait = 120
    IT[IT_BATTLESUIT].count = 30
    IT[IT_BATTLESUIT].icon = "file://{images}/ql/b.png"

    IT[IT_HASTE].name = "Haste"
    IT[IT_HASTE].sound = "items/guard.wav"
    IT[IT_HASTE].voice = "haste.wav"
    IT[IT_HASTE].model = "models/items/item_q3_haste.mdl"
    IT[IT_HASTE].type = ET_ITEM_POWERUP
    IT[IT_HASTE].wait = 120
    IT[IT_HASTE].count = 30
    IT[IT_HASTE].icon = "file://{images}/ql/h.png"

    IT[IT_INVIS].name = "Invisibility"
    IT[IT_INVIS].sound = "items/holdable.wav"
    IT[IT_INVIS].voice = "invisibility.wav"
    IT[IT_INVIS].model = "models/items/item_q3_invisibility.mdl"
    IT[IT_INVIS].type = ET_ITEM_POWERUP
    IT[IT_INVIS].wait = 120
    IT[IT_INVIS].count = 30
    IT[IT_INVIS].icon = "file://{images}/ql/i.png"

    IT[IT_REGEN].name = "Regeneration"
    IT[IT_REGEN].sound = "items/holdable.wav"
    IT[IT_REGEN].voice = "regeneration.wav"
    IT[IT_REGEN].model = "models/items/item_q3_regeneration.mdl"
    IT[IT_REGEN].type = ET_ITEM_POWERUP
    IT[IT_REGEN].wait = 120
    IT[IT_REGEN].count = 30
    IT[IT_REGEN].icon = "file://{images}/ql/r.png"
}

void setupWeaponSelectionPanel(){
    weaponSelectionPanel = new Panel()

    //we want to use up all the availavble bytes for an invisible item so the next options arent displayed
    weaponSelectionPanel.DrawItem("\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r"
    ,2)

    //add 9 options that can actually be selected
    weaponSelectionPanel.DrawItem("")
    weaponSelectionPanel.DrawItem("")
    weaponSelectionPanel.DrawItem("")
    weaponSelectionPanel.DrawItem("")
    weaponSelectionPanel.DrawItem("")
    weaponSelectionPanel.DrawItem("")
    weaponSelectionPanel.DrawItem("")
    weaponSelectionPanel.DrawItem("")
    weaponSelectionPanel.DrawItem("")
}

int weaponSelectionMenuHandler(Menu menu, MenuAction action, int client, int choice){
    if (action == MenuAction_Select){
        if(gamestate != GS_INTERMISSION){
            setDesiredWeapon(client,choice)
        }else{
            if(mapVoteWon == 0 && choice > 0 && choice <= 3 && choice != SD[client].mapVote && SD[client].lastMapVote + 1.0 < GetGameTime()){
                SD[client].mapVote = choice
                SD[client].lastMapVote = GetGameTime()
                PrintToChatAll("%N voted for %s.",client,mapvote[choice].nice_name)
                showMapVote()
            }
        }
        displayWeaponSelectionPanel(client)
    }

    return 0
}

void displayWeaponSelectionPanel(int client){
    weaponSelectionPanel.Send(client,weaponSelectionMenuHandler,-1)
}

void displayMainMenu(int client){
    menuMain.Display(client,-1)
    updateOverlay(client)
    updateAmmoText(client)
}

void setupSettingsMenus(){
    static char m[32]
    static int actions = MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End

    menuMain = new Menu(mainMenuHandler, actions)
    menuFOVSub = new Menu(mainMenuHandler, actions)
    menuFOVSelect = new Menu(mainMenuHandler, actions)
    menuFOVZoom = new Menu(mainMenuHandler, actions)
    menuFOVSmooth = new Menu(mainMenuHandler, actions)
    menuVoice = new Menu(mainMenuHandler, actions)
    menuColor = new Menu(mainMenuHandler, actions)
    menuColorEnemies = new Menu(mainMenuHandler, actions)
    menuColorRed = new Menu(mainMenuHandler, actions)
    menuColorBlue = new Menu(mainMenuHandler, actions)
    menuColorRailgun = new Menu(mainMenuHandler, actions)
    menuMisc = new Menu(mainMenuHandler, actions)
    menuLocation = new Menu(mainMenuHandler, actions)

    menuMain.SetTitle("Settings")
    IntToString(menuFOVSub,m,sizeof(m));menuMain.AddItem(m,"FOV Settings")
    IntToString(menuVoice,m,sizeof(m));    menuMain.AddItem(m,"Announcer Voice")
    IntToString(menuColor,m,sizeof(m));    menuMain.AddItem(m,"Colors")
    IntToString(menuMisc,m,sizeof(m));    menuMain.AddItem(m,"Misc")


    menuFOVSub.SetTitle("FOV Settings")
    IntToString(menuFOVSelect,m,sizeof(m));    menuFOVSub.AddItem(m,"FOV")
    IntToString(menuFOVZoom,m,sizeof(m));     menuFOVSub.AddItem(m,"Zoom FOV")
    IntToString(menuFOVSmooth,m,sizeof(m)); menuFOVSub.AddItem(m,"Zoom Transition")
    menuFOVSub.AddItem("","",ITEMDRAW_SPACER)
    menuFOVSub.AddItem("","",ITEMDRAW_SPACER)
    menuFOVSub.AddItem("","",ITEMDRAW_SPACER)
    IntToString(menuMain,m,sizeof(m));    menuFOVSub.AddItem(m,"Back",ITEMDRAW_CONTROL)
    menuFOVSub.Pagination = false
    menuFOVSub.ExitButton = true


    menuFOVSelect.SetTitle("FOV")
    menuFOVSelect.AddItem("0","Custom")
    menuFOVSelect.AddItem("130","130")
    menuFOVSelect.AddItem("120","120")
    menuFOVSelect.AddItem("110","110")
    menuFOVSelect.AddItem("100","100")
    menuFOVSelect.AddItem("90","90")
    IntToString(menuFOVSub,m,sizeof(m));    menuFOVSelect.AddItem(m,"Back",ITEMDRAW_CONTROL)
    menuFOVSelect.Pagination = false
    menuFOVSelect.ExitButton = true

    menuFOVZoom.SetTitle("Zoom FOV")
    menuFOVZoom.AddItem("0","Custom")
    menuFOVZoom.AddItem("70","70")
    menuFOVZoom.AddItem("60","60")
    menuFOVZoom.AddItem("50","50")
    menuFOVZoom.AddItem("40","40")
    menuFOVZoom.AddItem("30","30")
    IntToString(menuFOVSub,m,sizeof(m));    menuFOVZoom.AddItem(m,"Back",ITEMDRAW_CONTROL)
    menuFOVZoom.Pagination = false
    menuFOVZoom.ExitButton = true

    menuFOVSmooth.SetTitle("FOV Transition")
    menuFOVSmooth.AddItem("","Smooth")
    menuFOVSmooth.AddItem("","Instant")
    menuFOVSmooth.AddItem("","",ITEMDRAW_SPACER)
    menuFOVSmooth.AddItem("","",ITEMDRAW_SPACER)
    menuFOVSmooth.AddItem("","",ITEMDRAW_SPACER)
    menuFOVSmooth.AddItem("","",ITEMDRAW_SPACER)
    IntToString(menuFOVSub,m,sizeof(m));    menuFOVSmooth.AddItem(m,"Back",ITEMDRAW_CONTROL)
    menuFOVSmooth.Pagination = false
    menuFOVSmooth.ExitButton = true

    menuVoice.SetTitle("Announcer Voice")
    menuVoice.AddItem("","Default")
    menuVoice.AddItem("","Vadrigar")
    menuVoice.AddItem("","Daemia")
    menuVoice.AddItem("","",ITEMDRAW_SPACER)
    menuVoice.AddItem("","",ITEMDRAW_SPACER)
    menuVoice.AddItem("","",ITEMDRAW_SPACER)
    IntToString(menuMain,m,sizeof(m));    menuVoice.AddItem(m,"Back",ITEMDRAW_CONTROL)
    menuVoice.Pagination = false
    menuVoice.ExitButton = true

    menuColor.SetTitle("Colors")
    IntToString(menuColorEnemies,m,sizeof(m));    menuColor.AddItem(m,"Enemies")
    IntToString(menuColorRed,m,sizeof(m));     menuColor.AddItem(m,"Red Team")
    IntToString(menuColorBlue,m,sizeof(m)); menuColor.AddItem(m,"Blue Team")
    IntToString(menuColorRailgun,m,sizeof(m)); menuColor.AddItem(m,"Railgun Color")
    menuColor.AddItem("","",ITEMDRAW_SPACER)
    menuColor.AddItem("","",ITEMDRAW_SPACER)
    IntToString(menuMain,m,sizeof(m));    menuColor.AddItem(m,"Back",ITEMDRAW_CONTROL)
    menuColor.Pagination = false
    menuColor.ExitButton = true

    menuColorEnemies.SetTitle("Enemies Color")
    menuColorEnemies.AddItem("0","Custom")
    menuColorEnemies.AddItem("102 255 64","Green (Default)")
    menuColorEnemies.AddItem("204 51 51","Red")
    menuColorEnemies.AddItem("0 102 255","Blue")
    menuColorEnemies.AddItem("255 255 0","Yellow")
    menuColorEnemies.AddItem("255 0 255","Pink")
    IntToString(menuColor,m,sizeof(m));    menuColorEnemies.AddItem(m,"Back",ITEMDRAW_CONTROL)
    menuColorEnemies.Pagination = false
    menuColorEnemies.ExitButton = true

    menuColorRed.SetTitle("Team Red Color")
    menuColorRed.AddItem("0","Custom")
    menuColorRed.AddItem("204 51 51","Red (Default)")
    menuColorRed.AddItem("102 255 64","Green")
    menuColorRed.AddItem("0 102 255","Blue")
    menuColorRed.AddItem("255 255 0","Yellow")
    menuColorRed.AddItem("255 0 255","Pink")
    IntToString(menuColor,m,sizeof(m));    menuColorRed.AddItem(m,"Back",ITEMDRAW_CONTROL)
    menuColorRed.Pagination = false
    menuColorRed.ExitButton = true

    menuColorBlue.SetTitle("Team Red Color")
    menuColorBlue.AddItem("0","Custom")
    menuColorBlue.AddItem("0 102 255","Blue (Default)")
    menuColorBlue.AddItem("102 255 64","Green")
    menuColorBlue.AddItem("204 51 51","Red")
    menuColorBlue.AddItem("255 255 0","Yellow")
    menuColorBlue.AddItem("255 0 255","Pink")
    IntToString(menuColor,m,sizeof(m));    menuColorBlue.AddItem(m,"Back",ITEMDRAW_CONTROL)
    menuColorBlue.Pagination = false
    menuColorBlue.ExitButton = true

    menuColorRailgun.SetTitle("Railgun Color")
    menuColorRailgun.AddItem("0", "1 Bright Red")
    menuColorRailgun.AddItem("1", "2 Orange Red")
    menuColorRailgun.AddItem("2", "3 Tangerine")
    menuColorRailgun.AddItem("3", "4 Golden Yellow")
    menuColorRailgun.AddItem("4", "5 Lemon Yellow")
    menuColorRailgun.AddItem("5", "6 Lime Green")
    menuColorRailgun.AddItem("6", "7 Spring Green")
    menuColorRailgun.AddItem("7", "8 Mint Green")
    menuColorRailgun.AddItem("8", "9 Bright Green (Default)")
    menuColorRailgun.AddItem("9", "10 Sea Green")
    menuColorRailgun.AddItem("10","11 Turquoise")
    menuColorRailgun.AddItem("11","12 Sky Blue")
    menuColorRailgun.AddItem("12","13 Cyan")
    menuColorRailgun.AddItem("13","14 Azure")
    menuColorRailgun.AddItem("14","15 Royal Blue")
    menuColorRailgun.AddItem("15","16 Indigo")
    menuColorRailgun.AddItem("16","17 Bright Blue")
    menuColorRailgun.AddItem("17","18 Violet")
    menuColorRailgun.AddItem("18","19 Purple")
    menuColorRailgun.AddItem("19","20 Magenta")
    menuColorRailgun.AddItem("20","21 Fuchsia")
    menuColorRailgun.AddItem("21","22 Pink")
    menuColorRailgun.AddItem("22","23 Hot Pink")
    menuColorRailgun.AddItem("23","24 Coral")
    menuColorRailgun.AddItem("24","25 White")
    menuColorRailgun.AddItem("25","26 Gray")
    menuColorRailgun.ExitButton = true
    menuColorRailgun.ExitBackButton = true
    
    
    menuMisc.SetTitle("Misc")
    IntToString(menuLocation,m,sizeof(m)); menuMisc.AddItem(m,"Location Text")
    menuMisc.AddItem("","",ITEMDRAW_SPACER)
    menuMisc.AddItem("","",ITEMDRAW_SPACER)
    menuMisc.AddItem("","",ITEMDRAW_SPACER)
    menuMisc.AddItem("","",ITEMDRAW_SPACER)
    menuMisc.AddItem("","",ITEMDRAW_SPACER)
    IntToString(menuMain,m,sizeof(m));    menuMisc.AddItem(m,"Back",ITEMDRAW_CONTROL)
    menuMisc.Pagination = false
    menuMisc.ExitButton = true
    
    menuLocation.SetTitle("Location Text")
    menuLocation.AddItem("","Enable")
    menuLocation.AddItem("","Disable")
    menuLocation.AddItem("","",ITEMDRAW_SPACER)
    menuLocation.AddItem("","",ITEMDRAW_SPACER)
    menuLocation.AddItem("","",ITEMDRAW_SPACER)
    menuLocation.AddItem("","",ITEMDRAW_SPACER)
    IntToString(menuMisc,m,sizeof(m));    menuLocation.AddItem(m,"Back",ITEMDRAW_CONTROL)
    menuLocation.Pagination = false
    menuLocation.ExitButton = true
}

int mainMenuHandler(Menu menu, MenuAction action, int client, int choice){
    static char item[32]

    if(action == MenuAction_Display){
        SD[client].menuOpen = menu
    }

    if (action == MenuAction_Select){
        if(menu == menuFOVSelect){
            if(choice == 0){
                PrintToChat(client,"Check your Console")
                PrintToConsole(client,"Custom FOV\n\tuse command \"qfov <value>\"\n\tdefault: 100, min: 10, max: 130\n\texample: \"qfov 130\"")
                menu.Display(client,-1)
                  return 0
            }else if(choice != 6){    //not back button
                  menu.GetItem(choice, item, sizeof(item))
                  qfov(client,item)

                  menu.Display(client,-1)
                  return 0
            }
        }else if(menu == menuFOVZoom){
            if(choice == 0){
                PrintToChat(client,"Check your Console")
                PrintToConsole(client,"Custom Zoom FOV\n\tuse command \"qzoomfov <value>\"\n\tdefault: 60, min: 10, max: 130\n\texample: \"qzoomfov 40\"")
                menu.Display(client,-1)
                  return 0
            }else if(choice != 6){
                  menu.GetItem(choice, item, sizeof(item))
                  qfovzoom(client,item)

                  menu.Display(client,-1)
                  return 0
            }
        }else if(menu == menuFOVSmooth){
            if(choice == 0){
                SD[client].fovSmooth = true
                SetClientCookie(client,h_cookieFovSmooth,"1")

                  menu.Display(client,-1)
                  return 0
            }else if(choice == 1){
                SD[client].fovSmooth = false
                SetClientCookie(client,h_cookieFovSmooth,"0")

                  menu.Display(client,-1)
                  return 0
            }
        }else if(menu == menuVoice){
            if(choice != 6){
                if(choice == 0){
                    SD[client].voice = "vo"
                      SetClientCookie(client,h_cookieVoice,"vo")
                      EmitSoundToClient(client,"vo/excellent2.wav")
                      EmitSoundToClient(client,"vo/excellent2.wav")
                      EmitSoundToClient(client,"vo/excellent2.wav")
                }else if(choice == 1){
                    SD[client].voice = "vo_evil"
                      SetClientCookie(client,h_cookieVoice,"vo_evil")
                      EmitSoundToClient(client,"vo_evil/excellent2.wav")
                }else if(choice == 2){
                    SD[client].voice = "vo_female"
                      SetClientCookie(client,h_cookieVoice,"vo_female")
                      EmitSoundToClient(client,"vo_female/excellent2.wav")
                }

                  menu.Display(client,-1)
                  return 0
            }
        }else if(menu == menuColorEnemies){
            if(choice == 0){
                PrintToChat(client,"Check your Console")
                PrintToConsole(client,"Custom Enemy Color\n\tuse command \"qcolorenemies <r> <g> <b>\"\n\tdefault: \"102 255 64\", min: \"0 0 0\", max: \"255 255 255\"\n\texample: \"qcolorenemies 255 255 0\"")
                menu.Display(client,-1)
                  return 0
            }else if(choice != 6){
                  menu.GetItem(choice, item, sizeof(item))
                  qcolorenemies(client,item)

                  menu.Display(client,-1)
                  return 0
            }
        }else if(menu == menuColorRed){
            if(choice == 0){
                PrintToChat(client,"Check your Console")
                PrintToConsole(client,"Custom Team Red Color\n\tuse command \"qcolorteamred <r> <g> <b>\"\n\tdefault: \"204 51 51\", min: \"0 0 0\", max: \"255 255 255\"\n\texample: \"qcolorteamred 255 128 128\"")
                menu.Display(client,-1)
                  return 0
            }else if(choice != 6){
                  menu.GetItem(choice, item, sizeof(item))
                  qcolorteamred(client,item)

                  menu.Display(client,-1)
                  return 0
            }
        }else if(menu == menuColorBlue){
            if(choice == 0){
                PrintToChat(client,"Check your Console")
                PrintToConsole(client,"Custom Team Blue Color\n\tuse command \"qcolorteamblue <r> <g> <b>\"\n\tdefault: \"0 102 255\", min: \"0 0 0\", max: \"255 255 255\"\n\texample: \"qcolorteamblue 128 128 255\"")
                menu.Display(client,-1)
                  return 0
            }else if(choice != 6){
                  menu.GetItem(choice, item, sizeof(item))
                  qcolorteamblue(client,item)

                  menu.Display(client,-1)
                  return 0
            }
        }else if(menu == menuColorRailgun){
              menu.GetItem(choice, item, sizeof(item))
              SetClientCookie(client,h_cookieColorRailgun,item)
              SD[client].railColor = StringToInt(item)

              if(IsPlayerAlive(client)){
                  updateRailColors(client,SD[client].railColor)
              }

              menu.DisplayAt(client,6 * (choice / 6),-1)
              return 0
        }else if(menu == menuLocation){
            if(choice == 0){
                SetClientCookie(client,h_cookieLocation,"1")
                SD[client].locationEnabled = true
                
                menu.Display(client,-1)
                return 0
            }else if(choice == 1){
                SetClientCookie(client,h_cookieLocation,"0")
                SD[client].locationEnabled = false
                
                menu.Display(client,-1)
                return 0
            }
        }


        static char handle[32]
        static int h
          menu.GetItem(choice, handle, sizeof(handle))
          h = StringToInt(handle)

          if(h != 0){
              (view_as<Menu>(h)).Display(client,-1)
          }else{
              menu.Display(client,-1)
          }

    }else if (action == MenuAction_Cancel){
        if(choice == MenuCancel_Exit){
            endMenus(client)
        }else if(choice == MenuCancel_ExitBack){    //manually return from paginated menus
            if(menu == menuColorRailgun){
                menuColor.Display(client,-1)
            }else{
                menuMain.Display(client,-1)
                print("mainmenu MenuCancel_ExitBack")
            }
        }

        PrintHintText(client,"")
    }

    return 0
}

void endMenus(int client){
    SD[client].menuOpen = 0
    updateOverlay(client)
    updateAmmoText(client)
    displayWeaponSelectionPanel(client)
}

void setupCookies(){
    h_cookieFov = RegClientCookie("qlgo_fov","FOV",CookieAccess_Private)
    h_cookieFovZoom = RegClientCookie("qlgo_fovzoom","Zoom FOV",CookieAccess_Private)
    h_cookieFovSmooth = RegClientCookie("qlgo_fovsmooth","FOV Transition",CookieAccess_Private)
    h_cookieVoice = RegClientCookie("qlgo_voice","Announcer Voice",CookieAccess_Private)
     h_cookieColorEnemies = RegClientCookie("qlgo_colorenemies","Color Enemies",CookieAccess_Private)
     h_cookieColorTeamRed = RegClientCookie("qlgo_colorteamred","Color Team Red",CookieAccess_Private)
     h_cookieColorTeamBlue = RegClientCookie("qlgo_colorteamblue","Color Team Blue",CookieAccess_Private)
     h_cookieColorRailgun = RegClientCookie("qlgo_colorrailgun","Color Railgun",CookieAccess_Private)
     h_cookieLocation = RegClientCookie("qlgo_location","Enable location text",CookieAccess_Private)
}

//https://github.com/sneak-it/Normalized-Run-Speed/blob/master/scripting/runspeed.sp
void setupRunspeed(){
    Handle gamedata = LoadGameConfigFile("runspeed.games")

        if (gamedata != null) {
            int offset = GameConfGetOffset(gamedata, "GetPlayerMaxSpeed");
            CloseHandle(gamedata)

            if (offset != -1) {
                h_getPlayerMaxSpeed = DHookCreate(offset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, hook_getMaxPlayerSpeed)
            }
        }
}

MRESReturn hook_getMaxPlayerSpeed(int client, Handle hReturn){
    if (!IsClientInGame(client) || !IsPlayerAlive(client)){
        return MRES_Ignored
    }

    static float speed
    static int onground
    static bool crouching
    static bool walking
    static int waterlevel

    speed = 320.0

    crouching = GetEntProp(client,Prop_Send,"m_bDucked")
    walking = GetEntProp(client,Prop_Send,"m_bIsWalking")
    waterlevel = GetEntProp(client,Prop_Send,"m_nWaterLevel")
    onground = GetEntityFlags(client) & FL_ONGROUND != 0

    if(hasPowerup(client,PW_HASTE)){
        speed *= 1.3
    }

    if(waterlevel > 1 && !onground){
        if(crouching){
            speed *= 1.5    //somehow cant get faster than 130
        }else{
            speed *= 0.745    //190
        }

        DHookSetReturn(hReturn, speed)
        return MRES_Supercede
    }

    if(crouching){
        speed *= 0.735    //80
    }

    if(walking){
        speed *= 1.7    //~160
    }

    DHookSetReturn(hReturn, speed)
    return MRES_Supercede
}

void setupStringtableIndexes(){
     particleTable = FindStringTable("ParticleEffectNames")
     effectDispatchTable = FindStringTable("EffectDispatch")
     decalPrecacheTable  = FindStringTable("decalprecache")

    if (particleTable == -1 || effectDispatchTable == -1 || decalPrecacheTable == -1){
        print("Error finding some String table. Trying anyways...")
    }

    static char name[256]
    static char find[256]

    int count = GetStringTableNumStrings(effectDispatchTable)
    for (int i = 0; i < count; i++){
       ReadStringTable(effectDispatchTable, i, name, sizeof(name))
       if(StrEqual(name, "csblood")){
               csbloodEffectIndex = i
       }

       if(StrEqual(name, "ParticleEffect")){
               particleEffectIndex = i
       }

    }

    count = GetStringTableNumStrings(particleTable)
    for (int i = 0; i < count; i++){
        ReadStringTable(particleTable, i, name, sizeof(name))

        if(StrEqual(name,"hit")){
            particle_hit = i
            continue
        }

        if(StrEqual(name,"rlboom")){
            particle_rlboom = i
            continue
        }

        for(int x = 0; x < 10; x++){    //this can probably be done better but this is only done once per map change so whatever...

            Format(find,sizeof(find),"hitnums_%i_white",x)
            if(StrEqual(name,find)){
                hitnums_white[x] = i
                break;
            }

            Format(find,sizeof(find),"hitnums_%i_pink",x)
            if(StrEqual(name,find)){
                hitnums_pink[x] = i
                break;
            }

            Format(find,sizeof(find),"hitnums_%i_red",x)
            if(StrEqual(name,find)){
                hitnums_red[x] = i
                break;
            }

        }
    }
}

void addMapcontentToDownloadTable(){
    char path[128]
    Format(path,sizeof(path),"maps/info/%s_assets.txt",currentMap)

    File file = OpenFile(path,"r",true,"GAME")
    if(!file){
        delete file
        return
    }

    char buf[256]
    while(ReadFileLine(file,buf,sizeof(buf))){
        TrimString(buf)

        if(StrContains(buf,".vmt",false) != -1){
            for(int i = 0;buf[i];i++){
                buf[i] = CharToLower(buf[i])
            }
        }

        AddFileToDownloadsTable(buf)
    }

    delete file
}

void precacheCustomAssets(){
    //manually precache stuff used in code, custom stuff will still be in assets_general.txt for fastdl
    PrecacheGeneric("particles/quake.pcf", true)
    PrecacheModel("models/error.mdl", true)


    //debugLaserSprite = PrecacheModel("materials/sprites/laser.vmt")
    railLaserSprite = PrecacheModel("materials/gfx/misc/railcorethin_mono.vmt",true)
    lightningSprite = PrecacheModel("materials/sprites/lightning3new.vmt",true)
    PrecacheModel("materials/sprites/q3/plasmaa.vmt", true)

    //vmt's will not be automatically precached
    //precache weapon decals
    for(int i = 0;i< sizeof(WPN);i++){
        if(strlen(WPN[i].decal) > 0){
            PrecacheModel(WPN[i].decal,true)
        }
    }




    //automatically precache from file
    File file = OpenFile("maps/info/assets_general.txt","r",true,"GAME")
    char buf[256]

    if(!file){
        delete file
        return
    }

    while(ReadFileLine(file,buf,sizeof(buf))){
        TrimString(buf)
        if(buf[0] == ';' || buf[0] == '\0'){
            continue
        }

        if(StrContains(buf,".vmt",false) != -1){
            for(int i = 0;buf[i];i++){
                buf[i] = CharToLower(buf[i])
            }
        }

        AddFileToDownloadsTable(buf)

        if(StrContains(buf,".mdl",false) != -1){
            PrecacheModel(buf,true)
        }

        if(StrContains(buf,".wav",false) != -1 || StrContains(buf,".mp3",false) != -1){
            ReplaceString(buf,sizeof(buf),"sound/","",false)
            PrecacheSound(buf,true)
        }
    }

    delete file
}

void printVector(float vec[3],const char[] str = "vector"){
    print("%s: [%f %f %f]",str,vec[0],vec[1],vec[2])
}

//https://github.com/Franc1sco/FixHintColorMessages/blob/master/FixHintColorMessages.sp#L80
void printHintTextHTML(int client,const char[] text){    
    static char buf[2048]
    static int c[1]

    c[0] = client
    buf[0] = 0

    Protobuf msg = view_as<Protobuf>(StartMessageEx(usermsg_textmsg, c, sizeof(c), USERMSG_RELIABLE|USERMSG_BLOCKHOOKS))

    if(!msg){
        return
    }

    msg.SetInt("msg_dst", 4)
    msg.AddString("params", "#SFUI_ContractKillStart")

    Format(buf, sizeof(buf), "</font>%s<script>", text)
    msg.AddString("params", buf);
    msg.AddString("params", NULL_STRING)
    msg.AddString("params", NULL_STRING)
    msg.AddString("params", NULL_STRING)

    EndMessage()
}

void showFunfact(int client,const char[] text){
    if(!IsClientInGame(client) || IsFakeClient(client)){
        return
    }
    
    Event e = CreateEvent("cs_win_panel_round",true)
    e.SetString("funfact_token", text)
    e.BroadcastDisabled = true
    e.FireToClient(client)
    e.Cancel()
}

void showFunfactAll(const char[] text){
    Event e = CreateEvent("cs_win_panel_round",true)
    e.SetString("funfact_token", text)
    
    for(int i = 1;i<=MaxClients;i++){
        if(IsClientInGame(i) && !IsFakeClient(i)){
            e.FireToClient(i)
        }
    }
    
    e.Cancel()
}

void showStatus(int client,const char[] text,int duration = 1){
    if(!IsClientInGame(client) || IsFakeClient(client)){
        return
    }

    Event e = CreateEvent("show_survival_respawn_status", true)
    e.SetString("loc_token", text)
    e.BroadcastDisabled = true
    e.SetInt("duration", duration)
    e.SetInt("userid", -1)

    e.FireToClient(client)
    e.Cancel()
}

void showStatusAll(const char[] text,int duration = 5){
    Event e = CreateEvent("show_survival_respawn_status", true)
    e.SetString("loc_token", text)
    e.SetInt("duration", duration)
    e.SetInt("userid", -1)

    e.Fire()
}