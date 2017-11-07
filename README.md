# Project Description

ZeroBrane Package is a collection of packages for [ZeroBrane Studio](http://studio.zerobrane.com).

You can find more information about ZeroBrane Studio packages and plugins in the [documentation](http://studio.zerobrane.com/doc-plugin.html).

## Installation

To install a plugin, copy its `.lua` file to `ZBS/packages/` or `HOME/.zbstudio/packages/` folder
(where `ZBS` is the path to ZeroBrane Studio location and `HOME` is the path specified by the `HOME` environment variable).
The first location allows you to have per-instance plugins, while the second allows to have per-user plugins.
The second option may also be **preferrable for Mac OSX users** as the `ZBS/packages/` folder may be overwritten during an application upgrade.

## Dependencies

The plugins may depend on a particular version of ZeroBrane Studio.
One of the fields in the plugin description is `dependencies` that may have as its value
(1) a table with various dependencies or (2) a minumum version number of ZeroBrane Studio required to run the plugin.

If the version number for ZeroBrane Studio is **larger than the most recent released version** (for example, the current release version is 0.50, but the plugin has a dependency on 0.51),
this means that it requires a development version currently being worked on (which will become the next release version).

## Package List

* [analyzeall.lua](analyzeall.lua): Analyzes all files in a project. (v0.42)
* [autodelimiter.lua](autodelimiter.lua): Adds auto-insertion of delimiters (), {}, [], '', and "". (v0.2)
* [autodelimitersurroundselection.lua](autodelimitersurroundselection.lua): Extends auto-insertion of delimiters (), {}, [], '', and "" to add selection and removal of standalone pairs. (v0.41)
* [autoindent.lua](autoindent.lua): Sets editor indentation based on file text analysis. (v0.1)
* [autostartdebug.lua](autostartdebug.lua): Auto-starts debugger server. (v0.21)
* [blockcursor.lua](blockcursor.lua): Switches cursor to a block cursor. (v0.2)
* [clippy.lua](clippy.lua): Enables a stack-based clipboard which saves the last 10 entries. (v0.22)
* [cloneview.lua](cloneview.lua): Clones the current editor tab. (v0.15)
* [closetabsleftright.lua](closetabsleftright.lua): Closes editor tabs to the left and to the right of the current one. (v0.1)
* [colourpicker.lua](colourpicker.lua): Selects color to insert in the document. (v0.23)
* [cuberite.lua](cuberite.lua): Implements integration with Cuberite - the custom C++ minecraft server. (v0.52)
* [documentmap.lua](documentmap.lua): Adds document map. (v0.3)
* [edgemark.lua](edgemark.lua): Marks column edge for long lines. (v0.2)
* [editorautofocusbymouse.lua](editorautofocusbymouse.lua): Moves focus to an editor tab the mouse is over. (v0.1)
* [eris.lua](eris.lua): Implements integration with the Lua + Eris interpreter (5.3). (v0.11)
* [escapetoquit.lua](escapetoquit.lua): Exits application on Escape. (v0.1)
* [extregister.lua](extregister.lua): Registers known extensions to launch the IDE on Windows. (v0.2)
* [filetreeoneclick.lua](filetreeoneclick.lua): Changes filetree to activate items on one-click (as in Sublime Text). (v0.2)
* [highlightselected.lua](highlightselected.lua): Highlights all instances of a selected word. (v0.18)
* [livecodingtoolbar.lua](livecodingtoolbar.lua): Adds livecoding toolbar button. (v0.1)
* [localhelpmenu.lua](localhelpmenu.lua): Adds local help option to the menu. (v0.3)
* [luadist.lua](luadist.lua): Provides LuaDist integration to install modules from LuaDist. (v0.2)
* [maketoolbar.lua](maketoolbar.lua): Adds a menu item and toolbar button that run `make`. (v0.31)
* [markchar.lua](markchar.lua): Marks characters when typed with specific indicators. (v0.1)
* [moonscript.lua](moonscript.lua): Implements integration with Moonscript language. (v0.35)
* [moonscriptlove.lua](moonscriptlove.lua): Implements integration with Moonscript with LÖVE. (v0.33)
* [moveline.lua](moveline.lua): Adds moving line or selection up or down using `Ctrl-Shift-Up/Down`. (v0.11)
* [noblinkcursor.lua](noblinkcursor.lua): Disables cursor blinking. (v0.2)
* [openimagefile.lua](openimagefile.lua): Opens image file from the file tree. (v0.2)
* [openra.lua](openra.lua): Adds API description for auto-complete and tooltip support for OpenRA. (v20161019a)
* [openwithdefault.lua](openwithdefault.lua): Opens file with Default Program when activated. (v0.2)
* [outputclone.lua](outputclone.lua): Clones Output window to keep it on the screen when the application loses focus (OSX). (v0.41)
* [outputtofile.lua](outputtofile.lua): Redirects debugging output to a file. (v0.1)
* [overtype.lua](overtype.lua): Allows to switch overtyping on/off on systems that don't provide shortcut for that. (v0.31)
* [projectsettings.lua](projectsettings.lua): Adds project settings loaded on project switch. (v0.2)
* [realtimewatch.lua](realtimewatch.lua): Displays real-time values during debugging. (v0.3)
* [redis.lua](redis.lua): Integrates with Redis. (v0.31)
* [referencepanel.lua](referencepanel.lua): Adds a panel for showing documentation based on tooltips. (v0.2)
* [refreshproject.lua](refreshproject.lua): Refreshes project tree when files change (Windows only). (v0.21)
* [remoteedit.lua](remoteedit.lua): Allows to edit files remotely while debugging is in progress. (v0.13)
* [savealleveryxrunning.lua](savealleveryxrunning.lua): Saves all modified files every X seconds while running/debugging. (v0.2)
* [saveonappswitch.lua](saveonappswitch.lua): Saves all modified files when app focus is lost. (v0.11)
* [saveonfocuslost.lua](saveonfocuslost.lua): Saves a file when editor focus is lost. (v0.11)
* [screenshot.lua](screenshot.lua): Takes a delayed screenshot of the application window and saves it into a file. (v0.11)
* [shebangtype.lua](shebangtype.lua): Sets file type based on executable in shebang. (v0.1)
* [showluareference.lua](showluareference.lua): Adds 'show lua reference' option to the editor menu. (v0.2)
* [showreference.lua](showreference.lua): Adds 'show reference' option to the editor menu. (v0.3)
* [striptrailingwhitespace.lua](striptrailingwhitespace.lua): Strips trailing whitespaces before saving a file. (v0.1)
* [syntaxcheckontype.lua](syntaxcheckontype.lua): Reports syntax errors while typing (on `Enter`). (v0.41)
* [tildemenu.lua](tildemenu.lua): Allows to enter tilde (~) on keyboards that may not have it. (v0.21)
* [todo.lua](todo.lua): Adds a panel for showing a tasks list. (v1.23)
* [todoall.lua](todoall.lua): Adds a project-wise panel for showing a tasks list. (v0.1)
* [torch7.lua](torch7.lua): Implements integration with torch7 environment. (v0.58)
* [uniquetabname.lua](uniquetabname.lua): Updates editor tab names to always stay unique. (v0.1)
* [urho3d.lua](urho3d.lua): Urho3D game engine integration. (v0.41)
* [verbose_saving.lua](verbose_saving.lua): Saves a copy of each file on save in a separate directory with date and time appended to the file name. (v1)
* [wordcount.lua](wordcount.lua): Counts the number of words and other statistics in the document. (v0.1)
* [wordwrapmenu.lua](wordwrapmenu.lua): Adds word wrap option to the menu. (v0.21)
* [xml.lua](xml.lua): Adds XML syntax highlighting. (v0.21)

## Author

Paul Kulchenko (paul@kulchenko.com)

## License

See [LICENSE](LICENSE).
