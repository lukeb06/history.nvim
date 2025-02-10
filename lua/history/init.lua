local M = {}

M.setup = function(opts)
	local buffers = {}

	-- local forward_key = "<Tab>"
	-- local backward_key = "<S-Tab>"

	opts = opts
		or {
			forward_key = "<Tab>",
			backward_key = "<S-Tab>",
			position = "50%",
			size = {
				width = "40%",
				height = "60%",
			},
		}

	local forward_key = opts.forward_key or "<Tab>"
	local backward_key = opts.backward_key or "<S-Tab>"
	local position = opts.position or "50%"
	local size = opts.size or {
		width = "40%",
		height = "60%",
	}

	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function()
			local bufnr = vim.fn.bufnr("%")
			local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
			if buftype ~= "nofile" then
				for i, buf in ipairs(buffers) do
					if buf == bufnr then
						table.remove(buffers, i)
					end
				end

				table.insert(buffers, bufnr)
			end
		end,
	})

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

		for _, buf in ipairs(buffers) do
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
			position = position,
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
