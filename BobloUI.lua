--[[
	BobloUI v0.10.1-beta.1 - generated bundle, do not edit.
	Source: https://github.com/bobloscript/scripts/blob/main/BobloUI.lua
	Built: 2026-08-22T09:23:40.498Z
	Modules: 55
]]
local __modules = {}
local __cache = {}
local function __require(id)
	local cached = __cache[id]
	if cached then return cached[1] end
	local loader = __modules[id]
	if not loader then error("[BobloUI] missing bundled module: " .. id, 2) end
	local result = loader()
	__cache[id] = { result }
	return result
end

__modules["controls/Base"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Janitor=__require("runtime/Janitor")
local Signal=__require("runtime/Signal")
local Validate=__require("runtime/Validate")
local Base={}; Base.__index=Base

local function originSource(origin) return type(origin)=="table" and origin.Source or nil end
local function isSilent(origin) return type(origin)=="table" and origin.Silent==true end

function Base.init(self,section,typeName,options,config)
	options=options or {}; config=config or {}; Validate.Control(typeName,options)
	self.Type=typeName; self.Id=options.Id; self.Title=options.Title or ""; self.Description=options.Description; self.Keywords=options.Keywords or {}; self.Callback=options.Callback
	self._section=section; self._window=section._window; self._janitor=Janitor.new(`${typeName}[{self.Id or self.Title}]`); self._destroyed=false; self._mounted=false; self._order=options.Order or 0
	self._manualVisible=options.Visible~=false; self._dependencyVisible=true; self._manualDisabled=(options.Disabled==true or type(options.Disabled)=="string"); self._dependencyEnabled=true
	self._disabledReason=type(options.Disabled)=="string" and options.Disabled or nil; self._loading=false; self._tooltip=options.Tooltip; self._contextMenu=options.ContextMenu
	self._stateful=config.Stateful==true; self._persist=config.Persist~=false and self._stateful and options.IgnoreConfig~=true; self._value=config.Default; self._default=config.Default; self._baseLayoutStyle=config.Layout or "Inline"; self._layoutStyle=self._baseLayoutStyle; self._adaptive=config.Adaptive==true or options.Adaptive==true
	self.Changed=Signal.new(`${typeName}.Changed`); section._janitor:Add(self,"Destroy",self)
	if self.Id then
		if not string.match(self.Id,"^[A-Za-z0-9_.%-]+$") then error(`[BobloUI] invalid Id "{self.Id}". Use A-Z, a-z, 0-9, _, ., - only.`,3) end
		if self._stateful then self._window.State:SetDefault(self.Id,config.Default) end
		self._window.Registry:Add(self,{Id=self.Id,Type=typeName,Title=self:_resolve(self.Title),Description=self:_resolve(self.Description or ""),Keywords=self.Keywords,Tab=section._tab.Id,Section=section.Title,Path=`{self:_resolve(section._tab.Title)} -> {self:_resolve(section.Title or "Default")}`,Persist=self._persist})
	else
		self._window.Registry:Add(self,{Type=typeName,Title=self:_resolve(self.Title),Description=self:_resolve(self.Description or ""),Keywords=self.Keywords,Tab=section._tab.Id,Section=section.Title,Path=`{self:_resolve(section._tab.Title)} -> {self:_resolve(section.Title or "Default")}`,Persist=false})
	end
	if self.Id and self._stateful then
		self._janitor:Add(self._window.State:Watch(self.Id,function(value,old,id,origin)
			if self._destroyed then return end; self._value=value; if self._mounted then self:_render(value) end
			if not isSilent(origin) then
				if self.Callback then local ok,err=xpcall(self.Callback,debug.traceback,value); if not ok then warn(`[BobloUI] {self.Type} "{self.Id}" callback failed:\n{err}`) end end
				self.Changed:Fire(value,old,originSource(origin))
			end
		end))
	end
	self._janitor:Add(self._window.Theme.Changed:Connect(function() if self._mounted then self:_render(self:GetValue()); self:_applyDisabled(); self:_applyHoverVisual(false) end end))
	self._janitor:Add(self._window.Tokens.Changed:Connect(function() if self._mounted then self:_applyTokens() end end))
	self:_bindDependency(options.VisibleWhen,"visible"); self:_bindDependency(options.EnabledWhen,"enabled")
end

function Base.finish(self) self._section:_registerControl(self); if self._section._mounted then self:_mount() end; return self end

function Base:_bindDependency(spec,kind)
	if spec==nil then return end; local slot=`dep_{kind}`
	local function apply(result) if kind=="visible" then self._dependencyVisible=result==true; self:_applyVisible() else self._dependencyEnabled=result==true; self:_applyDisabled() end end
	if type(spec)=="table" then
		local ids={}; local req={}; for id,wanted in spec do table.insert(ids,id); table.insert(req,id.." = "..tostring(wanted)) end
		self._dependencyIds=ids; self._window.Registry:Update(self,{DependencyIds=ids,Requirement=table.concat(req,", ")})
		local function eval() for id,wanted in spec do if self._window.State:Get(id)~=wanted then apply(false); return end end; apply(true) end
		self._janitor:Add(self._window.State:WatchMany(ids,eval),nil,slot); eval()
	elseif type(spec)=="function" then
		local function retrack()
			self._janitor:Remove(slot); local ids,result=self._window.State:Track(spec); self._dependencyIds=ids
			self._window.Registry:Update(self,{DependencyIds=ids,Requirement=(#ids>0 and table.concat(ids,", ") or nil)})
			if #ids==0 then warn(`[BobloUI] {self.Type} "{self.Id or self.Title}" dependency tracked 0 State:Get calls. Use the State argument passed to the predicate.`) end
			local unsubs={}; for _,id in ids do table.insert(unsubs,self._window.State:Watch(id,function() retrack() end)) end
			self._janitor:Add(function() for _,u in unsubs do u() end end,nil,slot); apply(result==true)
		end; retrack()
	else error(`[BobloUI] {kind} dependency must be a table or function.`,3) end
end

function Base:_effectiveLayout()
	if self._baseLayoutStyle=="Stacked" then return "Stacked" end
	if self._adaptive and self._root and self._root.AbsoluteSize.X>0 and self._root.AbsoluteSize.X < self._window.Tokens:Get("ControlStackBreakpoint") then return "Stacked" end
	return "Inline"
end
function Base:_measure()
	local t=self._window.Tokens; local style=self._layoutStyle or self._baseLayoutStyle
	if style=="Stacked" then return t:Get("ControlHeight") + t:Get("FieldHeight") + 10 + (self.Description and 12 or 0) end
	return t:Get("ControlHeight") + (self.Description and 14 or 0)
end
function Base:_updateResponsiveLayout()
	if not self._root then return end
	local nextStyle=self:_effectiveLayout(); if nextStyle==self._layoutStyle then return end
	self._layoutStyle=nextStyle; self:_applyTokens()
end

function Base:_mount()
	if self._mounted or self._destroyed then return end; self._mounted=true
	local w=self._window; local t=w.Tokens; local h=self:_measure(); local pad=t:Get("ControlPadding")
	self._root=Create.New("CanvasGroup",{Name=self.Type.."_"..(self.Id or "Anonymous"),Size=UDim2.new(1,0,0,h),BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=self._order or 0,Parent=self._section:_controlParent(self)}); self._janitor:Add(self._root)
	self._janitor:Add(self._root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:_updateResponsiveLayout() end))
	Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("ControlRadius")),Parent=self._root}); w:_bind(self._root,{BackgroundColor3="ControlHover"})
	self._separator=Create.New("Frame",{Name="Separator",Size=UDim2.new(1,-pad*2,0,1),Position=UDim2.new(0,pad,1,-1),BorderSizePixel=0,BackgroundTransparency=0.72,Parent=self._root}); w:_bind(self._separator,{BackgroundColor3="BorderSubtle"})

	local titleWidth=if self._layoutStyle=="Stacked" then UDim2.new(1,-pad*2-76,0,t:Get("ControlHeight")) else UDim2.new(0.48,-pad,0,t:Get("ControlHeight"))
	self._titleLabel=Create.New("TextLabel",{Size=titleWidth,Position=UDim2.fromOffset(pad,0),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=t:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Text=self:_resolve(self.Title),Parent=self._root}); w:_bind(self._titleLabel,{TextColor3="Text"})
	if self.Description then
		self._descLabel=Create.New("TextLabel",{Size=UDim2.new(if self._layoutStyle=="Stacked" then 1 else 0.74,-pad*2,0,15),Position=UDim2.fromOffset(pad,t:Get("ControlHeight")-10),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=t:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Text=self:_resolve(self.Description),Parent=self._root}); w:_bind(self._descLabel,{TextColor3="TextTertiary"})
	end
	if self._layoutStyle=="Stacked" then
		local y=t:Get("ControlHeight")+(self.Description and 11 or 0)
		self._valueHost=Create.New("Frame",{Size=UDim2.new(1,-pad*2,0,t:Get("FieldHeight")),Position=UDim2.fromOffset(pad,y),BackgroundTransparency=1,Parent=self._root})
	else
		self._valueHost=Create.New("Frame",{Size=UDim2.new(0.52,-pad,0,t:Get("ControlHeight")),Position=UDim2.new(0.48,0,0,0),BackgroundTransparency=1,Parent=self._root})
	end
	if self._mountValue then self:_mountValue(self._valueHost) end

	self._janitor:Add(self._root.MouseEnter:Connect(function() self:_applyHoverVisual(true) end))
	self._janitor:Add(self._root.MouseLeave:Connect(function() self:_applyHoverVisual(false) end))
	if w.Interactions and (self._tooltip or self._contextMenu or self.Id or self._disabledReason) then self._janitor:Add(w.Interactions:Attach(self,self._root,function() return self._tooltip or self._disabledReason end,self._contextMenu)) end
	self:_applyVisible(); self:_applyDisabled(); self:_render(self:GetValue()); self._section:_refreshSeparators()
end

function Base:_applyHoverVisual(hover)
	if not self._root then return end
	self._root.BackgroundColor3=self._window.Theme:Get("ControlHover")
	self._root.BackgroundTransparency=if hover and not self._disabled then 0.62 else 1
end
function Base:_resolve(v) return self._window.Locale and self._window.Locale:Resolve(v) or v end
function Base:_refreshText()
	local title=self:_resolve(self.Title); local desc=self:_resolve(self.Description or "")
	if self._titleLabel then self._titleLabel.Text=title end; if self._descLabel then self._descLabel.Text=desc end
	self._window.Registry:Update(self,{Title=title,Description=desc,Path=`{self:_resolve(self._section._tab.Title)} -> {self:_resolve(self._section.Title or "Default")}`})
end
function Base:_applyTokens()
	if not self._root then return end; local t=self._window.Tokens; self._layoutStyle=self:_effectiveLayout(); local h=self:_measure(); local pad=t:Get("ControlPadding")
	self._root.Size=UDim2.new(1,0,0,h); local corner=self._root:FindFirstChildOfClass("UICorner"); if corner then corner.CornerRadius=UDim.new(0,t:Get("ControlRadius")) end
	if self._titleLabel then self._titleLabel.Position=UDim2.fromOffset(pad,0); self._titleLabel.TextSize=t:Get("FontBody"); self._titleLabel.Size=if self._layoutStyle=="Stacked" then UDim2.new(1,-pad*2-76,0,t:Get("ControlHeight")) else UDim2.new(0.48,-pad,0,t:Get("ControlHeight")) end
	if self._descLabel then self._descLabel.Position=UDim2.fromOffset(pad,t:Get("ControlHeight")-10); self._descLabel.TextSize=t:Get("FontSmall") end
	if self._separator then self._separator.Size=UDim2.new(1,-pad*2,0,1); self._separator.Position=UDim2.new(0,pad,1,-1) end
	if self._valueHost then
		if self._layoutStyle=="Stacked" then self._valueHost.Size=UDim2.new(1,-pad*2,0,t:Get("FieldHeight")); self._valueHost.Position=UDim2.fromOffset(pad,t:Get("ControlHeight")+(self.Description and 11 or 0))
		else self._valueHost.Size=UDim2.new(0.52,-pad,0,t:Get("ControlHeight")); self._valueHost.Position=UDim2.new(0.48,0,0,0) end
	end
	if self._applyValueTokens then self:_applyValueTokens() end
end
function Base:_render(value) end
function Base:GetValue() if self.Id and self._stateful then return self._window.State:Get(self.Id) end; return self._value end
function Base:SetValue(value,silent)
	if not self._stateful then self._value=value; if self._mounted then self:_render(value) end; if not silent then self.Changed:Fire(value,nil,self) end; return self end
	if self.Id then self._window.State:Set(self.Id,value,{Source=self,Silent=silent==true}) else local old=self._value; self._value=value; if self._mounted then self:_render(value) end; if not silent then if self.Callback then self.Callback(value) end; self.Changed:Fire(value,old,self) end end; return self
end
function Base:SetTitle(text) self.Title=text; if self._titleLabel then self._titleLabel.Text=self:_resolve(text) end; self._window.Registry:Update(self,{Title=text}); return self end
function Base:SetDescription(text) self.Description=text; if self._descLabel then self._descLabel.Text=self:_resolve(text or "") end; self._window.Registry:Update(self,{Description=text or ""}); if self._mounted then self:_applyTokens() end; return self end
function Base:SetKeywords(words) self.Keywords=words or {}; self._window.Registry:Update(self,{Keywords=self.Keywords}); return self end
function Base:_applyVisible() local visible=self._manualVisible and self._dependencyVisible; if self._root then self._root.Visible=visible end; self._window.Registry:Update(self,{Hidden=not visible}); if self._section and self._section._mounted then self._section:_refreshSeparators() end end
function Base:SetVisible(v) self._manualVisible=v==true; self:_applyVisible(); return self end
function Base:IsVisible() return self._manualVisible and self._dependencyVisible end
function Base:_applyDisabled()
	self._disabled=self._manualDisabled or not self._dependencyEnabled
	if self._root then self._root.GroupTransparency=if self._disabled then 0.42 else 0; self:_applyHoverVisual(false) end
end
function Base:SetDisabled(v,reason) self._manualDisabled=v==true; self._disabledReason=reason; self:_applyDisabled(); return self end
function Base:IsDisabled() return self._disabled==true end
function Base:SetLoading(v) self._loading=v==true; if self._setLoadingVisual then self:_setLoadingVisual(self._loading) end; return self end
function Base:SetBadge(text,style)
	if self._badge then self._badge:Destroy(); self._badge=nil end
	if text and self._root then local Badge=__require("primitives/Badge"); self._badge=Badge.new(self._window,text,style or "Neutral",self._root); self._badge.Position=UDim2.new(0.57,-6,0,13); self._badge.AnchorPoint=Vector2.new(1,0) end; return self
end
function Base:Reset(silent)
	if self.Id and self._stateful then self._window.State:Reset(self.Id,{Source=self,Silent=silent==true})
	elseif self._stateful then self:SetValue(self._default,silent) end
	return self
end
function Base:CopyValue()
	local value=self:GetValue(); local text
	if typeof(value)=="Color3" then text="#"..value:ToHex() elseif type(value)=="table" then
		local parts={}; for k,v in value do table.insert(parts,tostring(k).."="..tostring(v)) end; text=table.concat(parts,", ")
	else text=tostring(value) end
	local Env=__require("runtime/Env"); Env.SetClipboard(text); return text
end
function Base:PasteValue()
	if not self._stateful then return false,"not stateful" end
	local Env=__require("runtime/Env"); local raw=Env.GetClipboard(); if raw==nil then return false,"clipboard read unavailable" end
	local current=self:GetValue(); local value=raw
	local kind=typeof(current)
	if kind=="Color3" then
		local hex=string.gsub(raw,"#",""); local ok,c=pcall(Color3.fromHex,hex); if not ok then return false,"invalid color" end; value=c
	elseif type(current)=="number" then value=tonumber(raw); if value==nil then return false,"invalid number" end
	elseif type(current)=="boolean" then local v=string.lower(string.gsub(raw,"%s+","")); if v=="true" or v=="1" or v=="on" then value=true elseif v=="false" or v=="0" or v=="off" then value=false else return false,"invalid boolean" end
	elseif type(current)=="string" or current==nil then value=raw
	else return false,"value type is not pasteable" end
	self:SetValue(value); return true
end
function Base:Highlight(duration)
	if not self._root then return self end; local stroke=Create.New("UIStroke",{Thickness=1.5,Transparency=0.05,Parent=self._root}); self._window:_bind(stroke,{Color="Accent"}); task.delay(duration or 0.9,function() if stroke.Parent then stroke:Destroy() end end); return self
end
function Base:Reveal()
	self._section._tab:Select(); self._section:SetCollapsed(false); task.defer(function() if self._root and self._root.Parent then local page=self._section._tab._page; local top=self._root.AbsolutePosition.Y-page.AbsolutePosition.Y+page.CanvasPosition.Y; self._window.Motion:Tween(page,"Normal",{CanvasPosition=Vector2.new(0,math.max(0,top-24))}); self:Highlight() end end); return self
end
function Base:OnChanged(fn) return self.Changed:Connect(fn) end
function Base:GetInstance() return self._root end
function Base:Destroy() if self._destroyed then return end; self._destroyed=true; self._section._janitor:Release(self); self._window.Registry:Remove(self); self.Changed:Destroy(); self._janitor:Destroy(); self._section:_removeControl(self) end
return Base

end

__modules["controls/Button"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Base=__require("controls/Base")
local Signal=__require("runtime/Signal")
local Spinner=__require("primitives/Spinner")
local Button=setmetatable({}, {__index=Base}); Button.__index=Button
function Button.new(section,options)
	local self=setmetatable({},Button); Base.init(self,section,"Button",options,{Stateful=false,Persist=false,Adaptive=true}); self.Variant=options.Variant or "Default"; self.Text=options.Text or options.Title or "Run"; self.Confirm=options.Confirm; self.Clicked=Signal.new("Button.Clicked"); self._janitor:Add(self.Clicked); return Base.finish(self)
end
function Button:_tokens()
	if self.Variant=="Primary" then return "AccentButton","AccentText" end
	if self.Variant=="Danger" then return "Error","AccentText" end
	if self.Variant=="Ghost" then return "ControlInset","TextSecondary" end
	return "SurfaceSecondary","Text"
end
function Button:_mountValue(host)
	local w=self._window; local bg,fg=self:_tokens(); local h=w.Tokens:Get("FieldHeight")
	self._button=Create.New("TextButton",{Size=UDim2.new(1,0,0,h),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BorderSizePixel=0,AutoButtonColor=false,Text=self:_resolve(self.Text),Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontBody"),Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("FieldRadius")),Parent=self._button}); self._stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.55,Parent=self._button}); w:_bind(self._stroke,{Color=if self.Variant=="Primary" then "AccentBorder" else "BorderSubtle"}); w:_bind(self._button,{BackgroundColor3=bg,TextColor3=fg})
	self._janitor:Add(self._button.MouseEnter:Connect(function() if not self._loading then self._button.BackgroundColor3=w.Theme:Get(if self.Variant=="Primary" then "AccentButtonHover" else "SurfaceHover") end end)); self._janitor:Add(self._button.MouseLeave:Connect(function() self._button.BackgroundColor3=w.Theme:Get(bg) end)); self._janitor:Add(self._button.MouseButton1Click:Connect(function() self:Click() end))
end
function Button:Click()
	if self:IsDisabled() or self._loading then return self end
	if self._window.Sound then self._window.Sound:Play("Click") end
	local function run() if self.Callback then local ok,err=xpcall(self.Callback,debug.traceback); if not ok then warn(`[BobloUI] Button "{self.Title}" callback failed:\n{err}`) end end; self.Clicked:Fire() end
	if self.Confirm and self._window.Dialog then task.spawn(function() local ok=self._window.Dialog:Confirm({Title=self.Title,Content=self.Confirm}):Await(); if ok then run() end end) else run() end; return self
end
function Button:_setLoadingVisual(v)
	if not self._button then return end; self._button.Text=if v then "" else self:_resolve(self.Text); if self._spinner then self._spinner:Destroy(); self._spinner=nil end
	if v then self._spinner=Spinner.new(self._window,self._button,15); self._spinner.Position=UDim2.fromScale(0.5,0.5); self._spinner.AnchorPoint=Vector2.new(0.5,0.5) end
end
function Button:_refreshText() Base._refreshText(self); if self._button and not self._loading then self._button.Text=self:_resolve(self.Text) end end
function Button:_applyValueTokens() if self._button then self._button.Size=UDim2.new(1,0,0,self._window.Tokens:Get("FieldHeight")); self._button.TextSize=self._window.Tokens:Get("FontBody") end end
return Button

end

__modules["controls/ColorPicker"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Base=__require("controls/Base")
local Popover=__require("primitives/Popover")
local Sheet=__require("primitives/Sheet")
local Util=__require("runtime/Util")
local ColorPicker=setmetatable({}, {__index=Base}); ColorPicker.__index=ColorPicker

local HUE=ColorSequence.new({
	ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)), ColorSequenceKeypoint.new(1/6,Color3.fromHSV(1/6,1,1)),
	ColorSequenceKeypoint.new(2/6,Color3.fromHSV(2/6,1,1)), ColorSequenceKeypoint.new(3/6,Color3.fromHSV(3/6,1,1)),
	ColorSequenceKeypoint.new(4/6,Color3.fromHSV(4/6,1,1)), ColorSequenceKeypoint.new(5/6,Color3.fromHSV(5/6,1,1)),
	ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1)),
})

function ColorPicker.new(section,options)
	local self=setmetatable({},ColorPicker); self.Alpha=options.Alpha==true; self.Presets=options.Presets or {}; self._popup=nil
	local d=options.Default or Color3.new(1,1,1); if self.Alpha then d={Color=d,Alpha=math.clamp(options.DefaultAlpha or 1,0,1)} end
	Base.init(self,section,"ColorPicker",options,{Stateful=true,Default=d,Adaptive=true}); return Base.finish(self)
end
function ColorPicker:_colour(v) return self.Alpha and (type(v)=="table" and v.Color or Color3.new(1,1,1)) or v end
function ColorPicker:_mountValue(host)
	local w=self._window; local t=w.Tokens
	self._button=Create.New("TextButton",{Size=UDim2.new(1,0,0,t:Get("FieldHeight")),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=0,BorderSizePixel=0,AutoButtonColor=false,Text="",Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("FieldRadius")),Parent=self._button}); self._triggerStroke=Create.New("UIStroke",{Thickness=1,Transparency=0.62,Parent=self._button}); w:_bind(self._triggerStroke,{Color="BorderSubtle"}); w:_bind(self._button,{BackgroundColor3="ControlInset"})
	self._hexLabel=Create.New("TextLabel",{Size=UDim2.new(1,-44,1,0),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=t:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,Parent=self._button}); w:_bind(self._hexLabel,{TextColor3="TextSecondary"})
	self._swatch=Create.New("Frame",{Size=UDim2.fromOffset(24,18),Position=UDim2.new(1,-8,0.5,0),AnchorPoint=Vector2.new(1,0.5),BorderSizePixel=0,Parent=self._button}); Create.New("UICorner",{CornerRadius=UDim.new(0,6),Parent=self._swatch}); Create.New("UIStroke",{Thickness=1,Color=Color3.new(1,1,1),Transparency=0.76,Parent=self._swatch})
	self._janitor:Add(self._button.MouseEnter:Connect(function() if not self._popup then self._button.BackgroundColor3=w.Theme:Get("ControlHover") end end)); self._janitor:Add(self._button.MouseLeave:Connect(function() if not self._popup then self._button.BackgroundColor3=w.Theme:Get("ControlInset") end end)); self._janitor:Add(self._button.MouseButton1Click:Connect(function() if not self:IsDisabled() then if self._popup then self:Close() else self:Open() end end end))
end
function ColorPicker:_render(v)
	local c=self:_colour(v); if typeof(c)~="Color3" then c=Color3.new(1,1,1) end
	if self._swatch then self._swatch.BackgroundColor3=c; self._hexLabel.Text=Util.toHex(c) end; self:_syncPopup(c)
end
function ColorPicker:_syncPopup(c)
	if not self._sv then return end
	local h,s,v=c:ToHSV(); self._h=h; self._s=s; self._v=v; self._sv.BackgroundColor3=Color3.fromHSV(h,1,1); self._svCursor.Position=UDim2.fromScale(s,1-v); self._hueCursor.Position=UDim2.fromScale(h,0.5)
	if self._hexBox and not self._hexBox:IsFocused() then self._hexBox.Text=Util.toHex(c) end
	if self._rgbBoxes then local vals={math.round(c.R*255),math.round(c.G*255),math.round(c.B*255)}; for i,b in self._rgbBoxes do if not b:IsFocused() then b.Text=tostring(vals[i]) end end end
	if self._alphaBox and not self._alphaBox:IsFocused() then self._alphaBox.Text=tostring(math.round(self:GetAlpha()*100)).."%" end
end
function ColorPicker:_fieldStroke(box)
	local w=self._window; local s=Create.New("UIStroke",{Thickness=1,Transparency=0.55,Parent=box}); w:_bind(s,{Color="BorderSubtle"})
	box.Focused:Connect(function() s.Transparency=0.10; s.Color=w.Theme:Get("AccentBorder") end); box.FocusLost:Connect(function() s.Transparency=0.55; s.Color=w.Theme:Get("BorderSubtle") end)
end
function ColorPicker:_buildPopup(frame)
	local w=self._window; local c=self:_colour(self:GetValue()); local h,s,v=c:ToHSV(); self._h=h; self._s=s; self._v=v
	local top=if w.Device.Layout=="Drawer" then 20 else 8
	local sv=Create.New("Frame",{Name="SV",Size=UDim2.new(1,-16,0,94),Position=UDim2.fromOffset(8,top),BackgroundColor3=Color3.fromHSV(h,1,1),BorderSizePixel=0,ClipsDescendants=true,Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=sv}); self._sv=sv
	local white=Create.New("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Parent=sv}); Create.New("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}),Parent=white})
	local black=Create.New("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,Parent=sv}); Create.New("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}),Parent=black})
	self._svCursor=Create.New("Frame",{Size=UDim2.fromOffset(11,11),Position=UDim2.fromScale(s,1-v),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,ZIndex=4,Parent=sv}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._svCursor}); Create.New("UIStroke",{Thickness=2,Color=Color3.new(1,1,1),Parent=self._svCursor})
	local svHit=Create.New("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",ZIndex=5,Parent=sv})
	local function setSV(pos) local x=math.clamp((pos.X-sv.AbsolutePosition.X)/math.max(1,sv.AbsoluteSize.X),0,1); local y=math.clamp((pos.Y-sv.AbsolutePosition.Y)/math.max(1,sv.AbsoluteSize.Y),0,1); self._s=x; self._v=1-y; self:_setColour(Color3.fromHSV(self._h,self._s,self._v)) end
	svHit.InputBegan:Connect(function(i) if i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch then return end; setSV(i.Position); w.Input:CapturePointer(self,i,function(move) setSV(move.Position) end,function() end) end)

	local hueY=top+102
	local hue=Create.New("Frame",{Name="Hue",Size=UDim2.new(1,-16,0,12),Position=UDim2.fromOffset(8,hueY),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ClipsDescendants=false,Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=hue}); Create.New("UIGradient",{Color=HUE,Parent=hue}); self._hue=hue
	self._hueCursor=Create.New("Frame",{Size=UDim2.fromOffset(4,18),Position=UDim2.fromScale(h,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=4,Parent=hue}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._hueCursor}); Create.New("UIStroke",{Thickness=1,Color=Color3.new(0,0,0),Transparency=0.5,Parent=self._hueCursor})
	local hueHit=Create.New("TextButton",{Size=UDim2.new(1,0,0,26),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,Text="",ZIndex=5,Parent=hue})
	local function setHue(pos) self._h=math.clamp((pos.X-hue.AbsolutePosition.X)/math.max(1,hue.AbsoluteSize.X),0,1); self:_setColour(Color3.fromHSV(self._h,self._s,self._v)) end
	hueHit.InputBegan:Connect(function(i) if i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch then return end; setHue(i.Position); w.Input:CapturePointer(self,i,function(move) setHue(move.Position) end,function() end) end)

	local fieldsY=top+126
	self._hexBox=Create.New("TextBox",{Size=UDim2.new(0.36,-5,0,28),Position=UDim2.fromOffset(8,fieldsY),BackgroundTransparency=0,BorderSizePixel=0,ClearTextOnFocus=false,Text=Util.toHex(c),Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=self._hexBox}); w:_bind(self._hexBox,{BackgroundColor3="ControlInset",TextColor3="Text"}); self:_fieldStroke(self._hexBox)
	local boxes={}; self._rgbBoxes=boxes
	for i in {1,2,3} do local box=Create.New("TextBox",{Size=UDim2.new(0.213,-4,0,28),Position=UDim2.new(0.36+(i-1)*0.213,4,0,fieldsY),BackgroundTransparency=0,BorderSizePixel=0,ClearTextOnFocus=false,Text=tostring(math.round(({c.R,c.G,c.B})[i]*255)),Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=box}); w:_bind(box,{BackgroundColor3="ControlInset",TextColor3="Text"}); self:_fieldStroke(box); boxes[i]=box end
	local function commitBoxes() local r=math.clamp(tonumber(boxes[1].Text) or 0,0,255); local g=math.clamp(tonumber(boxes[2].Text) or 0,0,255); local b=math.clamp(tonumber(boxes[3].Text) or 0,0,255); self:_setColour(Color3.fromRGB(r,g,b)) end
	for _,box in boxes do box.FocusLost:Connect(commitBoxes) end
	self._hexBox.FocusLost:Connect(function() local raw=string.gsub(self._hexBox.Text,"#",""); local ok,new=pcall(Color3.fromHex,raw); if ok then self:_setColour(new) else self:_syncPopup(self:_colour(self:GetValue())) end end)

	local nextY=fieldsY+36
	if self.Alpha then
		local alphaLabel=Create.New("TextLabel",{Size=UDim2.new(0.55,0,0,28),Position=UDim2.fromOffset(8,nextY),BackgroundTransparency=1,Text="Alpha",Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,Parent=frame}); w:_bind(alphaLabel,{TextColor3="TextSecondary"})
		self._alphaBox=Create.New("TextBox",{Size=UDim2.new(0.35,-8,0,28),Position=UDim2.new(0.65,0,0,nextY),BackgroundTransparency=0,BorderSizePixel=0,ClearTextOnFocus=false,Text=tostring(math.round(self:GetAlpha()*100)).."%",Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=self._alphaBox}); w:_bind(self._alphaBox,{BackgroundColor3="ControlInset",TextColor3="Text"}); self:_fieldStroke(self._alphaBox); self._alphaBox.FocusLost:Connect(function() local n=tonumber(string.gsub(self._alphaBox.Text,"%%","")); if n then self:SetAlpha(math.clamp(n/100,0,1)) else self:_syncPopup(self:_colour(self:GetValue())) end end); nextY+=34
	end
	if #self.Presets>0 then
		local row=Create.New("Frame",{Size=UDim2.new(1,-16,0,24),Position=UDim2.fromOffset(8,nextY),BackgroundTransparency=1,Parent=frame}); Create.List(6,Enum.FillDirection.Horizontal).Parent=row
		for _,p in self.Presets do if typeof(p)=="Color3" then local b=Create.New("TextButton",{Size=UDim2.fromOffset(24,24),BackgroundColor3=p,Text="",BorderSizePixel=0,Parent=row}); Create.New("UICorner",{CornerRadius=UDim.new(0,6),Parent=b}); Create.New("UIStroke",{Thickness=1,Color=Color3.new(1,1,1),Transparency=0.78,Parent=b}); b.MouseButton1Click:Connect(function() self:_setColour(p) end) end end
	end
	self:_syncPopup(c)
end
function ColorPicker:_clearPopupRefs() self._sv=nil; self._hue=nil; self._svCursor=nil; self._hueCursor=nil; self._hexBox=nil; self._rgbBoxes=nil; self._alphaBox=nil end
function ColorPicker:_setColour(c) if self.Alpha then local v=table.clone(self:GetValue() or {}); v.Color=c; v.Alpha=v.Alpha or 1; self:SetValue(v) else self:SetValue(c) end end
function ColorPicker:_popupHeight()
	local base=178; if self.Alpha then base+=34 end; if #self.Presets>0 then base+=32 end; if self._window.Device.Layout=="Drawer" then base+=12 end; return base
end
function ColorPicker:Open()
	if self._window.Sound then self._window.Sound:Play("Open") end
	if self._popup then return self end; local height=self:_popupHeight(); local h
	local function dismissed() self._popup=nil; self:_clearPopupRefs(); self._window.Input:CancelCapture(self) end
	if self._window.Device.Layout=="Drawer" then h=Sheet.open(self._window,height,{OnDismiss=dismissed}) else h=Popover.open(self._window,self._button,Vector2.new(248,height),{OnDismiss=dismissed,Corner=8}) end
	self._popup=h; self:_buildPopup(h.Frame); return self
end
function ColorPicker:Close() if self._popup then local h=self._popup; self._popup=nil; self._window.Input:CancelCapture(self); self:_clearPopupRefs(); h:Dismiss() end; return self end
function ColorPicker:SetAlpha(a) if not self.Alpha then return self end; local v=table.clone(self:GetValue() or {}); v.Alpha=math.clamp(tonumber(a) or 1,0,1); return self:SetValue(v) end
function ColorPicker:GetAlpha() local v=self:GetValue(); return self.Alpha and type(v)=="table" and tonumber(v.Alpha) or 1 end
function ColorPicker:Destroy() self:Close(); Base.Destroy(self) end
function ColorPicker:_applyValueTokens() if self._button then self._button.Size=UDim2.new(1,0,0,self._window.Tokens:Get("FieldHeight")); self._hexLabel.TextSize=self._window.Tokens:Get("FontSmall") end end
return ColorPicker

end

__modules["controls/Divider"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Base=__require("controls/Base")
local Divider=setmetatable({}, {__index=Base}); Divider.__index=Divider

function Divider.new(section,options)
	options=options or {}
	local self=setmetatable({},Divider)
	Base.init(self,section,"Divider",options,{Stateful=false,Persist=false})
	self._window.Registry:Update(self,{Title=self:_resolve(self.Title or "Divider")})
	return Base.finish(self)
end
function Divider:_mount()
	if self._mounted or self._destroyed then return end; self._mounted=true
	local w=self._window
	self._root=Create.New("CanvasGroup",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,LayoutOrder=self._order,Parent=self._section._content}); self._janitor:Add(self._root)
	self._line=Create.New("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,0.5,0),BorderSizePixel=0,Parent=self._root}); w:_bind(self._line,{BackgroundColor3="BorderSubtle"})
	if self.Title and self.Title~="" then
		self._titleLabel=Create.New("TextLabel",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,1,0),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=0,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),Text="  "..self:_resolve(self.Title).."  ",Parent=self._root}); w:_bind(self._titleLabel,{BackgroundColor3="Surface",TextColor3="TextTertiary"})
	end
	if w.Interactions and (self._tooltip or self._contextMenu or self.Id) then self._janitor:Add(w.Interactions:Attach(self,self._root,self._tooltip,self._contextMenu)) end
	self:_applyVisible(); self:_applyDisabled()
end
function Divider:SetTitle(t) self.Title=t; if self._titleLabel then self._titleLabel.Text="  "..self:_resolve(t or "").."  " end; self._window.Registry:Update(self,{Title=self:_resolve(t or "Divider")}); return self end
function Divider:_applyTokens() if self._titleLabel then self._titleLabel.TextSize=self._window.Tokens:Get("FontSmall") end end
function Divider:_refreshText()
	if self._titleLabel then self._titleLabel.Text="  "..self:_resolve(self.Title or "").."  " end
	self._window.Registry:Update(self,{Title=self:_resolve(self.Title or "Divider"),Path=`{self:_resolve(self._section._tab.Title)} -> {self:_resolve(self._section.Title or "Default")}`})
end
return Divider

end

__modules["controls/Dropdown"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Base=__require("controls/Base")
local Popover=__require("primitives/Popover")
local Sheet=__require("primitives/Sheet")
local Scroller=__require("primitives/Scroller")
local Icon=__require("primitives/Icon")
local Dropdown=setmetatable({}, {__index=Base}); Dropdown.__index=Dropdown

local ROW_HEIGHT=32
local ROW_GAP=2
local MAX_VISIBLE_ROWS=7

local function normalize(options)
	local out={}
	for _,o in options or {} do
		if type(o)=="table" and o.Value~=nil then table.insert(out,{Value=o.Value,Label=tostring(o.Label or o.Value),Icon=o.Icon})
		else table.insert(out,{Value=o,Label=tostring(o)}) end
	end
	return out
end
local function contains(list,value) for _,v in list do if v==value then return true end end; return false end

function Dropdown.new(section,options)
	local self=setmetatable({},Dropdown)
	self.Multi=options.Multi==true
	self.Style=options.Style or "Dropdown"; if self.Style=="Segmented" and self.Multi then error("[BobloUI] segmented Dropdown does not support Multi=true.",3) end
	self.Searchable=if options.Searchable==nil then #(options.Options or {})>8 else options.Searchable
	self.AllowNone=options.AllowNone==true; self.Max=options.Max; self.Placeholder=options.Placeholder or "Select..."
	self._options=normalize(options.Options or {}); self._popup=nil
	local default=options.Default; if self.Multi and default==nil then default={} end
	Base.init(self,section,"Dropdown",options,{Stateful=true,Default=default,Adaptive=true}); return Base.finish(self)
end

function Dropdown:_mountValue(host)
	if self.Style=="Segmented" then return self:_mountSegmented(host) end
	local w=self._window; local t=w.Tokens
	self._button=Create.New("TextButton",{Size=UDim2.new(1,0,0,t:Get("FieldHeight")),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BorderSizePixel=0,AutoButtonColor=false,Text="",Parent=host})
	Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("FieldRadius")),Parent=self._button})
	self._stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.62,Parent=self._button}); w:_bind(self._stroke,{Color="BorderSubtle"}); w:_bind(self._button,{BackgroundColor3="ControlInset"})
	self._valueLabel=Create.New("TextLabel",{Size=UDim2.new(1,-32,1,0),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=t:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Text="",Parent=self._button}); w:_bind(self._valueLabel,{TextColor3="Text"})
	self._arrow=Icon.new(w,"chevron_down",{Size=UDim2.fromOffset(15,15),Position=UDim2.new(1,-9,0.5,0),AnchorPoint=Vector2.new(1,0.5),Parent=self._button})
	self._janitor:Add(self._button.MouseEnter:Connect(function() if not self._popup then self._button.BackgroundColor3=w.Theme:Get("ControlHover") end end))
	self._janitor:Add(self._button.MouseLeave:Connect(function() if not self._popup then self._button.BackgroundColor3=w.Theme:Get("ControlInset") end end))
	self._janitor:Add(self._button.MouseButton1Click:Connect(function() if not self:IsDisabled() then if self._popup then self:Close() else self:Open() end end end))
end

function Dropdown:_mountSegmented(host)
	local w=self._window; local t=w.Tokens
	self._segmentHost=Create.New("Frame",{Size=UDim2.new(1,0,0,t:Get("FieldHeight")),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=0,BorderSizePixel=0,Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("FieldRadius")),Parent=self._segmentHost}); local stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.62,Parent=self._segmentHost}); w:_bind(stroke,{Color="BorderSubtle"}); w:_bind(self._segmentHost,{BackgroundColor3="ControlInset"}); Create.List(2,Enum.FillDirection.Horizontal).Parent=self._segmentHost
	self._segments={}; for _,o in self._options do
		local b=Create.New("TextButton",{Size=UDim2.new(1/math.max(1,#self._options),-2,1,-4),BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,Text=o.Label,Font=w.Fonts.Medium,TextSize=t:Get("FontSmall"),Parent=self._segmentHost}); Create.New("UICorner",{CornerRadius=UDim.new(0,math.max(4,t:Get("FieldRadius")-2)),Parent=b}); w:_bind(b,{BackgroundColor3="AccentSoft",TextColor3="TextSecondary"}); self._segments[o.Value]=b; self._janitor:Add(b.MouseButton1Click:Connect(function() if not self:IsDisabled() then self:SetValue(o.Value) end end))
	end
end
function Dropdown:_renderSegments(v)
	if not self._segments then return end; local w=self._window; for value,b in self._segments do local on=value==v; b.BackgroundTransparency=if on then 0 else 1; b.TextColor3=w.Theme:Get(if on then "Text" else "TextSecondary") end
end
function Dropdown:_labelFor(value) for _,o in self._options do if o.Value==value then return o.Label end end; return tostring(value) end
function Dropdown:_display(value)
	if self.Multi then
		if type(value)~="table" or #value==0 then return self.Placeholder end
		local labels={}; for _,v in value do table.insert(labels,self:_labelFor(v)) end
		if #labels>3 then return `{#labels} selected` end
		return table.concat(labels,", ")
	end
	if value==nil then return self.Placeholder end
	return self:_labelFor(value)
end
function Dropdown:_render(v)
	if self.Style=="Segmented" then self:_renderSegments(v); return end
	if self._valueLabel then
		local empty=v==nil or (type(v)=="table" and #v==0)
		self._valueLabel.Text=self:_display(v); self._valueLabel.TextColor3=self._window.Theme:Get(empty and "TextTertiary" or "Text")
	end
end
function Dropdown:_select(value)
	if self._window.Sound then self._window.Sound:Play("Select") end
	if self.Multi then
		local current=table.clone(self:GetValue() or {}); local p=table.find(current,value)
		if p then table.remove(current,p) else if self.Max and #current>=self.Max then return end; table.insert(current,value) end
		self:SetValue(current); self:_rebuildPopup()
	else self:SetValue(value); self:Close() end
end

function Dropdown:_filteredCount()
	local query=(self._search and string.lower(self._search.Text)) or ""; local n=0
	for _,o in self._options do if query=="" or string.find(string.lower(o.Label),query,1,true) then n+=1 end end
	return n
end
function Dropdown:_popupMetrics(count)
	local drawer=self._window.Device.Layout=="Drawer"
	local top=if drawer then 20 else 8
	local searchBlock=if self.Searchable then 42 else 0
	local listTop=top+searchBlock
	local rows=math.max(1,math.min(MAX_VISIBLE_ROWS,count))
	local listHeight=rows*ROW_HEIGHT+math.max(0,rows-1)*ROW_GAP
	local height=listTop+listHeight+8
	local triggerWidth=self._button and self._button.AbsoluteSize.X or 180
	local minWidth=if self.Searchable then 220 else 176
	local width=math.min(math.max(triggerWidth,minWidth),320)
	return Vector2.new(width,height),listTop
end
function Dropdown:_resizePopup(count)
	if not self._popup then return end
	local size=self:_popupMetrics(count)
	if self._window.Device.Layout=="Drawer" then if self._popup.SetHeight then self._popup:SetHeight(math.min(440,size.Y)) end
	elseif self._popup.SetSize then self._popup:SetSize(size) end
end

function Dropdown:_buildPopup(frame)
	local w=self._window; local t=w.Tokens; frame.ClipsDescendants=true
	local size,listTop=self:_popupMetrics(#self._options)
	local top=if w.Device.Layout=="Drawer" then 20 else 8
	if self.Searchable then
		local field=Create.New("Frame",{Size=UDim2.new(1,-16,0,34),Position=UDim2.fromOffset(8,top),BackgroundTransparency=0,BorderSizePixel=0,Parent=frame})
		Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("FieldRadius")),Parent=field}); local s=Create.New("UIStroke",{Thickness=1,Transparency=0.46,Parent=field}); w:_bind(s,{Color="BorderSubtle"}); w:_bind(field,{BackgroundColor3="ControlInset"})
		local icon=Icon.new(w,"search",{Size=UDim2.fromOffset(14,14),Position=UDim2.fromOffset(10,10),Parent=field}); Icon.setColor(icon,w.Theme:Get("TextTertiary"))
		self._search=Create.New("TextBox",{Size=UDim2.new(1,-34,1,0),Position=UDim2.fromOffset(30,0),BackgroundTransparency=1,BorderSizePixel=0,ClearTextOnFocus=false,PlaceholderText="Search...",Text="",Font=w.Fonts.Regular,TextSize=t:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Parent=field})
		w:_bind(self._search,{TextColor3="Text",PlaceholderColor3="TextTertiary"})
		self._popupSearchConn=self._search:GetPropertyChangedSignal("Text"):Connect(function() self:_rebuildPopup() end)
	end
	self._list=Scroller.new(w,{Size=UDim2.new(1,-12,1,-listTop-6),Position=UDim2.fromOffset(6,listTop),Parent=frame})
	Create.New("UIPadding",{PaddingTop=UDim.new(0,0),PaddingBottom=UDim.new(0,0),PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,2),Parent=self._list})
	Create.List(ROW_GAP).Parent=self._list
	self:_rebuildPopup()
end

function Dropdown:_rebuildPopup()
	if not self._list then return end
	for _,child in self._list:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	local query=(self._search and string.lower(self._search.Text)) or ""; local selected=self:GetValue(); local w=self._window; local visible=0
	for _,o in self._options do
		if query=="" or string.find(string.lower(o.Label),query,1,true) then
			visible+=1
			local isSelected=if self.Multi then contains(selected or {},o.Value) else selected==o.Value
			local b=Create.New("TextButton",{Size=UDim2.new(1,0,0,ROW_HEIGHT),BackgroundTransparency=if isSelected then 0 else 1,BorderSizePixel=0,AutoButtonColor=false,Text="",Parent=self._list})
			Create.New("UICorner",{CornerRadius=UDim.new(0,7),Parent=b}); w:_bind(b,{BackgroundColor3="AccentSoft"})
			local mark=Create.New("Frame",{Size=UDim2.fromOffset(20,ROW_HEIGHT),Position=UDim2.fromOffset(2,0),BackgroundTransparency=1,Parent=b})
			if isSelected then local check=Icon.new(w,"check",{Size=UDim2.fromOffset(12,12),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),Parent=mark}); Icon.setColor(check,w.Theme:Get("Accent")) end
			local label=Create.New("TextLabel",{Size=UDim2.new(1,-28,1,0),Position=UDim2.fromOffset(24,0),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Text=o.Label,Parent=b}); w:_bind(label,{TextColor3=if isSelected then "Text" else "TextSecondary"})
			b.MouseEnter:Connect(function() if not isSelected then b.BackgroundTransparency=0; b.BackgroundColor3=w.Theme:Get("ControlHover") end end)
			b.MouseLeave:Connect(function() b.BackgroundTransparency=if isSelected then 0 else 1 end)
			b.MouseButton1Click:Connect(function() self:_select(o.Value) end)
		end
	end
	if visible==0 then
		local empty=Create.New("TextLabel",{Size=UDim2.new(1,0,0,ROW_HEIGHT),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),Text="No matches",Parent=self._list}); w:_bind(empty,{TextColor3="TextTertiary"})
	end
	self:_resizePopup(visible)
end

function Dropdown:_clearPopupRefs()
	if self._popupSearchConn then self._popupSearchConn:Disconnect(); self._popupSearchConn=nil end
	self._search=nil; self._list=nil
end
function Dropdown:Open()
	if self._window.Sound then self._window.Sound:Play("Open") end
	if self.Style=="Segmented" then return self end
	if self._popup then return self end
	local size=self:_popupMetrics(#self._options); local handle
	local function dismissed()
		self._popup=nil; self:_clearPopupRefs()
		if self._arrow then self._arrow.Rotation=0 end
		if self._button then self._button.BackgroundColor3=self._window.Theme:Get("ControlInset") end
		if self._stroke then self._stroke.Color=self._window.Theme:Get("BorderSubtle") end
	end
	if self._window.Device.Layout=="Drawer" then handle=Sheet.open(self._window,math.min(440,size.Y),{OnDismiss=dismissed})
	else handle=Popover.open(self._window,self._button,size,{OnDismiss=dismissed,Corner=8}) end
	self._popup=handle; self:_buildPopup(handle.Frame)
	self._arrow.Rotation=180; self._button.BackgroundColor3=self._window.Theme:Get("ControlHover"); self._stroke.Color=self._window.Theme:Get("AccentBorder")
	return self
end
function Dropdown:Close()
	if self._popup then local h=self._popup; self._popup=nil; self:_clearPopupRefs(); h:Dismiss() end
	if self._arrow then self._arrow.Rotation=0 end
	return self
end
function Dropdown:SetOptions(list)
	self._options=normalize(list or {}); local current=self:GetValue()
	if self.Multi then
		local kept={}; for _,v in current or {} do for _,o in self._options do if o.Value==v then table.insert(kept,v); break end end end; self:SetValue(kept,true)
	else
		local exists=false; for _,o in self._options do if o.Value==current then exists=true break end end
		if not exists then self:SetValue(if self.AllowNone then nil else (self._options[1] and self._options[1].Value or nil),true) end
	end
	if self.Style=="Segmented" and self._segmentHost then local host=self._valueHost; self._segmentHost:Destroy(); self._segmentHost=nil; self._segments=nil; self:_mountSegmented(host) else self:_rebuildPopup() end; self:_render(self:GetValue()); return self
end
function Dropdown:Refresh(list) if list~=nil then return self:SetOptions(list) end; self:_rebuildPopup(); return self end
function Dropdown:AddOption(o) local n=normalize({o})[1]; if n then table.insert(self._options,n) end; self:_rebuildPopup(); return self end
function Dropdown:RemoveOption(value) for i=#self._options,1,-1 do if self._options[i].Value==value then table.remove(self._options,i) end end; return self:SetOptions(self._options) end
function Dropdown:Destroy() self:Close(); Base.Destroy(self) end
function Dropdown:_applyValueTokens() if self._button then self._button.Size=UDim2.new(1,0,0,self._window.Tokens:Get("FieldHeight")); self._valueLabel.TextSize=self._window.Tokens:Get("FontBody") end; if self._segmentHost then self._segmentHost.Size=UDim2.new(1,0,0,self._window.Tokens:Get("FieldHeight")); for _,b in self._segments or {} do b.TextSize=self._window.Tokens:Get("FontSmall") end end end
return Dropdown

end

__modules["controls/Keybind"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Base=__require("controls/Base")
local Keybind=setmetatable({}, {__index=Base}); Keybind.__index=Keybind
local function keyName(key) if typeof(key)=="EnumItem" then return key.Name end; if type(key)=="table" then return key.Key end; return tostring(key or "None") end
local function enumKey(name) if typeof(name)=="EnumItem" then return name end; if type(name)=="string" then return Enum.KeyCode[name] or Enum.UserInputType[name] end; return nil end
function Keybind.new(section,options)
	local self=setmetatable({},Keybind); self.Mode=options.Mode or "Toggle"; self._actionCallback=options.Callback; local baseOptions=table.clone(options); baseOptions.Callback=nil; if section._window.Device.Class=="Phone" and baseOptions.Visible==nil then baseOptions.Visible=false end; self.AllowedModes=options.AllowedModes or {"Toggle","Hold","Always"}; if not table.find(self.AllowedModes,self.Mode) then error(`[BobloUI] keybind mode "{self.Mode}" is not allowed.`,3) end; self.Blacklist=options.Blacklist or {}; self._binding=nil; self._capturing=false; local d=options.Default; local stored={Key=keyName(d or Enum.KeyCode.E),Mode=self.Mode}; Base.init(self,section,"Keybind",baseOptions,{Stateful=true,Default=stored,Adaptive=true}); return Base.finish(self)
end
function Keybind:_mountValue(host)
	local w=self._window; local t=w.Tokens
	self._button=Create.New("TextButton",{Size=UDim2.new(1,0,0,t:Get("FieldHeight")),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BorderSizePixel=0,AutoButtonColor=false,Text="",Font=w.Fonts.Medium,TextSize=t:Get("FontSmall"),Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("FieldRadius")),Parent=self._button}); self._stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.62,Parent=self._button}); w:_bind(self._stroke,{Color="BorderSubtle"}); w:_bind(self._button,{BackgroundColor3="ControlInset",TextColor3="TextSecondary"}); self._janitor:Add(self._button.MouseEnter:Connect(function() self._button.BackgroundColor3=w.Theme:Get("SurfaceHover") end)); self._janitor:Add(self._button.MouseLeave:Connect(function() if not self._capturing then self._button.BackgroundColor3=w.Theme:Get("ControlInset") end end)); self._janitor:Add(self._button.MouseButton1Click:Connect(function() if not self:IsDisabled() then self:Capture() end end)); self:_rebind()
end
function Keybind:_render(v) if type(v)=="table" then self.Mode=v.Mode or self.Mode end; if self._button then self._button.Text=if self._capturing then "Press a key…" else `{keyName(v)}  ·  {self.Mode}`; self._button.BackgroundColor3=self._window.Theme:Get(self._capturing and "AccentSoft" or "ControlInset"); self._stroke.Color=self._window.Theme:Get(self._capturing and "AccentBorder" or "BorderSubtle"); self:_rebind() end end
function Keybind:_rebind() if self._binding then self._binding:Destroy(); self._binding=nil end; local v=self:GetValue(); if not self._mounted or type(v)~="table" then return end; local key=enumKey(v.Key); if not key then return end; self._binding=self._window.Input:BindKey(self.Id or tostring(self),key,v.Mode or self.Mode,function(active) if self._actionCallback then local ok,err=xpcall(self._actionCallback,debug.traceback,active); if not ok then warn(err) end end end); self._janitor:Add(self._binding,"Destroy","keybinding") end
function Keybind:Capture()
	if self._capturing then return self end
	self._capturing=true; self:_render(self:GetValue())
	local cancel=self._window.Input:CaptureNextKey(function(key)
		-- The capture has already been consumed by Input. Release the stale
		-- Janitor entry without invoking its cancellation callback.
		self._janitor:Release("capture")
		self._capturing=false
		if table.find(self.Blacklist,key) then self:_render(self:GetValue()); return end
		local v=table.clone(self:GetValue() or {}); v.Key=key.Name; v.Mode=self.Mode; self:SetValue(v)
	end,function()
		if self._destroyed then return end
		self._capturing=false; self:_render(self:GetValue())
	end)
	self._janitor:Add(cancel,nil,"capture")
	return self
end
function Keybind:Cancel()
	if not self._capturing then return self end
	self._janitor:Remove("capture")
	self._capturing=false; self:_render(self:GetValue())
	return self
end
function Keybind:SetMode(mode) if not table.find(self.AllowedModes,mode) then error(`[BobloUI] keybind mode "{mode}" is not allowed.`,2) end; self.Mode=mode; local v=table.clone(self:GetValue() or {}); v.Mode=mode; return self:SetValue(v) end
function Keybind:IsActive() return self._binding and self._binding.Active or false end
function Keybind:Focus() return self:Capture() end
function Keybind:_applyValueTokens() if self._button then self._button.Size=UDim2.new(1,0,0,self._window.Tokens:Get("FieldHeight")); self._button.TextSize=self._window.Tokens:Get("FontSmall") end end
return Keybind

end

__modules["controls/Paragraph"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Base=__require("controls/Base")
local Paragraph=setmetatable({}, {__index=Base}); Paragraph.__index=Paragraph

function Paragraph.new(section,options)
	options=options or {}
	local self=setmetatable({},Paragraph)
	self.Content=options.Content or ""; self.Variant=options.Variant or "Default"
	Base.init(self,section,"Paragraph",options,{Stateful=false,Persist=false})
	self._window.Registry:Update(self,{Title=self:_resolve((self.Title and self.Title~="") and self.Title or self.Content),Description=self:_resolve(self.Content)})
	return Base.finish(self)
end
function Paragraph:_mount()
	if self._mounted or self._destroyed then return end; self._mounted=true
	local w=self._window
	self._root=Create.New("CanvasGroup",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=if self.Variant=="Default" then 1 else 0,BorderSizePixel=0,LayoutOrder=self._order,Parent=self._section._content}); self._janitor:Add(self._root)
	if self.Variant~="Default" then
		Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("ControlRadius")),Parent=self._root})
		local token=if self.Variant=="Info" then "AccentSoft" elseif self.Variant=="Warning" then "SurfaceHover" elseif self.Variant=="Danger" then "SurfaceHover" else "Control"
		w:_bind(self._root,{BackgroundColor3=token}); local stripe=Create.New("Frame",{Size=UDim2.fromOffset(3,18),Position=UDim2.new(0,0,0,10),BorderSizePixel=0,Parent=self._root}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=stripe}); w:_bind(stripe,{BackgroundColor3=if self.Variant=="Info" then "Info" elseif self.Variant=="Warning" then "Warning" else "Error"})
	end
	self._padding=Create.New("UIPadding",{Parent=self._root}); self._layout=Create.List(3); self._layout.Parent=self._root
	if self.Title and self.Title~="" then
		self._titleLabel=Create.New("TextLabel",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Text=self:_resolve(self.Title),Parent=self._root}); w:_bind(self._titleLabel,{TextColor3="Text"})
	end
	self._content=Create.New("TextLabel",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text=self:_resolve(self.Content),Parent=self._root}); w:_bind(self._content,{TextColor3="TextSecondary"})
	if w.Interactions and (self._tooltip or self._contextMenu or self.Id) then self._janitor:Add(w.Interactions:Attach(self,self._root,self._tooltip,self._contextMenu)) end
	self:_applyTokens(); self:_applyVisible(); self:_applyDisabled()
end
function Paragraph:_applyTokens()
	if not self._root then return end
	local t=self._window.Tokens
	if self._padding then local p=math.max(6,t:Get("SectionPadding")-4); self._padding.PaddingTop=UDim.new(0,p); self._padding.PaddingBottom=UDim.new(0,p); self._padding.PaddingLeft=UDim.new(0,p); self._padding.PaddingRight=UDim.new(0,p) end
	if self._titleLabel then self._titleLabel.TextSize=t:Get("FontBody") end
	if self._content then self._content.TextSize=t:Get("FontSmall") end
end
function Paragraph:_refreshText()
	if self._titleLabel then self._titleLabel.Text=self:_resolve(self.Title or "") end
	if self._content then self._content.Text=self:_resolve(self.Content) end
	self._window.Registry:Update(self,{Title=self:_resolve((self.Title and self.Title~="") and self.Title or self.Content),Description=self:_resolve(self.Content),Path=`{self:_resolve(self._section._tab.Title)} -> {self:_resolve(self._section.Title or "Default")}`})
end
function Paragraph:SetContent(v) self.Content=v or ""; if self._content then self._content.Text=self:_resolve(self.Content) end; local fields={Description=self:_resolve(self.Content)}; if not self.Title or self.Title=="" then fields.Title=self:_resolve(self.Content) end; self._window.Registry:Update(self,fields); return self end
return Paragraph

end

__modules["controls/Slider"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Base=__require("controls/Base")
local Slider=setmetatable({}, {__index=Base}); Slider.__index=Slider
function Slider.new(section,options)
	if type(options.Min)~="number" or type(options.Max)~="number" then error("[BobloUI] AddSlider requires Min and Max numbers.",3) end
	local self=setmetatable({},Slider); self.Min=options.Min; self.Max=options.Max; self.Step=options.Step or 1; self.Precision=options.Precision; self.Suffix=options.Suffix or ""; self.Format=options.Format
	local d=options.Default; if d==nil then d=self.Min end; d=math.clamp(d,self.Min,self.Max); Base.init(self,section,"Slider",options,{Stateful=true,Default=d,Layout="Stacked"}); return Base.finish(self)
end
function Slider:_format(v) if self.Format then return self.Format(v) end; if self.Precision then return string.format("%."..self.Precision.."f",v)..self.Suffix end; return tostring(v)..self.Suffix end
function Slider:_normalize(v) v=tonumber(v) or self.Min; v=math.clamp(v,self.Min,self.Max); v=math.round((v-self.Min)/self.Step)*self.Step+self.Min; return math.clamp(v,self.Min,self.Max) end
function Slider:SetValue(v,silent) return Base.SetValue(self,self:_normalize(v),silent) end
function Slider:_mountValue(host)
	local w=self._window; local t=w.Tokens
	self._valueBox=Create.New("TextBox",{Size=UDim2.fromOffset(72,24),Position=UDim2.new(1,0,0,-t:Get("ControlHeight")+(self.Description and -5 or 2)),AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,BorderSizePixel=0,ClearTextOnFocus=false,Text=self:_format(self:GetValue()),Font=w.Fonts.Medium,TextSize=t:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Right,Parent=host}); w:_bind(self._valueBox,{TextColor3="TextSecondary"})
	self._track=Create.New("Frame",{Size=UDim2.new(1,-4,0,t:Get("SliderTrack")),Position=UDim2.new(0,2,0.5,5),AnchorPoint=Vector2.new(0,0.5),BorderSizePixel=0,Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._track}); w:_bind(self._track,{BackgroundColor3="SurfaceInset"})
	self._fill=Create.New("Frame",{Size=UDim2.fromScale(0,1),BorderSizePixel=0,Parent=self._track}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._fill}); w:_bind(self._fill,{BackgroundColor3="Accent"})
	self._knob=Create.New("Frame",{Size=UDim2.fromOffset(t:Get("SliderKnob"),t:Get("SliderKnob")),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),BorderSizePixel=0,ZIndex=3,Parent=self._track}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._knob}); Create.New("UIStroke",{Thickness=1,Color=Color3.new(1,1,1),Transparency=0.42,Parent=self._knob}); w:_bind(self._knob,{BackgroundColor3="Accent"})
	local hit=Create.New("TextButton",{Size=UDim2.new(1,0,0,30),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,Text="",ZIndex=4,Parent=self._track})
	self._janitor:Add(hit.InputBegan:Connect(function(i)
		if self:IsDisabled() then return end; if i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch then return end
		local page=self._section._tab._page; local oldScroll=page and page.ScrollingEnabled; if i.UserInputType==Enum.UserInputType.Touch and page then page.ScrollingEnabled=false end
		local function at(pos) local a=(pos.X-self._track.AbsolutePosition.X)/math.max(1,self._track.AbsoluteSize.X); self:SetValue(self.Min+math.clamp(a,0,1)*(self.Max-self.Min)) end; at(i.Position); w.Input:CapturePointer(self,i,function(m) at(m.Position) end,function() if page and oldScroll~=nil then page.ScrollingEnabled=oldScroll end end)
	end)); self._janitor:Add(self._valueBox.FocusLost:Connect(function() self:SetValue(self._valueBox.Text) end))
end
function Slider:_render(v)
	if not self._fill then return end; local a=math.clamp((v-self.Min)/math.max(0.000001,self.Max-self.Min),0,1); self._fill.Size=UDim2.fromScale(a,1); self._knob.Position=UDim2.fromScale(a,0.5); if not self._valueBox:IsFocused() then self._valueBox.Text=self:_format(v) end
end
function Slider:_applyValueTokens() if self._track then self._track.Size=UDim2.new(1,-4,0,self._window.Tokens:Get("SliderTrack")); local n=self._window.Tokens:Get("SliderKnob"); self._knob.Size=UDim2.fromOffset(n,n); self._valueBox.TextSize=self._window.Tokens:Get("FontSmall") end end
function Slider:SetMin(v) self.Min=v; if self.Max<self.Min then self.Max=self.Min end; self:SetValue(self:GetValue(),true); return self end
function Slider:SetMax(v) self.Max=v; if self.Min>self.Max then self.Min=self.Max end; self:SetValue(self:GetValue(),true); return self end
function Slider:SetStep(v) self.Step=math.max(0.000001,v); self:SetValue(self:GetValue(),true); return self end
return Slider

end

__modules["controls/Status"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Base=__require("controls/Base")
local Status=setmetatable({}, {__index=Base}); Status.__index=Status
local TOKENS={Neutral="TextSecondary",Success="Success",Warning="Warning",Error="Error",Info="Info",Pending="Warning"}
function Status.new(section,options)
	local self=setmetatable({},Status)
	self.Status=options.Status or "Neutral"; self.Pulse=options.Pulse==true
	Base.init(self,section,"Status",options,{Stateful=options.Id~=nil,Default=options.Value,Persist=false,Adaptive=true})
	if not options.Id then self._value=options.Value end
	return Base.finish(self)
end
function Status:_mountValue(host)
	local w=self._window
	self._statusWrap=Create.New("Frame",{
		AutomaticSize=Enum.AutomaticSize.X,
		Size=UDim2.new(0,0,1,0), Position=UDim2.new(1,0,0,0), AnchorPoint=Vector2.new(1,0),
		BackgroundTransparency=1, Parent=host,
	})
	local layout=Create.New("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,8),Parent=self._statusWrap})
	self._dot=Create.New("Frame",{Size=UDim2.fromOffset(7,7),BorderSizePixel=0,LayoutOrder=1,Parent=self._statusWrap})
	Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._dot})
	w:_bind(self._dot,{BackgroundColor3=function(palette) return palette[TOKENS[self.Status] or "TextSecondary"] end})
	self._valueLabel=Create.New("TextLabel",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,1,0),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,Text="",LayoutOrder=2,Parent=self._statusWrap})
	w:_bind(self._valueLabel,{TextColor3="TextSecondary"})
	self:SetStatus(self.Status)
	if self.Pulse and w.Motion.Enabled then local tw=w.Motion:Tween(self._dot,TweenInfo.new(0.8,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{BackgroundTransparency=0.65}); if tw then self._janitor:Add(tw) end end
end
function Status:_render(v) if self._valueLabel then self._valueLabel.Text=tostring(v or "") end end
function Status:SetStatus(s) self.Status=s; if self._dot then self._dot.BackgroundColor3=self._window.Theme:Get(TOKENS[s] or "TextSecondary") end; return self end
function Status:_applyValueTokens() if self._valueLabel then self._valueLabel.TextSize=self._window.Tokens:Get("FontSmall") end end
return Status

end

__modules["controls/TextField"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Base=__require("controls/Base")
local TextField=setmetatable({}, {__index=Base}); TextField.__index=TextField
function TextField.new(section,options)
	local self=setmetatable({},TextField); self.Placeholder=options.Placeholder or ""; self.Numeric=options.Numeric==true; self.MaxLength=options.MaxLength; self.Multiline=options.Multiline==true; self.ClearOnFocus=options.ClearOnFocus==true; self.Validate=options.Validate; self.CommitOn=options.CommitOn or "FocusLost"; self._error=nil
	Base.init(self,section,"Input",options,{Stateful=true,Default=options.Default or (self.Numeric and 0 or ""),Adaptive=true}); return Base.finish(self)
end
function TextField:_mountValue(host)
	local w=self._window; local t=w.Tokens
	self._box=Create.New("TextBox",{Size=UDim2.new(1,0,0,t:Get("FieldHeight")),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=0,BorderSizePixel=0,ClearTextOnFocus=self.ClearOnFocus,MultiLine=self.Multiline,PlaceholderText=self.Placeholder,Text=tostring(self:GetValue() or ""),Font=w.Fonts.Regular,TextSize=t:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("FieldRadius")),Parent=self._box}); Create.New("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),Parent=self._box}); self._stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.62,Parent=self._box}); w:_bind(self._stroke,{Color="BorderSubtle"}); w:_bind(self._box,{BackgroundColor3="ControlInset",TextColor3="Text",PlaceholderColor3="TextTertiary"})
	if self.CommitOn=="Change" then self._janitor:Add(self._box:GetPropertyChangedSignal("Text"):Connect(function() self:_commit() end)) end
	self._janitor:Add(self._box.Focused:Connect(function() self._stroke.Color=w.Theme:Get("AccentBorder"); self._stroke.Transparency=0; if w.Device.Layout=="Drawer" then task.defer(function() self:Reveal() end) end end))
	self._janitor:Add(self._box.FocusLost:Connect(function(enter) self._stroke.Color=w.Theme:Get("BorderSubtle"); self._stroke.Transparency=0.62; if self.CommitOn=="FocusLost" or (self.CommitOn=="Enter" and enter) then self:_commit() end end))
end
function TextField:_commit()
	local text=self._box.Text; if self.MaxLength and #text>self.MaxLength then text=string.sub(text,1,self.MaxLength); self._box.Text=text end
	local value=if self.Numeric then tonumber(text) else text; if self.Numeric and value==nil then self:SetError("Enter a number"); self:_render(self:GetValue()); return end
	if self.Validate then local ok,message=self.Validate(value); if not ok then self:SetError(message or "Invalid value"); return end end; self:SetError(nil); self:SetValue(value)
end
function TextField:_render(v)
	if self._box then if not self._box:IsFocused() then self._box.Text=tostring(v or "") end; self._box.BackgroundColor3=self._window.Theme:Get(self._error and "AccentSoft" or "ControlInset"); if self._error then self._stroke.Color=self._window.Theme:Get("Error"); self._stroke.Transparency=0 end end
end
function TextField:Focus() if self._box then self._box:CaptureFocus() end; return self end
function TextField:Blur() if self._box then self._box:ReleaseFocus() end; return self end
function TextField:Clear() return self:SetValue(self.Numeric and 0 or "") end
function TextField:SetError(text) self._error=text; self:_render(self:GetValue()); return self end
function TextField:_applyDisabled() Base._applyDisabled(self); if self._box then self._box.TextEditable=not self._disabled end end
function TextField:_applyValueTokens() if self._box then self._box.Size=UDim2.new(1,0,0,self._window.Tokens:Get("FieldHeight")); self._box.TextSize=self._window.Tokens:Get("FontBody") end end
return TextField

end

__modules["controls/Toggle"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Base=__require("controls/Base")
local Toggle=setmetatable({}, {__index=Base}); Toggle.__index=Toggle
function Toggle.new(section,options) local self=setmetatable({},Toggle); Base.init(self,section,"Toggle",options,{Stateful=true,Default=options.Default==true}); return Base.finish(self) end
function Toggle:_mountValue(host)
	local w=self._window; local t=w.Tokens
	self._button=Create.New("TextButton",{Size=UDim2.fromOffset(34,18),Position=UDim2.new(1,0,0.5,0),AnchorPoint=Vector2.new(1,0.5),BorderSizePixel=0,AutoButtonColor=false,Text="",Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._button})
	self._stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.62,Parent=self._button}); w:_bind(self._stroke,{Color="BorderStrong"}); w:_bind(self._button,{BackgroundColor3="SurfaceInset"})
	self._knob=Create.New("Frame",{Size=UDim2.fromOffset(12,12),Position=UDim2.new(0,3,0.5,0),AnchorPoint=Vector2.new(0,0.5),BorderSizePixel=0,Parent=self._button}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._knob}); w:_bind(self._knob,{BackgroundColor3="TextTertiary"})
	self._janitor:Add(self._button.MouseButton1Click:Connect(function() if not self:IsDisabled() then self:Flip() end end))
end
function Toggle:_render(value)
	if not self._button then return end; local on=value==true; local w=self._window
	self._button.BackgroundColor3=w.Theme:Get(if on then "Accent" else "SurfaceInset"); self._stroke.Color=w.Theme:Get(if on then "AccentBorder" else "BorderSubtle"); self._stroke.Transparency=if on then 0.45 else 0.62
	self._knob.BackgroundColor3=w.Theme:Get(if on then "AccentText" else "TextSecondary")
	w.Motion:Tween(self._knob,"Fast",{Position=if on then UDim2.new(1,-15,0.5,0) else UDim2.new(0,3,0.5,0)})
end
function Toggle:Flip() if self._window.Sound then self._window.Sound:Play("Toggle") end; return self:SetValue(not self:GetValue()) end
return Toggle

end

__modules["init"] = function()
--!nonstrict
-- BobloUI public entry. All higher-level services are wired here by injection.
local Env=__require("runtime/Env")
local Janitor=__require("runtime/Janitor")
local Util=__require("runtime/Util")
local Tokens=__require("kernel/Tokens")
local Theme=__require("kernel/Theme")
local Device=__require("kernel/Device")
local Layer=__require("kernel/Layer")
local Store=__require("kernel/Store")
local Registry=__require("kernel/Registry")
local Input=__require("kernel/Input")
local Motion=__require("kernel/Motion")
local Locale=__require("kernel/Locale")
local Window=__require("shell/Window")
local Favorites=__require("services/Favorites")
local Config=__require("services/Config")
local Search=__require("services/Search")
local Commands=__require("services/Commands")
local Notify=__require("services/Notify")
local Dialog=__require("services/Dialog")
local Palette=__require("services/Palette")
local Interactions=__require("services/Interactions")
local Build=__require("schema/Build")
local Icon=__require("primitives/Icon")
local Dark=__require("themes/Dark")
local Light=__require("themes/Light")
local OLED=__require("themes/OLED")
local Midnight=__require("themes/Midnight")
local Settings=__require("services/Settings")
local Sound=__require("services/Sound")
local Navigation=__require("services/Navigation")
local HttpService=game:GetService("HttpService")

local BobloUI={}
BobloUI.Version="0.10.1-beta.1"; BobloUI.ApiLevel=10; BobloUI.Env=Env; BobloUI.Icon=Icon
local REGISTRY_KEY="__BobloUI"
local function globalRegistry()
	local existing=Env.Globals[REGISTRY_KEY]; if type(existing)=="table" and type(existing.Instances)=="table" then return existing end
	local created={Instances={}}; Env.Globals[REGISTRY_KEY]=created; return created
end
local function evict(id)
	local r=globalRegistry(); local previous=r.Instances[id]; if not previous then return end; r.Instances[id]=nil
	local ok,err=pcall(function() previous:Unload() end); if not ok then warn(`[BobloUI] previous window "{id}" failed to unload ({err}); sweeping GUIs.`); Layer.SweepOrphans(id) end
end
local WINDOW_OPTIONS={"Id","Singleton","Title","Subtitle","Theme","Accent","Density","Scale","Size","MinSize","Locale","ToggleKey","ConfigFolder","AutoLoad","ReducedMotion","HighContrast","Settings","RememberGeometry","KeyboardNavigation","SoundEnabled","SoundVolume","Sounds","OnUnload"}
local function checkOptions(options)
	if type(options)~="table" then error("[BobloUI] CreateWindow expects an options table.",3) end
	if type(options.Title)~="string" then error("[BobloUI] CreateWindow: Title is required and must be a string.",3) end
	for key in options do
		if not table.find(WINDOW_OPTIONS,key) then
			local suggestion=Util.suggest(tostring(key),WINDOW_OPTIONS)
			local hint=if suggestion then " Did you mean \""..suggestion.."\"?" else ""
			warn(`[BobloUI] CreateWindow: unknown option "{key}".{hint}\nValid options: {table.concat(WINDOW_OPTIONS,", ")}`)
		end
	end
end

function BobloUI:CreateWindow(options)
	checkOptions(options); local id=options.Id or Util.slug(options.Title); if not options.Id then warn(`[BobloUI] CreateWindow: no Id given, using "{id}" from Title. Set Id explicitly.`) end
	local singleton=options.Singleton~=false; if singleton then evict(id) end
	local janitor=Janitor.new(`Window[{id}]`)
	local device=Device.new(); janitor:Add(device)
	local tokens=Tokens.new(options.Density or "Comfortable",device.Class); janitor:Add(tokens)
	local theme=Theme.new({Palettes={Dark=Dark,Light=Light,Midnight=Midnight,OLED=OLED},Accent=options.Accent}); janitor:Add(theme); theme:Set(options.Theme or "Dark")
	if options.HighContrast then theme:SetHighContrast(true) end
	local input=Input.new(); janitor:Add(input)
	local layers=Layer.new(id,input); janitor:Add(layers)
	local state=Store.new(); janitor:Add(state)
	local registry=Registry.new(); janitor:Add(registry)
	local motion=Motion.new(); janitor:Add(motion); if options.ReducedMotion then motion:SetEnabled(false) end
	local locale=Locale.new(options.Locale or "en"); janitor:Add(locale)
	locale:Register("en",{
		["search.placeholder"]="Search controls or type > for commands",["common.cancel"]="Cancel",["common.confirm"]="Confirm",
		["settings.title"]="Settings",["settings.description"]="Interface, profiles and accessibility",["nav.system"]="System",
		["settings.appearance"]="Appearance",["settings.appearanceDesc"]="Theme, scale, density and language",["settings.theme"]="Theme",["settings.accent"]="Accent color",["settings.scale"]="UI scale",["settings.density"]="Density",["settings.language"]="Language",["settings.reducedMotion"]="Reduced motion",["settings.highContrast"]="High contrast",["settings.keyboardNavigation"]="Keyboard / gamepad navigation",["settings.uiSounds"]="UI sounds",["settings.soundVolume"]="UI sound volume",
		["settings.themeEditor"]="Advanced theme editor",["settings.themeEditorDesc"]="Override any core interface color",["settings.theme.reset"]="Reset custom theme",["settings.theme.export"]="Export theme",["settings.theme.import"]="Import theme",
		["settings.window"]="Window",["settings.lockWindow"]="Lock window position",["settings.rememberGeometry"]="Remember size and position",["settings.resetLayout"]="Reset window layout",["settings.resetAll"]="Reset all controls",
		["settings.configs"]="Config profiles",["settings.config.name"]="Profile name",["settings.config.profile"]="Selected profile",["settings.config.save"]="Save profile",["settings.config.load"]="Load profile",["settings.config.autoload"]="Auto-load profile",["settings.config.duplicate"]="Duplicate profile",["settings.config.rename"]="Rename profile",["settings.config.delete"]="Delete profile",["settings.config.export"]="Export profile",["settings.config.import"]="Import profile",["settings.config.paste"]="Paste exported JSON",["settings.config.disabled"]="Set ConfigFolder in CreateWindow to enable persistent profiles.",
		["settings.favorites"]="Favorites",["settings.favorites.empty"]="No favorites yet. Right-click or long-press a control to pin it.",["settings.keybinds"]="Keybind manager",["settings.keybinds.empty"]="No keybind controls in this hub.",
		["settings.open"]="Open",["settings.removeFavorite"]="Remove from Favorites",["settings.save"]="Save",["settings.load"]="Load",["settings.set"]="Set",["settings.duplicate"]="Duplicate",["settings.rename"]="Rename",["settings.delete"]="Delete",["settings.export"]="Export",["settings.import"]="Import",["settings.reset"]="Reset",["settings.saved"]="Profile saved",["settings.autoloadSet"]="Auto-load updated",["settings.copied"]="Copied to clipboard",["settings.resetDone"]="Theme reset"
	})
	locale:Register("ru",{
		["search.placeholder"]="Поиск функций или > для команд",["common.cancel"]="Отмена",["common.confirm"]="Подтвердить",["settings.title"]="Настройки",["settings.description"]="Интерфейс, профили и доступность",["nav.system"]="Система",["settings.appearance"]="Внешний вид",["settings.appearanceDesc"]="Тема, масштаб, плотность и язык",["settings.theme"]="Тема",["settings.accent"]="Цвет акцента",["settings.scale"]="Масштаб UI",["settings.density"]="Плотность",["settings.language"]="Язык",["settings.reducedMotion"]="Меньше анимаций",["settings.highContrast"]="Высокий контраст",["settings.keyboardNavigation"]="Навигация клавиатурой / геймпадом",["settings.uiSounds"]="Звуки интерфейса",["settings.soundVolume"]="Громкость интерфейса",["settings.themeEditor"]="Редактор темы",["settings.themeEditorDesc"]="Изменение основных цветов интерфейса",["settings.window"]="Окно",["settings.lockWindow"]="Заблокировать окно",["settings.rememberGeometry"]="Запоминать размер и позицию",["settings.resetLayout"]="Сбросить расположение",["settings.resetAll"]="Сбросить все функции",["settings.configs"]="Профили",["settings.config.name"]="Имя профиля",["settings.config.profile"]="Выбранный профиль",["settings.config.disabled"]="Укажите ConfigFolder, чтобы включить сохранение профилей.",["settings.favorites"]="Избранное",["settings.favorites.empty"]="Избранного пока нет.",["settings.keybinds"]="Горячие клавиши",["settings.keybinds.empty"]="В хабе нет горячих клавиш.",["settings.open"]="Открыть",["settings.save"]="Сохранить",["settings.load"]="Загрузить",["settings.set"]="Назначить",["settings.duplicate"]="Копировать",["settings.rename"]="Переименовать",["settings.delete"]="Удалить",["settings.export"]="Экспорт",["settings.import"]="Импорт",["settings.reset"]="Сбросить",["settings.copied"]="Скопировано",["settings.saved"]="Профиль сохранён"
	})
	locale:Register("es",{
		["search.placeholder"]="Buscar controles o usar > para comandos",["common.cancel"]="Cancelar",["common.confirm"]="Confirmar",["settings.title"]="Ajustes",["settings.description"]="Interfaz, perfiles y accesibilidad",["nav.system"]="Sistema",["settings.appearance"]="Apariencia",["settings.theme"]="Tema",["settings.accent"]="Color de acento",["settings.scale"]="Escala de UI",["settings.density"]="Densidad",["settings.language"]="Idioma",["settings.reducedMotion"]="Movimiento reducido",["settings.highContrast"]="Alto contraste",["settings.keyboardNavigation"]="Navegación con teclado / mando",["settings.uiSounds"]="Sonidos de interfaz",["settings.soundVolume"]="Volumen de interfaz",["settings.window"]="Ventana",["settings.configs"]="Perfiles",["settings.favorites"]="Favoritos",["settings.keybinds"]="Atajos",["settings.open"]="Abrir",["settings.save"]="Guardar",["settings.load"]="Cargar",["settings.reset"]="Restablecer"
	})

	local window=Window.new({Id=id,Janitor=janitor,Theme=theme,Tokens=tokens,Device=device,Layers=layers,Fonts=Tokens.Fonts,State=state,Registry=registry,Input=input,Motion=motion,Locale=locale},options)
	window.Version=BobloUI.Version; window.ApiLevel=BobloUI.ApiLevel; window.Singleton=singleton; window.CustomControls=BobloUI.CustomControls
	window.State=state; window.Registry=registry; window.Input=input; window.Motion=motion; window.Locale=locale

	local favorites=Favorites.new(registry); janitor:Add(favorites); window.Favorites=favorites
	local search=Search.new(window); window.Search=search
	local commands=Commands.new(window); window.Commands=commands
	local notify=Notify.new(window); janitor:Add(notify); window.Notify=notify
	local dialog=Dialog.new(window); janitor:Add(dialog); window.Dialog=dialog
	local config=nil; if options.ConfigFolder then config=Config.new(window,options.ConfigFolder); janitor:Add(config); window.Config=config end
	local interactions=Interactions.new(window); janitor:Add(interactions); window.Interactions=interactions
	local palette=Palette.new(window,search,commands); janitor:Add(palette); window.Palette=palette
	local sound=Sound.new(window,options); janitor:Add(sound); window.Sound=sound
	local navigation=Navigation.new(window,options.KeyboardNavigation~=false); janitor:Add(navigation); window.Navigation=navigation
	local settings=nil; if options.Settings~=false then settings=Settings.new(window,options); janitor:Add(settings); window.Settings=settings end
	function window:OpenSettings() if settings then settings:Open() end; return self end

	local unloaded=false
	function window:SetTheme(name) theme:Set(name); return self end
	function window:SetAccent(colour) theme:SetAccent(colour); return self end
	function window:SetThemeToken(token,colour) theme:SetToken(token,colour); return self end
	function window:SetHighContrast(enabled) theme:SetHighContrast(enabled); return self end
	function window:RegisterTheme(name,palette) theme:Register(name,palette); return self end
	function window:SetDensity(density) tokens:SetDensity(density); return self end
	function window:SetScale(scale)
		local root=self:GetInstance(); local uiScale=root:FindFirstChildOfClass("UIScale"); if not uiScale then uiScale=Instance.new("UIScale"); uiScale.Parent=root end; self._scale=math.clamp(scale,0.5,2); uiScale.Scale=self._scale; return self
	end
	function window:GetScale() return self._scale or 1 end
	function window:ExportTheme(copy) local raw=HttpService:JSONEncode(theme:Export()); if copy then Env.SetClipboard(raw) end; return raw end
	function window:ImportTheme(raw) local data=raw; if type(raw)=="string" then local ok,res=pcall(HttpService.JSONDecode,HttpService,raw); if not ok then return false,res end; data=res end; return theme:Import(data) end
	function window:SetLocale(name)
		locale:Set(name); for _,tab in self._tabs do if tab._refreshLocale then tab:_refreshLocale() end end; for _,entry in registry:Entries() do if entry.Handle and entry.Handle._refreshText then entry.Handle:_refreshText() end end; search:Reindex(); return self
	end
	function window:SetReducedMotion(reduced) motion:SetEnabled(not reduced); return self end
	function window:SetKeyboardNavigation(enabled) navigation:SetEnabled(enabled); return self end
	function window:SetUISounds(enabled) sound:SetEnabled(enabled); return self end
	function window:SetSoundVolume(volume) sound:SetVolume(volume); return self end
	function window:RegisterSound(name,spec) sound:Register(name,spec); return self end
	function window:PlaySound(name,override) return sound:Play(name,override) end
	function window:OpenSearch(query) palette:Open(query or "","search"); return self end
	function window:OpenCommands() palette:Open("> ","commands"); return self end
	function window:Build(schema) return Build.Run(self,schema) end
	function window:OnUnload(fn) return self.Unloading:Connect(fn) end
	function window:IsUnloaded() return unloaded end

	commands:Register({Id="ui.toggle",Title="Toggle UI",Keywords={"show","hide"},Callback=function() window:Toggle() end})
	commands:Register({Id="ui.theme",Title="Toggle light/dark theme",Keywords={"theme","dark","light"},Callback=function() window:SetTheme(theme:Current()=="Dark" and "Light" or "Dark") end})
	commands:Register({Id="ui.settings",Title="Open settings",Keywords={"settings","preferences","config"},Callback=function() window:OpenSettings() end})
	commands:Register({Id="ui.reset",Title="Reset UI layout",Keywords={"reset","layout","window"},Callback=function() window:ResetGeometry() end})
	commands:Register({Id="ui.unload",Title="Unload UI",Keywords={"close","destroy"},Callback=function() window:Unload() end})

	local toggleKey=options.ToggleKey; if toggleKey==nil then toggleKey=Enum.KeyCode.RightShift end
	if toggleKey~=false and typeof(toggleKey)=="EnumItem" then janitor:Add(input:BindKey("__window_toggle",toggleKey,"Toggle",function() if not unloaded then window:Toggle() end end)) end
	if options.Scale then window:SetScale(options.Scale) end
	if options.OnUnload then window:OnUnload(options.OnUnload) end
	if singleton then globalRegistry().Instances[id]=window end

	local baseDestroy=Window.Destroy
	function window:Unload()
		if unloaded then return end; unloaded=true; self.Unloading:Fire()
		if config and config:GetAutoLoad() then pcall(function() config:Save(config:GetAutoLoad()) end) end
		layers:DismissAll(); baseDestroy(self); janitor:Destroy()
		local r=globalRegistry(); if r.Instances[id]==self then r.Instances[id]=nil end
	end

	if config and options.AutoLoad then local ok,err=config:LoadAuto(); if not ok and err~="no autoload" then warn(`[BobloUI] autoload failed: {err}`) end end
	return window
end
BobloUI.CustomControls={}
function BobloUI:RegisterControl(name,factory) if type(name)~="string" or type(factory)~="function" then error("[BobloUI] RegisterControl(name,factory) expects string/function.",2) end; self.CustomControls[name]=factory; return self end

function BobloUI:GetWindow(id) return globalRegistry().Instances[id] end
function BobloUI:ListWindows() local ids=Util.keys(globalRegistry().Instances); table.sort(ids); return ids end
function BobloUI:SweepOrphans(id) return Layer.SweepOrphans(id) end
return BobloUI

end

__modules["kernel/Device"] = function()
--!nonstrict
--[[
	Device — viewport, layout mode, insets, on-screen keyboard.

	Two independent axes, which most libraries conflate:

	  Layout  Wide / Rail / Drawer   -- STRUCTURE, driven by viewport width
	  Class   Desktop / Tablet / Phone -- INPUT + sizing, driven by capabilities

	A desktop window dragged narrow gets Drawer layout without becoming a phone.
	A tablet in landscape gets Rail without losing touch sizing.
]]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Signal = __require("runtime/Signal")
local Janitor = __require("runtime/Janitor")

local Device = {}
Device.__index = Device

Device.Breakpoints = {
	Drawer = 700,
	Rail = 1100,
}

--- Viewport can change several times during a device rotation.
local DEBOUNCE = 0.1

local function layoutFor(width: number): string
	if width < Device.Breakpoints.Drawer then
		return "Drawer"
	elseif width < Device.Breakpoints.Rail then
		return "Rail"
	end
	return "Wide"
end

local function classFor(width: number): string
	local touch = UserInputService.TouchEnabled
	local keyboard = UserInputService.KeyboardEnabled
	-- A device with a keyboard is treated as a desktop even when it also has a
	-- touchscreen: the sizing that matters is the one the user actually uses.
	if touch and not keyboard then
		return if width < Device.Breakpoints.Drawer then "Phone" else "Tablet"
	end
	return "Desktop"
end

function Device.new()
	local self = setmetatable({
		Changed = Signal.new("Device.Changed"),

		Viewport = Vector2.new(1280, 720),
		Layout = "Wide",
		Class = "Desktop",
		Orientation = "Landscape",
		IsTouch = UserInputService.TouchEnabled,
		Insets = { Top = 0, Right = 0, Bottom = 0, Left = 0 },
		KeyboardHeight = 0,

		_janitor = Janitor.new("Device"),
		_pending = nil,
	}, Device)

	self:_recompute(true)
	self:_connect()

	return self
end

function Device:_camera(): Camera?
	return workspace.CurrentCamera
end

function Device:_readInsets()
	local top, bottom = 0, 0
	local left, right = 0, 0

	local ok, topLeft, bottomRight = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and topLeft then
		top = topLeft.Y
		left = topLeft.X
		if bottomRight then
			bottom = bottomRight.Y
			right = bottomRight.X
		end
	end

	-- TopbarInset covers notches / safe areas on newer clients.
	local okTopbar, topbar = pcall(function()
		return GuiService.TopbarInset
	end)
	if okTopbar and typeof(topbar) == "Rect" then
		top = math.max(top, topbar.Min.Y)
	end

	return { Top = top, Right = right, Bottom = bottom, Left = left }
end

function Device:_recompute(silent: boolean?)
	local camera = self:_camera()
	local viewport = camera and camera.ViewportSize or self.Viewport
	if viewport.X <= 0 or viewport.Y <= 0 then
		return
	end

	local changed = {}

	local function set(key, value)
		if self[key] ~= value then
			self[key] = value
			changed[key] = true
		end
	end

	set("Viewport", viewport)
	set("Layout", layoutFor(viewport.X))
	set("Class", classFor(viewport.X))
	set("Orientation", if viewport.Y > viewport.X then "Portrait" else "Landscape")
	set("IsTouch", UserInputService.TouchEnabled)

	local insets = self:_readInsets()
	local current = self.Insets
	if
		insets.Top ~= current.Top
		or insets.Bottom ~= current.Bottom
		or insets.Left ~= current.Left
		or insets.Right ~= current.Right
	then
		self.Insets = insets
		changed.Insets = true
	end

	local keyboardHeight = 0
	if UserInputService.OnScreenKeyboardVisible then
		keyboardHeight = UserInputService.OnScreenKeyboardSize.Y
	end
	set("KeyboardHeight", keyboardHeight)

	if silent then
		return
	end
	if next(changed) then
		self.Changed:Fire(self, changed)
	end
end

function Device:_schedule()
	if self._pending then
		return
	end
	self._pending = task.delay(DEBOUNCE, function()
		self._pending = nil
		self:_recompute()
	end)
	self._janitor:Add(self._pending, nil, "pendingRecompute")
end

function Device:_connect()
	local janitor = self._janitor

	local function watchCamera(camera: Camera?)
		janitor:Remove("cameraViewport")
		if not camera then
			return
		end
		janitor:Add(
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:_schedule()
			end),
			nil,
			"cameraViewport"
		)
	end

	watchCamera(self:_camera())

	janitor:Add(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera(self:_camera())
		self:_schedule()
	end))

	janitor:Add(GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
		self:_schedule()
	end))

	janitor:Add(UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(function()
		-- Keyboard transitions must not wait out the rotation debounce.
		self:_recompute()
	end))

	janitor:Add(UserInputService:GetPropertyChangedSignal("OnScreenKeyboardSize"):Connect(function()
		self:_recompute()
	end))
end

--- Usable rectangle after topbar / notch insets.
function Device:SafeArea(): (Vector2, Vector2)
	local insets = self.Insets
	local position = Vector2.new(insets.Left, insets.Top)
	local size = Vector2.new(
		math.max(0, self.Viewport.X - insets.Left - insets.Right),
		math.max(0, self.Viewport.Y - insets.Top - insets.Bottom)
	)
	return position, size
end

function Device:Destroy()
	self._janitor:Destroy()
	self.Changed:Destroy()
end

return Device


end

__modules["kernel/Input"] = function()
--!nonstrict
local UserInputService=game:GetService("UserInputService")
local Signal=__require("runtime/Signal")
local Janitor=__require("runtime/Janitor")
local Input={}; Input.__index=Input
local function isPointerStart(i) return i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch end
local function isPointerMove(i) return i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch end
local function eventKey(i) return if i.KeyCode~=Enum.KeyCode.Unknown then i.KeyCode else i.UserInputType end
function Input.new()
	local self=setmetatable({Began=Signal.new("Input.Began"),Changed=Signal.new("Input.Changed"),Ended=Signal.new("Input.Ended"),_janitor=Janitor.new("Input"),_capture=nil,_keybinds={},_nextCapture=nil},Input)
	self._janitor:Add(UserInputService.InputBegan:Connect(function(i,p) self:_began(i,p) end))
	self._janitor:Add(UserInputService.InputChanged:Connect(function(i,p) self:_changed(i,p) end))
	self._janitor:Add(UserInputService.InputEnded:Connect(function(i,p) self:_ended(i,p) end))
	return self
end
function Input:_began(i,processed)
	-- Capture is an explicit user action. Roblox often marks keys as processed
	-- when the game has its own binding, so gameProcessedEvent must not make
	-- key capture randomly fail. The capture path owns this input and returns.
	if self._nextCapture then
		local capture=self._nextCapture
		local key=if i.KeyCode~=Enum.KeyCode.Unknown then i.KeyCode elseif i.UserInputType~=Enum.UserInputType.MouseMovement then i.UserInputType else nil
		if key then
			self._nextCapture=nil
			capture.Callback(key)
			return
		end
	end

	-- Script-hub keybinds should still fire when the game consumes the same
	-- key. The one important exception is typing: never trigger a hub action
	-- while a TextBox/chat field has keyboard focus.
	local typing=UserInputService:GetFocusedTextBox()~=nil
	local keyboard=i.KeyCode~=Enum.KeyCode.Unknown
	if not typing and (not processed or keyboard) then
		local key=eventKey(i); local list=self._keybinds[key]; if list then for _,h in table.clone(list) do if h.Enabled then h:_press() end end end
	end
	self.Began:Fire(i,processed)
end
function Input:_changed(i,processed)
	if self._capture and isPointerMove(i) then local c=self._capture; if c.Changed then c.Changed(i) end end
	self.Changed:Fire(i,processed)
end
function Input:_ended(i,processed)
	if self._capture and (isPointerStart(i) or i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then
		local c=self._capture; self._capture=nil; if c.Ended then c.Ended(i) end
	end
	local key=eventKey(i); local list=self._keybinds[key]; if list then for _,h in table.clone(list) do if h.Enabled then h:_release() end end end
	self.Ended:Fire(i,processed)
end
function Input:CapturePointer(owner,input,onChanged,onEnded)
	if not isPointerStart(input) then return false end
	if self._capture and self._capture.Ended then pcall(self._capture.Ended,input,true) end
	self._capture={Owner=owner,Changed=onChanged,Ended=onEnded}; return true
end
function Input:CancelCapture(owner) if self._capture and (not owner or self._capture.Owner==owner) then local c=self._capture; self._capture=nil; if c.Ended then c.Ended(nil,true) end end end
function Input:AttachDrag(gui,onDelta,enabledFn)
	local janitor=Janitor.new("Input.Drag"); local startPos
	janitor:Add(gui.InputBegan:Connect(function(i)
		if enabledFn and not enabledFn() then return end
		if not isPointerStart(i) then return end
		startPos=i.Position
		self:CapturePointer(gui,i,function(move) onDelta(move.Position-startPos,move) end,function() end)
	end)); return janitor
end
function Input:IsKeyDown(key)
	if typeof(key)~="EnumItem" then return false end
	if key.EnumType==Enum.KeyCode then return UserInputService:IsKeyDown(key) end
	local ok,result=pcall(UserInputService.IsMouseButtonPressed,UserInputService,key); return ok and result==true
end
function Input:CaptureNextKey(callback,onCancel)
	if type(callback)~="function" then error("[BobloUI] CaptureNextKey expects a callback.",2) end
	if self._nextCapture then
		local previous=self._nextCapture; self._nextCapture=nil
		if previous.OnCancel then pcall(previous.OnCancel) end
	end
	local capture={Callback=callback,OnCancel=onCancel}
	self._nextCapture=capture
	local alive=true
	return function()
		if not alive then return end; alive=false
		if self._nextCapture==capture then
			self._nextCapture=nil
			if capture.OnCancel then pcall(capture.OnCancel) end
		end
	end
end
function Input:BindKey(id,key,mode,callback)
	mode=mode or "Toggle"; local handle={Id=id,Key=key,Mode=mode,Callback=callback,Enabled=true,Active=mode=="Always",_toggle=false,_input=self}
	function handle:_press() if self.Mode=="Hold" then self.Active=true; self.Callback(true) elseif self.Mode=="Toggle" then self._toggle=not self._toggle; self.Active=self._toggle; self.Callback(self.Active) elseif self.Mode=="Always" then self.Active=true; self.Callback(true) end end
	function handle:_release() if self.Mode=="Hold" and self.Active then self.Active=false; self.Callback(false) end end
	function handle:Destroy() local list=self._input._keybinds[self.Key]; if list then local p=table.find(list,self); if p then table.remove(list,p) end end end
	local list=self._keybinds[key] or {}; self._keybinds[key]=list; table.insert(list,handle); return handle
end
function Input:Destroy()
	self:CancelCapture()
	if self._nextCapture then local capture=self._nextCapture; self._nextCapture=nil; if capture.OnCancel then pcall(capture.OnCancel) end end
	for _,list in self._keybinds do for _,h in list do h.Enabled=false end end; self._keybinds={}; self._janitor:Destroy(); self.Began:Destroy(); self.Changed:Destroy(); self.Ended:Destroy()
end
return Input

end

__modules["kernel/Layer"] = function()
--!nonstrict
--[[
	Layer — ScreenGui layers and the modal stack.

	Three ScreenGuis, not one:

	  Root     100  window chrome and content
	  Overlay  200  popovers, sheets, dialogs, context menus, the palette
	  Toast    300  notifications, which must survive on top of a dialog

	This is the fix for the single most common bug in Roblox UI libraries: a
	dropdown rendered inside a ScrollingFrame gets clipped by ClipsDescendants.
	Anything transient renders into Overlay with absolute coordinates instead.

	Click-outside is handled with a full-screen transparent catcher Frame placed
	UNDER the transient content, not by hit-testing every input against every
	open popup.
]]

local CollectionService = game:GetService("CollectionService")
local Create = __require("runtime/Create")
local Janitor = __require("runtime/Janitor")
local Signal = __require("runtime/Signal")
local Env = __require("runtime/Env")

local Layer = {}
Layer.__index = Layer

--- Every root ScreenGui carries this tag so a failed :Unload() in an older
--- bundle can still be swept up by a newer one (architecture doc A.9).
Layer.Tag = "BobloUI"

local ORDER = {
	Root = 100,
	Overlay = 200,
	Toast = 300,
}

function Layer.new(windowId: string, input)
	local self = setmetatable({
		DismissedTop = Signal.new("Layer.DismissedTop"),
		_janitor = Janitor.new("Layer"),
		_windowId = windowId,
		_stack = {},
		_guis = {},
	}, Layer)

	local parent = Env.GetGuiParent()

	for name, order in ORDER do
		local gui = Create.New("ScreenGui", {
			Name = `BobloUI.{name}.{windowId}`,
			DisplayOrder = order,
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			AutoLocalize = false,
		})
		gui:SetAttribute("BobloWindowId", windowId)
		CollectionService:AddTag(gui, Layer.Tag)
		Env.Protect(gui)
		gui.Parent = parent

		self[name] = gui
		self._guis[name] = gui
		self._janitor:Add(gui)
	end

	-- Escape closes the topmost transient surface through the shared input dispatcher.
	if input then
		self._janitor:Add(input.Began:Connect(function(key, processed)
			if key.KeyCode == Enum.KeyCode.Escape and #self._stack > 0 then
				self:DismissTop()
			end
		end))
	end

	return self
end

--[[
	Push(options) -> handle

	options.Scrim      dim everything below (dialogs); default false
	options.OnDismiss  called when the surface is dismissed for any reason
	options.Modal      swallow clicks outside instead of dismissing; default false

	handle.Container   Frame to build into
	handle:Dismiss()
]]
function Layer:Push(options)
	options = options or {}

	local depth = #self._stack + 1
	local baseZ = depth * 10

	local janitor = Janitor.new(`Layer.Push[{depth}]`)
	local handle = {
		Depth = depth,
		_janitor = janitor,
		_layer = self,
		_dismissed = false,
		_onDismiss = options.OnDismiss,
	}

	local catcher = Create.New("TextButton", {
		Name = "Catcher",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = options.ScrimColour or Color3.new(0, 0, 0),
		BackgroundTransparency = if options.Scrim then (options.ScrimTransparency or 0.5) else 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = baseZ,
		Parent = self.Overlay,
	})
	janitor:Add(catcher)

	janitor:Add(catcher.MouseButton1Click:Connect(function()
		if not options.Modal then
			handle:Dismiss()
		end
	end))

	local container = Create.New("Frame", {
		Name = "Container",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 1,
		Parent = self.Overlay,
	})
	janitor:Add(container)

	handle.Catcher = catcher
	handle.Container = container

	function handle:Dismiss()
		if self._dismissed then
			return
		end
		self._dismissed = true

		local stack = self._layer._stack
		local position = table.find(stack, self)
		if position then
			table.remove(stack, position)
		end

		if self._onDismiss then
			local ok, err = pcall(self._onDismiss)
			if not ok then
				warn(`[BobloUI] Layer OnDismiss failed: {err}`)
			end
		end

		self._janitor:Destroy()
	end

	function handle:IsOpen(): boolean
		return not self._dismissed
	end

	table.insert(self._stack, handle)
	return handle
end

function Layer:DismissTop()
	local top = self._stack[#self._stack]
	if top then
		top:Dismiss()
		self.DismissedTop:Fire(top)
	end
end

function Layer:DismissAll()
	for index = #self._stack, 1, -1 do
		self._stack[index]:Dismiss()
	end
	self._stack = {}
end

function Layer:StackDepth(): number
	return #self._stack
end

--- Emergency sweep. Used when an older bundle's :Unload() errored and its
--- ScreenGuis are still on screen (architecture doc A.9).
function Layer.SweepOrphans(windowId: string?)
	local removed = 0
	for _, gui in CollectionService:GetTagged(Layer.Tag) do
		if not windowId or gui:GetAttribute("BobloWindowId") == windowId then
			pcall(function()
				gui:Destroy()
			end)
			removed += 1
		end
	end
	return removed
end

function Layer:Destroy()
	self:DismissAll()
	self._janitor:Destroy()
	self.DismissedTop:Destroy()
end

return Layer


end

__modules["kernel/Locale"] = function()
--!nonstrict
local Signal=__require("runtime/Signal")
local Locale={}; Locale.__index=Locale
function Locale.new(initial)
	return setmetatable({Changed=Signal.new("Locale.Changed"),_name=initial or "en",_locales={en={}}},Locale)
end
function Locale:Register(name,dict) self._locales[name]=table.clone(dict or {}) end
function Locale:Add(name,dict) local target=self._locales[name] or {}; self._locales[name]=target; for k,v in dict do target[k]=v end end
function Locale:Set(name) if not self._locales[name] then warn(`[BobloUI] locale "{name}" is not registered.`) end; if self._name~=name then self._name=name; self.Changed:Fire(name) end end
function Locale:Get() return self._name end
function Locale:List() local out={}; for name in self._locales do table.insert(out,name) end; table.sort(out); return out end
function Locale:T(key,vars)
	local dict=self._locales[self._name] or {}; local fallback=self._locales.en or {}; local text=dict[key] or fallback[key] or key
	if vars then for k,v in vars do text=string.gsub(text,"{"..k.."}",tostring(v)) end end
	return text
end
function Locale:Resolve(value) if type(value)=="string" and string.sub(value,1,1)=="@" then return self:T(string.sub(value,2)) end; return value end
function Locale:Destroy() self.Changed:Destroy(); self._locales={} end
return Locale

end

__modules["kernel/Motion"] = function()
--!nonstrict
local TweenService=game:GetService("TweenService")
local Janitor=__require("runtime/Janitor")
local Motion={}; Motion.__index=Motion
function Motion.new()
	return setmetatable({Enabled=true,_active=setmetatable({}, {__mode="k"}),_janitor=Janitor.new("Motion")},Motion)
end
Motion.Presets={Fast=TweenInfo.new(0.1,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),Normal=TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),Slow=TweenInfo.new(0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)}
function Motion:SetEnabled(v) self.Enabled=v==true end
function Motion:Tween(instance, info, props)
	local old=self._active[instance]; if old then pcall(function() old:Cancel() end) end
	if not self.Enabled then for k,v in props do instance[k]=v end; return nil end
	if type(info)=="string" then info=Motion.Presets[info] or Motion.Presets.Normal end
	info=info or Motion.Presets.Normal
	local tween=TweenService:Create(instance,info,props); self._active[instance]=tween
	tween.Completed:Once(function() if self._active[instance]==tween then self._active[instance]=nil end end); tween:Play(); return tween
end
function Motion:Destroy() for _,t in self._active do pcall(function() t:Cancel() end) end; self._active={}; self._janitor:Destroy() end
return Motion

end

__modules["kernel/Registry"] = function()
--!nonstrict
local Signal = __require("runtime/Signal")
local Registry = {}; Registry.__index = Registry
function Registry.new()
	return setmetatable({Added=Signal.new("Registry.Added"),Removed=Signal.new("Registry.Removed"),_byId={},_entries={},_anon=0}, Registry)
end
function Registry:Add(handle, meta)
	meta = meta or {}; local id = meta.Id or handle.Id
	if id and self._byId[id] then
		local old=self._byId[id]; error(`[BobloUI] duplicate Id "{id}". First registered at {old.Path or old.Type or "unknown"}.`,2)
	end
	local key=id
	if not key then self._anon+=1; key=`__anon_{self._anon}` end
	local entry={Key=key,Id=id,Handle=handle,Type=meta.Type or handle.Type,Title=meta.Title or handle.Title or "",Description=meta.Description or "",Keywords=meta.Keywords or {},Tab=meta.Tab,Section=meta.Section,Path=meta.Path,Persist=meta.Persist==true,Hidden=false}
	self._entries[key]=entry; if id then self._byId[id]=entry end
	handle._registryKey=key; self.Added:Fire(entry); return entry
end
function Registry:Get(id) local e=self._byId[id]; return e and e.Handle or nil end
function Registry:GetEntry(id) return self._byId[id] end
function Registry:Has(id) return self._byId[id]~=nil end
function Registry:Update(handle, fields)
	local e=self._entries[handle._registryKey or handle.Id]; if not e then return end
	for k,v in fields do e[k]=v end
end
function Registry:Remove(handleOrId)
	local e
	if type(handleOrId)=="string" then e=self._byId[handleOrId] or self._entries[handleOrId]
	else e=self._entries[handleOrId._registryKey or handleOrId.Id] end
	if not e then return end
	self._entries[e.Key]=nil; if e.Id then self._byId[e.Id]=nil end; self.Removed:Fire(e)
end
function Registry:Entries() local out={}; for _,e in self._entries do table.insert(out,e) end; return out end
function Registry:GetPersistable() local out={}; for _,e in self._entries do if e.Id and e.Persist and e.Handle and not e.Handle._destroyed then table.insert(out,e) end end; return out end
function Registry:Destroy() self.Added:Destroy(); self.Removed:Destroy(); self._byId={}; self._entries={} end
return Registry

end

__modules["kernel/Store"] = function()
--!nonstrict
--[[ Central synchronous state store with batching and dependency tracking. ]]
local Signal = __require("runtime/Signal")
local Util = __require("runtime/Util")

local Store = {}
Store.__index = Store

local function equal(a, b)
	if rawequal(a, b) then return true end
	if typeof(a) ~= typeof(b) then return false end
	local kind = typeof(a)
	if kind == "Color3" then return a.R == b.R and a.G == b.G and a.B == b.B end
	if kind == "Vector2" or kind == "Vector3" or kind == "UDim2" or kind == "CFrame" then return a == b end
	if type(a) == "table" and type(b) == "table" then
		for k, v in a do if not equal(v, b[k]) then return false end end
		for k in b do if a[k] == nil then return false end end
		return true
	end
	return a == b
end

function Store.new()
	return setmetatable({
		Changed = Signal.new("State.Changed"),
		_values = {}, _present = {}, _defaults = {}, _defaultPresent = {}, _watchers = {},
		_batchDepth = 0, _pending = {}, _destroyed = false,
		_dispatchDepth = 0,
	}, Store)
end

function Store:Get(id) return self._values[id] end
function Store:Has(id) return self._present[id] == true end
function Store:Snapshot() return Util.deepCopy(self._values) end
function Store:SetDefault(id, value)
	if not self._defaultPresent[id] then self._defaults[id] = Util.deepCopy(value); self._defaultPresent[id] = true end
	if not self._present[id] then self._values[id] = Util.deepCopy(value); self._present[id] = true end
	return self._values[id]
end

function Store:_dispatch(id, value, oldValue, origin)
	self._dispatchDepth += 1
	if self._dispatchDepth > 64 then
		self._dispatchDepth -= 1
		error(`[BobloUI] State cascade exceeded 64 updates near "{id}". Check recursive watchers.`, 3)
	end
	local bucket = self._watchers[id]
	if bucket then
		local copy = table.clone(bucket)
		for _, fn in copy do
			if table.find(bucket, fn) then
				local ok, err = xpcall(fn, debug.traceback, value, oldValue, id, origin)
				if not ok then warn(`[BobloUI] State watcher "{id}" failed:\n{err}`) end
			end
		end
	end
	self.Changed:Fire(id, value, oldValue, origin)
	self._dispatchDepth -= 1
end

function Store:Set(id, value, origin)
	if self._destroyed then error("[BobloUI] State store is destroyed.", 2) end
	if type(id) ~= "string" or id == "" then error("[BobloUI] State:Set requires a non-empty string id.", 2) end
	local old = self._values[id]
	if self._present[id] and equal(old, value) then return false end
	self._values[id] = value
	self._present[id] = true
	if self._batchDepth > 0 then
		local pending = self._pending[id]
		if pending then pending.newValue, pending.origin = value, origin
		else self._pending[id] = {oldValue = old, newValue = value, origin = origin} end
	else
		self:_dispatch(id, value, old, origin)
	end
	return true
end

function Store:Update(id, fn, origin)
	if type(fn) ~= "function" then error("[BobloUI] State:Update expects a function.", 2) end
	return self:Set(id, fn(self:Get(id)), origin)
end

function Store:Reset(id, origin)
	if not self._defaultPresent[id] then return false end
	return self:Set(id, Util.deepCopy(self._defaults[id]), origin)
end

function Store:Watch(id, fn)
	if type(fn) ~= "function" then error("[BobloUI] State:Watch expects a function.", 2) end
	local bucket = self._watchers[id]
	if not bucket then bucket = {}; self._watchers[id] = bucket end
	table.insert(bucket, fn)
	local alive = true
	return function()
		if not alive then return end
		alive = false
		local current = self._watchers[id]
		if current then
			local pos = table.find(current, fn)
			if pos then table.remove(current, pos) end
			if #current == 0 then self._watchers[id] = nil end
		end
	end
end

function Store:WatchMany(ids, fn)
	local unsubs = {}
	local function emit(_, _, changedId, origin)
		local snapshot = {}
		for _, id in ids do snapshot[id] = self:Get(id) end
		fn(snapshot, changedId, origin)
	end
	for _, id in ids do table.insert(unsubs, self:Watch(id, emit)) end
	return function() for _, unsub in unsubs do unsub() end end
end

function Store:Batch(fn)
	self._batchDepth += 1
	local ok, result = xpcall(fn, debug.traceback)
	self._batchDepth -= 1
	if self._batchDepth == 0 then
		local pending = self._pending; self._pending = {}
		for id, change in pending do
			if not equal(change.oldValue, change.newValue) then
				self:_dispatch(id, change.newValue, change.oldValue, change.origin)
			end
		end
	end
	if not ok then error(result, 2) end
	return result
end

-- Runs predicate with a proxy that records every :Get(). Returns {ids}, result.
function Store:Track(predicate)
	if type(predicate) ~= "function" then error("[BobloUI] State:Track expects a function.", 2) end
	local seen, ordered = {}, {}
	local proxy = {}
	function proxy:Get(id)
		if not seen[id] then seen[id] = true; table.insert(ordered, id) end
		return self.__store:Get(id)
	end
	proxy.__store = self
	local ok, result = xpcall(predicate, debug.traceback, proxy)
	if not ok then error(`[BobloUI] dependency predicate failed:\n{result}`, 2) end
	return ordered, result
end

function Store:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	self.Changed:Destroy(); self._values = {}; self._present = {}; self._defaults = {}; self._defaultPresent = {}; self._watchers = {}; self._pending = {}
end
return Store

end

__modules["kernel/Theme"] = function()
--!nonstrict
--[[
	Theme — palette registry + binding registry.

	The binding registry is the point of this module. Every coloured property is
	registered once at creation:

		theme:Bind(frame, "BackgroundColor3", "Surface")

	A theme change is then a single pass over one flat array, instead of walking
	the Instance tree with a pcall per property. At 200 controls that is roughly
	2000 assignments — fine as a one-off, catastrophic as a tree walk.

	Deliberately NOT tweened. 2000 concurrent tweens is the single most
	expensive thing a Roblox UI can do; Window covers the swap with one short
	fade instead.
]]

local Signal = __require("runtime/Signal")
local Util = __require("runtime/Util")

local Theme = {}
Theme.__index = Theme

function Theme.new(options)
	options = options or {}

	local self = setmetatable({
		Changed = Signal.new("Theme.Changed"),

		_palettes = {},
		_name = nil,
		_base = nil,
		_resolved = nil,
		_accent = options.Accent,
		_overrides = {},
		_highContrast = false,

		_bindings = {},
		_free = {},
		_dropped = 0,
	}, Theme)

	if options.Palettes then
		for name, palette in options.Palettes do
			self:Register(name, palette)
		end
	end

	return self
end

-- ===== palettes ===================================================

function Theme:Register(name: string, palette)
	self._palettes[name] = palette
	if self._name == name then
		self:_resolve()
		self:_apply()
	end
end

function Theme:List(): { string }
	local names = Util.keys(self._palettes)
	table.sort(names)
	return names
end

function Theme:Current(): string?
	return self._name
end

--[[
	Derived accents.

	When an explicit accent is set, AccentHover/AccentPressed/AccentText are
	ALWAYS recomputed — a palette's own hover colour belongs to its own accent
	and would otherwise go stale the moment SetAccent is called. Without an
	explicit accent, the palette's values win.
]]
function Theme:_resolve()
	local base = self._palettes[self._name]
	if not base then
		error(`[BobloUI] theme "{tostring(self._name)}" is not registered`, 2)
	end

	local palette = table.clone(base)

	if self._accent then
		palette.Accent = self._accent
		palette.AccentHover = Util.lighten(self._accent, 0.12)
		palette.AccentPressed = Util.darken(self._accent, 0.12)
		palette.AccentText = Util.contrastText(self._accent)
	else
		palette.AccentHover = base.AccentHover or Util.lighten(base.Accent, 0.12)
		palette.AccentPressed = base.AccentPressed or Util.darken(base.Accent, 0.12)
		palette.AccentText = base.AccentText or Util.contrastText(base.Accent)
	end

	-- Apply base-token overrides before computing semantic derivatives so a
	-- custom Surface/Border immediately influences AccentSoft/Button/etc.
	for token, value in self._overrides do
		if value ~= nil then palette[token] = value end
	end

	local mixBase = palette.Surface or palette.Background
	palette.AccentSoft = palette.Accent:Lerp(mixBase, 0.90)
	palette.AccentMuted = palette.Accent:Lerp(mixBase, 0.72)
	palette.AccentBorder = palette.Accent:Lerp(palette.Border or mixBase, 0.48)
	palette.AccentButton = palette.Accent:Lerp(mixBase, 0.18)
	palette.AccentButtonHover = palette.Accent:Lerp(mixBase, 0.08)
	if self._highContrast then
		local dark = Util.luminance(palette.Canvas) < 0.5
		if dark then
			palette.Text = Color3.new(1,1,1)
			palette.TextSecondary = Color3.fromRGB(214,218,225)
			palette.BorderSubtle = Color3.fromRGB(58,64,74)
			palette.Border = Color3.fromRGB(78,85,97)
		else
			palette.Text = Color3.new(0,0,0)
			palette.TextSecondary = Color3.fromRGB(48,54,64)
			palette.BorderSubtle = Color3.fromRGB(190,196,205)
			palette.Border = Color3.fromRGB(160,168,179)
		end
	end

	self._base = base
	self._resolved = palette
end

function Theme:Palette()
	return table.clone(self._resolved)
end

function Theme:Get(token): any
	if type(token) == "function" then
		return token(self._resolved)
	end
	local value = self._resolved[token]
	if value == nil then
		local suggestion = Util.suggest(token, Util.keys(self._resolved))
		local hint = if suggestion then ` Did you mean "{suggestion}"?` else ""
		error(`[BobloUI] unknown theme token "{token}".{hint}`, 2)
	end
	return value
end

function Theme:Set(name: string)
	if not self._palettes[name] then
		local suggestion = Util.suggest(name, self:List())
		local hint = if suggestion then ` Did you mean "{suggestion}"?` else ""
		error(`[BobloUI] theme "{name}" is not registered.{hint}`, 2)
	end
	if self._name == name then
		return
	end
	self._name = name
	self:_resolve()
	self:_apply()
	self.Changed:Fire(name)
end

function Theme:SetAccent(colour: Color3?)
	self._accent = colour
	self:_resolve()
	self:_apply()
	self.Changed:Fire(self._name)
end

function Theme:SetToken(token, colour)
	if self._resolved and self._resolved[token] == nil then
		error(`[BobloUI] cannot override unknown theme token "{tostring(token)}".`,2)
	end
	if colour ~= nil and typeof(colour) ~= "Color3" then error("[BobloUI] Theme:SetToken expects Color3 or nil.",2) end
	self._overrides[token]=colour
	self:_resolve(); self:_apply(); self.Changed:Fire(self._name)
	return self
end
function Theme:GetOverrides() return table.clone(self._overrides) end
function Theme:ResetToken(token) return self:SetToken(token,nil) end
function Theme:ResetOverrides() self._overrides={}; self:_resolve(); self:_apply(); self.Changed:Fire(self._name); return self end
function Theme:SetHighContrast(enabled)
	enabled=enabled==true; if self._highContrast==enabled then return self end
	self._highContrast=enabled; self:_resolve(); self:_apply(); self.Changed:Fire(self._name); return self
end
function Theme:IsHighContrast() return self._highContrast end
function Theme:Export()
	local data={Theme=self._name,HighContrast=self._highContrast,Overrides={}}
	if self._accent then data.Accent="#"..self._accent:ToHex() end
	for token,value in self._overrides do if typeof(value)=="Color3" then data.Overrides[token]="#"..value:ToHex() end end
	return data
end
function Theme:Import(data)
	if type(data)~="table" then return false,"theme import expects table" end
	if data.Theme and self._palettes[data.Theme] then self._name=data.Theme end
	if type(data.Accent)=="string" then local ok,c=pcall(Color3.fromHex,string.gsub(data.Accent,"#","")); if ok then self._accent=c end end
	self._overrides={}
	for token,value in data.Overrides or {} do
		if type(value)=="string" then local ok,c=pcall(Color3.fromHex,string.gsub(value,"#","")); if ok then self._overrides[token]=c end end
	end
	self._highContrast=data.HighContrast==true; self:_resolve(); self:_apply(); self.Changed:Fire(self._name); return true
end

-- ===== bindings ===================================================

--[[
	Bind(instance, property, token) -> handle

	The handle must be stored in the owner's Janitor. BaseControl does this
	automatically (step 7); shell code does it explicitly.
]]
function Theme:Bind(instance: Instance, property: string, token): number
	local binding = { instance = instance, property = property, token = token }

	local slot = table.remove(self._free)
	if slot then
		self._bindings[slot] = binding
	else
		table.insert(self._bindings, binding)
		slot = #self._bindings
	end

	if self._resolved then
		instance[property] = self:Get(token)
	end

	return slot
end

--- Bind several properties of one instance. Returns a single handle.
function Theme:BindMany(instance: Instance, map: { [string]: any }): { number }
	local handles = {}
	for property, token in map do
		table.insert(handles, self:Bind(instance, property, token))
	end
	return handles
end

function Theme:Unbind(handle)
	if type(handle) == "table" then
		for _, single in handle do
			self:Unbind(single)
		end
		return
	end
	if self._bindings[handle] then
		self._bindings[handle] = false
		table.insert(self._free, handle)
	end
end

function Theme:_apply()
	local bindings = self._bindings
	local dropped = 0

	for slot = 1, #bindings do
		local binding = bindings[slot]
		if binding then
			local ok = pcall(function()
				binding.instance[binding.property] = self:Get(binding.token)
			end)
			if not ok then
				-- Instance destroyed without unbinding. Reclaim the slot.
				bindings[slot] = false
				table.insert(self._free, slot)
				dropped += 1
			end
		end
	end

	self._dropped += dropped
	if dropped > 0 then
		-- Not fatal, but it means some owner forgot its Janitor entry.
		warn(`[BobloUI] Theme dropped {dropped} binding(s) to destroyed instances.`)
	end
end

function Theme:BindingCount(): number
	local n = 0
	for _, binding in self._bindings do
		if binding then
			n += 1
		end
	end
	return n
end

function Theme:Destroy()
	self._bindings = {}
	self._free = {}
	self.Changed:Destroy()
end

return Theme


end

__modules["kernel/Tokens"] = function()
--!nonstrict
local Signal = __require("runtime/Signal")

local Tokens = {}
Tokens.__index = Tokens
Tokens.MinTapTarget = 42

local function enumFont(name, fallback)
	for _, item in Enum.Font:GetEnumItems() do
		if item.Name == name then return item end
	end
	return fallback
end

Tokens.Fonts = {
	Regular = enumFont("BuilderSans", Enum.Font.Gotham),
	Medium = enumFont("BuilderSansMedium", Enum.Font.GothamMedium),
	Bold = enumFont("BuilderSansBold", Enum.Font.GothamBold),
	Heavy = enumFont("BuilderSansExtraBold", Enum.Font.GothamBold),
}

Tokens.Profiles = {
	Comfortable = {
		ControlHeight = 46,
		ControlPadding = 13,
		ControlRadius = 8,
		FieldHeight = 34,
		FieldRadius = 8,
		RowGap = 0,
		SectionGap = 16,
		ColumnGap = 14,
		TwoColumnMinWidth = 586,
		MinSectionWidth = 286,
		ControlStackBreakpoint = 300,
		ControlGridMinWidth = 600,
		SectionPadding = 12,
		PagePadding = 20,
		HeaderHeight = 56,
		SidebarWidth = 168,
		RailWidth = 54,
		NavItemHeight = 38,
		FontCaption = 11,
		FontSmall = 12,
		FontBody = 14,
		FontTitle = 15,
		FontHeading = 18,
		FontDisplay = 21,
		IconSm = 14,
		IconMd = 18,
		CornerSm = 7,
		CornerMd = 10,
		CornerLg = 14,
		Stroke = 1,
		SliderTrack = 2,
		SliderKnob = 10,
	},
	Compact = {
		ControlHeight = 40,
		ControlPadding = 10,
		ControlRadius = 9,
		FieldHeight = 31,
		FieldRadius = 7,
		RowGap = 0,
		SectionGap = 10,
		ColumnGap = 12,
		TwoColumnMinWidth = 546,
		MinSectionWidth = 267,
		ControlStackBreakpoint = 282,
		ControlGridMinWidth = 560,
		SectionPadding = 9,
		PagePadding = 18,
		HeaderHeight = 50,
		SidebarWidth = 158,
		RailWidth = 50,
		NavItemHeight = 35,
		FontCaption = 10,
		FontSmall = 11,
		FontBody = 13,
		FontTitle = 14,
		FontHeading = 18,
		FontDisplay = 20,
		IconSm = 14,
		IconMd = 18,
		CornerSm = 7,
		CornerMd = 10,
		CornerLg = 15,
		Stroke = 1,
		SliderTrack = 3,
		SliderKnob = 10,
	},
	Touch = {
		ControlHeight = 48,
		ControlPadding = 13,
		ControlRadius = 11,
		FieldHeight = 38,
		FieldRadius = 9,
		RowGap = 0,
		SectionGap = 15,
		ColumnGap = 14,
		TwoColumnMinWidth = 626,
		MinSectionWidth = 306,
		ControlStackBreakpoint = 324,
		ControlGridMinWidth = 640,
		SectionPadding = 14,
		PagePadding = 14,
		HeaderHeight = 54,
		SidebarWidth = 238,
		RailWidth = 60,
		NavItemHeight = 48,
		FontCaption = 11,
		FontSmall = 13,
		FontBody = 15,
		FontTitle = 16,
		FontHeading = 20,
		FontDisplay = 22,
		IconSm = 17,
		IconMd = 21,
		CornerSm = 8,
		CornerMd = 12,
		CornerLg = 17,
		Stroke = 1,
		SliderTrack = 4,
		SliderKnob = 16,
	},
}

function Tokens.new(density: string?, deviceClass: string?)
	local self = setmetatable({Changed=Signal.new("Tokens.Changed"),_density=density or "Comfortable",_deviceClass=deviceClass or "Desktop",_values={}}, Tokens)
	self:_recompute(); return self
end
function Tokens:_effectiveDensity()
	if self._deviceClass == "Phone" and self._density == "Comfortable" then return "Touch" end
	return self._density
end
function Tokens:_recompute()
	local profile=Tokens.Profiles[self:_effectiveDensity()] or Tokens.Profiles.Comfortable
	local values=table.clone(profile)
	if self._deviceClass=="Phone" then
		values.ControlHeight=math.max(values.ControlHeight,Tokens.MinTapTarget)
		values.NavItemHeight=math.max(values.NavItemHeight,Tokens.MinTapTarget)
		values.FieldHeight=math.max(values.FieldHeight,34)
	end
	self._values=values
end
function Tokens:Get(key) local value=self._values[key]; if value==nil then error(`[BobloUI] unknown token "{key}"`,2) end; return value end
function Tokens:All() return table.clone(self._values) end
function Tokens:GetDensity() return self._density end
function Tokens:SetDensity(density)
	if not Tokens.Profiles[density] then error(`[BobloUI] unknown density "{density}". Valid: Comfortable, Compact, Touch`,2) end
	if self._density==density then return end; self._density=density; self:_recompute(); self.Changed:Fire(self)
end
function Tokens:SetDeviceClass(deviceClass)
	if self._deviceClass==deviceClass then return end; self._deviceClass=deviceClass; local before=self._values; self:_recompute()
	for key,value in self._values do if before[key]~=value then self.Changed:Fire(self); return end end
end
function Tokens:Destroy() self.Changed:Destroy() end
return Tokens

end

__modules["primitives/Badge"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Badge={}
local BG={Neutral="SurfaceSecondary",Info="AccentSoft",Success="Success",Warning="Warning",Danger="Error"}
local FG={Neutral="TextSecondary",Info="Accent",Success="AccentText",Warning="AccentText",Danger="AccentText"}
function Badge.new(window,text,style,parent)
	style=style or "Neutral"
	local label=Create.New("TextLabel",{AutomaticSize=Enum.AutomaticSize.XY,BackgroundTransparency=0,Text=string.upper(text or ""),Font=window.Fonts.Bold,TextSize=window.Tokens:Get("FontCaption"),Parent=parent})
	Create.New("UIPadding",{PaddingLeft=UDim.new(0,7),PaddingRight=UDim.new(0,7),PaddingTop=UDim.new(0,3),PaddingBottom=UDim.new(0,3),Parent=label})
	Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=label})
	window:_bind(label,{BackgroundColor3=BG[style] or BG.Neutral,TextColor3=FG[style] or FG.Neutral}); return label
end
return Badge

end

__modules["primitives/Icon"] = function()
--!nonstrict
-- BobloUI built-in icon primitive.
-- Core icons are drawn from GuiObjects so they do not depend on font glyphs or
-- external assets. Custom rbxasset:// / rbxassetid:// images can still be registered.
local Create = __require("runtime/Create")

local Icon = { Registry = {} }

function Icon.Register(name, value)
	Icon.Registry[name] = value
end

local function copyLayoutProps(props)
	local allowed = {
		Name=true, Size=true, Position=true, AnchorPoint=true, Parent=true,
		LayoutOrder=true, ZIndex=true, Visible=true, Rotation=true,
	}
	local out = { BackgroundTransparency = 1, BorderSizePixel = 0 }
	for key, value in props or {} do
		if allowed[key] then out[key] = value end
	end
	return out
end

local function tag(instance)
	instance:SetAttribute("BobloIconPart", true)
	return instance
end

local function bindPart(window, instance, token)
	if instance:IsA("UIStroke") then
		window:_bind(instance, { Color = token or "TextSecondary" })
	elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		window:_bind(instance, { ImageColor3 = token or "TextSecondary" })
	elseif instance:IsA("TextLabel") or instance:IsA("TextButton") then
		window:_bind(instance, { TextColor3 = token or "TextSecondary" })
	else
		window:_bind(instance, { BackgroundColor3 = token or "TextSecondary" })
	end
end

local function part(window, parent, props, token)
	props = props or {}
	props.BorderSizePixel = 0
	props.Parent = parent
	local item = tag(Create.New("Frame", props))
	bindPart(window, item, token)
	return item
end

local function rounded(window, parent, props, radius, token)
	local item = part(window, parent, props, token)
	Create.New("UICorner", { CornerRadius = UDim.new(radius == 1 and 1 or 0, radius == 1 and 0 or (radius or 2)), Parent = item })
	return item
end

local function line(window, parent, x, y, width, height, rotation, token)
	local item = rounded(window, parent, {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.new(0.5, x, 0.5, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation or 0,
	}, 1, token)
	return item
end

local Draw = {}

Draw.dashboard = function(window, root)
	for _, p in {{-4.5,-4.5},{4.5,-4.5},{-4.5,4.5},{4.5,4.5}} do
		rounded(window, root, {Size=UDim2.fromOffset(6,6), Position=UDim2.new(0.5,p[1],0.5,p[2]), AnchorPoint=Vector2.new(0.5,0.5)}, 2)
	end
end
Draw["layout-dashboard"] = Draw.dashboard
Draw.home = Draw.dashboard

Draw.user = function(window, root)
	rounded(window, root, {Size=UDim2.fromOffset(7,7), Position=UDim2.new(0.5,0,0.5,-4.5), AnchorPoint=Vector2.new(0.5,0.5)}, 1)
	rounded(window, root, {Size=UDim2.fromOffset(14,7), Position=UDim2.new(0.5,0,0.5,5), AnchorPoint=Vector2.new(0.5,0.5)}, 4)
end
Draw.player = Draw.user

Draw.eye = function(window, root)
	local ring = tag(Create.New("Frame", {Size=UDim2.fromOffset(16,10), Position=UDim2.fromScale(0.5,0.5), AnchorPoint=Vector2.new(0.5,0.5), BackgroundTransparency=1, BorderSizePixel=0, Parent=root}))
	Create.New("UICorner", {CornerRadius=UDim.new(1,0), Parent=ring})
	local stroke = tag(Create.New("UIStroke", {Thickness=1.4, Transparency=0.05, Parent=ring}))
	bindPart(window, stroke)
	rounded(window, root, {Size=UDim2.fromOffset(4.5,4.5), Position=UDim2.fromScale(0.5,0.5), AnchorPoint=Vector2.new(0.5,0.5)}, 1)
end
Draw.visuals = Draw.eye

Draw.settings = function(window, root)
	local ring = tag(Create.New("Frame", {Size=UDim2.fromOffset(9,9), Position=UDim2.fromScale(0.5,0.5), AnchorPoint=Vector2.new(0.5,0.5), BackgroundTransparency=1, BorderSizePixel=0, Parent=root}))
	Create.New("UICorner", {CornerRadius=UDim.new(1,0), Parent=ring})
	local stroke = tag(Create.New("UIStroke", {Thickness=1.5, Parent=ring}))
	bindPart(window, stroke)
	for _, r in {0,45,90,135} do line(window, root, 0, 0, 16, 2, r) end
	-- redraw centre on top so the spokes read as a gear, not an asterisk
	local cover = rounded(window, root, {Size=UDim2.fromOffset(7,7), Position=UDim2.fromScale(0.5,0.5), AnchorPoint=Vector2.new(0.5,0.5)}, 1, "Sidebar")
	cover:SetAttribute("BobloIconMask", true)
	local inner = rounded(window, root, {Size=UDim2.fromOffset(3,3), Position=UDim2.fromScale(0.5,0.5), AnchorPoint=Vector2.new(0.5,0.5)}, 1)
end

Draw.search = function(window, root)
	local ring = tag(Create.New("Frame", {Size=UDim2.fromOffset(10,10), Position=UDim2.new(0.5,-2,0.5,-2), AnchorPoint=Vector2.new(0.5,0.5), BackgroundTransparency=1, BorderSizePixel=0, Parent=root}))
	Create.New("UICorner", {CornerRadius=UDim.new(1,0), Parent=ring})
	local stroke=tag(Create.New("UIStroke", {Thickness=1.4, Transparency=0.04, Parent=ring})); bindPart(window,stroke)
	line(window,root,5,5,6,1.5,45)
end

Draw.close = function(window, root)
	line(window,root,0,0,13,1.6,45)
	line(window,root,0,0,13,1.6,-45)
end

Draw.menu = function(window, root)
	for _, y in {-5,0,5} do line(window,root,0,y,15,1.6,0) end
end

Draw.chevron_down = function(window, root)
	line(window,root,-3,0,7,1.5,45)
	line(window,root,3,0,7,1.5,-45)
end
Draw.chevron_right = function(window, root)
	line(window,root,0,-3,7,1.5,45)
	line(window,root,0,3,7,1.5,-45)
end
Draw.chevron_up = function(window, root)
	line(window,root,-3,0,7,1.5,-45)
	line(window,root,3,0,7,1.5,45)
end

Draw.check = function(window, root)
	line(window,root,-3,1,6,1.6,45)
	line(window,root,3,-1,10,1.6,-45)
end

Draw.plus = function(window, root)
	line(window,root,0,0,13,1.5,0); line(window,root,0,0,13,1.5,90)
end
Draw.minus = function(window, root) line(window,root,0,0,13,1.5,0) end

Draw.moon = function(window, root)
	local ring = tag(Create.New("Frame", {Size=UDim2.fromOffset(14,14), Position=UDim2.fromScale(0.5,0.5), AnchorPoint=Vector2.new(0.5,0.5), BackgroundTransparency=1, BorderSizePixel=0, Parent=root}))
	Create.New("UICorner", {CornerRadius=UDim.new(1,0), Parent=ring})
	local stroke=tag(Create.New("UIStroke", {Thickness=1.4, Transparency=0.04, Parent=ring})); bindPart(window,stroke)
	local mask=rounded(window,root,{Size=UDim2.fromOffset(11,11),Position=UDim2.new(0.5,3,0.5,-3),AnchorPoint=Vector2.new(0.5,0.5)},1,"Canvas")
	mask:SetAttribute("BobloIconMask",true)
end
Draw.palette = Draw.moon

Draw.command = function(window, root)
	for _, p in {{-4,-4},{4,-4},{-4,4},{4,4}} do
		local ring=tag(Create.New("Frame",{Size=UDim2.fromOffset(6,6),Position=UDim2.new(0.5,p[1],0.5,p[2]),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Parent=root}))
		Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=ring}); local s=tag(Create.New("UIStroke",{Thickness=1.2,Parent=ring})); bindPart(window,s)
	end
	line(window,root,0,-4,8,1.2,0); line(window,root,0,4,8,1.2,0); line(window,root,-4,0,8,1.2,90); line(window,root,4,0,8,1.2,90)
end

Draw.star = function(window, root)
	-- restrained sparkle, used as a generic fallback action icon
	line(window,root,0,0,14,1.4,0); line(window,root,0,0,14,1.4,90)
	line(window,root,0,0,9,1.2,45); line(window,root,0,0,9,1.2,-45)
end

Draw.copy = function(window, root)
	local a=tag(Create.New("Frame",{Size=UDim2.fromOffset(10,10),Position=UDim2.new(0.5,-2,0.5,2),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Parent=root})); Create.New("UICorner",{CornerRadius=UDim.new(0,2),Parent=a}); local sa=tag(Create.New("UIStroke",{Thickness=1.2,Parent=a})); bindPart(window,sa)
	local b=tag(Create.New("Frame",{Size=UDim2.fromOffset(10,10),Position=UDim2.new(0.5,2,0.5,-2),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Parent=root})); Create.New("UICorner",{CornerRadius=UDim.new(0,2),Parent=b}); local sb=tag(Create.New("UIStroke",{Thickness=1.2,Parent=b})); bindPart(window,sb)
end
Draw.reset = function(window, root)
	local ring=tag(Create.New("Frame",{Size=UDim2.fromOffset(13,13),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Parent=root})); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=ring}); local st=tag(Create.New("UIStroke",{Thickness=1.3,Transparency=0.05,Parent=ring})); bindPart(window,st)
	local mask=rounded(window,root,{Size=UDim2.fromOffset(7,5),Position=UDim2.new(0.5,5,0.5,-5),AnchorPoint=Vector2.new(0.5,0.5)},1,"SurfaceRaised"); mask:SetAttribute("BobloIconMask",true)
	line(window,root,4,-5,6,1.4,0); line(window,root,2,-3,5,1.4,90)
end

Draw.info = function(window, root)
	local ring=tag(Create.New("Frame",{Size=UDim2.fromOffset(15,15),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Parent=root}))
	Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=ring}); local s=tag(Create.New("UIStroke",{Thickness=1.3,Parent=ring})); bindPart(window,s)
	rounded(window,root,{Size=UDim2.fromOffset(1.8,6),Position=UDim2.new(0.5,0,0.5,2),AnchorPoint=Vector2.new(0.5,0.5)},1)
	rounded(window,root,{Size=UDim2.fromOffset(2,2),Position=UDim2.new(0.5,0,0.5,-4),AnchorPoint=Vector2.new(0.5,0.5)},1)
end

function Icon.setColor(instance, color)
	if not instance then return end
	local function apply(item)
		if item:GetAttribute("BobloIconMask") then return end
		if item:GetAttribute("BobloIconPart") then
			if item:IsA("UIStroke") then item.Color=color
			elseif item:IsA("ImageLabel") or item:IsA("ImageButton") then item.ImageColor3=color
			elseif item:IsA("TextLabel") or item:IsA("TextButton") then item.TextColor3=color
			elseif item:IsA("GuiObject") then item.BackgroundColor3=color end
		end
	end
	apply(instance)
	for _, item in instance:GetDescendants() do apply(item) end
end

function Icon.new(window, name, props)
	props = props or {}
	local custom = Icon.Registry[name]
	if type(custom) == "string" and (string.find(custom,"rbxasset://",1,true) or string.find(custom,"rbxassetid://",1,true)) then
		local imageProps = table.clone(props)
		imageProps.BackgroundTransparency=1; imageProps.Image=custom
		local image=tag(Create.New("ImageLabel",imageProps)); bindPart(window,image); return image
	end
	if type(custom) == "function" then
		local root=Create.New("Frame",copyLayoutProps(props)); custom(window,root); return root
	end
	if type(custom) == "string" then
		local textProps=table.clone(props); textProps.BackgroundTransparency=1; textProps.Text=custom; textProps.Font=window.Fonts.Medium; textProps.TextSize=textProps.TextSize or window.Tokens:Get("FontTitle")
		local label=tag(Create.New("TextLabel",textProps)); bindPart(window,label); return label
	end
	local drawer = Draw[name]
	if drawer then
		local root=Create.New("Frame",copyLayoutProps(props)); drawer(window,root); return root
	end
	-- Unknown custom names degrade to a small neutral dot rather than a Unicode glyph.
	local root=Create.New("Frame",copyLayoutProps(props))
	rounded(window,root,{Size=UDim2.fromOffset(5,5),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5)},1)
	return root
end

return Icon

end

__modules["primitives/Popover"] = function()
--!nonstrict
local Surface=__require("primitives/Surface")
local Popover={}

function Popover.open(window,anchor,size,options)
	options=options or {}
	local handle=window.Layers:Push({Scrim=false,Modal=false,OnDismiss=options.OnDismiss})
	local currentSize=Vector2.new(math.max(1,size.X),math.max(1,size.Y))
	local frame=Surface.new(window,{
		Name="Popover",
		Size=UDim2.fromOffset(currentSize.X,currentSize.Y),
		BorderSizePixel=0,
		Parent=handle.Container,
	},{
		Token="SurfaceRaised",
		StrokeToken="Border",
		StrokeTransparency=0.42,
		Corner=options.Corner or window.Tokens:Get("CornerMd"),
	})
	frame.ZIndex=handle.Depth*10+2

	local function place()
		if not anchor or not anchor.Parent then handle:Dismiss(); return end
		local pos,asz=anchor.AbsolutePosition,anchor.AbsoluteSize
		local safePos,safeSize=window.Device:SafeArea()
		local minX=safePos.X+8
		local maxX=math.max(minX,safePos.X+safeSize.X-currentSize.X-8)
		local minY=safePos.Y+8
		local maxY=safePos.Y+safeSize.Y-currentSize.Y-8
		local x=math.clamp(pos.X,minX,maxX)
		local below=pos.Y+asz.Y+5
		local y
		if below+currentSize.Y<=safePos.Y+safeSize.Y-8 then
			y=below
		else
			y=math.max(minY,pos.Y-currentSize.Y-5)
		end
		frame.Position=UDim2.fromOffset(x,math.min(y,maxY))
	end

	place()
	local c1=anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	local c2=anchor:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	local c3=window.Device.Changed:Connect(place)
	local oldDismiss=handle.Dismiss

	function handle:SetSize(newSize)
		if self._dismissed then return self end
		currentSize=Vector2.new(math.max(1,newSize.X),math.max(1,newSize.Y))
		frame.Size=UDim2.fromOffset(currentSize.X,currentSize.Y)
		place()
		return self
	end
	function handle:Reposition()
		if not self._dismissed then place() end
		return self
	end
	function handle:GetSize() return currentSize end
	function handle:Dismiss()
		if self._dismissed then return end
		c1:Disconnect(); c2:Disconnect(); c3:Disconnect(); oldDismiss(self)
	end

	handle.Frame=frame
	return handle
end
return Popover

end

__modules["primitives/Scroller"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Scroller={}
function Scroller.new(window,props)
	props=props or {}; props.BackgroundTransparency=props.BackgroundTransparency or 1; props.BorderSizePixel=0; props.CanvasSize=props.CanvasSize or UDim2.new(); props.AutomaticCanvasSize=props.AutomaticCanvasSize or Enum.AutomaticSize.Y; props.ScrollingDirection=props.ScrollingDirection or Enum.ScrollingDirection.Y; props.ScrollBarThickness=props.ScrollBarThickness or 4
	local frame=Create.New("ScrollingFrame",props); window:_bind(frame,{ScrollBarImageColor3="BorderStrong"}); return frame
end
return Scroller

end

__modules["primitives/Sheet"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Surface=__require("primitives/Surface")
local Sheet={}

function Sheet.open(window,height,options)
	options=options or {}; local requestedHeight=height
	local handle=window.Layers:Push({Scrim=true,ScrimTransparency=0.56,Modal=false,OnDismiss=options.OnDismiss})
	local function metrics()
		local safePos,safeSize=window.Device:SafeArea(); local keyboard=window.Device.KeyboardHeight or 0
		local usableH=math.max(120,safeSize.Y-keyboard)
		local h=math.min(requestedHeight or math.floor(usableH*0.6),math.floor(usableH*0.82))
		return safePos,safeSize,usableH,h
	end
	local safePos,safeSize,usableH,h=metrics()
	local frame=Surface.new(window,{Name="Sheet",Size=UDim2.fromOffset(math.max(1,safeSize.X-12),h),Position=UDim2.fromOffset(safePos.X+6,safePos.Y+usableH-6),AnchorPoint=Vector2.new(0,1),BorderSizePixel=0,Parent=handle.Container},{Token="SurfaceRaised",StrokeToken="Border",StrokeTransparency=0.42,Corner=window.Tokens:Get("CornerLg")})
	frame.ZIndex=handle.Depth*10+2
	local grab=Create.New("TextButton",{Size=UDim2.fromOffset(64,22),Position=UDim2.new(0.5,0,0,0),AnchorPoint=Vector2.new(0.5,0),BackgroundTransparency=1,BorderSizePixel=0,Text="",Parent=frame})
	local bar=Create.New("Frame",{Size=UDim2.fromOffset(32,3),Position=UDim2.new(0.5,0,0,7),AnchorPoint=Vector2.new(0.5,0),BorderSizePixel=0,Parent=grab}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=bar}); window:_bind(bar,{BackgroundColor3="Border"})
	local function layout()
		if not frame.Parent then return end; local p,s,u,hh=metrics(); frame.Size=UDim2.fromOffset(math.max(1,s.X-12),hh); frame.Position=UDim2.fromOffset(p.X+6,p.Y+u-6)
	end
	local conn=window.Device.Changed:Connect(layout)
	local oldDismiss=handle.Dismiss
	local dragStart
	local dragConn=grab.InputBegan:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
		dragStart=input.Position; window.Input:CapturePointer(handle,input,function(move)
			local dy=math.max(0,move.Position.Y-dragStart.Y)
			local p,s,u=metrics(); frame.Position=UDim2.fromOffset(p.X+6,p.Y+u-6+dy)
		end,function(move,cancelled)
			local dy=move and math.max(0,move.Position.Y-dragStart.Y) or 0; if not cancelled and dy>60 then handle:Dismiss() else layout() end
		end)
	end)
	function handle:SetHeight(newHeight) requestedHeight=newHeight; layout(); return self end
	function handle:Dismiss() if self._dismissed then return end; window.Input:CancelCapture(self); conn:Disconnect(); dragConn:Disconnect(); oldDismiss(self) end
	handle.Frame=frame; return handle
end
return Sheet

end

__modules["primitives/Spinner"] = function()
--!nonstrict
local TweenService=game:GetService("TweenService")
local Create=__require("runtime/Create")
local Spinner={}
function Spinner.new(window,parent,size)
	local label=Create.New("TextLabel",{Size=UDim2.fromOffset(size or 16,size or 16),BackgroundTransparency=1,Text=window.Motion and not window.Motion.Enabled and "…" or "◌",Font=window.Fonts.Bold,TextSize=size or 16,Parent=parent}); window:_bind(label,{TextColor3="Text"})
	if not window.Motion or window.Motion.Enabled then
		local tween=TweenService:Create(label,TweenInfo.new(0.8,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1),{Rotation=360}); tween:Play()
		label.Destroying:Once(function() pcall(function() tween:Cancel() end) end)
	end
	return label
end
return Spinner

end

__modules["primitives/Surface"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Surface={}
function Surface.new(window,props,options)
	props=props or {}; options=options or {}
	local frame=Create.New(options.ClassName or "Frame",props)
	if options.Corner~=false then Create.New("UICorner",{CornerRadius=UDim.new(0,options.Corner or window.Tokens:Get("CornerMd")),Parent=frame}) end
	if options.Stroke~=false then
		local stroke=Create.New("UIStroke",{Thickness=options.StrokeThickness or window.Tokens:Get("Stroke"),Transparency=if options.StrokeTransparency==nil then 0.18 else options.StrokeTransparency,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Parent=frame})
		window:_bind(stroke,{Color=options.StrokeToken or "BorderSubtle"})
	end
	window:_bind(frame,{BackgroundColor3=options.Token or "Surface"})
	return frame
end
return Surface

end

__modules["runtime/Create"] = function()
--!nonstrict
--[[
	Create — Instance construction.

	`New(className, props, children)` sets Parent LAST. Parenting an Instance
	before its properties are assigned makes Roblox render and lay out a
	half-configured object; at 200 controls that is measurable.
]]

local Create = {}

function Create.Apply(instance: Instance, props: { [string]: any }?): Instance
	if not props then
		return instance
	end
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	return instance
end

function Create.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)

	Create.Apply(instance, props)

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	if props and props.Parent then
		instance.Parent = props.Parent
	end

	return instance
end

-- ===== common modifiers ==========================================
-- Small enough to inline everywhere, common enough that inlining them
-- everywhere is how a 400-line component happens.

function Create.Corner(radius: number): UICorner
	return Create.New("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Create.Stroke(thickness: number, transparency: number?): UIStroke
	return Create.New("UIStroke", {
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Create.Padding(top: number, right: number?, bottom: number?, left: number?): UIPadding
	local r = right or top
	local b = bottom or top
	local l = left or r
	return Create.New("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
		PaddingLeft = UDim.new(0, l),
	})
end

function Create.List(gap: number, direction: Enum.FillDirection?, props: { [string]: any }?): UIListLayout
	local layout = Create.New("UIListLayout", {
		Padding = UDim.new(0, gap),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return Create.Apply(layout, props) :: any
end

function Create.SizeConstraint(min: Vector2?, max: Vector2?): UISizeConstraint
	return Create.New("UISizeConstraint", {
		MinSize = min or Vector2.zero,
		MaxSize = max or Vector2.new(math.huge, math.huge),
	})
end

function Create.Scale(scale: number): UIScale
	return Create.New("UIScale", { Scale = scale })
end

return Create


end

__modules["runtime/Env"] = function()
--!nonstrict
--[[
	Env — executor / environment abstraction.

	Every executor-specific call in BobloUI goes through this module. Nothing
	else in the codebase is allowed to reference `gethui`, `writefile`,
	`syn.protect_gui` or any other injected global directly.

	Detection runs once, at load. In Studio every capability is simply false and
	the library degrades: config saves land in memory, the GUI goes to PlayerGui.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Env = {}

-- ===== global lookup ==============================================
-- Injected globals live in different places depending on the executor, so try
-- each source rather than assuming one.

local function tryGlobal(name: string): any?
	local sources = {}

	local ok, genv = pcall(function()
		return getgenv()
	end)
	if ok and type(genv) == "table" then
		table.insert(sources, genv)
	end

	local ok2, fenv = pcall(function()
		return getfenv(0)
	end)
	if ok2 and type(fenv) == "table" then
		table.insert(sources, fenv)
	end

	table.insert(sources, _G)

	for _, source in sources do
		local found, value = pcall(function()
			return source[name]
		end)
		if found and value ~= nil then
			return value
		end
	end
	return nil
end

Env.IsStudio = RunService:IsStudio()

--- Cross-script table. In Studio there is no getgenv, so this is bundle-local
--- and the window registry only spans one script — which is correct there.
do
	local ok, genv = pcall(function()
		return getgenv()
	end)
	Env.Globals = (ok and type(genv) == "table") and genv or {}
	Env.HasSharedGlobals = ok and type(genv) == "table"
end

-- ===== identity ===================================================

do
	local identify = tryGlobal("identifyexecutor") or tryGlobal("getexecutorname")
	local name = nil
	if identify then
		local ok, result = pcall(identify)
		if ok and type(result) == "string" then
			name = result
		end
	end
	Env.Executor = name or (Env.IsStudio and "Roblox Studio" or "Unknown")
end

-- ===== filesystem =================================================

local writefile = tryGlobal("writefile")
local readfile = tryGlobal("readfile")
local isfile = tryGlobal("isfile")
local isfolder = tryGlobal("isfolder")
local makefolder = tryGlobal("makefolder")
local listfiles = tryGlobal("listfiles")
local delfile = tryGlobal("delfile")

local hasFilesystem = writefile ~= nil and readfile ~= nil and isfile ~= nil and isfolder ~= nil and makefolder ~= nil

Env.FS = if hasFilesystem
	then {
		Read = function(path: string): string?
			local ok, contents = pcall(readfile, path)
			return if ok then contents else nil
		end,
		Write = function(path: string, contents: string): boolean
			return (pcall(writefile, path, contents))
		end,
		Delete = function(path: string): boolean
			if not delfile then
				return false
			end
			return (pcall(delfile, path))
		end,
		List = function(path: string): { string }
			if not listfiles then
				return {}
			end
			local ok, entries = pcall(listfiles, path)
			return if ok and type(entries) == "table" then entries else {}
		end,
		IsFile = function(path: string): boolean
			local ok, result = pcall(isfile, path)
			return ok and result == true
		end,
		IsFolder = function(path: string): boolean
			local ok, result = pcall(isfolder, path)
			return ok and result == true
		end,
		MakeFolder = function(path: string): boolean
			return (pcall(makefolder, path))
		end,
	}
	else nil

-- ===== clipboard / http ===========================================

local setclipboard = tryGlobal("setclipboard") or tryGlobal("toclipboard")
local getclipboard = tryGlobal("getclipboard") or tryGlobal("fromclipboard")

function Env.SetClipboard(text: string): boolean
	if not setclipboard then return false end
	return (pcall(setclipboard, text))
end
function Env.GetClipboard(): string?
	if not getclipboard then return nil end
	local ok,value=pcall(getclipboard); if not ok or value==nil then return nil end
	return tostring(value)
end

-- ===== GUI parent =================================================
--[[
	Preference order, per the architecture doc (A.5):
	  gethui()  ->  CoreGui  ->  PlayerGui
	CoreGui is probed by actually parenting a throwaway Folder; asking for the
	service succeeds even when writing to it does not.
]]

local gethui = tryGlobal("gethui")
local protectGui = tryGlobal("protect_gui")
if not protectGui then
	local syn = tryGlobal("syn")
	if type(syn) == "table" then
		protectGui = syn.protect_gui
	end
end

local cachedParent: Instance? = nil

function Env.GetGuiParent(): Instance
	if cachedParent and cachedParent.Parent ~= nil then
		return cachedParent
	end

	if gethui then
		local ok, hidden = pcall(gethui)
		if ok and typeof(hidden) == "Instance" then
			cachedParent = hidden
			return hidden
		end
	end

	local ok, coreGui = pcall(function()
		local service = game:GetService("CoreGui")
		local probe = Instance.new("Folder")
		probe.Parent = service
		probe:Destroy()
		return service
	end)
	if ok and coreGui then
		cachedParent = coreGui
		return coreGui
	end

	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		or Players.LocalPlayer:WaitForChild("PlayerGui")
	cachedParent = playerGui
	return playerGui
end

function Env.Protect(gui: Instance)
	if protectGui then
		pcall(protectGui, gui)
	end
end

-- ===== capability summary =========================================

Env.Capabilities = {
	Filesystem = Env.FS ~= nil,
	HiddenUI = gethui ~= nil,
	ProtectGui = protectGui ~= nil,
	Clipboard = setclipboard ~= nil,
	ClipboardRead = getclipboard ~= nil,
	SharedGlobals = Env.HasSharedGlobals,
}

function Env.Describe(): string
	local flags = {}
	for name, enabled in Env.Capabilities do
		if enabled then
			table.insert(flags, name)
		end
	end
	table.sort(flags)
	local list = if #flags > 0 then table.concat(flags, ", ") else "none"
	return `{Env.Executor} [{list}]`
end

return Env


end

__modules["runtime/Janitor"] = function()
--!nonstrict
--[[
	Janitor — cleanup container.

	Every object in BobloUI that creates Instances, connections or tasks owns a
	Janitor. Parents adopt their children's Janitors, so `UI:Unload()` is a
	single cascading Destroy.

	Cleanup runs in REVERSE insertion order (LIFO): tearing down in reverse
	avoids handlers firing against half-destroyed state.
]]

local Janitor = {}
Janitor.__index = Janitor

local function cleanupOne(object: any, method: any)
	if method ~= nil then
		if type(method) == "function" then
			method(object)
		else
			local fn = object[method]
			if fn then
				fn(object)
			end
		end
		return
	end

	local kind = typeof(object)
	if kind == "function" then
		object()
	elseif kind == "RBXScriptConnection" then
		object:Disconnect()
	elseif kind == "thread" then
		pcall(task.cancel, object)
	elseif kind == "Instance" then
		if object:IsA("Tween") then
			object:Cancel()
		end
		object:Destroy()
	elseif kind == "table" then
		local fn = object.Destroy or object.Disconnect or object.Cleanup
		if fn then
			fn(object)
		end
	end
end

function Janitor.new(name: string?)
	return setmetatable({
		_name = name or "Janitor",
		_items = {},
		_indexed = {},
		_destroyed = false,
	}, Janitor)
end

function Janitor.is(value): boolean
	return type(value) == "table" and getmetatable(value) == Janitor
end

--[[
	Add(object, method?, index?)

	method  nil       -> inferred from the object's type
	        string    -> object[method](object)
	        function  -> method(object)
	index   any       -> replaces (and cleans up) whatever was stored there
]]
function Janitor:Add(object: any, method: any?, index: any?)
	if self._destroyed then
		-- The owner is already gone. Clean immediately rather than leaking.
		cleanupOne(object, method)
		return object
	end

	if index ~= nil then
		self:Remove(index)
	end

	local entry = { object = object, method = method, index = index }
	table.insert(self._items, entry)
	if index ~= nil then
		self._indexed[index] = entry
	end
	return object
end

function Janitor:AddJanitor(child, index: any?)
	return self:Add(child, "Destroy", index)
end

function Janitor:Get(index: any): any?
	local entry = self._indexed[index]
	return entry and entry.object or nil
end

function Janitor:Remove(index: any)
	local entry = self._indexed[index]
	if not entry then
		return
	end
	self._indexed[index] = nil
	local position = table.find(self._items, entry)
	if position then
		table.remove(self._items, position)
	end
	local ok, err = pcall(cleanupOne, entry.object, entry.method)
	if not ok then
		warn(`[BobloUI] {self._name}: cleanup of "{tostring(index)}" failed: {err}`)
	end
end

--- Removes an entry WITHOUT cleaning it up, for handing ownership elsewhere.
function Janitor:Release(index: any): any?
	local entry = self._indexed[index]
	if not entry then
		return nil
	end
	self._indexed[index] = nil
	local position = table.find(self._items, entry)
	if position then
		table.remove(self._items, position)
	end
	return entry.object
end

function Janitor:LinkToInstance(instance: Instance)
	return self:Add(instance.Destroying:Connect(function()
		self:Destroy()
	end))
end

function Janitor:IsEmpty(): boolean
	return #self._items == 0
end

function Janitor:Cleanup()
	local items = self._items
	self._items = {}
	self._indexed = {}
	for index = #items, 1, -1 do
		local entry = items[index]
		local ok, err = pcall(cleanupOne, entry.object, entry.method)
		if not ok then
			warn(`[BobloUI] {self._name}: cleanup failed: {err}`)
		end
	end
end

function Janitor:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:Cleanup()
end

return Janitor


end

__modules["runtime/RuntimeManifest"] = function()
-- generated by build/generate.mjs; edit build/manifest.json instead.
return {["Button"]={["Method"]="AddButton",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Adaptive"]="boolean?",["Text"]="string?",["Variant"]="string?",["Confirm"]="string?"},["Required"]={"Title"},["Stateful"]=false},["Toggle"]={["Method"]="AddToggle",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Adaptive"]="boolean?",["Default"]="boolean?"},["Required"]={"Title"},["Stateful"]=true},["Slider"]={["Method"]="AddSlider",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Adaptive"]="boolean?",["Min"]="number",["Max"]="number",["Default"]="number?",["Step"]="number?",["Precision"]="number?",["Suffix"]="string?",["Format"]="function?"},["Required"]={"Title","Min","Max"},["Stateful"]=true},["Dropdown"]={["Method"]="AddDropdown",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Adaptive"]="boolean?",["Options"]="table",["Default"]="any?",["Multi"]="boolean?",["Searchable"]="boolean?",["AllowNone"]="boolean?",["Max"]="number?",["Placeholder"]="string?",["Style"]="string?"},["Required"]={"Title","Options"},["Stateful"]=true},["Input"]={["Method"]="AddInput",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Adaptive"]="boolean?",["Default"]="string|number?",["Placeholder"]="string?",["Numeric"]="boolean?",["MaxLength"]="number?",["Multiline"]="boolean?",["ClearOnFocus"]="boolean?",["Validate"]="function?",["CommitOn"]="string?"},["Required"]={"Title"},["Stateful"]=true},["Keybind"]={["Method"]="AddKeybind",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Adaptive"]="boolean?",["Default"]="EnumItem?",["Mode"]="string?",["AllowedModes"]="table?",["Blacklist"]="table?"},["Required"]={"Title"},["Stateful"]=true},["ColorPicker"]={["Method"]="AddColorPicker",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Adaptive"]="boolean?",["Default"]="Color3?",["Alpha"]="boolean?",["DefaultAlpha"]="number?",["Presets"]="table?"},["Required"]={"Title"},["Stateful"]=true},["Paragraph"]={["Method"]="AddParagraph",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Adaptive"]="boolean?",["Content"]="string?",["Variant"]="string?"},["Required"]={},["Stateful"]=false},["Divider"]={["Method"]="AddDivider",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Adaptive"]="boolean?"},["Required"]={},["Stateful"]=false},["Status"]={["Method"]="AddStatus",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Adaptive"]="boolean?",["Value"]="any?",["Status"]="string?",["Pulse"]="boolean?"},["Required"]={"Title"},["Stateful"]=true}}

end

__modules["runtime/Signal"] = function()
--!nonstrict
--[[
	Signal — synchronous, error-isolated event.

	Not a BindableEvent: those serialise their arguments, which loses table
	identity and breaks any payload richer than primitives. The State layer
	depends on passing real tables through, so we need our own.

	Semantics:
	  * handlers run SYNCHRONOUSLY, in connection order, before Fire returns
	  * a handler that errors is reported and skipped; it does not abort the rest
	  * connections made during a Fire are not called by that Fire
	  * connections disconnected during a Fire are not called by that Fire
]]

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local signal = self._signal
	signal._dirty = true
	if signal._depth == 0 then
		signal:_compact()
	end
end

Connection.Destroy = Connection.Disconnect

function Signal.new(name: string?)
	return setmetatable({
		_name = name or "Signal",
		_conns = {},
		_depth = 0,
		_dirty = false,
	}, Signal)
end

function Signal.is(value): boolean
	return type(value) == "table" and getmetatable(value) == Signal
end

function Signal:_compact()
	local kept = {}
	for _, conn in self._conns do
		if conn.Connected then
			table.insert(kept, conn)
		end
	end
	self._conns = kept
	self._dirty = false
end

function Signal:Connect(fn)
	if type(fn) ~= "function" then
		error(`[BobloUI] {self._name}:Connect expects a function, got {typeof(fn)}`, 2)
	end
	local conn = setmetatable({
		Connected = true,
		_fn = fn,
		_signal = self,
	}, Connection)
	table.insert(self._conns, conn)
	return conn
end

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...)
	local conns = self._conns
	local count = #conns
	if count == 0 then
		return
	end

	self._depth += 1
	for index = 1, count do
		local conn = conns[index]
		if conn and conn.Connected then
			local ok, err = xpcall(conn._fn, debug.traceback, ...)
			if not ok then
				warn(`[BobloUI] error in {self._name} handler:\n{err}`)
			end
		end
	end
	self._depth -= 1

	if self._depth == 0 and self._dirty then
		self:_compact()
	end
end

function Signal:Wait()
	local co = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		task.spawn(co, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, conn in self._conns do
		conn.Connected = false
	end
	self._conns = {}
	self._dirty = false
end

function Signal:GetConnectionCount(): number
	local n = 0
	for _, conn in self._conns do
		if conn.Connected then
			n += 1
		end
	end
	return n
end

Signal.Destroy = Signal.DisconnectAll

return Signal


end

__modules["runtime/Util"] = function()
--!nonstrict
--[[ Util — dependency-free helpers. Level 0: requires nothing. ]]

local Util = {}

-- ===== tables =====================================================

function Util.assign(target: { [any]: any }, ...): { [any]: any }
	for index = 1, select("#", ...) do
		local source = select(index, ...)
		if source then
			for key, value in source do
				target[key] = value
			end
		end
	end
	return target
end

function Util.copy(source: { [any]: any }): { [any]: any }
	return table.clone(source)
end

function Util.deepCopy(source: any): any
	if type(source) ~= "table" then
		return source
	end
	local out = {}
	for key, value in source do
		out[key] = Util.deepCopy(value)
	end
	return out
end

function Util.keys(source: { [any]: any }): { any }
	local out = {}
	for key in source do
		table.insert(out, key)
	end
	return out
end

-- ===== numbers ====================================================

function Util.lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

function Util.round(value: number, step: number?): number
	local increment = step or 1
	return math.round(value / increment) * increment
end

-- ===== strings ====================================================

function Util.trim(text: string): string
	local trimmed = text:gsub("^%s+", "")
	trimmed = trimmed:gsub("%s+$", "")
	return trimmed
end

function Util.startsWith(text: string, prefix: string): boolean
	return text:sub(1, #prefix) == prefix
end

--- Normalises free text into a safe Id: lowercase, [a-z0-9._-], no repeats.
function Util.slug(text: string): string
	local out = text:lower()
	out = out:gsub("[^%w%.%-_]+", "-")
	out = out:gsub("%-+", "-")
	out = out:gsub("^%-+", "")
	out = out:gsub("%-+$", "")
	return out ~= "" and out or "untitled"
end

function Util.levenshtein(a: string, b: string): number
	if a == b then
		return 0
	end
	local lenA, lenB = #a, #b
	if lenA == 0 then
		return lenB
	end
	if lenB == 0 then
		return lenA
	end

	local previous = table.create(lenB + 1)
	for j = 0, lenB do
		previous[j + 1] = j
	end

	for i = 1, lenA do
		local current = table.create(lenB + 1)
		current[1] = i
		local charA = a:byte(i)
		for j = 1, lenB do
			local cost = if charA == b:byte(j) then 0 else 1
			current[j + 1] = math.min(current[j] + 1, previous[j + 1] + 1, previous[j] + cost)
		end
		previous = current
	end

	return previous[lenB + 1]
end

--[[
	Best "did you mean" candidate, or nil when nothing is close enough.
	Feeds the learning error messages described in the architecture doc (G.2).
]]
function Util.suggest(word: string, candidates: { string }): string?
	local lowered = word:lower()
	local best, bestDistance = nil, math.huge
	local limit = math.max(2, math.floor(#word / 3))

	for _, candidate in candidates do
		local distance = Util.levenshtein(lowered, candidate:lower())
		if distance < bestDistance then
			best, bestDistance = candidate, distance
		end
	end

	if best and bestDistance <= limit then
		return best
	end
	return nil
end

-- ===== colour =====================================================

function Util.hex(value: string): Color3
	return Color3.fromHex(value)
end

function Util.toHex(colour: Color3): string
	return "#" .. colour:ToHex()
end

function Util.mix(from: Color3, to: Color3, alpha: number): Color3
	return from:Lerp(to, alpha)
end

function Util.lighten(colour: Color3, amount: number): Color3
	return colour:Lerp(Color3.new(1, 1, 1), amount)
end

function Util.darken(colour: Color3, amount: number): Color3
	return colour:Lerp(Color3.new(0, 0, 0), amount)
end

function Util.luminance(colour: Color3): number
	return 0.2126 * colour.R + 0.7152 * colour.G + 0.0722 * colour.B
end

--- Readable foreground for an arbitrary background. Used for AccentText.
function Util.contrastText(background: Color3): Color3
	if Util.luminance(background) > 0.55 then
		return Color3.fromRGB(18, 20, 24)
	end
	return Color3.fromRGB(250, 251, 253)
end

-- ===== misc =======================================================

function Util.now(): number
	return os.clock()
end

return Util


end

__modules["runtime/Validate"] = function()
--!nonstrict
local Manifest=__require("runtime/RuntimeManifest")
local Util=__require("runtime/Util")
local Validate={}

local function matches(value,spec)
	if value==nil then return string.find(spec,"?",1,true)~=nil or spec=="any?" end
	if string.find(spec,"any",1,true) then return true end
	for part in string.gmatch(spec,"[^|]+") do
		part=string.gsub(part,"%?","")
		if part=="string" and type(value)=="string" then return true
		elseif part=="number" and type(value)=="number" then return true
		elseif part=="boolean" and type(value)=="boolean" then return true
		elseif part=="function" and type(value)=="function" then return true
		elseif part=="table" and type(value)=="table" then return true
		elseif part=="Color3" and typeof(value)=="Color3" then return true
		elseif part=="EnumItem" and typeof(value)=="EnumItem" then return true end
	end
	return false
end

function Validate.Collect(typeName,options,path)
	local errors={}; local spec=Manifest[typeName]; path=path or typeName
	if not spec then return {`{path}: unknown control type "{typeName}"`} end
	if type(options)~="table" then return {`{path}: expected an options table`} end
	local names={}; for k in spec.Options do table.insert(names,k) end; table.sort(names)
	for _,key in spec.Required or {} do
		if options[key]==nil then table.insert(errors,`{path}.{key}: required option is missing`) end
	end
	for key,value in options do
		local expected=spec.Options[key]
		if not expected then
			local suggestion=Util.suggest(tostring(key),names)
			local hint=if suggestion then ` Did you mean "{suggestion}"?` else ""
			table.insert(errors,`{path}.{tostring(key)}: unknown option.{hint}`)
		elseif not matches(value,expected) then
			table.insert(errors,`{path}.{key}: expected {expected}, got {typeof(value)}`)
		end
	end
	return errors
end

function Validate.Control(typeName,options)
	local spec=Manifest[typeName]
	if not spec then error(`[BobloUI] unknown control type "{typeName}".`,3) end
	if type(options)~="table" then error(`[BobloUI] {spec.Method} expects an options table.`,3) end
	for _,key in spec.Required or {} do
		if options[key]==nil then error(`[BobloUI] {spec.Method}: required option "{key}" is missing.`,3) end
	end
	local names={}; for k in spec.Options do table.insert(names,k) end; table.sort(names)
	for key,value in options do
		local expected=spec.Options[key]
		if not expected then
			local suggestion=Util.suggest(tostring(key),names)
			local hint=if suggestion then " Did you mean \""..suggestion.."\"?" else ""
			warn(`[BobloUI] {spec.Method}: unknown option "{key}".{hint}\nValid options: {table.concat(names,", ")}`)
		elseif not matches(value,expected) then
			error(`[BobloUI] {spec.Method}: option "{key}" expected {expected}, got {typeof(value)}.`,3)
		end
	end
	return options
end
return Validate

end

__modules["schema/Build"] = function()
--!nonstrict
local Manifest=__require("runtime/RuntimeManifest")
local Validate=__require("runtime/Validate")
local Build={}

local TAB_KEYS={Id=true,Title=true,Description=true,Icon=true,Order=true,Badge=true,Group=true,Visible=true,Sections=true,Controls=true}
local SECTION_KEYS={Id=true,Title=true,Description=true,Collapsible=true,Collapsed=true,Column=true,Span=true,Layout=true,Visible=true,Controls=true}
local function unknownKeys(value,allowed,path,errors)
	for key in value do if not allowed[key] then table.insert(errors,`{path}.{tostring(key)}: unknown field`) end end
end
local function validateControl(control,path,errors)
	if type(control)~="table" then table.insert(errors,path.." must be a table"); return end
	if type(control.Type)~="string" or not Manifest[control.Type] then table.insert(errors,path..`.Type "{tostring(control.Type)}" is unknown`); return end
	local options={}; for k,v in control do if k~="Type" then options[k]=v end end
	for _,err in Validate.Collect(control.Type,options,path) do table.insert(errors,err) end
end
local function validate(schema)
	local errors={}
	if type(schema)~="table" then return {"schema must be a table"} end
	unknownKeys(schema,{Tabs=true},"schema",errors)
	if type(schema.Tabs)~="table" then table.insert(errors,"schema.Tabs must be an array"); return errors end
	for ti,tab in schema.Tabs do
		local tp=`Tabs[{ti}]`
		if type(tab)~="table" then table.insert(errors,tp.." must be a table"); continue end
		unknownKeys(tab,TAB_KEYS,tp,errors)
		if type(tab.Title)~="string" then table.insert(errors,tp..".Title must be a string") end
		if tab.Id~=nil and type(tab.Id)~="string" then table.insert(errors,tp..".Id must be a string") end
		if tab.Controls~=nil and type(tab.Controls)~="table" then table.insert(errors,tp..".Controls must be an array")
		else for ci,control in tab.Controls or {} do validateControl(control,`{tp}.Controls[{ci}]`,errors) end end
		if tab.Sections~=nil and type(tab.Sections)~="table" then table.insert(errors,tp..".Sections must be an array")
		else
			for si,section in tab.Sections or {} do
				local sp=`{tp}.Sections[{si}]`
				if type(section)~="table" then table.insert(errors,sp.." must be a table"); continue end
				unknownKeys(section,SECTION_KEYS,sp,errors)
				if section.Column~=nil and section.Column~=1 and section.Column~=2 then table.insert(errors,sp..".Column must be 1 or 2") end
				if section.Span~=nil and section.Span~="Auto" and section.Span~=1 and section.Span~=2 then table.insert(errors,sp..".Span must be Auto, 1, or 2") end
				if section.Layout~=nil and section.Layout~="Stack" and section.Layout~="Grid" and section.Layout~="Auto" then table.insert(errors,sp..".Layout must be Stack, Grid, or Auto") end
				if section.Controls~=nil and type(section.Controls)~="table" then table.insert(errors,sp..".Controls must be an array")
				else for ci,control in section.Controls or {} do validateControl(control,`{sp}.Controls[{ci}]`,errors) end end
			end
		end
	end
	return errors
end

function Build.Validate(schema) return validate(schema) end
function Build.Run(window,schema)
	local errors=validate(schema)
	if #errors>0 then error("[BobloUI] UI:Build validation failed:\n - "..table.concat(errors,"\n - "),2) end
	local handles={}
	local function createControl(container,desc)
		local spec=Manifest[desc.Type]; local method=spec.Method; local options={}
		for k,v in desc do if k~="Type" then options[k]=v end end
		local h=container[method](container,options); if h.Id then handles[h.Id]=h end; return h
	end
	for _,td in schema.Tabs do
		local tab=window:AddTab({Id=td.Id,Title=td.Title,Description=td.Description,Icon=td.Icon,Order=td.Order,Badge=td.Badge,Group=td.Group,Visible=td.Visible}); if tab.Id then handles[tab.Id]=tab end
		for _,cd in td.Controls or {} do createControl(tab,cd) end
		for _,sd in td.Sections or {} do
			local section=tab:AddSection({Id=sd.Id,Title=sd.Title,Description=sd.Description,Collapsible=sd.Collapsible,Collapsed=sd.Collapsed,Column=sd.Column,Span=sd.Span,Layout=sd.Layout,Visible=sd.Visible}); if section.Id then handles[section.Id]=section end
			for _,cd in sd.Controls or {} do createControl(section,cd) end
		end
	end
	return handles
end
return Build

end

__modules["services/Commands"] = function()
--!nonstrict
local Commands={}; Commands.__index=Commands
function Commands.new(window) return setmetatable({_window=window,_commands={}},Commands) end
function Commands:Register(c) if type(c)~="table" or type(c.Id)~="string" or type(c.Title)~="string" or type(c.Callback)~="function" then error("[BobloUI] Commands:Register requires Id, Title, Callback.",2) end; self._commands[c.Id]=c; return c end
function Commands:Unregister(id) self._commands[id]=nil end
function Commands:Run(id) local c=self._commands[id]; if not c then return false end; if c.EnabledWhen and not c.EnabledWhen(self._window.State) then return false end; local ok,err=xpcall(c.Callback,debug.traceback); if not ok then warn(`[BobloUI] command "{id}" failed:\n{err}`) end; return ok end
function Commands:List() local o={}; for _,c in self._commands do table.insert(o,c) end; table.sort(o,function(a,b)return a.Title<b.Title end); return o end
function Commands:Query(text) local q=string.lower(text or ""); local o={}; for _,c in self._commands do local hay=string.lower(c.Title.." "..table.concat(c.Keywords or {}," ")); if q=="" or string.find(hay,q,1,true) then table.insert(o,{Kind="Command",Id=c.Id,Title=c.Title,Icon=c.Icon,Callback=c.Callback,Command=c}) end end; table.sort(o,function(a,b)return a.Title<b.Title end); return o end
return Commands

end

__modules["services/Config"] = function()
--!nonstrict
local HttpService=game:GetService("HttpService")
local Signal=__require("runtime/Signal")
local Util=__require("runtime/Util")
local Storage=__require("services/Storage")
local Env=__require("runtime/Env")
local Config={}; Config.__index=Config
local CURRENT=1
local function serialize(v)
	local k=typeof(v)
	if k=="Color3" then return {__type="Color3",Hex=v:ToHex()} end
	if k=="Vector2" then return {__type="Vector2",X=v.X,Y=v.Y} end
	if k=="Vector3" then return {__type="Vector3",X=v.X,Y=v.Y,Z=v.Z} end
	if k=="UDim" then return {__type="UDim",Scale=v.Scale,Offset=v.Offset} end
	if k=="UDim2" then return {__type="UDim2",XS=v.X.Scale,XO=v.X.Offset,YS=v.Y.Scale,YO=v.Y.Offset} end
	if k=="EnumItem" then return {__type="EnumItem",Enum=tostring(v.EnumType),Name=v.Name} end
	if type(v)=="table" then local o={}; for key,val in v do o[key]=serialize(val) end; return o end
	if type(v)=="number" or type(v)=="string" or type(v)=="boolean" or v==nil then return v end
	return tostring(v)
end
local function deserialize(v)
	if type(v)~="table" then return v end
	if v.__type=="Color3" then local ok,c=pcall(Color3.fromHex,v.Hex); return ok and c or Color3.new(1,1,1) end
	if v.__type=="Vector2" then return Vector2.new(v.X or 0,v.Y or 0) end
	if v.__type=="Vector3" then return Vector3.new(v.X or 0,v.Y or 0,v.Z or 0) end
	if v.__type=="UDim" then return UDim.new(v.Scale or 0,v.Offset or 0) end
	if v.__type=="UDim2" then return UDim2.new(v.XS or 0,v.XO or 0,v.YS or 0,v.YO or 0) end
	if v.__type=="EnumItem" then local enumName=string.match(v.Enum or "","Enum%.(.+)"); local et=enumName and Enum[enumName]; return et and et[v.Name] or v.Name end
	local o={}; for key,val in v do o[key]=deserialize(val) end; return o
end
function Config.new(window,folder)
	local self=setmetatable({Saved=Signal.new("Config.Saved"),Loaded=Signal.new("Config.Loaded"),_window=window,_storage=Storage.new(folder),_folder=folder,_migrations={},_pending={},_orphans={},_ignored={},_pendingCollapsed={},_autoload=nil},Config)
	self._registryConn=window.Registry.Added:Connect(function(entry)
		if entry.Id and self._pending[entry.Id]~=nil then local value=self._pending[entry.Id]; self._pending[entry.Id]=nil; self._orphans[entry.Id]=nil; window.State:Set(entry.Id,value,{Source="CONFIG",Silent=false}) end
		if entry.Id and self._pendingCollapsed[entry.Id]~=nil and entry.Handle and entry.Handle.SetCollapsed then local v=self._pendingCollapsed[entry.Id]; self._pendingCollapsed[entry.Id]=nil; entry.Handle:SetCollapsed(v) end
	end)
	local auto=self._storage:Read("autoload.txt"); if auto and auto~="" then self._autoload=auto end
	return self
end
function Config:SetFolder(folder) self._folder=folder; self._storage=Storage.new(folder); return self end
function Config:_file(name) return `configs/{name}.json` end
function Config:_ensureConfigDir() if Env.FS and not Env.FS.IsFolder(self._storage.Root.."/configs") then Env.FS.MakeFolder(self._storage.Root.."/configs") end end
function Config:List() local out={}; local entries=if Env.FS then Env.FS.List(self._storage.Root.."/configs") else self._storage:List(); for _,n in entries do local name=string.match(n,"([^/\\]+)%.json$"); if name and name~="autoload" then table.insert(out,name) end end; table.sort(out); return out end
function Config:SetIgnored(id,v) self._ignored[id]=v==true; return self end
function Config:Save(name)
	if type(name)~="string" or name=="" then return false,"invalid name" end; self:_ensureConfigDir(); local values={}
	for _,e in self._window.Registry:GetPersistable() do if not self._ignored[e.Id] then values[e.Id]=serialize(e.Handle:GetValue()) end end
	for id,v in self._orphans do if values[id]==nil then values[id]=serialize(v) end end
	local collapsed={}; for _,tab in self._window._tabs or {} do for _,section in tab._sections or {} do if section.Id then collapsed[section.Id]=section.Collapsed==true end end end
	local geometry=self._window.GetRememberGeometry and self._window:GetRememberGeometry() and self._window:GetGeometry() or nil
	local meta={theme=self._window.Theme:Current(),themeData=self._window.Theme.Export and self._window.Theme:Export() or nil,accent=serialize(self._window.Theme:Get("Accent")),density=self._window.Tokens:GetDensity(),scale=self._window.GetScale and self._window:GetScale() or 1,locale=self._window.Locale and self._window.Locale:Get() or "en",favorites=self._window.Favorites and self._window.Favorites:List() or {},collapsed=collapsed,geometry=serialize(geometry),reducedMotion=self._window.Motion and not self._window.Motion.Enabled or false,keyboardNavigation=self._window.Navigation and self._window.Navigation:IsEnabled() or true,uiSounds=self._window.Sound and self._window.Sound:IsEnabled() or true,soundVolume=self._window.Sound and self._window.Sound:GetVolume() or 1}
	local envelope={['$schema']=CURRENT,name=name,library="BobloUI",libraryVersion=self._window.Version,savedAt=os.time(),values=values,meta=meta}; local ok,json=pcall(HttpService.JSONEncode,HttpService,envelope); if not ok then return false,json end
	local wrote=self._storage:Write(self:_file(name),json); if wrote then self.Saved:Fire(name) end; return wrote,wrote and nil or "write failed"
end
function Config:Load(name)
	local raw=self._storage:Read(self:_file(name)); if not raw then return false,"config not found" end; local ok,data=pcall(HttpService.JSONDecode,HttpService,raw); if not ok or type(data)~="table" then return false,"invalid json" end
	local version=tonumber(data['$schema']) or 0; if version<CURRENT then self._storage:Write(self:_file(name)..".bak",raw); while version<CURRENT do local migration=self._migrations[version]; if not migration then break end; local okm,res=xpcall(migration,debug.traceback,data); if not okm then return false,res end; data=res or data; version+=1; data['$schema']=version end end
	self._window.State:Batch(function() for id,rawValue in data.values or {} do local v=deserialize(rawValue); if self._window.Registry:Has(id) then self._window.State:Set(id,v,{Source="CONFIG"}) else self._pending[id]=v; self._orphans[id]=v end end end)
	local meta=data.meta or {}; if meta.themeData and self._window.Theme.Import then pcall(function() self._window.Theme:Import(meta.themeData) end) elseif meta.theme then pcall(function() self._window:SetTheme(meta.theme) end) end; if meta.accent and not meta.themeData then pcall(function() self._window:SetAccent(deserialize(meta.accent)) end) end; if meta.density then pcall(function() self._window:SetDensity(meta.density) end) end; if meta.scale and self._window.SetScale then pcall(function() self._window:SetScale(meta.scale) end) end; if meta.locale and self._window.SetLocale then pcall(function() self._window:SetLocale(meta.locale) end) end; if self._window.Favorites and type(meta.favorites)=="table" then self._window.Favorites:Set(meta.favorites) end
	if meta.reducedMotion~=nil and self._window.SetReducedMotion then pcall(function() self._window:SetReducedMotion(meta.reducedMotion==true) end) end; if meta.keyboardNavigation~=nil and self._window.SetKeyboardNavigation then pcall(function() self._window:SetKeyboardNavigation(meta.keyboardNavigation~=false) end) end; if meta.uiSounds~=nil and self._window.SetUISounds then pcall(function() self._window:SetUISounds(meta.uiSounds~=false) end) end; if meta.soundVolume~=nil and self._window.SetSoundVolume then pcall(function() self._window:SetSoundVolume(meta.soundVolume) end) end
	if type(meta.collapsed)=="table" then for id,value in meta.collapsed do local sec=self._window:Get(id); if sec and sec.SetCollapsed then sec:SetCollapsed(value==true) else self._pendingCollapsed[id]=value==true end end end
	if meta.geometry and self._window.GetRememberGeometry and self._window:GetRememberGeometry() then local g=deserialize(meta.geometry); if type(g)=="table" then if g.Size then self._window:SetSize(g.Size) end; if g.Position then self._window:SetPosition(g.Position) end; if g.Scale then self._window:SetScale(g.Scale) end; if g.Locked~=nil then self._window:SetLocked(g.Locked) end end end
	self.Loaded:Fire(name); return true
end
function Config:Delete(name) return self._storage:Delete(self:_file(name)) end
function Config:Rename(a,b) local raw=self._storage:Read(self:_file(a)); if not raw then return false,"not found" end; if not self._storage:Write(self:_file(b),raw) then return false,"write failed" end; self._storage:Delete(self:_file(a)); return true end
function Config:Duplicate(a,b) local raw=self._storage:Read(self:_file(a)); if not raw then return false,"not found" end; return self._storage:Write(self:_file(b),raw) end
function Config:Export(name) local raw=self._storage:Read(self:_file(name)); if raw then Env.SetClipboard(raw) end; return raw end
function Config:Import(json,name) local ok=pcall(HttpService.JSONDecode,HttpService,json); if not ok then return false,"invalid json" end; self:_ensureConfigDir(); return self._storage:Write(self:_file(name),json) end
function Config:SetAutoLoad(name) self._autoload=name; self._storage:Write("autoload.txt",name or ""); return self end
function Config:GetAutoLoad() return self._autoload end
function Config:LoadAuto() if self._autoload then return self:Load(self._autoload) end; return false,"no autoload" end
function Config:RegisterMigration(from,to,fn) if to~=from+1 then error("[BobloUI] config migrations must be linear (N -> N+1).",2) end; self._migrations[from]=fn; return self end
function Config:Destroy() if self._registryConn then self._registryConn:Disconnect() end; self.Saved:Destroy(); self.Loaded:Destroy(); self._pending={}; self._orphans={}; self._pendingCollapsed={} end
return Config

end

__modules["services/Dialog"] = function()
--!nonstrict
local TextService=game:GetService("TextService")
local Create=__require("runtime/Create")
local Signal=__require("runtime/Signal")
local Janitor=__require("runtime/Janitor")
local Surface=__require("primitives/Surface")
local Sheet=__require("primitives/Sheet")
local DialogSection=__require("services/DialogSection")
local Dialog={}; Dialog.__index=Dialog

function Dialog.new(window) return setmetatable({_window=window,_open={}},Dialog) end

function Dialog:_width()
	return math.max(240,math.min(392,self._window.Device.Viewport.X-32))
end
function Dialog:_measure(text,width)
	if not text or text=="" then return 0 end
	local w=self._window
	local ok,size=pcall(function() return TextService:GetTextSize(tostring(text),w.Tokens:Get("FontBody"),w.Fonts.Regular,Vector2.new(width,1000)) end)
	return if ok then math.max(18,size.Y) else 36
end
function Dialog:_surface(height,onDismiss)
	local w=self._window
	if w.Device.Layout=="Drawer" then local h=Sheet.open(w,height,{OnDismiss=onDismiss}); return h,h.Frame end
	local safeHeight=math.max(1,math.min(height,math.max(1,w.Device.Viewport.Y-32)))
	local h=w.Layers:Push({Scrim=true,ScrimTransparency=0.52,Modal=true,OnDismiss=onDismiss})
	local frame=Surface.new(w,{Size=UDim2.fromOffset(self:_width(),safeHeight),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BorderSizePixel=0,ClipsDescendants=true,Parent=h.Container},{Token="SurfaceRaised",StrokeToken="Border",StrokeTransparency=0.40,Corner=w.Tokens:Get("CornerLg")})
	frame.ZIndex=h.Depth*10+3; return h,frame
end
function Dialog:_button(parent,text,primary,danger,callback,options)
	options=options or {}
	local w=self._window
	local bg=if danger and primary then "Error" elseif primary then "AccentButton" else "ControlInset"
	local fg=if primary then "AccentText" else "TextSecondary"
	local full=options.FullWidth==true
	local b=Create.New("TextButton",{AutomaticSize=if full then Enum.AutomaticSize.None else Enum.AutomaticSize.X,Size=if full then UDim2.new(1,0,0,34) else UDim2.new(0,0,0,34),BackgroundTransparency=0,BorderSizePixel=0,AutoButtonColor=false,Text=if full then tostring(text) else "  "..tostring(text).."  ",TextXAlignment=if full then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontBody"),Parent=parent})
	if full then Create.New("UIPadding",{PaddingLeft=UDim.new(0,11),PaddingRight=UDim.new(0,11),Parent=b}) end
	Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("FieldRadius")),Parent=b})
	local stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.58,Parent=b}); w:_bind(stroke,{Color=primary and "AccentBorder" or "BorderSubtle"}); w:_bind(b,{BackgroundColor3=bg,TextColor3=fg})
	b.MouseEnter:Connect(function() if not danger then b.BackgroundColor3=w.Theme:Get(primary and "AccentButtonHover" or "ControlHover") end end)
	b.MouseLeave:Connect(function() b.BackgroundColor3=w.Theme:Get(bg) end)
	b.MouseButton1Click:Connect(callback)
	return b
end

function Dialog:_make(options,kind)
	options=options or {}; local w=self._window
	local resultSignal=Signal.new("Dialog.Resolved"); local resultHandle={Resolved=resultSignal,_resolved=false,_result=nil}
	local width=self:_width(); local contentHeight=self:_measure(options.Content or "",width-32)
	local titleY=14; local contentY=44; local afterContent=contentY+contentHeight
	if contentHeight==0 then afterContent=43 end
	local inputY=afterContent+(kind=="Prompt" and 12 or 0)
	local buttonsY=if kind=="Prompt" then inputY+34+16 else afterContent+16
	local height=math.max(kind=="Prompt" and 184 or 138,buttonsY+34+14)
	local layerHandle,frame
	local function removeOpen() local p=table.find(self._open,resultHandle); if p then table.remove(self._open,p) end end
	local function dismissed() if not resultHandle._resolved then resultHandle._resolved=true; resultHandle._result=nil; resultSignal:Fire(nil); removeOpen() end end
	layerHandle,frame=self:_surface(height,dismissed); resultHandle._layer=layerHandle

	local title=Create.New("TextLabel",{Size=UDim2.new(1,-32,0,24),Position=UDim2.fromOffset(16,titleY),BackgroundTransparency=1,Font=w.Fonts.Bold,TextSize=w.Tokens:Get("FontTitle"),TextXAlignment=Enum.TextXAlignment.Left,Text=options.Title or "",Parent=frame}); w:_bind(title,{TextColor3="Text"})
	if contentHeight>0 then
		local content=Create.New("TextLabel",{Size=UDim2.new(1,-32,0,contentHeight),Position=UDim2.fromOffset(16,contentY),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontBody"),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text=options.Content or "",Parent=frame}); w:_bind(content,{TextColor3="TextSecondary"})
	end
	local input=nil
	if kind=="Prompt" then
		input=Create.New("TextBox",{Size=UDim2.new(1,-32,0,34),Position=UDim2.fromOffset(16,inputY),BackgroundTransparency=0,BorderSizePixel=0,ClearTextOnFocus=false,PlaceholderText=options.Placeholder or "",Text=options.Default or "",Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Parent=frame})
		Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("FieldRadius")),Parent=input}); Create.New("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),Parent=input})
		local stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.54,Parent=input}); w:_bind(stroke,{Color="BorderSubtle"}); w:_bind(input,{BackgroundColor3="ControlInset",TextColor3="Text",PlaceholderColor3="TextTertiary"})
		input.Focused:Connect(function() stroke.Transparency=0.08; stroke.Color=w.Theme:Get("AccentBorder") end); input.FocusLost:Connect(function() stroke.Transparency=0.54; stroke.Color=w.Theme:Get("BorderSubtle") end)
	end

	local function resolve(v) if resultHandle._resolved then return end; resultHandle._resolved=true; resultHandle._result=v; resultSignal:Fire(v); removeOpen(); layerHandle:Dismiss() end
	function resultHandle:Resolve(v) resolve(v) end; function resultHandle:Close() resolve(nil) end; function resultHandle:IsOpen() return not self._resolved and layerHandle:IsOpen() end; function resultHandle:Await() if self._resolved then return self._result end; return self.Resolved:Wait() end; function resultHandle:Destroy() self:Close(); self.Resolved:Destroy() end
	local buttons=Create.New("Frame",{Size=UDim2.new(1,-32,0,34),Position=UDim2.fromOffset(16,buttonsY),BackgroundTransparency=1,Parent=frame}); Create.List(7,Enum.FillDirection.Horizontal,{HorizontalAlignment=Enum.HorizontalAlignment.Right}).Parent=buttons
	if kind=="Alert" then self:_button(buttons,options.Button or "OK",true,options.Danger==true,function() resolve(true) end)
	elseif kind=="Confirm" then self:_button(buttons,options.Cancel or "Cancel",false,false,function() resolve(false) end); self:_button(buttons,options.Confirm or "Confirm",true,options.Danger==true,function() resolve(true) end)
	else self:_button(buttons,options.Cancel or "Cancel",false,false,function() resolve(nil) end); self:_button(buttons,options.Confirm or "OK",true,false,function() resolve(input.Text) end) end
	table.insert(self._open,resultHandle); return resultHandle
end
function Dialog:Alert(o) return self:_make(o,"Alert") end
function Dialog:Confirm(o) return self:_make(o,"Confirm") end
function Dialog:Prompt(o) return self:_make(o,"Prompt") end
function Dialog:Choice(options)
	options=options or {}; local choices=options.Choices or {}; local w=self._window
	local result=Signal.new("Dialog.Choice"); local handle={Resolved=result,_resolved=false,_result=nil}
	local rowHeight,gap=34,6
	local maxListHeight=math.max(34,math.min(274,w.Device.Viewport.Y-150))
	local naturalHeight=#choices*rowHeight+math.max(0,#choices-1)*gap
	local listHeight=math.min(maxListHeight,math.max(rowHeight,naturalHeight))
	local height=50+listHeight+16; local layer,frame
	local function resolve(v) if handle._resolved then return end; handle._resolved=true; handle._result=v; result:Fire(v); if layer then layer:Dismiss() end end
	layer,frame=self:_surface(height,function() resolve(nil) end)
	local title=Create.New("TextLabel",{Size=UDim2.new(1,-32,0,24),Position=UDim2.fromOffset(16,14),BackgroundTransparency=1,Font=w.Fonts.Bold,TextSize=w.Tokens:Get("FontTitle"),TextXAlignment=Enum.TextXAlignment.Left,Text=options.Title or "Choose",Parent=frame}); w:_bind(title,{TextColor3="Text"})
	local scroll=naturalHeight>listHeight
	local list
	if scroll then
		list=Create.New("ScrollingFrame",{Size=UDim2.new(1,-32,0,listHeight),Position=UDim2.fromOffset(16,50),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=2,Parent=frame}); w:_bind(list,{ScrollBarImageColor3="BorderStrong"})
	else
		list=Create.New("Frame",{Size=UDim2.new(1,-32,0,listHeight),Position=UDim2.fromOffset(16,50),BackgroundTransparency=1,Parent=frame})
	end
	Create.List(gap).Parent=list
	for _,choice in choices do self:_button(list,choice.Text or tostring(choice.Value),choice.Primary==true,choice.Danger==true,function() resolve(choice.Value) end,{FullWidth=true}) end
	function handle:Resolve(v) resolve(v) end; function handle:Close() resolve(nil) end; function handle:IsOpen() return not self._resolved and layer:IsOpen() end; function handle:Await() if self._resolved then return self._result end; return self.Resolved:Wait() end; function handle:Destroy() self:Close(); self.Resolved:Destroy() end
	return handle
end

function Dialog:Custom(options)
	options=options or {}; local w=self._window; local j=Janitor.new("Dialog.Custom"); local closed=false; local layer,frame
	local function dismiss() if closed then return end; closed=true; j:Destroy() end
	layer,frame=self:_surface(options.Height or 340,dismiss); j:Add(function() if layer:IsOpen() then layer:Dismiss() end end)
	local title=Create.New("TextLabel",{Size=UDim2.new(1,-32,0,26),Position=UDim2.fromOffset(16,14),BackgroundTransparency=1,Font=w.Fonts.Bold,TextSize=w.Tokens:Get("FontTitle"),TextXAlignment=Enum.TextXAlignment.Left,Text=options.Title or "",Parent=frame}); w:_bind(title,{TextColor3="Text"})
	local content=Create.New("ScrollingFrame",{Size=UDim2.new(1,-32,1,-96),Position=UDim2.fromOffset(16,48),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=2,Parent=frame}); Create.List(w.Tokens:Get("RowGap")).Parent=content
	local section=DialogSection.new(w,content,j); if options.Build then options.Build(section) end
	local row=Create.New("Frame",{Size=UDim2.new(1,-32,0,34),Position=UDim2.new(0,16,1,-44),BackgroundTransparency=1,Parent=frame}); Create.List(7,Enum.FillDirection.Horizontal,{HorizontalAlignment=Enum.HorizontalAlignment.Right}).Parent=row
	for _,button in options.Buttons or {{Text="Close"}} do
		self:_button(row,button.Text or "Close",button.Primary==true,button.Danger==true,function() if button.Callback then button.Callback(section) end; if button.Close~=false then layer:Dismiss() end end)
	end
	return {Close=function() layer:Dismiss() end,IsOpen=function() return layer:IsOpen() end,Section=section}
end
function Dialog:Destroy() for _,d in table.clone(self._open) do if d:IsOpen() then d:Close() end end; self._open={} end
return Dialog

end

__modules["services/DialogSection"] = function()
--!nonstrict
local Button=__require("controls/Button")
local Toggle=__require("controls/Toggle")
local Slider=__require("controls/Slider")
local Dropdown=__require("controls/Dropdown")
local TextField=__require("controls/TextField")
local Keybind=__require("controls/Keybind")
local ColorPicker=__require("controls/ColorPicker")
local Paragraph=__require("controls/Paragraph")
local Divider=__require("controls/Divider")
local Status=__require("controls/Status")
local DialogSection={}; DialogSection.__index=DialogSection
function DialogSection.new(window,parent,janitor)
	local fakeTab={Id="__dialog",Title="Dialog",_page=parent,Select=function() end}
	return setmetatable({_window=window,_content=parent,_mounted=true,_janitor=janitor,_tab=fakeTab,_controls={},Title="Dialog"},DialogSection)
end
function DialogSection:_registerControl(c) table.insert(self._controls,c) end
function DialogSection:_removeControl(c) local p=table.find(self._controls,c); if p then table.remove(self._controls,p) end end
function DialogSection:AddButton(o) return Button.new(self,o) end
function DialogSection:AddToggle(o) return Toggle.new(self,o) end
function DialogSection:AddSlider(o) return Slider.new(self,o) end
function DialogSection:AddDropdown(o) return Dropdown.new(self,o) end
function DialogSection:AddInput(o) return TextField.new(self,o) end
function DialogSection:AddKeybind(o) return Keybind.new(self,o) end
function DialogSection:AddColorPicker(o) return ColorPicker.new(self,o) end
function DialogSection:AddParagraph(o) return Paragraph.new(self,o) end
function DialogSection:AddDivider(o) return Divider.new(self,o or {}) end
function DialogSection:AddStatus(o) return Status.new(self,o) end
function DialogSection:SetCollapsed() return self end
return DialogSection

end

__modules["services/Favorites"] = function()
--!nonstrict
local Signal=__require("runtime/Signal")
local Favorites={}; Favorites.__index=Favorites
function Favorites.new(registry) return setmetatable({Changed=Signal.new("Favorites.Changed"),_registry=registry,_set={}},Favorites) end
function Favorites:Add(id) if type(id)=="string" and not self._set[id] then self._set[id]=true; self.Changed:Fire(id,true) end; return self end
function Favorites:Remove(id) if self._set[id] then self._set[id]=nil; self.Changed:Fire(id,false) end; return self end
function Favorites:Toggle(id) if self._set[id] then return self:Remove(id) else return self:Add(id) end end
function Favorites:Has(id) return self._set[id]==true end
function Favorites:List() local o={}; for id in self._set do table.insert(o,id) end; table.sort(o); return o end
function Favorites:Set(ids) self._set={}; for _,id in ids or {} do if type(id)=="string" then self._set[id]=true end end; self.Changed:Fire(nil,nil) end
function Favorites:Destroy() self.Changed:Destroy(); self._set={} end
return Favorites

end

__modules["services/Interactions"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Janitor=__require("runtime/Janitor")
local Popover=__require("primitives/Popover")
local Sheet=__require("primitives/Sheet")
local Icon=__require("primitives/Icon")
local Env=__require("runtime/Env")
local Interactions={}; Interactions.__index=Interactions

local function longestLine(text)
	local longest=0
	for _,line in string.split(tostring(text),"\n") do longest=math.max(longest,#line) end
	return longest
end

function Interactions.new(window) return setmetatable({_window=window,_tooltip=nil,_menu=nil,_touchInfo=nil},Interactions) end
function Interactions:_hideTooltip() if self._tooltip then self._tooltip:Destroy(); self._tooltip=nil end end
function Interactions:_showTooltip(root,text)
	self:_hideTooltip(); if not root or not root.Parent then return end
	local w=self._window; local raw=tostring(text); local width=math.clamp(longestLine(raw)*6+16,88,260)
	local label=Create.New("TextLabel",{
		AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.fromOffset(width,0),BackgroundTransparency=0,BorderSizePixel=0,
		Text=w.Locale:Resolve(raw),TextWrapped=true,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,
		TextYAlignment=Enum.TextYAlignment.Top,Parent=w.Layers.Overlay,ZIndex=999,
	})
	Create.New("UIPadding",{PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,5),PaddingLeft=UDim.new(0,7),PaddingRight=UDim.new(0,7),Parent=label})
	Create.New("UICorner",{CornerRadius=UDim.new(0,6),Parent=label})
	local stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.46,Parent=label}); w:_bind(stroke,{Color="Border"}); w:_bind(label,{BackgroundColor3="SurfaceRaised",TextColor3="TextSecondary"})
	task.defer(function()
		if not label.Parent then return end
		local p=root.AbsolutePosition; local a=root.AbsoluteSize; local safePos,safeSize=w.Device:SafeArea()
		local x=math.clamp(p.X,safePos.X+8,math.max(safePos.X+8,safePos.X+safeSize.X-label.AbsoluteSize.X-8))
		local below=p.Y+a.Y+5; local y=below
		if below+label.AbsoluteSize.Y>safePos.Y+safeSize.Y-8 then y=math.max(safePos.Y+8,p.Y-label.AbsoluteSize.Y-5) end
		label.Position=UDim2.fromOffset(x,y)
	end)
	self._tooltip=label
end
function Interactions:_showTouchInfo(text)
	if self._touchInfo then self._touchInfo:Dismiss(); self._touchInfo=nil end
	local w=self._window; local height=math.min(220,106+math.ceil(#tostring(text)/48)*18)
	local h=Sheet.open(w,height,{OnDismiss=function() self._touchInfo=nil end}); self._touchInfo=h
	local label=Create.New("TextLabel",{Size=UDim2.new(1,-32,1,-40),Position=UDim2.fromOffset(16,24),BackgroundTransparency=1,Text=tostring(text),TextWrapped=true,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Parent=h.Frame}); w:_bind(label,{TextColor3="TextSecondary"})
end
function Interactions:OpenMenu(anchor,items)
	if self._menu then self._menu:Dismiss(); self._menu=nil end
	if #items==0 then return end
	local w=self._window; local maxLen=0
	for _,item in items do maxLen=math.max(maxLen,#tostring(item.Text or item.Title or "Action")) end
	local width=math.clamp(maxLen*7+52,176,250); local rowH=31; local height=12+#items*rowH+math.max(0,#items-1)*2
	local h=if w.Device.Layout=="Drawer" then Sheet.open(w,math.min(360,24+#items*38),{OnDismiss=function() self._menu=nil end}) else Popover.open(w,anchor,Vector2.new(width,height),{OnDismiss=function() self._menu=nil end,Corner=8})
	self._menu=h
	local top=if w.Device.Layout=="Drawer" then 20 else 6
	local list=Create.New("Frame",{Size=UDim2.new(1,-12,1,-top-6),Position=UDim2.fromOffset(6,top),BackgroundTransparency=1,Parent=h.Frame}); Create.List(2).Parent=list
	for _,item in items do
		local b=Create.New("TextButton",{Size=UDim2.new(1,0,0,rowH),BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,Text="",Parent=list})
		Create.New("UICorner",{CornerRadius=UDim.new(0,7),Parent=b}); w:_bind(b,{BackgroundColor3="ControlHover"})
		local offset=10
		if item.Icon then local icon=Icon.new(w,item.Icon,{Size=UDim2.fromOffset(14,14),Position=UDim2.fromOffset(9,8),Parent=b}); Icon.setColor(icon,w.Theme:Get(item.Danger and "Error" or "TextTertiary")); offset=30 end
		local label=Create.New("TextLabel",{Size=UDim2.new(1,-offset-8,1,0),Position=UDim2.fromOffset(offset,0),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Text=w.Locale:Resolve(item.Text or item.Title or "Action"),Parent=b}); w:_bind(label,{TextColor3=item.Danger and "Error" or "TextSecondary"})
		b.MouseEnter:Connect(function() b.BackgroundTransparency=0; label.TextColor3=w.Theme:Get(item.Danger and "Error" or "Text") end)
		b.MouseLeave:Connect(function() b.BackgroundTransparency=1; label.TextColor3=w.Theme:Get(item.Danger and "Error" or "TextSecondary") end)
		b.MouseButton1Click:Connect(function()
			h:Dismiss(); local ok,err=xpcall(item.Callback or function() end,debug.traceback); if not ok then warn(`[BobloUI] context action failed:\n{err}`) end
		end)
	end
end
function Interactions:Attach(control,root,tooltip,userMenu)
	local j=Janitor.new("Control.Interactions"); local hoverToken=0; local w=self._window
	local function tooltipText() local v=type(tooltip)=="function" and tooltip() or tooltip; return v and w.Locale:Resolve(v) or nil end
	if tooltip and w.Device.Class~="Phone" then
		j:Add(root.MouseEnter:Connect(function()
			hoverToken+=1; local token=hoverToken
			j:Add(task.delay(0.4,function() local tip=tooltipText(); if tip and token==hoverToken and root.Parent then self:_showTooltip(root,tip) end end))
		end))
		j:Add(root.MouseLeave:Connect(function() hoverToken+=1; self:_hideTooltip() end))
	elseif tooltip then
		local info=Create.New("TextButton",{Size=UDim2.fromOffset(20,20),Position=UDim2.new(0.6,-24,0,9),AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,Text="",ZIndex=3,Parent=root})
		local icon=Icon.new(w,"info",{Size=UDim2.fromOffset(14,14),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),Parent=info}); Icon.setColor(icon,w.Theme:Get("TextSecondary"))
		j:Add(info.MouseButton1Click:Connect(function() local tip=tooltipText(); if tip then self:_showTouchInfo(tip) end end))
	end
	local function items()
		local out={}; for _,x in userMenu or {} do table.insert(out,x) end
		if control.Reset and control._stateful then table.insert(out,{Text="Reset to default",Icon="reset",Callback=function() control:Reset() end}) end
		if control.CopyValue and control._stateful then table.insert(out,{Text="Copy value",Icon="copy",Callback=function() control:CopyValue() end}) end
		if control.PasteValue and control._stateful and Env.Capabilities.ClipboardRead then table.insert(out,{Text="Paste value",Icon="copy",Callback=function() local ok,err=control:PasteValue(); if not ok and w.Notify then w.Notify:Push({Title="Paste failed",Content=tostring(err),Variant="Warning"}) end end}) end
		if control.Id and w.Favorites then table.insert(out,{Text=w.Favorites:Has(control.Id) and "Remove from Favorites" or "Add to Favorites",Icon="star",Callback=function() w.Favorites:Toggle(control.Id) end}) end
		return out
	end
	j:Add(root.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton2 then self:OpenMenu(root,items())
		elseif input.UserInputType==Enum.UserInputType.Touch then
			local active=true; local start=input.Position; local token=task.delay(0.6,function() if active and root.Parent then self:OpenMenu(root,items()) end end); j:Add(token)
			local conn; conn=input.Changed:Connect(function()
				if (input.Position-start).Magnitude>12 then active=false end
				if input.UserInputState==Enum.UserInputState.End or input.UserInputState==Enum.UserInputState.Cancel then active=false; if conn then conn:Disconnect() end end
			end); j:Add(conn)
		end
	end)); return j
end
function Interactions:Destroy() self:_hideTooltip(); if self._menu then self._menu:Dismiss() end; if self._touchInfo then self._touchInfo:Dismiss() end end
return Interactions

end

__modules["services/Navigation"] = function()
--!nonstrict
-- Keyboard/gamepad focus navigation for controls in the active tab.
local UserInputService=game:GetService("UserInputService")
local Create=__require("runtime/Create")
local Navigation={}; Navigation.__index=Navigation

local NAV_TYPES={Button=true,Toggle=true,Slider=true,Dropdown=true,Input=true,Keybind=true,ColorPicker=true}
local function isNavKey(k)
	return k==Enum.KeyCode.Tab or k==Enum.KeyCode.DPadDown or k==Enum.KeyCode.DPadUp or k==Enum.KeyCode.DPadLeft or k==Enum.KeyCode.DPadRight
end
function Navigation.new(window,enabled)
	local self=setmetatable({_window=window,_enabled=enabled~=false,_focused=nil,_stroke=nil},Navigation)
	self._conn=window.Input.Began:Connect(function(input,processed) self:_input(input,processed) end)
	self._removed=window.Registry.Removed:Connect(function(entry) if self._focused and entry.Handle==self._focused then self:Clear() end end)
	return self
end
function Navigation:SetEnabled(enabled) self._enabled=enabled~=false; if not self._enabled then self:Clear() end; return self end
function Navigation:IsEnabled() return self._enabled end
function Navigation:_entries()
	local w=self._window; local active=w._active; if not active then return {} end
	local list={}
	for _,entry in w.Registry:Entries() do
		local h=entry.Handle
		if NAV_TYPES[entry.Type] and h and not h._destroyed and entry.Tab==active.Id and (not h.IsVisible or h:IsVisible()) and (not h.IsDisabled or not h:IsDisabled()) then table.insert(list,entry) end
	end
	table.sort(list,function(a,b)
		local ha,hb=a.Handle,b.Handle; local sa,sb=ha._section,hb._section
		local ao=(sa and sa._order or 0)*10000+(ha._order or 0); local bo=(sb and sb._order or 0)*10000+(hb._order or 0)
		if ao==bo then return tostring(a.Title)<tostring(b.Title) end; return ao<bo
	end)
	return list
end
function Navigation:_drawFocus(handle)
	if self._stroke then self._stroke:Destroy(); self._stroke=nil end
	local root=handle and handle:GetInstance(); if not root then return end
	self._stroke=Create.New("UIStroke",{Name="BobloUIKeyboardFocus",Thickness=1.5,Transparency=0.04,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Parent=root})
	self._window:_bind(self._stroke,{Color="Accent"})
end
function Navigation:Focus(handle)
	if not handle or handle._destroyed then return self end
	self._focused=handle; if handle.Reveal then handle:Reveal() end; task.defer(function() if self._focused==handle and not handle._destroyed then self:_drawFocus(handle) end end); return self
end
function Navigation:GetFocused() return self._focused end
function Navigation:Clear() self._focused=nil; if self._stroke then self._stroke:Destroy(); self._stroke=nil end; return self end
function Navigation:Move(delta)
	local entries=self:_entries(); if #entries==0 then return self end
	local index=0; for i,e in entries do if e.Handle==self._focused then index=i; break end end
	if index==0 then index=delta<0 and (#entries+1) or 0 end
	index=((index-1+delta)%#entries)+1; return self:Focus(entries[index].Handle)
end
function Navigation:Activate()
	local h=self._focused; if not h or h._destroyed or (h.IsDisabled and h:IsDisabled()) then return self end
	if h.Type=="Button" and h.Click then h:Click()
	elseif h.Type=="Toggle" and h.Flip then h:Flip()
	elseif h.Type=="Dropdown" and h.Open then h:Open()
	elseif h.Type=="Input" and h.Focus then h:Focus()
	elseif h.Type=="Keybind" and h.Capture then h:Capture()
	elseif h.Type=="ColorPicker" and h.Open then h:Open()
	end
	return self
end
function Navigation:_stepSlider(dir)
	local h=self._focused; if not h or h.Type~="Slider" then return false end
	local step=tonumber(h.Step) or 1; h:SetValue((tonumber(h:GetValue()) or 0)+step*dir); return true
end
function Navigation:_input(input,processed)
	if not self._enabled or not self._window:IsVisible() then return end
	if UserInputService:GetFocusedTextBox() then return end
	local k=input.KeyCode
	-- Tab is commonly marked processed by Roblox; allow it when no TextBox owns focus.
	if k==Enum.KeyCode.Tab then local backwards=self._window.Input:IsKeyDown(Enum.KeyCode.LeftShift) or self._window.Input:IsKeyDown(Enum.KeyCode.RightShift); self:Move(backwards and -1 or 1); return end
	if processed then return end
	if k==Enum.KeyCode.DPadDown then self:Move(1); return end
	if k==Enum.KeyCode.DPadUp then self:Move(-1); return end
	if k==Enum.KeyCode.Left or k==Enum.KeyCode.DPadLeft then if self:_stepSlider(-1) then return end end
	if k==Enum.KeyCode.Right or k==Enum.KeyCode.DPadRight then if self:_stepSlider(1) then return end end
	if k==Enum.KeyCode.Return or k==Enum.KeyCode.KeypadEnter or k==Enum.KeyCode.Space or k==Enum.KeyCode.ButtonA then self:Activate(); return end
	if k==Enum.KeyCode.Escape or k==Enum.KeyCode.ButtonB then self:Clear() end
end
function Navigation:Destroy() self:Clear(); if self._conn then self._conn:Disconnect() end; if self._removed then self._removed:Disconnect() end end
return Navigation

end

__modules["services/Notify"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Janitor=__require("runtime/Janitor")
local Icon=__require("primitives/Icon")
local Notify={}; Notify.__index=Notify
local TOK={Default="Accent",Success="Success",Warning="Warning",Error="Error",Loading="Info"}

function Notify.new(window)
	local self=setmetatable({_window=window,_items={},_queue={},_host=nil,_janitor=Janitor.new("Notify")},Notify)
	self:_ensureHost(); self._janitor:Add(window.Device.Changed:Connect(function() self:_applyLayout() end)); self._janitor:Add(window.Theme.Changed:Connect(function() self:_refreshTheme() end)); return self
end
function Notify:_ensureHost()
	if self._host and self._host.Parent then return end; local w=self._window
	self._host=Create.New("Frame",{Name="Notifications",BackgroundTransparency=1,Parent=w.Layers.Toast})
	self._layout=Create.List(8); self._layout.Parent=self._host; self:_applyLayout()
end
function Notify:_applyLayout()
	if not self._host then return end; local w=self._window; local mobile=w.Device.Layout=="Drawer"
	if mobile then
		self._host.Size=UDim2.new(1,-16,0,math.min(500,w.Device.Viewport.Y-24)); self._host.Position=UDim2.fromOffset(8,w.Device.Insets.Top+8); self._host.AnchorPoint=Vector2.new(0,0); self._layout.VerticalAlignment=Enum.VerticalAlignment.Top
	else
		self._host.Size=UDim2.fromOffset(320,560); self._host.Position=UDim2.new(1,-14,1,-14); self._host.AnchorPoint=Vector2.new(1,1); self._layout.VerticalAlignment=Enum.VerticalAlignment.Bottom
	end
end
function Notify:_refreshTheme() for _,item in self._items do if item._dot then item._dot.BackgroundColor3=self._window.Theme:Get(TOK[item.Variant] or "Accent") end end end
function Notify:_mount(item)
	local w=self._window; local j=Janitor.new("Notification"); item._janitor=j; local hasActions=item.Actions and #item.Actions>0
	local hasProgress=item.Progress~=nil; local height=(hasActions and 100 or 66)+(hasProgress and 9 or 0)
	local frame=Create.New("Frame",{Size=UDim2.new(1,0,0,height),BackgroundTransparency=0,BorderSizePixel=0,Parent=self._host})
	Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerMd")),Parent=frame}); local stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.44,Parent=frame}); w:_bind(frame,{BackgroundColor3="SurfaceRaised"}); w:_bind(stroke,{Color="Border"}); j:Add(frame)
	local dot=Create.New("Frame",{Size=UDim2.fromOffset(6,6),Position=UDim2.fromOffset(13,17),BorderSizePixel=0,Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=dot}); dot.BackgroundColor3=w.Theme:Get(TOK[item.Variant] or "Accent")
	item._title=Create.New("TextLabel",{Size=UDim2.new(1,-52,0,20),Position=UDim2.fromOffset(27,8),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Text=item.Title or "",Parent=frame}); w:_bind(item._title,{TextColor3="Text"})
	item._content=Create.New("TextLabel",{Size=UDim2.new(1,-52,0,28),Position=UDim2.fromOffset(27,29),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text=item.Content or "",Parent=frame}); w:_bind(item._content,{TextColor3="TextSecondary"})
	if hasProgress then
		local track=Create.New("Frame",{Size=UDim2.new(1,-26,0,3),Position=UDim2.new(0,13,1,-7),BorderSizePixel=0,BackgroundTransparency=0,Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=track}); w:_bind(track,{BackgroundColor3="ControlInset"})
		item._progressFill=Create.New("Frame",{Size=UDim2.new(math.clamp(tonumber(item.Progress) or 0,0,1),0,1,0),BorderSizePixel=0,Parent=track}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=item._progressFill}); w:_bind(item._progressFill,{BackgroundColor3="Accent"})
	end
	local close=Create.New("TextButton",{Size=UDim2.fromOffset(26,26),Position=UDim2.new(1,-5,0,5),AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,Text="",Parent=frame})
	local closeIcon=Icon.new(w,"close",{Size=UDim2.fromOffset(12,12),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),Parent=close}); Icon.setColor(closeIcon,w.Theme:Get("TextTertiary"))
	j:Add(close.MouseEnter:Connect(function() Icon.setColor(closeIcon,w.Theme:Get("Text")) end)); j:Add(close.MouseLeave:Connect(function() Icon.setColor(closeIcon,w.Theme:Get("TextTertiary")) end)); j:Add(close.MouseButton1Click:Connect(function() item:Dismiss() end)); item._dot=dot
	if hasActions then
		local row=Create.New("Frame",{Size=UDim2.new(1,-26,0,28),Position=UDim2.fromOffset(13,66),BackgroundTransparency=1,Parent=frame}); Create.List(6,Enum.FillDirection.Horizontal,{HorizontalAlignment=Enum.HorizontalAlignment.Right}).Parent=row
		for _,action in item.Actions do
			local b=Create.New("TextButton",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,1,0),BackgroundTransparency=0,BorderSizePixel=0,AutoButtonColor=false,Text="  "..(action.Text or "Action").."  ",Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontSmall"),Parent=row})
			Create.New("UICorner",{CornerRadius=UDim.new(0,7),Parent=b}); w:_bind(b,{BackgroundColor3="ControlInset",TextColor3="TextSecondary"})
			j:Add(b.MouseEnter:Connect(function() b.BackgroundColor3=w.Theme:Get("ControlHover"); b.TextColor3=w.Theme:Get("Text") end)); j:Add(b.MouseLeave:Connect(function() b.BackgroundColor3=w.Theme:Get("ControlInset"); b.TextColor3=w.Theme:Get("TextSecondary") end))
			j:Add(b.MouseButton1Click:Connect(function() local ok,err=xpcall(action.Callback or function() end,debug.traceback); if not ok then warn(err) end end))
		end
	end
	if item.Duration and item.Duration>0 then j:Add(task.delay(item.Duration,function() item:Dismiss() end)) end
end
function Notify:Push(options)
	options=options or {}; local item={Title=options.Title or "Notification",Content=options.Content or "",Variant=options.Variant or "Default",Actions=options.Actions,Progress=options.Progress,Duration=if options.Duration==nil then 4 else options.Duration,_service=self,_dismissed=false}
	function item:Update(o) if self._dismissed then return self end; for k,v in o do self[k]=v end; if self._title then self._title.Text=self.Title or ""; self._content.Text=self.Content or ""; self._dot.BackgroundColor3=self._service._window.Theme:Get(TOK[self.Variant] or "Accent"); if self._progressFill and self.Progress~=nil then self._progressFill.Size=UDim2.new(math.clamp(tonumber(self.Progress) or 0,0,1),0,1,0) end end; return self end
	function item:SetProgress(value) self.Progress=math.clamp(tonumber(value) or 0,0,1); if self._progressFill then self._progressFill.Size=UDim2.new(self.Progress,0,1,0) end; return self end
	function item:Dismiss() if self._dismissed then return end; self._dismissed=true; local p=table.find(self._service._items,self); if p then table.remove(self._service._items,p) end; if self._janitor then self._janitor:Destroy() end; self._service:_drain() end
	if #self._items<4 then table.insert(self._items,item); self:_mount(item) else table.insert(self._queue,item) end; return item
end
function Notify:_drain() while #self._items<4 and #self._queue>0 do local item=table.remove(self._queue,1); if not item._dismissed then table.insert(self._items,item); self:_mount(item) end end end
function Notify:Destroy() for i=#self._items,1,-1 do self._items[i]:Dismiss() end; self._queue={}; self._janitor:Destroy(); if self._host then self._host:Destroy(); self._host=nil end end
return Notify

end

__modules["services/Palette"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Surface=__require("primitives/Surface")
local Icon=__require("primitives/Icon")
local Palette={}; Palette.__index=Palette

local MAX_ROWS=7
local ROW_HEIGHT=44
local SEARCH_HEIGHT=42
local TOP_PAD=10
local LIST_TOP=60
local FOOTER_HEIGHT=24

function Palette.new(window,search,commands)
	local self=setmetatable({_window=window,_search=search,_commands=commands,_handle=nil,_mode="search",_results={},_rows={},_selected=0},Palette)
	self._inputConn=window.Input.Began:Connect(function(i,processed)
		if self._handle then
			if i.KeyCode==Enum.KeyCode.Escape then self:Close(); return end
			if i.KeyCode==Enum.KeyCode.Up then self:_move(-1); return end
			if i.KeyCode==Enum.KeyCode.Down then self:_move(1); return end
			if i.KeyCode==Enum.KeyCode.Return or i.KeyCode==Enum.KeyCode.KeypadEnter then self:_activateSelected(); return end
		end
		if processed then return end
		if i.KeyCode==Enum.KeyCode.K and (window.Input:IsKeyDown(Enum.KeyCode.LeftControl) or window.Input:IsKeyDown(Enum.KeyCode.RightControl)) then self:Open("") end
	end)
	return self
end

function Palette:_desktopHeight(rowCount,empty)
	if empty then return 112 end
	return LIST_TOP + rowCount*ROW_HEIGHT + FOOTER_HEIGHT + 8
end

function Palette:_applySize(rowCount,empty)
	if not self._frame then return end
	local w=self._window
	if w.Device.Layout=="Drawer" then
		self._frame.Size=UDim2.new(1,-12,1,-72)
		self._frame.Position=UDim2.fromOffset(6,60)
		return
	end
	local width=math.min(520,w.Device.Viewport.X-32)
	local height=math.min(404,self:_desktopHeight(rowCount,empty))
	self._frame.Size=UDim2.fromOffset(width,height)
	self._frame.Position=UDim2.fromScale(0.5,0.18)
end

function Palette:Open(query,mode)
	if self._handle then self:Close() end
	self._mode=mode or "search"
	local w=self._window
	local handle=w.Layers:Push({Scrim=true,ScrimTransparency=0.58,Modal=false,OnDismiss=function()
		self._handle=nil; self._box=nil; self._list=nil; self._frame=nil; self._results={}; self._rows={}; self._selected=0
	end})
	self._handle=handle
	local drawer=w.Device.Layout=="Drawer"
	local frame=Surface.new(w,{
		Size=if drawer then UDim2.new(1,-12,1,-72) else UDim2.fromOffset(math.min(520,w.Device.Viewport.X-32),112),
		Position=if drawer then UDim2.fromOffset(6,60) else UDim2.fromScale(0.5,0.18),
		AnchorPoint=if drawer then Vector2.new(0,0) else Vector2.new(0.5,0),
		BorderSizePixel=0,
		Parent=handle.Container,
	},{Token="SurfaceRaised",StrokeToken="Border",StrokeTransparency=0.40,Corner=w.Tokens:Get("CornerLg")})
	frame.ZIndex=handle.Depth*10+3
	self._frame=frame

	local field=Create.New("Frame",{Size=UDim2.new(1,-20,0,SEARCH_HEIGHT),Position=UDim2.fromOffset(10,TOP_PAD),BackgroundTransparency=0,BorderSizePixel=0,Parent=frame})
	Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("FieldRadius")),Parent=field})
	local fieldStroke=Create.New("UIStroke",{Thickness=1,Transparency=0.48,Parent=field})
	w:_bind(field,{BackgroundColor3="ControlInset"}); w:_bind(fieldStroke,{Color="BorderSubtle"})
	local searchIcon=Icon.new(w,"search",{Size=UDim2.fromOffset(16,16),Position=UDim2.fromOffset(12,13),Parent=field})
	Icon.setColor(searchIcon,w.Theme:Get("TextTertiary"))
	local esc=Create.New("TextLabel",{Size=UDim2.fromOffset(34,22),Position=UDim2.new(1,-9,0.5,0),AnchorPoint=Vector2.new(1,0.5),BackgroundTransparency=0,BorderSizePixel=0,Text="ESC",Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontCaption"),Parent=field})
	Create.New("UICorner",{CornerRadius=UDim.new(0,6),Parent=esc}); w:_bind(esc,{BackgroundColor3="SurfaceSecondary",TextColor3="TextTertiary"})
	self._box=Create.New("TextBox",{
		Size=UDim2.new(1,-82,1,0),Position=UDim2.fromOffset(36,0),BackgroundTransparency=1,BorderSizePixel=0,
		ClearTextOnFocus=false,PlaceholderText=w.Locale:T("search.placeholder"),Text=query or "",Font=w.Fonts.Regular,
		TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Parent=field,
	})
	w:_bind(self._box,{TextColor3="Text",PlaceholderColor3="TextTertiary"})
	self._box.Focused:Connect(function() fieldStroke.Transparency=0.08; fieldStroke.Color=w.Theme:Get("AccentBorder") end)
	self._box.FocusLost:Connect(function() fieldStroke.Transparency=0.48; fieldStroke.Color=w.Theme:Get("BorderSubtle") end)

	self._list=Create.New("Frame",{Size=UDim2.new(1,-20,1,-LIST_TOP-FOOTER_HEIGHT),Position=UDim2.fromOffset(10,LIST_TOP),BackgroundTransparency=1,Parent=frame})
	Create.List(0).Parent=self._list
	self._footer=Create.New("TextLabel",{Size=UDim2.new(1,-24,0,FOOTER_HEIGHT),Position=UDim2.new(0,12,1,-FOOTER_HEIGHT-2),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontCaption"),TextXAlignment=Enum.TextXAlignment.Left,Text="UP/DOWN  Navigate     ENTER  Open     ESC  Close",Parent=frame})
	w:_bind(self._footer,{TextColor3="TextTertiary"})

	self._box:GetPropertyChangedSignal("Text"):Connect(function() self:_refresh() end)
	self._box:CaptureFocus()
	self:_refresh()
	return self
end

function Palette:_collect()
	local w=self._window; local text=self._box.Text
	if string.sub(text,1,1)==">" or self._mode=="commands" then return self._commands:Query(string.gsub(text,"^>%s*","")) end
	if string.sub(text,1,1)=="@" then
		local q=string.lower(string.gsub(text,"^@%s*","")); local results={}
		for _,tab in w._tabs do
			local shown=w.Locale:Resolve(tab.Title)
			if q=="" or string.find(string.lower(shown),q,1,true) then table.insert(results,{Kind="Tab",Title=shown,Handle=tab,Path="Tab"}) end
		end
		return results
	end
	if string.sub(text,1,1)=="#" then
		local q=string.lower(string.gsub(text,"^#%s*","")); local results={}
		if w.Config then for _,name in w.Config:List() do if q=="" or string.find(string.lower(name),q,1,true) then table.insert(results,{Kind="Config",Title=name,Id=name,Path="Config profile"}) end end end
		return results
	end
	if string.sub(text,1,1)=="*" then
		local q=string.lower(string.gsub(text,"^%*%s*","")); local results={}
		for _,id in w.Favorites:List() do local h=w:Get(id); if h then local title=w.Locale:Resolve(h.Title or id); if q=="" or string.find(string.lower(title),q,1,true) then table.insert(results,{Kind="Favorite",Title=title,Handle=h,Path="Favorite"}) end end end
		return results
	end
	return self._search:Query(text)
end

function Palette:_emptyState(text)
	local w=self._window
	local title=Create.New("TextLabel",{Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Text=if text=="" then "Search controls" else "No results",Parent=self._list})
	w:_bind(title,{TextColor3=if text=="" then "TextSecondary" else "Text"})
	local hint=Create.New("TextLabel",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,Text=if text=="" then "Type a control, > command, @ tab, # config, or * favorite" else "Try another name or use > @ # *",Parent=self._list})
	w:_bind(hint,{TextColor3="TextTertiary"})
end

function Palette:_refresh()
	if not self._list then return end
	for _,c in self._list:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local w=self._window
	local raw=self:_collect()
	self._results={}; self._rows={}; self._selected=0
	for i=1,math.min(MAX_ROWS,#raw) do self._results[i]=raw[i] end
	local empty=#self._results==0
	self._footer.Visible=not empty
	self:_applySize(#self._results,empty)
	if empty then self:_emptyState(self._box.Text); return end

	for index,r in self._results do
		local b=Create.New("TextButton",{Size=UDim2.new(1,0,0,ROW_HEIGHT),BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,Text="",Parent=self._list})
		Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("FieldRadius")),Parent=b}); w:_bind(b,{BackgroundColor3="AccentSoft"})
		local title=Create.New("TextLabel",{Size=UDim2.new(1,-82,0,21),Position=UDim2.fromOffset(10,4),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Text=r.Title,Parent=b}); w:_bind(title,{TextColor3="Text"})
		local path=Create.New("TextLabel",{Size=UDim2.new(1,-82,0,15),Position=UDim2.fromOffset(10,24),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontCaption"),TextXAlignment=Enum.TextXAlignment.Left,Text=(r.Hidden and r.Requirement and ((r.Path or "").." · requires: "..r.Requirement)) or r.Path or (r.Kind=="Command" and "Command" or ""),Parent=b}); w:_bind(path,{TextColor3="TextTertiary"})
		local kind=Create.New("TextLabel",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,0,20),Position=UDim2.new(1,-10,0.5,0),AnchorPoint=Vector2.new(1,0.5),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontCaption"),Text=string.upper(r.Kind or "CONTROL"),Parent=b}); w:_bind(kind,{TextColor3="TextTertiary"})
		self._rows[index]=b
		b.MouseEnter:Connect(function() self:_select(index) end)
		b.MouseButton1Click:Connect(function() self:_activate(r) end)
	end
	self:_select(1)
end

function Palette:_select(index)
	if #self._rows==0 then self._selected=0; return end
	index=((index-1)%#self._rows)+1; self._selected=index
	for i,row in self._rows do if row.Parent then row.BackgroundTransparency=if i==index then 0 else 1 end end
end
function Palette:_move(delta) if #self._rows==0 then return end; self:_select((self._selected>0 and self._selected or 1)+delta) end
function Palette:_activate(r)
	if not r then return end; local w=self._window
	if r.Kind=="Command" then self._commands:Run(r.Id)
	elseif r.Kind=="Config" and w.Config then w.Config:Load(r.Id)
	elseif r.Kind=="Tab" then r.Handle:Select()
	elseif r.Kind=="Favorite" and r.Handle then r.Handle:Reveal()
	elseif r.Hidden and r.DependencyIds and r.DependencyIds[1] then local dep=w.Registry:Get(r.DependencyIds[1]); if dep and dep.Reveal then dep:Reveal() end
	elseif r.Handle and r.Handle.Reveal then r.Handle:Reveal() end
	self:Close()
end
function Palette:_activateSelected() if self._selected>0 then self:_activate(self._results[self._selected]) end end
function Palette:Close()
	if self._handle then local h=self._handle; self._handle=nil; h:Dismiss() end
	self._box=nil; self._list=nil; self._frame=nil; self._footer=nil; self._results={}; self._rows={}; self._selected=0
end
function Palette:Destroy() self:Close(); if self._inputConn then self._inputConn:Disconnect() end end
return Palette

end

__modules["services/Search"] = function()
--!nonstrict
local Search={}; Search.__index=Search
local function lower(v) return string.lower(tostring(v or "")) end
local function subseq(query,text) local qi=1; for i=1,#text do if string.sub(text,i,i)==string.sub(query,qi,qi) then qi+=1; if qi>#query then return true end end end; return false end
function Search.new(window) return setmetatable({_window=window,_registry=window.Registry},Search) end
function Search:_score(entry,q)
	local id=lower(entry.Id); local title=lower(entry.Title); local desc=lower(entry.Description); local path=lower(entry.Path); local score=0
	if id==q then score=1000 elseif string.sub(title,1,#q)==q then score=800 elseif string.find(title,q,1,true) then score=600 end
	for _,kw in entry.Keywords or {} do local k=lower(kw); if k==q then score=math.max(score,500) elseif string.sub(k,1,#q)==q then score=math.max(score,400) end end
	if string.find(desc,q,1,true) then score=math.max(score,200) end; if string.find(path,q,1,true) then score=math.max(score,150) end; if score==0 and #q>1 and subseq(q,title) then score=80 end
	if self._window.Favorites and entry.Id and self._window.Favorites:Has(entry.Id) then score+=60 end; if entry.Hidden then score-=200 end; return score
end
function Search:Query(text)
	local q=lower(text); local results={}
	for _,entry in self._registry:Entries() do
		if entry.Type~="Section" and entry.Type~="Tab" and entry.Type~="Divider" then
			local score=if q=="" then ((self._window.Favorites and entry.Id and self._window.Favorites:Has(entry.Id)) and 100 or 0) else self:_score(entry,q)
			if score>0 then table.insert(results,{Kind="Control",Id=entry.Id,Title=entry.Title,Path=entry.Path or "",Description=entry.Description,Score=score,Hidden=entry.Hidden,Handle=entry.Handle,Type=entry.Type,DependencyIds=entry.DependencyIds,Requirement=entry.Requirement}) end
		end
	end
	table.sort(results,function(a,b) if a.Score==b.Score then return a.Title<b.Title end; return a.Score>b.Score end); local out={}; for i=1,math.min(12,#results) do out[i]=results[i] end; return out
end
function Search:Reveal(id) local h=self._registry:Get(id); if h and h.Reveal then h:Reveal(); return true end; return false end
function Search:Reindex() return self end
return Search

end

__modules["services/Settings"] = function()
--!nonstrict
-- Built-in settings center. Uses only public window/tab/section/control APIs.
local Env=__require("runtime/Env")
local Settings={}; Settings.__index=Settings

local THEME_TOKENS={"Canvas","Background","Sidebar","Surface","SurfaceRaised","SurfaceInset","SurfaceSecondary","SurfaceHover","SurfaceActive","Control","ControlHover","ControlPressed","ControlInset","BorderSubtle","Border","BorderStrong","Text","TextSecondary","TextTertiary","TextDisabled","Success","Warning","Error","Info","Scrim","Shadow"}

local function clearSection(section)
	for _,control in table.clone(section._controls or {}) do control:Destroy() end
end

function Settings.new(window,options)
	local self=setmetatable({_window=window,_options=options or {},_mounted=false,_refreshing=false,_tokenControls={}},Settings)
	window._settingsService=self
	return self
end

function Settings:_profileOptions()
	local list=self._window.Config and self._window.Config:List() or {}
	if #list==0 then return {"Default"} end
	return list
end

function Settings:_refreshProfiles()
	if self._profileDrop then self._profileDrop:SetOptions(self:_profileOptions()) end
end

function Settings:_refreshFavorites()
	if not self._favoritesSection or self._refreshing then return end; self._refreshing=true
	clearSection(self._favoritesSection)
	local ids=self._window.Favorites:List()
	if #ids==0 then self._favoritesSection:AddParagraph({Content="@settings.favorites.empty"})
	else
		for _,id in ids do local handle=self._window:Get(id); if handle and not handle._destroyed then
			self._favoritesSection:AddButton({Title=handle.Title or id,Text="@settings.open",Variant="Ghost",Callback=function() handle:Reveal() end,ContextMenu={{Text="@settings.removeFavorite",Callback=function() self._window.Favorites:Remove(id) end}}})
		end end
	end
	self._refreshing=false
end

function Settings:_refreshKeybinds()
	if not self._keybindSection or self._refreshing then return end; self._refreshing=true
	clearSection(self._keybindSection); local n=0
	for _,entry in self._window.Registry:Entries() do if entry.Type=="Keybind" and entry.Handle and not entry.Handle._destroyed and not string.match(entry.Id or "","^__settings") then
		n+=1; local h=entry.Handle; local current=h:GetValue(); local key=(type(current)=="table" and current.Key) or "None"
		self._keybindSection:AddButton({Title=h.Title or entry.Id,Text=tostring(key),Variant="Ghost",Callback=function() h:Reveal(); task.defer(function() h:Capture() end) end})
	end end
	if n==0 then self._keybindSection:AddParagraph({Content="@settings.keybinds.empty"}) end
	self._refreshing=false
end

function Settings:_buildConfig(section)
	local w=self._window
	if not w.Config then section:AddParagraph({Variant="Info",Content="@settings.config.disabled"}); return end
	self._profileName=section:AddInput({Id="__settings.configName",Title="@settings.config.name",Default="Default",IgnoreConfig=true,Adaptive=true})
	self._profileDrop=section:AddDropdown({Id="__settings.configProfile",Title="@settings.config.profile",Options=self:_profileOptions(),Default=self:_profileOptions()[1],AllowNone=true,IgnoreConfig=true,Adaptive=true})
	local function chosen() return self._profileDrop:GetValue() or self._profileName:GetValue() or "Default" end
	section:AddButton({Title="@settings.config.save",Text="@settings.save",Variant="Primary",Callback=function() local ok,err=w.Config:Save(self._profileName:GetValue() or chosen()); if ok then self:_refreshProfiles(); w.Notify:Push({Title=w.Locale:T("settings.saved"),Variant="Success"}) else w.Notify:Push({Title=tostring(err),Variant="Error"}) end end})
	section:AddButton({Title="@settings.config.load",Text="@settings.load",Callback=function() local ok,err=w.Config:Load(chosen()); if not ok then w.Notify:Push({Title=tostring(err),Variant="Error"}) end end})
	section:AddButton({Title="@settings.config.autoload",Text="@settings.set",Callback=function() w.Config:SetAutoLoad(chosen()); w.Notify:Push({Title=w.Locale:T("settings.autoloadSet"),Variant="Success"}) end})
	section:AddButton({Title="@settings.config.duplicate",Text="@settings.duplicate",Callback=function() task.spawn(function() local name=w.Dialog:Prompt({Title=w.Locale:T("settings.config.duplicate"),Placeholder="Copy"}):Await(); if name and name~="" then w.Config:Duplicate(chosen(),name); self:_refreshProfiles() end end) end})
	section:AddButton({Title="@settings.config.rename",Text="@settings.rename",Callback=function() task.spawn(function() local name=w.Dialog:Prompt({Title=w.Locale:T("settings.config.rename"),Default=chosen()}):Await(); if name and name~="" then w.Config:Rename(chosen(),name); self:_refreshProfiles() end end) end})
	section:AddButton({Title="@settings.config.delete",Text="@settings.delete",Variant="Danger",Callback=function() task.spawn(function() if w.Dialog:Confirm({Title=w.Locale:T("settings.config.delete"),Content=chosen(),Danger=true}):Await() then w.Config:Delete(chosen()); self:_refreshProfiles() end end) end})
	section:AddButton({Title="@settings.config.export",Text="@settings.export",Callback=function() local raw=w.Config:Export(chosen()); if raw then w.Notify:Push({Title=w.Locale:T("settings.copied"),Variant="Success"}) end end})
	section:AddButton({Title="@settings.config.import",Text="@settings.import",Callback=function() task.spawn(function() local raw=w.Dialog:Prompt({Title=w.Locale:T("settings.config.import"),Content=w.Locale:T("settings.config.paste"),Placeholder="{...}"}):Await(); if raw and raw~="" then local name=w.Dialog:Prompt({Title=w.Locale:T("settings.config.name"),Default="Imported"}):Await(); if name then local ok,err=w.Config:Import(raw,name); if ok then self:_refreshProfiles() else w.Notify:Push({Title=tostring(err),Variant="Error"}) end end end end) end})
end

function Settings:_syncAppearance()
	if not self._mounted then return end; local w=self._window
	if self._themeControl then self._themeControl:SetOptions(w.Theme:List()); self._themeControl:SetValue(w.Theme:Current(),true) end
	if self._accentControl then self._accentControl:SetValue(w.Theme:Get("Accent"),true) end
	if self._scaleControl then self._scaleControl:SetValue(math.floor((w:GetScale() or 1)*100+0.5),true) end
	if self._densityControl then self._densityControl:SetValue(w.Tokens:GetDensity(),true) end
	if self._localeControl then self._localeControl:SetOptions(w.Locale:List()); self._localeControl:SetValue(w.Locale:Get(),true) end
	if self._motionControl then self._motionControl:SetValue(not w.Motion.Enabled,true) end
	if self._contrastControl then self._contrastControl:SetValue(w.Theme:IsHighContrast(),true) end
	if self._navigationControl and w.Navigation then self._navigationControl:SetValue(w.Navigation:IsEnabled(),true) end
	if self._soundsControl and w.Sound then self._soundsControl:SetValue(w.Sound:IsEnabled(),true) end
	if self._soundVolumeControl and w.Sound then self._soundVolumeControl:SetValue(math.floor(w.Sound:GetVolume()*100+0.5),true) end
	for token,control in self._tokenControls do if control and not control._destroyed then control:SetValue(w.Theme:Get(token),true) end end
end

function Settings:_ensureMounted()
	if self._mounted then return self end; self._mounted=true; local w=self._window
	local tab=w:AddTab({Id="__bobloui_settings",Title="@settings.title",Description="@settings.description",Icon="settings",Group="@nav.system",Order=999,_system=true})
	self.Tab=tab
	local appearance=tab:AddSection({Id="__settings.appearance",Title="@settings.appearance",Description="@settings.appearanceDesc",Span="Auto"})
	self._themeControl=appearance:AddDropdown({Id="__settings.theme",Title="@settings.theme",Options=w.Theme:List(),Default=w.Theme:Current(),IgnoreConfig=true,Callback=function(v) w:SetTheme(v) end})
	self._accentControl=appearance:AddColorPicker({Id="__settings.accent",Title="@settings.accent",Default=w.Theme:Get("Accent"),IgnoreConfig=true,Callback=function(v) local c=type(v)=="table" and v.Color or v; if typeof(c)=="Color3" then w:SetAccent(c) end end})
	self._scaleControl=appearance:AddSlider({Id="__settings.scale",Title="@settings.scale",Min=70,Max=140,Step=5,Default=math.floor((w._scale or 1)*100+0.5),Suffix="%",IgnoreConfig=true,Callback=function(v) w:SetScale(v/100) end})
	self._densityControl=appearance:AddDropdown({Id="__settings.density",Title="@settings.density",Options={"Compact","Comfortable","Touch"},Default=w.Tokens:GetDensity(),IgnoreConfig=true,Callback=function(v) w:SetDensity(v) end})
	self._localeControl=appearance:AddDropdown({Id="__settings.locale",Title="@settings.language",Options=w.Locale:List(),Default=w.Locale:Get(),IgnoreConfig=true,Callback=function(v) w:SetLocale(v) end})
	self._motionControl=appearance:AddToggle({Id="__settings.motion",Title="@settings.reducedMotion",Default=not w.Motion.Enabled,IgnoreConfig=true,Callback=function(v) w:SetReducedMotion(v) end})
	self._contrastControl=appearance:AddToggle({Id="__settings.contrast",Title="@settings.highContrast",Default=w.Theme:IsHighContrast(),IgnoreConfig=true,Callback=function(v) w:SetHighContrast(v) end})
	self._navigationControl=appearance:AddToggle({Id="__settings.navigation",Title="@settings.keyboardNavigation",Default=w.Navigation and w.Navigation:IsEnabled() or true,IgnoreConfig=true,Callback=function(v) w:SetKeyboardNavigation(v) end})
	self._soundsControl=appearance:AddToggle({Id="__settings.sounds",Title="@settings.uiSounds",Default=w.Sound and w.Sound:IsEnabled() or true,IgnoreConfig=true,Callback=function(v) w:SetUISounds(v) end})
	self._soundVolumeControl=appearance:AddSlider({Id="__settings.soundVolume",Title="@settings.soundVolume",Min=0,Max=100,Step=5,Default=w.Sound and math.floor(w.Sound:GetVolume()*100+0.5) or 100,Suffix="%",IgnoreConfig=true,VisibleWhen=function(State) return State:Get("__settings.sounds")~=false end,Callback=function(v) w:SetSoundVolume(v/100) end})

	local editor=tab:AddSection({Id="__settings.themeEditor",Title="@settings.themeEditor",Description="@settings.themeEditorDesc",Collapsible=true,Collapsed=true,Span="Auto"})
	for _,token in THEME_TOKENS do local name=token; self._tokenControls[name]=editor:AddColorPicker({Id="__settings.token."..name,Title=name,Default=w.Theme:Get(name),IgnoreConfig=true,Callback=function(v) local c=type(v)=="table" and v.Color or v; if typeof(c)=="Color3" then w.Theme:SetToken(name,c) end end}) end
	editor:AddButton({Title="@settings.theme.reset",Text="@settings.reset",Callback=function() w.Theme:ResetOverrides(); w:SetAccent(nil); w.Notify:Push({Title=w.Locale:T("settings.resetDone"),Variant="Success"}) end})
	editor:AddButton({Title="@settings.theme.export",Text="@settings.export",Callback=function() w:ExportTheme(true); w.Notify:Push({Title=w.Locale:T("settings.copied"),Variant="Success"}) end})
	editor:AddButton({Title="@settings.theme.import",Text="@settings.import",Callback=function() task.spawn(function() local raw=w.Dialog:Prompt({Title=w.Locale:T("settings.theme.import"),Placeholder="{...}"}):Await(); if raw then local ok,err=w:ImportTheme(raw); if not ok then w.Notify:Push({Title=tostring(err),Variant="Error"}) end end end) end})

	local windowSec=tab:AddSection({Id="__settings.window",Title="@settings.window",Span="Auto"})
	windowSec:AddToggle({Id="__settings.lock",Title="@settings.lockWindow",Default=w:IsLocked(),IgnoreConfig=true,Callback=function(v) w:SetLocked(v) end})
	windowSec:AddToggle({Id="__settings.remember",Title="@settings.rememberGeometry",Default=w:GetRememberGeometry(),IgnoreConfig=true,Callback=function(v) w:SetRememberGeometry(v) end})
	windowSec:AddButton({Title="@settings.resetLayout",Text="@settings.reset",Callback=function() w:ResetGeometry() end})
	windowSec:AddButton({Title="@settings.resetAll",Text="@settings.reset",Variant="Danger",Confirm="Reset every saved control to its default value?",Callback=function() w:ResetAll() end})

	local config=tab:AddSection({Id="__settings.configs",Title="@settings.configs",Collapsible=true,Collapsed=false,Span="Auto"}); self:_buildConfig(config)
	self._favoritesSection=tab:AddSection({Id="__settings.favorites",Title="@settings.favorites",Collapsible=true,Collapsed=false,Span="Auto"})
	self._keybindSection=tab:AddSection({Id="__settings.keybinds",Title="@settings.keybinds",Collapsible=true,Collapsed=false,Span="Auto"})
	self:_refreshFavorites(); self:_refreshKeybinds()
	self._favConn=w.Favorites.Changed:Connect(function() task.defer(function() self:_refreshFavorites() end) end)
	self._regAdd=w.Registry.Added:Connect(function(entry) if entry.Type=="Keybind" then task.defer(function() self:_refreshKeybinds() end) end end)
	self._regRemove=w.Registry.Removed:Connect(function(entry) if entry.Type=="Keybind" then task.defer(function() self:_refreshKeybinds() end) end end)
	if w.Config then self._savedConn=w.Config.Saved:Connect(function() self:_refreshProfiles() end) end
	self._themeConn=w.Theme.Changed:Connect(function() task.defer(function() self:_syncAppearance() end) end)
	self._tokensConn=w.Tokens.Changed:Connect(function() task.defer(function() self:_syncAppearance() end) end)
	self._localeConn=w.Locale.Changed:Connect(function() task.defer(function() self:_syncAppearance() end) end)
	self:_syncAppearance()
	return self
end
function Settings:Open() self:_ensureMounted(); if self.Tab then self.Tab:Select() end; return self end
function Settings:Destroy() for _,c in {self._favConn,self._regAdd,self._regRemove,self._savedConn,self._themeConn,self._tokensConn,self._localeConn} do if c then c:Disconnect() end end end
return Settings

end

__modules["services/Sound"] = function()
--!nonstrict
-- Optional UI sound registry. No copyrighted/default assets are bundled: hub authors
-- can register their own sound ids and users can disable the whole layer.
local SoundService=game:GetService("SoundService")
local Janitor=__require("runtime/Janitor")
local Sound={}; Sound.__index=Sound

local function normalize(spec)
	if type(spec)=="string" or type(spec)=="number" then return {Id=tostring(spec),Volume=0.35,PlaybackSpeed=1} end
	if type(spec)~="table" then return nil end
	return {
		Id=tostring(spec.Id or spec.SoundId or ""),
		Volume=math.clamp(tonumber(spec.Volume) or 0.35,0,10),
		PlaybackSpeed=math.clamp(tonumber(spec.PlaybackSpeed or spec.Speed) or 1,0.1,4),
	}
end
local function assetId(id)
	if id=="" then return "" end
	if string.match(id,"^rbxassetid://") or string.match(id,"^https?://") then return id end
	if tonumber(id) then return "rbxassetid://"..id end
	return id
end

function Sound.new(window,options)
	local self=setmetatable({_window=window,_enabled=options.SoundEnabled~=false,_volume=math.clamp(tonumber(options.SoundVolume) or 1,0,1),_sounds={},_janitor=Janitor.new("Sound")},Sound)
	for name,spec in options.Sounds or {} do self:Register(name,spec) end
	return self
end
function Sound:Register(name,spec)
	if type(name)~="string" or name=="" then error("[BobloUI] Sound:Register requires a non-empty name.",2) end
	local normalized=normalize(spec); if not normalized or normalized.Id=="" then error(`[BobloUI] Sound:Register "{name}" requires Id/SoundId.`,2) end
	self._sounds[name]=normalized; return self
end
function Sound:Unregister(name) self._sounds[name]=nil; return self end
function Sound:SetEnabled(enabled) self._enabled=enabled~=false; return self end
function Sound:IsEnabled() return self._enabled end
function Sound:SetVolume(volume) self._volume=math.clamp(tonumber(volume) or 1,0,1); return self end
function Sound:GetVolume() return self._volume end
function Sound:Play(name,override)
	if not self._enabled then return nil end
	local base=self._sounds[name]; if not base then return nil end
	local spec={Id=base.Id,Volume=base.Volume,PlaybackSpeed=base.PlaybackSpeed}
	if type(override)=="table" then if override.Volume~=nil then spec.Volume=math.clamp(tonumber(override.Volume) or spec.Volume,0,10) end; if override.PlaybackSpeed~=nil then spec.PlaybackSpeed=math.clamp(tonumber(override.PlaybackSpeed) or spec.PlaybackSpeed,0.1,4) end end
	local s=Instance.new("Sound"); s.Name="BobloUI_"..name; s.SoundId=assetId(spec.Id); s.Volume=spec.Volume*self._volume; s.PlaybackSpeed=spec.PlaybackSpeed; s.Parent=SoundService
	local conn; conn=s.Ended:Connect(function() if conn then conn:Disconnect(); conn=nil end; if s.Parent then s:Destroy() end end)
	self._janitor:Add(s)
	local ok=pcall(function() s:Play() end); if not ok then s:Destroy(); return nil end
	task.delay(12,function() if s.Parent and not s.IsPlaying then s:Destroy() end end)
	return s
end
function Sound:Destroy() self._sounds={}; self._janitor:Destroy() end
return Sound

end

__modules["services/Storage"] = function()
--!nonstrict
local Env=__require("runtime/Env")
local Storage={}; Storage.__index=Storage
local MEMORY={}
local function ensure(path)
	if not Env.FS then return end
	local acc=""; for part in string.gmatch(path,"[^/]+") do acc=if acc=="" then part else acc.."/"..part; if not Env.FS.IsFolder(acc) then Env.FS.MakeFolder(acc) end end
end
function Storage.new(folder) local root=`BobloUI/{folder or "Default"}`; ensure(root); return setmetatable({Root=root,Memory=not Env.FS},Storage) end
function Storage:_path(name) return self.Root.."/"..name end
function Storage:Read(name) local p=self:_path(name); if Env.FS then return Env.FS.Read(p) end; return MEMORY[p] end
function Storage:Write(name,data) local p=self:_path(name); if Env.FS then ensure(self.Root); return Env.FS.Write(p,data) end; MEMORY[p]=data; return true end
function Storage:Delete(name) local p=self:_path(name); if Env.FS then return Env.FS.Delete(p) end; MEMORY[p]=nil; return true end
function Storage:Exists(name) local p=self:_path(name); return Env.FS and Env.FS.IsFile(p) or MEMORY[p]~=nil end
function Storage:List()
	local out={}; if Env.FS then for _,p in Env.FS.List(self.Root) do local n=string.match(p,"([^/\\]+)$"); if n then table.insert(out,n) end end else local prefix=self.Root.."/"; for p in MEMORY do if string.sub(p,1,#prefix)==prefix then table.insert(out,string.sub(p,#prefix+1)) end end end; table.sort(out); return out
end
return Storage

end

__modules["shell/Section"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Janitor=__require("runtime/Janitor")
local Surface=__require("primitives/Surface")
local Icon=__require("primitives/Icon")
local Button=__require("controls/Button"); local Toggle=__require("controls/Toggle"); local Slider=__require("controls/Slider"); local Dropdown=__require("controls/Dropdown"); local TextField=__require("controls/TextField"); local Keybind=__require("controls/Keybind"); local ColorPicker=__require("controls/ColorPicker"); local Paragraph=__require("controls/Paragraph"); local Divider=__require("controls/Divider"); local Status=__require("controls/Status")
local Section={}; Section.__index=Section
function Section.new(tab,options)
	options=options or {}
	local order=#tab._sections+1
	local column=options.Column==2 and 2 or 1
	local span=options.Span or "Auto"; if span~="Auto" and span~=1 and span~=2 then error("[BobloUI] Section Span must be 'Auto', 1, or 2.",3) end
	local layout=options.Layout or "Stack"; if layout~="Stack" and layout~="Grid" and layout~="Auto" then error("[BobloUI] Section Layout must be 'Stack', 'Grid', or 'Auto'.",3) end
	local self=setmetatable({Id=options.Id,Title=options.Title,Description=options.Description,Collapsible=options.Collapsible==true,Collapsed=options.Collapsed==true,Column=column,Span=span,Layout=layout,_columnExplicit=options.Column~=nil,_effectiveContentLayout=nil,_order=order,_implicit=options._implicit==true,_tab=tab,_window=tab._window,_janitor=Janitor.new(`Section[{options.Title or "Default"}]`),_controls={},_mounted=false,_visible=options.Visible~=false},Section)
	tab._janitor:Add(self,"Destroy",self); table.insert(tab._sections,self); if self.Id then self._window.Registry:Add(self,{Id=self.Id,Type="Section",Title=self.Title or "Section",Tab=tab.Id,Path=tab.Title,Persist=false}) end
	self._janitor:Add(self._window.Tokens.Changed:Connect(function() if self._mounted then self:_applyTokens() end end)); if tab._mounted then self:_mount() end; tab:_scheduleSectionLayout(); return self
end
function Section:_mount()
	if self._mounted then return end; self._mounted=true; local w=self._window; local t=w.Tokens
	self._root=Surface.new(w,{Name="Section",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BorderSizePixel=0,LayoutOrder=self._order,Visible=self._visible,Parent=self._tab:_sectionParent(self.Column)},{Token=if self._implicit then "Canvas" else "Surface",Stroke=not self._implicit,StrokeToken="BorderSubtle",StrokeTransparency=0.72,Corner=if self._implicit then 0 else t:Get("CornerMd")}); self._janitor:Add(self._root)
	self._janitor:Add(self._root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if not self._destroyed then self:_updateContentLayout(); self._tab:_scheduleSectionLayout() end end))
	local pad=if self._implicit then 0 else t:Get("SectionPadding"); self._padding=Create.New("UIPadding",{PaddingTop=UDim.new(0,pad),PaddingBottom=UDim.new(0,pad),PaddingLeft=UDim.new(0,pad),PaddingRight=UDim.new(0,pad),Parent=self._root}); self._rootLayout=Create.List(if self._implicit then t:Get("RowGap") else 8); self._rootLayout.Parent=self._root
	if not self._implicit and self.Title then
		local headerClass=if self.Collapsible then "TextButton" else "Frame"; self._header=Create.New(headerClass,{Size=UDim2.new(1,0,0,self.Description and 38 or 24),BackgroundTransparency=1,BorderSizePixel=0,Text=headerClass=="TextButton" and "" or nil,AutoButtonColor=headerClass=="TextButton" and false or nil,Parent=self._root})
		self._title=Create.New("TextLabel",{Size=UDim2.new(1,-34,0,19),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=t:Get("FontTitle"),TextXAlignment=Enum.TextXAlignment.Left,Text=w.Locale:Resolve(self.Title),Parent=self._header}); w:_bind(self._title,{TextColor3="Text"})
		if self.Description then self._desc=Create.New("TextLabel",{Size=UDim2.new(1,-34,0,15),Position=UDim2.fromOffset(0,20),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=t:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Text=w.Locale:Resolve(self.Description),Parent=self._header}); w:_bind(self._desc,{TextColor3="TextTertiary"}) end
		if self.Collapsible then
			self._chevron=Icon.new(w,"chevron_down",{Size=UDim2.fromOffset(18,18),Position=UDim2.new(1,-2,0,3),AnchorPoint=Vector2.new(1,0),Parent=self._header})
			self._chevron.Rotation=if self.Collapsed then -90 else 0
			self._janitor:Add(self._header.MouseButton1Click:Connect(function() self:SetCollapsed(not self.Collapsed) end))
		end
	end
	self._content=Create.New("Frame",{Name="Controls",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Visible=not self.Collapsed,Parent=self._root})
	self:_updateContentLayout(true)
	for _,control in self._controls do control:_mount() end
	self:_reparentControls()
end
function Section:_wantedContentLayout()
	if self.Layout=="Stack" or self.Layout=="Grid" then return self.Layout end
	if not self._root then return "Stack" end
	return self._root.AbsoluteSize.X>=self._window.Tokens:Get("ControlGridMinWidth") and "Grid" or "Stack"
end
function Section:_destroyGridColumns()
	for _,col in self._gridColumns or {} do if col and col.Parent then col:Destroy() end end
	self._gridColumns=nil; self._gridLayouts=nil
end
function Section:_buildGridColumns()
	if self._gridColumns then return end; local gap=self._window.Tokens:Get("ColumnGap")
	self._gridColumns={}; self._gridLayouts={}
	for i=1,2 do
		local col=Create.New("Frame",{Name="ControlColumn"..i,Size=UDim2.new(0.5,-gap/2,0,0),AutomaticSize=Enum.AutomaticSize.Y,Position=if i==1 then UDim2.new(0,0,0,0) else UDim2.new(0.5,gap/2,0,0),BackgroundTransparency=1,Parent=self._content})
		local layout=Create.List(self._window.Tokens:Get("RowGap")); layout.Parent=col; self._gridColumns[i]=col; self._gridLayouts[i]=layout
	end
end
function Section:_reparentControls()
	if not self._content then return end
	if self._effectiveContentLayout=="Grid" then
		self:_buildGridColumns(); local visibleIndex=0
		for _,control in self._controls do if control._root then visibleIndex+=1; control._root.Parent=self._gridColumns[((visibleIndex-1)%2)+1] end end
	else
		for _,control in self._controls do if control._root then control._root.Parent=self._content end end
	end
	self:_refreshSeparators()
end
function Section:_updateContentLayout(force)
	if not self._content then return end; local wanted=self:_wantedContentLayout(); if not force and self._effectiveContentLayout==wanted then return end
	-- Move controls out before destroying old layout containers.
	for _,control in self._controls do if control._root then control._root.Parent=self._content end end
	if self._contentLayout then self._contentLayout:Destroy(); self._contentLayout=nil end
	self:_destroyGridColumns(); self._effectiveContentLayout=wanted
	if wanted=="Grid" then self:_buildGridColumns() else self._contentLayout=Create.List(self._window.Tokens:Get("RowGap")); self._contentLayout.Parent=self._content end
	self:_reparentControls()
end
function Section:_controlParent(control)
	if not self._content then return nil end
	if self._effectiveContentLayout=="Grid" then self:_buildGridColumns(); local index=table.find(self._controls,control) or #self._controls; return self._gridColumns[((math.max(1,index)-1)%2)+1] end
	return self._content
end
function Section:_applyTokens()
	if not self._mounted then return end; local t=self._window.Tokens; local pad=if self._implicit then 0 else t:Get("SectionPadding"); local u=UDim.new(0,pad)
	if self._padding then self._padding.PaddingTop=u; self._padding.PaddingBottom=u; self._padding.PaddingLeft=u; self._padding.PaddingRight=u end
	if self._rootLayout then self._rootLayout.Padding=UDim.new(0,if self._implicit then t:Get("RowGap") else 8) end; if self._contentLayout then self._contentLayout.Padding=UDim.new(0,t:Get("RowGap")) end; for _,layout in self._gridLayouts or {} do layout.Padding=UDim.new(0,t:Get("RowGap")) end; self:_updateContentLayout()
	if self._title then self._title.TextSize=t:Get("FontTitle") end; if self._desc then self._desc.TextSize=t:Get("FontSmall") end
end
function Section:_refreshSeparators()
	local groups={}
	for _,control in self._controls do if control._separator and control._root and control._root.Visible then local parent=control._root.Parent; groups[parent]=groups[parent] or {}; table.insert(groups[parent],control) end end
	for _,visible in groups do for i,control in visible do control._separator.Visible=i<#visible end end
end
function Section:_registerControl(c) table.insert(self._controls,c); if self._mounted then task.defer(function() if not self._destroyed then self:_reparentControls() end end) end end
function Section:_removeControl(c) local p=table.find(self._controls,c); if p then table.remove(self._controls,p) end; if self._mounted then self:_reparentControls() else self:_refreshSeparators() end end
function Section:AddCustom(name,o) local factory=self._window.CustomControls and self._window.CustomControls[name]; if not factory then error(`[BobloUI] unknown custom control "{tostring(name)}".`,2) end; return factory(self,o or {}) end
function Section:AddButton(o) return Button.new(self,o) end; function Section:AddToggle(o) return Toggle.new(self,o) end; function Section:AddSlider(o) return Slider.new(self,o) end; function Section:AddDropdown(o) return Dropdown.new(self,o) end; function Section:AddInput(o) return TextField.new(self,o) end; function Section:AddKeybind(o) return Keybind.new(self,o) end; function Section:AddColorPicker(o) return ColorPicker.new(self,o) end; function Section:AddParagraph(o) return Paragraph.new(self,o) end; function Section:AddDivider(o) return Divider.new(self,o or {}) end; function Section:AddStatus(o) return Status.new(self,o) end
function Section:_refreshLocale() if self._title then self._title.Text=self._window.Locale:Resolve(self.Title or "") end; if self._desc then self._desc.Text=self._window.Locale:Resolve(self.Description or "") end; if self.Id then self._window.Registry:Update(self,{Title=self._window.Locale:Resolve(self.Title or "Section"),Path=self._window.Locale:Resolve(self._tab.Title)}) end; for _,control in self._controls do if control._refreshText then control:_refreshText() end end end
function Section:SetTitle(t) self.Title=t; if self._title then self._title.Text=self._window.Locale:Resolve(t or "") end; if self.Id then self._window.Registry:Update(self,{Title=self._window.Locale:Resolve(t or "Section")}) end; return self end
function Section:SetSpan(span)
	if span~="Auto" and span~=1 and span~=2 then error("[BobloUI] Section:SetSpan expects 'Auto', 1, or 2.",2) end
	self.Span=span; self._tab:_scheduleSectionLayout(); return self
end
function Section:SetLayout(layout) if layout~="Stack" and layout~="Grid" and layout~="Auto" then error("[BobloUI] Section:SetLayout expects 'Stack', 'Grid', or 'Auto'.",2) end; self.Layout=layout; self:_updateContentLayout(true); return self end
function Section:Reset() for _,control in self._controls do if control.Reset then control:Reset() end end; return self end
function Section:SetVisible(v) self._visible=v==true; if self._root then self._root.Visible=self._visible end; self._tab:_scheduleSectionLayout(); return self end
function Section:SetCollapsed(v) self.Collapsed=v==true; if self._content then self._content.Visible=not self.Collapsed end; if self._chevron then self._chevron.Rotation=if self.Collapsed then -90 else 0 end; self._tab:_scheduleSectionLayout(); return self end
function Section:GetInstance() return self._root end
function Section:Destroy() if self._destroyed then return end; self._destroyed=true; self._tab._janitor:Release(self); if self.Id then self._window.Registry:Remove(self) end; local p=table.find(self._tab._sections,self); if p then table.remove(self._tab._sections,p) end; for _,control in table.clone(self._controls) do control:Destroy() end; self._janitor:Destroy(); if not self._tab._destroyed then self._tab:_scheduleSectionLayout() end end
return Section

end

__modules["shell/Window"] = function()
--!nonstrict
--[[
	Window — the shell.

	Window shell, navigation, lazy tab mounting and responsive layout switching.

	Two things here are load-bearing for later steps and are built now rather
	than retrofitted:

	  * lazy mounting. Tab:_ensureMounted() already gates page construction, so
	    step 8 only has to fill in what gets built, not change WHEN.
	  * layout switching by reparenting. The nav list is moved between the
	    sidebar and the drawer, never rebuilt, so control state cannot be lost
	    on a device rotation.

	Drag, resize and control gestures all share kernel/Input so a window does not
	add its own global UserInputService listeners.
]]

local Create = __require("runtime/Create")
local Janitor = __require("runtime/Janitor")
local Signal = __require("runtime/Signal")
local Util = __require("runtime/Util")
local Section = __require("shell/Section")
local Icon = __require("primitives/Icon")
local Badge = __require("primitives/Badge")

local New = Create.New

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local FADE_TIME = 0.12
local DRAWER_TIME = 0.18

local function drawSearchIcon(window, parent)
	local ring = New("Frame", {
		Size = UDim2.fromOffset(11, 11),
		Position = UDim2.new(0.5, -2, 0.5, -2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = parent,
	})
	New("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ring})
	local stroke = New("UIStroke", {Thickness = 1.5, Transparency = 0.08, Parent = ring})
	window:_bind(stroke, {Color = "TextSecondary"})
	local handle = New("Frame", {
		Size = UDim2.fromOffset(6, 1.5),
		Position = UDim2.new(0.5, 6, 0.5, 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BorderSizePixel = 0,
		Parent = parent,
	})
	New("UICorner", {CornerRadius = UDim.new(1, 0), Parent = handle})
	window:_bind(handle, {BackgroundColor3 = "TextSecondary"})
end

local function drawThemeIcon(window, parent)
	local moon = New("Frame", {
		Size = UDim2.fromOffset(13, 13),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = parent,
	})
	New("UICorner", {CornerRadius = UDim.new(1, 0), Parent = moon})
	local stroke = New("UIStroke", {Thickness = 1.4, Transparency = 0.08, Parent = moon})
	window:_bind(stroke, {Color = "TextSecondary"})
	local mask = New("Frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.new(0.5, 3, 0.5, -2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		Parent = parent,
	})
	New("UICorner", {CornerRadius = UDim.new(1, 0), Parent = mask})
	window:_bind(mask, {BackgroundColor3 = "Canvas"})
end

-- ===================================================================
-- Tab
-- ===================================================================

function Tab.new(window, options)
	local self = setmetatable({
		Id = options.Id or Util.slug(options.Title),
		Title = options.Title,
		Description = options.Description,
		Icon = options.Icon,
		Badge = options.Badge,
		Group = options.Group,
		Order = options.Order or (#window._tabs + 1),

		_window = window,
		_janitor = Janitor.new(`Tab[{options.Title}]`),
		_mounted = false,
		_selected = false,
		_sections = {},
		_defaultSection = nil,
		_twoColumn = false,
		_layoutPending = false,
	}, Tab)

	window._janitor:Add(self,"Destroy",self)

	local tokens = window.Tokens

	-- Nav entry ---------------------------------------------------
	local button = New("TextButton", {
		Name = `Nav_{self.Id}`,
		Size = UDim2.new(1, 0, 0, tokens:Get("NavItemHeight")),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = window:_navLayoutOrder(self.Group,self.Order),
		Visible = options.Visible ~= false,
		Parent = window._navList,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = button })
	local indicator = New("Frame", {Name="Indicator", Size=UDim2.fromOffset(2,18), Position=UDim2.new(0,0,0.5,0), AnchorPoint=Vector2.new(0,0.5), BorderSizePixel=0, Visible=false, Parent=button})
	New("UICorner", {CornerRadius=UDim.new(1,0), Parent=indicator}); window:_bind(indicator,{BackgroundColor3="Accent"})
	self._indicator=indicator
	self._janitor:Add(button)

	-- Built-in vector icons keep navigation consistent even without external assets.
	local avatarProps = {
		Name = "Avatar",
		Size = UDim2.fromOffset(tokens:Get("IconMd"), tokens:Get("IconMd")),
		Position = UDim2.new(0, 9, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = button,
	}
	local avatar = Icon.new(window, options.Icon or "star", avatarProps)

	local label = New("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.new(0, 34, 0, 0),
		BackgroundTransparency = 1,
		Font = window.Fonts.Medium,
		TextSize = tokens:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = window.Locale:Resolve(options.Title),
		Parent = button,
	})

	window:_bind(button, { BackgroundColor3 = "SurfaceHover" })
	window:_bind(label, { TextColor3 = "TextSecondary" })

	self._button = button
	self._avatar = avatar
	self._label = label
	self._badge = nil
	if options.Badge then self:SetBadge(options.Badge) end

	self._janitor:Add(button.MouseEnter:Connect(function()
		if not self._selected then
			button.BackgroundTransparency = 0.72
		end
	end))
	self._janitor:Add(button.MouseLeave:Connect(function()
		if not self._selected then
			button.BackgroundTransparency = 1
		end
	end))
	self._janitor:Add(button.MouseButton1Click:Connect(function()
		self:Select()
	end))

	-- Page --------------------------------------------------------
	self._page = New("ScrollingFrame", {
		Name = `Page_{self.Id}`,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageTransparency = 0.4,
		ClipsDescendants = true,
		Parent = window._content,
	})
	self._janitor:Add(self._page)

	self._pagePadding = New("UIPadding", {
		PaddingTop = UDim.new(0, tokens:Get("PagePadding")),
		PaddingBottom = UDim.new(0, tokens:Get("PagePadding")),
		PaddingLeft = UDim.new(0, 0),
		PaddingRight = UDim.new(0, 0),
		Parent = self._page,
	})
	self._introHeight = if self.Description then 54 else 36
	local pagePadding = tokens:Get("PagePadding")
	self._pageIntro = New("Frame", {
		Name = "PageIntro",
		Size = UDim2.new(1, -(pagePadding * 2), 0, self._introHeight),
		Position = UDim2.fromOffset(pagePadding, 0),
		BackgroundTransparency = 1,
		Parent = self._page,
	})
	self._pageTitle = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = window.Fonts.Bold,
		TextSize = tokens:Get("FontHeading"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = window.Locale:Resolve(self.Title),
		Parent = self._pageIntro,
	})
	window:_bind(self._pageTitle, {TextColor3 = "Text"})
	if self.Description then
		self._pageDescription = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.fromOffset(0, 26),
			BackgroundTransparency = 1,
			Font = window.Fonts.Regular,
			TextSize = tokens:Get("FontSmall"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = window.Locale:Resolve(self.Description),
			Parent = self._pageIntro,
		})
		window:_bind(self._pageDescription, {TextColor3 = "TextTertiary"})
	end
	self._sectionHost = New("Frame", {
		Name = "SectionHost",
		Size = UDim2.new(1, -(pagePadding * 2), 0, 0),
		Position = UDim2.fromOffset(pagePadding, self._introHeight),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		Parent = self._page,
	})
	self._emptyState = New("TextLabel", {
		Name = "EmptyState",
		Size = UDim2.new(1, -(pagePadding * 2), 0, 54),
		Position = UDim2.fromOffset(pagePadding, self._introHeight + 24),
		BackgroundTransparency = 1,
		Font = window.Fonts.Regular,
		TextSize = tokens:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Text = "Nothing here yet",
		Visible = false,
		Parent = self._page,
	})
	window:_bind(self._emptyState, { TextColor3 = "TextTertiary" })
	self._column1 = New("Frame", {Name="Column1", Size=UDim2.new(1,0,0,0), Position=UDim2.fromOffset(0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, Parent=self._sectionHost})
	self._column2 = New("Frame", {Name="Column2", Size=UDim2.new(1,0,0,0), Position=UDim2.fromOffset(0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, Visible=false, Parent=self._sectionHost})
	self._column1Layout = Create.List(tokens:Get("SectionGap")); self._column1Layout.Parent = self._column1
	self._column2Layout = Create.List(tokens:Get("SectionGap")); self._column2Layout.Parent = self._column2
	self._janitor:Add(self._sectionHost:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_scheduleSectionLayout()
	end))

	window:_bind(self._page, { ScrollBarImageColor3 = "BorderStrong" })

	return self
end

--[[
	Lazy mounting.

	State registration and search indexing must NOT wait for this — a control
	that only exists once its tab is opened is the classic lazy-UI bug. Step 8
	builds Instances here and nothing else.
]]
function Tab:_ensureMounted()
	self._mounted = true
	for _, section in self._sections do
		if not section._mounted then section:_mount() end
	end
	if self._emptyState then self._emptyState.Visible = #self._sections == 0 end
end


function Tab:_applyTokens()
	local t = self._window.Tokens
	local pagePadding = t:Get("PagePadding")
	if self._pagePadding then
		self._pagePadding.PaddingTop = UDim.new(0, pagePadding)
		self._pagePadding.PaddingBottom = UDim.new(0, pagePadding)
		self._pagePadding.PaddingLeft = UDim.new(0, 0)
		self._pagePadding.PaddingRight = UDim.new(0, 0)
	end
	if self._pageIntro then
		self._pageIntro.Position = UDim2.fromOffset(pagePadding, 0)
		self._pageIntro.Size = UDim2.new(1, -(pagePadding * 2), 0, self._introHeight)
	end
	if self._sectionHost then
		self._sectionHost.Position = UDim2.fromOffset(pagePadding, self._introHeight)
		self._sectionHost.Size = UDim2.new(1, -(pagePadding * 2), 0, 0)
	end
	if self._emptyState then
		self._emptyState.Position = UDim2.fromOffset(pagePadding, self._introHeight + 24)
		self._emptyState.Size = UDim2.new(1, -(pagePadding * 2), 0, 54)
		self._emptyState.TextSize = t:Get("FontBody")
	end
	if self._pageTitle then self._pageTitle.TextSize=t:Get("FontHeading") end
	if self._pageDescription then self._pageDescription.TextSize=t:Get("FontSmall") end
	if self._column1Layout then self._column1Layout.Padding=UDim.new(0,t:Get("SectionGap")) end
	if self._column2Layout then self._column2Layout.Padding=UDim.new(0,t:Get("SectionGap")) end
	for _,section in self._sections do if section._applyTokens then section:_applyTokens() end end
	self:_scheduleSectionLayout()
end

function Tab:_sectionParent(column)
	return self._sectionHost
end

function Tab:_scheduleSectionLayout()
	if self._layoutPending or self._destroyed then return end
	self._layoutPending = true
	local thread = task.defer(function()
		self._layoutPending = false
		if not self._destroyed then self:_applySectionLayout(self._window._layout) end
	end)
	self._janitor:Add(thread, nil, "sectionLayoutTask")
end

function Tab:_applySectionLayout(layout)
	if not self._sectionHost or not self._sectionHost.Parent then return end
	local t=self._window.Tokens
	local available=math.floor(self._sectionHost.AbsoluteSize.X+0.5)
	if available<=0 then available=math.max(0,math.floor(self._page.AbsoluteSize.X-(t:Get("PagePadding")*2)+0.5)) end
	local gap=t:Get("ColumnGap")
	local minWidth=t:Get("MinSectionWidth")
	local twoColumn=(layout~="Drawer") and available >= math.max(t:Get("TwoColumnMinWidth"),minWidth*2+gap)
	self._twoColumn=twoColumn
	if self._column1 then self._column1.Visible=false end; if self._column2 then self._column2.Visible=false end
	local visible={}
	for _,section in self._sections do
		if section._root and section._visible~=false then
			section._root.Parent=self._sectionHost
			table.insert(visible,section)
		end
	end
	local function heightOf(section)
		return math.max(1,math.floor((section._root and section._root.AbsoluteSize.Y or 1)+0.5))
	end
	local half=if twoColumn then math.max(1,math.floor((available-gap)/2)) else available
	if not twoColumn then
		local y=0
		for _,sec in visible do
			sec._root.Size=UDim2.fromOffset(available,0)
			sec._root.Position=UDim2.fromOffset(0,y)
			y+=heightOf(sec)+gap
		end
		self._sectionHost.Size=UDim2.new(1,0,0,math.max(0,y-gap))
		return
	end

	-- Desktop uses a small masonry layout instead of row pairing. A tall card
	-- in the left column must not create a matching blank hole under a short
	-- card on the right. Full-span sections act as synchronization barriers.
	local y1,y2=0,0
	local onlyOne=#visible==1
	local function placeColumn(sec,column)
		local x=if column==1 then 0 else half+gap
		local width=if column==1 then half else available-gap-half
		local y=if column==1 then y1 else y2
		sec._root.Size=UDim2.fromOffset(width,0)
		sec._root.Position=UDim2.fromOffset(x,y)
		local nextY=y+heightOf(sec)+gap
		if column==1 then y1=nextY else y2=nextY end
	end
	local function placeFull(sec)
		local y=math.max(y1,y2)
		sec._root.Size=UDim2.fromOffset(available,0)
		sec._root.Position=UDim2.fromOffset(0,y)
		local nextY=y+heightOf(sec)+gap
		y1,y2=nextY,nextY
	end

	for _,sec in visible do
		local wantsFull=sec.Span==2 or (sec.Span=="Auto" and onlyOne)
		if wantsFull then
			placeFull(sec)
		else
			-- Respect an explicitly requested legacy column, otherwise fill the
			-- shorter column. Section.new stores whether Column was explicit.
			local column
			if sec._columnExplicit then column=sec.Column else column=if y1<=y2 then 1 else 2 end
			placeColumn(sec,column)
		end
	end
	self._sectionHost.Size=UDim2.new(1,0,0,math.max(0,math.max(y1,y2)-gap))
end

function Tab:AddSection(options)
	options = options or {}
	if not options.Title and not options._implicit then error("[BobloUI] AddSection requires Title.", 2) end
	local section=Section.new(self, options)
	if self._emptyState then self._emptyState.Visible=false end
	return section
end

function Tab:_default()
	if not self._defaultSection then self._defaultSection = Section.new(self, {_implicit=true}) end
	return self._defaultSection
end
function Tab:AddCustom(name,o) return self:_default():AddCustom(name,o) end
function Tab:AddButton(o) return self:_default():AddButton(o) end
function Tab:AddToggle(o) return self:_default():AddToggle(o) end
function Tab:AddSlider(o) return self:_default():AddSlider(o) end
function Tab:AddDropdown(o) return self:_default():AddDropdown(o) end
function Tab:AddInput(o) return self:_default():AddInput(o) end
function Tab:AddKeybind(o) return self:_default():AddKeybind(o) end
function Tab:AddColorPicker(o) return self:_default():AddColorPicker(o) end
function Tab:AddParagraph(o) return self:_default():AddParagraph(o) end
function Tab:AddDivider(o) return self:_default():AddDivider(o) end
function Tab:AddStatus(o) return self:_default():AddStatus(o) end

function Tab:Select()
	self._window:_selectTab(self)
	return self
end

function Tab:IsSelected(): boolean
	return self._selected
end

function Tab:_setSelected(selected: boolean)
	self._selected = selected
	self._page.Visible = selected
	self._button.BackgroundTransparency = if selected then 0.72 else 1
	if self._indicator then self._indicator.Visible=selected end

	local theme = self._window.Theme
	self._label.TextColor3 = theme:Get(if selected then "Text" else "TextSecondary")
	Icon.setColor(self._avatar, theme:Get(if selected then "Accent" else "AccentMuted"))

	if selected then
		self:_ensureMounted()
	end
end

function Tab:_refreshLocale()
	local shown=self._window.Locale:Resolve(self.Title)
	self._label.Text=shown; 	if self._pageTitle then self._pageTitle.Text=shown end
	if self._pageDescription then self._pageDescription.Text=self._window.Locale:Resolve(self.Description or "") end
	if self._window.Registry then self._window.Registry:Update(self,{Title=shown,Path=shown}) end
	for _,section in self._sections do if section._refreshLocale then section:_refreshLocale() end end
	if self._selected then self._window:_refreshHeaderTitle() end
	self._window:_refreshGroups()
end

function Tab:SetGroup(group) self.Group=group; if self._button then self._button.LayoutOrder=self._window:_navLayoutOrder(group,self.Order) end; self._window:_refreshGroups(); return self end

function Tab:SetTitle(title: string)
	self.Title = title
	local shown=self._window.Locale:Resolve(title)
	self._label.Text = shown
	if self._pageTitle then self._pageTitle.Text=shown end
		if self._window.Registry then self._window.Registry:Update(self,{Title=shown,Path=shown}) end
	if self._selected then
		self._window:_refreshHeaderTitle()
	end
	return self
end

function Tab:SetDescription(description: string?)
	self.Description=description
	if self._pageDescription then self._pageDescription:Destroy(); self._pageDescription=nil end
	self._introHeight=if description then 54 else 36
	local pagePadding = self._window.Tokens:Get("PagePadding")
	if self._pageIntro then self._pageIntro.Size=UDim2.new(1,-(pagePadding*2),0,self._introHeight); self._pageIntro.Position=UDim2.fromOffset(pagePadding,0) end
	if self._sectionHost then self._sectionHost.Position=UDim2.fromOffset(pagePadding,self._introHeight); self._sectionHost.Size=UDim2.new(1,-(pagePadding*2),0,0) end
	if self._emptyState then self._emptyState.Position=UDim2.fromOffset(pagePadding,self._introHeight+24); self._emptyState.Size=UDim2.new(1,-(pagePadding*2),0,54) end
	self:_scheduleSectionLayout()
	if description and self._pageIntro then
		self._pageDescription=New("TextLabel",{Size=UDim2.new(1,0,0,16),Position=UDim2.fromOffset(0,26),BackgroundTransparency=1,Font=self._window.Fonts.Regular,TextSize=self._window.Tokens:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,Text=self._window.Locale:Resolve(description),Parent=self._pageIntro})
		self._window:_bind(self._pageDescription,{TextColor3="TextTertiary"})
	end
	return self
end

function Tab:SetIcon(icon)
	self.Icon = icon
	if self._avatar then self._avatar:Destroy() end
	local t=self._window.Tokens
	local props={Name="Avatar",Size=UDim2.fromOffset(t:Get("IconMd"),t:Get("IconMd")),Position=UDim2.new(0,9,0.5,0),AnchorPoint=Vector2.new(0,0.5),Parent=self._button}
	self._avatar=Icon.new(self._window,icon or "star",props)
	self:_setSelected(self._selected)
	self._window:_applyLayout(self._window._layout,true)
	return self
end

function Tab:SetBadge(text)
	self.Badge=text
	if self._badge then self._badge:Destroy(); self._badge=nil end
	if text then self._badge=Badge.new(self._window,text,"Neutral",self._button); self._badge.Position=UDim2.new(1,-8,0.5,0); self._badge.AnchorPoint=Vector2.new(1,0.5); self._badge.Visible=self._window._layout~="Rail" end
	return self
end

function Tab:SetVisible(visible: boolean)
	self._button.Visible = visible
	if not visible and self._selected then
		self._window:_selectFirstVisible()
	end
	return self
end

function Tab:GetInstance(): Instance
	return self._page
end

function Tab:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	local window = self._window
	window._janitor:Release(self)
	if window.Registry then window.Registry:Remove(self) end
	local position = table.find(window._tabs, self)
	if position then
		table.remove(window._tabs, position)
	end
	local wasSelected = self._selected
	self._janitor:Destroy()
	if wasSelected and not window._destroying then
		window:_selectFirstVisible()
	end
end

-- ===================================================================
-- Window
-- ===================================================================

function Window.new(context, options)
	local self = setmetatable({
		Id = context.Id,
		Title = options.Title,
		Subtitle = options.Subtitle,

		Theme = context.Theme,
		Tokens = context.Tokens,
		Device = context.Device,
		Layers = context.Layers,
		Fonts = context.Fonts,
		State = context.State,
		Registry = context.Registry,
		Input = context.Input,
		Motion = context.Motion,
		Locale = context.Locale,

		Unloading = Signal.new("Window.Unloading"),

		_janitor = context.Janitor,
		_tabs = {},
		_active = nil,
		_layout = nil,
		_drawer = nil,
		_visible = true,
		_size = options.Size or UDim2.fromOffset(720, 480),
		_minSize = options.MinSize or Vector2.new(500, 340),
		_themeHandles = {},
		_groups = {}, _groupSeq = 0,
		_locked = false, _scale = options.Scale or 1, _rememberGeometry = options.RememberGeometry ~= false,
	}, Window)

	self:_build()
	self:_applyLayout(self.Device.Layout, true)

	self._janitor:Add(self.Device.Changed:Connect(function(device, changed)
		if changed.Layout then
			self:_applyLayout(device.Layout)
		end
		if changed.Class then
			self.Tokens:SetDeviceClass(device.Class)
		end
		if changed.Viewport or changed.Insets then
			self:_applyGeometry()
		end
	end))

	self._janitor:Add(self.Tokens.Changed:Connect(function()
		self:_applyTokens()
	end))

	self._janitor:Add(self.Theme.Changed:Connect(function()
		self:_flashThemeSwap()
		for _,tab in self._tabs do tab:_setSelected(tab._selected) end
	end))

	-- Edge swipe opens the mobile drawer; a left swipe while it is open closes it.
	self._janitor:Add(self.Input.Began:Connect(function(input,processed)
		if processed or self._layout~="Drawer" or input.UserInputType~=Enum.UserInputType.Touch then return end
		local start=input.Position; local dx=0
		if not self._drawer and start.X<=24 then
			self.Input:CapturePointer(self,input,function(move) dx=move.Position.X-start.X end,function() if dx>60 then self:OpenDrawer() end end)
		elseif self._drawer then
			self.Input:CapturePointer(self,input,function(move) dx=move.Position.X-start.X end,function() if dx < -60 then self:CloseDrawer() end end)
		end
	end))

	return self
end

function Window:_bind(instance: Instance, map: { [string]: any })
	local handles = self.Theme:BindMany(instance, map)
	local released = false
	local destroying
	local function release()
		if released then return end
		released = true
		self.Theme:Unbind(handles)
		if destroying then destroying:Disconnect() end
	end
	destroying = instance.Destroying:Connect(release)
	self._janitor:Add(release)
	return handles
end

-- ===== construction ==============================================

function Window:_build()
	local tokens = self.Tokens

	self._root = New("Frame", {
		Name = "Window",
		Size = self._size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.Layers.Root,
	})
	self._janitor:Add(self._root)
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerLg")), Parent = self._root })
	self._rootStroke = New("UIStroke", {
		Thickness = tokens:Get("Stroke"),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = self._root,
	})
	self:_bind(self._root, { BackgroundColor3 = "Canvas" })
	self._rootStroke.Transparency = 0.42
	self:_bind(self._rootStroke, { Color = "BorderStrong" })

	self:_buildHeader()
	self:_buildBody()
	self:_buildResizeGrip()

	-- Covers a theme swap so 2000 instant assignments read as one transition
	-- instead of a flicker. Cheaper than tweening every binding.
	self._flash = New("Frame", {
		Name = "ThemeFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
		Visible = false,
		Parent = self._root,
	})
	self._janitor:Add(self._flash)

	self._restoreButton = New("TextButton", {
		Name = "Restore", Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 0, BorderSizePixel = 0, AutoButtonColor = false,
		Text = (self.Title:sub(1, 1):upper()), Font = self.Fonts.Bold, TextSize = 16,
		Visible = false, Parent = self.Layers.Root,
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._restoreButton })
	self:_bind(self._restoreButton, { BackgroundColor3 = "Accent", TextColor3 = "AccentText" })
	self._janitor:Add(self._restoreButton.MouseButton1Click:Connect(function() self:Show() end))
end

function Window:_buildHeader()
	local tokens = self.Tokens

	self._header = New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, tokens:Get("HeaderHeight")),
		BorderSizePixel = 0,
		Parent = self._root,
	})
	self:_bind(self._header, { BackgroundColor3 = "Canvas" })

	self._headerLine = New("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BorderSizePixel = 0,
		Parent = self._header,
	})
	self._headerLine.BackgroundTransparency = 0.35
	self:_bind(self._headerLine, { BackgroundColor3 = "BorderSubtle" })

	-- Hamburger, drawn rather than typed: no font ships a guaranteed glyph.
	self._navToggle = New("TextButton", {
		Name = "NavToggle",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = self._header,
	})
	for index = 0, 2 do
		local bar = New("Frame", {
			Name = `Bar{index}`,
			Size = UDim2.fromOffset(16, 2),
			Position = UDim2.new(0.5, 0, 0.5, (index - 1) * 5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BorderSizePixel = 0,
			Parent = self._navToggle,
		})
		self:_bind(bar, { BackgroundColor3 = "TextSecondary" })
	end
	self._janitor:Add(self._navToggle.MouseButton1Click:Connect(function()
		self:OpenDrawer()
	end))

	self._brandMark = New("Frame", {
		Name = "BrandMark",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		Parent = self._header,
	})
	New("UICorner", {CornerRadius = UDim.new(0, 8), Parent = self._brandMark})
	self:_bind(self._brandMark, {BackgroundColor3 = "AccentSoft"})
	self._brandGlyph = New("TextLabel", {
		Size = UDim2.fromScale(1,1), BackgroundTransparency = 1,
		Font = self.Fonts.Bold, TextSize = 14, Text = self.Title:sub(1,1):upper(), Parent = self._brandMark,
	})
	self:_bind(self._brandGlyph, {TextColor3 = "Accent"})

	self._titleLabel = New("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -176, 0, 18),
		Position = UDim2.new(0, 52, 0, 9),
		BackgroundTransparency = 1,
		Font = self.Fonts.Bold,
		TextSize = tokens:Get("FontTitle"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self.Title,
		Parent = self._header,
	})
	self:_bind(self._titleLabel, { TextColor3 = "Text" })

	self._subtitleLabel = New("TextLabel", {
		Name = "Subtitle",
		Size = UDim2.new(1, -176, 0, 14),
		Position = UDim2.new(0, 52, 0, 29),
		BackgroundTransparency = 1,
		Font = self.Fonts.Regular,
		TextSize = tokens:Get("FontSmall"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self.Subtitle or "",
		Visible = self.Subtitle ~= nil,
		Parent = self._header,
	})
	self:_bind(self._subtitleLabel, { TextColor3 = "TextSecondary" })

	self._searchButton = New("TextButton", {
		Name = "Search",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -116, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 0.82,
		AutoButtonColor = false,
		Text = "",
		Parent = self._header,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = self._searchButton })
	self:_bind(self._searchButton, { BackgroundColor3 = "ControlHover" })
	drawSearchIcon(self, self._searchButton)
	self._janitor:Add(self._searchButton.MouseEnter:Connect(function() self._searchButton.BackgroundTransparency=0.48 end))
	self._janitor:Add(self._searchButton.MouseLeave:Connect(function() self._searchButton.BackgroundTransparency=0.82 end))
	self._janitor:Add(self._searchButton.MouseButton1Click:Connect(function()
		if self.OpenSearch then self:OpenSearch() end
	end))

	self._themeButton = New("TextButton", {
		Name = "Theme",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -80, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 0.82,
		AutoButtonColor = false,
		Text = "",
		Parent = self._header,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = self._themeButton })
	self:_bind(self._themeButton, { BackgroundColor3 = "ControlHover" })
	drawThemeIcon(self, self._themeButton)
	self._janitor:Add(self._themeButton.MouseEnter:Connect(function() self._themeButton.BackgroundTransparency=0.48 end))
	self._janitor:Add(self._themeButton.MouseLeave:Connect(function() self._themeButton.BackgroundTransparency=0.82 end))
	self._janitor:Add(self._themeButton.MouseButton1Click:Connect(function()
		if self.SetTheme then self:SetTheme(self.Theme:Current() == "Dark" and "Light" or "Dark") end
	end))

	self._minimizeButton = New("TextButton", {
		Name = "Minimize",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -44, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 0.86,
		AutoButtonColor = false,
		Text = "",
		Parent = self._header,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = self._minimizeButton })
	local minLine=New("Frame",{Size=UDim2.fromOffset(12,2),Position=UDim2.new(0.5,0,0.5,3),AnchorPoint=Vector2.new(0.5,0.5),BorderSizePixel=0,Parent=self._minimizeButton})
	self:_bind(minLine,{BackgroundColor3="TextSecondary"}); self:_bind(self._minimizeButton,{BackgroundColor3="ControlHover"})
	self._janitor:Add(self._minimizeButton.MouseEnter:Connect(function() self._minimizeButton.BackgroundTransparency=0.48 end))
	self._janitor:Add(self._minimizeButton.MouseLeave:Connect(function() self._minimizeButton.BackgroundTransparency=0.86 end))
	self._janitor:Add(self._minimizeButton.MouseButton1Click:Connect(function() self:Minimize() end))

	self._closeButton = New("TextButton", {
		Name = "Close",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 0.88,
		AutoButtonColor = false,
		Text = "",
		Parent = self._header,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = self._closeButton })
	for _, rotation in { 45, -45 } do
		local bar = New("Frame", {
			Size = UDim2.fromOffset(14, 2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			BorderSizePixel = 0,
			Parent = self._closeButton,
		})
		self:_bind(bar, { BackgroundColor3 = "TextSecondary" })
	end
	self:_bind(self._closeButton, { BackgroundColor3 = "ControlHover" })
	self._closeButton.BackgroundTransparency = 0.88

	self._janitor:Add(self._closeButton.MouseEnter:Connect(function()
		self._closeButton.BackgroundTransparency = 0.48
	end))
	self._janitor:Add(self._closeButton.MouseLeave:Connect(function()
		self._closeButton.BackgroundTransparency = 0.88
	end))
	self._janitor:Add(self._closeButton.MouseButton1Click:Connect(function()
		self:Hide()
	end))

	self:_attachDrag(self._header)
end

function Window:_buildBody()
	local tokens = self.Tokens

	self._body = New("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -tokens:Get("HeaderHeight")),
		Position = UDim2.new(0, 0, 0, tokens:Get("HeaderHeight")),
		BackgroundTransparency = 1,
		Parent = self._root,
	})

	self._navPanel = New("Frame", {
		Name = "Nav",
		Size = UDim2.new(0, tokens:Get("SidebarWidth"), 1, 0),
		BorderSizePixel = 0,
		Parent = self._body,
	})
	self:_bind(self._navPanel, { BackgroundColor3 = "Sidebar" })

	self._navLine = New("Frame", {
		Name = "Divider",
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		BorderSizePixel = 0,
		Parent = self._navPanel,
	})
	self._navLine.BackgroundTransparency = 0.45
	self:_bind(self._navLine, { BackgroundColor3 = "BorderSubtle" })

	-- Reparented between _navPanel and the drawer. Never rebuilt.
	self._navList = New("Frame", {
		Name = "NavList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = self._navPanel,
	})
	New("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = self._navList,
	})
	Create.List(4).Parent = self._navList

	self._content = New("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -tokens:Get("SidebarWidth"), 1, 0),
		Position = UDim2.new(0, tokens:Get("SidebarWidth"), 0, 0),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self._body,
	})
	self:_bind(self._content, {BackgroundColor3 = "Canvas"})
	self._janitor:Add(self._content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:_scheduleSectionLayouts() end))
end

function Window:_buildResizeGrip()
	self._grip = New("TextButton", {
		Name = "ResizeGrip",
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(1, 0, 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 5,
		Parent = self._root,
	})

	self._janitor:Add(self._grip.InputBegan:Connect(function(input)
		if self._layout == "Drawer" or self._locked then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local startPosition = input.Position
		local startSize = self._root.AbsoluteSize
		self.Input:CapturePointer(self._grip, input, function(move)
			local delta = move.Position - startPosition
			local _, safeSize = self.Device:SafeArea()
			local maxWidth = math.max(320, safeSize.X - 40)
			local maxHeight = math.max(260, safeSize.Y - 40)
			local minWidth = math.min(self._minSize.X, maxWidth)
			local minHeight = math.min(self._minSize.Y, maxHeight)
			local width = math.clamp(startSize.X + delta.X, minWidth, maxWidth)
			local height = math.clamp(startSize.Y + delta.Y, minHeight, maxHeight)
			self._size = UDim2.fromOffset(width, height)
			if self._layout ~= "Drawer" then self._root.Size = self._size end
			self:_scheduleSectionLayouts()
		end, function() self:_scheduleSectionLayouts() end)
	end))
end

function Window:_attachDrag(handle: GuiObject)
	local startPosition
	local dragJanitor = self.Input:AttachDrag(handle, function(delta)
		if not startPosition then return end
		self._root.Position = UDim2.new(
			startPosition.X.Scale, startPosition.X.Offset + delta.X,
			startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
		)
	end, function()
		if self._layout == "Drawer" or self._locked then return false end
		startPosition = self._root.Position
		return true
	end)
	self._janitor:Add(dragJanitor)
end

-- ===== layout ====================================================

function Window:_scheduleSectionLayouts()
	if self._sectionLayoutPending or self._destroying then return end
	self._sectionLayoutPending = true
	local thread = task.defer(function()
		self._sectionLayoutPending = false
		if self._destroying then return end
		for _, tab in self._tabs do tab:_applySectionLayout(self._layout) end
	end)
	self._janitor:Add(thread, nil, "sectionLayoutsTask")
end

function Window:_applyLayout(layout: string, initial: boolean?)
	if self._layout == layout and not initial then
		return
	end
	self._layout = layout

	if not initial then self.Layers:DismissAll() end
	self:CloseDrawer()

	local drawerMode = layout == "Drawer"
	local railMode = layout == "Rail"

	self._navToggle.Visible = drawerMode
	self._grip.Visible = not drawerMode and not self._locked
	self._navPanel.Visible = not drawerMode
	self._subtitleLabel.Visible = self.Subtitle ~= nil and not drawerMode

	if self._navList.Parent ~= self._navPanel then
		self._navList.Parent = self._navPanel
	end

	self:_refreshGroups()
	for _, tab in self._tabs do
		tab:_applySectionLayout(layout)
		tab._label.Visible = not railMode
		if tab._badge then tab._badge.Visible = not railMode end
		tab._avatar.Position = if railMode
			then UDim2.fromScale(0.5, 0.5)
			else UDim2.new(0, 9, 0.5, 0)
		tab._avatar.AnchorPoint = if railMode then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5)
	end

	self:_applyTokens()
	self:_applyGeometry()
	self:_refreshHeaderTitle()
end

--- Re-reads every metric from Tokens. Called on density change and on layout
--- change; never rebuilds Instances.
function Window:_applyTokens()
	local tokens = self.Tokens
	local layout = self._layout
	local drawerMode = layout == "Drawer"
	local railMode = layout == "Rail"

	local navWidth = if railMode then tokens:Get("RailWidth") else tokens:Get("SidebarWidth")
	local headerHeight = tokens:Get("HeaderHeight")

	self._header.Size = UDim2.new(1, 0, 0, headerHeight)
	self._body.Size = UDim2.new(1, 0, 1, -headerHeight)
	self._body.Position = UDim2.new(0, 0, 0, headerHeight)

	self._titleLabel.TextSize = tokens:Get("FontTitle")
	self._subtitleLabel.TextSize = tokens:Get("FontSmall")
	self._rootStroke.Thickness = tokens:Get("Stroke")

	local titleLeft = if drawerMode then 48 else 52
	self._brandMark.Visible = not drawerMode
	self._titleLabel.Position = UDim2.new(0, titleLeft, 0, if self._subtitleLabel.Visible then 9 else 0)
	self._titleLabel.Size = UDim2.new(1, -titleLeft - 148, 0, if self._subtitleLabel.Visible then 20 else headerHeight)
	self._subtitleLabel.Position = UDim2.new(0, titleLeft, 0, 29)

	if drawerMode then
		self._content.Size = UDim2.fromScale(1, 1)
		self._content.Position = UDim2.new()
	else
		self._navPanel.Size = UDim2.new(0, navWidth, 1, 0)
		self._content.Size = UDim2.new(1, -navWidth, 1, 0)
		self._content.Position = UDim2.new(0, navWidth, 0, 0)
	end

	for _,g in self._groups do if g.Label then g.Label.TextSize=tokens:Get("FontCaption") end end
	for _, tab in self._tabs do
		tab:_applyTokens()
		tab._button.Size = UDim2.new(1, 0, 0, tokens:Get("NavItemHeight"))
		tab._label.TextSize = tokens:Get("FontBody")
	end
	self:_scheduleSectionLayouts()
end

function Window:_applyGeometry()
	if self._layout == "Drawer" then
		local position, size = self.Device:SafeArea()
		self._root.AnchorPoint = Vector2.new(0, 0)
		self._root.Position = UDim2.fromOffset(position.X, position.Y)
		self._root.Size = UDim2.fromOffset(size.X, size.Y)
	else
		self._root.AnchorPoint = Vector2.new(0.5, 0.5)
		if self._root.Position.X.Scale == 0 then self._root.Position = UDim2.fromScale(0.5, 0.5) end
		local _, safeSize = self.Device:SafeArea()
		local maxWidth = math.max(320, safeSize.X - 40)
		local maxHeight = math.max(260, safeSize.Y - 40)
		self._root.Size = UDim2.fromOffset(math.min(self._size.X.Offset, maxWidth), math.min(self._size.Y.Offset, maxHeight))
	end
	self:_scheduleSectionLayouts()
end

function Window:_refreshHeaderTitle()
	if self._layout == "Drawer" and self._active then
		self._titleLabel.Text = self.Locale:Resolve(self._active.Title)
	else
		self._titleLabel.Text = self.Title
	end
end

-- ===== drawer ====================================================

function Window:OpenDrawer()
	if self._drawer or self._layout ~= "Drawer" then
		return
	end

	local tokens = self.Tokens
	local width = math.min(tokens:Get("SidebarWidth"), self.Device.Viewport.X - 60)

	local handle = self.Layers:Push({
		Scrim = true,
		ScrimTransparency = 0.45,
		OnDismiss = function()
			self._drawer = nil
			if self._navList and self._navList.Parent ~= self._navPanel then
				self._navList.Parent = self._navPanel
			end
		end,
	})

	local panel = New("Frame", {
		Name = "Drawer",
		Size = UDim2.new(0, width, 1, 0),
		Position = UDim2.fromOffset(-width, 0),
		BorderSizePixel = 0,
		Parent = handle.Container,
	})
	self:_bind(panel, { BackgroundColor3 = "Sidebar" })

	self._navList.Parent = panel

	self.Motion:Tween(panel, TweenInfo.new(DRAWER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(0, 0),
	})

	self._drawer = handle
end

function Window:CloseDrawer()
	if self._drawer then
		self._drawer:Dismiss()
		self._drawer = nil
	end
end

-- ===== theme swap ================================================

function Window:_flashThemeSwap()
	local flash = self._flash
	if not flash or not flash.Parent then
		return
	end
	flash.BackgroundColor3 = self.Theme:Get("Canvas")
	flash.BackgroundTransparency = 0.55
	flash.Visible = true
	local tween = self.Motion:Tween(flash, TweenInfo.new(FADE_TIME), { BackgroundTransparency = 1 })
	if tween then
		tween.Completed:Once(function() flash.Visible = false end)
	else
		flash.Visible = false
	end
end

-- ===== tabs ======================================================

function Window:_ensureGroupHeader(group)
	if not group or group=="" then return nil end
	local existing=self._groups[group]; if existing then return existing end
	self._groupSeq+=1; local index=self._groupSeq; local t=self.Tokens
	local label=New("TextLabel",{Name="Group_"..tostring(index),Size=UDim2.new(1,-12,0,24),BackgroundTransparency=1,Font=self.Fonts.Bold,TextSize=t:Get("FontCaption"),TextXAlignment=Enum.TextXAlignment.Left,Text=string.upper(self.Locale:Resolve(group)),LayoutOrder=index*1000,Parent=self._navList})
	self:_bind(label,{TextColor3="TextTertiary"})
	existing={Index=index,Label=label,Title=group}; self._groups[group]=existing; return existing
end
function Window:_navLayoutOrder(group,order)
	local g=self:_ensureGroupHeader(group); return (g and g.Index*1000 or 0)+(order or 1)
end
function Window:_refreshGroups()
	for _,g in self._groups do if g.Label then g.Label.Text=string.upper(self.Locale:Resolve(g.Title)); g.Label.Visible=self._layout~="Rail" end end
end

function Window:AddTab(options)
	if type(options) ~= "table" or type(options.Title) ~= "string" then
		error("[BobloUI] AddTab requires a table with a Title string.", 2)
	end

	-- Validate BEFORE constructing: a rejected tab must not leave Instances behind.
	local id = options.Id or Util.slug(options.Title)
	for _, existing in self._tabs do
		if existing.Id == id then
			error(`[BobloUI] duplicate tab Id "{id}". Tab ids must be unique per window.`, 2)
		end
	end

	local tab = Tab.new(self, options)
	table.insert(self._tabs, tab)
	if self.Registry then self.Registry:Add(tab, {Id=id, Type="Tab", Title=options.Title, Path=options.Title, Persist=false}) end
	if not self._active and tab._button.Visible then
		self:_selectTab(tab)
	else
		tab:_setSelected(false)
	end

	self:_applyLayout(self._layout, true)
	if not options._system and self._settingsService and not self._settingsService._mounted then self._settingsService:_ensureMounted() end
	return tab
end

function Window:Get(id: string)
	return self.Registry and self.Registry:Get(id) or nil
end

function Window:GetTab(id: string)
	for _, tab in self._tabs do
		if tab.Id == id then
			return tab
		end
	end
	return nil
end

function Window:_selectTab(tab)
	if self._active == tab then
		return
	end
	if self._active then
		self._active:_setSelected(false)
	end
	self._active = tab
	tab:_setSelected(true)
	self:_refreshHeaderTitle()
	self:CloseDrawer()
end

function Window:_selectFirstVisible()
	self._active = nil
	for _, tab in self._tabs do
		if tab._button.Visible then
			self:_selectTab(tab)
			return
		end
	end
end

function Window:SetLocked(locked) self._locked=locked==true; if self._grip then self._grip.Visible=not self._locked and self._layout~="Drawer" end; return self end
function Window:IsLocked() return self._locked==true end
function Window:SetRememberGeometry(enabled) self._rememberGeometry=enabled~=false; return self end
function Window:GetRememberGeometry() return self._rememberGeometry end
function Window:SetSize(size)
	if typeof(size)=="Vector2" then size=UDim2.fromOffset(size.X,size.Y) end
	if typeof(size)~="UDim2" then error("[BobloUI] Window:SetSize expects UDim2 or Vector2.",2) end
	self._size=size; if self._layout~="Drawer" then self._root.Size=size end; self:_scheduleSectionLayouts(); return self
end
function Window:SetPosition(position) if typeof(position)~="UDim2" then error("[BobloUI] Window:SetPosition expects UDim2.",2) end; self._root.Position=position; return self end
function Window:GetGeometry() return {Size=self._size,Position=self._root.Position,Scale=self._scale,Locked=self._locked,Remember=self._rememberGeometry} end
function Window:ResetGeometry() self._size=UDim2.fromOffset(720,480); self._root.Position=UDim2.fromScale(0.5,0.5); if self._layout~="Drawer" then self._root.Size=self._size end; self:SetScale(1); self:SetLocked(false); return self end
function Window:Minimize() return self:Hide() end
function Window:Restore() return self:Show() end
function Window:ResetAll() self.State:Batch(function() for _,entry in self.Registry:GetPersistable() do if entry.Id then self.State:Reset(entry.Id,{Source="RESET"}) end end end); return self end

-- ===== visibility ================================================

function Window:Show()
	self._visible = true
	self._root.Visible = true
	if self._restoreButton then self._restoreButton.Visible = false end
	return self
end

function Window:Hide()
	self._visible = false
	self._root.Visible = false
	if self._restoreButton then self._restoreButton.Visible = true end
	self:CloseDrawer()
	return self
end

function Window:Toggle()
	if self._visible then self:Hide() else self:Show() end
	return self
end

function Window:IsVisible(): boolean
	return self._visible
end

function Window:SetTitle(title: string)
	self.Title = title
	if self._restoreButton then self._restoreButton.Text=title:sub(1,1):upper() end; if self._brandGlyph then self._brandGlyph.Text=title:sub(1,1):upper() end
	self:_refreshHeaderTitle()
	return self
end

function Window:SetSubtitle(text: string?)
	self.Subtitle = text
	self._subtitleLabel.Text = text or ""
	self._subtitleLabel.Visible = text ~= nil and self._layout ~= "Drawer"
	self:_applyTokens()
	return self
end

function Window:GetInstance(): Instance
	return self._root
end

function Window:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	self._destroying = true
	self:CloseDrawer()
	for _,tab in table.clone(self._tabs) do tab:Destroy() end
	self._tabs = {}
	self._active = nil
	self.Unloading:Destroy()
end

return Window


end

__modules["themes/Dark"] = function()
--!nonstrict
local hex=Color3.fromHex
return {
	Canvas=hex("#090B0F"),
	Background=hex("#090B0F"),
	Sidebar=hex("#0B0E12"),
	Surface=hex("#0F1318"),
	SurfaceRaised=hex("#11151B"),
	SurfaceInset=hex("#0C1014"),
	SurfaceSecondary=hex("#151A20"),
	SurfaceHover=hex("#171C23"),
	SurfaceActive=hex("#1B2129"),
	Control=hex("#11161B"),
	ControlHover=hex("#161B22"),
	ControlPressed=hex("#1B2129"),
	ControlInset=hex("#0C1116"),
	BorderSubtle=hex("#1A2028"),
	Border=hex("#242B35"),
	BorderStrong=hex("#313A46"),
	Text=hex("#F4F6F8"),
	TextSecondary=hex("#ADB5C2"),
	TextTertiary=hex("#7F8998"),
	TextDisabled=hex("#535C69"),
	Accent=hex("#8172F2"),
	Success=hex("#55D89A"),
	Warning=hex("#F2B84B"),
	Error=hex("#F06469"),
	Info=hex("#58B9FF"),
	Scrim=hex("#050608"),
	Shadow=hex("#000000"),
}

end

__modules["themes/Light"] = function()
--!nonstrict
local hex=Color3.fromHex
return {
	Canvas=hex("#F5F6F8"),
	Background=hex("#F5F6F8"),
	Sidebar=hex("#F8F9FB"),
	Surface=hex("#FFFFFF"),
	SurfaceRaised=hex("#FFFFFF"),
	SurfaceInset=hex("#F1F3F6"),
	SurfaceSecondary=hex("#F0F2F5"),
	SurfaceHover=hex("#E9ECF1"),
	SurfaceActive=hex("#E1E5EB"),
	Control=hex("#F8F9FB"),
	ControlHover=hex("#F2F4F7"),
	ControlPressed=hex("#EAEDF2"),
	ControlInset=hex("#FFFFFF"),
	BorderSubtle=hex("#E7EAF0"),
	Border=hex("#DDE2E9"),
	BorderStrong=hex("#C8D0DB"),
	Text=hex("#15181D"),
	TextSecondary=hex("#586372"),
	TextTertiary=hex("#7F8998"),
	TextDisabled=hex("#AAB2BE"),
	Accent=hex("#6E5DE7"),
	Success=hex("#169D63"),
	Warning=hex("#B77A09"),
	Error=hex("#D84A50"),
	Info=hex("#147FBE"),
	Scrim=hex("#15181D"),
	Shadow=hex("#101216"),
}

end

__modules["themes/Midnight"] = function()
--!nonstrict
-- Blue-black preset: darker than Dark, softer than OLED.
local hex=Color3.fromHex
return {
	Canvas=hex("#070912"),
	Background=hex("#070912"),
	Sidebar=hex("#090C16"),
	Surface=hex("#0D1120"),
	SurfaceRaised=hex("#101526"),
	SurfaceInset=hex("#090D18"),
	SurfaceSecondary=hex("#141A2C"),
	SurfaceHover=hex("#171E33"),
	SurfaceActive=hex("#1C2540"),
	Control=hex("#101624"),
	ControlHover=hex("#151D31"),
	ControlPressed=hex("#1A2440"),
	ControlInset=hex("#0A0F1B"),
	BorderSubtle=hex("#1A2238"),
	Border=hex("#25304B"),
	BorderStrong=hex("#354261"),
	Text=hex("#F4F6FF"),
	TextSecondary=hex("#B0B9D0"),
	TextTertiary=hex("#7D89A5"),
	TextDisabled=hex("#505A72"),
	Accent=hex("#7C84FF"),
	Success=hex("#54D6A0"),
	Warning=hex("#F0B95B"),
	Error=hex("#EF6A78"),
	Info=hex("#64B9FF"),
	Scrim=hex("#03040A"),
	Shadow=hex("#000000"),
}

end

__modules["themes/OLED"] = function()
--!nonstrict
local hex=Color3.fromHex
return {
	Canvas=hex("#000000"), Background=hex("#000000"), Sidebar=hex("#020203"),
	Surface=hex("#070709"), SurfaceRaised=hex("#09090C"), SurfaceInset=hex("#030304"),
	SurfaceSecondary=hex("#0D0D11"), SurfaceHover=hex("#111116"), SurfaceActive=hex("#17171E"),
	Control=hex("#08080B"), ControlHover=hex("#111116"), ControlPressed=hex("#17171E"), ControlInset=hex("#030304"),
	BorderSubtle=hex("#17171D"), Border=hex("#25252E"), BorderStrong=hex("#383845"),
	Text=hex("#FAFAFC"), TextSecondary=hex("#B8B8C2"), TextTertiary=hex("#858592"), TextDisabled=hex("#555561"),
	Accent=hex("#8172F2"), Success=hex("#55D89A"), Warning=hex("#F2B84B"), Error=hex("#F06469"), Info=hex("#58B9FF"),
	Scrim=hex("#000000"), Shadow=hex("#000000"),
}

end

return __require("init")
