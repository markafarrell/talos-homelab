machine:
  certSANs:
    - k.lan
    - {{ .Node.Host }}.lan

---
apiVersion: v1alpha1
kind: KubeAPIServerConfig
certExtraSANs:
  - k.lan
  - {{ .Node.Host }}.lan