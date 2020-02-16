AddCSLuaFile()

-- include("modules/cl_gui/gzt_gui.lua")

SWEP.Category = "Zone Tool"
SWEP.Spawnable = true --this is not supposed to be spawnable
SWEP.AdminOnly = true 
SWEP.PrintName = "Gamemode Zone Tool"
SWEP.Author = "Sarcly & Intox"
--Sarcly's comments
//Intox's comments

SWEP.ViewModelFOV = 60
SWEP.ViewModel = "models/weapons/c_toolgun.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"
util.PrecacheModel( SWEP.ViewModel )
util.PrecacheModel( SWEP.WorldModel )
 
SWEP.Slot = 5
SWEP.SlotPos = 8
SWEP.UseHands = true
SWEP.Weight	= 5

SWEP.AccurateCrosshair = false
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom	= false
SWEP.DrawAmmo = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Initialized = false
SWEP.IsPaused = false --CLIENT ONLY


SWEP.CurrentBox = {
	MinBound=nil,
	MaxBound=nil,
	Ent=nil
}
SWEP.Modes = {
	Loading = "Loading",
	Create = "Create",
	Edit = "Edit",
	Program = "Program"
}
SWEP.ModeList = {
	SWEP.Modes.Loading,
	SWEP.Modes.Create,
	SWEP.Modes.Edit,
	SWEP.Modes.Program
}

SWEP.KeyTable = {}
SWEP.KeyCreationQueue = {}
SWEP.KeyExecutionQueue = {}
SWEP.ModifierKeys = {}
SWEP.ModifierKeys[KEY_LCONTROL] = true
SWEP.ModifierKeys[KEY_LSHIFT] = true
SWEP.ModifierKeys[KEY_LALT] = true

SWEP.SelectedCorner = nil
SWEP.GrabMagCL = -1

if SERVER then
	util.AddNetworkString("gzt_returnclientzoneid")
end

if CLIENT then
	net.Receive("gzt_returnclientzoneid", function(len)
		LocalPlayer():GetActiveWeapon().entId = net.ReadString()
	end)
end

function SWEP:Initialize()
	self.Initialized = true
    self:SetHoldType("revolver")
	if CLIENT then
		self:SetToolMode("Loading")
		self:IncToolMode()
	end
end

function SWEP:SetupDataTables()
	self:NetworkVar("Float",0,"GrabMag")
	self:NetworkVar("Entity", 0, "CurrentEnt")
end

function SWEP:Deploy()
	self.KeyCreationQueue = {}
	self.KeyExecutionQueue = {}
end

function SWEP:CanBePickedUpByNPCs()
	return false
end
function SWEP:CanPrimaryAttack()
	return false	
end
function SWEP:CanSecondaryAttack()
	return false	
end

function SWEP:Think()
	if !self.Initialized then self:Initialize() end
	if CLIENT then
		if ConVarExists("gzt_is_paused") then 
			if gui.IsGameUIVisible() && !self.IsPaused then
				self.IsPaused = true
				GetConVar("gzt_is_paused"):SetInt(1)
			elseif !gui.IsGameUIVisible() && self.IsPaused then
				self.IsPaused = false
				GetConVar("gzt_is_paused"):SetInt(0)
			end
		end
	end
	self:ProcessInput()
end

for k,v in pairs(SWEP.Modes) do
	SWEP["KF"..v..KEY_R] = function(self, KeyCombo)
		if GetConVar("gzt_in_menu"):GetInt() == 1 || GetConVar("gzt_is_paused"):GetInt() == 1 then return end
		if !KeyCombo.processed && !KeyCombo.released then
			self:IncToolMode()
		end
	end
	SWEP["KF"..v..KEY_H] = function(self, KeyCombo)
		if GetConVar("gzt_is_paused"):GetInt() == 1 then return end
		if !KeyCombo.processed && !KeyCombo.released && CLIENT then
			self:GetOwner():ConCommand("gzt_toggle_gui")
		end	
	end
end

SWEP["KF"..SWEP.Modes.Create..KEY_T] = function(self, KeyCombo)
	if GetConVar("gzt_in_menu"):GetInt() == 1 || GetConVar("gzt_is_paused"):GetInt() == 1 then return end
	if !KeyCombo.processed && !KeyCombo.released && SERVER then
		if self.CurrentBox.gzt_entity && IsValid(self.CurrentBox.gzt_entity) then
			if self.CurrentBox.gzt_entity:GetDrawFaces() then
				self.CurrentBox.gzt_entity:SetDrawFaces(false)
			else
				self.CurrentBox.gzt_entity:SetDrawFaces(true)
			end
		end
	end
end

SWEP["KF"..SWEP.Modes.Create..MOUSE_LEFT] = function(self, KeyCombo)
	if GetConVar("gzt_in_menu"):GetInt() == 1 || GetConVar("gzt_is_paused"):GetInt() == 1 then return end
	if !KeyCombo.processed && !KeyCombo.released then  
		self.CurrentBox.gzt_pos1 = self:GetOwner():GetPos()
		if self.CurrentBox && self.CurrentBox.gzt_pos1 && self.CurrentBox.gzt_pos2 then
			self:TellServerToCreateZone()
		end
	end
end

SWEP["KF"..SWEP.Modes.Create..MOUSE_RIGHT] = function(self, KeyCombo)
	if GetConVar("gzt_in_menu"):GetInt() == 1 || GetConVar("gzt_is_paused"):GetInt() == 1 then return end
	if !KeyCombo.processed && !KeyCombo.released then
		self.CurrentBox.gzt_pos2 = self:GetOwner():GetPos()
		if self.CurrentBox && self.CurrentBox.gzt_pos1 && self.CurrentBox.gzt_pos2 then
			self:TellServerToCreateZone()
		end
	end
end

SWEP.TellServerToCreateZone = function(self)
	local zoneObj = {}
	zoneObj.gzt_pos1 = self.CurrentBox.gzt_pos1
	zoneObj.gzt_pos2 = self.CurrentBox.gzt_pos2
	zoneObj.gzt_parents = GetConVar("gzt_selected_category_parents"):GetString()
	print("self entid", self.entId)
	if self.entId == nil then
		GZT_WRAPPER:ClientMakeZone(zoneObj)
	else
		GZT_WRAPPER:ClientUpdateZone(zoneObj, self.entId)
	end
end

SWEP["KF"..SWEP.Modes.Create..KEY_LCONTROL..MOUSE_LEFT] = function(self, KeyCombo)
	if GetConVar("gzt_in_menu"):GetInt() == 1 || GetConVar("gzt_is_paused"):GetInt() == 1 then return end
	if !KeyCombo.processed && !KeyCombo.released then
		if self.CurrentBox.gzt_entity then
			self:DeleteBox()
			self.CurrentBox.gzt_entity=nil
		end
		if self.CurrentBox.gzt_pos1 then
			self.CurrentBox.gzt_pos1=nil
		end
	end
end

SWEP["KF"..SWEP.Modes.Create..KEY_LCONTROL..MOUSE_RIGHT] = function(self, KeyCombo)
	if GetConVar("gzt_in_menu"):GetInt() == 1 || GetConVar("gzt_is_paused"):GetInt() == 1 then return end
	if !KeyCombo.processed && !KeyCombo.released then 
		if self.CurrentBox.gzt_entity then
			self:DeleteBox()
			self.CurrentBox.gzt_entity=nil
		end
		if self.CurrentBox.gzt_pos2 then
			self.CurrentBox.gzt_pos2=nil
		end
	end
end

SWEP["KF"..SWEP.Modes.Create..KEY_LALT..MOUSE_LEFT] = function(self, KeyCombo)
	if GetConVar("gzt_in_menu"):GetInt() == 1 || GetConVar("gzt_is_paused"):GetInt() == 1 then return end
	if !KeyCombo.processed && !KeyCombo.released then
		if(!IsValid(self.SelectedCorner)) then
			tr = self:GetOwner():GetEyeTrace()
			if(tr.Hit && IsValid(tr.Entity) && tr.Entity.ClassName=="gzt_zonecorner" && !tr.Entity:GetOwner().Grabbed) then
				//set grab state for all corners to true, grabplayer maybe = self:GetOwner()?
				self.SelectedCorner = tr.Entity
				self.SelectedCorner:GetOwner().Grabbed = true
				self.SelectedCorner:SetColor(Color(0,0,255,255))
				self:SetGrabMag(self.SelectedCorner:GetPos():Distance(self:GetOwner():EyePos()))
				self.GrabMagCL = self.SelectedCorner:GetPos():Distance(self:GetOwner():EyePos())
				print("Set grab mag to "..self.SelectedCorner:GetPos():Distance(self:GetOwner():EyePos()))
			end
		end
	elseif KeyCombo.processed && !KeyCombo.released then
		if IsValid(self.SelectedCorner) then
			print("using grab mag ", self:GetGrabMag())
			if SERVER then
				self.SelectedCorner:SetPos(self:GetOwner():EyePos()+self:GetOwner():GetAimVector()*self:GetGrabMag())
			else
				self.SelectedCorner:SetPos(self:GetOwner():EyePos()+self:GetOwner():GetAimVector()*self.GrabMagCL)
			end
			self.SelectedCorner:GetOwner():Resize(self.SelectedCorner)
		end
	elseif KeyCombo.processed && KeyCombo.released then
		if IsValid(self.SelectedCorner) then
			self.SelectedCorner:SetColor(Color(255,255,255,255))
			if(SERVER) then
				self.SelectedCorner:GetOwner():BuildCorners()
			end
			self.SelectedCorner:GetOwner().Grabbed = nil
			self.SelectedCorner = nil 
		end
	end
end

function SWEP:GetToolMode() 
	return self.ModeList[GetConVar("gzt_toolmode"):GetInt()]
end

function SWEP:SetToolMode(mode)
	for k,v in pairs(self.ModeList) do
		if v == mode then
			if ConVarExists("gzt_toolmode") then
				GetConVar("gzt_toolmode"):SetInt(k)
			end
			return
		end
	end
	if ConVarExists("gzt_toolmode") then
		GetConVar("gzt_toolmode"):SetInt(2)
	end
end

function SWEP:IncToolMode()
	if !ConVarExists("gzt_toolmode") then return end 
	if GetConVar("gzt_toolmode"):GetInt() >= #self.ModeList then
		GetConVar("gzt_toolmode"):SetInt(2)
	else
		GetConVar("gzt_toolmode"):SetInt(GetConVar("gzt_toolmode"):GetInt()+1)
	end
end

function PlayerBindPress(ply, bind, pressed)
	if(ply:GetActiveWeapon():IsValid() && ply:GetActiveWeapon():GetClass()=="gzt_zonetool") then
		local self = ply:GetActiveWeapon()
		if IsValid(self.SelectedCorner) then
			if(bind == "invprev") then
				--TODO:scale amount moved on scroll by how far away the box is
				self.GrabMagCL = math.max(self.GrabMagCL+10, 10)
				self:SetGrabMag(self.GrabMagCL)
				print("increasing grabmag to ", self.GrabMagCL)
				return true
			elseif bind == "invnext" then
				self.GrabMagCL = math.max(self.GrabMagCL-10, 10)
				self:SetGrabMag(self.GrabMagCL)
				return true
			end
		end
	end
end
hook.Add("PlayerBindPress", "gzt_ZoneToolScrollHandle", PlayerBindPress)

function SWEP:PlayerButtonDown(key, ply)
	--In this function self refers to the player holding the tool, not the tool itself
	if CLIENT && !IsFirstTimePredicted() then return end 
	if self:GetActiveWeapon():IsValid() && self:GetActiveWeapon():GetClass()=="gzt_zonetool" then
		local toolInst = self:GetActiveWeapon()
		toolInst.KeyTable[key] = {key=key, time=SysTime()} 
		toolInst.KeyCreationQueue[#toolInst.KeyCreationQueue+1] = {key=key, time=SysTime()}
	end
end
hook.Add("PlayerButtonDown", "gzt_ZoneToolKeyDown", SWEP.PlayerButtonDown)

function SWEP:PlayerButtonUp(key, ply)
    --In this function self refers to the player holding the tool, not the tool itself
	if self:GetActiveWeapon():IsValid() && self:GetActiveWeapon():GetClass()=="gzt_zonetool" then
		local toolInst = self:GetActiveWeapon()
		if(!toolInst.KeyTable) then return end
		toolInst.KeyTable[key] = nil
		if(toolInst.ModifierKeys[key]) then
			for i,v in pairs(toolInst.KeyCreationQueue) do
				if v.key == key then
					toolInst.KeyCreationQueue[i] = nil
				end
			end
		end
	end
end
hook.Add("PlayerButtonUp","gzt_ZoneToolKeyUp", SWEP.PlayerButtonUp)

function SWEP:ProcessInput()
	if (SERVER) then return end
	--CREATION OF KEY COMBOS
	for i,key in pairs(self.KeyCreationQueue) do
		if !self.KeyCreationQueue[i] then continue end
		if self.KeyCreationQueue[i] && self.KeyCreationQueue[i+1] && self.KeyCreationQueue[i+2] && self.KeyCreationQueue[i+3] then
			if self.KeyCreationQueue[i].key != self.KeyCreationQueue[i+1].key && self.KeyCreationQueue[i].key != self.KeyCreationQueue[i+2].key && self.KeyCreationQueue[i].key != self.KeyCreationQueue[i+3].key && self.KeyCreationQueue[i+1].key != self.KeyCreationQueue[i+2].key && self.KeyCreationQueue[i+1].key != self.KeyCreationQueue[i+3].key && self.KeyCreationQueue[i+2].key != self.KeyCreationQueue[i+3].key then
				if self.ModifierKeys[self.KeyCreationQueue[i].key] && self.ModifierKeys[self.KeyCreationQueue[i+1].key] && self.ModifierKeys[self.KeyCreationQueue[i+2].key] then
					if !self.ModifierKeys[self.KeyCreationQueue[i+3].key] then
						self.KeyExecutionQueue[#self.KeyExecutionQueue+1] = {key1=self.KeyCreationQueue[i], key2=self.KeyCreationQueue[i+1], key3=self.KeyCreationQueue[i+2], key4=self.KeyCreationQueue[i+3], comboType="QUADRUPLE", processed=false, released=false}
						if !self.KeyTable[self.KeyCreationQueue[i].key] then
							self.KeyCreationQueue[i] = nil
						end
						if !self.KeyTable[self.KeyCreationQueue[i+1].key] then
							self.KeyCreationQueue[i+1] = nil
						end
						if !self.KeyTable[self.KeyCreationQueue[i+2].key] then
							self.KeyCreationQueue[i+2] = nil
						end
						self.KeyCreationQueue[i+3]=nil
					end
				end
			end
		elseif self.KeyCreationQueue[i] && self.KeyCreationQueue[i+1] && self.KeyCreationQueue[i+2] && (self.KeyCreationQueue[i].key != self.KeyCreationQueue[i+1].key && self.KeyCreationQueue[i+1].key != self.KeyCreationQueue[i+2].key && self.KeyCreationQueue[i].key != self.KeyCreationQueue[i+2].key) then
			if self.ModifierKeys[self.KeyCreationQueue[i].key] && self.ModifierKeys[self.KeyCreationQueue[i+1].key] then
				if !self.ModifierKeys[self.KeyCreationQueue[i+2].key] then
					self.KeyExecutionQueue[#self.KeyExecutionQueue+1] = {key1=self.KeyCreationQueue[i], key2=self.KeyCreationQueue[i+1], key3=self.KeyCreationQueue[i+2], comboType="TRIPLE", processed=false, released=false}
					if !self.KeyTable[self.KeyCreationQueue[i].key] then
						self.KeyCreationQueue[i] = nil
					end
					if !self.KeyTable[self.KeyCreationQueue[i+1].key] then
						self.KeyCreationQueue[i+1] = nil
					end
					self.KeyCreationQueue[i+2]=nil
				end
			end
		elseif self.KeyCreationQueue[i] && self.KeyCreationQueue[i+1] && (self.KeyCreationQueue[i].key != self.KeyCreationQueue[i+1].key) then
			if self.ModifierKeys[self.KeyCreationQueue[i].key] then
				if !self.ModifierKeys[self.KeyCreationQueue[i+1].key] then
					self.KeyExecutionQueue[#self.KeyExecutionQueue+1] = {key1=self.KeyCreationQueue[i], key2=self.KeyCreationQueue[i+1], comboType="DOUBLE", processed=false, released=false}
					if !self.KeyTable[self.KeyCreationQueue[i].key] then
						self.KeyCreationQueue[i] = nil
					end
					self.KeyCreationQueue[i+1]=nil
				end
			end
		elseif self.KeyCreationQueue[i] then
			if !self.ModifierKeys[self.KeyCreationQueue[i].key] then
				self.KeyExecutionQueue[#self.KeyExecutionQueue+1] = {key1=self.KeyCreationQueue[i], comboType="SINGLE", processed=false, released=false}
				self.KeyCreationQueue[i]=nil
			end
		end
	end
	--EXECUTION OF KEY COMBOS
	for i,KeyCombo in pairs(self.KeyExecutionQueue) do
		--if key combo has been processed and is not held then remove it
		if !self.KeyExecutionQueue[i] then continue end
		if self.KeyExecutionQueue[i].processed then
			if self.KeyExecutionQueue[i].comboType == "SINGLE" then
				if !self.KeyTable[self.KeyExecutionQueue[i].key1.key] then
					self.KeyExecutionQueue[i].released=true
				end
			elseif self.KeyExecutionQueue[i].comboType == "DOUBLE" then
				if !self.KeyTable[self.KeyExecutionQueue[i].key1.key] || !self.KeyTable[self.KeyExecutionQueue[i].key2.key] then
					self.KeyExecutionQueue[i].released=true
				end
			elseif self.KeyExecutionQueue[i].comboType == "TRIPLE" then
				if !self.KeyTable[self.KeyExecutionQueue[i].key1.key] || !self.KeyTable[self.KeyExecutionQueue[i].key2.key] || !self.KeyTable[self.KeyExecutionQueue[i].key3.key] then
					self.KeyExecutionQueue[i].released=true
				end
			elseif self.KeyExecutionQueue[i].comboType == "QUADRUPLE" then
				if !self.KeyTable[self.KeyExecutionQueue[i].key1.key] || !self.KeyTable[self.KeyExecutionQueue[i].key2.key] || !self.KeyTable[self.KeyExecutionQueue[i].key3.key] || !self.KeyTable[self.KeyExecutionQueue[i].key4.key] then
					self.KeyExecutionQueue[i].released=true
				end
			end
		end
		--run the fuction for the key combo if it exists
		if self.KeyExecutionQueue[i].comboType == "SINGLE" then
			if self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key1.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key1.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true 
			end
		elseif self.KeyExecutionQueue[i].comboType == "DOUBLE" then
			if self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key2.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key2.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true 
			elseif self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key2.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key2.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true 
			end
		elseif self.KeyExecutionQueue[i].comboType == "TRIPLE" then
			if self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key3.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key3.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true 
			elseif self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key3.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key3.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true 
			elseif self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key3.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key3.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true 
			end
		elseif self.KeyExecutionQueue[i].comboType == "QUADRUPLE" then
			if self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key3.key..self.KeyExecutionQueue[i].key4.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key3.key..self.KeyExecutionQueue[i].key4.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true 
			elseif self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key3.key..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key4.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key3.key..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key4.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true 
			elseif self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key3.key..self.KeyExecutionQueue[i].key4.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key3.key..self.KeyExecutionQueue[i].key4.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true
			elseif self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key3.key..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key4.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key3.key..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key4.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true
			elseif self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key3.key..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key4.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key3.key..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key4.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true
			elseif self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key3.key..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key4.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key3.key..self.KeyExecutionQueue[i].key2.key..self.KeyExecutionQueue[i].key1.key..self.KeyExecutionQueue[i].key4.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true
			elseif self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key4.key] then
				self["KF"..self:GetToolMode()..self.KeyExecutionQueue[i].key4.key](self,self.KeyExecutionQueue[i])
				self.KeyExecutionQueue[i].processed=true 
			end
		end
		if self.KeyExecutionQueue[i].processed && self.KeyExecutionQueue[i].released then
			if self.KeyExecutionQueue[i].comboType == "SINGLE" then
				if !self.KeyTable[self.KeyExecutionQueue[i].key1.key] then
					self.KeyExecutionQueue[i]=nil
					continue
				end
			elseif self.KeyExecutionQueue[i].comboType == "DOUBLE" then
				if !self.KeyTable[self.KeyExecutionQueue[i].key1.key] || !self.KeyTable[self.KeyExecutionQueue[i].key2.key] then
					self.KeyExecutionQueue[i]=nil
					continue
				end
			elseif self.KeyExecutionQueue[i].comboType == "TRIPLE" then
				if !self.KeyTable[self.KeyExecutionQueue[i].key1.key] || !self.KeyTable[self.KeyExecutionQueue[i].key2.key] || !self.KeyTable[self.KeyExecutionQueue[i].key3.key] then
					self.KeyExecutionQueue[i]=nil
					continue 
				end
			elseif self.KeyExecutionQueue[i].comboType == "QUADRUPLE" then
				if !self.KeyTable[self.KeyExecutionQueue[i].key1.key] || !self.KeyTable[self.KeyExecutionQueue[i].key2.key] || !self.KeyTable[self.KeyExecutionQueue[i].key3.key] || !self.KeyTable[self.KeyExecutionQueue[i].key4.key] then
					self.KeyExecutionQueue[i]=nil
					continue 
				end
			end
		end
		if(!self.KeyExecutionQueue[i].processed) then
			self.KeyExecutionQueue[i]=nil
		end
	end
end

function SWEP:RenderScreen()
    if SERVER then return end
	local matScreen = Material( "models/weapons/v_toolgun/screen" )
    local screenTarget = GetRenderTarget("GModToolgunScreen", 256, 256)
	matScreen:SetTexture( "$basetexture", screenTarget )
	render.PushRenderTarget(screenTarget)
	cam.Start2D()
		surface.SetDrawColor(0,0,0,255)
		surface.DrawRect(0,0,256,256)
		--Draw tool screen here
        draw.SimpleText("yeet", "GModToolScreen", 256/2, 256/3, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
		draw.SimpleText(self.ModeList[GetConVar("gzt_toolmode"):GetInt()], "GModToolSubtitle", 256/2, 256/1.5, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
	cam.End2D()
	render.PopRenderTarget()
end

--[[ current problems...

	grab mag not working <- just use net or something
	corner trailing behind cursor
	corner beam 
	corners still active when zone gone
]]
GZT_ZONETOOL = SWEP