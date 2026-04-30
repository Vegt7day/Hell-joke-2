github_url
:   hide

# SplitContainer {#class_SplitContainer}

**Inherits:** `Container<class_Container>`{.interpreted-text role="ref"} **\<** `Control<class_Control>`{.interpreted-text role="ref"} **\<** `CanvasItem<class_CanvasItem>`{.interpreted-text role="ref"} **\<** `Node<class_Node>`{.interpreted-text role="ref"} **\<** `Object<class_Object>`{.interpreted-text role="ref"}

**Inherited By:** `HSplitContainer<class_HSplitContainer>`{.interpreted-text role="ref"}, `VSplitContainer<class_VSplitContainer>`{.interpreted-text role="ref"}

A container that arranges child controls horizontally or vertically and provides grabbers for adjusting the split ratios between them.

::: rst-class
classref-introduction-group
:::

## Description

A container that arranges child controls horizontally or vertically and creates grabbers between them. The grabbers can be dragged around to change the size relations between the child controls.

::: rst-class
classref-introduction-group
:::

## Tutorials

- `Using Containers <../tutorials/ui/gui_containers>`{.interpreted-text role="doc"}

::: rst-class
classref-reftable-group
:::

## Properties

::: rst-class
classref-reftable-group
:::

## Methods

::: rst-class
classref-reftable-group
:::

## Theme Properties

::: rst-class
classref-section-separator
:::

------------------------------------------------------------------------

::: rst-class
classref-descriptions-group
:::

## Signals

:::: {#class_SplitContainer_signal_drag_ended}
::: rst-class
classref-signal
:::
::::

**drag_ended**() `🔗<class_SplitContainer_signal_drag_ended>`{.interpreted-text role="ref"}

Emitted when the user ends dragging.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_signal_drag_started}
::: rst-class
classref-signal
:::
::::

**drag_started**() `🔗<class_SplitContainer_signal_drag_started>`{.interpreted-text role="ref"}

Emitted when the user starts dragging.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_signal_dragged}
::: rst-class
classref-signal
:::
::::

**dragged**(offset: `int<class_int>`{.interpreted-text role="ref"}) `🔗<class_SplitContainer_signal_dragged>`{.interpreted-text role="ref"}

Emitted when any dragger is dragged by user.

::: rst-class
classref-section-separator
:::

------------------------------------------------------------------------

::: rst-class
classref-descriptions-group
:::

## Enumerations

:::: {#enum_SplitContainer_DraggerVisibility}
::: rst-class
classref-enumeration
:::
::::

enum **DraggerVisibility**: `🔗<enum_SplitContainer_DraggerVisibility>`{.interpreted-text role="ref"}

:::: {#class_SplitContainer_constant_DRAGGER_VISIBLE}
::: rst-class
classref-enumeration-constant
:::
::::

`DraggerVisibility<enum_SplitContainer_DraggerVisibility>`{.interpreted-text role="ref"} **DRAGGER_VISIBLE** = `0`

The split dragger icon is always visible when `autohide<class_SplitContainer_theme_constant_autohide>`{.interpreted-text role="ref"} is `false`, otherwise visible only when the cursor hovers it.

The size of the grabber icon determines the minimum `separation<class_SplitContainer_theme_constant_separation>`{.interpreted-text role="ref"}.

The dragger icon is automatically hidden if the length of the grabber icon is longer than the split bar.

:::: {#class_SplitContainer_constant_DRAGGER_HIDDEN}
::: rst-class
classref-enumeration-constant
:::
::::

`DraggerVisibility<enum_SplitContainer_DraggerVisibility>`{.interpreted-text role="ref"} **DRAGGER_HIDDEN** = `1`

The split dragger icon is never visible regardless of the value of `autohide<class_SplitContainer_theme_constant_autohide>`{.interpreted-text role="ref"}.

The size of the grabber icon determines the minimum `separation<class_SplitContainer_theme_constant_separation>`{.interpreted-text role="ref"}.

:::: {#class_SplitContainer_constant_DRAGGER_HIDDEN_COLLAPSED}
::: rst-class
classref-enumeration-constant
:::
::::

`DraggerVisibility<enum_SplitContainer_DraggerVisibility>`{.interpreted-text role="ref"} **DRAGGER_HIDDEN_COLLAPSED** = `2`

The split dragger icon is not visible, and the split bar is collapsed to zero thickness.

::: rst-class
classref-section-separator
:::

------------------------------------------------------------------------

::: rst-class
classref-descriptions-group
:::

## Property Descriptions

:::: {#class_SplitContainer_property_collapsed}
::: rst-class
classref-property
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **collapsed** = `false` `🔗<class_SplitContainer_property_collapsed>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_collapsed**(value: `bool<class_bool>`{.interpreted-text role="ref"})
- `bool<class_bool>`{.interpreted-text role="ref"} **is_collapsed**()

If `true`, the draggers will be disabled and the children will be sized as if all `split_offsets<class_SplitContainer_property_split_offsets>`{.interpreted-text role="ref"} were `0`.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_property_drag_area_highlight_in_editor}
::: rst-class
classref-property
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **drag_area_highlight_in_editor** = `false` `🔗<class_SplitContainer_property_drag_area_highlight_in_editor>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_drag_area_highlight_in_editor**(value: `bool<class_bool>`{.interpreted-text role="ref"})
- `bool<class_bool>`{.interpreted-text role="ref"} **is_drag_area_highlight_in_editor_enabled**()

Highlights the drag area `Rect2<class_Rect2>`{.interpreted-text role="ref"} so you can see where it is during development. The drag area is gold if `dragging_enabled<class_SplitContainer_property_dragging_enabled>`{.interpreted-text role="ref"} is `true`, and red if `false`.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_property_drag_area_margin_begin}
::: rst-class
classref-property
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **drag_area_margin_begin** = `0` `🔗<class_SplitContainer_property_drag_area_margin_begin>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_drag_area_margin_begin**(value: `int<class_int>`{.interpreted-text role="ref"})
- `int<class_int>`{.interpreted-text role="ref"} **get_drag_area_margin_begin**()

Reduces the size of the drag area and split bar `split_bar_background<class_SplitContainer_theme_style_split_bar_background>`{.interpreted-text role="ref"} at the beginning of the container.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_property_drag_area_margin_end}
::: rst-class
classref-property
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **drag_area_margin_end** = `0` `🔗<class_SplitContainer_property_drag_area_margin_end>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_drag_area_margin_end**(value: `int<class_int>`{.interpreted-text role="ref"})
- `int<class_int>`{.interpreted-text role="ref"} **get_drag_area_margin_end**()

Reduces the size of the drag area and split bar `split_bar_background<class_SplitContainer_theme_style_split_bar_background>`{.interpreted-text role="ref"} at the end of the container.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_property_drag_area_offset}
::: rst-class
classref-property
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **drag_area_offset** = `0` `🔗<class_SplitContainer_property_drag_area_offset>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_drag_area_offset**(value: `int<class_int>`{.interpreted-text role="ref"})
- `int<class_int>`{.interpreted-text role="ref"} **get_drag_area_offset**()

Shifts the drag area in the axis of the container to prevent the drag area from overlapping the `ScrollBar<class_ScrollBar>`{.interpreted-text role="ref"} or other selectable `Control<class_Control>`{.interpreted-text role="ref"} of a child node.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_property_dragger_visibility}
::: rst-class
classref-property
:::
::::

`DraggerVisibility<enum_SplitContainer_DraggerVisibility>`{.interpreted-text role="ref"} **dragger_visibility** = `0` `🔗<class_SplitContainer_property_dragger_visibility>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_dragger_visibility**(value: `DraggerVisibility<enum_SplitContainer_DraggerVisibility>`{.interpreted-text role="ref"})
- `DraggerVisibility<enum_SplitContainer_DraggerVisibility>`{.interpreted-text role="ref"} **get_dragger_visibility**()

Determines the dragger\'s visibility. This property does not determine whether dragging is enabled or not. Use `dragging_enabled<class_SplitContainer_property_dragging_enabled>`{.interpreted-text role="ref"} for that.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_property_dragging_enabled}
::: rst-class
classref-property
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **dragging_enabled** = `true` `🔗<class_SplitContainer_property_dragging_enabled>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_dragging_enabled**(value: `bool<class_bool>`{.interpreted-text role="ref"})
- `bool<class_bool>`{.interpreted-text role="ref"} **is_dragging_enabled**()

Enables or disables split dragging.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_property_split_offset}
::: rst-class
classref-property
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **split_offset** = `0` `🔗<class_SplitContainer_property_split_offset>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_split_offset**(value: `int<class_int>`{.interpreted-text role="ref"})
- `int<class_int>`{.interpreted-text role="ref"} **get_split_offset**()

**Deprecated:** Use `split_offsets<class_SplitContainer_property_split_offsets>`{.interpreted-text role="ref"} instead. The first element of the array is the split offset between the first two children.

The first element of `split_offsets<class_SplitContainer_property_split_offsets>`{.interpreted-text role="ref"}.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_property_split_offsets}
::: rst-class
classref-property
:::
::::

`PackedInt32Array<class_PackedInt32Array>`{.interpreted-text role="ref"} **split_offsets** = `PackedInt32Array(0)` `🔗<class_SplitContainer_property_split_offsets>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_split_offsets**(value: `PackedInt32Array<class_PackedInt32Array>`{.interpreted-text role="ref"})
- `PackedInt32Array<class_PackedInt32Array>`{.interpreted-text role="ref"} **get_split_offsets**()

Offsets for each dragger in pixels. Each one is the offset of the split between the `Control<class_Control>`{.interpreted-text role="ref"} nodes before and after the dragger, with `0` being the default position. The default position is based on the `Control<class_Control>`{.interpreted-text role="ref"} nodes expand flags and minimum sizes. See `Control.size_flags_horizontal<class_Control_property_size_flags_horizontal>`{.interpreted-text role="ref"}, `Control.size_flags_vertical<class_Control_property_size_flags_vertical>`{.interpreted-text role="ref"}, and `Control.size_flags_stretch_ratio<class_Control_property_size_flags_stretch_ratio>`{.interpreted-text role="ref"}.

If none of the `Control<class_Control>`{.interpreted-text role="ref"} nodes before the dragger are expanded, the default position will be at the start of the **SplitContainer**. If none of the `Control<class_Control>`{.interpreted-text role="ref"} nodes after the dragger are expanded, the default position will be at the end of the **SplitContainer**. If the dragger is in between expanded `Control<class_Control>`{.interpreted-text role="ref"} nodes, the default position will be in the middle, based on the `Control.size_flags_stretch_ratio<class_Control_property_size_flags_stretch_ratio>`{.interpreted-text role="ref"}s and minimum sizes.

**Note:** If the split offsets cause `Control<class_Control>`{.interpreted-text role="ref"} nodes to overlap, the first split will take priority when resolving the positions.

**Note:** The returned array is *copied* and any changes to it will not update the original property value. See `PackedInt32Array<class_PackedInt32Array>`{.interpreted-text role="ref"} for more details.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_property_touch_dragger_enabled}
::: rst-class
classref-property
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **touch_dragger_enabled** = `false` `🔗<class_SplitContainer_property_touch_dragger_enabled>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_touch_dragger_enabled**(value: `bool<class_bool>`{.interpreted-text role="ref"})
- `bool<class_bool>`{.interpreted-text role="ref"} **is_touch_dragger_enabled**()

If `true`, a touch-friendly drag handle will be enabled for better usability on smaller screens. Unlike the standard grabber, this drag handle overlaps the **SplitContainer**\'s children and does not affect their minimum separation. The standard grabber will no longer be drawn when this option is enabled.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_property_vertical}
::: rst-class
classref-property
:::
::::

`bool<class_bool>`{.interpreted-text role="ref"} **vertical** = `false` `🔗<class_SplitContainer_property_vertical>`{.interpreted-text role="ref"}

::: rst-class
classref-property-setget
:::

- `void (No return value.)`{.interpreted-text role="abbr"} **set_vertical**(value: `bool<class_bool>`{.interpreted-text role="ref"})
- `bool<class_bool>`{.interpreted-text role="ref"} **is_vertical**()

If `true`, the **SplitContainer** will arrange its children vertically, rather than horizontally.

Can\'t be changed when using `HSplitContainer<class_HSplitContainer>`{.interpreted-text role="ref"} and `VSplitContainer<class_VSplitContainer>`{.interpreted-text role="ref"}.

::: rst-class
classref-section-separator
:::

------------------------------------------------------------------------

::: rst-class
classref-descriptions-group
:::

## Method Descriptions

:::: {#class_SplitContainer_method_clamp_split_offset}
::: rst-class
classref-method
:::
::::

`void (No return value.)`{.interpreted-text role="abbr"} **clamp_split_offset**(priority_index: `int<class_int>`{.interpreted-text role="ref"} = 0) `🔗<class_SplitContainer_method_clamp_split_offset>`{.interpreted-text role="ref"}

Clamps the `split_offsets<class_SplitContainer_property_split_offsets>`{.interpreted-text role="ref"} values to ensure they are within valid ranges and do not overlap with each other. When overlaps occur, this method prioritizes one split offset (at index `priority_index`) by clamping any overlapping split offsets to it.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_method_get_drag_area_control}
::: rst-class
classref-method
:::
::::

`Control<class_Control>`{.interpreted-text role="ref"} **get_drag_area_control**() `🔗<class_SplitContainer_method_get_drag_area_control>`{.interpreted-text role="ref"}

**Deprecated:** Use the first element of `get_drag_area_controls()<class_SplitContainer_method_get_drag_area_controls>`{.interpreted-text role="ref"} instead.

Returns the drag area `Control<class_Control>`{.interpreted-text role="ref"}. For example, you can move a pre-configured button into the drag area `Control<class_Control>`{.interpreted-text role="ref"} so that it rides along with the split bar. Try setting the `Button<class_Button>`{.interpreted-text role="ref"} anchors to `center` prior to the `reparent()` call.

    $BarnacleButton.reparent($SplitContainer.get_drag_area_control())

**Note:** The drag area `Control<class_Control>`{.interpreted-text role="ref"} is drawn over the **SplitContainer**\'s children, so `CanvasItem<class_CanvasItem>`{.interpreted-text role="ref"} draw objects called from the `Control<class_Control>`{.interpreted-text role="ref"} and children added to the `Control<class_Control>`{.interpreted-text role="ref"} will also appear over the **SplitContainer**\'s children. Try setting `Control.mouse_filter<class_Control_property_mouse_filter>`{.interpreted-text role="ref"} of custom children to `Control.MOUSE_FILTER_IGNORE<class_Control_constant_MOUSE_FILTER_IGNORE>`{.interpreted-text role="ref"} to prevent blocking the mouse from dragging if desired.

**Warning:** This is a required internal node, removing and freeing it may cause a crash.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_method_get_drag_area_controls}
::: rst-class
classref-method
:::
::::

`Array<class_Array>`{.interpreted-text role="ref"}\[`Control<class_Control>`{.interpreted-text role="ref"}\] **get_drag_area_controls**() `🔗<class_SplitContainer_method_get_drag_area_controls>`{.interpreted-text role="ref"}

Returns an `Array<class_Array>`{.interpreted-text role="ref"} of the drag area `Control<class_Control>`{.interpreted-text role="ref"}s. These are the interactable `Control<class_Control>`{.interpreted-text role="ref"} nodes between each child. For example, this can be used to add a pre-configured button to a drag area `Control<class_Control>`{.interpreted-text role="ref"} so that it rides along with the split bar. Try setting the `Button<class_Button>`{.interpreted-text role="ref"} anchors to `center` prior to the `Node.reparent()<class_Node_method_reparent>`{.interpreted-text role="ref"} call.

    $BarnacleButton.reparent($SplitContainer.get_drag_area_controls()[0])

**Note:** The drag area `Control<class_Control>`{.interpreted-text role="ref"}s are drawn over the **SplitContainer**\'s children, so `CanvasItem<class_CanvasItem>`{.interpreted-text role="ref"} draw objects called from a drag area and children added to it will also appear over the **SplitContainer**\'s children. Try setting `Control.mouse_filter<class_Control_property_mouse_filter>`{.interpreted-text role="ref"} of custom children to `Control.MOUSE_FILTER_IGNORE<class_Control_constant_MOUSE_FILTER_IGNORE>`{.interpreted-text role="ref"} to prevent blocking the mouse from dragging if desired.

**Warning:** These are required internal nodes, removing or freeing them may cause a crash.

::: rst-class
classref-section-separator
:::

------------------------------------------------------------------------

::: rst-class
classref-descriptions-group
:::

## Theme Property Descriptions

:::: {#class_SplitContainer_theme_color_touch_dragger_color}
::: rst-class
classref-themeproperty
:::
::::

`Color<class_Color>`{.interpreted-text role="ref"} **touch_dragger_color** = `Color(1, 1, 1, 0.3)` `🔗<class_SplitContainer_theme_color_touch_dragger_color>`{.interpreted-text role="ref"}

The color of the touch dragger.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_theme_color_touch_dragger_hover_color}
::: rst-class
classref-themeproperty
:::
::::

`Color<class_Color>`{.interpreted-text role="ref"} **touch_dragger_hover_color** = `Color(1, 1, 1, 0.6)` `🔗<class_SplitContainer_theme_color_touch_dragger_hover_color>`{.interpreted-text role="ref"}

The color of the touch dragger when hovered.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_theme_color_touch_dragger_pressed_color}
::: rst-class
classref-themeproperty
:::
::::

`Color<class_Color>`{.interpreted-text role="ref"} **touch_dragger_pressed_color** = `Color(1, 1, 1, 1)` `🔗<class_SplitContainer_theme_color_touch_dragger_pressed_color>`{.interpreted-text role="ref"}

The color of the touch dragger when pressed.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_theme_constant_autohide}
::: rst-class
classref-themeproperty
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **autohide** = `1` `🔗<class_SplitContainer_theme_constant_autohide>`{.interpreted-text role="ref"}

Boolean value. If `1` (`true`), the grabbers will hide automatically when they aren\'t under the cursor. If `0` (`false`), the grabbers are always visible. The `dragger_visibility<class_SplitContainer_property_dragger_visibility>`{.interpreted-text role="ref"} must be `DRAGGER_VISIBLE<class_SplitContainer_constant_DRAGGER_VISIBLE>`{.interpreted-text role="ref"}.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_theme_constant_minimum_grab_thickness}
::: rst-class
classref-themeproperty
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **minimum_grab_thickness** = `6` `🔗<class_SplitContainer_theme_constant_minimum_grab_thickness>`{.interpreted-text role="ref"}

The minimum thickness of the area users can click on to grab a split bar. This ensures that the split bar can still be dragged if `separation<class_SplitContainer_theme_constant_separation>`{.interpreted-text role="ref"} or `h_grabber<class_SplitContainer_theme_icon_h_grabber>`{.interpreted-text role="ref"} / `v_grabber<class_SplitContainer_theme_icon_v_grabber>`{.interpreted-text role="ref"}\'s size is too narrow to easily select.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_theme_constant_separation}
::: rst-class
classref-themeproperty
:::
::::

`int<class_int>`{.interpreted-text role="ref"} **separation** = `12` `🔗<class_SplitContainer_theme_constant_separation>`{.interpreted-text role="ref"}

The split bar thickness, i.e., the gap between each child of the container. This is overridden by the size of the grabber icon if `dragger_visibility<class_SplitContainer_property_dragger_visibility>`{.interpreted-text role="ref"} is set to `DRAGGER_VISIBLE<class_SplitContainer_constant_DRAGGER_VISIBLE>`{.interpreted-text role="ref"}, or `DRAGGER_HIDDEN<class_SplitContainer_constant_DRAGGER_HIDDEN>`{.interpreted-text role="ref"}, and `separation<class_SplitContainer_theme_constant_separation>`{.interpreted-text role="ref"} is smaller than the size of the grabber icon in the same axis.

**Note:** To obtain `separation<class_SplitContainer_theme_constant_separation>`{.interpreted-text role="ref"} values less than the size of the grabber icon, for example a `1 px` hairline, set `h_grabber<class_SplitContainer_theme_icon_h_grabber>`{.interpreted-text role="ref"} or `v_grabber<class_SplitContainer_theme_icon_v_grabber>`{.interpreted-text role="ref"} to a new `ImageTexture<class_ImageTexture>`{.interpreted-text role="ref"}, which effectively sets the grabber icon size to `0 px`.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_theme_icon_grabber}
::: rst-class
classref-themeproperty
:::
::::

`Texture2D<class_Texture2D>`{.interpreted-text role="ref"} **grabber** `🔗<class_SplitContainer_theme_icon_grabber>`{.interpreted-text role="ref"}

The icon used for the grabbers drawn in the separations. This is only used in `HSplitContainer<class_HSplitContainer>`{.interpreted-text role="ref"} and `VSplitContainer<class_VSplitContainer>`{.interpreted-text role="ref"}. For **SplitContainer**, see `h_grabber<class_SplitContainer_theme_icon_h_grabber>`{.interpreted-text role="ref"} and `v_grabber<class_SplitContainer_theme_icon_v_grabber>`{.interpreted-text role="ref"} instead.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_theme_icon_h_grabber}
::: rst-class
classref-themeproperty
:::
::::

`Texture2D<class_Texture2D>`{.interpreted-text role="ref"} **h_grabber** `🔗<class_SplitContainer_theme_icon_h_grabber>`{.interpreted-text role="ref"}

The icon used for the grabbers drawn in the separations when `vertical<class_SplitContainer_property_vertical>`{.interpreted-text role="ref"} is `false`.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_theme_icon_h_touch_dragger}
::: rst-class
classref-themeproperty
:::
::::

`Texture2D<class_Texture2D>`{.interpreted-text role="ref"} **h_touch_dragger** `🔗<class_SplitContainer_theme_icon_h_touch_dragger>`{.interpreted-text role="ref"}

The icon used for the drag handle when `touch_dragger_enabled<class_SplitContainer_property_touch_dragger_enabled>`{.interpreted-text role="ref"} is `true` and `vertical<class_SplitContainer_property_vertical>`{.interpreted-text role="ref"} is `false`.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_theme_icon_touch_dragger}
::: rst-class
classref-themeproperty
:::
::::

`Texture2D<class_Texture2D>`{.interpreted-text role="ref"} **touch_dragger** `🔗<class_SplitContainer_theme_icon_touch_dragger>`{.interpreted-text role="ref"}

The icon used for the drag handle when `touch_dragger_enabled<class_SplitContainer_property_touch_dragger_enabled>`{.interpreted-text role="ref"} is `true`. This is only used in `HSplitContainer<class_HSplitContainer>`{.interpreted-text role="ref"} and `VSplitContainer<class_VSplitContainer>`{.interpreted-text role="ref"}. For **SplitContainer**, see `h_touch_dragger<class_SplitContainer_theme_icon_h_touch_dragger>`{.interpreted-text role="ref"} and `v_touch_dragger<class_SplitContainer_theme_icon_v_touch_dragger>`{.interpreted-text role="ref"} instead.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_theme_icon_v_grabber}
::: rst-class
classref-themeproperty
:::
::::

`Texture2D<class_Texture2D>`{.interpreted-text role="ref"} **v_grabber** `🔗<class_SplitContainer_theme_icon_v_grabber>`{.interpreted-text role="ref"}

The icon used for the grabbers drawn in the separations when `vertical<class_SplitContainer_property_vertical>`{.interpreted-text role="ref"} is `true`.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_theme_icon_v_touch_dragger}
::: rst-class
classref-themeproperty
:::
::::

`Texture2D<class_Texture2D>`{.interpreted-text role="ref"} **v_touch_dragger** `🔗<class_SplitContainer_theme_icon_v_touch_dragger>`{.interpreted-text role="ref"}

The icon used for the drag handle when `touch_dragger_enabled<class_SplitContainer_property_touch_dragger_enabled>`{.interpreted-text role="ref"} is `true` and `vertical<class_SplitContainer_property_vertical>`{.interpreted-text role="ref"} is `true`.

::: rst-class
classref-item-separator
:::

------------------------------------------------------------------------

:::: {#class_SplitContainer_theme_style_split_bar_background}
::: rst-class
classref-themeproperty
:::
::::

`StyleBox<class_StyleBox>`{.interpreted-text role="ref"} **split_bar_background** `🔗<class_SplitContainer_theme_style_split_bar_background>`{.interpreted-text role="ref"}

Determines the background of the split bar if its thickness is greater than zero.
