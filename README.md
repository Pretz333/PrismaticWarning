# PrismaticWarning

Prismatic Warning alerts when to slot a weapon with a prismatic onslaught enchant (henceforth called a “prismatic weapon”) in dungeons, trials, and arenas. 

<b>Why use this AddOn?</b>

Using a prismatic weapon enchant instead of the typical weapon damage or flame enchant significantly increases a player’s DPS, but can only be used on daedra and undead. 

It can be difficult to remember what bosses exactly count as a daedra or undead, so this AddOn reminds you to slot a prismatic weapon when you approach one of the supported bosses.

<b>See AddOn Page at _______ for all information</b>

<b>How to use this AddOn:</b>
  <ul>
  <li>Install this AddOn</li>
  <li>Install LibAddonMenu-2.0 (if not already installed)</li>
  <li>Once installed, there is a setting window under the AddOns section of settings that I recommend to take a look through. Some example settings are:
    <ul>
    <li>Hide on-screen alert in combat</li>
    <li>Alert depending on your selected LFG role (separates stamina and magicka damage dealers)</li>
    <li>Only alert when on veteran difficulty</li></li>
    </ul>
  </ul>

<b>Known Bugs:</b>
<ul>
<li>Bloodroot Forge alerts before Earthgore Amalgam spawns in</li>
<li>Prismatic Warning will not catch if you change your role while not in a group</li>
<li>If you are in a partial-prismatic dungeon using the map to look at a zone you aren’t in and you cross one of the slot/deslot boundaries, you will not be alerted to slot/deslot the prismatic weapon.</li>
</ul>

<b>To Be Added:</b>
  <ul>
<li>Hel Ra Citadel (Ra Kotu)</li>
<li>Translations of menu and alerts. Everything on my end is done, if you can translate, please:<ul>
<li>Open the “lang” folder inside the AddOn folder</li>
<li>If a copy of your language code (fr, de, ru, etc.) doesn’t exist, make a copy of the “new.lua” file and rename it to your language code</li>
<li>Translate as many of the sentences or words in between the quotes inside the file as you want. For example if I was attempting to make a French translation, the first line of the file is PRISMATICWARNING_ALERT = “Prismatic”, I would want to change that to PRISMATICWARNING_ALERT = “Prismatique”,</li>
<li>Leave a comment with the new/updated translation (the lang.lua file)</li></li></ul></ul>
