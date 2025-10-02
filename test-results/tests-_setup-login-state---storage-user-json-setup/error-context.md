# Page snapshot

```yaml
- generic [active] [ref=e1]:
  - banner [ref=e2]:
    - heading "Page not found (404)" [level=1] [ref=e3]:
      - text: Page not found
      - generic [ref=e4]: (404)
    - table [ref=e5]:
      - rowgroup [ref=e6]:
        - 'row "Request Method: GET" [ref=e7]':
          - rowheader "Request Method:" [ref=e8]
          - cell "GET" [ref=e9]
        - 'row "Request URL: http://127.0.0.1:8010/accounts/login/" [ref=e10]':
          - rowheader "Request URL:" [ref=e11]
          - cell "http://127.0.0.1:8010/accounts/login/" [ref=e12]
  - main [ref=e13]:
    - paragraph [ref=e14]:
      - text: Using the URLconf defined in
      - code [ref=e15]: core.urls
      - text: ", Django tried these URL patterns, in this order:"
    - list [ref=e16]:
      - listitem [ref=e17]:
        - code
      - listitem [ref=e18]:
        - code [ref=e19]: admin/
      - listitem [ref=e20]:
        - code [ref=e21]: maintenance/
    - paragraph [ref=e22]:
      - text: The current path,
      - code [ref=e23]: accounts/login/
      - text: ", didn’t match any of these."
  - contentinfo [ref=e24]:
    - paragraph [ref=e25]:
      - text: You’re seeing this error because you have
      - code [ref=e26]: DEBUG = True
      - text: in your Django settings file. Change that to
      - code [ref=e27]: "False"
      - text: ", and Django will display a standard 404 page."
```