# Page snapshot

```yaml
- generic [ref=e1]:
  - link "Skip to main content" [ref=e2] [cursor=pointer]:
    - /url: "#content-start"
  - generic [ref=e3]:
    - banner [ref=e4]:
      - generic [ref=e5]:
        - link "Bakım ve Kalibrasyon Yönetimi" [ref=e7] [cursor=pointer]:
          - /url: /admin/
        - 'button "Toggle theme (current theme: auto)" [ref=e8] [cursor=pointer]':
          - generic [ref=e9] [cursor=pointer]: "Toggle theme (current theme: auto)"
          - img [ref=e10] [cursor=pointer]
    - main [ref=e13]:
      - generic [ref=e16]:
        - generic [ref=e17]:
          - generic [ref=e18]: "Username:"
          - textbox "Username:" [active] [ref=e19]
        - generic [ref=e20]:
          - generic [ref=e21]: "Password:"
          - textbox "Password:" [ref=e22]
        - button "Log in" [ref=e24] [cursor=pointer]
    - contentinfo
```