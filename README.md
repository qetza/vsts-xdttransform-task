[![Donate](images/donate.png)](https://www.paypal.me/grouchon/5)

# XDT transform task
Visual Studio Team Services Build and Release extension that applies XDT transforms on XML files.

## Usage
Add a new task, select **XDT Transform** from the **Utility** category and configure it as needed.

![XDT Transform parameters](images/task-parameters.png)

Parameters include:
- **Working folder**: the working directory for relative paths. If not specified the default working directory will be used.
- **Transformations**: an absolute or relative comma or newline-separated transformation file rules.

> **Syntax**: {xdt path} => {xml path}[ => {output path}]  
>
> - `web.release.config => web.config` will apply _web.release.config_ to _web.config_ and update the file.  
> - `xdt\web.release.config => config\web.config => web.config` will apply _xdt\web.release.config_ to _config\web.config_ and save the result in _web.config_.
>
> **Wildcard support**
> - `*.release.config => *.config` will apply all _{filename}.release.config_ files to _{filename}.config_ and update the file.
> - `*.release.config => config\*.config => c:\tmp\*.config` will apply all _{filename}.release.config_ files to _config\\{filename}.config_ and save the result in _c:\tmp\\{filename}.config_.
>
> Transform pattern must start with _*_  
> Transform file search is recursive  
> Relative paths for source pattern and output pattern are relative to the transform file path.

## Tips
You can use the [XDT transform task](https://marketplace.visualstudio.com/items?itemName=qetza.xdttransform) to inject tokens in your XML based configuration files configured for local development and then use the [Replace Tokens task](https://marketplace.visualstudio.com/items?itemName=qetza.replacetokens) to replace those tokens with variable values:
- create an XDT transformation file containing your tokens
- setup your configuration file with local developement values
- at deployment time
  - inject your tokens in the configuration file by using your transformation file
  - replace tokens in your updated configuration file

## Debug
You can set the variable `system.debug` to `true` to enable the debug logging on the task to help you investigate unexpected behavior of the task. 
If you cannot fix your issue, open an issue on the github repo and i'll help you :)

# Release notes
**New in 3.1.0**
- Update VstsTaskSdk to 0.11.0 ([#24](https://github.com/qetza/vsts-xdttransform-task/issues/24)).
- Update Microsoft.Web.XmlTransform.dll to 3.1.0 (contributed by [livioc](https://github.com/livioc))

**New in 3.0.0**
- Add support for wildcard in transformation rules ([#8](https://github.com/qetza/vsts-xdttransform-task/issues/8)) (contributed by [Luuk Sommers](https://github.com/luuksommers))

**New in 2.1.0**
- Add support for comma separator in _Transformations_ parameters.

**New in 2.0.0**
- **Breaking change**: All previous parameters are now merged in a single line using syntax `{xdt path} => {xml path}[ => {output path}]`.
- Add support for multiple transformations.
- Add _Working folder_ parameter for root of relative paths.

**New in 1.0.0**
- Initial release
