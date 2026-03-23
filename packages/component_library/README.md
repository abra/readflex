# component_library

Shared presentation package for reusable UI building blocks.

## Put Here

- Design tokens and theme primitives
- Reusable visual widgets used by multiple screens or features
- Small layout shells for common presentation patterns
- Generic UI states such as loading, empty, and error
- UI-only controls and wrappers with no business logic

## Do Not Put Here

- Feature-specific screens, sheets, cards, or flows
- Repository, service, or routing logic
- Domain models, use cases, or application orchestration
- Widgets that are still used in only one place and have no clear reuse

## Rule of Thumb

If a widget is presentation-only and reused across features, it is a good
candidate for `component_library`.

If a widget knows about feature state, repositories, or product-specific
behavior, keep it in the feature package.
