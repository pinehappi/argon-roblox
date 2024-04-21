local Argon = script:FindFirstAncestor('Argon')

local Dom = require(Argon.Dom)
local Log = require(Argon.Log)
local Util = require(Argon.Util)
local Types = require(Argon.Types)
local equals = require(Argon.Helpers.equals)

local Error = require(script.Parent.Error)
local Changes = require(script.Parent.Changes)

local ReadProcessor = require(script.Read)
local WriteProcessor = require(script.Write)

local Processor = {}
Processor.__index = Processor

function Processor.new(tree)
	local self = {
		tree = tree,
		read = ReadProcessor.new(tree),
		write = WriteProcessor.new(tree),
	}

	return setmetatable(self, Processor)
end

function Processor:init(snapshot: Types.Snapshot, ignoreMeta: boolean): Types.Changes
	Log.trace('Hydrating initial snapshot..')

	self:hydrate(snapshot, game)

	Log.trace('Diffing initial snapshot..')

	local changes = Changes.new()

	for _, child in ipairs(snapshot.children) do
		changes:join(self:diff(child, snapshot.id, ignoreMeta))
	end

	return changes
end

function Processor:hydrate(snapshot: Types.Snapshot, instance: Instance)
	self.tree:insertInstance(instance, snapshot.id)

	local children = instance:GetChildren()
	local hydrated = table.create(#children, false)

	for _, snapshotChild in ipairs(snapshot.children) do
		for index, child in children do
			if hydrated[index] then
				continue
			end

			if child.Name == snapshotChild.name and child.ClassName == snapshotChild.class then
				self:hydrate(snapshotChild, child)
				hydrated[index] = true
				break
			end
		end
	end
end

function Processor:diff(snapshot: Types.Snapshot, parent: Types.Ref, ignoreMeta: boolean): Types.Changes
	local changes = Changes.new()

	local instance = self.tree:getInstance(snapshot.id)

	-- Check if snapshot is new
	if not instance then
		changes:add(snapshot, parent)
		return changes
	end

	-- Diff properties, find updated ones
	do
		local defaultProperties = Dom.getDefaultProperties(instance.ClassName)
		local updatedProperties = {}

		for property, default in pairs(defaultProperties) do
			local value = snapshot.properties[property]

			if value then
				local readSuccess, instanceValue = Dom.readProperty(instance, property)

				if not readSuccess then
					local err = Error.new(Error.ReadFailed, property, instance)
					Log.warn(err)

					continue
				end

				local decodeSuccess, snapshotValue = Dom.EncodedValue.decode(value)

				if not decodeSuccess then
					local err = Error.new(Error.DecodeFailed, property, value)
					Log.warn(err)

					continue
				end

				if not equals(instanceValue, snapshotValue) then
					updatedProperties[property] = value
				end

				-- If snapshot does not have the property we want it to be default
			else
				local readSuccess, instanceValue = Dom.readProperty(instance, property)

				if not readSuccess then
					local err = Error.new(Error.ReadFailed, property, instance)
					Log.warn(err)

					continue
				end

				local _, defaultValue = Dom.EncodedValue.decode(default)

				if not equals(instanceValue, defaultValue) then
					updatedProperties[property] = default
				end
			end
		end

		if next(updatedProperties) then
			changes:update({
				id = snapshot.id,
				properties = updatedProperties,
			})
		end
	end

	-- Diff snapshot children, find new ones
	for _, child in snapshot.children do
		local childInstance = self.tree:getInstance(child.id)

		if not childInstance then
			changes:add(child, snapshot.id)
		end
	end

	-- Diff instance children, find removed ones
	for _, child in instance:GetChildren() do
		local childId = self.tree:getId(child)

		if childId then
			local childSnapshot = Util.filter(snapshot.children, function(child)
				return child.id == childId
			end)

			changes:join(self:diff(childSnapshot, snapshot.id, ignoreMeta))
		elseif (not snapshot.meta.keepUnknowns or ignoreMeta) and Dom.isCreatable(child.ClassName) then
			changes:remove(child)
		end
	end

	return changes
end

function Processor:revertChanges(changes: Types.Changes): Types.Changes
	local reverted = Changes.new()

	for _, snapshot in ipairs(changes.additions) do
		reverted:remove(buffer.fromstring(snapshot.id))
	end

	for _, snapshot in ipairs(changes.updates) do
		local instance = self.tree:getInstance(snapshot.id)
		reverted:update(self.read:onChange(instance))
	end

	for _, instance in ipairs(changes.removals) do
		reverted:add(self.read:onAdd(instance))
	end

	return reverted
end

return Processor