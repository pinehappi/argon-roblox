local Argon = script:FindFirstAncestor('Argon')
local Fusion = require(Argon.Packages.Fusion)

local App = script:FindFirstAncestor('App')
local Components = script.Parent
local Util = Components.Util

local Enums = require(App.Enums)
local Style = require(App.Style)
local Types = require(Util.Types)
local stripProps = require(Util.stripProps)
local mapColor = require(Util.mapColor)
local mapFont = require(Util.mapFont)

local New = Fusion.New
local Hydrate = Fusion.Hydrate

local COMPONENT_ONLY_PROPS = {
	'Font',
	'Color',
}

type Props = {
	Font: Types.CanBeState<Enums.Font>?,
	Color: Types.CanBeState<Enums.Color | Color3>?,
	[any]: any,
}

return function(props: Props): TextLabel
	return Hydrate(New('TextLabel') {
		FontFace = mapFont(props.Font, Enums.Font.Default),
		TextColor3 = mapColor(props.Color, Enums.Color.Text),
		TextSize = Style.TextSize,
		AutomaticSize = Enum.AutomaticSize.XY,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
	})(stripProps(props, COMPONENT_ONLY_PROPS))
end
