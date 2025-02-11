local M = {}

M.buffers = {}

M.get_history_file = function(mode)
	mode = mode or "w"
	local data_dir = vim.fn.stdpath("data")
	local history_dir = data_dir .. "/history.nvim"
	vim.fn.mkdir(history_dir, "p")

	local filename = vim.fn.getcwd():gsub("/", "-"):gsub(" ", "_"):gsub("\\.", "-") .. ".json"

	local file = io.open(history_dir .. "/" .. filename, mode)

	return file
end

M.save_buffers = function()
	local bufs = {}
	for _, buf in ipairs(M.buffers) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
			table.insert(bufs, vim.api.nvim_buf_get_name(buf))
		end
	end

	local file = M.get_history_file()

	if not file then
		return
	end

	file:write(vim.fn.json_encode(bufs))
	file:close()
end

M.load_buffers = function()
	local file = M.get_history_file("r")

	if not file then
		return
	end

	local bufs = vim.fn.json_decode(file:read("*a"))
	file:close()

	for _, buf in ipairs(bufs) do
		vim.cmd("edit " .. buf)
		-- local bufnr = vim.fn.bufnr(buf)
		--       table.insert(M.buffers, bufnr)
	end
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
			callback = M.save_buffers,
		})
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = M.load_buffers,
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

	local function create_menu()
		local lines = {}

		for _, buf in ipairs(M.buffers) do
			if vim.api.nvim_buf_is_valid(buf) then
				local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
				if buftype ~= "nofile" then
					local name = vim.api.nvim_buf_get_name(buf)
					local cwd = vim.fn.getcwd()

					name = name:gsub(cwd .. "/", "")

					local item = Menu.item(name, { bufnr = buf })
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
