-- Explicit viewport scaling for authored UI shells.
--
-- Put a UIScale in the authored hierarchy, then bind that UIScale here. This
-- avoids discovering and rewriting arbitrary PlayerGui descendants at runtime.

local Workspace = game:GetService("Workspace")

local AuthoredUiLayout = {}

export type Options = {
	ReferenceViewport: Vector2?,
	MinimumScale: number?,
	MaximumScale: number?,
	DownscaleOnly: boolean?,
	WidthWeight: number?,
}

export type Binding = {
	Update: () -> (),
	Destroy: () -> (),
}

local DEFAULT_REFERENCE_VIEWPORT = Vector2.new(1600, 900)

function AuthoredUiLayout.bind(uiScale: UIScale, options: Options?): Binding
	assert(uiScale:IsA("UIScale"), "AuthoredUiLayout.bind expects an authored UIScale")

	local config = options or {}
	local referenceViewport = config.ReferenceViewport or DEFAULT_REFERENCE_VIEWPORT
	local minimumScale = config.MinimumScale or 0.68
	local maximumScale = config.MaximumScale or 1.15
	local downscaleOnly = config.DownscaleOnly == true
	local widthWeight = math.clamp(config.WidthWeight or 0.5, 0, 1)
	local destroyed = false
	local cameraConnection: RBXScriptConnection? = nil
	local workspaceConnection: RBXScriptConnection? = nil

	local function update()
		if destroyed then
			return
		end

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local viewport = camera.ViewportSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end

		local widthScale = viewport.X / referenceViewport.X
		local heightScale = viewport.Y / referenceViewport.Y
		local blendedScale = widthScale * widthWeight + heightScale * (1 - widthWeight)
		if downscaleOnly then
			blendedScale = math.min(blendedScale, 1)
		end
		uiScale.Scale = math.clamp(blendedScale, minimumScale, maximumScale)
	end

	local function bindCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
			cameraConnection = nil
		end

		local camera = Workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end

	workspaceConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()

	return {
		Update = update,
		Destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			if cameraConnection then
				cameraConnection:Disconnect()
				cameraConnection = nil
			end
			if workspaceConnection then
				workspaceConnection:Disconnect()
				workspaceConnection = nil
			end
		end,
	}
end

return AuthoredUiLayout
