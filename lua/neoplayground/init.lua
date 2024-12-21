-- lua/neoplayground/init.lua
local M = {}

-- Default configuration
M.config = {
	output_filetype = "lua", -- Default output filetype
	auto_refresh = true, -- Auto refresh on save
	split_width = 0.5, -- Split width ratio (50%)
}

-- Store output window information
M.windows = {
	output_buf = nil, -- Buffer number for output window
	output_win = nil, -- Window number for output window
}

-- Setup function that will be called by lazy.nvim
function M.setup(opts)
	-- Merge user config with defaults
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Create autocommand group
	local augroup = vim.api.nvim_create_augroup("NeoPlayground", { clear = true })

	-- Add autocmd for BufWritePost
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = augroup,
		pattern = "*.lua", -- Only for Lua files
		callback = function()
			local current_buf = vim.api.nvim_get_current_buf()
			if vim.b[current_buf].is_playground then
				M.update_output(current_buf)
			end
		end,
	})

	-- Create command to start playground
	vim.api.nvim_create_user_command("PlaygroundStart", function()
		-- Mark current buffer as playground
		vim.b.is_playground = true
		-- Create output window
		M.create_output_window()
		-- Initial update
		M.update_output(vim.api.nvim_get_current_buf())
	end, {})
end

-- Function to create or get output window
function M.create_output_window()
	-- If output window exists and is valid, return it
	if M.windows.output_win and vim.api.nvim_win_is_valid(M.windows.output_win) then
		return
	end

	-- Save current window to return to it later
	local current_win = vim.api.nvim_get_current_win()

	-- Create vertical split
	vim.cmd("vsplit")

	-- Get the new window and move it to the right
	M.windows.output_win = vim.api.nvim_get_current_win()
	vim.cmd("wincmd L")

	-- Create or get output buffer
	if not M.windows.output_buf or not vim.api.nvim_buf_is_valid(M.windows.output_buf) then
		M.windows.output_buf = vim.api.nvim_create_buf(false, true)
		-- Set buffer options
		vim.api.nvim_buf_set_option(M.windows.output_buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(M.windows.output_buf, "bufhidden", "hide")
		vim.api.nvim_buf_set_option(M.windows.output_buf, "swapfile", false)
		vim.api.nvim_buf_set_option(M.windows.output_buf, "filetype", M.config.output_filetype)
	end

	-- Set the buffer in the output window
	vim.api.nvim_win_set_buf(M.windows.output_win, M.windows.output_buf)

	-- Return to original window
	vim.api.nvim_set_current_win(current_win)
end

-- Function to update output
function M.update_output(buf)
	-- Ensure output window exists
	M.create_output_window()

	-- Get content of current buffer
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local content = table.concat(lines, "\n")

	-- Execute the code and capture output
	local success, result = pcall(function()
		local func = loadstring(content)
		if func then
			return func()
		end
		return "No output"
	end)

	-- Prepare output content
	local output
	if success then
		if result == nil then
			output = "nil"
		else
			output = vim.inspect(result)
		end
	else
		output = "Error: " .. tostring(result)
	end

	-- Update output buffer
	vim.api.nvim_buf_set_lines(M.windows.output_buf, 0, -1, false, vim.split(output, "\n"))
end

return M
