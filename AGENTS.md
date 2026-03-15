# AGENTS.md

## Ruby Style
- This repository is Ruby-first. Prefer Ruby naming and control flow over Python- or Java-style ceremony.
- Use names that describe the role in the domain. Avoid vague plumbing names like `context`, `handler`, `data`, or `control` unless they are the clearest possible name.
- Boolean-returning methods must end with `?`.
- Prefer `find`, `any?`, early return, and guard clauses over `value = nil` plus later reassignment.
- Do not add `attr_reader` for every instance variable in a small internal object. If the state is only used internally, access the instance variable directly.
- If an object is already scoped to one responsibility, avoid redundant prefixes in every private method name.
- Do not prefix Ruby private methods with `_`. Use `private` for visibility and a normal method name for intent.

## Naming Examples

Bad:

```ruby
def _playwright_try_get_by_label(locator)
  # ...
end
```

Good:

```ruby
def find_by_label(locator)
  # ...
end
```

Bad:

```ruby
def click_associated_label(control)
  return true if control.evaluate("el => !!el.checked")
end
```

Good:

```ruby
def click_associated_label?(playwright_locator)
  return true if playwright_locator.evaluate("el => !!el.checked")
end
```

Bad:

```ruby
def initialize(node_context:, selector:, locator:, checked:)
  @node_context = node_context
  @selector = selector
  @locator = locator
  @checked = checked
end
```

Good:

```ruby
def initialize(node:, node_type:, locator:, checked:)
  @node = node
  @node_type = node_type
  @locator = locator
  @checked = checked
end
```

Bad:

```ruby
control = nil

candidates.each do |candidate|
  next unless matches?(candidate)

  control = candidate
  break
end

control
```

Good:

```ruby
candidates.find do |element_handle|
  matches?(element_handle)
end
```

Bad:

```ruby
attr_reader :node, :node_type, :locator, :checked
```

Good:

```ruby
def click_associated_label?(playwright_locator)
  return true if playwright_locator.evaluate("el => !!el.checked") == @checked
end
```

## General Guidance
- Prefer concise Ruby that reads top-to-bottom without carrying unnecessary temporary state.
- Prefer small private helper objects only when they reduce complexity. Once extracted, give them Ruby-like method names and keep their public surface minimal.
