# [1.1.0](https://github.com/chriskievit/ampersand/compare/v1.0.0...v1.1.0) (2026-10-13)


### Features

* **release:** ship a drag-to-install DMG ([#2](https://github.com/chriskievit/ampersand/issues/2)) ([62ec765](https://github.com/chriskievit/ampersand/commit/62ec7651a22aae349967a4e211e7c3a40161b27b)), closes [#1](https://github.com/chriskievit/ampersand/issues/1)

# 1.0.0 (2026-10-13)


### Bug Fixes

* apply backpressure to pty output; show ports and pids without locale grouping ([7fe6951](https://github.com/chriskievit/ampersand/commit/7fe6951b0500847c0d59b57f38d741808f90e137))
* **core:** batch output before it leaves the supervisor ([9a0555d](https://github.com/chriskievit/ampersand/commit/9a0555dc5270f2950fc8647147e72519fd133e55))
* **core:** identify tracked process groups by leader start time ([fed7746](https://github.com/chriskievit/ampersand/commit/fed77465057b0f5d8fff130d54e69e3d92453e83))
* quit waits for stopping, deleted and Run Once processes ([0a86d94](https://github.com/chriskievit/ampersand/commit/0a86d941baeed6977afdaf5b2c2b6937f195ff82))
* **ui:** finish-review fixes — reduce-motion crossfade, invalid env rows marked and held back, footer and notice polish ([d73c9a9](https://github.com/chriskievit/ampersand/commit/d73c9a9da3f6813d13c4ceedadd56f880082ee64))
* **ui:** keep window notices inside the detail pane; env errors only in the Environment section ([bff1787](https://github.com/chriskievit/ampersand/commit/bff178714bf1509805e53107b62c374f2ef9b148))
* **ui:** notice buttons keep their size next to long messages ([62cdd52](https://github.com/chriskievit/ampersand/commit/62cdd52f5a8a5919528cd6d27862e3d86eac4dfe))
* **ui:** popover opens on the row that needs attention; native selection, adaptive footer, No Group header ([aa00071](https://github.com/chriskievit/ampersand/commit/aa00071c974d02006468b6a0da7557b9e8dd9ab2))
* **ui:** size the popover list to its content ([ec06625](https://github.com/chriskievit/ampersand/commit/ec06625cbaef09e2a5b9cc122e3354b57b648fd8))
* **ui:** stop the empty suggestions panel from covering the popover list ([a4187a8](https://github.com/chriskievit/ampersand/commit/a4187a82f88e0ef7671935e0d2738a2f56f80537))
* **ui:** surface errors and port conflicts in the window, complete menu bar, drop ⌘⌫ delete ([470239d](https://github.com/chriskievit/ampersand/commit/470239d362b4555b5a6261270448bc68bf8d793b))


### Features

* add Liquid Glass app icon ([2f939f8](https://github.com/chriskievit/ampersand/commit/2f939f8c9a1818366609bae2d5379d68bda6304a))
* **app:** add app model, supervisors wiring, notifications and quit flow ([346a7f8](https://github.com/chriskievit/ampersand/commit/346a7f87f363b479ef3f888992ba2f82f6b36ecc))
* **app:** add command bar popover and menu bar icon ([dbaed1a](https://github.com/chriskievit/ampersand/commit/dbaed1ac8d2ee1677620b0b33fdd370d9102115a))
* **app:** add command editor, settings tab and project import ([d5ca0f4](https://github.com/chriskievit/ampersand/commit/d5ca0f4ef9329ac7156712aed20f1825562ac74b))
* **app:** add main window with sidebar and ANSI log view ([d7887dd](https://github.com/chriskievit/ampersand/commit/d7887dd07096b39db6af807dae9c9aa76e047ca5))
* **app:** add menu commands, settings window and undo ([bc08218](https://github.com/chriskievit/ampersand/commit/bc08218206b43e945e3d6a06dcafef2ceccf4808))
* **core:** add .env text parser ([afb458b](https://github.com/chriskievit/ampersand/commit/afb458b294c2793b46c908ed7e7a20f4a2ca09be))
* **core:** add bounded log line buffer ([99d155f](https://github.com/chriskievit/ampersand/commit/99d155f7608b94932465ac8803fdd15855440d78))
* **core:** add command draft with suggestion and validation rules ([245f1b6](https://github.com/chriskievit/ampersand/commit/245f1b6ce8772abeb2d727abd0dcc588b7231627))
* **core:** add command models and config store ([f117050](https://github.com/chriskievit/ampersand/commit/f117050e8f7168076d194bfc525a9234ac9c6e95))
* **core:** add pure config editing operations ([bef96eb](https://github.com/chriskievit/ampersand/commit/bef96eb41a895e51003b08cd43d4ccd20f002bbb))
* **core:** add restart backoff policy ([17e48f7](https://github.com/chriskievit/ampersand/commit/17e48f769a732713d891d7ba4acf44af28e366d5))
* **core:** add TCP/HTTP health checks and port owner probe ([4f66d97](https://github.com/chriskievit/ampersand/commit/4f66d979ae26a9e4294a5cfb7a4baee4695508b9))
* **core:** add tested status and metric copy ([4364e30](https://github.com/chriskievit/ampersand/commit/4364e30300358cc0563f44f9a7496fab91add07f))
* **core:** clean up process groups left by a crashed session ([15388d1](https://github.com/chriskievit/ampersand/commit/15388d12692bc351fd9a4a063a5e54c427211170))
* **core:** detect package.json scripts in a project folder ([8945987](https://github.com/chriskievit/ampersand/commit/8945987fb52a7e43e566c9d9b1a2c04102a1e9a8))
* **core:** ordered env pairs and .env serialization ([51f20f5](https://github.com/chriskievit/ampersand/commit/51f20f5bdf0861795f6caef96d1feb28ae3b0a36))
* **core:** parse ANSI SGR sequences into styled runs ([d35fe9d](https://github.com/chriskievit/ampersand/commit/d35fe9d827256316046d58f2194db0640fd5458a))
* **core:** parse pasted command lines into suggestions ([5111efd](https://github.com/chriskievit/ampersand/commit/5111efd2aadf4e6913f2cc9b7d29854fab55f154))
* **core:** sample CPU and memory per process group ([b61747a](https://github.com/chriskievit/ampersand/commit/b61747a659b78ea57c032248c111cb104271b60f))
* **core:** spawn commands on a pty in their own process group ([276ece2](https://github.com/chriskievit/ampersand/commit/276ece21707028081595059a6b396815240b8e4f))
* **core:** supervise commands with restart backoff ([53c8bc5](https://github.com/chriskievit/ampersand/commit/53c8bc5ba1f8cb6ab5c29ffdd9bb3278f09c628b))
* treat a clean exit as finished, not a crash ([ab6fff8](https://github.com/chriskievit/ampersand/commit/ab6fff8554074cfa3030f6f2dcc6a240665a40ad))
* **ui:** native environment list with import; Quit counts live processes; popover keys work after Tab ([7ba68a8](https://github.com/chriskievit/ampersand/commit/7ba68a8335b28e8f22984bb88b49acc6bf1cc650))
* **ui:** native window: grouped auto-applying settings, searchable sidebar, toolbar menus, native notices ([1f7d22d](https://github.com/chriskievit/ampersand/commit/1f7d22d4fc227b2138d66b900edc4bcb26dcea47))
