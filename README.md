# history.nvim

![screenshot](https://github.com/lukeb06/history.nvim/blob/master/.github/screenshot.png)

### A Neovim plugin for viewing and navigating your recently visited buffers.

> Requires [nui.nvim](https://github.com/MunifTanjim/nui.nvim)

## Installation and Configuration

> with [lazy.nvim](https://lazy.folke.io/)

```lua
return {
	"lukeb06/history.nvim",
	dependencies = { "MunifTanjim/nui.nvim" },
	config = true,
	opts = {
		forward_key = "<Tab>", -- optional. key to open the UI. once opened, pressing this key will cycle forward through the buffer history.
		backward_key = "<S-Tab>", -- optional. this key does not open the UI, but will cycle backwards through the buffer history UI when open.
		width = "40%", -- optional. width of the UI, can be a percentage or a number.
		height = "60%", -- optional. height of the UI, can be a percentage or a number.
	},
}
```
