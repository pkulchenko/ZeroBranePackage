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

* [analyzeall.lua](analyzeall.lua): Analyzes all files in a project.
* [autodelimiter.lua](autodelimiter.lua): Adds auto-insertion of delimiters (), {}, [], '', and "".
* [autodelimitersurroundselection.lua](autodelimitersurroundselection.lua): Extends auto-insertion of delimiters (), {}, [], '', and "" to add selection and removal of standalone pairs.
* [autoindent.lua](autoindent.lua): Sets editor indentation based on file text analysis.
* [autostartdebug.lua](autostartdebug.lua): Auto-starts debugger server.
* [blockcursor.lua](blockcursor.lua): Switches cursor to a block cursor.
* [clippy.lua](clippy.lua): Enables a stack-based clipboard which saves the last 10 entries.
* [cloneview.lua](cloneview.lua): Clones the current editor tab.
* [closetabsleftright.lua](closetabsleftright.lua): Closes editor tabs to the left and to the right of the current one.
* [colourpicker.lua](colourpicker.lua): Selects color to insert in the document.
* [cuberite.lua](cuberite.lua): Implements integration with Cuberite - the custom C++ minecraft server.
* [documentmap.lua](documentmap.lua): Adds document map.
* [edgemark.lua](edgemark.lua): Marks column edge for long lines.
* [editorautofocusbymouse.lua](editorautofocusbymouse.lua): Moves focus to an editor tab the mouse is over.
* [eris.lua](eris.lua): Implements integration with the Lua + Eris interpreter (5.3).
* [escapetoquit.lua](escapetoquit.lua): Exits application on Escape.
* [extregister.lua](extregister.lua): Registers known extensions to launch the IDE on Windows.
* [filetreeoneclick.lua](filetreeoneclick.lua): Changes filetree to activate items on one-click (as in Sublime Text).
* [hidemenu.lua](hidemenu.lua): Hides and shows the menu bar when pressing alt.
* [hidemousewhentyping.lua](hidemousewhentyping.lua): Hides mouse cursor when typing.
* [highlightselected.lua](highlightselected.lua): Highlights all instances of a selected word.
* [launchtime.lua](launchtime.lua): Measures IDE startup performance up to the first IDLE event.
* [localhelpmenu.lua](localhelpmenu.lua): Adds local help option to the menu.
* [luadist.lua](luadist.lua): Provides LuaDist integration to install modules from LuaDist.
* [maketoolbar.lua](maketoolbar.lua): Adds a menu item and toolbar button that run `make`.
* [markchar.lua](markchar.lua): Marks characters when typed with specific indicators.
* [moonscript.lua](moonscript.lua): Implements integration with Moonscript language.
* [moonscriptlove.lua](moonscriptlove.lua): Implements integration with Moonscript with LÖVE.
* [moveline.lua](moveline.lua): Adds moving line or selection up or down using `Ctrl-Shift-Up/Down`.
* [noblinkcursor.lua](noblinkcursor.lua): Disables cursor blinking.
* [openimagefile.lua](openimagefile.lua): Opens image file from the file tree.
* [openra.lua](openra.lua): Adds API description for auto-complete and tooltip support for OpenRA.
* [openwithdefault.lua](openwithdefault.lua): Opens file with Default Program when activated.
* [outputclone.lua](outputclone.lua): Clones Output window to keep it on the screen when the application loses focus (OSX).
* [outputtofile.lua](outputtofile.lua): Redirects debugging output to a file.
* [overtype.lua](overtype.lua): Allows to switch overtyping on/off on systems that don't provide shortcut for that.
* [projectsettings.lua](projectsettings.lua): Adds project settings loaded on project switch.
* [realtimewatch.lua](realtimewatch.lua): Displays real-time values during debugging.
* [redbean.lua](redbean.lua): Adds integration and debugging for Redbean web server.
* [redis.lua](redis.lua): Integrates with Redis.
* [referencepanel.lua](referencepanel.lua): Adds a panel for showing documentation based on tooltips.
* [refreshproject.lua](refreshproject.lua): Refreshes project tree when files change (Windows only).
* [remoteedit.lua](remoteedit.lua): Allows to edit files remotely while debugging is in progress.
* [savealleveryxrunning.lua](savealleveryxrunning.lua): Saves all modified files every X seconds while running/debugging.
* [saveonappswitch.lua](saveonappswitch.lua): Saves all modified files when app focus is lost.
* [saveonfocuslost.lua](saveonfocuslost.lua): Saves a file when editor focus is lost.
* [screenshot.lua](screenshot.lua): Takes a delayed screenshot of the application window and saves it into a file.
* [shebangtype.lua](shebangtype.lua): Sets file type based on executable in shebang.
* [showluareference.lua](showluareference.lua): Adds 'show lua reference' option to the editor menu.
* [showreference.lua](showreference.lua): Adds 'show reference' option to the editor menu.
* [striptrailingwhitespace.lua](striptrailingwhitespace.lua): Strips trailing whitespaces before saving a file.
* [syntaxcheckontype.lua](syntaxcheckontype.lua): Reports syntax errors while typing (on `Enter`).
* [tasks.lua](tasks.lua): Provides project wide tasks panel.
* [teal.lua](teal.lua): Adds support for Teal, a typed Lua dialect that compiles to Lua.
* [tildemenu.lua](tildemenu.lua): Allows to enter tilde (~) on keyboards that may not have it.
* [todo.lua](todo.lua): Adds a panel for showing a tasks list.
* [todoall.lua](todoall.lua): Adds a project-wide panel for showing a tasks list.
* [torch7.lua](torch7.lua): Implements integration with torch7 environment.
* [uniquetabname.lua](uniquetabname.lua): Updates editor tab names to always stay unique.
* [urho3d.lua](urho3d.lua): Implements integration with Urho3D game engine.
* [verbosesaving.lua](verbosesaving.lua): Saves a copy of each file on save in a separate directory with date and time appended to the file name.
* [wordcount.lua](wordcount.lua): Counts the number of words and other statistics in the document.
* [wordwrapmenu.lua](wordwrapmenu.lua): Adds word wrap option to the menu.
* [xml.lua](xml.lua): Adds XML syntax highlighting.

## Author

Paul Kulchenko (paul@kulchenko.com)

## License

See [LICENSE](LICENSE).
