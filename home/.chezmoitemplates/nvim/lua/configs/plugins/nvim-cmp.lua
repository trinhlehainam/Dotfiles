local cmp = require("cmp")

local luasnip = require("luasnip")
luasnip.config.setup()

local lspkind = require("lspkind")

local sources = {
	{ name = "git" },
	{ name = "nvim_lsp" },
	{ name = "luasnip" }, -- For luasnip users.
	{ name = "buffer" },
	{ name = "path" },
	{ name = "crates" },
}

if vim.fn.has("nvim-0.10.0") == 1 then
	table.insert(sources, {
		name = "lazydev",
		group_index = 0, -- set group index to 0 to skip loading LuaLS completions
	})
end

cmp.setup({
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},
	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},
	mapping = cmp.mapping.preset.insert({
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete({}),
		["<CR>"] = cmp.mapping.confirm({
			behavior = cmp.ConfirmBehavior.Replace,
			select = true,
		}),
		-- Use [C-p] and [C-n] for navigate backward and forward
		-- ['<Tab>'] = cmp.mapping(function(fallback)
		--   if cmp.visible() then
		--     cmp.select_next_item()
		--   elseif luasnip.expand_or_jumpable() then
		--     luasnip.expand_or_jump()
		--   else
		--     fallback()
		--   end
		-- end, { 'i', 's' }),
		-- ['<S-Tab>'] = cmp.mapping(function(fallback)
		--   if cmp.visible() then
		--     cmp.select_prev_item()
		--   elseif luasnip.jumpable(-1) then
		--     luasnip.jump(-1)
		--   else
		--     fallback()
		--   end
		-- end, { 'i', 's' }),

		-- Think of <c-l> as moving to the right of your snippet expansion.
		--  So if you have a snippet that's like:
		--  function $name($args)
		--    $body
		--  end
		--
		-- <c-l> will move you to the right of each of the expansion locations.
		-- <c-h> is similar, except moving you backwards.
		["<C-l>"] = cmp.mapping(function()
			if luasnip.expand_or_locally_jumpable() then
				luasnip.expand_or_jump()
			end
		end, { "i", "s" }),
		["<C-h>"] = cmp.mapping(function()
			if luasnip.locally_jumpable(-1) then
				luasnip.jump(-1)
			end
		end, { "i", "s" }),
	}),
	sources = {
		{ name = "git" },
		{ name = "nvim_lsp" },
		{ name = "luasnip" }, -- For luasnip users.
		{ name = "buffer" },
		{ name = "path" },
		{ name = "crates" },
	},
	formatting = {
		format = lspkind.cmp_format({
			before = function(entry, vim_item)
				local hastailwindtools, tailwindtools = pcall(require, "tailwind-tools.cmp")

				if not hastailwindtools then
					return vim_item
				end

				return tailwindtools.lspkind_format(entry, vim_item)
			end,
		}),
	},
})

require("cmp_git").setup()
--

-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline({ "/", "?" }, {
	mapping = cmp.mapping.preset.cmdline(),
	sources = {
		{ name = "buffer" },
	},
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(":", {
	mapping = cmp.mapping.preset.cmdline(),
	sources = cmp.config.sources({
		{ name = "path" },
	}, {
		{ name = "cmdline" },
	}),
	matching = { disallow_symbol_nonprefix_matching = false },
})
