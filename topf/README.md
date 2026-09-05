# topf

## Encrypt secrets file

```bash
sops --age=$(age-keygen -y ${PWD}/../credentials/age.agekey) --encrypt --in-place secrets.yaml
```

## Render

```bash
export SOPS_AGE_KEY_FILE=${PWD}/../credentials/age.agekey

topf render
```

## Apply

```bash
export SOPS_AGE_KEY_FILE=${PWD}/../credentials/age.agekey

topf apply
```