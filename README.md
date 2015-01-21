SwitchyOmega
============

Manage and switch between multiple proxies quickly & easily.

Chromium Extension
------------------
The project is available as a Chromium Extension.

You can try it on [Chrome Web Store](https://chrome.google.com/webstore/detail/padekgcemlokbadohgkifijomclgjgif),
or grab a packaged extension file for offline installation on the [Releases page](https://github.com/FelisCatus/SwitchyOmega/releases).

Please [report issues on the issue tracker.](https://github.com/FelisCatus/SwitchyOmega/issues)

Development status
------------------

## PAC generator
This project contains a PAC generating module called `omega-pac`, which handles
the profiles model and compile profiles into PAC scripts. This module is standalone
and can be published to npm when the documentation is ready.

## Options manager
The folder `omega-target` contains browser-independent logic for managing the
options and applying profiles. Every public method is well documented in the comments.
Functions related to browser are not included, and shall be implemented in subclasses
of the `omega-target` classes.

`omega-web` is a web-based configuration interface for various options and profiles.
The interface works great with `omega-target` as the back-end.

`omega-web` alone is incomplete and requires a file named `omega_target_web.js`
containing an angular module `omegaTarget`. The module contains browser-dependent
code to communicate with `omega-target` back-end, and other code retrieving
browser-related state and information.
See the `omega-target-chromium-extension/omega_target_web.coffee` file for an
example of such module.

## Targets
The `omega-target-*` folders should contain environment-dependent code such as
browser API calls.

Each target folder should contain an extended `OmegaTarget` object, which
contains subclasses of the abstract base classes like `Options`. The classes
contains implementation of the abstract methods, and can override other methods
at will.

A target can copy the files in `omega-web` into its build to provide a web-based
configuration interface. If so, the target must provide the `omega_target_web.js`
file as described in the Options manager section.

Additionally, each target can contain other files and resources required for the
target, such as background pages and extension manifests.

For now, only one target has been implemented: The Chromium Extension target.
This target allows the project to be used as a Chromium extension in most
Chromium-based browsers.

However, the project architecture allows more targets to be added in the future.
The first step would be adapting more browsers including Firefox. I don't have
time for that now. Feel free to open a pull request if you want to help.

## Translation

All translations are in the `omega-i18n` folder. For now, only `en` \(English\)
and `zh` \(简体中文\) translations are done. If you notice a translation issue
such as typo or bad spelling, please open an issue or a pull request.

You can also help to translate SwitchyOmega into your language. Just fork the
project and copy the `en` folder to a new folder named the locale code of your
choice. Then edit the `message.json` to provide translations. The file is in
[Chrome Extension Locale-Specific Messages Format](https://developer.chrome.com/extensions/i18n-messages).
Don't forget to open a pull request when you are done translating.

## Building the project

SwitchyOmega has migrated to use npm and grunt for building. Please note that
npm 2.x is required for this project.

To build the project:

    # Install node and npm first (make sure npm --version > 2.0), then:
    
    sudo npm install -g grunt-cli bower
    # In the project folder:
    cd omega-build
    npm run deps # This runs npm install in every module.
    npm run dev # This runs npm link to aid local development.
    # Note: the previous command may require sudo in some environments.
    # The modules are now working. We can build now:
    grunt
    # After building, a folder will be generated:
    cd .. # Return to project root.
    ls omega-chromium-extension/build/
    # The folder above can be loaded as an unpacked extension in Chromium now.

To enable `grunt watch`, run `grunt watch` once in the `omega-build` directory.
This will effectively run `grunt watch` in every module in this project.

License
-------
![GPLv3](https://www.gnu.org/graphics/gplv3-127x51.png)

SwitchyOmega is licensed under [GNU General Public License](https://www.gnu.org/licenses/gpl.html) Version 3 or later.

SwitchyOmega is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

SwitchyOmega is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with SwitchyOmega.  If not, see <http://www.gnu.org/licenses/>.
