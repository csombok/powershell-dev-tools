# Overview
PowerShell productivity tools for development

# How to setup

This tool is a self-contained PowerShell module. It can be used by explicitly installing to user's PowerShell module directory.

[Please find details here how to install custom PowerShell modules.](https://msdn.microsoft.com/en-us/library/dd878350(v=vs.85).aspx)


# Tools

## Compare NPM dependecies

This tool is suppused to compare *npm* dependencies in a source and a destination package.json. 
By using this tool it's easy to higlight version mismatches.

```PowerShell
# Simple compare 
npmCompare c:\examples\first\package.json c:\examples\second\package.json

# Include DEV dependecies
npmCompare c:\examples\first\package.json c:\examples\second\package.json -IncludeDevDeps

# Show mathcing entries as well
npmCompare c:\examples\first\package.json c:\examples\second\package.json -IncludeEquals
```

**Example output:**
```
Name                                          Type         SourceVersion DestinationVersion
----                                          ----         ------------- ------------------
@google-cloud/bigquery                        dependencies 1.0.0         ^0.9.6
@google-cloud/datastore                       dependencies 1.1.0         1.0.4
async                                         dependencies 2.6.0         2.3.0
body-parser                                   dependencies 1.18.2
cors                                          dependencies 2.8.4
debug                                         dependencies 3.1.0         2.6.8
es6-promise                                   dependencies 4.2.2
express                                       dependencies 4.16.2
helmet                                        dependencies 3.9.0
parseurl                                      dependencies 1.3.2
path-to-regexp                                dependencies 2.1.0
serve-static                                  dependencies 1.13.1
strict-transport-security                     dependencies 0.2.1
uuid                                          dependencies 3.2.1         3.1.0
```

### Paremeters

- **SourceNpm**: Path of the *package.json* file to be used as the *source* of the comparison
- **DestinationNpm**: Path of the *package.json* file to be used as *destination* of the comparison
- **Filter**: Filter the package name
- **IncludeEqual**: Include matching packages
- **IncludeDevDeps**: Include *devDependencies* in comparison
- **ShowMismatchOnly**: Show package version mismatch only in the result


## Compare DLLs in source directories

This tool is suppused to compare dlls in a source and a destination folders. 
By using this tool it's easy to higlight version mismatches and missing references.

```PowerShell
# Simple compare 
dllCompare c:\examples\first c:\examples\second\

# Use filter
dllCompare c:\examples\first c:\examples\second\ -Filter Microsoft*

# Analyze file versions
dllCompare c:\examples\first c:\examples\second\ -CompareVersion
```

**Example output:**

```
Name                              FileVersion  SideIndicator
----                              -----------  -------------
Hangfire.Core.resources.dll       1.6.8.0      =>
Hangfire.Core.dll                 1.6.8.0      =>
Hangfire.SqlServer.dll            1.6.8.0      =>
Hangfire.SqlServer.dll            0.0.0.0      =>
Microsoft.Owin.dll                3.0.30819.47 =>
Microsoft.Owin.Host.SystemWeb.dll 3.0.30819.47 =>
Newtonsoft.Json.dll               5.0.1.16007  =>
Owin.dll                          1.0          =>
```