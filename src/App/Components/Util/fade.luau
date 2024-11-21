-- Inserts a CanvasGroup into a frame then reparents all the children into it
-- then fades the CanvasGroup.
-- When using this MAKE SURE your frame is not AutomaticSize as the CanvasGroup will have
-- its size set to {1, 0, 1, 0} which will expand the frame to max if it is AutomaticSize.

local TweenService = game:GetService("TweenService")

local Argon = script:FindFirstAncestor("Argon")
local App = Argon.App

local Theme = require(App.Theme)

type FadeOptions = {
	tweenInfo: TweenInfo?,
	offset: UDim2?,
}
return function(frame: Frame, fadeOptions: FadeOptions)
	local tweenInfo = fadeOptions.tweenInfo or Theme.FadeTweenInfo
	local offset = fadeOptions.offset or UDim2.fromOffset(0, 0)

	local canvasGroup = Instance.new("CanvasGroup")
	canvasGroup.BackgroundTransparency = 1
	canvasGroup.Size = UDim2.fromScale(1, 1)

	for _, child in frame:GetChildren() do
		child.Parent = canvasGroup
	end
	canvasGroup.Parent = frame

	frame.Interactable = false

	TweenService:Create(frame, tweenInfo, {
		BackgroundTransparency = 1,
		Position = frame.Position + offset,
	}):Play()
	local tween = TweenService:Create(canvasGroup, tweenInfo, {
		GroupTransparency = 1,
	})
	tween:Play()
	tween.Completed:Wait()
end
