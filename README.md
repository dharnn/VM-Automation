# VirtualBox VM Automation

## Overview

An automation project that simplifies the provisioning of Ubuntu virtual machines using PowerShell, Vagrant, and Oracle VirtualBox.

The project uses PowerShell to collect and validate VM configuration settings, while Vagrant manages VM provisioning.

## Technologies

- Windows PowerShell
- HashiCorp Vagrant
- Oracle VirtualBox
- Ubuntu Linux
- JSON
- Git and GitHub

## Features

- Automated virtual machine provisioning
- Host resource assessment for CPU, RAM, and disk space
- Configurable virtual machine resources
- Input validation and deployment confirmation
- JSON-based VM configuration
- Vagrant integration with VirtualBox

## Prerequisites

- Windows with PowerShell
- Oracle VirtualBox
- HashiCorp Vagrant
- Git

## Project Files

- `create-vm.ps1` — PowerShell provisioning script
- `Vagrantfile` — Vagrant configuration
- `vm.json` — Locally generated VM configuration, excluded from Git
- `.gitignore` — Excludes local VM state and sensitive files

## Usage

1. Clone the repository.
2. Open PowerShell in the project directory.
3. Review the PowerShell script and Vagrant configuration.
4. Execute the provisioning script:

```powershell
.\create-vm.ps1
```

5. Follow the prompts to configure and deploy the virtual machine.

## Security Considerations

- Local Vagrant state is excluded from version control.
- Machine-specific configuration is not committed.
- Private keys and sensitive files are excluded through `.gitignore`.

## Project Purpose

This project demonstrates practical infrastructure automation, virtualization administration, PowerShell scripting, resource validation, and repeatable VM provisioning.