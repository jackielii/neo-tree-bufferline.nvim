--This file should have all functions that are in the public api and either set
--or read the state of this source.

local vim = vim
local renderer = require("neo-tree.ui.renderer")
local manager = require("neo-tree.sources.manager")
local events = require("neo-tree.events")
local utils = require("neo-tree.utils")

local M = {
	-- This is the name our source will be referred to as
	-- within Neo-tree
	name = "pinned-buffers",
	-- This is how our source will be displayed in the Source Selector
	display_name = " 📌Pinned Buffers "
}

local function indexOf(t, value)
	for i, v in ipairs(t) do
		if v == value then
			return i
		end
	end
	return -1
end

local fnmod = vim.fn.fnamemodify

---Navigate to the given path.
---@param path string Path to navigate to. If empty, will navigate to the cwd.
M.navigate = function(state, path, path_to_reveal, callback, async)
	if path == nil then
		path = vim.fn.getcwd()
	end
	state.path = path

	-- print(path, path_to_reveal)

	local orderedPos
	local positions = vim.g['BufferlinePositions']
	if positions then
		orderedPos = vim.json.decode(positions)
	end

	local paths = vim.split(vim.g['BufferlinePinnedBuffers'] or '', ',')
	if orderedPos then
		table.sort(paths, function(a, b)
			return indexOf(orderedPos, a) < indexOf(orderedPos, b)
		end)
	end

	-- local state = require("bufferline.state")
	-- local groups = require("bufferline.groups")
	-- vim.print(vim.inspect(groups.state))

	local items = {}
	if paths then
		for i, path in ipairs(paths) do
			table.insert(items, {
				id = path,
				name = vim.fs.basename(path),
				-- name = '' .. i .. ' ' .. vim.fs.basename(path),
				type = "file",
				ext = path:match("%.([-_,()%s%w%i]+)$"),
				path = path,
				extra = {
					index = i
				}
			})
		end
	end

	-- fix duplicate names to include parent names
	local seen = {}
	for i, item in ipairs(items) do
		if seen[item.name] then
			local index = seen[item.name]
			local path1, path2 = items[index].path, item.path
			local name1, name2 = '', ''
			while name1 == name2 do
				local parent1, parent2 = fnmod(path1, ":h"), fnmod(path2, ":h")
				if parent1 == '' or parent2 == '' then
					break
				end
				name1, name2 = fnmod(path1, ":t") .. '/' .. name1, fnmod(path2, ":t") .. '/' .. name2
				path1, path2 = parent1, parent2
			end
			items[index].name = name1
			item.name = name2
		else
			seen[item.name] = i
		end
	end

	renderer.show_nodes(items, state)
end

M.follow = function(callback, force_show)
	if utils.is_floating() then
		return false
	end
	utils.debounce("pinned-buffers-follow", function()
		local state = manager.get_state(M.name)
		local path_to_reveal = vim.fn.expand("%:p")
		local res = renderer.focus_node(state, path_to_reveal, true)
		print("follow", res)
		return res
	end, 100, utils.debounce_strategy.CALL_LAST_ONLY)
end

---Configures the plugin, should be called before the plugin is used.
---@param config table Configuration table containing any keys that the user
--wants to change from the defaults. May be empty to accept default values.
M.setup = function(config, global_config)
	local pinEvent = "BUFFERLINE_PIN_BUFFER"
	events.define_autocmd_event(pinEvent, { "User BufferlineUpdated" }, 200)
	local refresh_events = {
		-- events.VIM_BUFFER_ADDED,
		-- events.VIM_BUFFER_DELETED,
		-- events.VIM_BUFFER_CHANGED,
		-- events.VIM_BUFFER_ENTER,
		pinEvent,
	}

	for _, e in ipairs(refresh_events) do
		manager.subscribe(M.name, {
			event = e,
			handler = function()
				manager.refresh(M.name)
			end,
		})
	end

	manager.subscribe(M.name, {
		event = events.VIM_BUFFER_ENTER,
		handler = function(args)
			if utils.is_real_file(args.afile) then
				M.follow()
			end
		end,
	})
end

return M
