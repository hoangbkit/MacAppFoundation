# Theme catalog

MacAppFoundation exposes a reusable built-in theme catalog through `MacAppThemeCatalog` and matching `MacAppTheme` convenience accessors.

The current built-ins are:

| ID | Name | Scheme |
| --- | --- | --- |
| `system` | System | follows macOS |
| `github-dark-dimmed` | GitHub Dark Dimmed | dark |
| `midnight` | Midnight | dark |
| `ocean` | Ocean | dark |
| `aurora` | Aurora | dark |
| `ember` | Ember | dark |
| `graphite` | Graphite | dark |
| `porcelain` | Porcelain | light |
| `blossom` | Blossom | light |
| `morning-mist` | Morning Mist | light |
| `soft-sage` | Soft Sage | light |
| `sunrise` | Sunrise | light |
| `github-light` | GitHub Light | light |

Apps choose the subset they expose through `MacAppThemeConfiguration` and can insert custom themes with their own IDs.
