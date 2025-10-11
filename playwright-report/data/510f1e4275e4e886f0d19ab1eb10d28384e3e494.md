# Page snapshot

```yaml
- generic [active] [ref=e1]:
  - link "Skip to main content" [ref=e2] [cursor=pointer]:
    - /url: "#content-start"
  - generic [ref=e3]:
    - banner [ref=e4]:
      - generic [ref=e5]:
        - link "Django administration" [ref=e7] [cursor=pointer]:
          - /url: /admin/
        - 'button "Toggle theme (current theme: auto)" [ref=e8] [cursor=pointer]':
          - generic [ref=e9] [cursor=pointer]: "Toggle theme (current theme: auto)"
          - img [ref=e10] [cursor=pointer]
    - navigation "Breadcrumbs" [ref=e12]:
      - link "Home" [ref=e14] [cursor=pointer]:
        - /url: /admin/
    - main [ref=e16]:
      - generic [ref=e17]:
        - heading "Logged out" [level=1] [ref=e18]
        - paragraph [ref=e19]: Thanks for spending some quality time with the web site today.
        - paragraph [ref=e20]:
          - link "Log in again" [ref=e21] [cursor=pointer]:
            - /url: /admin/
    - contentinfo
```