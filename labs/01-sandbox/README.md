# Lab 1: Stand up your GCP GRC sandbox

| | |
|---|---|
| **Video** | 01_04 |
| **Hands-on time** | ~30 min |
| **Cost** | $0 |
| **Prerequisites** | `docs/SETUP.md` steps 1 to 4 |
| **Where you'll work** | Your fork of `cgegcp`, repo root |

## Steps

### 1. Fork and clone

Fork `github.com/GRCEngClub/cgegcp` to your own GitHub account, then clone your fork. Every lab and your capstone live in this one repo.

### 2. Confirm the project and account

**where:** repo root

```bash
gcloud config list
```

The `account` line must be your Gmail, and `project` your lab project.

### 3. Run the probe

**where:** repo root

```bash
./labs/00-setup/probe.sh
```

**Expected output** (validated on a fresh project):

```
  ✓ no Organization above the project (course tenancy)
Enabling the APIs Lab 2 uses (stage 00 enables the rest in Lab 3)...
  ✓ cloudasset API enabled
  ✓ logging API enabled
  ✓ storage API enabled
  ✓ cloudresourcemanager API enabled
  ✓ cloudbilling API enabled
  ✓ billing linked
  ✓ Application Default Credentials present (Terraform will find them)
  ✓ Cloud Asset Inventory answers queries

Ready for Lab 2.
```

| If you see | Do this |
|---|---|
| `✗ no project pinned` | `gcloud config set project YOUR_PROJECT_ID` |
| `✗ no ADC` | `gcloud auth application-default login` |
| `✗ ... API still enabling` | Wait two minutes, run the probe again. Normal on a new project |
| `! project sits under an organization` | Fine, but read "If you have an Organization" in `docs/SETUP.md` |

### 4. Your evidence for this lab

The probe output and your budget configuration. Both are reproducible, so there's nothing to screenshot.

## Teardown

None. Everything later builds on this project.
