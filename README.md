# .NET C# CI/CD Pipeline with Installer Automation on GitLab

This repository contains configurations and scripts to automate building .NET C# projects and creating Windows installers using Inno Setup or WiX Toolset within a GitLab CI/CD pipeline, even when running GitLab on Linux.

## Overview

This setup helps you transition from Visual Studio Installer Projects (MSI installers) to Inno Setup or WiX, with automated builds through GitLab. The pipeline:

1. Builds your .NET C# project
2. Compiles an Inno Setup script to create a Windows installer
3. Archives and publishes the installer as an artifact

## Repository Structure

```
├── .gitlab-ci.yml        # GitLab CI/CD pipeline configuration
├── installer/
│   ├── inno/
│   │   └── setup.iss     # Inno Setup script template
│   └── wix/
│       └── Product.wxs   # WiX Toolset script template
├── src/                  # Your C# project source files
└── README.md             # This file
```

## Setup Instructions

### 1. Configure Your GitLab CI/CD Pipeline

Copy the provided `.gitlab-ci.yml` file to your repository:

```yaml
stages:
  - build
  - package

build_project:
  stage: build
  image: mcr.microsoft.com/dotnet/sdk:6.0
  script:
    - dotnet restore
    - dotnet build --configuration Release
    - dotnet publish --configuration Release --output ./publish
  artifacts:
    paths:
      - ./publish/
    expire_in: 1 day

create_installer:
  stage: package
  image: mono:latest
  dependencies:
    - build_project
  before_script:
    - apt-get update && apt-get install -y wget unzip wine64
    # Download Inno Setup
    - wget https://files.jrsoftware.org/is/6/innosetup-6.2.1.exe
    # Optional: Download icon editor tool if needed
    - wget https://github.com/electron/rcedit/releases/download/v1.1.1/rcedit-x64.exe
  script:
    # Install innoextract to extract Inno Setup
    - apt-get install -y innoextract
    - mkdir -p /opt/innosetup
    - innoextract innosetup-6.2.1.exe -d /opt/innosetup
    # Use wine to compile the Inno Setup script
    - cp -r ./publish /opt/innosetup/publish
    - cp ./installer/inno/setup.iss /opt/innosetup/
    - cd /opt/innosetup
    - wine ISCC.exe setup.iss
    # Copy the output back to the project
    - mkdir -p $CI_PROJECT_DIR/Output
    - cp -r Output/* $CI_PROJECT_DIR/Output/
  artifacts:
    paths:
      - ./Output/*.exe
    expire_in: 1 week
```

### 2. Choose and Configure Your Installer

#### Option A: Inno Setup Script

Create a file named `installer/inno/setup.iss` in your repository:

```
[Setup]
; NOTE: The value of AppId uniquely identifies this application
AppId={{YOUR-GUID-HERE}
AppName=MyApp
AppVersion=1.0
DefaultDirName={autopf}\MyApp
DefaultGroupName=MyApp
OutputDir=Output
OutputBaseFilename=MyAppSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{autoprograms}\MyApp"; Filename: "{app}\MyApp.exe"
Name: "{autodesktop}\MyApp"; Filename: "{app}\MyApp.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\MyApp.exe"; Description: "{cm:LaunchProgram,MyApp}"; Flags: nowait postinstall skipifsilent
```

#### Option B: WiX Toolset Script

Create a file named `installer/wix/Product.wxs` in your repository:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi" xmlns:ui="http://wixtoolset.org/schemas/v4/wxs/ui">
  <Product Id="*" Name="MyApp" Language="1033" Version="1.0.0.0" Manufacturer="Your Company" UpgradeCode="PUT-GUID-HERE">
    
    <Package InstallerVersion="200" Compressed="yes" InstallScope="perMachine" />

    <MajorUpgrade DowngradeErrorMessage="A newer version of [ProductName] is already installed." />
    <MediaTemplate />

    <Feature Id="ProductFeature" Title="MyApp" Level="1">
      <ComponentGroupRef Id="ProductComponents" />
      <ComponentRef Id="ProgramMenuDir"/>
    </Feature>

    <UI>
      <UIRef Id="WixUI_InstallDir" />
      <Property Id="WIXUI_INSTALLDIR" Value="INSTALLFOLDER" />
    </UI>
    
  </Product>

  <Fragment>
    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFilesFolder" Name="PFiles">
        <Directory Id="INSTALLFOLDER" Name="MyApp" />
      </Directory>
      <Directory Id="ProgramMenuFolder" Name="Programs">
        <Directory Id="ProgramMenuDir" Name="MyApp">
          <Component Id="ProgramMenuDir" Guid="PUT-GUID-HERE">
            <RemoveFolder Id='ProgramMenuDir' On='uninstall' />
            <RegistryValue Root='HKCU' Key='Software\[Manufacturer]\[ProductName]' Type='string' Value='' KeyPath='yes' />
          </Component>
        </Directory>
      </Directory>
      <Directory Id="DesktopFolder" Name="Desktop" />
    </Directory>
  </Fragment>

  <Fragment>
    <ComponentGroup Id="ProductComponents" Directory="INSTALLFOLDER">
      <!-- Add components for each file in your application -->
      <Component Id="MainExecutable" Guid="PUT-GUID-HERE">
        <File Id="MainExe" Name="MyApp.exe" Source="$(var.PublishDir)MyApp.exe" KeyPath="yes">
          <Shortcut Id="StartMenuShortcut" Directory="ProgramMenuDir" Name="MyApp" WorkingDirectory="INSTALLFOLDER" Icon="icon.ico" IconIndex="0" Advertise="yes" />
          <Shortcut Id="DesktopShortcut" Directory="DesktopFolder" Name="MyApp" WorkingDirectory="INSTALLFOLDER" Icon="icon.ico" IconIndex="0" Advertise="yes" />
        </File>
      </Component>
      <!-- Add additional components for other files -->
    </ComponentGroup>
  </Fragment>
</Wix>
```

Customize either script with your application details. Both formats support registry entries, shortcuts, and post-installation commands.

## GitLab CI/CD Configuration Options

### Option 1: Using Inno Setup with Linux Runner and Wine

This option uses Wine to compile Inno Setup scripts on Linux:

```yaml
create_inno_installer:
  stage: package
  image: mono:latest
  dependencies:
    - build_project
  before_script:
    - apt-get update && apt-get install -y wget unzip wine64 innoextract
    - wget https://files.jrsoftware.org/is/6/innosetup-6.2.1.exe
    - mkdir -p /opt/innosetup
    - innoextract innosetup-6.2.1.exe -d /opt/innosetup
  script:
    - cp -r ./publish /opt/innosetup/publish
    - cp ./installer/inno/setup.iss /opt/innosetup/
    - cd /opt/innosetup
    - wine ISCC.exe setup.iss
    - mkdir -p $CI_PROJECT_DIR/Output
    - cp -r Output/* $CI_PROJECT_DIR/Output/
  artifacts:
    paths:
      - ./Output/*.exe
    expire_in: 1 week
```

### Option 2: Using WiX with Linux Runner

This option uses WiX's Linux-compatible toolchain `wixl` for creating MSI installers:

```yaml
create_wix_installer:
  stage: package
  image: ubuntu:latest
  dependencies:
    - build_project
  before_script:
    - apt-get update && apt-get install -y msitools
  script:
    - mkdir -p ./Output
    # Replace placeholder values with actual data
    - sed -i 's/\$\(var\.PublishDir\)/\.\/publish\//g' installer/wix/Product.wxs
    - wixl -v installer/wix/Product.wxs -o ./Output/MyApp.msi
  artifacts:
    paths:
      - ./Output/*.msi
    expire_in: 1 week
```

### Option 3: Using a Windows Runner

If you have access to a Windows machine, you can register it as a GitLab runner to build both the C# project and the installer natively.

1. Install the GitLab Runner on a Windows machine
2. Register it with your GitLab instance
3. Use tags in your `.gitlab-ci.yml` to target this runner

Example addition to your `.gitlab-ci.yml`:

```yaml
# For Inno Setup
create_installer_windows_inno:
  stage: package
  tags:
    - windows
  dependencies:
    - build_project
  script:
    - iscc.exe installer/inno/setup.iss
  artifacts:
    paths:
      - .\Output\*.exe
    expire_in: 1 week

# For WiX
create_installer_windows_wix:
  stage: package
  tags:
    - windows
  dependencies:
    - build_project
  script:
    - nuget install WiX
    - .\WiX.*\tools\candle.exe -ext WixUIExtension installer/wix/Product.wxs -dPublishDir=publish\
    - .\WiX.*\tools\light.exe -ext WixUIExtension Product.wixobj -out .\Output\MyApp.msi
  artifacts:
    paths:
      - .\Output\*.msi
    expire_in: 1 week
```

## Advanced Configuration Tips

### Versioning

#### Inno Setup Versioning

Automatically update the installer version based on your CI/CD pipeline:

```
[Setup]
AppName=MyApp
AppVersion=$CI_COMMIT_TAG
; ... other settings ...
```

You can dynamically replace these values in your CI/CD pipeline:

```yaml
script:
  - sed -i "s/#define MyAppVersion \".*\"/#define MyAppVersion \"$CI_COMMIT_TAG\"/g" /opt/innosetup/setup.iss
  - cd /opt/innosetup
  - wine ISCC.exe setup.iss
```

#### WiX Versioning

For WiX, you can update the version in the CI/CD pipeline:

```yaml
script:
  - sed -i "s/Version=\"[0-9.]*\"/Version=\"$CI_COMMIT_TAG.0\"/g" installer/wix/Product.wxs
  - wixl -v installer/wix/Product.wxs -o ./Output/MyApp.msi
```

### Code Signing

#### Inno Setup Code Signing

```yaml
create_inno_installer:
  # ... previous configuration ...
  before_script:
    # ... previous before_script commands ...
    - mkdir -p /certs
    - echo "$CODE_SIGNING_CERT" | base64 -d > /certs/certificate.pfx
  script:
    # ... previous script commands ...
    - cd /opt/innosetup
    - wine ISCC.exe "/SSigning=yes /F/certs/certificate.pfx /P$CODE_SIGNING_PASSWORD" setup.iss
```

#### WiX Code Signing

For WiX, signing typically requires the Windows SignTool, which works best with a Windows runner:

```yaml
create_wix_installer_windows:
  # ... previous configuration ...
  script:
    # ... build MSI ...
    - '& "C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe" sign /f "$env:CODE_SIGNING_CERT" /p "$env:CODE_SIGNING_PASSWORD" /tr http://timestamp.digicert.com /td sha256 /fd sha256 ".\Output\MyApp.msi"'
```

### Storing Build Artifacts

Configure your pipeline to store installers in GitLab's package registry:

```yaml
create_installer:
  # ... previous configuration ...
  script:
    # ... previous script commands ...
    - 'curl --header "JOB-TOKEN: $CI_JOB_TOKEN" --upload-file ./Output/*.exe "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/my-app/${CI_COMMIT_TAG}/MyAppSetup.exe"'
```

For WiX-generated MSI files:

```yaml
script:
  # ... previous script commands ...
  - 'curl --header "JOB-TOKEN: $CI_JOB_TOKEN" --upload-file ./Output/*.msi "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/my-app/${CI_COMMIT_TAG}/MyApp.msi"'
```

## Dealing with Complex Dependencies

Both example installer scripts you provided include large numbers of dependencies. Here are strategies to manage them:

### For Inno Setup

When your application has many DLLs (like in your example), streamline the `[Files]` section with wildcard patterns:

```
[Files]
; Main executable and config files
Source: "publish\*.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\*.config"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\*.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\*.pdb"; DestDir: "{app}"; Flags: ignoreversion
; Include all subdirectories
Source: "publish\**"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
```

Or generate the file list programmatically in your CI/CD pipeline:

```yaml
script:
  - echo "[Files]" > file_list.iss
  - find ./publish -type f -exec echo "Source: \"{}\" ; DestDir: \"{app}\\$(dirname {} | sed 's/\.\\/publish\\///')\"; Flags: ignoreversion" \; >> file_list.iss
  - cat file_list.iss >> /opt/innosetup/setup.iss
  - cd /opt/innosetup
  - wine ISCC.exe setup.iss
```

### For WiX

When using WiX with many files (like in your example), you can:

1. Use a heat.exe command to automatically generate component lists:

```yaml
script:
  - .\WiX.*\tools\heat.exe dir publish -cg ProductComponents -dr INSTALLFOLDER -ke -srd -gg -sfrag -template fragment -out Components.wxs
  - .\WiX.*\tools\candle.exe -ext WixUIExtension installer/wix/Product.wxs Components.wxs
  - .\WiX.*\tools\light.exe -ext WixUIExtension Product.wixobj Components.wixobj -out .\Output\MyApp.msi
```

2. For Linux-based CI/CD with `wixl`, you can generate components with a script:

```yaml
script:
  - mkdir -p ./Output
  - cp installer/wix/Product.wxs ./Product.wxs
  - echo "<Wix xmlns=\"http://schemas.microsoft.com/wix/2006/wi\"><Fragment><ComponentGroup Id=\"ProductComponents\" Directory=\"INSTALLFOLDER\">" > Components.wxs
  - find ./publish -type f | while read file; do
      guid=$(uuidgen);
      id=$(basename "$file" | sed 's/[^a-zA-Z0-9]//g');
      echo "<Component Id=\"$id\" Guid=\"$guid\" Win64=\"yes\"><File Id=\"${id}File\" Name=\"$(basename "$file")\" DiskId=\"1\" Source=\"$file\" KeyPath=\"yes\" /></Component>" >> Components.wxs;
    done
  - echo "</ComponentGroup></Fragment></Wix>" >> Components.wxs
  - wixl -v Product.wxs Components.wxs -o ./Output/MyApp.msi
```

## Troubleshooting

- **Inno Setup Compilation Issues**: 
  - Running Inno Setup through Wine may have some limitations
  - Make sure paths in your Inno Setup script are relative to the /opt/innosetup directory
  - Test with a simplified script first to identify compatibility issues

- **WiX Compilation Issues**:
  - When using `wixl` on Linux, some Windows-specific features may not be supported
  - GUIDs need to be generated for components and products
  - Path separators should be consistent with the platform

- **Path Issues**: 
  - Use forward slashes in scripts when running on Linux
  - Use relative paths instead of absolute paths (like `C:\Users\...`)
  - For absolute paths in Windows runners, use variables like `$(var.ProjectDir)`

- **Mono Compatibility**:
  - Some .NET features might not be fully supported in Mono, test thoroughly
  - For .NET Core or .NET 5+ projects, use the .NET SDK Docker images

## Resources

- [Inno Setup Documentation](https://jrsoftware.org/ishelp/)
- [WiX Toolset Documentation](https://wixtoolset.org/documentation/)
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [WiX Toolset on Linux (wixl)](https://gitlab.gnome.org/GNOME/msitools)
- [innoextract](https://github.com/dscharrer/innoextract)
- [Wine HQ](https://www.winehq.org/)
