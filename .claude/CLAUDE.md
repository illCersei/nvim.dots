# Neovim-конфиг пользователя (~/.config/nvim)

Neovim **0.12.5**, плагин-менеджер — встроенный `vim.pack` (lock: `nvim-pack-lock.json`).
Репозиторий: `git@github.com:illCersei/nvim.dots.git`, ветка `main`.

## Правила работы
- **Никогда не коммитить и не пушить без явного разрешения.**
- Ничего не редактировать без разрешения, если просят «просто посмотреть».
- Пользователь — новичок в Codeforces; объяснять на базовом уровне.

## Структура
`init.lua` — порядок загрузки:
1. `require("vim._core.ui2").enable({})` — новый встроенный UI cmdline/сообщений (0.12)
2. `options` → `keymaps` → `commands` → `pack` → `treesitter` → `lsp` → `cf`
3. `colorscheme nightfox` (transparent = true)

| Файл | Что внутри |
|---|---|
| `lua/options.lua` | опции + подсветка при yank (`TextYankPost`) |
| `lua/keymaps.lua` | leader = пробел, общие маппинги |
| `lua/commands.lua` | `:PackAdd`, `:PackDel`, `:PackUpdate [plugins]` — обёртки над `vim.pack` |
| `lua/pack.lua` | список плагинов + настройка всех mini.* и fugitive |
| `lua/treesitter.lua` | nvim-treesitter (ветка `main`), `install()` + автозапуск по `FileType` |
| `lua/lsp.lua` | mason, capabilities от mini.completion, `vim.lsp.enable` |
| `lua/cf.lua` | Codeforces-workflow |
| `templates/template.cpp` | шаблон задачи CF (`solve()` + мультитест, маркер `CURSOR`) |

## Ключевые опции (`options.lua`)
- `number` + `relativenumber`, отступы 4 пробела (`expandtab`), `smartindent`, `nowrap`
- `laststatus = 3` (один глобальный статус-бар — **стандартный**, без плагинов)
- `guicursor = ""` — курсор всегда блок
- `clipboard += unnamedplus`, `undofile` в `stdpath("data")/undodir`, без swap/backup
- `ignorecase` + `smartcase`, `inccommand = split`, `splitbelow`/`splitright`, `scrolloff = 8`
- `completeopt = menuone,noselect,fuzzy,nosort`, `signcolumn = yes`, `colorcolumn = "0"`, `winborder = rounded`, `winbar = "%=%m %f"` (имя файла справа в каждом окне)

## Плагины (`pack.lua`)
- Темы: **nightfox** (активна), vim-moonfly-colors, tokyonight (установлены, не используются)
- `mini.nvim`: icons (+ mock nvim-web-devicons), files (preview справа), tabline, bracketed, bufremove, notify (только текст), cmdline (autocorrect off), surround,
  pick + extra, pairs, completion (LSP), snippets (+ friendly-snippets, LSP-сервер сниппетов), diff (git)
- nvim-treesitter (main), nvim-lspconfig, mason.nvim, vim-fugitive
- Автокоманда: при выходе в Normal принудительно закрываются сессии mini.snippets
  (иначе после undo остаются висящие плейсхолдеры).

## Маппинги (leader = `<Space>`)
**Общие (`keymaps.lua`):**
- `x p` — вставка поверх выделения без потери регистра; `<leader>d` (n/v) — удалить в `_`
- `i <C-c>` → `<Esc>`; `n <C-c>` → `:nohl`
- `v J`/`K` — двигать строки; `v <`/`>` — отступ с сохранением выделения
- `J` — join без сдвига курсора; `<C-d>`/`<C-u>`/`n`/`N` — с центрированием
- `<leader>s` — заменить слово под курсором по всему файлу
- `<leader>X` — `chmod +x %`; `<leader>re` — `:restart`; `<leader>u` — встроенный undotree

**Плагины (`pack.lua`):**
- `-` — mini.files; `<leader>-` — mini.files на текущем файле
  (внутри: `<CR>` войти, `L` войти+, `_` выйти, `H` выйти+)
- `<leader>pf` файлы, `<leader>pb` открытые буферы, `<leader>ps` grep слова под курсором, `<leader>vh` help,
  `<leader>xx` диагностика, `<leader>pk` keymaps — всё через mini.pick/extra
- Surround на префиксе **`gs`**: `gsa` добавить, `gsd` удалить, `gsr` заменить,
  `gsf`/`gsF` найти, `gsh` подсветить, `gsn` n_lines (встроенный `s` свободен)
- `]b`/`[b` (и прочие `]x`/`[x` из mini.bracketed) — след./пред. буфер; `<leader>bd` — закрыть буфер, не закрывая окно
- `<leader>gg` — fugitive на весь экран в новой вкладке; `<leader>gd` — `Gvdiffsplit`

**LSP (`lsp.lua`):** `gd` definition, `<leader>f` format, `<leader>e` float диагностики.
Серверы: lua_ls (globals `vim`), marksman, gopls, rust_analyzer, clangd. `virtual_text = true`.

**CF (`cf.lua`):**
- Новый файл с однобуквенным именем (`a.cpp`, `b.cpp`…) заполняется шаблоном,
  курсор ставится на место `CURSOR`, включается insert.
- `<leader>r` — сохранить, `g++ -std=c++17 -O2 -Wall -Wshadow`, запустить с `< input.txt`
  в нижнем терминале (высота 15; прошлый терминал закрывается). `input.txt` создаётся, если нет.
- `<leader>i` — открыть `input.txt` в vsplit (или перейти в уже открытое окно).

## Treesitter
Парсеры: c, cpp, go, rust, typescript, javascript, tsx, html, css, json, bash, http, dockerfile.

## История решений (не предлагать повторно)
- Индикатор NORMAL-режима **не нужен**: пробовали `mini.statusline` (не понравился внешний вид)
  и echo `-- NORMAL --` через `ModeChanged` — оба варианта отклонены. Статус-бар оставить стандартным.
- `df` раньше открывал диагностику и ломал встроенный `df<char>` → перенесено на `<leader>e`.
- Surround перенесён с `s*` на `gs*`, чтобы вернуть встроенный `s`.
- Известная мелочь: `<leader>r` ждёт `timeoutlen` из-за пересечения с `<leader>re`.
