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

---Navigate to the given path.
---@param path string Path to navigate to. If empty, will navigate to the cwd.
M.navigate = function(state, path, path_to_reveal, callback, async)
	if path == nil then
		path = vim.fn.getcwd()
	end
	state.path = path

	local paths = vim.split(vim.g['BufferlinePinnedBuffers'] or '', ',')
	local items = {}
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

	renderer.show_nodes(items, state)
end


---Configures the plugin, should be called before the plugin is used.
---@param config table Configuration table containing any keys that the user
--wants to change from the defaults. May be empty to accept default values.
M.setup = function(config, global_config)
	local pinEvent = "BUFFERLINE_PIN_BUFFER"
	events.define_autocmd_event(pinEvent, { "User BufferlinePinBuffer" }, 200)
	local refresh_events = {
		-- events.VIM_BUFFER_ADDED,
		-- events.VIM_BUFFER_DELETED,
		-- events.VIM_BUFFER_CHANGED,
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

	-- if config.bind_to_cwd then
	-- 	manager.subscribe(M.name, {
	-- 		event = events.VIM_DIR_CHANGED,
	-- 		handler = wrap(manager.dir_changed),
	-- 	})
	-- end

	-- -- You most likely want to use this function to subscribe to events
	-- if config.use_libuv_file_watcher then
	-- 	manager.subscribe(M.name, {
	-- 		event = events.FS_EVENT,
	-- 		handler = function(args)
	-- 			manager.refresh(M.name)
	-- 		end,
	-- 	})
	-- end
end

return M
