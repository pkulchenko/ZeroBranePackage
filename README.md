# Project Description

ZeroBrane Package is a collection of packages for [ZeroBrane Studio](http://studio.zerobrane.com).

You can find more information about ZeroBrane Studio packages and plugins in the [documentation](http://studio.zerobrane.com/doc-plugin.html).

## Installation

To install a plugin, copy its `.lua` file to `ZBS/packages/` or `HOME/.zbstudio/packages` folder
(where `ZBS` is the path to ZeroBrane Studio location and `HOME` is the path specified by the `HOME` environment variable).
The first location allows you to have per-instance plugins, while the second allows to have per-user plugins.
The second option may also be **preferrable for Mac OS X users** as the `packages/` folder may be overwritten during an application upgrade.

## Dependencies

The plugins may depend on a particular version of ZeroBrane Studio.
One of the fields in the plugin description is `dependencies` that may have as its value
(1) a table with various dependencies or (2) a minumum version number of ZeroBrane Studio required to run the plugin.

If the version number for ZeroBrane Studio is **larger than the most recent released version** (for example, the current release version is 0.50, but the plugin has a dependency on 0.51),
this means that it requires a development version currently being working on (which will become the next release version).

## Author

Paul Kulchenko (paul@kulchenko.com)

## License

See LICENSE file
