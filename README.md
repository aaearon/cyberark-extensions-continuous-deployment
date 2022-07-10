# cyberark-extensions-continuous-deployment

A simple proof of concept in regards to integrating CyberArk extensions into a continuous deployment workflow using GitHub Actions.

See the accompanying blog post about doing continuous deployment with CPM plugins [here](https://timschindler.blog/cyberark-central-policy-manager-platforms-and-plugins-with-continuous-deployment).

## How it works

Any time a release is created on GitHub, all the files for all the platforms under the `platforms` folder are deployed to the Vault defined in `deploy.ps1`. This can be tweaked in `platform-deploy.yml`.

The two required platform files (CPM policy file and PVWA settings file) must be named `Policy-$PlatformId.ini` and `Policy-$PlatformId.xml` accordingly. Both files must be in a folder under `platforms` whose name must match the PlatformId (defined as `PolicyID` in `Policy-$PlatformId.ini` and the `ID` attribute in `Policy-$PlatformId.xml` in the appropriate element). Any optional files included in the folder will be uploaded to the Vault as long as the platform was imported through the PVWA or REST API.

The CPM policy file will be added under the `root\Policies` folder in the `PasswordManagerShared` safe and the content of the PVWA settings file will be merged into the Vault's `Policies.xml` file in the `PVWAConfig` safe. Any optional files will be uploaded to the platform's folder (`root\ImportedPlatforms\Policy-$PlatformId`) in the `PasswordManagerShared` safe and the CPM will deploy the files to the `bin` folder of all the CPMs as long as the platform's folder exists (only for platforms that were imported.)

## Setup

Set up a [self-hosted runner](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners) on a Windows machine that has [PoShPACLI](https://github.com/pspete/PoShPACLI) installed.
