# history.nvim

![screenshot](https://github.com/lukeb06/history.nvim/blob/master/.github/screenshot.png)

### A Neovim plugin for viewing and navigating your recently visited buffers.

> Requires [nui.nvim](https://github.com/MunifTanjim/nui.nvim)

## Installation

> with [lazy.nvim](https://lazy.folke.io/)

```lua
return { "lukeb06/history.nvim", config = true }
```

## Configuration

```lua
opts = {
    forward_key = "<Tab>", -- key to open the UI. once opened, pressing this key will cycle forward through the buffer history.
    backward_key = "<S-Tab>" -- this key does not open the UI, but will cycle backwards through the buffer history UI when open.
}
```
