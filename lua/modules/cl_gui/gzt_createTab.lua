AddCSLuaFile()
if SERVER then return end

include("modules/cl_gui/gzt_tabPanel.lua")

local PANEL = {}

function PANEL:Init()

end

vgui.Register("gzt_CreateTab", PANEL, "gzt_TabPanel")