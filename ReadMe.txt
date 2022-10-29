AutoRespond ReadMe File 
Version 1.0.1 Reborn


Usage: 	
"/ar" or "/autorespond" : Show the AutoRespond Frame
"/ar options" or "/autorespond options" for showing the main options frame

To add a profession link, click the - All button in the top right to minimize all of the profession tabs, then just Add Link

::: Changelog :::
V1.0.1
	- Fixed string.find = nil errors on startup or reload
	- Fixed parsing of realm names to parse apostrophes & spaces
	- Changed how the options save, they now save per character
		*NEW LOCATION* ~ WTF > Account > AccountName/Number > Realm > CharacterName > SavedVariables > AutoRespond.lua
		*OLD LOCATION* ~ WTF > Account > AccountName/Number > SavedVariables > AutoRespond.lua

************* IMPORTANT ************		
To update a pre existing config to the new saving method. 
- Load a character that already has the options all set.
- Type /reload to generate the new config based on the old one. 
- Then exit WoW and delete old config from the old location above ^
- Start WoW and confirm that your settings, keywords, responses, are all the same.