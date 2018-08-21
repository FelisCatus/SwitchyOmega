SwitchyOmega
============

Manage and switch between multiple proxies quickly & easily.

[![Translation status](https://hosted.weblate.org/widgets/switchyomega/-/svg-badge.svg)](https://hosted.weblate.org/engage/switchyomega/?utm_source=widget)

Chromium Extension
------------------
The project is available as a Chromium Extension.

You can try it on [Chrome Web Store](https://chrome.google.com/webstore/detail/padekgcemlokbadohgkifijomclgjgif),
or grab a packaged extension file (CRX) for offline installation on the [Releases page](https://github.com/FelisCatus/SwitchyOmega/releases).

Please [report issues on the issue tracker.](https://github.com/FelisCatus/SwitchyOmega/issues)

Firefox Addon (Experimental)
----------------------------

There is also an experimental WebExtension port, which allows installing in
**Firefox Nightly Version >= 56**.

**Since the WebExtensions API is still under heavy development on Mozilla's side,
we strongly recommended using the Nightly channel (>= 56.0) and update frequently.**

The Developer Edition and Beta channels will not receive fixes as often and
therefore unsupported by SwitchyOmega. Some users report that it works with the
Firefox Developer Edition (>= 55) as well, but we strongly advise against doing
so. It won't work at all in Firefox 54 Stable.

You can try it on [Mozilla Add-ons](https://addons.mozilla.org/en-US/firefox/addon/switchyomega/),
or grab a packaged extension file (XPI) for offline installation on the [Releases page](https://github.com/FelisCatus/SwitchyOmega/releases).

Please make sure that you are using the latest Nightly build before you
[report issues](https://github.com/FelisCatus/SwitchyOmega/issues).
Build number AND build date should be mentioned somewhere in the issue.

NOTE: PAC Profiles DO NOT work on Firefox due to AMO review policies. We will see what we can do.

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

For now, only one target has been implemented: The WebExtension target.
This target allows the project to be used as a Chromium extension in most
Chromium-based browsers and also as a Firefox Addon as mentioned above.

## Translation

Translation is hosted on Weblate. If you want to help improve the translated
text or start translation for your language, please follow the link of the picture
below.

本项目翻译由Weblate托管。如果您希望帮助改进翻译，或将本项目翻译成一种新的语言，请
点击下方图片链接进入翻译。

[![Translation status](https://hosted.weblate.org/widgets/switchyomega/-/287x66-white.png)](https://hosted.weblate.org/engage/switchyomega/?utm_source=widget)

## Building the project

SwitchyOmega has migrated to use npm and grunt for building. Please note that
npm 2.x is required for this project.

To build the project:

    # Install node and npm first (make sure npm --version > 2.0), then:
    
    sudo npm install -g grunt-cli@1.2.0 bower
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

Notice
------

SwitchyOmega currently does not have a dedicated project homepage. `switchyomega.com` and similar webites are NOT affiliated with the SwitchyOmega project in any way, nor are they maintained by SwitchyOmega project members. Please refer to this Github repository and wiki for official information.

SwitchyOmega is not cooperating with any proxy providers, VPN providers or ISPs at the moment. No advertisement is displayed in SwitchyOmega project or software. Proxy providers are welcome to recommend SwitchyOmega as part of the solution in tutorials, but it must be made clear that SwitchyOmega is an independent project, is not affiliated with the provider and therefore cannot provide any support on network connections or proxy technology.

重要声明
--------

SwitchyOmega 目前没有专门的项目主页。 `switchyomega.com` 等网站与 SwitchyOmega 项目并无任何关联，也并非由 SwitchyOmega 项目成员维护。一切信息请以 Github 上的项目和 wiki 为准。

SwitchyOmega 目前未与任何代理提供商、VPN提供商或 ISP 达成任何合作协议，项目或软件中不包含任何此类广告。欢迎代理提供商在教程或说明中推荐 SwitchyOmega ，但请明确说明此软件是独立项目，与代理提供商无关，且不提供任何关于网络连接或代理技术的支持。
