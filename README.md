SwitchyOmega
============

A proxy extension for Chromium.

Development status
==================

## Chromium Extension
The project is now usable as a Chromium Extension.

You can try it on [Chrome Web Store](https://chrome.google.com/webstore/detail/padekgcemlokbadohgkifijomclgjgif)

## Development Schedule
The project is now in alpha, and still considered unstable. Any feedback is
welcomed.

Please [report issues on the issue tracker.](https://github.com/FelisCatus/SwitchyOmega/issues)

## Build

SwitchyOmega has migrated to use npm and grunt for building.

To build the project:

    # Install node and npm first, then:
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
=======
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
