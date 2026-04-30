github_url
:   hide

::: {.meta keywords="batch"}
:::

# MultiMeshInstance2D {#class_MultiMeshInstance2D}

**Inherits:** `Node2D<class_Node2D>`{.interpreted-text role="ref"} **\<** `CanvasItem<class_CanvasItem>`{.interpreted-text role="ref"} **\<** `Node<class_Node>`{.interpreted-text role="ref"} **\<** `Object<class_Object>`{.interpreted-text role="ref"}

Node that instances a `MultiMesh<class_MultiMesh>`{.interpreted-text role="ref"} in 2D.

::: rst-class
classref-introduction-group
:::

## Description

**MultiMeshInstance2D** is a specialized node to instance a `MultiMesh<class_MultiMesh>`{.interpreted-text role="ref"} resource in 2D. This can be faster to render compared to displaying many `Sprite2D<class_Sprite2D>`{.interpreted-text role="ref"} nodes with large transparent areas, especially if the nodes take up a lot of space on screen at high viewport resolutions. This is because using a mesh designed to fit the sprites\' opaque areas will reduce GPU fill rate utilization (at the cost of increased vertex processing utilization).

Usage is the same as `MultiMeshInstance3D<class_MultiMeshInstance3D>`{.interpreted-text role="ref"}.

::: rst-class
classref-reftable-group
:::

## Properties

::: rst-class
classref-section-separator
:::

------------------------------------------------------------------------

::: rst-class
classref-descriptions-group
:::

## Signals

:::: {#class_MultiMeshInstance2D_signal_texture_changed}
::: rst-class
classref-signal
:::
::::

**texture_changed**() `🔗<class_MultiMeshInstance2D_signal_texture_changed>`{.interpreted-text role="ref"}

Emitted when the `texture<class_MultiMeshInstance2D_property_texture>`{.interpreted-text role="ref"} is changed.

::: rst-class
classref-section-separator
:::

------------------------------------------------------------------------

::: rst-class
classref-descriptions-group
:::

## Property Descriptions

:::: {#class_MultiMeshInstance2D_property_multimesh}
::: rst-class
classref-property
:::
::::

`MultiMesh<class_MultiMesh>`{.interpreted-text role="ref"} **multimesh** `🔗<class_MultiMeshInstance2D_property_multimesh>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_multimesh**(value: `MultiMesh<class_MultiMesh>`{.interpreted-text role="ref"})
- `MultiMesh<class_MultiMesh>`{.interpreted-text role="ref"} **get_multimesh**()

The `MultiMesh<class_MultiMesh>`{.interpreted-text role="ref"} that will be drawn by the **MultiMeshInstance2D**.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_MultiMeshInstance2D_property_texture}
::: rst-class
classref-property
:::
::::

`Texture2D<class_Texture2D>`{.interpreted-text role="ref"} **texture** `🔗<class_MultiMeshInstance2D_property_texture>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_texture**(value: `Texture2D<class_Texture2D>`{.interpreted-text role="ref"})
- `Texture2D<class_Texture2D>`{.interpreted-text role="ref"} **get_texture**()

The `Texture2D<class_Texture2D>`{.interpreted-text role="ref"} that will be used if using the default `CanvasItemMaterial<class_CanvasItemMaterial>`{.interpreted-text role="ref"}. Can be accessed as `TEXTURE` in CanvasItem shader.
