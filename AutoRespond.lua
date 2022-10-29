--[[----------------------------------------------
Autorespond created by Ayradyss in the first and enhanced by Chef de Loup

The features of the mod in the following:
- multiply responses with multiply keywords for each response
- responses can be handled as text with links or as script code
- several controls for each response for input and output of a response
--]]-----------------------------------------------

--[[-----------------------------------------------
Backdrops
--]]-----------------------------------------------
BACKDROP_AUTO_RESPONSE_FRAME = {
    bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileEdge = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
};

--[[-----------------------------------------------
global variables
--]]-----------------------------------------------
AutoRespondMainOptions = {}; -- SavedVariable - MainOptions
AutoRespondOptions = {}; -- SavedVariable - Responds and Options


local Realm; -- realm of active player
local Player; -- name of active player

local getglobal = getglobal; -- Speed up ggvar

local VariablesLoaded = 1; -- flag to check if Variables was loaded
local Initialized = nil; -- flag to check if previous initialize

local ActiveOption = 1; -- position of actual respond
local AR_Version = "1.0.0 Reborn"; -- version of AR

local AR_SpamCheck = nil; -- status of spamcheck
local AR_SpamList = {}; -- each entry consists of the name of the whisperer and the time of the last whisper

--[[--------------------------------------------------------------------------------------------
functions for the main frame
--]]--------------------------------------------------------------------------------------------


--[[-----------------------------------------------
function for registering main events and slashcommands of the mod
--]]-----------------------------------------------
function AutoRespond_OnLoad(event, self)
	-- register main events
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("PLAYER_LEAVING_WORLD");
	self:RegisterEvent("VARIABLES_LOADED");

	-- register slashcommand and handler function
	SlashCmdList["AUTORESPOND"] = AutoRespond_SlashHandler;
	SLASH_AUTORESPOND1 = "/AutoRespond";
	SLASH_AUTORESPOND2 = "/ar";
	
	VariablesLoaded = 1;
	AutoRespond_InitializeSetup();
end


--[[-----------------------------------------------
function for initializing the mod
this function only works once when all needed variables are loaded
--]]-----------------------------------------------
function AutoRespond_InitializeSetup()
	-- check if previous initialized or variables are not loaded
	if not Initialized and VariablesLoaded then
		-- get realm and playername
		Player = UnitFullName("player");
		Realm = GetRealmName();
	
		-- initialize SavedVariables if not given
		if AutoRespondMainOptions[Realm] == nil then AutoRespondMainOptions[Realm] = {}; end
		if AutoRespondMainOptions[Realm][Player] == nil then
			AutoRespondMainOptions[Realm][Player] = { ActiveMod = 1, InFight = nil, Scaling = 1.0, SpamCheck = nil, SpamTimer = 60.0 };
		end
		
		if(AutoRespondOptions[Realm] == nil) then AutoRespondOptions[Realm] = {}; end
		if(AutoRespondOptions[Realm][Player] == nil) then 
			AutoRespondOptions[Realm][Player] = {};
			table.insert( AutoRespondOptions[Realm][Player],{ Active = nil, Script = nil, Keywords = {AUTO_RESPOND_DEFAULT_KEYWORD_TEXT}, Response = {AUTO_RESPOND_DEFAULT_RESPONSE_TEXT}, Options = { Receive = { Guild = nil, Party = nil, Raid = nil, Friends = nil, Names = {} }, Tell = { Guild = nil, Party = nil, Raid = nil } } } );
		end
	
		-- secure function for hooking 
		hooksecurefunc("SetItemRef",AutoRespond_SetItemRef)
		
		AutoRespondFrame:SetScale(AutoRespondMainOptions[Realm][Player]["Scaling"]);
		
		-- Loaded Message
		--DEFAULT_CHAT_FRAME:AddMessage(string.format(AUTO_RESPOND_LOADED_TEXT,AR_Version));
		
		Initialized = 1;
	end
	
	if VariablesLoaded and AutoRespondMainOptions[Realm][Player]["ActiveMod"] then
		AutoRespondFrame:RegisterEvent("CHAT_MSG_WHISPER")	
		AutoRespondFrame:RegisterEvent("CHAT_MSG_BN_WHISPER")
		AutoRespondFrame:SetScript("OnEvent", AutoRespond_whispHandler);
	end
end


--[[-----------------------------------------------
functions for handling the whisper
--]]-----------------------------------------------
function AutoRespond_whispHandler(_, event, msg, sender, _, _, _, status)
    if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
        local formatSenderApos = sender:gsub("%'", "") -- remove ' in realm name, if any
        local formatSenderSpc = sender:gsub(" ", "") -- remove space in realm name, if any
        --print(formatSenderSpc, formatSenderApos);
            
        if status == "GM" then
            DEFAULT_CHAT_FRAME:AddMessage("::: AutoRespond ::: GM MESSAGE DETECTED, NOT REPLYING"); -- Don't want to be auto replying and such to a GM
        else
            if AutoRespondMainOptions[Realm][Player]["InFight"] and UnitAffectingCombat("player") then
                SendChatMessage(AUTO_RESPOND_DEFAULT_INFIGHT_MESSAGE, "WHISPER", GetDefaultLanguage("player"), sender);
            else
                local respond_id = AutoRespond_CheckMessage(msg, 1);
                
                if not AutoRespond_SpamCheck(sender, respond_id) then
                    while respond_id do
                        AutoRespond_SendRespond(sender, respond_id);
                        respond_id = AutoRespond_CheckMessage(msg, respond_id+1);
                    end
                end
            end
        end
    end
end
--[[--------------------------------------------------------------------------------------------
system functions for the mod
--]]--------------------------------------------------------------------------------------------

--[[-----------------------------------------------
hook function for getting links from chat links 
Parameter:
	link - the link of the item as itemid
	text - the link as text
	button - identifier of the button that was pressed 
--]]-----------------------------------------------
function AutoRespond_SetItemRef(link,text,button)
	-- check if you should include the link in responsetext
	if ( IsShiftKeyDown() ) and ( AutoRespondFrame:IsVisible() ) then
		AutoRespondFrame_ResponseFrame_ScrollFrameResponse_ListResponse:Insert(text);
	end
end


--[[-----------------------------------------------
slashhandler of the addon
Parameter:
	msg - the message that was given with the slashcommand
--]]-----------------------------------------------
function AutoRespond_SlashHandler(msg)
	if string.find(msg,"options") then
		AutoRespondOptionsFrame:Show();
	else
		-- none of these above then just show the mainframe of the mod
		AutoRespondFrame:Show();
	end
end


--[[--------------------------------------------------------------------------------------------
functions for the responses
--]]--------------------------------------------------------------------------------------------


--[[-----------------------------------------------
function for checking of spam by time
the function looks through the spam list and clears out-dated entries
Parameter:
	who - the name of the whisperer
	id - id of the response if found
Return
	returns nil if whisperer is not spamming else 1 to stop sending respond
--]]-----------------------------------------------
function AutoRespond_SpamCheck(who,id)
	local ret,timer = nil,AutoRespondMainOptions[Realm][Player]["SpamTimer"];
	if AutoRespondMainOptions[Realm][Player]["SpamCheck"] and id then
		for i,k in ipairs(AR_SpamList) do
			if GetTime() - k["Time"] >= timer then
				table.remove(AR_SpamList,i);
			else
				if k["Name"] == who then
					ret = 1;
					k["Time"] = GetTime();
				end
			end
		end
		if not ret then
			local w,t = who,GetTime();
			table.insert( AR_SpamList, { Name = w,Time = t } );
		end
	end
	return ret;
end


--[[-----------------------------------------------
function for checking the whisper to get a response to
Parameter:
	what - the message that was given in the whisper
	index - the index of the response to start from searching
Return
	returns the index of a response that have a matching keyword to the whispered text
	the returned index could be the value of the passed index or higher
	if no match can be found the return value will be nil
--]]-----------------------------------------------
function AutoRespond_CheckMessage(what,index)
	local t = AutoRespondOptions[Realm][Player]; 
	
	-- start at given respondindex until last respond
	for i=index,getn(t) do
		-- respond is active?
		if t[i]["Active"] then
			-- check if keyword(s) is found in whisper
	    for k,v in ipairs(t[i]["Keywords"]) do
				if string.find(string.lower(what), string.lower(v), 1, true) then
					-- return immediately with index of matched respond 
					return i;
				end
			end
		end
	end
	return nil;
end


--[[-----------------------------------------------
function for checking the whisper options
these options verify if the originator of the whisper is allowed to get the response
Parameter:
	who - the originator of the whisper
	index - the index of the response to start from
Return:
	nil - the originator should not get this response
	1 - response can be send
--]]-----------------------------------------------
function AutoRespond_CheckCan(who,index)
	local skip,restrict = nil,nil;
	local t = AutoRespondOptions[Realm][Player][index]["Options"]["Receive"];

	-- check for given names
	if t["Names"] then
	    for i,v in ipairs(t["Names"]) do
			if string.lower(v) == string.lower(who) then
			    skip = 1;
			end
		end
		restrict = 1;
	end

	-- check for group restriction
	if t["Party"] and not skip then
		for i=1,GetNumPartyMembers() do
			if UnitName("party"..i) == who then
				skip = 1;
			end
		end
		restrict = 1;
	end

	-- check for raid restriction
	if t["Raid"] and not skip then
		for i=1,GetNumRaidMembers() do
			if UnitName("raid"..i) == who then
				skip = 1;
			end
		end
		restrict = 1;
	end

	-- check for friends restriction
	if t["Friends"] and not skip then
		for i=1,GetNumFriends() do
			if GetFriendInfo(i) == who then
				skip = 1;
			end
		end
		restrict = 1;
	end

	-- check for guild restriction
	if t["Guild"] and not skip then
		for i=1, GetNumGuildMembers(true) do
			if GetGuildRosterInfo(i) == who then
				skip = 1;
			end
		end
		restrict = 1;
	end

	if not restrict then
	    return 1;
	else 
		return skip;
	end
end


--[[-----------------------------------------------
function for getting the response of a respond
Parameter: 
	index - the index of the respond the get the response from
Return:
	returns the response or nil if no response is available
--]]-----------------------------------------------
function AutoRespondgetglobaletResponse(index)
	local t = nil;
	if(AutoRespondOptions[Realm][Player][index]["Response"]) then
		t = AutoRespondOptions[Realm][Player][index]["Response"];
	end
	return t;
end


--[[-----------------------------------------------
function for responding
Parameter: 
	who - the name of the originator to respond to
	index - the index of the respond
--]]-----------------------------------------------
function AutoRespond_SendRespond(who,index)
	local formatSender = who:gsub("%'", "\\'") -- remove ' in realm name, if any (hopefully)
	-- check restrictions for originator
	if AutoRespond_CheckCan(formatSender,index) then
		local t = AutoRespondgetglobaletResponse(index);
		if t then
			-- if response is a script then use RunScript() else response by SendChatMessage()
			if AutoRespondOptions[Realm][Player][index]["Script"] then
		    for i=1,getn(t) do
		   	   RunScript(string.gsub(t[i],"$t","'"..formatSender.."'"));
		    end
			else
				local channel,receiver = "WHISPER",who;
				if AutoRespondOptions[Realm][Player][index]["Options"]["Tell"]["Guild"] then
					channel = "GUILD";
					receiver = nil;
				elseif AutoRespondOptions[Realm][Player][index]["Options"]["Tell"]["Party"] then
					channel = "PARTY";
					receiver = nil;
				elseif AutoRespondOptions[Realm][Player][index]["Options"]["Tell"]["Raid"] then
					channel = "RAID";
					receiver = nil;
				end
				for i=1,getn(t) do
					if receiver == UnitName("player") then
						DEFAULT_CHAT_FRAME:AddMessage("::: AutoRespond ::: "..string.gsub(t[i],"$t",formatSender));
					else
						SendChatMessage(string.gsub(t[i],"$t",formatSender), channel, GetDefaultLanguage("player"), receiver);
					end
				end
			end
		end
	end
end

--[[-----------------------------------------------
function to save the keyword(s) for the response
--]]-----------------------------------------------
function AutoRespond_SaveKeywords()
	local text = AutoRespondFrame_ResponseFrame_ListKeywords:GetText();
	if ActiveOption > 0 then
		if AutoRespondOptions[Realm][Player][ActiveOption] then
			-- delete old keywords
			if AutoRespondOptions[Realm][Player][ActiveOption]["Keywords"] then
				while getn(AutoRespondOptions[Realm][Player][ActiveOption]["Keywords"]) > 0 do
					table.remove(AutoRespondOptions[Realm][Player][ActiveOption]["Keywords"]);
				end
			end
			AutoRespondOptions[Realm][Player][ActiveOption]["Keywords"] = {};
			
			-- check if text is given
			if text and (text ~= "") then
				for keyword in string.gmatch(text, "[^,]+") do
					AutoRespond_SaveToTable(strtrim(keyword), AutoRespondOptions[Realm][Player][ActiveOption]["Keywords"])
				end
			end
		end
	end
end


--[[-----------------------------------------------
function to update the visible keywords
--]]-----------------------------------------------
function AutoRespond_UpdateKeywords()
	local text = "";
	if ActiveOption > 0 then
		if AutoRespondOptions[Realm][Player][ActiveOption] and AutoRespondOptions[Realm][Player][ActiveOption]["Keywords"] then
			local max = getn(AutoRespondOptions[Realm][Player][ActiveOption]["Keywords"]);
			for i,v in ipairs(AutoRespondOptions[Realm][Player][ActiveOption]["Keywords"]) do
				text = text..v;
				if i < max then
					text = text..", ";
				end
			end
		end
	end
	AutoRespondFrame_ResponseFrame_ListKeywords:SetText(text);
end


--[[-----------------------------------------------
function setting the usability of the ButtonListKeywords
--]]-----------------------------------------------
function AutoRespond_UpdateButtonListKeywords()
	if ActiveOption == 0 then
		AutoRespondFrame_ResponseFrame_ButtonListKeywords:Disable();
	else
		AutoRespondFrame_ResponseFrame_ButtonListKeywords:Enable();
	end
end


--[[-----------------------------------------------
function for saving the response text
--]]-----------------------------------------------
function AutoRespond_SaveResponse()
	local text = AutoRespondFrame_ResponseFrame_ScrollFrameResponse_ListResponse:GetText();
	if ActiveOption > 0 then
		if AutoRespondOptions[Realm][Player][ActiveOption] then
			-- delete old response
			if AutoRespondOptions[Realm][Player][ActiveOption]["Response"] then
				while getn(AutoRespondOptions[Realm][Player][ActiveOption]["Response"]) > 0 do
					table.remove(AutoRespondOptions[Realm][Player][ActiveOption]["Response"]);
				end
			end
			AutoRespondOptions[Realm][Player][ActiveOption]["Response"] = {};
			
			if text and text~="" then
				for line in string.gmatch(text, "[^\r\n]+") do
					AutoRespond_SaveToTable(line,AutoRespondOptions[Realm][Player][ActiveOption]["Response"]);
				end
			end
		end
	end
end


--[[-----------------------------------------------
function for saving text in a table
Parameter:
	text - the text to save
	var - the table to save to
--]]-----------------------------------------------
function AutoRespond_SaveToTable(text,var)
	if text and (text ~= "") then
		table.insert(var,text);
	end
end


--[[-----------------------------------------------
function to update the visible response
--]]-----------------------------------------------
function AutoRespond_UpdateResponse()
	local text = "";
	if ActiveOption > 0 then
		if AutoRespondOptions[Realm][Player][ActiveOption] and AutoRespondOptions[Realm][Player][ActiveOption]["Response"] then
			local max = getn(AutoRespondOptions[Realm][Player][ActiveOption]["Response"]);
			for i,v in ipairs(AutoRespondOptions[Realm][Player][ActiveOption]["Response"]) do
				 text = text..v;
				 if i < max then
			     	 text = text.."\n";
				 end
			end
		end
	end
	AutoRespondFrame_ResponseFrame_ScrollFrameResponse_ListResponse:SetText(text);
end

function AutoRespond_UpdateButtonListResponse()
	if ActiveOption == 0 then
		AutoRespondFrame_ResponseFrame_ButtonListResponse:Disable();
	else
		AutoRespondFrame_ResponseFrame_ButtonListResponse:Enable();
	end
end


--[[-----------------------------------------------
functions for the link button
--]]-----------------------------------------------
function AutoRespond_ButtonAddLinkOnShow()
	if ActiveOption == 0 then
		AutoRespondFrame_ResponseFrame_ButtonAddLink:Disable();
	else
		AutoRespondFrame_ResponseFrame_ButtonAddLink:Enable();
	end
end

function AutoRespond_ButtonAddLinkOnClick()
	if CursorHasItem() then
		for i=0,4 do
			if GetBagName(i) then
				for j=1, GetContainerNumSlots(i) do
					local _,_,locked = GetContainerItemInfo(i,j);
					if locked and GetContainerItemLink(i,j) then
						AutoRespondFrame_ResponseFrame_ScrollFrameResponse_ListResponse:Insert(GetContainerItemLink(i,j));
						SetCursor(nil);
						return;
					end
				end
			end
		end
		SetCursor(nil);
	end
	
	local temp = C_TradeSkillUI.GetTradeSkillLine(1);

	if temp then
		-- Link selected item
		local index = GetTradeSkillSelectionIndex();
		if (index) and (index < GetNumTradeSkills()) then
			local link = GetTradeSkillItemLink(index);
			if link then
				AutoRespondFrame_ResponseFrame_ScrollFrameResponse_ListResponse:Insert(link);
			else
				-- Link Profession when all of the selections are minimized
				local skillWindow = GetTradeSkillListLink();
				if skillWindow then
					AutoRespondFrame_ResponseFrame_ScrollFrameResponse_ListResponse:Insert(skillWindow);
				end
			end
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage(AUTO_RESPOND_NO_LINK_ITEM); -- Can't find anything so error out
	end
end


--[[-----------------------------------------------
functions for the reagent button
--]]-----------------------------------------------
function AutoRespond_ButtonAddReagentOnShow()
	if ActiveOption == 0 then
		AutoRespondFrame_ResponseFrame_ButtonAddReagent:Disable();
	else
		AutoRespondFrame_ResponseFrame_ButtonAddReagent:Enable();
	end
end

function AutoRespond_ButtonAddReagentOnClick()
	local text = "";
	if C_TradeSkillUI.GetTradeSkillLine(1) then
		local index = TradeSkillFrame.RecipeList:GetSelectedRecipeID();
		
		if (index) then
			for i=1, C_TradeSkillUI.GetRecipeNumReagents(index) do
				local _,_,num = C_TradeSkillUI.GetRecipeReagentInfo(index, i);
				text = text..num.."x"..C_TradeSkillUI.GetRecipeReagentItemLink(index,i)..";";
			end
		end
		
	else
		local index = TradeSkillFrame and TradeSkillFrame.RecipeList:GetSelectedRecipeID();
		
    	if (index) and (index < GetNumTradeSkills()) then
		    for i=1,GetTradeSkillNumReagents(index), 1 do
		   		local _,_,num = GetTradeSkillReagentInfo(index, i);
				text = text..num.."x"..GetTradeSkillReagentItemLink(index, i)..";";
			end
		end
		
	end
	
	if text ~= "" then
		AutoRespondFrame_ResponseFrame_ScrollFrameResponse_ListResponse:Insert(text);
	end
end


--[[--------------------------------------------------------------------------------------------
functions for the options of the response
--]]--------------------------------------------------------------------------------------------


--[[-----------------------------------------------
functions for the active-option of the response
--]]-----------------------------------------------
function AutoRespond_UpdateActive()
	if ActiveOption == 0 then
		AutoRespondFrame_OptionsFrame_ButtonActive:Disable();
	else
		AutoRespondFrame_OptionsFrame_ButtonActive:Enable();
		AutoRespondFrame_OptionsFrame_ButtonActive:SetChecked(AutoRespondOptions[Realm][Player][ActiveOption]["Active"]);
	end
end

function AutoRespond_ToggleActive()
	AutoRespondOptions[Realm][Player][ActiveOption]["Active"] = AutoRespondFrame_OptionsFrame_ButtonActive:GetChecked();
end


--[[-----------------------------------------------
functions for the script-option of the response
--]]-----------------------------------------------
function AutoRespond_UpdateScript()
	if ActiveOption == 0 then
		AutoRespondFrame_OptionsFrame_ButtonScript:Disable();
		AutoRespondFrame_OptionsFrame_ButtonScript:SetChecked(nil);
	else
		AutoRespondFrame_OptionsFrame_ButtonScript:Enable();
		AutoRespondFrame_OptionsFrame_ButtonScript:SetChecked(AutoRespondOptions[Realm][Player][ActiveOption]["Script"]);
	end
end

function AutoRespond_ToggleScript()
	AutoRespondOptions[Realm][Player][ActiveOption]["Script"] = AutoRespondFrame_OptionsFrame_ButtonScript:GetChecked();
end


--[[-----------------------------------------------
functions for the CanGuild-option of the response
--]]-----------------------------------------------
function AutoRespond_InitCanGuild()
	if ActiveOption == 0 then
		AutoRespondFrame_OptionsFrame_ButtonCanGuild:Disable();
		AutoRespondFrame_OptionsFrame_ButtonCanGuild:SetChecked(nil);
	else
		AutoRespondFrame_OptionsFrame_ButtonCanGuild:Enable();
		AutoRespondFrame_OptionsFrame_ButtonCanGuild:SetChecked(AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Guild"]);
	end
end

function AutoRespond_ToggleCanGuild()
	AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Guild"] = AutoRespondFrame_OptionsFrame_ButtonCanGuild:GetChecked();
end


--[[-----------------------------------------------
functions for the CanParty-option of the response
--]]-----------------------------------------------
function AutoRespond_InitCanParty()
	if ActiveOption == 0 then
		AutoRespondFrame_OptionsFrame_ButtonCanParty:Disable();
		AutoRespondFrame_OptionsFrame_ButtonCanParty:SetChecked(nil);
	else
		AutoRespondFrame_OptionsFrame_ButtonCanParty:Enable();
		AutoRespondFrame_OptionsFrame_ButtonCanParty:SetChecked(AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Party"]);
	end
end

function AutoRespond_ToggleCanParty()
	AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Party"] = AutoRespondFrame_OptionsFrame_ButtonCanParty:GetChecked();
end


--[[-----------------------------------------------
functions for the CanRaid-option of the response
--]]-----------------------------------------------
function AutoRespond_InitCanRaid()
	if ActiveOption == 0 then
		AutoRespondFrame_OptionsFrame_ButtonCanRaid:Disable();
		AutoRespondFrame_OptionsFrame_ButtonCanRaid:SetChecked(nil);
	else
		AutoRespondFrame_OptionsFrame_ButtonCanRaid:Enable();
		AutoRespondFrame_OptionsFrame_ButtonCanRaid:SetChecked(AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Raid"]);
	end
end

function AutoRespond_ToggleCanRaid()
	AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Raid"] = AutoRespondFrame_OptionsFrame_ButtonCanRaid:GetChecked();
end


--[[-----------------------------------------------
functions for the CanFriends-option of the response
--]]-----------------------------------------------
function AutoRespond_InitCanFriends()
	if ActiveOption == 0 then
		AutoRespondFrame_OptionsFrame_ButtonCanFriends:Disable();
		AutoRespondFrame_OptionsFrame_ButtonCanFriends:SetChecked(nil);
	else
		AutoRespondFrame_OptionsFrame_ButtonCanFriends:Enable();
		AutoRespondFrame_OptionsFrame_ButtonCanFriends:SetChecked(AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Friends"]);
	end
end

function AutoRespond_ToggleCanFriends()
	AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Friends"] = AutoRespondFrame_OptionsFrame_ButtonCanFriends:GetChecked();
end


--[[-----------------------------------------------
functions for the CanNames-option of the response
--]]-----------------------------------------------
function AutoRespond_InitCanNames()
	local text = "";
	if ActiveOption > 0 then
		if AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Names"] then
			local max = getn(AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Names"]);
			for i,v in ipairs(AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Names"]) do
				text = text..v;
				if i < max then
					text = text..", ";
				end
			end
		end
	end
	AutoRespondFrame_OptionsFrame_ListCanNames:SetText(text);
end

function AutoRespond_SaveCanNames()
	if AutoRespondOptions[Realm][Player][ActiveOption] and AutoRespondOptions[Realm][Player][ActiveOption]["Options"] and AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"] then
		if AutoRespondFrame_OptionsFrame_ListCanNames:GetNumLetters() > 0 then
			AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Names"] = {};
			local function towords(word) if word then table.insert(AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Names"],word); end end
			if not string.find(string.gsub(AutoRespondFrame_OptionsFrame_ListCanNames:GetText(), "%w+", towords), "%S") then end;
		else
			AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Receive"]["Names"] = nil;
		end
	end
end

function AutoRespond_UpdateButtonListCanNames()
	if ActiveOption == 0 then
		AutoRespondFrame_OptionsFrame_ListCanNames:Disable();
	else
		AutoRespondFrame_OptionsFrame_ListCanNames:Enable();
	end
end


--[[-----------------------------------------------
functions for TellGuild-option of the reponse
--]]-----------------------------------------------
function AutoRespond_InitTellGuild()
	if ActiveOption == 0 then
		AutoRespondFrame_OptionsFrame_ButtonTellGuild:Disable();
		AutoRespondFrame_OptionsFrame_ButtonTellGuild:SetChecked(nil);
	else
		AutoRespondFrame_OptionsFrame_ButtonTellGuild:Enable();
		AutoRespondFrame_OptionsFrame_ButtonTellGuild:SetChecked(AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Tell"]["Guild"]);
	end
end

function AutoRespond_ToggleTellGuild()
	AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Tell"]["Guild"] = AutoRespondFrame_OptionsFrame_ButtonTellGuild:GetChecked();
end


--[[-----------------------------------------------
functions for TellParty-option of the reponse
--]]-----------------------------------------------
function AutoRespond_InitTellParty()
	if ActiveOption == 0 then
		AutoRespondFrame_OptionsFrame_ButtonTellParty:Disable();
		AutoRespondFrame_OptionsFrame_ButtonTellParty:SetChecked(nil);
	else
		AutoRespondFrame_OptionsFrame_ButtonTellParty:Enable();
		AutoRespondFrame_OptionsFrame_ButtonTellParty:SetChecked(AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Tell"]["Party"]);
	end
end

function AutoRespond_ToggleTellParty()
	AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Tell"]["Party"] = AutoRespondFrame_OptionsFrame_ButtonTellParty:GetChecked();
end


--[[-----------------------------------------------
functions for TellRaid-option of the reponse
--]]-----------------------------------------------
function AutoRespond_InitTellRaid()
	if ActiveOption == 0 then
		AutoRespondFrame_OptionsFrame_ButtonTellRaid:Disable();
		AutoRespondFrame_OptionsFrame_ButtonTellRaid:SetChecked(nil);
	else
		AutoRespondFrame_OptionsFrame_ButtonTellRaid:Enable();
		AutoRespondFrame_OptionsFrame_ButtonTellRaid:SetChecked(AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Tell"]["Raid"]);
	end
end

function AutoRespond_ToggleTellRaid()
	AutoRespondOptions[Realm][Player][ActiveOption]["Options"]["Tell"]["Raid"] = AutoRespondFrame_OptionsFrame_ButtonTellRaid:GetChecked();
end


--[[--------------------------------------------------------------------------------------------
functions for the whole Responds
--]]--------------------------------------------------------------------------------------------

--[[-----------------------------------------------
function to create a new respond
--]]-----------------------------------------------
function AutoRespond_ButtonNew()
	AutoRespondFrame:Hide();
	
	table.insert( AutoRespondOptions[Realm][Player], { Active = nil, Script = nil, Keywords = {AUTO_RESPOND_DEFAULT_KEYWORD_TEXT}, Response = {AUTO_RESPOND_DEFAULT_RESPONSE_TEXT}, Options = { Receive = { Guild = nil, Party = nil, Raid = nil, Friends = nil, Names = {} }, Tell = { Guild = nil, Party = nil, Raid = nil } } } );
	
	DEFAULT_CHAT_FRAME:AddMessage(AUTO_RESPOND_ADD_NEW_TEXT);
	
	ActiveOption = getn(AutoRespondOptions[Realm][Player]);
	
	AutoRespondFrame:Show();
end


--[[-----------------------------------------------
function to check status for delete-button
--]]-----------------------------------------------
function AutoRespond_ButtonOnShow()
	if ActiveOption == 0 and getn(AutoRespondOptions[Realm][Player]) == 0 then
		AutoRespondFrame_ButtonDelete:Disable();
	else
		AutoRespondFrame_ButtonDelete:Enable();
	end
end


--[[-----------------------------------------------
function to delete a respond
--]]-----------------------------------------------
function AutoRespond_ButtonDelete()
	local index = getn(AutoRespondOptions[Realm][Player]);
	if index >= ActiveOption and index > 0 then
		AutoRespondFrame:Hide();
		table.remove(AutoRespondOptions[Realm][Player],ActiveOption);
		DEFAULT_CHAT_FRAME:AddMessage(AUTO_RESPOND_DELETED_TEXT);
		if(ActiveOption == index) then
			ActiveOption = ActiveOption - 1;
		end
		AutoRespondFrame:Show();
	else
		DEFAULT_CHAT_FRAME:AddMessage(AUTO_RESPOND_EMPTY_LIST_TEXT);
	end
end


--[[-----------------------------------------------
function to check status for previous-button
--]]-----------------------------------------------
function AutoRespond_ButtonPreviousOnShow()
	if ActiveOption <= 1 then
		AutoRespondFrame_ButtonPrevious:Disable();
	else
		AutoRespondFrame_ButtonPrevious:Enable();
	end
end


--[[-----------------------------------------------
function to go to previous response
--]]-----------------------------------------------
function AutoRespond_ButtonPreviousOnClick()
	AutoRespondFrame:Hide();
	ActiveOption = ActiveOption - 1;
	AutoRespondFrame:Show();
end


--[[-----------------------------------------------
function to check status for next-button
--]]-----------------------------------------------
function AutoRespond_ButtonNextOnShow()
	if ActiveOption == (getn(AutoRespondOptions[Realm][Player])) then
		AutoRespondFrame_ButtonNext:Disable();
	else
		AutoRespondFrame_ButtonNext:Enable();
	end
end


--[[-----------------------------------------------
function to go to next response
--]]-----------------------------------------------
function AutoRespond_ButtonNextOnClick()
	AutoRespondFrame:Hide();
	ActiveOption = ActiveOption + 1;
	AutoRespondFrame:Show();
end


--[[--------------------------------------------------------------------------------------------
functions for the main-options
--]]--------------------------------------------------------------------------------------------


--[[-----------------------------------------------
function to show the actual status of the ActiveMod option
--]]-----------------------------------------------
function AutoRespondOptions_InitActiveMod()
	AutoRespondOptionsFrame_ActiveMod:SetChecked(AutoRespondMainOptions[Realm][Player]["ActiveMod"]);
end


--[[-----------------------------------------------
function to save the status of the ActiveMod option
--]]-----------------------------------------------
function AutoRespondOptions_ToggleActiveMod()
	local active = AutoRespondOptionsFrame_ActiveMod:GetChecked();
	if active then
		AutoRespondFrame:RegisterEvent("CHAT_MSG_WHISPER");
	else
		AutoRespondFrame:UnregisterEvent("CHAT_MSG_WHISPER");
	end
	AutoRespondMainOptions[Realm][Player]["ActiveMod"] = AutoRespondOptionsFrame_ActiveMod:GetChecked();
end


--[[-----------------------------------------------
function to show the status of the actual InFight option
--]]-----------------------------------------------
function AutoRespondOptions_InitInFight()
	AutoRespondOptionsFrame_InFight:SetChecked(AutoRespondMainOptions[Realm][Player]["InFight"]);
end


--[[-----------------------------------------------
function to save the status of the InFight option
--]]-----------------------------------------------
function AutoRespondOptions_ToggleInFight()
	AutoRespondMainOptions[Realm][Player]["InFight"] = AutoRespondOptionsFrame_InFight:GetChecked();
end


--[[-----------------------------------------------
function to show the actual scaling and texts for the scale-widget
--]]-----------------------------------------------
function AutoRespondOptions_Scaling_OnShow()
	local scaling = AutoRespondMainOptions[Realm][Player]["Scaling"];
	
	getglobal(AutoRespondOptionsFrame_Scaling_Slider:GetName() .. "High"):SetText("150%");
	getglobal(AutoRespondOptionsFrame_Scaling_Slider:GetName() .. "Low"):SetText("50%");
	getglobal(AutoRespondOptionsFrame_Scaling_Slider:GetName() .. "Text"):SetText("Scaling - " .. (scaling*100));
	
	AutoRespondOptionsFrame_Scaling_Slider:SetMinMaxValues(0.5, 1.5);
	AutoRespondOptionsFrame_Scaling_Slider:SetValueStep(0.01);
	AutoRespondOptionsFrame_Scaling_Slider:SetValue(scaling);
end


--[[-----------------------------------------------
function to save the scaling when changed
--]]-----------------------------------------------
function AutoRespondOptions_Scaling_OnValueChanged()
	scaling = floor(AutoRespondOptionsFrame_Scaling_Slider:GetValue()*100+0.5)/100;
	getglobal(AutoRespondOptionsFrame_Scaling_Slider:GetName() .. "Text"):SetText("Scaling - " .. (scaling*100) .. "%");
	AutoRespondMainOptions[Realm][Player]["Scaling"] = scaling;
	AutoRespondOptions_ScaleFrame(scaling);
end


--[[-----------------------------------------------
function to set the scale of the mainframe
--]]-----------------------------------------------
function AutoRespondOptions_ScaleFrame(scaling)
	AutoRespondFrame:SetScale(scaling);
end


--[[-----------------------------------------------
function to init the spam check option
--]]-----------------------------------------------
function AutoRespondOptions_InitSpamCheck()
	AutoRespondOptionsFrame_SpamCheck:SetChecked(AutoRespondMainOptions[Realm][Player]["SpamCheck"]);
end

--[[-----------------------------------------------
function to save the spam check option when changed
--]]-----------------------------------------------
function AutoRespondOptions_ToggleSpamCheck()
	AutoRespondMainOptions[Realm][Player]["SpamCheck"] = AutoRespondOptionsFrame_SpamCheck:GetChecked();
end


--[[-----------------------------------------------
function to save the spam timer when changed
--]]-----------------------------------------------
function AutoRespondOptions_SpamTimer_OnValueChanged()
	timer = AutoRespondOptionsFrame_SpamTimer_Slider:GetValue();
	getglobal(AutoRespondOptionsFrame_SpamTimer_Slider:GetName() .. "Text"):SetText("Spam timer - " .. (timer));
	AutoRespondMainOptions[Realm][Player]["SpamTimer"] = timer;
end

--[[-----------------------------------------------
function to init the spam timer option
--]]-----------------------------------------------
function AutoRespondOptions_SpamTimer_OnShow()
	local timer = AutoRespondMainOptions[Realm][Player]["SpamTimer"];
	if not timer then 
		 timer = 60.0; 
	end
	getglobal(AutoRespondOptionsFrame_SpamTimer_Slider:GetName().."High"):SetText("60s");
	getglobal(AutoRespondOptionsFrame_SpamTimer_Slider:GetName().."Low"):SetText("1s");
	getglobal(AutoRespondOptionsFrame_SpamTimer_Slider:GetName() .. "Text"):SetText("Spam timer - " .. (timer));
	
	AutoRespondOptionsFrame_SpamTimer_Slider:SetMinMaxValues(1.0, 60.0);
	AutoRespondOptionsFrame_SpamTimer_Slider:SetValueStep(1.0);
	AutoRespondOptionsFrame_SpamTimer_Slider:SetValue(timer);
end


--[[--------------------------------------------------------------------------------------------
special functions for macros or scripts
--]]--------------------------------------------------------------------------------------------

--[[-----------------------------------------------
function to promote a response to a channel
Parameter:
	index - the index of the response to promote
	channel - the identifier of the channel to promote to
	number - only with channel "CHANNEL" where number is the numeric id of the channel to promote to
--]]-----------------------------------------------
function AutoRespond_PromoteResponse(index,channel,number)
	if channel and index and (index <= getn(AutoRespondOptions[Realm][Player])) then
		for i,v in AutoRespondOptions[Realm][Player][index]["Response"] do
	    if channel == "CHANNEL" then
	    	if number then
					SendChatMessage(v,channel,GetDefaultLanguage("player"),number);
				else
					DEFAULT_CHAT_FRAME:AddMessage(AUTO_RESPOND_PROMOTE_CHANNEL_ERROR);
				end
			else
				SendChatMessage(v,channel,GetDefaultLanguage("player"));
			end
		end
	end
end


--[[-----------------------------------------------
function to promote all keywords of response(s) to a channel
Parameter:
	index - the index of the response, if nil all active responses will be used
	channel - the identifier of the channel to promote to
	number - only with channel "CHANNEL" where number is the numeric id of the channel to promote to
--]]-----------------------------------------------
function AutoRespond_PromoteKeywords(index,channel, number)
	local s,e = 1,getn(AutoRespondOptions[Realm][Player]);
	if index then
		s = index;
		e = index;
	end
	for i=s,e do
		if AutoRespondOptions[Realm][Player][i] and AutoRespondOptions[Realm][Player][i]["Active"] then
		   	if AutoRespondOptions[Realm][Player][i]["Keywords"] then
				local text,max = "", getn(AutoRespondOptions[Realm][Player][i]["Keywords"]);
				for j,v in ipairs(AutoRespondOptions[Realm][Player][i]["Keywords"]) do
					text = text..v;
					if j < max then
						text = text..", ";
					end
				end
				if channel == "CHANNEL" then
					if number then
						SendChatMessage(text,channel,GetDefaultLanguage("player"),number);
					else
						DEFAULT_CHAT_FRAME:AddMessage(AUTO_RESPOND_PROMOTE_CHANNEL_ERROR);
					end
				else
					SendChatMessage(text,channel,GetDefaultLanguage("player"));
				end
			end
		end
	end
end