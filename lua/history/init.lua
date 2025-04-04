local M = {}

M.history = {}

M.icons = { enable = false, custom = {} }

-- Returns a file handle to the workspace history file
M.get_history_file = function(mode)
	mode = mode or "w"
	local data_dir = vim.fn.stdpath("data")
	local history_dir = data_dir .. "/history.nvim"
	vim.fn.mkdir(history_dir, "p")

	local filename = vim.fn.getcwd():gsub("/", "-"):gsub(" ", "_") .. ".json"

	if filename:match("^[_-]") then
		filename = filename:sub(2)
	end

	local path = history_dir .. "/" .. filename

	if mode == "r" then
		local file = io.open(path, "r")
		if not file then
			return nil
		end
		return file
	end

	return io.open(path, mode)
end

-- Self-explanatory
M.get_filepath_from_bufnr = function(bufnr)
	return vim.api.nvim_buf_get_name(bufnr)
end

-- Save the history to the workspace file
M.save_history = function()
	local files = {}
	for _, filepath in ipairs(M.history) do
		if vim.fn.filereadable(filepath) == 1 then
			table.insert(files, filepath)
		end
	end

	local file = M.get_history_file()

	if file then
		file:write(vim.fn.json_encode(files))
		file:close()
	end
end

-- Load the history from the workspace file
M.load_history = function()
	vim.schedule(
		function() -- Ensure this runs after startup. I'm actually not sure if this is necessary anymore but I'm too lazy to test it rn.
			local file = M.get_history_file("r")
			if not file then
				return
			end

			local content = file:read("*a")
			file:close()

			local files = vim.fn.json_decode(content)
			if not files or #files == 0 then
				return
			end

			M.history = {}

			for _, filepath in ipairs(files) do
				M.add_file_to_history(filepath)
			end
		end
	)
end

-- Open the file and return the buffer number. Returns nil if the file doesn't exist.
M.open_file = function(filepath)
	if vim.fn.filereadable(filepath) == 1 then
		vim.cmd("silent! edit " .. vim.fn.fnameescape(filepath))
		return vim.fn.bufnr("%")
	end

	return nil
end

-- Self-explanatory
M.add_file_to_history = function(filepath)
	table.insert(M.history, filepath)
end

-- Self-explanatory
M.get_filetype_from_filepath = function(filepath)
	local filetype = vim.fn.fnamemodify(filepath, ":t:e")
	return filetype
end

M.setup = function(opts)
	opts = opts
		or {
			forward_key = "<Tab>",
			backward_key = "<S-Tab>",
			width = "40%",
			height = "60%",
			persist = true,
			icons = {
				enable = false,
				custom = {},
			},
		}

	-- Merge icon configuration
	M.icons = vim.tbl_deep_extend("force", {
		enable = false,
		custom = {},
	}, opts.icons or {})

	local forward_key = opts.forward_key or "<Tab>"
	local backward_key = opts.backward_key or "<S-Tab>"
	local size = {
		width = opts.width or "40%",
		height = opts.height or "60%",
	}
	local persist = opts.persist or true

	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function()
			local bufnr = vim.fn.bufnr("%")
			local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
			local filepath = M.get_filepath_from_bufnr(bufnr)

			if buftype ~= "nofile" then
				for i, file in ipairs(M.history) do
					if file == filepath then
						table.remove(M.history, i)
					end
				end

				M.add_file_to_history(filepath)
			end
		end,
	})

	if persist then
		vim.api.nvim_create_autocmd("VimLeavePre", {
			callback = function()
				if vim.fn.argc(-1) == 0 then
					M.save_history()
				end
			end,
		})
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				if vim.fn.argc(-1) == 0 then
					M.load_history()
				end
			end,
		})
	end

	local Menu = require("nui.menu")

	local function array_reverse(x)
		local n, m = #x, #x / 2
		for i = 1, m do
			x[i], x[n - i + 1] = x[n - i + 1], x[i]
		end
		return x
	end

	local function escape_pattern(text)
		local ret = text:gsub("([^%w])", "%%%1")
		ret = ret:gsub("%%%$", "$")
		ret = ret:gsub("%$$", "%%$")
		ret = ret:gsub("%%%^", "^")
		ret = ret:gsub("^%^", "%%^")
		return ret
	end

	local function create_menu()
		local lines = {}
		local NuiText = require("nui.text")
		local NuiLine = require("nui.line")
		local web_devicons_available, web_devicons = pcall(require, "nvim-web-devicons")

		-- Warn if web-devicons isn't installed but icons are enabled
		if M.icons.enable and not web_devicons_available then
			vim.notify_once("history.nvim: nvim-web-devicons not installed, disabling icons", vim.log.levels.WARN)
			M.icons.enable = false
		end

		for _, filepath in ipairs(M.history) do
			if vim.fn.filereadable(filepath) == 1 then
				local cwd = vim.fn.getcwd()
				local ft = M.get_filetype_from_filepath(filepath)

				-- Get icon with custom override
				local icon, hl = " ", "Normal"
				if M.icons.enable then
					-- Use custom icon if defined
					if M.icons.custom[ft] then
						icon = M.icons.custom[ft]
					else
						icon, hl = web_devicons.get_icon(filepath, ft)
					end
					icon = icon or " " -- Fallback to space if no icon found
				end

				local match = escape_pattern(cwd .. "/")
				filepath = filepath:gsub(match, "")

				-- Split path components
				local dir, filename = filepath:match("^(.*/)([^/]+)$")
				dir = dir or ""
				filename = filename or filepath

				-- Create styled line
				local line = NuiLine()
				if M.icons.enable then
					line:append(NuiText(" ", "Comment")) -- Left padding
					line:append(NuiText(icon .. " ", hl)) -- Icon with color
				end
				line:append(NuiText(dir, "Comment"))
				line:append(NuiText(filename, "Normal"))

				local item = Menu.item(line, { filpath = filepath })
				table.insert(lines, item)
			end
		end

		lines = array_reverse(lines)

		local menu = Menu({
			position = "50%",
			size = size,
			border = {
				style = "single",
				text = {
					top = "[history.nvim]",
					top_align = "center",
				},
			},
			win_options = {
				winhighlight = "Normal:Normal,FloatBorder:Normal",
			},
		}, {
			lines = lines,
			max_width = 20,
			keymap = {
				focus_next = { "j", "<Down>", forward_key },
				focus_prev = { "k", "<Up>", backward_key },
				close = { "<Esc>", "<C-c>" },
				submit = { "<CR>", "<Space>" },
			},
			on_close = function()
				-- print("Menu Closed!")
			end,
			on_submit = function(item)
				-- vim.api.nvim_set_current_buf(item.bufnr)
				M.open_file(item.filepath)
			end,
		})

		-- mount the component
		menu:mount()

		vim.api.nvim_feedkeys("j", "n", false)
	end

	vim.keymap.set("n", forward_key, function()
		create_menu()
	end, { desc = "History Menu", silent = true })
end

return M
