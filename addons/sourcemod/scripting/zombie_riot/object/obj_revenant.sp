#pragma semicolon 1
#pragma newdecls required

static int NPCId;

void ObjectRevenant_Setup()
{
	PrecacheModel("models/items/crystal_ball_pickup_major.mdl");

	NPCData data;
	strcopy(data.Name, sizeof(data.Name), "Revenant's Shadow");
	strcopy(data.Plugin, sizeof(data.Plugin), "obj_revenant");
	strcopy(data.Icon, sizeof(data.Icon), "");
	data.IconCustom = false;
	data.Flags = 0;
	data.Category = Type_Hidden;
	data.Func = ClotSummon;
	NPCId = NPC_Add(data);
}

static any ClotSummon(int client, float vecPos[3], float vecAng[3])
{
	return ObjectRevenant(client, vecPos, vecAng);
}

methodmap ObjectRevenant < ObjectGeneric
{
	public void PlayShootSound() 
	{
		EmitSoundToAll("weapons/capper_shoot.wav", this.index, SNDCHAN_AUTO, 80, _, 0.8, 100);
	}
	public ObjectRevenant(int client, const float vecPos[3], const float vecAng[3])
	{
		ObjectRevenant npc = view_as<ObjectRevenant>(ObjectGeneric(client, vecPos, vecAng, "models/items/crystal_ball_pickup_major.mdl", _, "50", {15.0, 15.0, 34.0}, _, false));
		
		npc.FuncCanBuild = ClotCanBuild;
		func_NPCThink[npc.index] = ClotThink;

		return npc;
	}
}

public bool ObjectRevenant_CanBuild(int client, int &count, int &maxcount)
{
	if(client)
	{
		count = ObjectBarricade_Buildings(client) + ObjectRevenant_Buildings(client);
		maxcount = 4;
		if(i_NormalBarracks_HexBarracksUpgrades_2[client] & ZR_BARRACKS_TROOP_CLASSES)
			maxcount = 1;

		if(count >= maxcount)
			return false;
	}
	
	return true;
}

int ObjectRevenant_Buildings(int owner)
{
	int count;
	
	int entity = -1;
	while((entity=FindEntityByClassname(entity, "obj_building")) != -1)
	{
		if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == owner)
		{
			if(NPCId == i_NpcInternalId[entity])
				count++;
		}
	}

	return count;
}

static bool ClotCanBuild(int client, int &count, int &maxcount)
{
	return false;
}

static void ClotThink(ObjectRevenant npc)
{
	int Owner = GetEntPropEnt(npc.index, Prop_Send, "m_hOwnerEntity");
	if(!IsValidClient(Owner))
	{
		return;
	}

	float gameTime = GetGameTime(npc.index);
	if(npc.m_flNextMeleeAttack > gameTime)
		return;
	
	float distance = 800.0 * Attributes_GetOnPlayer(Owner, 344, true, true);

	int target = GetClosestTarget(npc.index, _, distance, .CanSee = true, .UseVectorDistance = true);
	if(IsValidEnemy(npc.index, npc.m_iTarget))
	{
		Handle swingTrace;

		if(npc.DoSwingTrace(swingTrace, target, { 9999.0, 9999.0, 9999.0 }))
		{
			target = TR_GetEntityIndex(swingTrace);
			
			if(IsValidEnemy(npc.index, target))
			{
				float vecHit[3];
				TR_GetEndPosition(vecHit, swingTrace);
				float origin[3];
				float angles[3];
				view_as<CClotBody>(npc.index).GetAttachment("spelleffect_major", origin, angles);
				ShootLaser(npc.index, "bullet_tracer01_red", origin, vecHit, false);
				
				npc.PlayShootSound();

				float damageDealt = 250.0;
				damageDealt *= Attributes_GetOnPlayer(Owner, 287, true, true);
				if(ShouldNpcDealBonusDamage(target))
				{
					damageDealt *= 3.0;
				}
				else if(!b_NpcHasDied[target])
				{
					float duration = GetGameTime() + 1.0;
					if(duration > f_MaimDebuff[target])
						f_MaimDebuff[target] = duration;
					
					if(i_HowManyBombsOnThisEntity[target][Owner] < 1)
					{
						f_BombEntityWeaponDamageApplied[target][Owner] += damageDealt * 8.4;
						i_HowManyBombsOnThisEntity[target][Owner] += 1;
						i_HowManyBombsHud[target] += 1;
						Apply_Particle_Teroriser_Indicator(target);
					}
				}

				SDKHooks_TakeDamage(target, npc.index, Owner, damageDealt, DMG_SHOCK, -1, _, vecHit);
			}
		}

		delete swingTrace;
	}

	npc.m_flNextMeleeAttack = gameTime + (GetRandomFloat(3.0, 5.0) * Attributes_GetOnPlayer(Owner, 343, true, true));
}