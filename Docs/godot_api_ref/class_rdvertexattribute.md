github_url
:   hide

# RDVertexAttribute {#class_RDVertexAttribute}

**Inherits:** `RefCounted<class_RefCounted>`{.interpreted-text role="ref"} **\<** `Object<class_Object>`{.interpreted-text role="ref"}

Vertex attribute (used by `RenderingDevice<class_RenderingDevice>`{.interpreted-text role="ref"}).

::: rst-class
classref-introduction-group
:::

## Description

This object is used by `RenderingDevice<class_RenderingDevice>`{.interpreted-text role="ref"}.

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

## Property Descriptions

:::: {#class_RDVertexAttribute_property_binding}
::: rst-class
classref-property
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **binding** = `4294967295` `🔗<class_RDVertexAttribute_property_binding>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_binding**(value: `int<class_int>`{.interpreted-text role="ref"})
- `int<class_int>`{.interpreted-text role="ref"} **get_binding**()

The index of the buffer in the vertex buffer array to bind this vertex attribute. When set to `-1`, it defaults to the index of the attribute.

**Note:** You cannot mix binding explicitly assigned attributes with implicitly assigned ones (i.e. `-1`). Either all attributes must have their binding set to `-1`, or all must have explicit bindings.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_RDVertexAttribute_property_format}
::: rst-class
classref-property
:::
::::

`DataFormat<enum_RenderingDevice_DataFormat>`{.interpreted-text role="ref"} **format** = `232` `🔗<class_RDVertexAttribute_property_format>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_format**(value: `DataFormat<enum_RenderingDevice_DataFormat>`{.interpreted-text role="ref"})
- `DataFormat<enum_RenderingDevice_DataFormat>`{.interpreted-text role="ref"} **get_format**()

The way that this attribute\'s data is interpreted when sent to a shader.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_RDVertexAttribute_property_frequency}
::: rst-class
classref-property
:::
::::

`VertexFrequency<enum_RenderingDevice_VertexFrequency>`{.interpreted-text role="ref"} **frequency** = `0` `🔗<class_RDVertexAttribute_property_frequency>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_frequency**(value: `VertexFrequency<enum_RenderingDevice_VertexFrequency>`{.interpreted-text role="ref"})
- `VertexFrequency<enum_RenderingDevice_VertexFrequency>`{.interpreted-text role="ref"} **get_frequency**()

The rate at which this attribute is pulled from its vertex buffer.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_RDVertexAttribute_property_location}
::: rst-class
classref-property
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **location** = `0` `🔗<class_RDVertexAttribute_property_location>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_location**(value: `int<class_int>`{.interpreted-text role="ref"})
- `int<class_int>`{.interpreted-text role="ref"} **get_location**()

The location in the shader that this attribute is bound to.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_RDVertexAttribute_property_offset}
::: rst-class
classref-property
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **offset** = `0` `🔗<class_RDVertexAttribute_property_offset>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_offset**(value: `int<class_int>`{.interpreted-text role="ref"})
- `int<class_int>`{.interpreted-text role="ref"} **get_offset**()

The number of bytes between the start of the vertex buffer and the first instance of this attribute.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_RDVertexAttribute_property_stride}
::: rst-class
classref-property
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **stride** = `0` `🔗<class_RDVertexAttribute_property_stride>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_stride**(value: `int<class_int>`{.interpreted-text role="ref"})
- `int<class_int>`{.interpreted-text role="ref"} **get_stride**()

The number of bytes between the starts of consecutive instances of this attribute.
