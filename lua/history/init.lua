local M = {}

M.buffers = {}

M.get_history_file = function(mode)
	mode = mode or "w"
	local data_dir = vim.fn.stdpath("data")
	local history_dir = data_dir .. "/history.nvim"
	vim.fn.mkdir(history_dir, "p")

	local filename = vim.fn.getcwd():gsub("/", "-"):gsub(" ", "_"):gsub("\\.", "-") .. ".json"
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

M.save_buffers = function()
	local bufs = {}
	for _, buf in ipairs(M.buffers) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
			table.insert(bufs, vim.api.nvim_buf_get_name(buf))
		end
	end

	local file = M.get_history_file()

	if file then
		file:write(vim.fn.json_encode(bufs))
		file:close()
	end
end

M.load_buffers = function()
	vim.schedule(function() -- Ensure this runs after startup
		local file = M.get_history_file("r")
		if not file then
			return
		end

		local content = file:read("*a")
		file:close()

		local bufs = vim.fn.json_decode(content)
		if not bufs or #bufs == 0 then
			return
		end

		M.buffers = {}

		for _, bufname in ipairs(bufs) do
			if vim.fn.filereadable(bufname) == 1 then
				vim.cmd("silent! edit " .. vim.fn.fnameescape(bufname))
			end
		end
	end)
end

M.setup = function(opts)
	opts = opts
		or {
			forward_key = "<Tab>",
			backward_key = "<S-Tab>",
			width = "40%",
			height = "60%",
			persist = true,
		}

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
			if buftype ~= "nofile" then
				for i, buf in ipairs(M.buffers) do
					if buf == bufnr then
						table.remove(M.buffers, i)
					end
				end

				table.insert(M.buffers, bufnr)
			end
		end,
	})

	if persist then
		vim.api.nvim_create_autocmd("VimLeavePre", {
			callback = function()
				if vim.fn.argc(-1) == 0 then
					M.save_buffers()
				end
			end,
		})
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				if vim.fn.argc(-1) == 0 then
					M.load_buffers()
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

		for _, buf in ipairs(M.buffers) do
			if vim.api.nvim_buf_is_valid(buf) then
				local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
				if buftype ~= "nofile" then
					local name = vim.api.nvim_buf_get_name(buf)
					local cwd = vim.fn.getcwd()

					local match = escape_pattern(cwd .. "/")
					name = name:gsub(match, "")

					-- Split the name into directory and filename
					local dir, filename = name:match("^(.*/)([^/]+)$")
					if not dir then
						filename = name
						dir = ""
					end

					-- Create menu item with styled text
					local item = Menu.item({
						{ text = dir, hl = "Comment" },
						{ text = filename, hl = "Normal" },
					}, { bufnr = buf })

					table.insert(lines, item)
				end
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
				vim.api.nvim_set_current_buf(item.bufnr)
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
