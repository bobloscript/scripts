--[[
	BobloUI v0.9.2-beta.1 - generated bundle, do not edit.
	Source: https://github.com/robscript/boblo-ui
	Built: 2026-08-17T05:58:59.119Z
	Modules: 50
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
	self._stateful=config.Stateful==true; self._persist=config.Persist~=false and self._stateful and options.IgnoreConfig~=true; self._value=config.Default; self._layoutStyle=config.Layout or "Inline"
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

function Base:_measure()
	local t=self._window.Tokens
	if self._layoutStyle=="Stacked" then return t:Get("ControlHeight") + 30 + (self.Description and 15 or 0) end
	return t:Get("ControlHeight") + (self.Description and 14 or 0)
end

function Base:_mount()
	if self._mounted or self._destroyed then return end; self._mounted=true
	local w=self._window; local t=w.Tokens; local h=self:_measure(); local pad=t:Get("ControlPadding")
	self._root=Create.New("CanvasGroup",{Name=self.Type.."_"..(self.Id or "Anonymous"),Size=UDim2.new(1,0,0,h),BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=self._order or 0,Parent=self._section._content}); self._janitor:Add(self._root)
	Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("ControlRadius")),Parent=self._root}); w:_bind(self._root,{BackgroundColor3="ControlHover"})
	self._separator=Create.New("Frame",{Name="Separator",Size=UDim2.new(1,-pad*2,0,1),Position=UDim2.new(0,pad,1,-1),BorderSizePixel=0,BackgroundTransparency=0.58,Parent=self._root}); w:_bind(self._separator,{BackgroundColor3="BorderSubtle"})

	local titleWidth=if self._layoutStyle=="Stacked" then UDim2.new(1,-pad*2-76,0,t:Get("ControlHeight")) else UDim2.new(0.54,-pad,0,t:Get("ControlHeight"))
	self._titleLabel=Create.New("TextLabel",{Size=titleWidth,Position=UDim2.fromOffset(pad,0),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=t:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Text=self:_resolve(self.Title),Parent=self._root}); w:_bind(self._titleLabel,{TextColor3="Text"})
	if self.Description then
		self._descLabel=Create.New("TextLabel",{Size=UDim2.new(if self._layoutStyle=="Stacked" then 1 else 0.68,-pad*2,0,15),Position=UDim2.fromOffset(pad,t:Get("ControlHeight")-10),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=t:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Text=self:_resolve(self.Description),Parent=self._root}); w:_bind(self._descLabel,{TextColor3="TextTertiary"})
	end
	if self._layoutStyle=="Stacked" then
		local y=t:Get("ControlHeight")+(self.Description and 11 or 0)
		self._valueHost=Create.New("Frame",{Size=UDim2.new(1,-pad*2,0,30),Position=UDim2.fromOffset(pad,y),BackgroundTransparency=1,Parent=self._root})
	else
		self._valueHost=Create.New("Frame",{Size=UDim2.new(0.46,-pad,0,t:Get("ControlHeight")),Position=UDim2.new(0.54,0,0,0),BackgroundTransparency=1,Parent=self._root})
	end
	if self._mountValue then self:_mountValue(self._valueHost) end

	self._janitor:Add(self._root.MouseEnter:Connect(function() self:_applyHoverVisual(true) end))
	self._janitor:Add(self._root.MouseLeave:Connect(function() self:_applyHoverVisual(false) end))
	if w.Interactions and (self._tooltip or self._contextMenu or self.Id) then self._janitor:Add(w.Interactions:Attach(self,self._root,self._tooltip,self._contextMenu)) end
	self:_applyVisible(); self:_applyDisabled(); self:_render(self:GetValue()); self._section:_refreshSeparators()
end

function Base:_applyHoverVisual(hover)
	if not self._root then return end
	self._root.BackgroundColor3=self._window.Theme:Get("ControlHover")
	self._root.BackgroundTransparency=if hover and not self._disabled then 0.48 else 1
end
function Base:_resolve(v) return self._window.Locale and self._window.Locale:Resolve(v) or v end
function Base:_refreshText()
	local title=self:_resolve(self.Title); local desc=self:_resolve(self.Description or "")
	if self._titleLabel then self._titleLabel.Text=title end; if self._descLabel then self._descLabel.Text=desc end
	self._window.Registry:Update(self,{Title=title,Description=desc,Path=`{self:_resolve(self._section._tab.Title)} -> {self:_resolve(self._section.Title or "Default")}`})
end
function Base:_applyTokens()
	if not self._root then return end; local t=self._window.Tokens; local h=self:_measure(); local pad=t:Get("ControlPadding")
	self._root.Size=UDim2.new(1,0,0,h); local corner=self._root:FindFirstChildOfClass("UICorner"); if corner then corner.CornerRadius=UDim.new(0,t:Get("ControlRadius")) end
	if self._titleLabel then self._titleLabel.Position=UDim2.fromOffset(pad,0); self._titleLabel.TextSize=t:Get("FontBody"); self._titleLabel.Size=if self._layoutStyle=="Stacked" then UDim2.new(1,-pad*2-76,0,t:Get("ControlHeight")) else UDim2.new(0.54,-pad,0,t:Get("ControlHeight")) end
	if self._descLabel then self._descLabel.Position=UDim2.fromOffset(pad,t:Get("ControlHeight")-10); self._descLabel.TextSize=t:Get("FontSmall") end
	if self._separator then self._separator.Size=UDim2.new(1,-pad*2,0,1); self._separator.Position=UDim2.new(0,pad,1,-1) end
	if self._valueHost then
		if self._layoutStyle=="Stacked" then self._valueHost.Size=UDim2.new(1,-pad*2,0,30); self._valueHost.Position=UDim2.fromOffset(pad,t:Get("ControlHeight")+(self.Description and 11 or 0))
		else self._valueHost.Size=UDim2.new(0.46,-pad,0,t:Get("ControlHeight")); self._valueHost.Position=UDim2.new(0.54,0,0,0) end
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
	local self=setmetatable({},Button); Base.init(self,section,"Button",options,{Stateful=false,Persist=false}); self.Variant=options.Variant or "Default"; self.Text=options.Text or options.Title or "Run"; self.Confirm=options.Confirm; self.Clicked=Signal.new("Button.Clicked"); self._janitor:Add(self.Clicked); return Base.finish(self)
end
function Button:_tokens()
	if self.Variant=="Primary" then return "Accent","AccentText" end
	if self.Variant=="Danger" then return "Error","AccentText" end
	if self.Variant=="Ghost" then return "ControlInset","TextSecondary" end
	return "SurfaceSecondary","Text"
end
function Button:_mountValue(host)
	local w=self._window; local bg,fg=self:_tokens(); local h=w.Tokens:Get("FieldHeight")
	self._button=Create.New("TextButton",{Size=UDim2.new(1,0,0,h),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BorderSizePixel=0,AutoButtonColor=false,Text=self.Text,Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontBody"),Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("FieldRadius")),Parent=self._button}); self._stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.35,Parent=self._button}); w:_bind(self._stroke,{Color=if self.Variant=="Primary" then "AccentBorder" else "BorderSubtle"}); w:_bind(self._button,{BackgroundColor3=bg,TextColor3=fg})
	self._janitor:Add(self._button.MouseEnter:Connect(function() if not self._loading then self._button.BackgroundColor3=w.Theme:Get(if self.Variant=="Primary" then "AccentHover" else "SurfaceHover") end end)); self._janitor:Add(self._button.MouseLeave:Connect(function() self._button.BackgroundColor3=w.Theme:Get(bg) end)); self._janitor:Add(self._button.MouseButton1Click:Connect(function() self:Click() end))
end
function Button:Click()
	if self:IsDisabled() or self._loading then return self end
	local function run() if self.Callback then local ok,err=xpcall(self.Callback,debug.traceback); if not ok then warn(`[BobloUI] Button "{self.Title}" callback failed:\n{err}`) end end; self.Clicked:Fire() end
	if self.Confirm and self._window.Dialog then task.spawn(function() local ok=self._window.Dialog:Confirm({Title=self.Title,Content=self.Confirm}):Await(); if ok then run() end end) else run() end; return self
end
function Button:_setLoadingVisual(v)
	if not self._button then return end; self._button.Text=if v then "" else self.Text; if self._spinner then self._spinner:Destroy(); self._spinner=nil end
	if v then self._spinner=Spinner.new(self._window,self._button,15); self._spinner.Position=UDim2.fromScale(0.5,0.5); self._spinner.AnchorPoint=Vector2.new(0.5,0.5) end
end
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
	ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)),
	ColorSequenceKeypoint.new(1/6,Color3.fromHSV(1/6,1,1)),
	ColorSequenceKeypoint.new(2/6,Color3.fromHSV(2/6,1,1)),
	ColorSequenceKeypoint.new(3/6,Color3.fromHSV(3/6,1,1)),
	ColorSequenceKeypoint.new(4/6,Color3.fromHSV(4/6,1,1)),
	ColorSequenceKeypoint.new(5/6,Color3.fromHSV(5/6,1,1)),
	ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1)),
})

function ColorPicker.new(section,options)
	local self=setmetatable({},ColorPicker)
	self.Alpha=options.Alpha==true; self.Presets=options.Presets or {}; self._popup=nil
	local d=options.Default or Color3.new(1,1,1)
	if self.Alpha then d={Color=d,Alpha=math.clamp(options.DefaultAlpha or 1,0,1)} end
	Base.init(self,section,"ColorPicker",options,{Stateful=true,Default=d}); return Base.finish(self)
end
function ColorPicker:_colour(v) return self.Alpha and (type(v)=="table" and v.Color or Color3.new(1,1,1)) or v end
function ColorPicker:_mountValue(host)
	local w=self._window; local t=w.Tokens
	self._button=Create.New("TextButton",{Size=UDim2.new(1,0,0,t:Get("FieldHeight")),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=0,BorderSizePixel=0,AutoButtonColor=false,Text="",Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("FieldRadius")),Parent=self._button}); self._triggerStroke=Create.New("UIStroke",{Thickness=1,Transparency=0.5,Parent=self._button}); w:_bind(self._triggerStroke,{Color="BorderSubtle"}); w:_bind(self._button,{BackgroundColor3="ControlInset"})
	self._hexLabel=Create.New("TextLabel",{Size=UDim2.new(1,-46,1,0),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=t:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,Parent=self._button}); w:_bind(self._hexLabel,{TextColor3="TextSecondary"})
	self._swatch=Create.New("Frame",{Size=UDim2.fromOffset(26,20),Position=UDim2.new(1,-8,0.5,0),AnchorPoint=Vector2.new(1,0.5),BorderSizePixel=0,Parent=self._button}); Create.New("UICorner",{CornerRadius=UDim.new(0,6),Parent=self._swatch}); Create.New("UIStroke",{Thickness=1,Color=Color3.new(1,1,1),Transparency=0.72,Parent=self._swatch})
	self._janitor:Add(self._button.MouseEnter:Connect(function() if not self._popup then self._button.BackgroundColor3=w.Theme:Get("SurfaceHover") end end)); self._janitor:Add(self._button.MouseLeave:Connect(function() if not self._popup then self._button.BackgroundColor3=w.Theme:Get("ControlInset") end end))
	self._janitor:Add(self._button.MouseButton1Click:Connect(function() if not self:IsDisabled() then if self._popup then self:Close() else self:Open() end end end))
end
function ColorPicker:_render(v)
	local c=self:_colour(v); if typeof(c)~="Color3" then c=Color3.new(1,1,1) end
	if self._swatch then self._swatch.BackgroundColor3=c; self._hexLabel.Text=Util.toHex(c) end
	self:_syncPopup(c)
end
function ColorPicker:_syncPopup(c)
	if not self._sv then return end
	local h,s,v=c:ToHSV(); self._h=h; self._s=s; self._v=v
	self._sv.BackgroundColor3=Color3.fromHSV(h,1,1)
	self._svCursor.Position=UDim2.fromScale(s,1-v); self._hueCursor.Position=UDim2.fromScale(h,0.5)
	if self._hexBox and not self._hexBox:IsFocused() then self._hexBox.Text=Util.toHex(c) end
	if self._rgbBoxes then local vals={math.round(c.R*255),math.round(c.G*255),math.round(c.B*255)}; for i,b in self._rgbBoxes do if not b:IsFocused() then b.Text=tostring(vals[i]) end end end
	if self._alphaBox and not self._alphaBox:IsFocused() then self._alphaBox.Text=tostring(math.round(self:GetAlpha()*100)).."%" end
end
function ColorPicker:_buildPopup(frame)
	local w=self._window; local c=self:_colour(self:GetValue()); local h,s,v=c:ToHSV(); self._h=h; self._s=s; self._v=v
	local width=250
	local sv=Create.New("Frame",{Name="SV",Size=UDim2.new(1,-16,0,108),Position=UDim2.fromOffset(8,8),BackgroundColor3=Color3.fromHSV(h,1,1),BorderSizePixel=0,ClipsDescendants=true,Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=sv}); self._sv=sv
	local white=Create.New("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Parent=sv}); local wg=Create.New("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}),Parent=white})
	local black=Create.New("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,Parent=sv}); local bg=Create.New("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}),Parent=black})
	self._svCursor=Create.New("Frame",{Size=UDim2.fromOffset(12,12),Position=UDim2.fromScale(s,1-v),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,ZIndex=4,Parent=sv}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._svCursor}); Create.New("UIStroke",{Thickness=2,Color=Color3.new(1,1,1),Parent=self._svCursor})
	local svHit=Create.New("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",ZIndex=5,Parent=sv})
	local function setSV(pos) local x=math.clamp((pos.X-sv.AbsolutePosition.X)/math.max(1,sv.AbsoluteSize.X),0,1); local y=math.clamp((pos.Y-sv.AbsolutePosition.Y)/math.max(1,sv.AbsoluteSize.Y),0,1); self._s=x; self._v=1-y; self:_setColour(Color3.fromHSV(self._h,self._s,self._v)) end
	svHit.InputBegan:Connect(function(i) if i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch then return end; setSV(i.Position); w.Input:CapturePointer(self,i,function(move) setSV(move.Position) end,function() end) end)

	local hue=Create.New("Frame",{Name="Hue",Size=UDim2.new(1,-16,0,14),Position=UDim2.fromOffset(8,124),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ClipsDescendants=false,Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=hue}); Create.New("UIGradient",{Color=HUE,Parent=hue}); self._hue=hue
	self._hueCursor=Create.New("Frame",{Size=UDim2.fromOffset(5,20),Position=UDim2.fromScale(h,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=4,Parent=hue}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._hueCursor}); Create.New("UIStroke",{Thickness=1,Color=Color3.new(0,0,0),Transparency=0.45,Parent=self._hueCursor})
	local hueHit=Create.New("TextButton",{Size=UDim2.new(1,0,0,28),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,Text="",ZIndex=5,Parent=hue})
	local function setHue(pos) self._h=math.clamp((pos.X-hue.AbsolutePosition.X)/math.max(1,hue.AbsoluteSize.X),0,1); self:_setColour(Color3.fromHSV(self._h,self._s,self._v)) end
	hueHit.InputBegan:Connect(function(i) if i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch then return end; setHue(i.Position); w.Input:CapturePointer(self,i,function(move) setHue(move.Position) end,function() end) end)

	self._hexBox=Create.New("TextBox",{Size=UDim2.new(0.36,-5,0,30),Position=UDim2.fromOffset(8,150),BackgroundTransparency=0,BorderSizePixel=0,ClearTextOnFocus=false,Text=Util.toHex(c),Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=self._hexBox}); w:_bind(self._hexBox,{BackgroundColor3="ControlInset",TextColor3="Text"})
	local boxes={}; self._rgbBoxes=boxes; for i in {1,2,3} do local box=Create.New("TextBox",{Size=UDim2.new(0.213,-4,0,30),Position=UDim2.new(0.36+(i-1)*0.213,4,0,150),BackgroundTransparency=0,BorderSizePixel=0,ClearTextOnFocus=false,Text=tostring(math.round(({c.R,c.G,c.B})[i]*255)),Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=box}); w:_bind(box,{BackgroundColor3="ControlInset",TextColor3="Text"}); boxes[i]=box end
	local function commitBoxes() local r=math.clamp(tonumber(boxes[1].Text) or 0,0,255); local g=math.clamp(tonumber(boxes[2].Text) or 0,0,255); local b=math.clamp(tonumber(boxes[3].Text) or 0,0,255); self:_setColour(Color3.fromRGB(r,g,b)) end
	for _,box in boxes do box.FocusLost:Connect(commitBoxes) end
	self._hexBox.FocusLost:Connect(function() local raw=string.gsub(self._hexBox.Text,"#",""); local ok,new=pcall(Color3.fromHex,raw); if ok then self:_setColour(new) else self:_syncPopup(self:_colour(self:GetValue())) end end)

	local nextY=188
	if self.Alpha then
		local alphaLabel=Create.New("TextLabel",{Size=UDim2.new(0.55,0,0,28),Position=UDim2.fromOffset(8,nextY),BackgroundTransparency=1,Text="Alpha",Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,Parent=frame}); w:_bind(alphaLabel,{TextColor3="TextSecondary"})
		self._alphaBox=Create.New("TextBox",{Size=UDim2.new(0.35,-8,0,28),Position=UDim2.new(0.65,0,0,nextY),BackgroundTransparency=0,BorderSizePixel=0,ClearTextOnFocus=false,Text=tostring(math.round(self:GetAlpha()*100)).."%",Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=self._alphaBox}); w:_bind(self._alphaBox,{BackgroundColor3="ControlInset",TextColor3="Text"}); self._alphaBox.FocusLost:Connect(function() local n=tonumber(string.gsub(self._alphaBox.Text,"%%","")); if n then self:SetAlpha(math.clamp(n/100,0,1)) else self:_syncPopup(self:_colour(self:GetValue())) end end); nextY+=36
	end
	if #self.Presets>0 then local row=Create.New("Frame",{Size=UDim2.new(1,-16,0,28),Position=UDim2.fromOffset(8,nextY),BackgroundTransparency=1,Parent=frame}); Create.List(6,Enum.FillDirection.Horizontal).Parent=row; for _,p in self.Presets do if typeof(p)=="Color3" then local b=Create.New("TextButton",{Size=UDim2.fromOffset(26,26),BackgroundColor3=p,Text="",BorderSizePixel=0,Parent=row}); Create.New("UICorner",{CornerRadius=UDim.new(0,6),Parent=b}); b.MouseButton1Click:Connect(function() self:_setColour(p) end) end end end
	self:_syncPopup(c)
end
function ColorPicker:_clearPopupRefs() self._sv=nil; self._hue=nil; self._svCursor=nil; self._hueCursor=nil; self._hexBox=nil; self._rgbBoxes=nil; self._alphaBox=nil end
function ColorPicker:_setColour(c) if self.Alpha then local v=table.clone(self:GetValue() or {}); v.Color=c; v.Alpha=v.Alpha or 1; self:SetValue(v) else self:SetValue(c) end end
function ColorPicker:Open()
	if self._popup then return self end; local height=if self.Alpha then 278 else 242; if #self.Presets>0 then height+=34 end; local h
	if self._window.Device.Layout=="Drawer" then h=Sheet.open(self._window,height,{OnDismiss=function() self._popup=nil; self:_clearPopupRefs(); self._window.Input:CancelCapture(self) end}) else h=Popover.open(self._window,self._button,Vector2.new(266,height),{OnDismiss=function() self._popup=nil; self:_clearPopupRefs(); self._window.Input:CancelCapture(self) end}) end
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
local Dropdown=setmetatable({}, {__index=Base}); Dropdown.__index=Dropdown
local function normalize(options) local out={}; for _,o in options or {} do if type(o)=="table" and o.Value~=nil then table.insert(out,{Value=o.Value,Label=tostring(o.Label or o.Value),Icon=o.Icon}) else table.insert(out,{Value=o,Label=tostring(o)}) end end; return out end
local function contains(list,value) for _,v in list do if v==value then return true end end; return false end
function Dropdown.new(section,options)
	local self=setmetatable({},Dropdown); self.Multi=options.Multi==true; self.Searchable=if options.Searchable==nil then #(options.Options or {})>8 else options.Searchable; self.AllowNone=options.AllowNone==true; self.Max=options.Max; self.Placeholder=options.Placeholder or "Select..."; self._options=normalize(options.Options or {}); self._popup=nil; local default=options.Default; if self.Multi and default==nil then default={} end; Base.init(self,section,"Dropdown",options,{Stateful=true,Default=default}); return Base.finish(self)
end
function Dropdown:_mountValue(host)
	local w=self._window; local t=w.Tokens
	self._button=Create.New("TextButton",{Size=UDim2.new(1,0,0,t:Get("FieldHeight")),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BorderSizePixel=0,AutoButtonColor=false,Text="",Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("FieldRadius")),Parent=self._button}); self._stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.5,Parent=self._button}); w:_bind(self._stroke,{Color="BorderSubtle"}); w:_bind(self._button,{BackgroundColor3="ControlInset"})
	self._valueLabel=Create.New("TextLabel",{Size=UDim2.new(1,-32,1,0),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=t:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Text="",Parent=self._button}); w:_bind(self._valueLabel,{TextColor3="Text"})
	self._arrow=Create.New("TextLabel",{Size=UDim2.fromOffset(24,24),Position=UDim2.new(1,-5,0.5,0),AnchorPoint=Vector2.new(1,0.5),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=15,Text="⌄",Parent=self._button}); w:_bind(self._arrow,{TextColor3="TextTertiary"})
	self._janitor:Add(self._button.MouseEnter:Connect(function() if not self._popup then self._button.BackgroundColor3=w.Theme:Get("SurfaceHover") end end)); self._janitor:Add(self._button.MouseLeave:Connect(function() if not self._popup then self._button.BackgroundColor3=w.Theme:Get("ControlInset") end end)); self._janitor:Add(self._button.MouseButton1Click:Connect(function() if not self:IsDisabled() then if self._popup then self:Close() else self:Open() end end end))
end
function Dropdown:_labelFor(value) for _,o in self._options do if o.Value==value then return o.Label end end; return tostring(value) end
function Dropdown:_display(value) if self.Multi then if type(value)~="table" or #value==0 then return self.Placeholder end; local labels={}; for _,v in value do table.insert(labels,self:_labelFor(v)) end; if #labels>3 then return `{#labels} selected` end; return table.concat(labels,", ") end; if value==nil then return self.Placeholder end; return self:_labelFor(value) end
function Dropdown:_render(v) if self._valueLabel then local empty=v==nil or (type(v)=="table" and #v==0); self._valueLabel.Text=self:_display(v); self._valueLabel.TextColor3=self._window.Theme:Get(empty and "TextTertiary" or "Text") end end
function Dropdown:_select(value) if self.Multi then local current=table.clone(self:GetValue() or {}); local p=table.find(current,value); if p then table.remove(current,p) else if self.Max and #current>=self.Max then return end; table.insert(current,value) end; self:SetValue(current); self:_rebuildPopup() else self:SetValue(value); self:Close() end end
function Dropdown:_buildPopup(frame)
	local w=self._window; local t=w.Tokens; frame.ClipsDescendants=true; local y=10
	if self.Searchable then self._search=Create.New("TextBox",{Size=UDim2.new(1,-20,0,34),Position=UDim2.fromOffset(10,10),BackgroundTransparency=0,BorderSizePixel=0,ClearTextOnFocus=false,PlaceholderText="Search...",Text="",Font=w.Fonts.Regular,TextSize=t:Get("FontBody"),Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("FieldRadius")),Parent=self._search}); local s=Create.New("UIStroke",{Thickness=1,Transparency=0.25,Parent=self._search}); w:_bind(s,{Color="BorderSubtle"}); w:_bind(self._search,{BackgroundColor3="ControlInset",TextColor3="Text",PlaceholderColor3="TextTertiary"}); y=52; self._popupSearchConn=self._search:GetPropertyChangedSignal("Text"):Connect(function() self:_rebuildPopup() end) end
	self._list=Scroller.new(w,{Size=UDim2.new(1,-12,1,-y-6),Position=UDim2.fromOffset(6,y),Parent=frame}); Create.New("UIPadding",{PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,2),PaddingLeft=UDim.new(0,3),PaddingRight=UDim.new(0,3),Parent=self._list}); Create.List(3).Parent=self._list; self:_rebuildPopup()
end
function Dropdown:_rebuildPopup()
	if not self._list then return end; for _,child in self._list:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	local query=(self._search and string.lower(self._search.Text)) or ""; local selected=self:GetValue(); local w=self._window
	for _,o in self._options do if query=="" or string.find(string.lower(o.Label),query,1,true) then
		local isSelected=if self.Multi then contains(selected or {},o.Value) else selected==o.Value
		local b=Create.New("TextButton",{Size=UDim2.new(1,0,0,34),BackgroundTransparency=if isSelected then 0 else 1,BorderSizePixel=0,AutoButtonColor=false,Text="",Parent=self._list}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("FieldRadius")),Parent=b}); w:_bind(b,{BackgroundColor3="AccentSoft"})
		local mark=Create.New("TextLabel",{Size=UDim2.fromOffset(24,34),Position=UDim2.fromOffset(4,0),BackgroundTransparency=1,Font=w.Fonts.Bold,TextSize=13,Text=if isSelected then "✓" else "",Parent=b}); w:_bind(mark,{TextColor3="Accent"})
		local label=Create.New("TextLabel",{Size=UDim2.new(1,-34,1,0),Position=UDim2.fromOffset(30,0),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Text=o.Label,Parent=b}); w:_bind(label,{TextColor3=if isSelected then "Text" else "TextSecondary"}); b.MouseEnter:Connect(function() if not isSelected then b.BackgroundTransparency=0; b.BackgroundColor3=w.Theme:Get("SurfaceHover") end end); b.MouseLeave:Connect(function() b.BackgroundTransparency=if isSelected then 0 else 1 end); b.MouseButton1Click:Connect(function() self:_select(o.Value) end)
	end end
end
function Dropdown:Open()
	if self._popup then return self end; local size=Vector2.new(math.max(230,self._button.AbsoluteSize.X),math.min(340,90+#self._options*36)); local handle
	local function dismissed() self._popup=nil; if self._arrow then self._arrow.Text="⌄"; self._button.BackgroundColor3=self._window.Theme:Get("ControlInset"); self._stroke.Color=self._window.Theme:Get("BorderSubtle") end end
	if self._window.Device.Layout=="Drawer" then handle=Sheet.open(self._window,math.min(440,130+#self._options*36),{OnDismiss=dismissed}) else handle=Popover.open(self._window,self._button,size,{OnDismiss=dismissed}) end
	self._popup=handle; self:_buildPopup(handle.Frame); self._arrow.Text="⌃"; self._button.BackgroundColor3=self._window.Theme:Get("SurfaceHover"); self._stroke.Color=self._window.Theme:Get("AccentBorder"); return self
end
function Dropdown:Close() if self._popup then local h=self._popup; self._popup=nil; if self._popupSearchConn then self._popupSearchConn:Disconnect(); self._popupSearchConn=nil end; self._search=nil; self._list=nil; h:Dismiss() end; if self._arrow then self._arrow.Text="⌄" end; return self end
function Dropdown:SetOptions(list) self._options=normalize(list or {}); local current=self:GetValue(); if self.Multi then local kept={}; for _,v in current or {} do for _,o in self._options do if o.Value==v then table.insert(kept,v); break end end end; self:SetValue(kept,true) else local exists=false; for _,o in self._options do if o.Value==current then exists=true break end end; if not exists then self:SetValue(if self.AllowNone then nil else (self._options[1] and self._options[1].Value or nil),true) end end; self:_rebuildPopup(); self:_render(self:GetValue()); return self end
function Dropdown:Refresh(list) if list~=nil then return self:SetOptions(list) end; self:_rebuildPopup(); return self end
function Dropdown:AddOption(o) local n=normalize({o})[1]; if n then table.insert(self._options,n) end; self:_rebuildPopup(); return self end
function Dropdown:RemoveOption(value) for i=#self._options,1,-1 do if self._options[i].Value==value then table.remove(self._options,i) end end; return self:SetOptions(self._options) end
function Dropdown:Destroy() self:Close(); Base.Destroy(self) end
function Dropdown:_applyValueTokens() if self._button then self._button.Size=UDim2.new(1,0,0,self._window.Tokens:Get("FieldHeight")); self._valueLabel.TextSize=self._window.Tokens:Get("FontBody") end end
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
	local self=setmetatable({},Keybind); self.Mode=options.Mode or "Toggle"; self._actionCallback=options.Callback; local baseOptions=table.clone(options); baseOptions.Callback=nil; if section._window.Device.Class=="Phone" and baseOptions.Visible==nil then baseOptions.Visible=false end; self.AllowedModes=options.AllowedModes or {"Toggle","Hold","Always"}; if not table.find(self.AllowedModes,self.Mode) then error(`[BobloUI] keybind mode "{self.Mode}" is not allowed.`,3) end; self.Blacklist=options.Blacklist or {}; self._binding=nil; self._capturing=false; local d=options.Default; local stored={Key=keyName(d or Enum.KeyCode.E),Mode=self.Mode}; Base.init(self,section,"Keybind",baseOptions,{Stateful=true,Default=stored}); return Base.finish(self)
end
function Keybind:_mountValue(host)
	local w=self._window; local t=w.Tokens
	self._button=Create.New("TextButton",{Size=UDim2.new(1,0,0,t:Get("FieldHeight")),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BorderSizePixel=0,AutoButtonColor=false,Text="",Font=w.Fonts.Medium,TextSize=t:Get("FontSmall"),Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("FieldRadius")),Parent=self._button}); self._stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.5,Parent=self._button}); w:_bind(self._stroke,{Color="BorderSubtle"}); w:_bind(self._button,{BackgroundColor3="ControlInset",TextColor3="TextSecondary"}); self._janitor:Add(self._button.MouseEnter:Connect(function() self._button.BackgroundColor3=w.Theme:Get("SurfaceHover") end)); self._janitor:Add(self._button.MouseLeave:Connect(function() if not self._capturing then self._button.BackgroundColor3=w.Theme:Get("ControlInset") end end)); self._janitor:Add(self._button.MouseButton1Click:Connect(function() if not self:IsDisabled() then self:Capture() end end)); self:_rebind()
end
function Keybind:_render(v) if type(v)=="table" then self.Mode=v.Mode or self.Mode end; if self._button then self._button.Text=if self._capturing then "Press a key…" else `{keyName(v)}  ·  {self.Mode}`; self._button.BackgroundColor3=self._window.Theme:Get(self._capturing and "AccentSoft" or "ControlInset"); self._stroke.Color=self._window.Theme:Get(self._capturing and "AccentBorder" or "BorderSubtle"); self:_rebind() end end
function Keybind:_rebind() if self._binding then self._binding:Destroy(); self._binding=nil end; local v=self:GetValue(); if not self._mounted or type(v)~="table" then return end; local key=enumKey(v.Key); if not key then return end; self._binding=self._window.Input:BindKey(self.Id or tostring(self),key,v.Mode or self.Mode,function(active) if self._actionCallback then local ok,err=xpcall(self._actionCallback,debug.traceback,active); if not ok then warn(err) end end end); self._janitor:Add(self._binding,"Destroy","keybinding") end
function Keybind:Capture() if self._capturing then return self end; self._capturing=true; self:_render(self:GetValue()); self._janitor:Add(self._window.Input:CaptureNextKey(function(key) self._capturing=false; if table.find(self.Blacklist,key) then self:_render(self:GetValue()); return end; local v=table.clone(self:GetValue() or {}); v.Key=key.Name; v.Mode=self.Mode; self:SetValue(v) end),nil,"capture"); return self end
function Keybind:Cancel() self._capturing=false; self._janitor:Remove("capture"); self:_render(self:GetValue()); return self end
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
function Status.new(section,options) local self=setmetatable({},Status); self.Status=options.Status or "Neutral"; self.Pulse=options.Pulse==true; Base.init(self,section,"Status",options,{Stateful=options.Id~=nil,Default=options.Value,Persist=false}); if not options.Id then self._value=options.Value end; return Base.finish(self) end
function Status:_mountValue(host) local w=self._window; self._dot=Create.New("Frame",{Size=UDim2.fromOffset(8,8),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BorderSizePixel=0,Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._dot}); w:_bind(self._dot,{BackgroundColor3=function(palette) return palette[TOKENS[self.Status] or "TextSecondary"] end}); self._valueLabel=Create.New("TextLabel",{Size=UDim2.new(1,-14,1,0),Position=UDim2.fromOffset(14,0),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Right,Text="",Parent=host}); w:_bind(self._valueLabel,{TextColor3="TextSecondary"}); self:SetStatus(self.Status); if self.Pulse and w.Motion.Enabled then local tw=w.Motion:Tween(self._dot,TweenInfo.new(0.8,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{BackgroundTransparency=0.65}); if tw then self._janitor:Add(tw) end end end
function Status:_render(v) if self._valueLabel then self._valueLabel.Text=tostring(v or "") end end
function Status:SetStatus(s) self.Status=s; if self._dot then self._dot.BackgroundColor3=self._window.Theme:Get(TOKENS[s] or "TextSecondary") end; return self end
return Status

end

__modules["controls/TextField"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Base=__require("controls/Base")
local TextField=setmetatable({}, {__index=Base}); TextField.__index=TextField
function TextField.new(section,options)
	local self=setmetatable({},TextField); self.Placeholder=options.Placeholder or ""; self.Numeric=options.Numeric==true; self.MaxLength=options.MaxLength; self.Multiline=options.Multiline==true; self.ClearOnFocus=options.ClearOnFocus==true; self.Validate=options.Validate; self.CommitOn=options.CommitOn or "FocusLost"; self._error=nil
	Base.init(self,section,"Input",options,{Stateful=true,Default=options.Default or (self.Numeric and 0 or "")}); return Base.finish(self)
end
function TextField:_mountValue(host)
	local w=self._window; local t=w.Tokens
	self._box=Create.New("TextBox",{Size=UDim2.new(1,0,0,t:Get("FieldHeight")),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=0,BorderSizePixel=0,ClearTextOnFocus=self.ClearOnFocus,MultiLine=self.Multiline,PlaceholderText=self.Placeholder,Text=tostring(self:GetValue() or ""),Font=w.Fonts.Regular,TextSize=t:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(0,t:Get("FieldRadius")),Parent=self._box}); Create.New("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),Parent=self._box}); self._stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.5,Parent=self._box}); w:_bind(self._stroke,{Color="BorderSubtle"}); w:_bind(self._box,{BackgroundColor3="ControlInset",TextColor3="Text",PlaceholderColor3="TextTertiary"})
	if self.CommitOn=="Change" then self._janitor:Add(self._box:GetPropertyChangedSignal("Text"):Connect(function() self:_commit() end)) end
	self._janitor:Add(self._box.Focused:Connect(function() self._stroke.Color=w.Theme:Get("AccentBorder"); self._stroke.Transparency=0; if w.Device.Layout=="Drawer" then task.defer(function() self:Reveal() end) end end))
	self._janitor:Add(self._box.FocusLost:Connect(function(enter) self._stroke.Color=w.Theme:Get("BorderSubtle"); self._stroke.Transparency=0.5; if self.CommitOn=="FocusLost" or (self.CommitOn=="Enter" and enter) then self:_commit() end end))
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
	self._button=Create.New("TextButton",{Size=UDim2.fromOffset(36,20),Position=UDim2.new(1,0,0.5,0),AnchorPoint=Vector2.new(1,0.5),BorderSizePixel=0,AutoButtonColor=false,Text="",Parent=host}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._button})
	self._stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.5,Parent=self._button}); w:_bind(self._stroke,{Color="BorderStrong"}); w:_bind(self._button,{BackgroundColor3="SurfaceActive"})
	self._knob=Create.New("Frame",{Size=UDim2.fromOffset(14,14),Position=UDim2.new(0,3,0.5,0),AnchorPoint=Vector2.new(0,0.5),BorderSizePixel=0,Parent=self._button}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=self._knob}); w:_bind(self._knob,{BackgroundColor3="TextTertiary"})
	self._janitor:Add(self._button.MouseButton1Click:Connect(function() if not self:IsDisabled() then self:Flip() end end))
end
function Toggle:_render(value)
	if not self._button then return end; local on=value==true; local w=self._window
	self._button.BackgroundColor3=w.Theme:Get(if on then "Accent" else "SurfaceActive"); self._stroke.Color=w.Theme:Get(if on then "AccentBorder" else "BorderStrong"); self._stroke.Transparency=if on then 0.35 else 0.5
	self._knob.BackgroundColor3=w.Theme:Get(if on then "AccentText" else "TextTertiary")
	w.Motion:Tween(self._knob,"Fast",{Position=if on then UDim2.new(1,-17,0.5,0) else UDim2.new(0,3,0.5,0)})
end
function Toggle:Flip() return self:SetValue(not self:GetValue()) end
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

local BobloUI={}
BobloUI.Version="0.9.2-beta.1"; BobloUI.ApiLevel=9; BobloUI.Env=Env; BobloUI.Icon=Icon
local REGISTRY_KEY="__BobloUI"
local function globalRegistry()
	local existing=Env.Globals[REGISTRY_KEY]; if type(existing)=="table" and type(existing.Instances)=="table" then return existing end
	local created={Instances={}}; Env.Globals[REGISTRY_KEY]=created; return created
end
local function evict(id)
	local r=globalRegistry(); local previous=r.Instances[id]; if not previous then return end; r.Instances[id]=nil
	local ok,err=pcall(function() previous:Unload() end); if not ok then warn(`[BobloUI] previous window "{id}" failed to unload ({err}); sweeping GUIs.`); Layer.SweepOrphans(id) end
end
local WINDOW_OPTIONS={"Id","Singleton","Title","Subtitle","Theme","Accent","Density","Scale","Size","MinSize","Locale","ToggleKey","ConfigFolder","AutoLoad","ReducedMotion","OnUnload"}
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
	local theme=Theme.new({Palettes={Dark=Dark,Light=Light},Accent=options.Accent}); janitor:Add(theme); theme:Set(options.Theme or "Dark")
	local input=Input.new(); janitor:Add(input)
	local layers=Layer.new(id,input); janitor:Add(layers)
	local state=Store.new(); janitor:Add(state)
	local registry=Registry.new(); janitor:Add(registry)
	local motion=Motion.new(); janitor:Add(motion); if options.ReducedMotion then motion:SetEnabled(false) end
	local locale=Locale.new(options.Locale or "en"); janitor:Add(locale)
	locale:Register("en",{["search.placeholder"]="Search controls or type > for commands",["common.cancel"]="Cancel",["common.confirm"]="Confirm"})
	locale:Register("ru",{["search.placeholder"]="Поиск функций или > для команд",["common.cancel"]="Отмена",["common.confirm"]="Подтвердить"})

	local window=Window.new({Id=id,Janitor=janitor,Theme=theme,Tokens=tokens,Device=device,Layers=layers,Fonts=Tokens.Fonts,State=state,Registry=registry,Input=input,Motion=motion,Locale=locale},options)
	window.Version=BobloUI.Version; window.ApiLevel=BobloUI.ApiLevel; window.Singleton=singleton
	window.State=state; window.Registry=registry; window.Input=input; window.Motion=motion; window.Locale=locale

	local favorites=Favorites.new(registry); janitor:Add(favorites); window.Favorites=favorites
	local search=Search.new(window); window.Search=search
	local commands=Commands.new(window); window.Commands=commands
	local notify=Notify.new(window); janitor:Add(notify); window.Notify=notify
	local dialog=Dialog.new(window); janitor:Add(dialog); window.Dialog=dialog
	local config=nil; if options.ConfigFolder then config=Config.new(window,options.ConfigFolder); janitor:Add(config); window.Config=config end
	local interactions=Interactions.new(window); janitor:Add(interactions); window.Interactions=interactions
	local palette=Palette.new(window,search,commands); janitor:Add(palette); window.Palette=palette

	local unloaded=false
	function window:SetTheme(name) theme:Set(name); return self end
	function window:SetAccent(colour) theme:SetAccent(colour); return self end
	function window:SetDensity(density) tokens:SetDensity(density); return self end
	function window:SetScale(scale)
		local root=self:GetInstance(); local uiScale=root:FindFirstChildOfClass("UIScale"); if not uiScale then uiScale=Instance.new("UIScale"); uiScale.Parent=root end; uiScale.Scale=math.clamp(scale,0.5,2); return self
	end
	function window:SetLocale(name)
		locale:Set(name); for _,tab in self._tabs do if tab._refreshLocale then tab:_refreshLocale() end end; for _,entry in registry:Entries() do if entry.Handle and entry.Handle._refreshText then entry.Handle:_refreshText() end end; search:Reindex(); return self
	end
	function window:SetReducedMotion(reduced) motion:SetEnabled(not reduced); return self end
	function window:OpenSearch(query) palette:Open(query or "","search"); return self end
	function window:OpenCommands() palette:Open("> ","commands"); return self end
	function window:Build(schema) return Build.Run(self,schema) end
	function window:OnUnload(fn) return self.Unloading:Connect(fn) end
	function window:IsUnloaded() return unloaded end

	commands:Register({Id="ui.toggle",Title="Toggle UI",Keywords={"show","hide"},Callback=function() window:Toggle() end})
	commands:Register({Id="ui.theme",Title="Toggle light/dark theme",Keywords={"theme","dark","light"},Callback=function() window:SetTheme(theme:Current()=="Dark" and "Light" or "Dark") end})
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
	if self._nextCapture and not processed then
		local cb=self._nextCapture; self._nextCapture=nil
		if i.KeyCode~=Enum.KeyCode.Unknown then cb(i.KeyCode) elseif i.UserInputType~=Enum.UserInputType.MouseMovement then cb(i.UserInputType) end
		return
	end
	if not processed then
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
function Input:CaptureNextKey(callback) self._nextCapture=callback; return function() if self._nextCapture==callback then self._nextCapture=nil end end end
function Input:BindKey(id,key,mode,callback)
	mode=mode or "Toggle"; local handle={Id=id,Key=key,Mode=mode,Callback=callback,Enabled=true,Active=mode=="Always",_toggle=false,_input=self}
	function handle:_press() if self.Mode=="Hold" then self.Active=true; self.Callback(true) elseif self.Mode=="Toggle" then self._toggle=not self._toggle; self.Active=self._toggle; self.Callback(self.Active) elseif self.Mode=="Always" then self.Active=true; self.Callback(true) end end
	function handle:_release() if self.Mode=="Hold" and self.Active then self.Active=false; self.Callback(false) end end
	function handle:Destroy() local list=self._input._keybinds[self.Key]; if list then local p=table.find(list,self); if p then table.remove(list,p) end end end
	local list=self._keybinds[key] or {}; self._keybinds[key]=list; table.insert(list,handle); return handle
end
function Input:Destroy() self:CancelCapture(); self._nextCapture=nil; for _,list in self._keybinds do for _,h in list do h.Enabled=false end end; self._keybinds={}; self._janitor:Destroy(); self.Began:Destroy(); self.Changed:Destroy(); self.Ended:Destroy() end
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

	-- Semantic accent derivatives stay correct even after SetAccent().
	local mixBase = palette.Surface or palette.Background
	palette.AccentSoft = palette.Accent:Lerp(mixBase, 0.90)
	palette.AccentMuted = palette.Accent:Lerp(mixBase, 0.72)
	palette.AccentBorder = palette.Accent:Lerp(palette.Border or mixBase, 0.48)

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
		ControlHeight = 44,
		ControlPadding = 12,
		ControlRadius = 8,
		FieldHeight = 32,
		FieldRadius = 8,
		RowGap = 0,
		SectionGap = 16,
		SectionPadding = 10,
		PagePadding = 22,
		HeaderHeight = 54,
		SidebarWidth = 176,
		RailWidth = 54,
		NavItemHeight = 36,
		FontCaption = 10,
		FontSmall = 11,
		FontBody = 13,
		FontTitle = 14,
		FontHeading = 18,
		FontDisplay = 21,
		IconSm = 14,
		IconMd = 18,
		CornerSm = 7,
		CornerMd = 10,
		CornerLg = 14,
		Stroke = 1,
		SliderTrack = 3,
		SliderKnob = 12,
	},
	Compact = {
		ControlHeight = 38,
		ControlPadding = 10,
		ControlRadius = 9,
		FieldHeight = 30,
		FieldRadius = 7,
		RowGap = 0,
		SectionGap = 10,
		SectionPadding = 9,
		PagePadding = 18,
		HeaderHeight = 50,
		SidebarWidth = 164,
		RailWidth = 50,
		NavItemHeight = 34,
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
		SliderKnob = 11,
	},
	Touch = {
		ControlHeight = 48,
		ControlPadding = 13,
		ControlRadius = 11,
		FieldHeight = 38,
		FieldRadius = 9,
		RowGap = 0,
		SectionGap = 15,
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
-- Small built-in glyph registry. Custom image assets can be registered at runtime.
local Create=__require("runtime/Create")
local Icon={Registry={}}
Icon.Glyphs={search="⌕",settings="⚙",close="×",chevron_down="⌄",chevron_right="›",check="✓",plus="+",minus="−",star="★",info="i",warning="!",command="⌘",copy="⧉",trash="×",palette="◐",menu="≡"}
function Icon.Register(name,value) Icon.Registry[name]=value end
function Icon.new(window,name,props)
	props=props or {}; local custom=Icon.Registry[name]
	if type(custom)=="string" and string.find(custom,"rbxasset") then
		props.BackgroundTransparency=1; props.Image=custom; local image=Create.New("ImageLabel",props); window:_bind(image,{ImageColor3="TextSecondary"}); return image
	end
	props.BackgroundTransparency=1; props.Text=(type(custom)=="string" and custom) or Icon.Glyphs[name] or tostring(name or "•"); props.Font=window.Fonts.Medium; props.TextSize=props.TextSize or window.Tokens:Get("FontTitle")
	local label=Create.New("TextLabel",props); window:_bind(label,{TextColor3="TextSecondary"}); return label
end
return Icon

end

__modules["primitives/Popover"] = function()
--!nonstrict
local Surface=__require("primitives/Surface")
local Popover={}
function Popover.open(window,anchor,size,options)
	options=options or {}; local handle=window.Layers:Push({Scrim=false,Modal=false,OnDismiss=options.OnDismiss})
	local frame=Surface.new(window,{Name="Popover",Size=UDim2.fromOffset(size.X,size.Y),BorderSizePixel=0,Parent=handle.Container},{Token="SurfaceRaised",StrokeToken="BorderStrong",StrokeTransparency=0.16,Corner=window.Tokens:Get("CornerMd")}); frame.ZIndex=handle.Depth*10+2
	local function place()
		if not anchor or not anchor.Parent then handle:Dismiss(); return end
		local pos,asz=anchor.AbsolutePosition,anchor.AbsoluteSize; local safePos,safeSize=window.Device:SafeArea(); local minX=safePos.X+8; local maxX=math.max(minX,safePos.X+safeSize.X-size.X-8); local minY=safePos.Y+8; local maxY=safePos.Y+safeSize.Y-size.Y-8
		local x=math.clamp(pos.X,minX,maxX); local below=pos.Y+asz.Y+7; local y=if below+size.Y<=safePos.Y+safeSize.Y-8 then below else math.max(minY,pos.Y-size.Y-7); frame.Position=UDim2.fromOffset(x,math.min(y,maxY))
	end
	place(); local c1=anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(place); local c2=anchor:GetPropertyChangedSignal("AbsoluteSize"):Connect(place); local c3=window.Device.Changed:Connect(place)
	local oldDismiss=handle.Dismiss; function handle:Dismiss() if self._dismissed then return end; c1:Disconnect(); c2:Disconnect(); c3:Disconnect(); oldDismiss(self) end
	handle.Frame=frame; return handle
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
	options=options or {}; local handle=window.Layers:Push({Scrim=true,ScrimTransparency=0.52,Modal=false,OnDismiss=options.OnDismiss})
	local function resolvedHeight() return math.min(height or math.floor(window.Device.Viewport.Y*0.6),math.floor(window.Device.Viewport.Y*0.8)) end
	local frame=Surface.new(window,{Name="Sheet",Size=UDim2.new(1,-12,0,resolvedHeight()),Position=UDim2.new(0,6,1,-6),AnchorPoint=Vector2.new(0,1),BorderSizePixel=0,Parent=handle.Container},{Token="SurfaceRaised",StrokeToken="BorderStrong",StrokeTransparency=0.18,Corner=window.Tokens:Get("CornerLg")}); frame.ZIndex=handle.Depth*10+2
	local grab=Create.New("Frame",{Size=UDim2.fromOffset(36,4),Position=UDim2.new(0.5,0,0,7),AnchorPoint=Vector2.new(0.5,0),BorderSizePixel=0,Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=grab}); window:_bind(grab,{BackgroundColor3="BorderStrong"})
	local conn=window.Device.Changed:Connect(function() if frame.Parent then frame.Size=UDim2.new(1,-12,0,resolvedHeight()) end end)
	local oldDismiss=handle.Dismiss; function handle:Dismiss() if self._dismissed then return end; conn:Disconnect(); oldDismiss(self) end
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

function Env.SetClipboard(text: string): boolean
	if not setclipboard then
		return false
	end
	return (pcall(setclipboard, text))
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
return {["Button"]={["Method"]="AddButton",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Text"]="string?",["Variant"]="string?",["Confirm"]="string?"},["Required"]={"Title"},["Stateful"]=false},["Toggle"]={["Method"]="AddToggle",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Default"]="boolean?"},["Required"]={"Title"},["Stateful"]=true},["Slider"]={["Method"]="AddSlider",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Min"]="number",["Max"]="number",["Default"]="number?",["Step"]="number?",["Precision"]="number?",["Suffix"]="string?",["Format"]="function?"},["Required"]={"Title","Min","Max"},["Stateful"]=true},["Dropdown"]={["Method"]="AddDropdown",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Options"]="table",["Default"]="any?",["Multi"]="boolean?",["Searchable"]="boolean?",["AllowNone"]="boolean?",["Max"]="number?",["Placeholder"]="string?"},["Required"]={"Title","Options"},["Stateful"]=true},["Input"]={["Method"]="AddInput",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Default"]="string|number?",["Placeholder"]="string?",["Numeric"]="boolean?",["MaxLength"]="number?",["Multiline"]="boolean?",["ClearOnFocus"]="boolean?",["Validate"]="function?",["CommitOn"]="string?"},["Required"]={"Title"},["Stateful"]=true},["Keybind"]={["Method"]="AddKeybind",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Default"]="EnumItem?",["Mode"]="string?",["AllowedModes"]="table?",["Blacklist"]="table?"},["Required"]={"Title"},["Stateful"]=true},["ColorPicker"]={["Method"]="AddColorPicker",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Default"]="Color3?",["Alpha"]="boolean?",["DefaultAlpha"]="number?",["Presets"]="table?"},["Required"]={"Title"},["Stateful"]=true},["Paragraph"]={["Method"]="AddParagraph",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Content"]="string?",["Variant"]="string?"},["Required"]={},["Stateful"]=false},["Divider"]={["Method"]="AddDivider",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?"},["Required"]={},["Stateful"]=false},["Status"]={["Method"]="AddStatus",["Options"]={["Id"]="string?",["Title"]="string?",["Description"]="string?",["Keywords"]="table?",["Badge"]="string?",["Disabled"]="boolean|string?",["Visible"]="boolean?",["VisibleWhen"]="table|function?",["EnabledWhen"]="table|function?",["IgnoreConfig"]="boolean?",["Order"]="number?",["Callback"]="function?",["Tooltip"]="string?",["ContextMenu"]="table?",["Value"]="any?",["Status"]="string?",["Pulse"]="boolean?"},["Required"]={"Title"},["Stateful"]=true}}

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

local TAB_KEYS={Id=true,Title=true,Icon=true,Order=true,Badge=true,Sections=true,Controls=true}
local SECTION_KEYS={Id=true,Title=true,Description=true,Collapsible=true,Collapsed=true,Column=true,Controls=true}
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
		local tab=window:AddTab({Id=td.Id,Title=td.Title,Icon=td.Icon,Order=td.Order,Badge=td.Badge}); if tab.Id then handles[tab.Id]=tab end
		for _,cd in td.Controls or {} do createControl(tab,cd) end
		for _,sd in td.Sections or {} do
			local section=tab:AddSection({Id=sd.Id,Title=sd.Title,Description=sd.Description,Collapsible=sd.Collapsible,Collapsed=sd.Collapsed,Column=sd.Column}); if section.Id then handles[section.Id]=section end
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
	if v.__type=="EnumItem" then local enumName=string.match(v.Enum or "","Enum%.(.+)"); local et=enumName and Enum[enumName]; return et and et[v.Name] or v.Name end
	local o={}; for key,val in v do o[key]=deserialize(val) end; return o
end
function Config.new(window,folder)
	local self=setmetatable({Saved=Signal.new("Config.Saved"),Loaded=Signal.new("Config.Loaded"),_window=window,_storage=Storage.new(folder),_folder=folder,_migrations={},_pending={},_orphans={},_ignored={},_autoload=nil},Config)
	self._registryConn=window.Registry.Added:Connect(function(entry) if entry.Id and self._pending[entry.Id]~=nil then local value=self._pending[entry.Id]; self._pending[entry.Id]=nil; self._orphans[entry.Id]=nil; window.State:Set(entry.Id,value,{Source="CONFIG",Silent=false}) end end)
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
	local meta={theme=self._window.Theme:Current(),accent=serialize(self._window.Theme:Get("Accent")),density=self._window.Tokens:GetDensity(),locale=self._window.Locale and self._window.Locale:Get() or "en",favorites=self._window.Favorites and self._window.Favorites:List() or {}}
	local envelope={['$schema']=CURRENT,name=name,library="BobloUI",libraryVersion=self._window.Version,savedAt=os.time(),values=values,meta=meta}; local ok,json=pcall(HttpService.JSONEncode,HttpService,envelope); if not ok then return false,json end
	local wrote=self._storage:Write(self:_file(name),json); if wrote then self.Saved:Fire(name) end; return wrote,wrote and nil or "write failed"
end
function Config:Load(name)
	local raw=self._storage:Read(self:_file(name)); if not raw then return false,"config not found" end; local ok,data=pcall(HttpService.JSONDecode,HttpService,raw); if not ok or type(data)~="table" then return false,"invalid json" end
	local version=tonumber(data['$schema']) or 0; if version<CURRENT then self._storage:Write(self:_file(name)..".bak",raw); while version<CURRENT do local migration=self._migrations[version]; if not migration then break end; local okm,res=xpcall(migration,debug.traceback,data); if not okm then return false,res end; data=res or data; version+=1; data['$schema']=version end end
	self._window.State:Batch(function() for id,rawValue in data.values or {} do local v=deserialize(rawValue); if self._window.Registry:Has(id) then self._window.State:Set(id,v,{Source="CONFIG"}) else self._pending[id]=v; self._orphans[id]=v end end end)
	local meta=data.meta or {}; if meta.theme then pcall(function() self._window:SetTheme(meta.theme) end) end; if meta.accent then pcall(function() self._window:SetAccent(deserialize(meta.accent)) end) end; if meta.density then pcall(function() self._window:SetDensity(meta.density) end) end; if meta.locale and self._window.SetLocale then pcall(function() self._window:SetLocale(meta.locale) end) end; if self._window.Favorites and type(meta.favorites)=="table" then self._window.Favorites:Set(meta.favorites) end
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
function Config:Destroy() if self._registryConn then self._registryConn:Disconnect() end; self.Saved:Destroy(); self.Loaded:Destroy(); self._pending={}; self._orphans={} end
return Config

end

__modules["services/Dialog"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Signal=__require("runtime/Signal")
local Janitor=__require("runtime/Janitor")
local Surface=__require("primitives/Surface")
local Sheet=__require("primitives/Sheet")
local DialogSection=__require("services/DialogSection")
local Dialog={}; Dialog.__index=Dialog
function Dialog.new(window) return setmetatable({_window=window,_open={}},Dialog) end
function Dialog:_surface(height,onDismiss)
	local w=self._window
	if w.Device.Layout=="Drawer" then local h=Sheet.open(w,height,{OnDismiss=onDismiss}); return h,h.Frame end
	local h=w.Layers:Push({Scrim=true,ScrimTransparency=0.45,Modal=true,OnDismiss=onDismiss}); local width=math.min(420,w.Device.Viewport.X-32); local frame=Surface.new(w,{Size=UDim2.fromOffset(width,height),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BorderSizePixel=0,Parent=h.Container},{Token="SurfaceRaised",StrokeToken="BorderStrong",StrokeTransparency=0.15,Corner=w.Tokens:Get("CornerLg")}); frame.ZIndex=h.Depth*10+3; return h,frame
end
function Dialog:_make(options,kind)
	options=options or {}; local w=self._window; local resultSignal=Signal.new("Dialog.Resolved"); local resultHandle={Resolved=resultSignal,_resolved=false,_result=nil}; local height=kind=="Prompt" and 210 or 180; local layerHandle,frame
	local function removeOpen() local p=table.find(self._open,resultHandle); if p then table.remove(self._open,p) end end
	local function dismissed() if not resultHandle._resolved then resultHandle._resolved=true; resultHandle._result=nil; resultSignal:Fire(nil); removeOpen() end end
	layerHandle,frame=self:_surface(height,dismissed); resultHandle._layer=layerHandle
	local title=Create.New("TextLabel",{Size=UDim2.new(1,-32,0,30),Position=UDim2.fromOffset(16,14),BackgroundTransparency=1,Font=w.Fonts.Bold,TextSize=w.Tokens:Get("FontTitle"),TextXAlignment=Enum.TextXAlignment.Left,Text=options.Title or "",Parent=frame}); w:_bind(title,{TextColor3="Text"})
	local content=Create.New("TextLabel",{Size=UDim2.new(1,-32,0,50),Position=UDim2.fromOffset(16,48),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontBody"),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text=options.Content or "",Parent=frame}); w:_bind(content,{TextColor3="TextSecondary"})
	local input=nil; if kind=="Prompt" then input=Create.New("TextBox",{Size=UDim2.new(1,-32,0,34),Position=UDim2.fromOffset(16,106),BackgroundTransparency=0,BorderSizePixel=0,ClearTextOnFocus=false,PlaceholderText=options.Placeholder or "",Text=options.Default or "",Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontBody"),Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=input}); w:_bind(input,{BackgroundColor3="ControlInset",TextColor3="Text",PlaceholderColor3="TextTertiary"}) end
	local function resolve(v) if resultHandle._resolved then return end; resultHandle._resolved=true; resultHandle._result=v; resultSignal:Fire(v); removeOpen(); layerHandle:Dismiss() end
	function resultHandle:Resolve(v) resolve(v) end; function resultHandle:Close() resolve(nil) end; function resultHandle:IsOpen() return not self._resolved and layerHandle:IsOpen() end; function resultHandle:Await() if self._resolved then return self._result end; return self.Resolved:Wait() end; function resultHandle:Destroy() self:Close(); self.Resolved:Destroy() end
	local y=kind=="Prompt" and 156 or 126; local buttons=Create.New("Frame",{Size=UDim2.new(1,-32,0,38),Position=UDim2.fromOffset(16,y),BackgroundTransparency=1,Parent=frame}); Create.List(8,Enum.FillDirection.Horizontal,{HorizontalAlignment=Enum.HorizontalAlignment.Right}).Parent=buttons
	local function add(text,primary,value) local b=Create.New("TextButton",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,1,0),BackgroundTransparency=0,BorderSizePixel=0,Text="  "..text.."  ",Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontBody"),Parent=buttons}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=b}); w:_bind(b,{BackgroundColor3=primary and (options.Danger and "Error" or "Accent") or "Control",TextColor3=primary and "AccentText" or "Text"}); b.MouseButton1Click:Connect(function() resolve(value()) end) end
	if kind=="Alert" then add(options.Button or "OK",true,function() return true end) elseif kind=="Confirm" then add(options.Cancel or "Cancel",false,function() return false end); add(options.Confirm or "Confirm",true,function() return true end) else add(options.Cancel or "Cancel",false,function() return nil end); add(options.Confirm or "OK",true,function() return input.Text end) end
	table.insert(self._open,resultHandle); return resultHandle
end
function Dialog:Alert(o) return self:_make(o,"Alert") end
function Dialog:Confirm(o) return self:_make(o,"Confirm") end
function Dialog:Prompt(o) return self:_make(o,"Prompt") end
function Dialog:Custom(options)
	options=options or {}; local w=self._window; local j=Janitor.new("Dialog.Custom"); local closed=false; local layer,frame
	local function dismiss() if closed then return end; closed=true; j:Destroy() end
	layer,frame=self:_surface(options.Height or 360,dismiss); j:Add(function() if layer:IsOpen() then layer:Dismiss() end end)
	local title=Create.New("TextLabel",{Size=UDim2.new(1,-32,0,30),Position=UDim2.fromOffset(16,12),BackgroundTransparency=1,Font=w.Fonts.Bold,TextSize=w.Tokens:Get("FontTitle"),TextXAlignment=Enum.TextXAlignment.Left,Text=options.Title or "",Parent=frame}); w:_bind(title,{TextColor3="Text"})
	local content=Create.New("ScrollingFrame",{Size=UDim2.new(1,-32,1,-98),Position=UDim2.fromOffset(16,50),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,Parent=frame}); Create.List(w.Tokens:Get("RowGap")).Parent=content; local section=DialogSection.new(w,content,j); if options.Build then options.Build(section) end
	local row=Create.New("Frame",{Size=UDim2.new(1,-32,0,36),Position=UDim2.new(0,16,1,-44),BackgroundTransparency=1,Parent=frame}); Create.List(8,Enum.FillDirection.Horizontal,{HorizontalAlignment=Enum.HorizontalAlignment.Right}).Parent=row
	for _,button in options.Buttons or {{Text="Close"}} do local b=Create.New("TextButton",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,1,0),BackgroundTransparency=0,BorderSizePixel=0,Text="  "..(button.Text or "Close").."  ",Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontBody"),Parent=row}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=b}); w:_bind(b,{BackgroundColor3=button.Primary and "Accent" or "Control",TextColor3=button.Primary and "AccentText" or "Text"}); b.MouseButton1Click:Connect(function() if button.Callback then button.Callback(section) end; if button.Close~=false then layer:Dismiss() end end) end
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
local Interactions={}; Interactions.__index=Interactions
function Interactions.new(window) return setmetatable({_window=window,_tooltip=nil,_menu=nil,_touchInfo=nil},Interactions) end
function Interactions:_hideTooltip() if self._tooltip then self._tooltip:Destroy(); self._tooltip=nil end end
function Interactions:_showTooltip(root,text)
	self:_hideTooltip(); if not root or not root.Parent then return end; local w=self._window
	local label=Create.New("TextLabel",{AutomaticSize=Enum.AutomaticSize.XY,BackgroundTransparency=0,BorderSizePixel=0,Text=tostring(text),TextWrapped=true,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Parent=w.Layers.Overlay,ZIndex=999}); Create.New("UIPadding",{PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),Parent=label}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=label}); w:_bind(label,{BackgroundColor3="Surface",TextColor3="Text"})
	task.defer(function() if not label.Parent then return end; local p=root.AbsolutePosition; local a=root.AbsoluteSize; local safePos,safeSize=w.Device:SafeArea(); local x=math.clamp(p.X,safePos.X+8,math.max(safePos.X+8,safePos.X+safeSize.X-label.AbsoluteSize.X-8)); local y=math.clamp(p.Y+a.Y+6,safePos.Y+8,math.max(safePos.Y+8,safePos.Y+safeSize.Y-label.AbsoluteSize.Y-8)); label.Position=UDim2.fromOffset(x,y) end); self._tooltip=label
end
function Interactions:_showTouchInfo(text)
	if self._touchInfo then self._touchInfo:Dismiss(); self._touchInfo=nil end; local w=self._window
	local h=Sheet.open(w,170,{OnDismiss=function() self._touchInfo=nil end}); self._touchInfo=h
	local label=Create.New("TextLabel",{Size=UDim2.new(1,-32,1,-32),Position=UDim2.fromOffset(16,16),BackgroundTransparency=1,Text=tostring(text),TextWrapped=true,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Parent=h.Frame}); w:_bind(label,{TextColor3="Text"})
end
function Interactions:OpenMenu(anchor,items)
	if self._menu then self._menu:Dismiss(); self._menu=nil end; if #items==0 then return end; local w=self._window
	local h=if w.Device.Layout=="Drawer" then Sheet.open(w,math.min(360,20+#items*38),{OnDismiss=function() self._menu=nil end}) else Popover.open(w,anchor,Vector2.new(220,16+#items*36),{OnDismiss=function() self._menu=nil end}); self._menu=h; local list=Create.New("Frame",{Size=UDim2.new(1,-12,1,-12),Position=UDim2.fromOffset(6,6),BackgroundTransparency=1,Parent=h.Frame}); Create.List(3).Parent=list
	for _,item in items do local b=Create.New("TextButton",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,Text="  "..(item.Text or item.Title or "Action"),Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Parent=list}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=b}); w:_bind(b,{BackgroundColor3="SurfaceHover",TextColor3=item.Danger and "Error" or "Text"}); b.MouseButton1Click:Connect(function() h:Dismiss(); local ok,err=xpcall(item.Callback or function() end,debug.traceback); if not ok then warn(`[BobloUI] context action failed:\n{err}`) end end) end
end
function Interactions:Attach(control,root,tooltip,userMenu)
	local j=Janitor.new("Control.Interactions"); local hoverToken=0; local w=self._window
	if tooltip and w.Device.Class~="Phone" then
		j:Add(root.MouseEnter:Connect(function() hoverToken+=1; local token=hoverToken; j:Add(task.delay(0.5,function() if token==hoverToken and root.Parent then self:_showTooltip(root,tooltip) end end)) end)); j:Add(root.MouseLeave:Connect(function() hoverToken+=1; self:_hideTooltip() end))
	elseif tooltip then
		local info=Create.New("TextButton",{Size=UDim2.fromOffset(20,20),Position=UDim2.new(0.6,-24,0,9),AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,Text="i",Font=w.Fonts.Bold,TextSize=13,ZIndex=3,Parent=root}); w:_bind(info,{TextColor3="TextSecondary"}); j:Add(info.MouseButton1Click:Connect(function() self:_showTouchInfo(tooltip) end))
	end
	local function items() local out={}; for _,x in userMenu or {} do table.insert(out,x) end; if control.Id and w.Favorites then table.insert(out,{Text=w.Favorites:Has(control.Id) and "Remove from Favorites" or "Add to Favorites",Callback=function() w.Favorites:Toggle(control.Id) end}) end; return out end
	j:Add(root.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton2 then self:OpenMenu(root,items())
		elseif input.UserInputType==Enum.UserInputType.Touch then
			local active=true; local start=input.Position; local token=task.delay(0.6,function() if active and root.Parent then self:OpenMenu(root,items()) end end); j:Add(token)
			local conn; conn=input.Changed:Connect(function() if (input.Position-start).Magnitude>12 then active=false end; if input.UserInputState==Enum.UserInputState.End or input.UserInputState==Enum.UserInputState.Cancel then active=false; if conn then conn:Disconnect() end end end); j:Add(conn)
		end
	end)); return j
end
function Interactions:Destroy() self:_hideTooltip(); if self._menu then self._menu:Dismiss() end; if self._touchInfo then self._touchInfo:Dismiss() end end
return Interactions

end

__modules["services/Notify"] = function()
--!nonstrict
local Create=__require("runtime/Create")
local Janitor=__require("runtime/Janitor")
local Notify={}; Notify.__index=Notify
local TOK={Default="Accent",Success="Success",Warning="Warning",Error="Error",Loading="Info"}
function Notify.new(window)
	local self=setmetatable({_window=window,_items={},_queue={},_host=nil,_janitor=Janitor.new("Notify")},Notify)
	self:_ensureHost(); self._janitor:Add(window.Device.Changed:Connect(function() self:_applyLayout() end)); self._janitor:Add(window.Theme.Changed:Connect(function() self:_refreshTheme() end)); return self
end
function Notify:_ensureHost()
	if self._host and self._host.Parent then return end; local w=self._window
	self._host=Create.New("Frame",{Name="Notifications",BackgroundTransparency=1,Parent=w.Layers.Toast})
	self._layout=Create.List(10); self._layout.Parent=self._host; self:_applyLayout()
end
function Notify:_applyLayout()
	if not self._host then return end; local w=self._window; local mobile=w.Device.Layout=="Drawer"
	if mobile then
		self._host.Size=UDim2.new(1,-16,0,math.min(520,w.Device.Viewport.Y-24)); self._host.Position=UDim2.fromOffset(8,w.Device.Insets.Top+8); self._host.AnchorPoint=Vector2.new(0,0); self._layout.VerticalAlignment=Enum.VerticalAlignment.Top
	else
		self._host.Size=UDim2.fromOffset(350,600); self._host.Position=UDim2.new(1,-16,1,-16); self._host.AnchorPoint=Vector2.new(1,1); self._layout.VerticalAlignment=Enum.VerticalAlignment.Bottom
	end
end
function Notify:_refreshTheme() for _,item in self._items do if item._dot then item._dot.BackgroundColor3=self._window.Theme:Get(TOK[item.Variant] or "Accent") end end end
function Notify:_mount(item)
	local w=self._window; local j=Janitor.new("Notification"); item._janitor=j; local hasActions=item.Actions and #item.Actions>0
	local frame=Create.New("Frame",{Size=UDim2.new(1,0,0,hasActions and 106 or 72),BackgroundTransparency=0,BorderSizePixel=0,Parent=self._host}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerMd")),Parent=frame}); local stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.18,Parent=frame}); w:_bind(frame,{BackgroundColor3="SurfaceRaised"}); w:_bind(stroke,{Color="BorderSubtle"}); j:Add(frame)
	local dot=Create.New("Frame",{Size=UDim2.fromOffset(8,8),Position=UDim2.fromOffset(13,18),BorderSizePixel=0,Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(1,0),Parent=dot}); dot.BackgroundColor3=w.Theme:Get(TOK[item.Variant] or "Accent")
	item._title=Create.New("TextLabel",{Size=UDim2.new(1,-54,0,24),Position=UDim2.fromOffset(30,8),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Text=item.Title or "",Parent=frame}); w:_bind(item._title,{TextColor3="Text"})
	item._content=Create.New("TextLabel",{Size=UDim2.new(1,-54,0,30),Position=UDim2.fromOffset(30,33),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text=item.Content or "",Parent=frame}); w:_bind(item._content,{TextColor3="TextSecondary"})
	local close=Create.New("TextButton",{Size=UDim2.fromOffset(28,28),Position=UDim2.new(1,-6,0,6),AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,Text="×",Font=w.Fonts.Bold,TextSize=18,Parent=frame}); w:_bind(close,{TextColor3="TextSecondary"}); j:Add(close.MouseButton1Click:Connect(function() item:Dismiss() end)); item._dot=dot
	if hasActions then local row=Create.New("Frame",{Size=UDim2.new(1,-30,0,28),Position=UDim2.fromOffset(20,70),BackgroundTransparency=1,Parent=frame}); Create.List(6,Enum.FillDirection.Horizontal,{HorizontalAlignment=Enum.HorizontalAlignment.Right}).Parent=row; for _,action in item.Actions do local b=Create.New("TextButton",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,1,0),BackgroundTransparency=0,BorderSizePixel=0,Text="  "..(action.Text or "Action").."  ",Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontSmall"),Parent=row}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("CornerSm")),Parent=b}); w:_bind(b,{BackgroundColor3="Control",TextColor3="Text"}); j:Add(b.MouseButton1Click:Connect(function() local ok,err=xpcall(action.Callback or function() end,debug.traceback); if not ok then warn(err) end end)) end end
	if item.Duration and item.Duration>0 then j:Add(task.delay(item.Duration,function() item:Dismiss() end)) end
end
function Notify:Push(options)
	options=options or {}; local item={Title=options.Title or "Notification",Content=options.Content or "",Variant=options.Variant or "Default",Actions=options.Actions,Duration=if options.Duration==nil then 4 else options.Duration,_service=self,_dismissed=false}
	function item:Update(o) if self._dismissed then return self end; for k,v in o do self[k]=v end; if self._title then self._title.Text=self.Title or ""; self._content.Text=self.Content or ""; self._dot.BackgroundColor3=self._service._window.Theme:Get(TOK[self.Variant] or "Accent") end; return self end
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
local Scroller=__require("primitives/Scroller")
local Palette={}; Palette.__index=Palette
function Palette.new(window,search,commands)
	local self=setmetatable({_window=window,_search=search,_commands=commands,_handle=nil,_mode="search",_results={},_rows={},_selected=0},Palette)
	self._inputConn=window.Input.Began:Connect(function(i,processed)
		if self._handle then if i.KeyCode==Enum.KeyCode.Up then self:_move(-1); return end; if i.KeyCode==Enum.KeyCode.Down then self:_move(1); return end; if i.KeyCode==Enum.KeyCode.Return or i.KeyCode==Enum.KeyCode.KeypadEnter then self:_activateSelected(); return end end
		if processed then return end; if i.KeyCode==Enum.KeyCode.K and (window.Input:IsKeyDown(Enum.KeyCode.LeftControl) or window.Input:IsKeyDown(Enum.KeyCode.RightControl)) then self:Open("") end
	end); return self
end
function Palette:Open(query,mode)
	if self._handle then self:Close() end; self._mode=mode or "search"; local w=self._window
	local handle=w.Layers:Push({Scrim=true,ScrimTransparency=0.56,Modal=false,OnDismiss=function() self._handle=nil; self._box=nil; self._list=nil; self._results={}; self._rows={}; self._selected=0 end}); self._handle=handle
	local drawer=w.Device.Layout=="Drawer"; local frame=Surface.new(w,{Size=if drawer then UDim2.new(1,-12,1,-72) else UDim2.fromOffset(math.min(580,w.Device.Viewport.X-32),430),Position=if drawer then UDim2.fromOffset(6,60) else UDim2.fromScale(0.5,0.24),AnchorPoint=if drawer then Vector2.new(0,0) else Vector2.new(0.5,0),BorderSizePixel=0,Parent=handle.Container},{Token="SurfaceRaised",StrokeToken="BorderStrong",StrokeTransparency=0.14,Corner=w.Tokens:Get("CornerLg")}); frame.ZIndex=handle.Depth*10+3
	self._box=Create.New("TextBox",{Size=UDim2.new(1,-24,0,44),Position=UDim2.fromOffset(12,12),BackgroundTransparency=0,BorderSizePixel=0,ClearTextOnFocus=false,PlaceholderText=w.Locale:T("search.placeholder"),Text=query or "",Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Parent=frame}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("FieldRadius")),Parent=self._box}); Create.New("UIPadding",{PaddingLeft=UDim.new(0,13),PaddingRight=UDim.new(0,13),Parent=self._box}); local stroke=Create.New("UIStroke",{Thickness=1,Transparency=0.1,Parent=self._box}); w:_bind(stroke,{Color="AccentBorder"}); w:_bind(self._box,{BackgroundColor3="ControlInset",TextColor3="Text",PlaceholderColor3="TextTertiary"})
	self._list=Scroller.new(w,{Size=UDim2.new(1,-20,1,-76),Position=UDim2.fromOffset(10,66),Parent=frame}); Create.List(4).Parent=self._list
	self._box:GetPropertyChangedSignal("Text"):Connect(function() self:_refresh() end); self._box:CaptureFocus(); self:_refresh(); return self
end
function Palette:_collect()
	local w=self._window; local text=self._box.Text
	if string.sub(text,1,1)==">" or self._mode=="commands" then return self._commands:Query(string.gsub(text,"^>%s*","")) end
	if string.sub(text,1,1)=="@" then local q=string.lower(string.gsub(text,"^@%s*","")); local results={}; for _,tab in w._tabs do local shown=w.Locale:Resolve(tab.Title); if q=="" or string.find(string.lower(shown),q,1,true) then table.insert(results,{Kind="Tab",Title=shown,Handle=tab,Path="Tab"}) end end; return results end
	return self._search:Query(text)
end
function Palette:_refresh()
	if not self._list then return end; for _,c in self._list:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local w=self._window; self._results=self:_collect(); self._rows={}; self._selected=0
	for index,r in self._results do
		local b=Create.New("TextButton",{Size=UDim2.new(1,0,0,48),BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,Text="",Parent=self._list}); Create.New("UICorner",{CornerRadius=UDim.new(0,w.Tokens:Get("FieldRadius")),Parent=b}); w:_bind(b,{BackgroundColor3="AccentSoft"})
		local title=Create.New("TextLabel",{Size=UDim2.new(1,-74,0,24),Position=UDim2.fromOffset(11,4),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontBody"),TextXAlignment=Enum.TextXAlignment.Left,Text=r.Title,Parent=b}); w:_bind(title,{TextColor3="Text"})
		local path=Create.New("TextLabel",{Size=UDim2.new(1,-74,0,16),Position=UDim2.fromOffset(11,27),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=w.Tokens:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,Text=(r.Hidden and r.Requirement and ((r.Path or "").." · requires: "..r.Requirement)) or r.Path or (r.Kind=="Command" and "Command" or ""),Parent=b}); w:_bind(path,{TextColor3="TextTertiary"})
		local kind=Create.New("TextLabel",{AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.new(0,0,0,22),Position=UDim2.new(1,-10,0.5,0),AnchorPoint=Vector2.new(1,0.5),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=w.Tokens:Get("FontCaption"),Text=string.upper(r.Kind or "CONTROL"),Parent=b}); w:_bind(kind,{TextColor3="TextTertiary"})
		self._rows[index]=b; b.MouseEnter:Connect(function() self:_select(index) end); b.MouseButton1Click:Connect(function() self:_activate(r) end)
	end
	if #self._results>0 then self:_select(1) end
end
function Palette:_select(index) if #self._rows==0 then self._selected=0; return end; index=((index-1)%#self._rows)+1; self._selected=index; for i,row in self._rows do if row.Parent then row.BackgroundTransparency=if i==index then 0 else 1 end end end
function Palette:_move(delta) if #self._rows==0 then return end; self:_select((self._selected>0 and self._selected or 1)+delta) end
function Palette:_activate(r) if not r then return end; local w=self._window; if r.Kind=="Command" then self._commands:Run(r.Id) elseif r.Kind=="Tab" then r.Handle:Select() elseif r.Hidden and r.DependencyIds and r.DependencyIds[1] then local dep=w.Registry:Get(r.DependencyIds[1]); if dep and dep.Reveal then dep:Reveal() end elseif r.Handle and r.Handle.Reveal then r.Handle:Reveal() end; self:Close() end
function Palette:_activateSelected() if self._selected>0 then self:_activate(self._results[self._selected]) end end
function Palette:Close() if self._handle then local h=self._handle; self._handle=nil; h:Dismiss() end; self._box=nil; self._list=nil; self._results={}; self._rows={}; self._selected=0 end
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
local Button=__require("controls/Button"); local Toggle=__require("controls/Toggle"); local Slider=__require("controls/Slider"); local Dropdown=__require("controls/Dropdown"); local TextField=__require("controls/TextField"); local Keybind=__require("controls/Keybind"); local ColorPicker=__require("controls/ColorPicker"); local Paragraph=__require("controls/Paragraph"); local Divider=__require("controls/Divider"); local Status=__require("controls/Status")
local Section={}; Section.__index=Section
function Section.new(tab,options)
	options=options or {}; local self=setmetatable({Id=options.Id,Title=options.Title,Description=options.Description,Collapsible=options.Collapsible==true,Collapsed=options.Collapsed==true,Column=options.Column or 1,_implicit=options._implicit==true,_tab=tab,_window=tab._window,_janitor=Janitor.new(`Section[{options.Title or "Default"}]`),_controls={},_mounted=false,_visible=options.Visible~=false},Section)
	tab._janitor:Add(self,"Destroy",self); table.insert(tab._sections,self); if self.Id then self._window.Registry:Add(self,{Id=self.Id,Type="Section",Title=self.Title or "Section",Tab=tab.Id,Path=tab.Title,Persist=false}) end
	self._janitor:Add(self._window.Tokens.Changed:Connect(function() if self._mounted then self:_applyTokens() end end)); if tab._mounted then self:_mount() end; return self
end
function Section:_mount()
	if self._mounted then return end; self._mounted=true; local w=self._window; local t=w.Tokens
	self._root=Surface.new(w,{Name="Section",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BorderSizePixel=0,Visible=self._visible,Parent=self._tab:_sectionParent(self.Column)},{Token=if self._implicit then "Canvas" else "SurfaceRaised",Stroke=not self._implicit,StrokeToken="BorderSubtle",StrokeTransparency=0.48,Corner=if self._implicit then 0 else t:Get("CornerMd")}); self._janitor:Add(self._root)
	local pad=if self._implicit then 0 else t:Get("SectionPadding"); self._padding=Create.New("UIPadding",{PaddingTop=UDim.new(0,pad),PaddingBottom=UDim.new(0,pad),PaddingLeft=UDim.new(0,pad),PaddingRight=UDim.new(0,pad),Parent=self._root}); self._rootLayout=Create.List(if self._implicit then t:Get("RowGap") else 10); self._rootLayout.Parent=self._root
	if not self._implicit and self.Title then
		local headerClass=if self.Collapsible then "TextButton" else "Frame"; self._header=Create.New(headerClass,{Size=UDim2.new(1,0,0,self.Description and 38 or 24),BackgroundTransparency=1,BorderSizePixel=0,Text=headerClass=="TextButton" and "" or nil,AutoButtonColor=headerClass=="TextButton" and false or nil,Parent=self._root})
		self._title=Create.New("TextLabel",{Size=UDim2.new(1,-34,0,19),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=t:Get("FontTitle"),TextXAlignment=Enum.TextXAlignment.Left,Text=w.Locale:Resolve(self.Title),Parent=self._header}); w:_bind(self._title,{TextColor3="Text"})
		if self.Description then self._desc=Create.New("TextLabel",{Size=UDim2.new(1,-34,0,15),Position=UDim2.fromOffset(0,20),BackgroundTransparency=1,Font=w.Fonts.Regular,TextSize=t:Get("FontSmall"),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Text=w.Locale:Resolve(self.Description),Parent=self._header}); w:_bind(self._desc,{TextColor3="TextTertiary"}) end
		if self.Collapsible then
			self._chevron=Create.New("TextLabel",{Size=UDim2.fromOffset(26,26),Position=UDim2.new(1,0,0,0),AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,Font=w.Fonts.Medium,TextSize=17,Text=if self.Collapsed then "›" else "⌄",Parent=self._header}); w:_bind(self._chevron,{TextColor3="TextTertiary"}); self._janitor:Add(self._header.MouseButton1Click:Connect(function() self:SetCollapsed(not self.Collapsed) end))
		end
	end
	self._content=Create.New("Frame",{Name="Controls",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Visible=not self.Collapsed,Parent=self._root}); self._contentLayout=Create.List(t:Get("RowGap")); self._contentLayout.Parent=self._content
	for _,control in self._controls do control:_mount() end
end
function Section:_applyTokens()
	if not self._mounted then return end; local t=self._window.Tokens; local pad=if self._implicit then 0 else t:Get("SectionPadding"); local u=UDim.new(0,pad)
	if self._padding then self._padding.PaddingTop=u; self._padding.PaddingBottom=u; self._padding.PaddingLeft=u; self._padding.PaddingRight=u end
	if self._rootLayout then self._rootLayout.Padding=UDim.new(0,if self._implicit then t:Get("RowGap") else 10) end; if self._contentLayout then self._contentLayout.Padding=UDim.new(0,t:Get("RowGap")) end
	if self._title then self._title.TextSize=t:Get("FontTitle") end; if self._desc then self._desc.TextSize=t:Get("FontSmall") end
end
function Section:_refreshSeparators()
	local visible={}
	for _,control in self._controls do if control._separator and control._root and control._root.Visible then table.insert(visible,control) end end
	for i,control in visible do control._separator.Visible=i<#visible end
end
function Section:_registerControl(c) table.insert(self._controls,c); if self._mounted then task.defer(function() if not self._destroyed then self:_refreshSeparators() end end) end end
function Section:_removeControl(c) local p=table.find(self._controls,c); if p then table.remove(self._controls,p) end; self:_refreshSeparators() end
function Section:AddButton(o) return Button.new(self,o) end; function Section:AddToggle(o) return Toggle.new(self,o) end; function Section:AddSlider(o) return Slider.new(self,o) end; function Section:AddDropdown(o) return Dropdown.new(self,o) end; function Section:AddInput(o) return TextField.new(self,o) end; function Section:AddKeybind(o) return Keybind.new(self,o) end; function Section:AddColorPicker(o) return ColorPicker.new(self,o) end; function Section:AddParagraph(o) return Paragraph.new(self,o) end; function Section:AddDivider(o) return Divider.new(self,o or {}) end; function Section:AddStatus(o) return Status.new(self,o) end
function Section:_refreshLocale() if self._title then self._title.Text=self._window.Locale:Resolve(self.Title or "") end; if self._desc then self._desc.Text=self._window.Locale:Resolve(self.Description or "") end; if self.Id then self._window.Registry:Update(self,{Title=self._window.Locale:Resolve(self.Title or "Section"),Path=self._window.Locale:Resolve(self._tab.Title)}) end; for _,control in self._controls do if control._refreshText then control:_refreshText() end end end
function Section:SetTitle(t) self.Title=t; if self._title then self._title.Text=self._window.Locale:Resolve(t or "") end; if self.Id then self._window.Registry:Update(self,{Title=self._window.Locale:Resolve(t or "Section")}) end; return self end
function Section:SetVisible(v) self._visible=v==true; if self._root then self._root.Visible=self._visible end; return self end
function Section:SetCollapsed(v) self.Collapsed=v==true; if self._content then self._content.Visible=not self.Collapsed end; if self._chevron then self._chevron.Text=if self.Collapsed then "›" else "⌄" end; return self end
function Section:GetInstance() return self._root end
function Section:Destroy() if self._destroyed then return end; self._destroyed=true; self._tab._janitor:Release(self); if self.Id then self._window.Registry:Remove(self) end; local p=table.find(self._tab._sections,self); if p then table.remove(self._tab._sections,p) end; for _,control in table.clone(self._controls) do control:Destroy() end; self._janitor:Destroy() end
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
		Order = options.Order or (#window._tabs + 1),

		_window = window,
		_janitor = Janitor.new(`Tab[{options.Title}]`),
		_mounted = false,
		_selected = false,
		_sections = {},
		_defaultSection = nil,
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
		LayoutOrder = self.Order,
		Parent = window._navList,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = button })
	local indicator = New("Frame", {Name="Indicator", Size=UDim2.fromOffset(2,16), Position=UDim2.new(0,1,0.5,0), AnchorPoint=Vector2.new(0,0.5), BorderSizePixel=0, Visible=false, Parent=button})
	New("UICorner", {CornerRadius=UDim.new(1,0), Parent=indicator}); window:_bind(indicator,{BackgroundColor3="Accent"})
	self._indicator=indicator
	self._janitor:Add(button)

	-- Icon when supplied, otherwise a minimal initial (also remains useful in Rail mode).
	local avatarProps = {
		Name = "Avatar",
		Size = UDim2.fromOffset(tokens:Get("IconMd"), tokens:Get("IconMd")),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = button,
	}
	local avatar
	if options.Icon then
		avatar = Icon.new(window, options.Icon, avatarProps)
	else
		avatarProps.Font = window.Fonts.Medium
		avatarProps.TextSize = tokens:Get("FontSmall")
		avatarProps.Text = window.Locale:Resolve(options.Title):sub(1, 1):upper()
		avatar = New("TextLabel", avatarProps)
		window:_bind(avatar, { TextColor3 = "TextTertiary" })
	end

	local label = New("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, -36, 1, 0),
		Position = UDim2.new(0, 32, 0, 0),
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
			button.BackgroundTransparency = 0.45
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
		Parent = window._content,
	})
	self._janitor:Add(self._page)

	self._pagePadding = New("UIPadding", {
		PaddingTop = UDim.new(0, tokens:Get("PagePadding")),
		PaddingBottom = UDim.new(0, tokens:Get("PagePadding")),
		PaddingLeft = UDim.new(0, tokens:Get("PagePadding")),
		PaddingRight = UDim.new(0, tokens:Get("PagePadding")),
		Parent = self._page,
	})
	self._introHeight = if self.Description then 54 else 36
	self._pageIntro = New("Frame", {
		Name = "PageIntro",
		Size = UDim2.new(1, 0, 0, self._introHeight),
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
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromOffset(0, self._introHeight),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self._page,
	})
	self._emptyState = New("TextLabel", {
		Name = "EmptyState",
		Size = UDim2.new(1, -40, 0, 54),
		Position = UDim2.new(0, 20, 0, self._introHeight + 24),
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
	self._column1 = New("Frame", {Name="Column1", Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, Parent=self._sectionHost})
	self._column2 = New("Frame", {Name="Column2", Size=UDim2.new(0.5,-6,0,0), Position=UDim2.new(0.5,6,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, Visible=false, Parent=self._sectionHost})
	self._column1Layout = Create.List(tokens:Get("SectionGap")); self._column1Layout.Parent = self._column1
	self._column2Layout = Create.List(tokens:Get("SectionGap")); self._column2Layout.Parent = self._column2

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
	local t=self._window.Tokens
	if self._pagePadding then
		local p=UDim.new(0,t:Get("PagePadding")); self._pagePadding.PaddingTop=p; self._pagePadding.PaddingBottom=p; self._pagePadding.PaddingLeft=p; self._pagePadding.PaddingRight=p
	end
	if self._pageTitle then self._pageTitle.TextSize=t:Get("FontHeading") end
	if self._pageDescription then self._pageDescription.TextSize=t:Get("FontSmall") end
	if self._emptyState then self._emptyState.TextSize=t:Get("FontBody") end
	if self._column1Layout then self._column1Layout.Padding=UDim.new(0,t:Get("SectionGap")) end
	if self._column2Layout then self._column2Layout.Padding=UDim.new(0,t:Get("SectionGap")) end
	for _,section in self._sections do if section._applyTokens then section:_applyTokens() end end
end

function Tab:_sectionParent(column)
	if self._window._layout == "Wide" and column == 2 then return self._column2 end
	return self._column1
end

function Tab:_applySectionLayout(layout)
	local wide = layout == "Wide"
	self._column1.Size = if wide then UDim2.new(0.5, -6, 0, 0) else UDim2.new(1, 0, 0, 0)
	self._column2.Visible = wide
	for _, section in self._sections do
		if section._root then section._root.Parent = self:_sectionParent(section.Column) end
	end
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
	self._button.BackgroundTransparency = if selected then 0.15 else 1
	if self._indicator then self._indicator.Visible=selected end

	local theme = self._window.Theme
	self._label.TextColor3 = theme:Get(if selected then "Text" else "TextSecondary")
	if self._avatar:IsA("ImageLabel") then self._avatar.ImageColor3 = theme:Get(if selected then "Accent" else "TextTertiary") elseif self._avatar:IsA("TextLabel") then self._avatar.TextColor3 = theme:Get(if selected then "Accent" else "TextTertiary") else self._avatar.BackgroundColor3 = theme:Get(if selected then "Accent" else "TextTertiary") end

	if selected then
		self:_ensureMounted()
	end
end

function Tab:_refreshLocale()
	local shown=self._window.Locale:Resolve(self.Title)
	self._label.Text=shown; if not self.Icon and self._avatar:IsA("TextLabel") then self._avatar.Text=shown:sub(1,1):upper() end
	if self._pageTitle then self._pageTitle.Text=shown end
	if self._pageDescription then self._pageDescription.Text=self._window.Locale:Resolve(self.Description or "") end
	if self._window.Registry then self._window.Registry:Update(self,{Title=shown,Path=shown}) end
	for _,section in self._sections do if section._refreshLocale then section:_refreshLocale() end end
	if self._selected then self._window:_refreshHeaderTitle() end
end

function Tab:SetTitle(title: string)
	self.Title = title
	local shown=self._window.Locale:Resolve(title)
	self._label.Text = shown
	if self._pageTitle then self._pageTitle.Text=shown end
	if not self.Icon and self._avatar:IsA("TextLabel") then self._avatar.Text = shown:sub(1,1):upper() end
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
	if self._pageIntro then self._pageIntro.Size=UDim2.new(1,0,0,self._introHeight) end
	if self._sectionHost then self._sectionHost.Position=UDim2.fromOffset(0,self._introHeight) end
	if self._emptyState then self._emptyState.Position=UDim2.new(0,20,0,self._introHeight+24) end
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
	local props={Name="Avatar",Size=UDim2.fromOffset(t:Get("IconMd"),t:Get("IconMd")),Position=UDim2.new(0,8,0.5,0),AnchorPoint=Vector2.new(0,0.5),Parent=self._button}
	if icon then self._avatar=Icon.new(self._window,icon,props) else props.Font=self._window.Fonts.Medium; props.TextSize=t:Get("FontSmall"); props.Text=self._window.Locale:Resolve(self.Title):sub(1,1):upper(); self._avatar=New("TextLabel",props); self._window:_bind(self._avatar,{TextColor3="TextTertiary"}) end
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
		Size = UDim2.new(1, -140, 0, 18),
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
		Size = UDim2.new(1, -140, 0, 14),
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
		Position = UDim2.new(1, -80, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = self._header,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = self._searchButton })
	self:_bind(self._searchButton, { BackgroundColor3 = "ControlHover" })
	drawSearchIcon(self, self._searchButton)
	self._janitor:Add(self._searchButton.MouseEnter:Connect(function() self._searchButton.BackgroundTransparency=0.35 end))
	self._janitor:Add(self._searchButton.MouseLeave:Connect(function() self._searchButton.BackgroundTransparency=1 end))
	self._janitor:Add(self._searchButton.MouseButton1Click:Connect(function()
		if self.OpenSearch then self:OpenSearch() end
	end))

	self._themeButton = New("TextButton", {
		Name = "Theme",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -44, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = self._header,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = self._themeButton })
	self:_bind(self._themeButton, { BackgroundColor3 = "ControlHover" })
	drawThemeIcon(self, self._themeButton)
	self._janitor:Add(self._themeButton.MouseEnter:Connect(function() self._themeButton.BackgroundTransparency=0.35 end))
	self._janitor:Add(self._themeButton.MouseLeave:Connect(function() self._themeButton.BackgroundTransparency=1 end))
	self._janitor:Add(self._themeButton.MouseButton1Click:Connect(function()
		if self.SetTheme then self:SetTheme(self.Theme:Current() == "Dark" and "Light" or "Dark") end
	end))

	self._closeButton = New("TextButton", {
		Name = "Close",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
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
	self._closeButton.BackgroundTransparency = 1

	self._janitor:Add(self._closeButton.MouseEnter:Connect(function()
		self._closeButton.BackgroundTransparency = 0
	end))
	self._janitor:Add(self._closeButton.MouseLeave:Connect(function()
		self._closeButton.BackgroundTransparency = 1
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
		PaddingTop = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 9),
		PaddingRight = UDim.new(0, 9),
		Parent = self._navList,
	})
	Create.List(5).Parent = self._navList

	self._content = New("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -tokens:Get("SidebarWidth"), 1, 0),
		Position = UDim2.new(0, tokens:Get("SidebarWidth"), 0, 0),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = self._body,
	})
	self:_bind(self._content, {BackgroundColor3 = "Canvas"})
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
		if self._layout == "Drawer" then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local startPosition = input.Position
		local startSize = self._root.AbsoluteSize
		self.Input:CapturePointer(self._grip, input, function(move)
			local delta = move.Position - startPosition
			self._size = UDim2.fromOffset(
				math.max(self._minSize.X, startSize.X + delta.X),
				math.max(self._minSize.Y, startSize.Y + delta.Y)
			)
			if self._layout ~= "Drawer" then self._root.Size = self._size end
		end, function() end)
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
		if self._layout == "Drawer" then return false end
		startPosition = self._root.Position
		return true
	end)
	self._janitor:Add(dragJanitor)
end

-- ===== layout ====================================================

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
	self._grip.Visible = not drawerMode
	self._navPanel.Visible = not drawerMode
	self._subtitleLabel.Visible = self.Subtitle ~= nil and not drawerMode

	if self._navList.Parent ~= self._navPanel then
		self._navList.Parent = self._navPanel
	end

	for _, tab in self._tabs do
		tab:_applySectionLayout(layout)
		tab._label.Visible = not railMode
		if tab._badge then tab._badge.Visible = not railMode end
		tab._avatar.Position = if railMode
			then UDim2.fromScale(0.5, 0.5)
			else UDim2.new(0, 8, 0.5, 0)
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
	self._titleLabel.Size = UDim2.new(1, -titleLeft - 112, 0, if self._subtitleLabel.Visible then 20 else headerHeight)
	self._subtitleLabel.Position = UDim2.new(0, titleLeft, 0, 29)

	if drawerMode then
		self._content.Size = UDim2.fromScale(1, 1)
		self._content.Position = UDim2.new()
	else
		self._navPanel.Size = UDim2.new(0, navWidth, 1, 0)
		self._content.Size = UDim2.new(1, -navWidth, 1, 0)
		self._content.Position = UDim2.new(0, navWidth, 0, 0)
	end

	for _, tab in self._tabs do
		tab:_applyTokens()
		tab._button.Size = UDim2.new(1, 0, 0, tokens:Get("NavItemHeight"))
		tab._label.TextSize = tokens:Get("FontBody")
	end
end

function Window:_applyGeometry()
	if self._layout == "Drawer" then
		local position, size = self.Device:SafeArea()
		self._root.AnchorPoint = Vector2.new(0, 0)
		self._root.Position = UDim2.fromOffset(position.X, position.Y)
		self._root.Size = UDim2.fromOffset(size.X, size.Y)
	else
		self._root.AnchorPoint = Vector2.new(0.5, 0.5)
		if self._root.Position.X.Scale == 0 then
			self._root.Position = UDim2.fromScale(0.5, 0.5)
		end
		local viewport = self.Device.Viewport
		self._root.Size = UDim2.fromOffset(
			math.min(self._size.X.Offset, viewport.X - 40),
			math.min(self._size.Y.Offset, viewport.Y - 40)
		)
	end
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
	if not self._active then
		self:_selectTab(tab)
	else
		tab:_setSelected(false)
	end

	self:_applyLayout(self._layout, true)
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
	Canvas=hex("#090B0E"),
	Background=hex("#090B0E"),
	Sidebar=hex("#0C0E12"),
	Surface=hex("#101319"),
	SurfaceRaised=hex("#13171D"),
	SurfaceInset=hex("#0D1014"),
	SurfaceSecondary=hex("#171B22"),
	SurfaceHover=hex("#171C23"),
	SurfaceActive=hex("#1D232C"),
	Control=hex("#12161C"),
	ControlHover=hex("#151A21"),
	ControlPressed=hex("#1B2028"),
	ControlInset=hex("#0D1116"),
	BorderSubtle=hex("#1C222A"),
	Border=hex("#252C36"),
	BorderStrong=hex("#343D49"),
	Text=hex("#F4F6F8"),
	TextSecondary=hex("#A7B0BE"),
	TextTertiary=hex("#707B8B"),
	TextDisabled=hex("#535C69"),
	Accent=hex("#8B7CF6"),
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
	TextSecondary=hex("#626C7A"),
	TextTertiary=hex("#8C96A5"),
	TextDisabled=hex("#AAB2BE"),
	Accent=hex("#6D4EF5"),
	Success=hex("#169D63"),
	Warning=hex("#B77A09"),
	Error=hex("#D84A50"),
	Info=hex("#147FBE"),
	Scrim=hex("#15181D"),
	Shadow=hex("#101216"),
}

end

return __require("init")
