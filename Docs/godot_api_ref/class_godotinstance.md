github_url
:   hide

# GodotInstance {#class_GodotInstance}

**Inherits:** `Object<class_Object>`{.interpreted-text role="ref"}

Provides access to an embedded Godot instance.

::: rst-class
classref-introduction-group
:::

## Description

GodotInstance represents a running Godot instance that is controlled from an outside codebase, without a perpetual main loop. It is created by the C API `libgodot_create_godot_instance`. Only one may be created per process.

::: rst-class
classref-reftable-group
:::

## Methods

::: rst-class
classref-section-separator
:::

------------------------------------------------------------------------

::: rst-class
classref-descriptions-group
:::

## Method Descriptions

:::: {#class_GodotInstance_method_focus_in}
::: rst-class
classref-method
:::
::::

`void (No return value.)`{.interpreted-text role="abbr"} **focus_in**() `🔗<class_GodotInstance_method_focus_in>`{.interpreted-text role="ref"}

Notifies the instance that it is now in focus.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_GodotInstance_method_focus_out}
::: rst-class
classref-method
:::
::::

`void (No return value.)`{.interpreted-text role="abbr"} **focus_out**() `🔗<class_GodotInstance_method_focus_out>`{.interpreted-text role="ref"}

Notifies the instance that it is now not in focus.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_GodotInstance_method_is_started}
::: rst-class
classref-method
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **is_started**() `🔗<class_GodotInstance_method_is_started>`{.interpreted-text role="ref"}

Returns `true` if this instance has been fully started.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_GodotInstance_method_iteration}
::: rst-class
classref-method
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **iteration**() `🔗<class_GodotInstance_method_iteration>`{.interpreted-text role="ref"}

Runs a single iteration of the main loop. Returns `true` if the engine is attempting to quit.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_GodotInstance_method_pause}
::: rst-class
classref-method
:::
::::

`void (No return value.)`{.interpreted-text role="abbr"} **pause**() `🔗<class_GodotInstance_method_pause>`{.interpreted-text role="ref"}

Notifies the instance that it is going to be paused.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_GodotInstance_method_resume}
::: rst-class
classref-method
:::
::::

`void (No return value.)`{.interpreted-text role="abbr"} **resume**() `🔗<class_GodotInstance_method_resume>`{.interpreted-text role="ref"}

Notifies the instance that it is being resumed.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_GodotInstance_method_start}
::: rst-class
classref-method
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **start**() `🔗<class_GodotInstance_method_start>`{.interpreted-text role="ref"}

Finishes this instance\'s startup sequence. Returns `true` on success.
