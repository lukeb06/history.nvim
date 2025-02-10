# history.nvim

A Neovim plugin for viewing and navigating your recently visited buffers.

## Installation

(with lazy.nvim)

```lua
return { "lukeb06/history.nvim", config = true, opts = {
	forward_key = "<Tab>",
	backward_key = "<S-Tab>",
} }
```
